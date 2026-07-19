#!/usr/bin/env python3
"""Validate the machine-readable BITLING legendary roadmap."""

from __future__ import annotations

import json
import re
import sys
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parents[1]
ROADMAP_PATH = ROOT / "production" / "legendary_roadmap.json"
MANIFEST_PATH = ROOT / "production" / "aaa_quality_manifest.json"
PILLARS_PATH = ROOT / "docs" / "LEGENDARY_PRODUCTION_PILLARS.md"
DOD_PATH = ROOT / "docs" / "LEGENDARY_DEFINITION_OF_DONE.md"


def load_object(path: Path) -> dict[str, Any]:
    data = json.loads(path.read_text(encoding="utf-8"))
    if not isinstance(data, dict):
        raise ValueError(f"{path.name} must contain an object")
    return data


def fail(message: str) -> None:
    print(f"[ROADMAP-GATE] FAIL {message}", file=sys.stderr)
    raise SystemExit(1)


def main() -> int:
    try:
        roadmap = load_object(ROADMAP_PATH)
        manifest = load_object(MANIFEST_PATH)
        pillars_text = PILLARS_PATH.read_text(encoding="utf-8")
        dod_text = DOD_PATH.read_text(encoding="utf-8")
    except (OSError, ValueError, json.JSONDecodeError) as exc:
        fail(str(exc))

    floors = manifest.get("development_floors", {})
    milestones = roadmap.get("milestones", [])
    blockers = roadmap.get("release_blockers", [])
    content_targets = roadmap.get("version_1_content_targets", {})
    pillar_count = len(re.findall(r"^##\s+[A-N]\.\s+", pillars_text, flags=re.MULTILINE))

    checks = {
        "milestones": (len(milestones), int(floors.get("legendary_roadmap_milestones_min", 12))),
        "production_pillars": (pillar_count, int(floors.get("legendary_production_pillars_min", 14))),
        "release_blockers": (len(blockers), int(floors.get("legendary_release_blockers_min", 9))),
        "version_1_content_targets": (len(content_targets), 10),
        "definition_of_done_passes": (len(re.findall(r"^### Pass [1-5]", dod_text, flags=re.MULTILINE)), 5),
    }

    milestone_ids: list[str] = []
    for item in milestones:
        if not isinstance(item, dict):
            fail("every milestone must be an object")
        milestone_id = str(item.get("id", "")).strip()
        if not milestone_id:
            fail("milestone id missing")
        if milestone_id in milestone_ids:
            fail(f"duplicate milestone id: {milestone_id}")
        milestone_ids.append(milestone_id)
        if not item.get("deliverables"):
            fail(f"milestone {milestone_id} has no deliverables")
        if not str(item.get("exit_gate", "")).strip():
            fail(f"milestone {milestone_id} has no exit gate")

    known = set(milestone_ids)
    for item in milestones:
        milestone_id = str(item["id"])
        for dependency in item.get("depends_on", []):
            if dependency not in known:
                fail(f"milestone {milestone_id} references unknown dependency {dependency}")

    for name, (actual, target) in checks.items():
        if actual < target:
            fail(f"{name}: {actual} < {target}")
        print(f"[ROADMAP-GATE] PASS {name}: {actual} / {target}")

    print("[ROADMAP-GATE] PASS")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
