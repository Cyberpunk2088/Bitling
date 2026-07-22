#!/usr/bin/env python3
"""Sabotage the stage-first loop and require the live-action gate to reject it."""

from __future__ import annotations

import shutil
import subprocess
import sys
import tempfile
from dataclasses import dataclass
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
GATE = Path("tools/habitat_live_action_gate.py")
PROTECTED_FILES = (
    Path("project.godot"),
    Path("main.tscn"),
    Path("scripts/core/habitat_live_action_runtime.gd"),
    Path("scripts/ui/ultimate_dashboard_live_action.gd"),
    Path("scripts/ui/bitling_habitat_stage.gd"),
    Path("scripts/ui/habitat_live_action_overlay.gd"),
    Path("tests/habitat_live_action_test.gd"),
    Path("tests/habitat_live_action_layout_test.gd"),
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
        "restore_world_runtime_without_live_loop",
        Path("project.godot"),
        'HabitatInteraction="*res://scripts/core/habitat_live_action_runtime.gd"',
        'HabitatInteraction="*res://scripts/core/habitat_world_consequence_runtime.gd"',
        "live action runtime is authoritative",
    ),
    Mutation(
        "restore_card_first_main_scene",
        Path("main.tscn"),
        'path="res://scripts/ui/ultimate_dashboard_live_action.gd"',
        'path="res://scripts/ui/ultimate_dashboard_consequences.gd"',
        "main scene cannot fall back to card-first gameplay",
    ),
    Mutation(
        "delete_observation_phase",
        Path("scripts/core/habitat_live_action_runtime.gd"),
        '["approach", "observe", "awaiting_choice", "perform", "aftermath"]',
        '["approach", "awaiting_choice", "perform", "aftermath"]',
        "five-phase action loop is canonical and ordered",
    ),
    Mutation(
        "skip_approach",
        Path("scripts/core/habitat_live_action_runtime.gd"),
        '"approach": 0.90,',
        '"approach": 0.0,',
        "approach cannot be skipped",
    ),
    Mutation(
        "skip_observation",
        Path("scripts/core/habitat_live_action_runtime.gd"),
        '"observe": 0.62,',
        '"observe": 0.0,',
        "observation cannot be skipped",
    ),
    Mutation(
        "resolve_on_selection",
        Path("scripts/core/habitat_live_action_runtime.gd"),
        'live_action["selected_choice"] = choice_id\n\t_set_live_phase("perform")',
        'live_action["selected_choice"] = choice_id\n\tsuper.resolve_choice(choice_id)',
        "selection cannot resolve rewards immediately",
    ),
    Mutation(
        "remove_autonomous_initiative",
        Path("scripts/core/habitat_live_action_runtime.gd"),
        "\t\t\ttrigger_autonomous_initiative()",
        "\t\t\tpass # Xogot never initiates",
        "idle time can trigger Xogot's own approach",
    ),
    Mutation(
        "randomize_live_action_timing",
        Path("scripts/core/habitat_live_action_runtime.gd"),
        "func trigger_autonomous_initiative() -> Dictionary:\n",
        "func trigger_autonomous_initiative() -> Dictionary:\n\tvar hidden_roll := randf()\n",
        "live action timing contains no hidden randomness",
    ),
    Mutation(
        "remove_sleep_movement_target",
        Path("scripts/ui/bitling_habitat_stage.gd"),
        '"sleep": Vector3(-2.35, -0.12, 0.78)',
        '"nap": Vector3(-2.35, -0.12, 0.78)',
        "all six canonical hotspots have physical movement targets",
    ),
    Mutation(
        "freeze_xogot_at_center",
        Path("scripts/ui/bitling_habitat_stage.gd"),
        "_live_position = _live_position.lerp(_live_target, clampf(blend, 0.0, 1.0))",
        "_live_position = LIVE_ACTION_WORLD_TARGETS[\"bitling\"]",
        "Xogot physically travels toward room objects",
    ),
    Mutation(
        "remove_in_world_choice_signal",
        Path("scripts/ui/bitling_habitat_stage.gd"),
        "signal live_action_choice_pressed(choice_id: String)",
        "signal deleted_live_action_choice_pressed(choice_id: String)",
        "stage emits in-world choice activation",
    ),
    Mutation(
        "live_overlay_steals_input",
        Path("scripts/ui/habitat_live_action_overlay.gd"),
        "mouse_filter = Control.MOUSE_FILTER_IGNORE",
        "mouse_filter = Control.MOUSE_FILTER_STOP",
        "live visual overlay cannot steal habitat input",
    ),
    Mutation(
        "break_tablet_row_threshold",
        Path("scripts/ui/habitat_live_action_overlay.gd"),
        "ROW_LAYOUT_MIN_WIDTH := 430.0",
        "ROW_LAYOUT_MIN_WIDTH := 900.0",
        "tablet row threshold protects medium-width stages",
    ),
    Mutation(
        "hide_choice_layout_diagnostics",
        Path("scripts/ui/habitat_live_action_overlay.gd"),
        '"choice_layout": _choice_layout(),',
        '"deleted_choice_layout": _choice_layout(),',
        "overlay publishes responsive choice-layout diagnostics",
    ),
    Mutation(
        "show_dashboard_choice_card",
        Path("scripts/ui/ultimate_dashboard_live_action.gd"),
        "_choice_card.visible = false",
        "_choice_card.visible = true",
        "central choice card is hidden",
    ),
    Mutation(
        "show_dashboard_moment_card",
        Path("scripts/ui/ultimate_dashboard_live_action.gd"),
        "_moment_card.visible = false",
        "_moment_card.visible = true",
        "central moment card is hidden",
    ),
    Mutation(
        "bypass_deferred_sequence_api",
        Path("scripts/ui/ultimate_dashboard_live_action.gd"),
        'service.call("begin_choice_sequence", choice_id)',
        'service.call("resolve_choice", choice_id)',
        "live dashboard cannot bypass visible performance",
    ),
    Mutation(
        "erase_phone_in_world_acceptance",
        Path("tests/habitat_live_action_test.gd"),
        "phone presents decisions inside the stage",
        "phone in-world decisions not checked",
        "runtime test protects phone in-world choices",
    ),
    Mutation(
        "erase_tablet_layout_acceptance",
        Path("tests/habitat_live_action_layout_test.gd"),
        "tablet reflows in-world choices into a horizontal row",
        "tablet row not checked",
        "layout test protects tablet readability",
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
    changed = original.replace(mutation.needle, mutation.replacement, 1)
    if changed == original:
        raise RuntimeError(f"{mutation.name}: mutation produced no change")
    target.write_text(changed, encoding="utf-8")


def main() -> int:
    failures: list[str] = []
    with tempfile.TemporaryDirectory(prefix="live-action-baseline-") as temp:
        fixture = Path(temp)
        copy_fixture(fixture)
        result = run_gate(fixture)
        if result.returncode != 0:
            print(result.stdout, file=sys.stderr)
            print("[LIVE-ACTION-MUTATION] FAIL: baseline rejected", file=sys.stderr)
            return 1
        print("[LIVE-ACTION-MUTATION] PASS: baseline accepted")

    for mutation in MUTATIONS:
        with tempfile.TemporaryDirectory(prefix=f"live-action-{mutation.name}-") as temp:
            fixture = Path(temp)
            copy_fixture(fixture)
            try:
                apply_mutation(fixture, mutation)
            except RuntimeError as error:
                failures.append(str(error))
                print(f"[LIVE-ACTION-MUTATION] FAIL: {error}", file=sys.stderr)
                continue
            result = run_gate(fixture)
            blocked = result.returncode != 0 and "[LIVE-ACTION-ARCH] BLOCKED:" in result.stdout
            specific = mutation.expected_failure in result.stdout
            if not blocked or not specific:
                failures.append(mutation.name)
                print(
                    f"[LIVE-ACTION-MUTATION] FAIL: {mutation.name} escaped or failed for the wrong reason\n{result.stdout}",
                    file=sys.stderr,
                )
                continue
            print(f"[LIVE-ACTION-MUTATION] PASS: rejected {mutation.name}")

    if failures:
        print(f"[LIVE-ACTION-MUTATION] BLOCKED: {len(failures)} checks failed", file=sys.stderr)
        return 1
    print(f"[LIVE-ACTION-MUTATION] PASS: baseline plus {len(MUTATIONS)} sabotage cases")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
