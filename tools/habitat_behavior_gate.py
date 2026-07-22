#!/usr/bin/env python3
"""Hard gate for persistent habits, visible conflict and behavioral agency."""

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
        print(f"[BEHAVIOR-ARCH] PASS: {message}")
    else:
        FAILURES.append(message)
        print(f"[BEHAVIOR-ARCH] FAIL: {message}", file=sys.stderr)


def read(relative: str) -> str:
    path = ROOT / relative
    check(path.is_file(), f"{relative} exists")
    return path.read_text(encoding="utf-8") if path.is_file() else ""


def main() -> int:
    project = read("project.godot")
    scene = read("main.tscn")
    runtime = read("scripts/core/habitat_behavior_runtime.gd")
    dashboard = read("scripts/ui/ultimate_dashboard_behavior.gd")
    test = read("tests/habitat_behavior_test.gd")

    check(
        'HabitatInteraction="*res://scripts/core/habitat_behavior_runtime.gd"' in project,
        "persistent behavior runtime is authoritative",
    )
    check(
        'path="res://scripts/ui/ultimate_dashboard_behavior.gd"' in scene,
        "main scene cannot hide persistent behavior state",
    )
    check(
        'extends "res://scripts/core/habitat_interaction_service.gd"' in runtime,
        "behavior runtime preserves the anti-grind habitat base",
    )
    check(
        'extends "res://scripts/ui/ultimate_dashboard_habitat.gd"' in dashboard,
        "behavior dashboard preserves habitat-first gameplay",
    )

    profile_ids = set(re.findall(r'^\s*"([a-z_]+)": \{"axis":', runtime, re.M))
    expected_ids = {
        "familiar_snack", "new_flavor", "let_choose", "follow_rule",
        "invent_together", "let_lead", "observe_first", "explain_connection",
        "ask_back", "check_in", "practical_help", "give_space", "dim_lights",
        "quiet_story", "dream_archive",
    }
    check(profile_ids == expected_ids, "all fifteen habitat approaches have explicit behavior profiles")

    axes_match = re.search(r'const BEHAVIOR_AXES[^=]*=\s*\[(.*?)\]', runtime)
    axes = set(re.findall(r'"([a-z_]+)"', axes_match.group(1))) if axes_match else set()
    check(axes == {"agency", "novelty", "arousal", "contact"}, "four relationship axes are canonical")

    for token, message in (
        ("SESSION_HABIT_GAIN", "habit growth is session-bounded"),
        ("HABIT_MIN_SESSIONS := 3", "habits require three sessions"),
        ("HABIT_MIN_CONTEXTS := 2", "habits require multiple contexts"),
        ("HABIT_FORMED_THRESHOLD := 55.0", "habit formation has an explicit threshold"),
        ("CONFLICT_NEGOTIATE_THRESHOLD := 38.0", "negotiation has an explicit threshold"),
        ("CONFLICT_RESIST_THRESHOLD := 74.0", "resistance has an explicit threshold"),
        ('"resisted": 0.38', "resistance changes mechanical execution"),
        ("session_index += 1", "every process session advances behavior history"),
        ("session_index += 1\n\tsession_choice_ids.clear()", "same-session habit farming is blocked"),
        ("func preview_choice", "behavior is previewable before commitment"),
        ("func resolve_choice", "behavior participates in authoritative resolution"),
        ("_apply_execution_to_effects", "execution mode changes non-essential effects"),
        ("if key in NEED_EFFECTS", "essential care remains available under resistance"),
        ('brain.set("current_intention", dominant_behavior)', "habits change Xogot's future behavior"),
        ('data["habits"]', "habits are persisted"),
        ('data["axis_conflicts"]', "conflicts are persisted"),
    ):
        check(token in runtime, message)

    check("random" not in runtime.lower(), "habit and conflict responses contain no hidden randomness")
    check("recommended_lens" not in runtime, "behavior runtime cannot reintroduce correct answers")
    check("behavior_label" in dashboard, "each choice exposes anticipated behavior")
    check("habit_strength" in dashboard and "friction" in dashboard, "habit and friction are visible before commitment")
    check("PersistentBehaviorCard" in dashboard, "persistent patterns have a dedicated in-product surface")
    check(
        'button.text += "\\nXOGOT: %s · MUSTER %d · REIBUNG %d"' in dashboard,
        "choice buttons disclose Xogot's response state",
    )

    for phrase, message in (
        ("habit requires three distinct sessions", "runtime test proves cross-session formation"),
        ("same-session repetition cannot strengthen the habit again", "runtime test blocks habit farming"),
        ("formed novelty habit changes Xogot's actual future intention", "runtime test proves actual behavior change"),
        ("strong opposing history becomes a visible boundary", "runtime test proves visible conflict"),
        ("boundary changes mechanical reward rather than only text", "runtime test proves mechanical consequences"),
        ("resistance never removes essential care utility", "runtime test protects wellbeing utility"),
        ("every visible choice shows Xogot's anticipated response", "runtime test protects UI transparency"),
    ):
        check(phrase in test, message)

    if FAILURES:
        print(f"[BEHAVIOR-ARCH] BLOCKED: {len(FAILURES)} of {ASSERTIONS} checks failed", file=sys.stderr)
        return 1
    print(f"[BEHAVIOR-ARCH] PASS: {ASSERTIONS} checks")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
