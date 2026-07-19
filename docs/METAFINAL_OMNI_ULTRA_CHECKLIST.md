# BITLING OMNI — METAFINALOMNIULTRABEST Quality Tree

This document is a living production gate for the next release. A feature is complete only after three passes: functional, experiential, and polish.

## P0 — Must work before visual expansion

### Audio foundation
- [ ] Audio buses: Master, Music, Ambience, Voice, SFX, UI
- [ ] Device-safe startup and mute handling
- [ ] Deterministic procedural placeholder sounds where authored audio is missing
- [ ] UI feedback for every primary action
- [ ] Mood-linked voice prosody contract
- [ ] Audio regression test and silent-device fallback

### Expression and animation
- [ ] Facial state model for eyes, pupils, eyelids, brows, mouth and head tilt
- [ ] Gesture state machine for idle, curious, happy, tired, sad, startled and clumsy
- [ ] Action reactions for feed, play, learn, care and sleep
- [ ] Anti-repetition scheduler
- [ ] Development-stage silhouette changes
- [ ] Reduced-motion fallback

### Dialogue quality
- [ ] Context matrix: mood × need × intention × relationship × time-of-day
- [ ] Large phrase banks per context
- [ ] Recency memory and cooldowns
- [ ] Personality-specific vocabulary
- [ ] Development-stage vocabulary
- [ ] Localization key architecture

## P1 — Core game feel

### Interaction loop
- [ ] Every action has anticipation, action, result and recovery phases
- [ ] Clear visual, audio and haptic feedback
- [ ] Meaningful short-term and long-term consequences
- [ ] Surprise events with bounded frequency
- [ ] No dead buttons or static cards

### Development
- [ ] Egg, baby, child, teen, adult, senior and legendary visual states
- [ ] Form and material changes tied to actual profile data
- [ ] Skill and specialization feedback
- [ ] Autonomy behavior visible in the room
- [ ] Persistent expression and preference history

### Atmosphere
- [ ] Time-of-day lighting
- [ ] Ambient room animation
- [ ] Layered foreground, midground and background motion
- [ ] Weather/event variants
- [ ] Camera easing and composition rules
- [ ] Performance profiles for phone, tablet and desktop

## P2 — Premium interface

- [ ] Hierarchy first: companion dominates, systems support
- [ ] Contextual panels instead of permanent dashboard overload
- [ ] Motion system for cards, overlays and navigation
- [ ] Icon consistency and touch targets
- [ ] Typography scale and localization resilience
- [ ] Accessibility: contrast, reduced motion, captions, scalable text, color-independent cues

## Three-pass acceptance loop

Every change must pass:

1. **Functional pass** — parser, boot, state wiring, persistence and platform safety.
2. **Experience pass** — visible feedback, understandable intent, no repetition fatigue, responsive layout.
3. **Polish pass** — timing, easing, audio mix, animation blending, visual hierarchy and edge cases.

## Release evidence

- Godot/Xogot import without errors
- Main-scene boot without errors
- Six platform resource packs
- Core, social, development, migration and fuzz suites
- Audio service tests
- Expression/animation tests
- Dialogue diversity tests
- Rendered phone, tablet and laptop references
- Physical Xogot device test matrix
