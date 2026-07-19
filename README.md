# BITLING OMNI

BITLING OMNI is an original living-companion game for Xogot and Godot 4.6. Version `0.3.0` establishes the METAFINAL 3D production baseline: a real-time 3D companion stage, cyberpunk living space, production HUD, responsive phone/tablet/desktop layouts, relationship development, adaptive learning, exploration, evolution, social foundations and local-first persistence.

## Visual production baseline

The previous canvas placeholder has been replaced by a `SubViewport`-based 3D presentation using standard Godot/Xogot nodes:

- modeled Bitling body, head, ears, eyes, paws, horns, tail and silhouette tufts;
- hero camera, blinking, eye tracking, idle motion, touch reactions and mood changes;
- rarity-driven lighting and shimmer;
- neon apartment with skyline, furniture, plants, holograms, floor grid and signal platform;
- filmic tonemapping, mobile-compatible glow and colored lighting;
- holographic passport with ID, phase, rarity, IQ, height and weight;
- vector neon action glyphs, radial trust meter and cinematic HUD treatment.

The same gameplay state is presented as:

- **Phone:** companion first, five large actions, compact status flow and bottom navigation.
- **Tablet:** two-column composition with the companion as visual anchor.
- **Desktop:** statistics left, 3D stage center, quests and social readiness right.

## Authored asset path

Final art can replace the tested procedural 3D fallback without changing gameplay code. The runtime automatically detects:

```text
assets/characters/bitling_omni/bitling_omni.glb
assets/characters/bitling_omni/material_profile.tres
assets/characters/bitling_omni/bitling_animations.res
assets/environments/neon_loft/neon_loft.glb
assets/environments/neon_loft/lighting_profile.tres
assets/ui/metafinal/metafinal_theme.tres
```

The rig contract expects these animations:

```text
idle, blink, look, happy, sad, tired, excited,
feed, play, learn, care, sleep, surprised, clumsy
```

Missing or invalid authored assets fall back safely to the in-engine 3D stage.

## Gameplay

| Action | Immediate effect | Long-term direction |
|---|---|---|
| `FÜTTERN` | restores satiation and happiness | food preferences and care history |
| `SPIELEN` | opens a Signal Expedition | exploration, coordination and humor |
| `LERNEN` | opens an adaptive pattern challenge | IQ, logic, curiosity and Researcher progression |
| `PFLEGEN` | improves health, happiness and trust | empathy, relationship and self-care |
| `SCHLAFEN` | restores energy | routine, wellbeing and self-control |

The dashboard reads authoritative values for level, XP, streak, needs, mood, intention, relationship, quests, identity, rarity and individual Bitling IQ. The UI does not own duplicate progression state.

## Core systems

| System | Responsibility |
|---|---|
| `GameState` | progression, needs, mood, memories and atomic persistence |
| `CompanionBrain` | relationship, trust, personality and autonomous intentions |
| `DevelopmentProfile` | IQ, attributes, skills, abilities, upbringing, preferences and Bronze–Platinum specializations |
| `BitlingIdentity` | permanent ID, passport, birth, form, height, weight and IQ |
| `AdaptiveLearning` | adaptive challenges and mastery |
| `ExplorationService` | Signal Expeditions and choice history |
| `EvolutionService` | original branching forms |
| `EmotionModel` | bounded simulated feelings |
| `BitlingLanguage` | validated semantic packets and fictional speech |
| `SocialSessionService` | pairing, consent and bounded peer learning |
| `LineageService` | resonance eggs, inheritance and hatchlings |
| `WellbeingGuard` | quiet hours, break prompts and healthy engagement |
| `ProductionBitlingStage3D` | character, room, camera, lighting and interaction presentation |
| `ProductionAssetCatalog` | GLB/PBR/rig contract and safe fallback |
| `MetafinalVisualDirector` | installs production graphics and action animation bridges |

## Architecture

```text
project.godot
main.tscn
scripts/
  core/
  social/
  platform/
  visual/production_asset_catalog.gd
  ui/
    ultimate_dashboard.gd
    production_bitling_stage_3d.gd
    production_bitling_stage_3d_v2.gd
    production_bitling_stage_3d_v3.gd
    metafinal_visual_director_v4.gd
    production_stage_identity_badge.gd
    neon_glyph.gd
    radial_status_meter.gd
    cinematic_edge_treatment.gd
tests/
  ci_smoke_test.gd
  experience_systems_test.gd
  development_profile_test.gd
  release_readiness_test.gd
  visual_layout_test.gd
```

## Quality gates

GitHub Actions validates the exact commit with Godot 4.6.3:

1. repository, autoload, secret and Xogot architecture audit;
2. resource import and parser checks;
3. production main-scene boot;
4. Windows, iOS/Xogot, Android, Web, Linux and macOS resource packs;
5. core, social, development, localization, migration, stress and fuzz regressions;
6. phone, tablet and desktop layout assertions;
7. explicit checks for the 3D SubViewport, holographic passport, vector glyphs, radial trust meter and authored animation contract;
8. strict failure on every script or engine error.

A separate workflow renders phone, tablet and laptop PNG references on every relevant commit.

## Release boundary

Version `0.3.0` is a tested 3D production baseline, not a claim that final AAA assets already exist. Exact concept-image fidelity still requires authored GLB character and room models, PBR textures, rigged animation, final VFX, sound, fonts and physical iPhone/iPad performance testing.
