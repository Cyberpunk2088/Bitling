# BITLING OMNI

BITLING OMNI is an original living-companion game for Xogot and Godot 4.6. Version `0.2.0` contains a responsive premium visual vertical slice with an animated Bitling, a procedural cyberpunk living space, relationship development, adaptive learning, exploration, branching evolution, social foundations and local-first persistence.

## Current visual slice

The home experience now uses the same live gameplay state in three purpose-built compositions:

- **Phone portrait:** companion stage first, large thumb actions, compact status flow and bottom navigation.
- **Tablet:** two-column dashboard with the companion kept visually dominant.
- **Laptop/desktop:** left statistics column, central living stage and right quest/social column.

The Bitling and room are currently rendered procedurally with standard Godot drawing APIs. This removes asset-loading risk during prototyping while providing breathing, blinking, eye tracking, touch reactions, mood faces, rarity sparkles, a neon skyline and an animated signal platform. Final production illustration, skeletal animation, audio and VFX can replace or extend this layer without changing the domain systems.

## Product pillars

- **Individual digital life:** every Bitling has its own identity, IQ, personality, attributes, skills, preferences, memories and development history.
- **Upbringing matters:** discipline, routine, independence and social confidence determine how effectively a Bitling can act without direct instructions.
- **Meaningful progression:** skills and specializations improve through matching activities rather than passive playtime.
- **Social compatibility:** hobbies, favorite food, conversation style, attributes and skills influence affinity and favorite-Bitling relationships.
- **Healthy engagement:** no shame messaging, no companion death during absence, capped offline changes, streak recovery and break reminders.
- **Xogot compatibility:** Godot 4.6, GDScript-only runtime, standard Controls/drawing APIs, mobile renderer and no required native extensions.
- **Local-first ownership:** versioned JSON saves, backups, deterministic simulation and explicit consent for social media channels.

## Visible gameplay loop

The main dashboard exposes five direct actions:

| Action | Immediate effect | Long-term direction |
|---|---|---|
| `FÜTTERN` | restores satiation and happiness | food preferences and care history |
| `SPIELEN` | opens a Signal Expedition | exploration, coordination and humor |
| `LERNEN` | opens an adaptive pattern challenge | IQ, logic, curiosity and Researcher progression |
| `PFLEGEN` | improves health, happiness and trust | empathy, relationship and self-care |
| `SCHLAFEN` | restores energy | routine, wellbeing and self-control |

The dashboard also displays level, XP, streak, needs, mood, intention, relationship, daily quests, a current event, social readiness, identity, phase and rarity.

## Implemented systems

| System | Responsibility |
|---|---|
| `GameState` | Core progression, needs, mood, memories and atomic profile persistence |
| `CompanionBrain` | Relationship, trust, familiarity, personality and autonomous intentions |
| `DevelopmentProfile` | Individual IQ, attributes, skills, abilities, upbringing, preferences, affinity, rarity and Bronze–Platinum specializations |
| `BitlingIdentity` | Passport, permanent ID, birth record, generation, form, height, weight and individual IQ projection |
| `AdaptiveLearning` | Per-skill mastery rating and adaptive pattern challenges |
| `ExplorationService` | Deterministic three-stage Signal Expeditions and choice history |
| `EvolutionService` | Original branching forms driven by multi-system requirements |
| `EmotionModel` | Bounded simulated feelings and social emotional responses |
| `BitlingLanguage` | Validated semantic packets and original procedural Bitling speech |
| `LanguageBridge` | Translatable intent layer, locale fallback and Bitling-language lessons |
| `SocialSessionService` | Pairing, per-channel consent and bounded peer learning |
| `LineageService` | Resonance eggs, inheritance, incubation and hatchling history |
| `VitalityService` | Gentle live need changes and capped offline simulation |
| `DialogueDirector` | Contextual reactions with anti-repeat history |
| `WellbeingGuard` | Quiet hours, notification limits, break prompts and copy validation |
| `ProfileOverlay` | Responsive passport and development display |
| `UltimateDashboard` | Phone/tablet/laptop composition and visible gameplay wiring |
| `BitlingStage` | Procedural creature, room, mood, rarity and touch animation |

## Development model

### Individual IQ

`intelligence_quotient` belongs to the Bitling. It is generated from that Bitling's persistent identity and can develop through sustained learning and teaching. It is never calculated from the human player's IQ, school performance or personal data.

### Attributes, skills and abilities

The profile tracks intelligence, empathy, humor, coordination, discipline, creativity, charisma, resilience and curiosity. Skills include logic, language, teaching, debate, humor, cooking, exploration, music, social interaction and self-care.

Abilities unlock from demonstrated competence and upbringing, including independent self-care, self-entertainment, peer teaching, structured debate, longer monologues, Bitling-language teaching and—only for legendary Bitlings—human-language speech and peer translation.

### Specializations

Every specialization begins at **Bronze** and advances through **Silver**, **Gold** and **Platinum**. Progress is activity-specific: teaching develops Mentor, discussion develops Orator, learning develops Researcher, care develops Caregiver and exploration develops Adventurer.

### Upbringing and autonomy

Discipline, routine, independence, self-control and social confidence feed a bounded autonomy score. Higher autonomy improves self-entertainment, self-care, study, hobby practice and teaching efficiency. It does not remove player control or allow unrestricted network actions.

### Preferences, relationships and rarity

Each Bitling receives deterministic hobbies, favorite food, favorite topic and conversation style. Similarity influences affinity. Repeated high-affinity encounters can establish a favorite Bitling.

Rarity is deterministic per identity: Common, Uncommon, Rare or Legendary. Rare profiles activate visual shimmer parameters. Legendary profiles can unlock human-language speech, peer translation and Bitling-language teaching. Rarity provides identity and presentation differences, not automatic pay-to-win dominance.

## Languages and age adaptation

The semantic intent layer preserves gameplay meaning independently from displayed language. German and English contain the complete current core set; additional starter translations cover major world languages. Unknown locales fall back to English instead of breaking gameplay.

This is an extensible localization architecture, not yet a claim that every production line has professional translation. A public release requires native review, fonts, right-to-left layout, plural rules, voice accessibility and cultural QA.

The player age band can be set to child, teen, adult or senior. It changes vocabulary complexity, monologue duration and sensitive-topic policy. Age adaptation remains transparent and never infers age secretly from camera, voice or behavior.

## Architecture

```text
project.godot                 Godot/Xogot 4.6 project baseline
main.tscn                     premium dashboard entry scene
scripts/
  core/                       state, progression, learning, evolution and wellbeing
  social/                     identity, emotion, language, sessions and lineage
  platform/                   haptic abstraction
  ui/
    ultimate_dashboard.gd     responsive phone/tablet/laptop dashboard
    bitling_stage.gd          procedural living-room and animated Bitling
    visual_layout_enhancer.gd viewport fill and scroll presentation
    stage_identity_badge.gd   live name, phase, form and rarity
    quest_localization_adapter.gd
    profile_launcher_guard.gd
    profile_overlay.gd
    learning_overlay.gd
    exploration_overlay.gd
    evolution_overlay.gd
tests/
  ci_smoke_test.gd
  experience_systems_test.gd
  development_profile_test.gd
  release_readiness_test.gd
  visual_layout_test.gd
tools/
  project_integrity.py
  release_readiness.py
  capture_visual.gd
```

## Automated quality gates

GitHub Actions validates the exact commit with Godot 4.6.3, matching the current Xogot runtime generation:

1. repository, autoload and Xogot architecture integrity;
2. secret and unsupported-runtime API audit;
3. public-release static audit;
4. resource import;
5. parser checks for all five regression entrypoints;
6. premium main-scene boot;
7. Windows, iOS/Xogot, Android, Web, Linux and macOS resource-pack exports;
8. core regressions;
9. experience and social regressions;
10. development and localization contracts;
11. release stress, migration and packet fuzzing;
12. responsive phone, tablet and laptop layout assertions;
13. strict failure on every `SCRIPT ERROR` or engine `ERROR:` line.

A separate visual workflow renders phone, tablet and laptop PNG references on every relevant commit. These images provide reviewable evidence of layout changes instead of relying exclusively on numeric assertions.

## Manual release gate

Automated CI cannot certify real Xogot touch behavior, safe areas, rotation, VoiceOver, thermal behavior, frame pacing, microphone routing or front-camera transport. Complete the physical iPhone/iPad matrix before store release.

## Engineering rules

- No scene owns authoritative domain state.
- Missing a day never removes earned rewards.
- Offline simulation cannot reduce core needs below its safe floor.
- Social sessions and consent do not persist across restarts.
- A peer cannot overwrite another Bitling's IQ, memories, personality or progression.
- Core gameplay remains operable without audio, video or haptics.
- Reduced-motion mode bypasses decorative motion.
- New save fields require migration and regression coverage.
- Every borrowed genre principle must receive an original BITLING purpose, presentation and terminology.
