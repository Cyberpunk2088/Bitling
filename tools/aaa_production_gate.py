#!/usr/bin/env python3
"""BITLING OMNI production gate.

Development mode validates the enforceable code/content baseline on every change.
Release mode additionally requires the authored character, environment, UI and
sound packages declared in production/aaa_quality_manifest.json.
"""

from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parents[1]
MANIFEST_PATH = ROOT / "production" / "aaa_quality_manifest.json"


def load_json(path: Path) -> dict[str, Any]:
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        raise RuntimeError(f"cannot read {path.relative_to(ROOT)}: {exc}") from exc
    if not isinstance(data, dict):
        raise RuntimeError(f"{path.relative_to(ROOT)} must contain a JSON object")
    return data


def read_text(relative_path: str) -> str:
    path = ROOT / relative_path
    return path.read_text(encoding="utf-8")


def extract_block(source: str, constant_name: str, closing: str) -> str:
    pattern = rf"const\s+{re.escape(constant_name)}[^=]*=\s*([\{{\[])(.*?){re.escape(closing)}"
    match = re.search(pattern, source, flags=re.DOTALL)
    return match.group(2) if match else ""


def version_tuple(value: str) -> tuple[int, int, int]:
    match = re.match(r"^(\d+)\.(\d+)\.(\d+)", value.strip())
    if not match:
        return (0, 0, 0)
    return tuple(int(part) for part in match.groups())


def count_files(directory: Path, suffixes: tuple[str, ...]) -> int:
    if not directory.exists():
        return 0
    return sum(1 for path in directory.rglob("*") if path.is_file() and path.suffix.lower() in suffixes)


def add_check(report: dict[str, Any], name: str, passed: bool, actual: Any, target: Any, severity: str = "error") -> None:
    entry = {
        "name": name,
        "passed": bool(passed),
        "actual": actual,
        "target": target,
        "severity": severity,
    }
    report["checks"].append(entry)
    if not passed:
        report["failures"].append(entry)


def audit_required_files(manifest: dict[str, Any], report: dict[str, Any]) -> None:
    for relative in manifest.get("required_files", []):
        path = ROOT / str(relative)
        add_check(report, f"required_file:{relative}", path.is_file(), path.is_file(), True)


def audit_project(manifest: dict[str, Any], report: dict[str, Any]) -> None:
    project = read_text("project.godot")
    version_match = re.search(r'config/version="([^"]+)"', project)
    project_version = version_match.group(1) if version_match else "0.0.0"
    minimum_version = str(manifest.get("minimum_project_version", "0.0.0"))
    add_check(
        report,
        "project_version",
        version_tuple(project_version) >= version_tuple(minimum_version),
        project_version,
        minimum_version,
    )

    autoload_matches = re.findall(r'^([A-Za-z0-9_]+)="\*res://([^"]+)"$', project, flags=re.MULTILINE)
    names = [name for name, _ in autoload_matches]
    add_check(report, "autoload_names_unique", len(names) == len(set(names)), len(set(names)), len(names))
    missing_autoloads = [path for _, path in autoload_matches if not (ROOT / path).is_file()]
    add_check(report, "autoload_paths_exist", not missing_autoloads, missing_autoloads, [])
    add_check(report, "main_scene_declared", 'run/main_scene="res://main.tscn"' in project, True, True)


def audit_content_floors(manifest: dict[str, Any], report: dict[str, Any]) -> None:
    floors = manifest.get("development_floors", {})
    dialogue = read_text("scripts/core/dialogue_director.gd")
    evolution = read_text("scripts/core/evolution_matrix_service.gd")
    partner = read_text("scripts/core/partner_world_service.gd")
    audio = read_text("scripts/audio/omni_audio_director.gd")
    assets = read_text("scripts/visual/production_asset_catalog.gd")
    workflow = read_text(".github/workflows/visual-capture.yml")

    dialogue_count = len(re.findall(r'\{"id":\s*"[^"]+",\s*"text":', dialogue))
    evolution_count = len(re.findall(r'"minimum_level"\s*:', evolution))

    technique_block = extract_block(partner, "TECHNIQUE_THRESHOLDS", "}")
    technique_count = len(re.findall(r'^\s*"[^"]+"\s*:\s*[0-9.]+', technique_block, flags=re.MULTILINE))

    bus_block = extract_block(audio, "BUS_LEVELS", "}")
    audio_bus_count = len(re.findall(r'^\s*"[^"]+"\s*:', bus_block, flags=re.MULTILINE))

    primary_actions = sum(1 for action in ("feed", "play", "learn", "care", "rest") if f'"{action}":' in audio)

    animation_block = extract_block(assets, "REQUIRED_CHARACTER_ANIMATIONS", "]")
    animation_count = len(re.findall(r'"[^"]+"', animation_block))

    capture_count = len(re.findall(r'test -s builds/visual/bitling-(?:phone|tablet|laptop)(?:-partner-world)?\.png', workflow))
    test_count = count_files(ROOT / "tests", (".gd",))

    values = {
        "gdscript_test_files": test_count,
        "responsive_capture_count": capture_count,
        "audio_bus_count": audio_bus_count,
        "primary_action_count": primary_actions,
        "evolution_route_count": evolution_count,
        "partner_technique_count": technique_count,
        "dialogue_core_count": dialogue_count,
        "required_character_animation_contract": animation_count,
    }
    for metric, actual in values.items():
        target = int(floors.get(f"{metric}_min", 0))
        add_check(report, metric, actual >= target, actual, target)


def audit_code_health(report: dict[str, Any]) -> None:
    scripts = list((ROOT / "scripts").rglob("*.gd"))
    oversized: list[dict[str, Any]] = []
    tab_violations: list[str] = []
    for path in scripts:
        text = path.read_text(encoding="utf-8")
        line_count = len(text.splitlines())
        if line_count > 1200:
            oversized.append({"path": str(path.relative_to(ROOT)), "lines": line_count})
        for line_number, line in enumerate(text.splitlines(), start=1):
            if line.startswith("    ") and line.strip():
                tab_violations.append(f"{path.relative_to(ROOT)}:{line_number}")
                if len(tab_violations) >= 20:
                    break
    add_check(report, "gdscript_file_size_budget", not oversized, oversized, "<=1200 lines/file")
    add_check(report, "gdscript_tab_indentation", not tab_violations, tab_violations, [])


def audit_release_assets(manifest: dict[str, Any], report: dict[str, Any]) -> None:
    missing = [str(path) for path in manifest.get("release_assets", []) if not (ROOT / str(path)).is_file()]
    add_check(report, "authored_release_assets", not missing, missing, [])

    floors = manifest.get("release_content_floors", {})
    values = {
        "authored_music_tracks": count_files(ROOT / "assets" / "audio" / "music", (".ogg", ".wav", ".mp3")),
        "authored_ambience_loops": count_files(ROOT / "assets" / "audio" / "ambience", (".ogg", ".wav", ".mp3")),
        "authored_sfx_files": count_files(ROOT / "assets" / "audio" / "sfx", (".ogg", ".wav", ".mp3")),
        "authored_voice_files": count_files(ROOT / "assets" / "audio" / "voice", (".ogg", ".wav", ".mp3")),
        "supported_locales": count_files(ROOT / "localization", (".po", ".csv", ".translation")),
    }
    for metric, actual in values.items():
        target = int(floors.get(f"{metric}_min", 0))
        add_check(report, metric, actual >= target, actual, target)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--profile", choices=("development", "release"), default="development")
    parser.add_argument("--output", default="logs/aaa-production-gate.json")
    args = parser.parse_args()

    report: dict[str, Any] = {
        "profile": args.profile,
        "checks": [],
        "failures": [],
        "release_blocked": False,
    }
    try:
        manifest = load_json(MANIFEST_PATH)
        audit_required_files(manifest, report)
        audit_project(manifest, report)
        audit_content_floors(manifest, report)
        audit_code_health(report)
        if args.profile == "release":
            audit_release_assets(manifest, report)
    except (OSError, RuntimeError, UnicodeError) as exc:
        add_check(report, "gate_execution", False, str(exc), "successful audit")

    report["passed"] = not report["failures"]
    report["release_blocked"] = args.profile == "release" and not report["passed"]
    output = ROOT / args.output
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(json.dumps(report, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")

    for check in report["checks"]:
        marker = "PASS" if check["passed"] else "FAIL"
        print(f"[AAA-GATE] {marker} {check['name']}: {check['actual']} / {check['target']}")
    if report["passed"]:
        print(f"[AAA-GATE] PASS ({args.profile})")
        return 0
    print(f"[AAA-GATE] BLOCKED ({args.profile}): {len(report['failures'])} failure(s)", file=sys.stderr)
    return 1


if __name__ == "__main__":
    raise SystemExit(main())
