#!/usr/bin/env python3
"""Hard gate for persistent, playable consequences inside the habitat world."""

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
        print(f"[WORLD-ARCH] PASS: {message}")
    else:
        FAILURES.append(message)
        print(f"[WORLD-ARCH] FAIL: {message}", file=sys.stderr)


def read(relative: str) -> str:
    path = ROOT / relative
    check(path.is_file(), f"{relative} exists")
    return path.read_text(encoding="utf-8") if path.is_file() else ""


def const_block(source: str, name: str) -> str:
    match = re.search(rf"const {re.escape(name)}[^=]*:=\s*\{{(.*?)\n\}}", source, re.S)
    return match.group(1) if match else ""


def main() -> int:
    project = read("project.godot")
    scene = read("main.tscn")
    runtime = read("scripts/core/habitat_world_consequence_runtime.gd")
    dashboard = read("scripts/ui/ultimate_dashboard_consequences.gd")
    stage = read("scripts/ui/bitling_habitat_stage.gd")
    overlay = read("scripts/ui/habitat_world_consequence_overlay.gd")
    test = read("tests/habitat_world_consequence_test.gd")

    check(
        'HabitatInteraction="*res://scripts/core/habitat_world_consequence_runtime.gd"' in project,
        "world consequence runtime is authoritative",
    )
    check(
        'path="res://scripts/ui/ultimate_dashboard_consequences.gd"' in scene,
        "main scene cannot hide world consequences",
    )
    check(
        'extends "res://scripts/core/habitat_behavior_runtime.gd"' in runtime,
        "world runtime preserves habits, conflict and anti-grind behavior",
    )
    check(
        'extends "res://scripts/ui/ultimate_dashboard_behavior.gd"' in dashboard,
        "world dashboard preserves visible behavior and habitat gameplay",
    )

    manifestation_block = const_block(runtime, "CHOICE_MANIFESTATIONS")
    manifestations = set(re.findall(r'^\s*"([a-z_]+)":\s*\{"hotspot":', manifestation_block, re.M))
    expected = {
        "familiar_snack", "new_flavor", "let_choose", "follow_rule",
        "invent_together", "let_lead", "observe_first", "explain_connection",
        "ask_back", "check_in", "practical_help", "give_space", "dim_lights",
        "quiet_story", "dream_archive",
    }
    check(manifestations == expected, "all fifteen choices have explicit room manifestations")

    repair_block = const_block(runtime, "CONFLICT_REPAIR_AMOUNTS")
    repair_values = [float(value) for value in re.findall(r':\s*([0-9]+(?:\.[0-9]+)?)', repair_block)]
    check(len(repair_values) == 3 and all(value > 0.0 for value in repair_values), "playing through conflict changes its mechanics")

    for token, message in (
        ("var world_marks: Dictionary", "persistent room marks exist"),
        ("var pending_world_events: Array[Dictionary]", "unresolved follow-up events exist"),
        ("var resolved_world_events: Array[Dictionary]", "resolved world history exists"),
        ("func get_current_moment", "world events can become the active habitat moment"),
        ("func refresh_moment", "world events take precedence over random rotation"),
        ("func _generate_habit_manifestation", "formed habits create room changes"),
        ("func _generate_conflict_follow_up", "conflict returns as a playable follow-up"),
        ("var conflict: Dictionary = _active_conflict()", "conflict follow-ups use repaired current state"),
        ("func _resolve_world_event", "follow-up events require a player response"),
        ('"world_event": true', "world moments declare their origin"),
        ('"no_correct_answer": true', "world consequences preserve open-ended agency"),
        ('data["world_marks"]', "room marks are persisted"),
        ('data["pending_world_events"]', "open follow-ups are persisted"),
        ('data["resolved_world_events"]', "resolved follow-ups are persisted"),
        ("generated_habit_events[choice_id] = true", "formed habits cannot spam duplicate manifestations"),
        ("if choice_id.is_empty() or generated_habit_events.has(choice_id):", "duplicate manifestations are rejected before creation"),
        ("if tier <= int(conflict_tiers.get(axis, 0)):", "conflict follow-ups are threshold-gated"),
        ("pending_world_events.append(event)", "world consequences enter a playable queue"),
        ("pending_world_events.pop_front()", "played consequences leave the active queue"),
    ):
        check(token in runtime, message)

    check("randf" not in runtime and "randi" not in runtime, "world consequences contain no hidden random refusal")
    check("recommended_lens" not in runtime, "world events cannot restore a correct-answer lens")
    check("WorldConsequenceCard" in dashboard, "persistent world state has an in-product panel")
    check("world_consequences_changed" in dashboard, "dashboard follows authoritative world state")
    check("set_world_consequence_snapshot" in dashboard, "dashboard sends consequences into the playable stage")
    check("get_world_consequence_ui_snapshot" in dashboard, "world UI exposes a testable contract")

    check('const HabitatWorldConsequenceOverlay := preload("res://scripts/ui/habitat_world_consequence_overlay.gd")' in stage, "production stage owns the world consequence visual layer")
    check("HabitatWorldConsequenceOverlay.new()" in stage, "production stage instantiates the world consequence visual layer")
    check("set_world_consequence_snapshot" in stage, "stage accepts authoritative world snapshots")
    check("world_consequence_overlay_ready" in stage, "stage exposes world-layer diagnostics")
    check("mouse_filter = Control.MOUSE_FILTER_IGNORE" in overlay, "world visuals can never steal habitat input")
    check("world_marks_visible" in overlay, "overlay exposes rendered room-mark diagnostics")
    check("active_event_visible" in overlay, "overlay exposes active follow-up diagnostics")

    for phrase, message in (
        ("formed novelty habit changes the physical window zone", "runtime test proves physical habit manifestation"),
        ("formed habit returns as Xogot's initiative", "runtime test proves autonomous follow-up"),
        ("reinforcement visibly upgrades the room mark", "runtime test proves persistent room evolution"),
        ("conflict returns as gameplay instead of remaining a hidden meter", "runtime test proves playable conflict"),
        ("living through the event mechanically changes conflict", "runtime test proves mechanical conflict resolution"),
        ("repaired conflict does not requeue from a stale result snapshot", "runtime test rejects stale conflict requeue"),
        ("room marks survive import", "runtime test proves world persistence"),
        ("persistent room change is rendered on the stage", "runtime test proves in-world visualization"),
    ):
        check(phrase in test, message)

    if FAILURES:
        print(f"[WORLD-ARCH] BLOCKED: {len(FAILURES)} of {ASSERTIONS} checks failed", file=sys.stderr)
        return 1
    print(f"[WORLD-ARCH] PASS: {ASSERTIONS} checks")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
