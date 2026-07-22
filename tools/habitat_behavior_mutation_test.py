#!/usr/bin/env python3
"""Attack every persistent-behavior invariant and require a specific rejection."""

from __future__ import annotations

import shutil
import subprocess
import sys
import tempfile
from dataclasses import dataclass
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
GATE = Path("tools/habitat_behavior_gate.py")
PROTECTED_FILES = (
    Path("project.godot"),
    Path("main.tscn"),
    Path("scripts/core/habitat_behavior_runtime.gd"),
    Path("scripts/core/habitat_world_consequence_runtime.gd"),
    Path("scripts/ui/ultimate_dashboard_behavior.gd"),
    Path("scripts/ui/ultimate_dashboard_consequences.gd"),
    Path("tests/habitat_behavior_test.gd"),
    GATE,
)


@dataclass(frozen=True)
class Mutation:
    name: str
    path: Path
    needle: str
    replacement: str
    expected_failure: str


MUTATIONS = (
    Mutation(
        "restore_stateless_runtime",
        Path("project.godot"),
        'HabitatInteraction="*res://scripts/core/habitat_world_consequence_runtime.gd"',
        'HabitatInteraction="*res://scripts/core/habitat_interaction_service.gd"',
        "persistent behavior runtime is authoritative",
    ),
    Mutation(
        "hide_behavior_dashboard",
        Path("main.tscn"),
        'path="res://scripts/ui/ultimate_dashboard_consequences.gd"',
        'path="res://scripts/ui/ultimate_dashboard_habitat.gd"',
        "main scene cannot hide persistent behavior state",
    ),
    Mutation(
        "break_world_behavior_inheritance",
        Path("scripts/core/habitat_world_consequence_runtime.gd"),
        'extends "res://scripts/core/habitat_behavior_runtime.gd"',
        'extends "res://scripts/core/habitat_interaction_service.gd"',
        "authoritative world runtime preserves persistent behavior",
    ),
    Mutation(
        "break_world_dashboard_behavior_inheritance",
        Path("scripts/ui/ultimate_dashboard_consequences.gd"),
        'extends "res://scripts/ui/ultimate_dashboard_behavior.gd"',
        'extends "res://scripts/ui/ultimate_dashboard_habitat.gd"',
        "production dashboard preserves visible behavior state",
    ),
    Mutation(
        "remove_cross_session_requirement",
        Path("scripts/core/habitat_behavior_runtime.gd"),
        "HABIT_MIN_SESSIONS := 3",
        "HABIT_MIN_SESSIONS := 1",
        "habits require three sessions",
    ),
    Mutation(
        "remove_context_requirement",
        Path("scripts/core/habitat_behavior_runtime.gd"),
        "HABIT_MIN_CONTEXTS := 2",
        "HABIT_MIN_CONTEXTS := 1",
        "habits require multiple contexts",
    ),
    Mutation(
        "make_resistance_cosmetic",
        Path("scripts/core/habitat_behavior_runtime.gd"),
        '"resisted": 0.38',
        '"resisted": 1.0',
        "resistance changes mechanical execution",
    ),
    Mutation(
        "allow_same_session_farming",
        Path("scripts/core/habitat_behavior_runtime.gd"),
        "session_index += 1\n\tsession_choice_ids.clear()",
        "session_index += 1\n\tpass # session history not cleared",
        "same-session habit farming is blocked",
    ),
    Mutation(
        "remove_need_preservation",
        Path("scripts/core/habitat_behavior_runtime.gd"),
        "if key in NEED_EFFECTS:\n\t\t\tcontinue",
        "if false:\n\t\t\tcontinue",
        "essential care remains available under resistance",
    ),
    Mutation(
        "stop_behavior_from_changing_intention",
        Path("scripts/core/habitat_behavior_runtime.gd"),
        'brain.set("current_intention", dominant_behavior)',
        'brain.set("current_intention", "observe")',
        "habits change Xogot's future behavior",
    ),
    Mutation(
        "hide_precommit_state",
        Path("scripts/ui/ultimate_dashboard_behavior.gd"),
        'button.text += "\\nXOGOT: %s · MUSTER %d · REIBUNG %d"',
        'button.tooltip_text = "hidden behavior" #',
        "choice buttons disclose Xogot's response state",
    ),
    Mutation(
        "reintroduce_hidden_randomness",
        Path("scripts/core/habitat_behavior_runtime.gd"),
        "func preview_choice(choice_id: String) -> Dictionary:",
        "func preview_choice(choice_id: String) -> Dictionary:\n\tvar random_roll := randf()",
        "habit and conflict responses contain no hidden randomness",
    ),
)


def copy_fixture(destination: Path) -> None:
    for relative in PROTECTED_FILES:
        source = ROOT / relative
        if not source.is_file():
            raise RuntimeError(f"missing protected file: {relative}")
        target = destination / relative
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(source, target)


def run_gate(fixture: Path) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        [sys.executable, str(fixture / GATE)],
        cwd=fixture,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        check=False,
        timeout=30,
    )


def apply_mutation(fixture: Path, mutation: Mutation) -> None:
    target = fixture / mutation.path
    original = target.read_text(encoding="utf-8")
    count = original.count(mutation.needle)
    if count != 1:
        raise RuntimeError(
            f"{mutation.name}: expected one target in {mutation.path}, found {count}"
        )
    target.write_text(original.replace(mutation.needle, mutation.replacement, 1), encoding="utf-8")


def main() -> int:
    failures: list[str] = []
    with tempfile.TemporaryDirectory(prefix="behavior-baseline-") as temp:
        fixture = Path(temp)
        copy_fixture(fixture)
        result = run_gate(fixture)
        if result.returncode != 0:
            print(result.stdout, file=sys.stderr)
            print("[BEHAVIOR-MUTATION] FAIL: baseline rejected", file=sys.stderr)
            return 1
        print("[BEHAVIOR-MUTATION] PASS: baseline accepted")

    for mutation in MUTATIONS:
        with tempfile.TemporaryDirectory(prefix=f"behavior-{mutation.name}-") as temp:
            fixture = Path(temp)
            copy_fixture(fixture)
            try:
                apply_mutation(fixture, mutation)
            except RuntimeError as error:
                failures.append(str(error))
                print(f"[BEHAVIOR-MUTATION] FAIL: {error}", file=sys.stderr)
                continue
            result = run_gate(fixture)
            blocked = result.returncode != 0 and "[BEHAVIOR-ARCH] BLOCKED:" in result.stdout
            specific = mutation.expected_failure in result.stdout
            if not blocked or not specific:
                failures.append(mutation.name)
                print(
                    f"[BEHAVIOR-MUTATION] FAIL: {mutation.name} escaped or was rejected for the wrong reason\n{result.stdout}",
                    file=sys.stderr,
                )
                continue
            print(f"[BEHAVIOR-MUTATION] PASS: rejected {mutation.name}")

    if failures:
        print(f"[BEHAVIOR-MUTATION] BLOCKED: {len(failures)} checks failed", file=sys.stderr)
        return 1
    print(f"[BEHAVIOR-MUTATION] PASS: baseline plus {len(MUTATIONS)} sabotage cases")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
