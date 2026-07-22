#!/usr/bin/env python3
"""Non-negotiable architecture gate for BITLING OMNI's habitat-first loop."""

from __future__ import annotations

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
FAILURES: list[str] = []
ASSERTIONS = 0


def check(condition: bool, message: str) -> None:
    global ASSERTIONS
    ASSERTIONS += 1
    if condition:
        print(f"[HABITAT-ARCH] PASS: {message}")
    else:
        FAILURES.append(message)
        print(f"[HABITAT-ARCH] FAIL: {message}", file=sys.stderr)


def read(relative: str) -> str:
    path = ROOT / relative
    check(path.is_file(), f"{relative} exists")
    return path.read_text(encoding="utf-8") if path.is_file() else ""


def main() -> int:
    project = read("project.godot")
    scene = read("main.tscn")
    service = read("scripts/core/habitat_interaction_service.gd")
    dashboard = read("scripts/ui/ultimate_dashboard_habitat.gd")
    stage = read("scripts/ui/bitling_habitat_stage.gd")
    marker_overlay = read("scripts/ui/habitat_hotspot_overlay.gd")
    visual_director = read("scripts/ui/metafinal_visual_director_v9.gd")
    runtime_test = read("tests/habitat_gameplay_test.gd")

    check(
        'HabitatInteraction="*res://scripts/core/habitat_interaction_service.gd"' in project,
        "habitat service is an authoritative autoload",
    )
    check(
        'path="res://scripts/ui/ultimate_dashboard_habitat.gd"' in scene,
        "main scene cannot fall back to the passive dashboard",
    )

    lens_match = re.search(r"const LENS_ORDER[^=]*=\s*\[(.*?)\]", service)
    lenses = re.findall(r'"([a-z_]+)"', lens_match.group(1)) if lens_match else []
    check(lenses == ["feed", "play", "learn", "care", "rest"], "exactly five intentional lenses are enforced")

    option_ids = re.findall(r'\b_o\("([a-z_]+)"', service)
    check(len(option_ids) == 15, "fifteen contextual approaches exist")
    check(len(set(option_ids)) == 15, "all contextual approaches have unique identities")
    for lens in lenses:
        block = re.search(rf'"{lens}":\s*\[(.*?)\](?:,\s*"|\s*\n\s*\}})', service, re.S)
        count = len(re.findall(r'\b_o\("', block.group(1))) if block else 0
        check(count == 3, f"{lens} has exactly three approaches")

    moment_block = re.search(r"const MOMENTS := \{(.*?)\n\}", service, re.S)
    moments = re.findall(r'^\s*"([a-z_]+)":\s*\{', moment_block.group(1), re.M) if moment_block else []
    check(len(moments) >= 9, "needs, intentions and room events create at least nine situations")
    check({"quiet", "window", "hologram", "parts", "plant", "lightball", "rest", "hungry", "recovery"}.issubset(set(moments)), "required habitat situations remain present")

    hotspots = {"bitling", "window", "workbench", "plant", "platform", "sleep"}
    for hotspot in sorted(hotspots):
        check(f'"{hotspot}"' in stage, f"{hotspot} remains clickable in the central habitat")
        check(f'"{hotspot}"' in service, f"{hotspot} remains connected to gameplay context")

    check(
        'extends "res://scripts/ui/production_bitling_stage_3d_v11.gd"' in stage,
        "habitat interaction is fused into the production 3D Living Home stage",
    )
    check("signal hotspot_pressed" in stage, "stage emits in-world interactions")
    check("HabitatHotspotOverlay" in stage, "production stage renders non-blocking room markers")
    check("mouse_filter = Control.MOUSE_FILTER_IGNORE" in marker_overlay, "hotspot markers can never steal stage input")
    check("hotspot_count\": 6" in stage or '"hotspot_count": 6' in stage, "stage diagnostics expose all six room hotspots")

    check(
        'preload("res://scripts/ui/bitling_habitat_stage.gd")' in visual_director,
        "visual director installs the habitat-capable production stage",
    )
    check("_wire_habitat_stage" in visual_director, "visual director explicitly wires habitat signals")
    check("hotspot_pressed" in visual_director, "visual director forwards room-level agency")
    check("_stage = ProductionStage3DV11.new()" not in visual_director, "visual director cannot silently restore a passive stage")
    check("LEGACY_STAGE_NAME" in visual_director, "legacy Wave diagnostics remain compatible without changing behavior")

    check("HabitatChoices" in dashboard, "dashboard renders contextual decisions in the center")
    check("range(3)" in dashboard, "dashboard reserves three simultaneous approaches")
    check("_run_interaction(" not in dashboard, "habitat UI cannot directly grant stat rewards")
    check("resolve_choice" in dashboard, "all center choices pass through the authoritative resolver")
    check("open_expedition" in dashboard and "open_adventures" in dashboard, "deep activities remain integrated overlays")
    check("center_is_game" in dashboard, "dashboard exposes a testable center-is-game contract")

    check("five intentional lenses replace direct stat buttons" in runtime_test, "runtime test guards the design diagnosis")
    check("interactive habitat stage replaces passive portrait" in runtime_test, "runtime test rejects passive center regressions")
    check("all contextual decisions remain available on phone" in runtime_test, "runtime test protects phone gameplay parity")

    if FAILURES:
        print(f"[HABITAT-ARCH] BLOCKED: {len(FAILURES)} of {ASSERTIONS} checks failed", file=sys.stderr)
        return 1
    print(f"[HABITAT-ARCH] PASS: {ASSERTIONS} checks")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
