# BITLING OMNI Visual Vertical Slice Report

## Target

Transform the previous functional dashboard into a recognizable premium living-companion game across phone, tablet and laptop while preserving the tested domain systems and Xogot portability.

## Delivered in version 0.2.0

### Living companion presentation

- procedural Bitling body with ears, tail, limbs, eyes and facial expressions;
- breathing/bobbing idle motion;
- timed blinking;
- pointer and touch eye tracking;
- squash/reaction animation after interaction;
- mood-dependent mouth presentation;
- rarity-dependent shimmer and sparkles;
- live name, phase, form and rarity badges.

### Cyberpunk living space

- animated neon skyline;
- moon, building lights and ambient sparkles;
- desk, monitor and plant silhouettes;
- perspective floor grid;
- rotating signal platform;
- cyan, violet and magenta lighting language.

### Responsive product composition

#### Phone

- companion and room shown first;
- five large thumb-friendly actions;
- bottom navigation;
- vertical status and quest flow;
- safe-area-aware margins;
- touch scrolling without a dominant technical scrollbar.

#### Tablet

- two-column composition;
- companion retained as the primary visual anchor;
- statistics and quest cards remain readable without desktop density.

#### Laptop/Desktop

- statistics and needs in the left column;
- companion stage and actions in the center;
- quests, event and social readiness in the right column;
- desktop navigation in the header;
- viewport-filling panel heights.

## Live gameplay wiring

The visible actions call the authoritative existing systems:

- `FÜTTERN` updates satiation, happiness, health, XP and quest progress;
- `SPIELEN` updates the companion and opens the Signal Expedition overlay;
- `LERNEN` updates curiosity and opens the adaptive learning overlay;
- `PFLEGEN` updates health, happiness, trust and care progression;
- `SCHLAFEN` restores energy and reinforces wellbeing behavior.

The dashboard reads live values for level, XP, streak, needs, mood, intention, relationship and daily quests. It does not maintain duplicate gameplay state.

## Xogot/Godot target

- project baseline: Godot 4.6 / Xogot;
- tested CI runtime: Godot 4.6.3;
- GDScript only;
- standard Godot Controls and Canvas drawing;
- Mobile renderer;
- no required native extension;
- camera capability probing remains passive and consent-first;
- project and export version: `0.2.0`.

## Automated evidence

The authoritative CI gate checks:

1. repository and autoload integrity;
2. release-readiness static analysis;
3. Godot 4.6.3 resource import;
4. parser validation for all test entrypoints;
5. premium main-scene boot;
6. resource-pack exports for Windows, iOS/Xogot, Android, Web, Linux and macOS;
7. core regression suite;
8. experience/social suite;
9. development/localization suite;
10. release stress/migration/fuzz suite;
11. phone, tablet and laptop layout suite;
12. strict engine-error log inspection.

A separate Godot 4.6.3 visual workflow renders PNG references at:

- `390 × 844` phone;
- `900 × 1200` tablet;
- `1440 × 900` laptop.

## Mobile performance safeguards

The procedural stage is not allowed to redraw at an uncontrolled display rate. A dedicated frame-budget service:

- limits active decorative redraws to 30 Hz;
- reduces decorative updates further when reduced-motion mode is enabled;
- stops the stage timer when the application loses focus;
- leaves interaction input and gameplay state independent of the visual frame budget.

## Acceptance status

The vertical slice is accepted for integration when all of the following are true:

- Godot/Xogot 4.6 import succeeds;
- premium main scene boots without engine errors;
- all six platform resource packs are created;
- all domain and visual regression suites pass;
- automated phone, tablet and laptop captures are produced;
- the laptop capture uses a genuine three-column composition;
- the phone capture prioritizes the companion and exposes all five primary actions;
- no old standalone profile launcher overlaps the new header;
- no unsupported native runtime dependency is introduced.

## Remaining production work

This slice closes the gap in composition and product identity, but it is not final release art. High-value production work still includes:

- final character concept sheets and multiple body/evolution variants;
- skeletal or frame-based animation authored by an animator;
- final room illustrations, props, day/night variants and personalization;
- sound effects, music, emotional speech synthesis and mixing;
- complete iconography and font package;
- onboarding and tutorial presentation;
- full localization resources and native-language QA;
- physical iPhone/iPad performance, accessibility and battery testing;
- final privacy, signing, licensing and store materials.
