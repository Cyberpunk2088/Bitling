#!/usr/bin/env python3
"""Attack every world-consequence invariant and demand specific rejection."""

from __future__ import annotations

import shutil
import subprocess
import sys
import tempfile
from dataclasses import dataclass
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
GATE = Path("tools/habitat_world_consequence_gate.py")
PROTECTED_FILES = (
    Path("project.godot"),
    Path("main.tscn"),
    Path("scripts/core/habitat_world_consequence_runtime.gd"),
    Path("scripts/ui/ultimate_dashboard_consequences.gd"),
    Path("scripts/ui/bitling_habitat_stage.gd"),
    Path("scripts/ui/habitat_world_consequence_overlay.gd"),
    Path("tests/habitat_world_consequence_test.gd"),
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
        "restore_behavior_only_runtime",
        Path("project.godot"),
        'HabitatInteraction="*res://scripts/core/habitat_world_consequence_runtime.gd"',
        'HabitatInteraction="*res://scripts/core/habitat_behavior_runtime.gd"',
        "world consequence runtime is authoritative",
    ),
    Mutation(
        "hide_world_dashboard",
        Path("main.tscn"),
        'path="res://scripts/ui/ultimate_dashboard_consequences.gd"',
        'path="res://scripts/ui/ultimate_dashboard_behavior.gd"',
        "main scene cannot hide world consequences",
    ),
    Mutation(
        "remove_choice_manifestation",
        Path("scripts/core/habitat_world_consequence_runtime.gd"),
        '"dream_archive": {"hotspot":',
        '"deleted_dream_archive": {"deleted_hotspot":',
        "all fifteen choices have explicit room manifestations",
    ),
    Mutation(
        "make_world_events_cosmetic",
        Path("scripts/core/habitat_world_consequence_runtime.gd"),
        "func _resolve_world_event(event: Dictionary, result: Dictionary) -> void:",
        "func _discard_world_event(event: Dictionary, result: Dictionary) -> void:",
        "follow-up events require a player response",
    ),
    Mutation(
        "stop_conflict_repair",
        Path("scripts/core/habitat_world_consequence_runtime.gd"),
        '"embraced": 18.0,',
        '"embraced": 0.0,',
        "playing through conflict changes its mechanics",
    ),
    Mutation(
        "requeue_repaired_conflict_from_stale_snapshot",
        Path("scripts/core/habitat_world_consequence_runtime.gd"),
        "var conflict: Dictionary = _active_conflict()",
        'var conflict: Dictionary = result.get("active_conflict", {}) as Dictionary',
        "conflict follow-ups use repaired current state",
    ),
    Mutation(
        "remove_world_persistence",
        Path("scripts/core/habitat_world_consequence_runtime.gd"),
        'data["world_marks"] = world_marks.duplicate(true)',
        'pass # world marks not persisted',
        "room marks are persisted",
    ),
    Mutation(
        "allow_duplicate_manifestations",
        Path("scripts/core/habitat_world_consequence_runtime.gd"),
        "generated_habit_events[choice_id] = true",
        "pass # duplicates allowed",
        "formed habits cannot spam duplicate manifestations",
    ),
    Mutation(
        "remove_stage_world_layer",
        Path("scripts/ui/bitling_habitat_stage.gd"),
        "const HabitatWorldConsequenceOverlay := preload",
        "const DeletedWorldLayer := preload",
        "production stage owns the world consequence visual layer",
    ),
    Mutation(
        "world_overlay_steals_input",
        Path("scripts/ui/habitat_world_consequence_overlay.gd"),
        "mouse_filter = Control.MOUSE_FILTER_IGNORE",
        "mouse_filter = Control.MOUSE_FILTER_STOP",
        "world visuals can never steal habitat input",
    ),
    Mutation(
        "hide_world_state_panel",
        Path("scripts/ui/ultimate_dashboard_consequences.gd"),
        'card.name = "WorldConsequenceCard"',
        'card.name = "HiddenWorldState"',
        "persistent world state has an in-product panel",
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
        raise RuntimeError(f"{mutation.name}: expected one target in {mutation.path}, found {count}")
    target.write_text(original.replace(mutation.needle, mutation.replacement, 1), encoding="utf-8")


def main() -> int:
    failures: list[str] = []
    with tempfile.TemporaryDirectory(prefix="world-baseline-") as temp:
        fixture = Path(temp)
        copy_fixture(fixture)
        result = run_gate(fixture)
        if result.returncode != 0:
            print(result.stdout, file=sys.stderr)
            print("[WORLD-MUTATION] FAIL: baseline rejected", file=sys.stderr)
            return 1
        print("[WORLD-MUTATION] PASS: baseline accepted")

    for mutation in MUTATIONS:
        with tempfile.TemporaryDirectory(prefix=f"world-{mutation.name}-") as temp:
            fixture = Path(temp)
            copy_fixture(fixture)
            try:
                apply_mutation(fixture, mutation)
            except RuntimeError as error:
                failures.append(str(error))
                print(f"[WORLD-MUTATION] FAIL: {error}", file=sys.stderr)
                continue
            result = run_gate(fixture)
            blocked = result.returncode != 0 and "[WORLD-ARCH] BLOCKED:" in result.stdout
            specific = mutation.expected_failure in result.stdout
            if not blocked or not specific:
                failures.append(mutation.name)
                print(
                    f"[WORLD-MUTATION] FAIL: {mutation.name} escaped or failed for the wrong reason\n{result.stdout}",
                    file=sys.stderr,
                )
                continue
            print(f"[WORLD-MUTATION] PASS: rejected {mutation.name}")

    if failures:
        print(f"[WORLD-MUTATION] BLOCKED: {len(failures)} checks failed", file=sys.stderr)
        return 1
    print(f"[WORLD-MUTATION] PASS: baseline plus {len(MUTATIONS)} sabotage cases")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
