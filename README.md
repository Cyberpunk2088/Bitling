# BITLING OMNI

BITLING OMNI is an original living-companion game for Xogot and Godot 4.4. The current branch contains a responsive vertical slice with relationship, learning, exploration, branching evolution, social communication and local-first persistence.

## Product pillars

- **Individual digital life:** every Bitling has its own identity, IQ, personality, attributes, skills, preferences, memories and development history.
- **Upbringing matters:** discipline, routine, independence and social confidence determine how effectively a Bitling can act without direct instructions.
- **Meaningful progression:** skills and specializations improve through matching activities rather than passive playtime.
- **Social compatibility:** hobbies, favorite food, conversation style, attributes and skills influence affinity and favorite-Bitling relationships.
- **Healthy engagement:** no shame messaging, no companion death during absence, capped offline changes, streak recovery and break reminders.
- **Xogot compatibility:** GDScript-only runtime, standard Godot Controls, mobile renderer and no required native extensions.
- **Local-first ownership:** versioned JSON saves, backups, deterministic simulation and explicit consent for social media channels.

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
| `ProfileOverlay` | Responsive passport and development display on phone, tablet and desktop |

## Development model

### Individual IQ

`intelligence_quotient` belongs to the Bitling. It is generated from that Bitling's persistent identity and can develop through sustained learning and teaching. It is never calculated from the human player's IQ, school performance or personal data.

### Attributes, skills and abilities

The profile currently tracks attributes such as intelligence, empathy, humor, coordination, discipline, creativity, charisma, resilience and curiosity. Skills include logic, language, teaching, debate, humor, cooking, exploration, music, social interaction and self-care.

Abilities unlock from demonstrated competence and upbringing, including independent self-care, self-entertainment, peer teaching, structured debate, longer monologues, Bitling-language teaching and—only for legendary Bitlings—human-language speech and peer translation.

### Specializations

Every specialization begins at **Bronze** and advances through **Silver**, **Gold** and **Platinum**. Progress is activity-specific: teaching develops Mentor, discussion develops Orator, learning develops Researcher, care develops Caregiver, exploration develops Adventurer, and tagged activities can develop Chef or Musician.

### Upbringing and autonomy

Discipline, routine, independence, self-control and social confidence feed a bounded autonomy score. Higher autonomy improves self-entertainment, self-care, study, hobby practice and teaching efficiency. It does not remove player control or allow unrestricted network actions.

### Preferences and relationships

Each Bitling receives deterministic hobbies, favorite food, favorite topic and conversation style. Similarity influences affinity. Repeated high-affinity encounters can establish a favorite Bitling. Conversation modes include chat, jokes, discussion, debate, teaching and monologue.

### Rarity

Rarity is deterministic per identity: Common, Uncommon, Rare or Legendary. Rare profiles provide visual shimmer parameters. Legendary profiles can unlock human-language speech, translate peer Bitling speech and teach the fictional language. Rarity provides identity and presentation differences, not automatic pay-to-win dominance.

## Languages and age adaptation

The semantic intent layer preserves gameplay meaning independently from displayed language. German and English contain the complete current core set; additional built-in starter translations cover Spanish, French, Italian, Portuguese, Polish, Turkish, Russian, Japanese, Korean, Chinese, Arabic and Hindi. Unknown locales fall back to English rather than breaking gameplay.

This is an extensible localization architecture, not yet a claim that every line has professional translation in every world language. A release requires native review, fonts, right-to-left layout, plural rules, voice accessibility and cultural QA for each supported locale.

The player age band can be set to child, teen, adult or senior. It changes vocabulary complexity, monologue duration and sensitive-topic policy. Age adaptation must remain transparent and must not infer age secretly from camera, voice or behavior.

## Player-facing vertical slice

The responsive home screen supports phone portrait, tablet and desktop layouts. Its primary actions are:

- **Pflegen:** improves needs and develops empathy, care and self-care.
- **Spielen:** opens a three-stage expedition and develops exploration, coordination and humor.
- **Lernen:** opens an adaptive pattern challenge and develops logic, curiosity and Researcher progression.
- **Ruhen:** restores energy and reinforces routine and self-control.
- **Ausweis:** opens the complete identity and development profile.

## Architecture

```text
project.godot
main.tscn
Bitling_Core.gd
scripts/
  core/
    adaptive_learning.gd
    companion_brain.gd
    development_profile.gd
    dialogue_director.gd
    evolution_service.gd
    exploration_service.gd
    game_state.gd
    vitality_service.gd
    wellbeing_guard.gd
  social/
    bitling_identity.gd
    bitling_language.gd
    emotion_model.gd
    language_bridge.gd
    lineage_service.gd
    media_capability_service.gd
    social_session_service.gd
  platform/
    haptic_service.gd
  ui/
    dialogue_toast.gd
    evolution_overlay.gd
    exploration_overlay.gd
    learning_overlay.gd
    profile_overlay.gd
tests/
  ci_smoke_test.gd
  experience_systems_test.gd
  development_profile_test.gd
tools/
  project_integrity.py
```

## Automated quality gates

GitHub Actions validates the exact branch commit with Godot 4.4.1:

1. repository integrity and all project/autoload paths;
2. rejection of C#, GDExtension and native library artifacts;
3. Godot resource import;
4. parser checks for all three regression entrypoints;
5. headless main-scene boot;
6. core regression suite;
7. experience/social regression suite;
8. development/localization regression suite;
9. diagnostic log upload on success or failure.

Any `SCRIPT ERROR` or Godot `ERROR:` line fails the pipeline even when the engine process returns exit code zero.

## Manual release gate

Automated CI cannot certify Xogot touch behavior, safe areas, rotation, VoiceOver, thermal behavior, real-device frame pacing, microphone routing or front-camera transport. Complete the device matrices on physical iPhone, iPad and desktop hardware before promoting the draft PR or creating a release.

## Engineering rules

- No scene owns authoritative domain state.
- Missing a day never removes earned rewards.
- Offline simulation cannot reduce core needs below its safe floor.
- Social sessions and consent do not persist across restarts.
- A peer cannot overwrite another Bitling's IQ, memories, personality or progression.
- Core gameplay remains operable without audio, video or haptics.
- Reduced-motion mode bypasses decorative tweens.
- New save fields require migration and regression coverage.
- Imported mechanics must receive an original BITLING purpose, presentation and terminology.
