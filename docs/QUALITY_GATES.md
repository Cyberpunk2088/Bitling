# BITLING OMNI Quality Gates

BITLING is not considered release-ready because a feature exists. It is release-ready only when the relevant gates below pass with evidence.

## 1. Xogot and Godot compatibility

- Godot 4.4.x imports the repository without parser or resource errors.
- The main scene boots headlessly in CI.
- Gameplay code is GDScript-only.
- No required native GDExtension, C#, Swift, Rust or C++ plugin is introduced.
- Every interactive control works with touch and mouse; primary actions also work with keyboard/controller focus.
- Layouts remain usable at phone portrait, tablet landscape and desktop aspect ratios.

## 2. Architecture

- `GameState` remains the persistent source of truth.
- UI code calls domain methods instead of mutating unrelated state directly.
- Cross-system communication uses explicit methods or `EventBus` signals.
- New systems expose deterministic import/export state when persistence is required.
- Save schema changes increment `SAVE_SCHEMA_VERSION` and retain migration behavior.

## 3. Gameplay and companion behavior

- Every action has a clear player intention, state effect, feedback response and progression result.
- The companion reacts to history, personality and current state rather than repeating a fixed random line only.
- Evolution is influenced by more than accumulated play time.
- Failure states teach or redirect; they do not shame the player.
- Absence never deletes earned rewards, kills the companion or produces guilt copy.

## 4. Automated testing

The CI pipeline must pass:

1. project resource import;
2. GDScript parser gate;
3. headless main-scene boot;
4. deterministic core regression suite;
5. diagnostic log upload even on failure.

Core regression coverage must include:

- multi-level XP progression;
- streak continuation and non-punitive repair;
- deterministic daily quests and one-time rewards;
- companion personality and relationship persistence;
- notification quiet hours and manipulative-copy rejection;
- save/load roundtrip and story flags.

## 5. Performance budgets

Targets for the first production vertical slice:

- stable 60 FPS on a representative modern iPhone and iPad;
- no frame-time spike above 50 ms during normal companion interactions;
- no unbounded arrays, timers, tweens or signal connections;
- no save operation on every frame or repeated input event;
- mobile renderer remains the baseline until profiling proves another choice.

## 6. Accessibility

- readable UI at 200% font scale;
- minimum touch target of 44 logical points;
- no information conveyed by color alone;
- reduced-motion mode bypasses decorative tweens;
- text alternatives exist for icon-only controls;
- core gameplay is operable without precision drag gestures.

## 7. Ethical engagement

- no loot boxes, gambling simulation or pay-to-win progression;
- no false urgency, fake scarcity or punishment for breaks;
- notifications respect opt-out, quiet hours and daily frequency limits;
- break suggestions preserve progress and explicitly confirm that BITLING remains safe;
- monetization and analytics require separate review before implementation.

## 8. Release evidence

A release candidate requires:

- green CI on the exact release commit;
- manual Xogot run on iPhone and iPad;
- desktop run on macOS, Windows or Linux;
- save migration test from the previous public build;
- 30-minute soak test without errors or growing memory use;
- issue list contains no unresolved blocker or critical defect.
