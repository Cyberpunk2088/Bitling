# BITLING OMNI

BITLING OMNI is an original living-companion game for Xogot and Godot 4.6. The current `0.9.0` development build combines expressive 3D companionship, individual development, recoverable care, adaptive learning, exploration, explainable evolution, settlement growth, legacy systems, local-first persistence and consent-first social architecture.

## Repair review

The focused repair and its evidence, remaining defects, and Mac testing instructions are tracked in [`docs/REPAIR_REVIEW_20260927.md`](docs/REPAIR_REVIEW_20260927.md). This is a review build, not a store release.

## Product constitution

The complete production direction is defined by four binding documents:

- [`docs/LEGENDARY_GAME_ROADMAP.md`](docs/LEGENDARY_GAME_ROADMAP.md) — full milestone and dependency plan;
- [`docs/LEGENDARY_PRODUCTION_PILLARS.md`](docs/LEGENDARY_PRODUCTION_PILLARS.md) — fourteen art, gameplay, learning, safety and operations pillars;
- [`docs/LEGENDARY_DEFINITION_OF_DONE.md`](docs/LEGENDARY_DEFINITION_OF_DONE.md) — five-pass acceptance standard for every feature;
- [`production/legendary_roadmap.json`](production/legendary_roadmap.json) — machine-readable roadmap validated by CI.

The roadmap is part of the AAA development baseline. It cannot be removed or reduced below its milestone, pillar and release-blocker floors without failing the roadmap gate.

## Core experience

| Entry | What it actually does |
|---|---|
| HOME | returns to the interactive habitat |
| NAHRUNG / SPIEL / FRAGEN / NÄHE / RUHE | selects an attitude and starts a visible encounter; choose one of three approaches in the room |
| SPIELE | opens the three playable activities: memory patterns, invented signal words and rhythm |
| LERNABENTEUER | opens the learning-adventure catalog |
| RAUM GESTALTEN | opens the separate room customization screen |

Progress from habitat choices is committed after the character performs the chosen action. Selecting an attitude alone does not grant rewards. Signal words are fictional vocabulary, not a real-language course. In-game IQ is a character stat, not a psychological assessment of the player.

The UI reads authoritative gameplay services and does not own duplicate progression state.

## Partner-world systems

- developmental life seasons from hatchling to wise;
- recoverable care quality and care strain;
- upbringing-driven autonomous actions;
- technique observation, aptitude, mastery and inheritance;
- persistent settlement residents, ranks and facilities;
- six original multi-category evolution routes;
- voluntary legacy renewal with selected inheritance;
- responsive Partner World interface for phone, tablet and desktop.

## Production presentation

The runtime currently provides a tested Godot 3D fallback with a companion stage, cyberpunk room, lighting, responsive HUD, passport, needs, relationship and interaction feedback. Final authored content can replace the fallback through the production asset contract:

```text
assets/characters/bitling_omni/bitling_omni.glb
assets/characters/bitling_omni/material_profile.tres
assets/characters/bitling_omni/bitling_animations.res
assets/environments/neon_loft/neon_loft.glb
assets/environments/neon_loft/lighting_profile.tres
assets/ui/metafinal/metafinal_theme.tres
```

Missing final assets remain a release blocker. A safe fallback is not accepted as final AAA content.

## Core services

| System | Responsibility |
|---|---|
| `GameState` | progression, needs, mood, memories and atomic persistence |
| `CompanionBrain` | relationship, personality and autonomous intentions |
| `DevelopmentProfile` | IQ, attributes, skills, upbringing and specializations |
| `BitlingIdentity` | permanent ID, passport, form, height, weight and IQ |
| `AdaptiveLearning` | adaptive challenges and mastery |
| `ExplorationService` | expeditions and choice history |
| `PartnerWorld` | life seasons, care, techniques, settlement and legacy |
| `EvolutionMatrix` | explainable multi-category development forecasts |
| `DialogueDirector` | contextual authored dialogue and anti-repetition |
| `OmniAudio` | runtime-safe audio buses and feedback foundation |
| `ProductionQuality` | runtime FPS, frame-time, memory, draw-call and audio-latency budgets |
| `SocialSessionService` | pairing, consent and bounded peer learning |
| `LineageService` | resonance eggs, inheritance and hatchlings |
| `WellbeingGuard` | quiet hours, breaks and healthy engagement |

## Quality gates

GitHub Actions validates exact commits with Godot 4.6.3:

1. project, autoload, secret and Xogot architecture audits;
2. public-release and AAA development gates;
3. legendary roadmap structure;
4. resource import, parser checks and main-scene boot;
5. Windows, iOS/Xogot, Android, Web, Linux and macOS packs;
6. core, social, development, partner-world, migration, stress and fuzz regressions;
7. runtime performance degradation and recovery tests;
8. phone, tablet and desktop layout assertions;
9. six rendered Home and Partner World reference images.

A separate strict release workflow remains blocked until final character, environment, animation, UI, music, ambience, SFX, voice and localization packages satisfy the authored-content contract.

## Release boundary

Version `0.9.0` is a systemic development build. It is not a claim that the full game or final AAA art package is complete. Version 1.0 requires the milestones and exit gates in the legendary roadmap, external playtests, professional content production, real-device profiling, accessibility review, learning evaluation, privacy review and operational readiness.
