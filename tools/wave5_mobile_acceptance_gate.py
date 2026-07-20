#!/usr/bin/env python3
"""Static Wave 5 mobile acceptance guard.

This complements the Godot runtime tests with repository-structure checks that
must fail before CI spends time on imports, exports and captures.
"""

from __future__ import annotations

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
EXPECTED_LEARNING_CAPTURES = {
    f"bitling-{viewport}-learning-{state}.png"
    for viewport in ("phone", "tablet", "laptop")
    for state in ("catalog", "session")
}


def read(relative: str) -> str:
    return (ROOT / relative).read_text(encoding="utf-8")


def fail(message: str) -> None:
    print(f"[WAVE5-MOBILE] FAIL {message}")
    raise SystemExit(1)


def require(condition: bool, message: str) -> None:
    if not condition:
        fail(message)
    print(f"[WAVE5-MOBILE] PASS {message}")


def project_autoloads() -> dict[str, str]:
    project = read("project.godot")
    pairs = re.findall(r'^([A-Za-z0-9_]+)="\*(res://[^"]+)"$', project, flags=re.MULTILINE)
    return {name: path for name, path in pairs}


def assert_active_overlay() -> None:
    autoloads = project_autoloads()
    require(
        autoloads.get("LearningAdventureOverlay") == "res://scripts/ui/learning_adventure_overlay_v3.gd",
        "project.godot activates LearningAdventureOverlay v3",
    )


def assert_mobile_overlay_contract() -> None:
    overlay = read("scripts/ui/learning_adventure_overlay_v3.gd")
    require("func get_mobile_readability_snapshot()" in overlay, "overlay exposes mobile readability snapshot")
    require('"approach_grid_children"' in overlay, "overlay snapshot reports mobile approach grid children")
    require('"approach_row_children"' in overlay, "overlay snapshot reports desktop approach row children")
    require("GridContainer" in overlay and "columns = 2" in overlay, "phone approach buttons use a two-column grid")
    require(not re.search(r'font_size"\s*,\s*(?:[0-9]\b|1[01]\b)', overlay), "v3 overlay does not force sub-12px phone fonts")
    require("custom_minimum_size = Vector2(0, 62)" in overlay, "phone answers keep 62px minimum height")


def assert_visual_polish_contract() -> None:
    polish = read("scripts/ui/learning_adventure_visual_polish.gd")
    require('font_size", 7 if compact' not in polish, "visual polish does not shrink approach labels below readable size")
    require("set_reduced_motion" in polish, "visual polish propagates reduced motion to learning stage")
    stage = read("scripts/ui/learning_companion_stage.gd")
    require(
        re.search(r"func _process\(delta: float\) -> void:\n\tif _reduced_motion:\n\t\treturn\n\t_pulse =", stage) is not None,
        "learning stage stops decorative redraw work when reduced motion is enabled",
    )
    require("set_process(not enabled)" in stage, "learning stage disables decorative processing under reduced motion")
    require('"processing": is_processing()' in stage, "learning stage exposes processing state to runtime regression")
    context = read("scripts/ui/learning_decision_context_polish.gd")
    require('font_size", 10 if width < 760.0 else 11' not in context, "decision context keeps phone transfer text readable")
    transfer = read("scripts/ui/learning_transfer_map.gd")
    require("func set_reduced_motion(enabled: bool)" in transfer, "transfer constellation supports reduced motion")
    require("set_process(not enabled)" in transfer, "transfer constellation disables decorative processing under reduced motion")
    require('"processing": is_processing()' in transfer, "transfer constellation exposes processing state to runtime regression")
    transfer_polish = read("scripts/ui/learning_transfer_map_polish.gd")
    require("_last_reduced_motion" in transfer_polish, "transfer polish synchronizes reduced motion by state change")


def assert_service_signal_contract() -> None:
    service = read("scripts/core/learning_adventure_service.gd")
    require(
        len(re.findall(r'^\s*challenge_changed\.emit\(', service, flags=re.MULTILINE)) == 2,
        "service emits challenge_changed once at session start and once for each next round",
    )


def assert_workflow_contract() -> None:
    wave5 = read(".github/workflows/wave5-learning-adventures.yml")
    require("learning_adventure_overlay_v3.gd" in wave5, "Wave 5 workflow contract expects active overlay v3")
    require(
        'LearningAdventureOverlay="*res://scripts/ui/learning_adventure_overlay_v2.gd"' not in wave5,
        "Wave 5 workflow contract no longer requires overlay v2 as active",
    )
    visual = read(".github/workflows/visual-capture.yml")
    for filename in sorted(EXPECTED_LEARNING_CAPTURES):
        require(filename in visual, f"visual workflow verifies focused capture {filename}")
    require("if-no-files-found: error" in visual, "visual artifacts fail when PNGs are missing")
    focused_upload = re.search(
        r"name: bitling-learning-visuals\s+path:\s+\|\n(?P<paths>(?:\s+.+\n)+?)\s+if-no-files-found: error",
        visual,
    )
    require(focused_upload is not None, "focused learning artifact upload is explicit")
    focused_paths = focused_upload.group("paths") if focused_upload is not None else ""
    require("builds/learning-visuals/*.png" in focused_paths, "focused learning artifact uploads staged PNGs")
    require("logs/" not in focused_paths, "focused learning artifact excludes logs")


def assert_capture_script_contract() -> None:
    capture = read("tools/capture_learning_adventures.gd")
    for viewport in ("phone", "tablet", "laptop"):
        require(f'{{"name": "{viewport}"' in capture, f"learning capture script includes {viewport} viewport")
    require("Vector2i(390, 844)" in capture, "learning capture script exercises a 390px phone viewport")
    require('learning-catalog.png" % str(capture.get("name", "device"))' in capture, "learning capture script saves catalog states")
    require('learning-session.png" % str(capture.get("name", "device"))' in capture, "learning capture script saves session states")


def assert_runtime_test_contract() -> None:
    runtime_test = read("tests/wave5_learning_adventures_test.gd")
    visual_test = read("tests/wave5_learning_visual_polish_test.gd")
    require('call("_show_completion"' not in runtime_test, "runtime test reaches completion through service state, not private overlay methods")
    require("stops decorative processing under reduced motion" in visual_test, "visual runtime test verifies reduced-motion processing stops")


def main() -> int:
    assert_active_overlay()
    assert_mobile_overlay_contract()
    assert_visual_polish_contract()
    assert_service_signal_contract()
    assert_workflow_contract()
    assert_capture_script_contract()
    assert_runtime_test_contract()
    print("[WAVE5-MOBILE] PASS")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
