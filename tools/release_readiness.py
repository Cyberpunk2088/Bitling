#!/usr/bin/env python3
"""Static public-release audit for BITLING.

The default CI mode fails deterministic code/configuration defects. Product,
store, legal and content blockers are reported without stopping engineering CI;
`--strict-release` converts those blockers into a failing release gate.
"""

from __future__ import annotations

import argparse
import json
import re
import sys
from dataclasses import asdict, dataclass
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
PROJECT = ROOT / "project.godot"
EXPORT_PRESETS = ROOT / "export_presets.cfg"

SECRET_PATTERNS = {
    "OpenAI key": re.compile(r"\bsk-(?:proj-)?[A-Za-z0-9_-]{20,}\b"),
    "GitHub token": re.compile(r"\bgh[pousr]_[A-Za-z0-9]{20,}\b"),
    "private key": re.compile(r"-----BEGIN (?:RSA |EC |OPENSSH )?PRIVATE KEY-----"),
}

XOGOT_FORBIDDEN_PATTERNS = {
    "OS process execution": re.compile(r"\bOS\.(?:execute|create_process|create_instance)\s*\("),
    "native extension manager": re.compile(r"\bGDExtensionManager\b"),
    "Java reflection bridge": re.compile(r"\bJavaClassWrapper\b"),
    "Objective-C bridge": re.compile(r"\b(?:ObjectiveC|ObjC)\w*\b"),
}

ALLOWED_COGNITIVE_INDEX_FILES = {
    Path("scripts/social/bitling_identity.gd"),
}

TEXT_SUFFIXES = {".gd", ".tscn", ".tres", ".cfg", ".md", ".py", ".json", ".yml", ".yaml", ".po", ".csv"}
TRANSLATION_SUFFIXES = {".translation", ".po", ".mo"}


@dataclass
class Finding:
    code: str
    severity: str
    message: str
    path: str = ""


def read_text(path: Path) -> str:
    try:
        return path.read_text(encoding="utf-8")
    except (OSError, UnicodeDecodeError):
        return ""


def iter_text_files() -> list[Path]:
    result: list[Path] = []
    for path in ROOT.rglob("*"):
        if not path.is_file() or ".git" in path.parts or path.suffix.lower() not in TEXT_SUFFIXES:
            continue
        result.append(path)
    return sorted(result)


def is_runtime_source(path: Path) -> bool:
    rel = path.relative_to(ROOT)
    return rel.name == "Bitling_Core.gd" or (rel.parts and rel.parts[0] == "scripts")


def add(findings: list[Finding], code: str, severity: str, message: str, path: Path | None = None) -> None:
    findings.append(Finding(code, severity, message, str(path.relative_to(ROOT)) if path else ""))


def audit_project(findings: list[Finding]) -> dict[str, object]:
    if not PROJECT.exists():
        add(findings, "PROJECT_MISSING", "error", "project.godot is missing")
        return {}

    text = read_text(PROJECT)
    version = re.search(r'^config/version="([^"]+)"', text, re.MULTILINE)
    if version is None:
        add(findings, "APP_VERSION_MISSING", "error", "application/config/version must be set", PROJECT)

    if 'window/energy_saving/keep_screen_on=true' in text:
        add(findings, "SCREEN_ALWAYS_ON", "error", "The game keeps the display awake globally; enable this only during an active call", PROJECT)

    autoload_match = re.search(r"\[autoload\](.*?)(?:\n\[|\Z)", text, re.DOTALL)
    autoload_count = 0
    if autoload_match:
        autoload_count = sum(
            1 for line in autoload_match.group(1).splitlines()
            if line.strip() and not line.lstrip().startswith(";") and "=" in line
        )
    if autoload_count > 20:
        add(findings, "AUTOLOAD_COUNT_HIGH", "warning", f"{autoload_count} autoloads increase startup coupling and memory pressure", PROJECT)

    translation_assets = [
        path.relative_to(ROOT) for path in ROOT.rglob("*")
        if path.is_file() and path.suffix.lower() in TRANSLATION_SUFFIXES
    ]
    has_translation_config = "[internationalization]" in text and "locale/translations" in text
    if not translation_assets and not has_translation_config:
        add(findings, "LOCALIZATION_PIPELINE_MISSING", "blocker", "No Godot translation resources or internationalization configuration exist", PROJECT)

    return {
        "version": version.group(1) if version else "",
        "autoload_count": autoload_count,
        "translation_assets": [str(path) for path in translation_assets],
    }


def audit_export(findings: list[Finding]) -> dict[str, object]:
    if not EXPORT_PRESETS.exists():
        add(findings, "EXPORT_PRESETS_MISSING", "blocker", "No export_presets.cfg exists", EXPORT_PRESETS)
        return {}

    text = read_text(EXPORT_PRESETS)
    bundle_match = re.search(r'application/bundle_identifier="([^"]*)"', text)
    team_match = re.search(r'application/app_store_team_id="([^"]*)"', text)
    bundle_id = bundle_match.group(1) if bundle_match else ""
    team_id = team_match.group(1) if team_match else ""

    if not bundle_id or bundle_id == "com.example.bitling" or ".example." in bundle_id:
        add(findings, "IOS_BUNDLE_PLACEHOLDER", "blocker", "Replace the placeholder iOS bundle identifier with the final unique identifier", EXPORT_PRESETS)
    if not team_id:
        add(findings, "IOS_TEAM_ID_MISSING", "blocker", "Apple App Store Team ID is required for an iOS release", EXPORT_PRESETS)

    audio_input = 'driver/enable_input=true' in read_text(PROJECT)
    if audio_input:
        for key, label in [
            ("privacy/microphone_usage_description", "microphone"),
            ("privacy/camera_usage_description", "camera"),
        ]:
            match = re.search(rf'{re.escape(key)}="([^"]*)"', text)
            if match is None or not match.group(1).strip():
                add(findings, f"IOS_{label.upper()}_DISCLOSURE_MISSING", "error", f"iOS {label} usage description is required", EXPORT_PRESETS)

    preset_names = set(re.findall(r'^name="([^"]+)"', text, re.MULTILINE))
    expected_names = {"Windows Desktop", "iOS Xogot", "Android", "Web", "Linux", "macOS"}
    missing_names = sorted(expected_names - preset_names)
    if missing_names:
        add(findings, "EXPORT_PRESET_REQUIRED_MISSING", "blocker", f"Missing public platform presets: {', '.join(missing_names)}", EXPORT_PRESETS)

    expected_platforms = {"Windows Desktop", "iOS", "Android", "Web", "Linux/X11", "macOS"}
    present_platforms = set(re.findall(r'^platform="([^"]+)"', text, re.MULTILINE))
    missing_platforms = sorted(expected_platforms - present_platforms)
    if missing_platforms:
        add(findings, "CROSS_PLATFORM_PRESETS_INCOMPLETE", "blocker", f"Public cross-platform claim is not backed by exporters for: {', '.join(missing_platforms)}", EXPORT_PRESETS)

    return {
        "bundle_identifier": bundle_id,
        "team_id_present": bool(team_id),
        "presets": sorted(preset_names),
        "platforms": sorted(present_platforms),
    }


def audit_defaults(findings: list[Finding]) -> None:
    state_file = ROOT / "scripts/core/game_state.gd"
    text = read_text(state_file)
    required_safe_defaults = {
        '"notifications_enabled": false': "Notifications must default to opt-in",
        '"social_discovery_enabled": false': "Social discovery must default to disabled",
        '"voice_chat_enabled": false': "Voice chat must default to disabled",
        '"video_chat_enabled": false': "Video chat must default to disabled",
        '"share_public_passport": false': "Passport sharing must default to disabled",
    }
    for needle, message in required_safe_defaults.items():
        if needle not in text:
            add(findings, "UNSAFE_DEFAULT", "error", message, state_file)


def audit_content(findings: list[Finding]) -> dict[str, int]:
    counters = {
        "text_files": 0,
        "gdscript_files": 0,
        "todo_markers": 0,
        "hardcoded_ui_strings": 0,
        "xogot_forbidden_apis": 0,
    }
    for path in iter_text_files():
        counters["text_files"] += 1
        if path.suffix == ".gd":
            counters["gdscript_files"] += 1
        text = read_text(path)
        rel = path.relative_to(ROOT)
        runtime_source = is_runtime_source(path)

        for label, pattern in SECRET_PATTERNS.items():
            if pattern.search(text):
                add(findings, "SECRET_DETECTED", "error", f"Possible {label} committed to the repository", path)

        if runtime_source:
            for label, pattern in XOGOT_FORBIDDEN_PATTERNS.items():
                if pattern.search(text):
                    counters["xogot_forbidden_apis"] += 1
                    add(findings, "XOGOT_FORBIDDEN_API", "error", f"Runtime source uses unsupported or non-portable {label}", path)

            todo_count = len(re.findall(r"\b(?:TODO|FIXME|HACK|XXX)\b", text, re.IGNORECASE))
            if todo_count:
                counters["todo_markers"] += todo_count
                add(findings, "OPEN_IMPLEMENTATION_MARKER", "warning", f"Contains {todo_count} TODO/FIXME-style markers", path)

            if "cognitive_index" in text and rel not in ALLOWED_COGNITIVE_INDEX_FILES:
                add(findings, "DEPRECATED_COGNITIVE_INDEX", "error", "Deprecated cognitive_index reference remains outside migration code", path)

            if path.suffix == ".gd":
                quoted = re.findall(r'"([^"\n]{8,})"', text)
                likely_ui = [
                    value for value in quoted
                    if re.search(r"[A-Za-zÄÖÜäöüß]", value)
                    and not value.startswith(("res://", "user://", "/root/"))
                ]
                if len(likely_ui) > 15:
                    counters["hardcoded_ui_strings"] += len(likely_ui)
                    add(findings, "LOCALIZATION_DEBT", "warning", f"Approximately {len(likely_ui)} user-facing or semantic strings remain embedded in code", path)

            if "http://" in text:
                add(findings, "INSECURE_HTTP", "error", "Plain HTTP endpoint found", path)

    return counters


def audit_release_assets(findings: list[Finding]) -> None:
    icon_candidates = [ROOT / "icon.svg", ROOT / "icon.png", ROOT / "assets/icon.svg", ROOT / "assets/icon.png"]
    if not any(path.exists() for path in icon_candidates):
        add(findings, "APP_ICON_MISSING", "blocker", "No production app icon is present")

    if not (ROOT / "LICENSE").exists() and not (ROOT / "LICENSE.md").exists():
        add(findings, "LICENSE_MISSING", "blocker", "Public repository has no explicit software/content license")

    privacy_candidates = [ROOT / "PRIVACY.md", ROOT / "docs/PRIVACY.md", ROOT / "docs/PRIVACY_POLICY.md"]
    if not any(path.exists() for path in privacy_candidates):
        add(findings, "PRIVACY_POLICY_MISSING", "blocker", "No publishable in-app/store privacy policy is present")

    if not (ROOT / "docs/PRIVACY_AND_CHILD_SAFETY_RELEASE_GATE.md").exists():
        add(findings, "CHILD_SAFETY_GATE_MISSING", "error", "Child-safety and social-feature release gate is missing")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--output", type=Path)
    parser.add_argument("--strict-release", action="store_true")
    args = parser.parse_args()

    findings: list[Finding] = []
    metadata = {
        "project": audit_project(findings),
        "export": audit_export(findings),
    }
    audit_defaults(findings)
    metadata["content"] = audit_content(findings)
    audit_release_assets(findings)

    counts = {
        severity: sum(1 for finding in findings if finding.severity == severity)
        for severity in ["error", "blocker", "warning"]
    }
    score = max(0, 100 - counts["error"] * 12 - counts["blocker"] * 7 - min(counts["warning"], 20) * 2)
    report = {
        "score": score,
        "counts": counts,
        "metadata": metadata,
        "findings": [asdict(finding) for finding in findings],
    }

    rendered = json.dumps(report, ensure_ascii=False, indent=2)
    print(rendered)
    if args.output:
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(rendered + "\n", encoding="utf-8")

    should_fail = counts["error"] > 0 or (args.strict_release and counts["blocker"] > 0)
    return 1 if should_fail else 0


if __name__ == "__main__":
    sys.exit(main())
