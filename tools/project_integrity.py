#!/usr/bin/env python3
"""Fail fast on repository conditions that make BITLING incompatible with Xogot."""

from __future__ import annotations

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
PROJECT_FILE = ROOT / "project.godot"
FORBIDDEN_SUFFIXES = {".cs", ".csproj", ".sln", ".gdextension", ".so", ".dll", ".dylib"}
MAX_GDSCRIPT_BYTES = 128 * 1024


def res_path_to_file(value: str) -> Path:
    if not value.startswith("res://"):
        raise ValueError(f"Expected res:// path, got {value!r}")
    return ROOT / value.removeprefix("res://")


def parse_project_paths(text: str) -> list[tuple[str, str]]:
    paths: list[tuple[str, str]] = []
    main_match = re.search(r'^run/main_scene="([^"]+)"', text, re.MULTILINE)
    if main_match:
        paths.append(("main scene", main_match.group(1)))

    in_autoload = False
    for raw_line in text.splitlines():
        line = raw_line.strip()
        if line.startswith("[") and line.endswith("]"):
            in_autoload = line == "[autoload]"
            continue
        if not in_autoload or not line or line.startswith(";"):
            continue
        match = re.match(r'([^=]+)="\*?([^"]+)"$', line)
        if match:
            paths.append((f"autoload {match.group(1).strip()}", match.group(2)))
    return paths


def main() -> int:
    errors: list[str] = []
    if not PROJECT_FILE.exists():
        errors.append("project.godot is missing")
    else:
        project_text = PROJECT_FILE.read_text(encoding="utf-8")
        for label, resource_path in parse_project_paths(project_text):
            try:
                file_path = res_path_to_file(resource_path)
            except ValueError as exc:
                errors.append(f"{label}: {exc}")
                continue
            if not file_path.exists():
                errors.append(f"{label} points to missing file: {resource_path}")

    forbidden: list[Path] = []
    oversized: list[Path] = []
    gdscript_count = 0
    for path in ROOT.rglob("*"):
        if not path.is_file() or ".git" in path.parts:
            continue
        if path.suffix.lower() in FORBIDDEN_SUFFIXES:
            forbidden.append(path.relative_to(ROOT))
        if path.suffix.lower() == ".gd":
            gdscript_count += 1
            if path.stat().st_size > MAX_GDSCRIPT_BYTES:
                oversized.append(path.relative_to(ROOT))

    for path in forbidden:
        errors.append(f"Xogot-incompatible native/C# artifact: {path}")
    for path in oversized:
        errors.append(f"GDScript exceeds {MAX_GDSCRIPT_BYTES} bytes and must be split: {path}")

    if gdscript_count == 0:
        errors.append("No GDScript files found")

    if errors:
        print("[integrity] FAIL")
        for error in errors:
            print(f"[integrity] - {error}")
        return 1

    print(f"[integrity] PASS: {gdscript_count} GDScript files, all project paths resolved")
    return 0


if __name__ == "__main__":
    sys.exit(main())
