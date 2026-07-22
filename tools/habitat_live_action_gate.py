#!/usr/bin/env python3
"""Hard architecture gate for BITLING's in-world moment-to-moment loop."""

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
        print(f"[LIVE-ACTION-ARCH] PASS: {message}")
    else:
        FAILURES.append(message)
        print(f"[LIVE-ACTION-ARCH] FAIL: {message}", file=sys.stderr)


def read(relative: str) -> str:
    path = ROOT / relative
    check(path.is_file(), f"{relative} exists")
    return path.read_text(encoding="utf-8") if path.is_file() else ""


def function_block(source: str, function_name: str) -> str:
    match = re.search(
        rf"^func {re.escape(function_name)}\([^\n]*\)(?:\s*->\s*[^:]+)?:\n(.*?)(?=^func |\Z)",
        source,
        re.M | re.S,
    )
    return match.group(1) if match else ""


def main() -> int:
    project = read("project.godot")
    scene = read("main.tscn")
    runtime = read("scripts/core/habitat_live_action_runtime.gd")
    dashboard = read("scripts/ui/ultimate_dashboard_live_action.gd")
    stage = read("scripts/ui/bitling_habitat_stage.gd")
    overlay = read("scripts/ui/habitat_live_action_overlay.gd")
    test = read("tests/habitat_live_action_test.gd")

    check(
        'HabitatInteraction="*res://scripts/core/habitat_live_action_runtime.gd"' in project,
        "live action runtime is authoritative",
    )
    check(
        'path="res://scripts/ui/ultimate_dashboard_live_action.gd"' in scene,
        "main scene cannot fall back to card-first gameplay",
    )
    check(
        'extends "res://scripts/core/habitat_world_consequence_runtime.gd"' in runtime,
        "live action runtime preserves world, behavior and anti-grind consequences",
    )
    check(
        'extends "res://scripts/ui/ultimate_dashboard_consequences.gd"' in dashboard,
        "live dashboard preserves all persistent consequence surfaces",
    )

    phases_match = re.search(r"const LIVE_ACTION_PHASES[^=]*=\s*\[(.*?)\]", runtime)
    phases = re.findall(r'"([a-z_]+)"', phases_match.group(1)) if phases_match else []
    expected_phases = ["approach", "observe", "awaiting_choice", "perform", "aftermath"]
    check(phases == expected_phases, "five-phase action loop is canonical and ordered")

    duration_block = re.search(r"const PHASE_DURATIONS\s*:=\s*\{(.*?)\n\}", runtime, re.S)
    durations = dict(re.findall(r'"([a-z_]+)"\s*:\s*([0-9]+(?:\.[0-9]+)?)', duration_block.group(1))) if duration_block else {}
    check(set(durations) == set(expected_phases), "every live action phase has an explicit duration contract")
    check(float(durations.get("approach", 0.0)) > 0.0, "approach cannot be skipped")
    check(float(durations.get("observe", 0.0)) > 0.0, "observation cannot be skipped")
    check(float(durations.get("perform", 0.0)) > 0.0, "performance cannot be skipped")
    check(float(durations.get("aftermath", 0.0)) > 0.0, "aftermath cannot be skipped")
    check(float(durations.get("awaiting_choice", -1.0)) == 0.0, "player choice has no coercive countdown")

    start_block = function_block(runtime, "start_encounter")
    begin_block = function_block(runtime, "begin_choice_sequence")
    advance_block = function_block(runtime, "advance_live_action")
    complete_block = function_block(runtime, "_complete_perform_phase")
    process_block = function_block(runtime, "_process")

    check('"phase": "approach"' in start_block, "encounters always begin with an approach")
    check('str(live_action.get("phase", "")) != "awaiting_choice"' in begin_block, "choices are locked until observation completes")
    check("super.resolve_choice" not in begin_block, "selection cannot resolve rewards immediately")
    check('live_action["selected_choice"] = choice_id' in begin_block, "selection only locks the intended action")
    check('_set_live_phase("perform")' in begin_block, "selection starts visible performance")
    check('super.resolve_choice(choice_id)' in complete_block, "persistent outcome is committed only after performance")
    check('result["committed_after_performance"] = true' in complete_block, "deferred commit is published in the result contract")
    check('"perform":\n\t\t\t_complete_perform_phase()' in advance_block, "phase advancement owns the commit point")
    check('"aftermath":\n\t\t\t_finish_live_action()' in advance_block, "aftermath must complete before returning to idle")

    check("AUTO_INITIATIVE_INTERVAL := 24.0" in runtime, "Xogot has a deterministic autonomous initiative interval")
    check("trigger_autonomous_initiative()" in process_block, "idle time can trigger Xogot's own approach")
    check("randf" not in runtime and "randi" not in runtime, "live action timing contains no hidden randomness")
    check('"source": "xogot" if source == "xogot" else "player"' in runtime, "initiative ownership is explicit")
    check('data["completed_live_actions"]' in runtime, "completed visible actions are persisted")
    check('not exported.has("live_action")' in test, "runtime test protects transient-phase save hygiene")

    target_match = re.search(r"const LIVE_ACTION_WORLD_TARGETS\s*:=\s*\{(.*?)\n\}", stage, re.S)
    targets = set(re.findall(r'^\s*"([a-z_]+)"\s*:', target_match.group(1), re.M)) if target_match else set()
    hotspots = {"bitling", "window", "workbench", "plant", "platform", "sleep"}
    check(targets == hotspots, "all six canonical hotspots have physical movement targets")
    check("func _apply_live_action_motion" in stage, "stage owns Xogot root motion")
    check('_live_position = _live_position.lerp(_live_target' in stage, "Xogot physically travels toward room objects")
    check('_bitling.position = Vector3(_live_position.x' in stage, "live motion reaches the rendered character root")
    check("signal live_action_choice_pressed" in stage, "stage emits in-world choice activation")
    check("activate_live_action_choice" in stage, "stage tokens have a testable activation path")
    check("_live_action_choice_at(position)" in stage, "in-world choices are hit-tested before room hotspots")
    check('const HabitatLiveActionOverlay := preload("res://scripts/ui/habitat_live_action_overlay.gd")' in stage, "production stage owns the live action overlay")

    check("mouse_filter = Control.MOUSE_FILTER_IGNORE" in overlay, "live visual overlay cannot steal habitat input")
    check("func get_choice_regions" in overlay, "in-world tokens expose physical hit regions")
    check('str(snapshot.get("phase", "")) != "awaiting_choice"' in overlay, "choice tokens only exist at the decision phase")
    check("choice_tokens_visible" in overlay and "in_world_choice_surface" in overlay, "overlay publishes in-world choice diagnostics")
    check("WÄHLE IM RAUM" in overlay, "stage language identifies the physical decision surface")

    check('_moment_card.visible = false' in dashboard, "central moment card is hidden")
    check('_choice_card.visible = false' in dashboard, "central choice card is hidden")
    check('stage.connect("live_action_choice_pressed", stage_callback)' in dashboard, "stage choices reach the live runtime")
    check('service.call("begin_choice_sequence", choice_id)' in dashboard, "in-world choice uses the deferred sequence API")
    check('service.call("resolve_choice", choice_id)' not in dashboard, "live dashboard cannot bypass visible performance")
    check('service.call("start_encounter", hotspot_id, "player", true)' in dashboard, "room clicks start physical encounters")
    check("get_live_action_ui_snapshot" in dashboard, "live dashboard exposes a testable center-is-game contract")

    for phrase, message in (
        ("selection alone cannot commit the outcome", "runtime test protects deferred commit"),
        ("partial performance cannot commit the outcome", "runtime test protects the full performance window"),
        ("Xogot can initiate the loop without a player hotspot click", "runtime test proves autonomous initiative"),
        ("changing stance replaces the three physical approaches", "runtime test proves live lens rebinding"),
        ("Xogot visibly moves toward the selected room object", "runtime test proves physical movement"),
        ("phone presents decisions inside the stage", "runtime test protects phone in-world choices"),
        ("desktop cannot regress to card-first gameplay", "runtime test protects desktop stage-first gameplay"),
    ):
        check(phrase in test, message)

    if FAILURES:
        print(f"[LIVE-ACTION-ARCH] BLOCKED: {len(FAILURES)} of {ASSERTIONS} checks failed", file=sys.stderr)
        return 1
    print(f"[LIVE-ACTION-ARCH] PASS: {ASSERTIONS} checks")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
