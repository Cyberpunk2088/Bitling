#!/usr/bin/env python3
"""Prove the habitat architecture gate fails under deliberate sabotage.

A gate that only passes the current tree is insufficient. This test creates
isolated copies of the protected architecture, injects one forbidden regression
at a time, and requires the gate to reject every mutation for the right reason.
"""

from __future__ import annotations

import shutil
import subprocess
import sys
import tempfile
from dataclasses import dataclass
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
GATE = Path("tools/habitat_architecture_gate.py")
PROTECTED_FILES = (
    Path("project.godot"),
    Path("main.tscn"),
    Path("scripts/core/habitat_interaction_service.gd"),
    Path("scripts/ui/ultimate_dashboard_habitat.gd"),
    Path("scripts/ui/bitling_habitat_stage.gd"),
    Path("scripts/ui/habitat_hotspot_overlay.gd"),
    Path("scripts/ui/metafinal_visual_director_v9.gd"),
    Path("tests/habitat_gameplay_test.gd"),
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
        "passive_dashboard_entrypoint",
        Path("main.tscn"),
        'path="res://scripts/ui/ultimate_dashboard_habitat.gd"',
        'path="res://scripts/ui/ultimate_dashboard.gd"',
        "main scene cannot fall back to the passive dashboard",
    ),
    Mutation(
        "remove_intent_lens",
        Path("scripts/core/habitat_interaction_service.gd"),
        '["feed", "play", "learn", "care", "rest"]',
        '["feed", "play", "learn", "care"]',
        "exactly five intentional lenses are enforced",
    ),
    Mutation(
        "delete_contextual_approach",
        Path("scripts/core/habitat_interaction_service.gd"),
        '_o("dream_archive"',
        '_deleted_option("dream_archive"',
        "fifteen contextual approaches exist",
    ),
    Mutation(
        "disconnect_sleep_hotspot",
        Path("scripts/ui/bitling_habitat_stage.gd"),
        '"sleep": Rect2',
        '"nap": Rect2',
        "sleep remains clickable in the central habitat",
    ),
    Mutation(
        "restore_direct_reward_button",
        Path("scripts/ui/ultimate_dashboard_habitat.gd"),
        "func _on_feed_pressed() -> void:\n\t_select_lens(\"feed\")",
        "func _on_feed_pressed() -> void:\n\t_run_interaction(\"feed\", {})",
        "habitat UI cannot directly grant stat rewards",
    ),
    Mutation(
        "bypass_authoritative_resolver",
        Path("scripts/ui/ultimate_dashboard_habitat.gd"),
        'service.call("resolve_choice", choice_id)',
        'service.call("perform_interaction", choice_id)',
        "all center choices pass through the authoritative resolver",
    ),
    Mutation(
        "downgrade_production_stage",
        Path("scripts/ui/bitling_habitat_stage.gd"),
        'extends "res://scripts/ui/production_bitling_stage_3d_v11.gd"',
        'extends "res://scripts/ui/bitling_stage.gd"',
        "habitat interaction is fused into the production 3D Living Home stage",
    ),
    Mutation(
        "visual_director_restores_passive_stage",
        Path("scripts/ui/metafinal_visual_director_v9.gd"),
        "_stage = ProductionHabitatStage.new()",
        "_stage = ProductionStage3DV11.new()",
        "visual director cannot silently restore a passive stage",
    ),
    Mutation(
        "hotspot_overlay_steals_input",
        Path("scripts/ui/habitat_hotspot_overlay.gd"),
        "mouse_filter = Control.MOUSE_FILTER_IGNORE",
        "mouse_filter = Control.MOUSE_FILTER_STOP",
        "hotspot markers can never steal stage input",
    ),
    Mutation(
        "erase_mobile_acceptance_guarantee",
        Path("tests/habitat_gameplay_test.gd"),
        "all contextual decisions remain available on phone",
        "phone decision availability not checked",
        "runtime test protects phone gameplay parity",
    ),
    Mutation(
        "reintroduce_correct_answer",
        Path("scripts/core/habitat_interaction_service.gd"),
        '"cues": ["Nähe", "Abstand", "Neugier"]',
        '"recommended_lens": "care"',
        "service cannot prescribe a correct lens",
    ),
    Mutation(
        "restore_repeat_farming",
        Path("scripts/core/habitat_interaction_service.gd"),
        "[1.0, 0.35, 0.0]",
        "[1.0, 1.0, 1.0]",
        "repeated choices lose XP and eventually reach zero",
    ),
)


def copy_fixture(destination: Path) -> None:
    for relative in PROTECTED_FILES:
        source = ROOT / relative
        if not source.is_file():
            raise RuntimeError(f"required protected file is missing: {relative}")
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
            f"{mutation.name}: expected exactly one mutation target in "
            f"{mutation.path}, found {count}"
        )
    changed = original.replace(mutation.needle, mutation.replacement, 1)
    if changed == original:
        raise RuntimeError(f"{mutation.name}: mutation produced no change")
    target.write_text(changed, encoding="utf-8")


def main() -> int:
    failures: list[str] = []

    with tempfile.TemporaryDirectory(prefix="habitat-gate-baseline-") as temp:
        baseline = Path(temp)
        copy_fixture(baseline)
        result = run_gate(baseline)
        if result.returncode != 0:
            print(result.stdout, file=sys.stderr)
            print("[HABITAT-MUTATION] FAIL: unmodified architecture does not pass", file=sys.stderr)
            return 1
        print("[HABITAT-MUTATION] PASS: unmodified architecture passes")

    for mutation in MUTATIONS:
        with tempfile.TemporaryDirectory(prefix=f"habitat-mutation-{mutation.name}-") as temp:
            fixture = Path(temp)
            copy_fixture(fixture)
            try:
                apply_mutation(fixture, mutation)
            except RuntimeError as error:
                failures.append(str(error))
                print(f"[HABITAT-MUTATION] FAIL: {error}", file=sys.stderr)
                continue

            result = run_gate(fixture)
            blocked = result.returncode != 0 and "[HABITAT-ARCH] BLOCKED:" in result.stdout
            specific = mutation.expected_failure in result.stdout
            if not blocked or not specific:
                failures.append(mutation.name)
                print(
                    f"[HABITAT-MUTATION] FAIL: {mutation.name} escaped or failed for an unrelated reason\n"
                    f"{result.stdout}",
                    file=sys.stderr,
                )
                continue
            print(f"[HABITAT-MUTATION] PASS: rejected {mutation.name}")

    if failures:
        print(
            f"[HABITAT-MUTATION] BLOCKED: {len(failures)} mutation checks failed",
            file=sys.stderr,
        )
        return 1

    print(f"[HABITAT-MUTATION] PASS: baseline plus {len(MUTATIONS)} sabotage cases")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
