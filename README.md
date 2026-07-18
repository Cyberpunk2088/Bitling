# BITLING OMNI

BITLING OMNI is an original living-companion game for Xogot and Godot 4.4. The current branch contains a playable, responsive vertical slice focused on relationship, learning, exploration, branching evolution and local-first persistence.

## Product pillars

- **Living continuity:** needs, mood, memories, personality, autonomous intentions and contextual dialogue persist across sessions.
- **Meaningful short sessions:** care, rest, adaptive learning and three-stage expeditions produce visible consequences without compulsory grinding.
- **Branching development:** forms are unlocked through level, relationship, trust, learning mastery and personality—not play time alone.
- **Healthy engagement:** no shame messaging, no companion death during absence, capped offline changes, streak recovery and break reminders.
- **Xogot compatibility:** GDScript-only runtime, standard Godot Controls, mobile renderer and no required native extensions.
- **Local-first ownership:** versioned JSON saves, atomic replacement, backup recovery and deterministic systems.

## Playable systems

| System | Responsibility |
|---|---|
| `GameState` | Authoritative progression, needs, mood, memories and schema-7 persistence |
| `CompanionBrain` | Relationship, trust, familiarity, personality and autonomous intentions |
| `AdaptiveLearning` | Per-skill mastery rating and adaptive pattern challenges |
| `ExplorationService` | Deterministic three-stage Signal Expeditions and choice history |
| `EvolutionService` | Original branching forms driven by multi-system requirements |
| `VitalityService` | Gentle live need changes and capped offline simulation |
| `DialogueDirector` | Authored contextual reactions with anti-repeat history |
| `WellbeingGuard` | Quiet hours, notification limits, break prompts and copy validation |
| `StreakService` | Calendar streaks with non-punitive recovery |
| `QuestService` | Deterministic daily impulses and one-time reward claims |
| `PlatformService` | Viewport, safe-area, input and device-class information |
| `HapticService` | Centralized iOS/Android vibration patterns with desktop no-op |

## Player-facing vertical slice

The responsive home screen supports phone portrait, tablet and desktop layouts. Its primary actions are:

- **Pflegen:** improves needs and shapes empathy/trust.
- **Spielen:** opens a three-stage expedition with authored choices.
- **Lernen:** opens an adaptive Musterlabor challenge with explanatory feedback.
- **Ruhen:** restores energy and explicitly preserves progress during breaks.

Newly available forms are presented as optional choices. Contextual companion dialogue appears as a non-modal toast and avoids immediate repetition.

## Architecture

```text
project.godot
main.tscn
Bitling_Core.gd
scripts/
  core/
    adaptive_learning.gd
    companion_brain.gd
    dialogue_director.gd
    event_bus.gd
    evolution_service.gd
    exploration_service.gd
    game_state.gd
    platform_service.gd
    quest_service.gd
    streak_service.gd
    vitality_service.gd
    wellbeing_guard.gd
  platform/
    haptic_service.gd
  ui/
    dialogue_toast.gd
    evolution_overlay.gd
    exploration_overlay.gd
    learning_overlay.gd
tests/
  ci_smoke_test.gd
  experience_systems_test.gd
tools/
  project_integrity.py
```

Persistent data is owned by `GameState`; specialized services expose deterministic `export_state()` and `import_state()` contracts. UI code consumes domain methods and EventBus signals instead of duplicating profile state.

## Automated quality gates

GitHub Actions validates the exact branch commit with Godot 4.4.1:

1. repository integrity and all project/autoload paths;
2. rejection of C#, GDExtension and native library artifacts;
3. Godot resource import;
4. parser checks for both regression entrypoints;
5. headless main-scene boot;
6. core regression suite;
7. experience-layer regression suite;
8. diagnostic log upload on success or failure.

Any `SCRIPT ERROR` or Godot `ERROR:` line fails the pipeline even when the engine process returns exit code zero.

## Manual release gate

Automated CI cannot certify Xogot touch behavior, safe areas, rotation, VoiceOver, thermal behavior or real-device frame pacing. Complete `docs/XOGOT_MANUAL_TEST_MATRIX.md` on iPhone, iPad and desktop before promoting the draft PR or creating a release.

## Engineering rules

- No scene owns persistent profile data.
- All progression rewards pass through `GameState`.
- Missing a day never removes earned rewards.
- Offline simulation cannot reduce core needs below its safe floor.
- Core gameplay remains operable without drag-and-drop, audio or haptics.
- Reduced-motion mode bypasses decorative tweens.
- New save fields require a schema increment and regression coverage.
- Imported mechanics must receive an original BITLING purpose, presentation and terminology.
