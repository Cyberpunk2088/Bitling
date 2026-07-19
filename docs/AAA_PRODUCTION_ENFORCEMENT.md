# BITLING OMNI — AAA Production Enforcement

## Definition

`AAA` is treated as a production discipline, not a marketing label. A BITLING build may be called a production candidate only when engineering, authored content, visual presentation, audio, accessibility, platform exports and evidence all pass the same immutable commit.

The system deliberately separates two gates:

1. **Development gate** — mandatory on every branch and pull request. It protects architecture, minimum systemic depth, responsive captures, runtime budgets, tests and export integrity.
2. **Release gate** — mandatory for release tags and manual release approval. It additionally requires final authored character, room, animation, UI-theme, music, ambience, sound-effect, voice and localization packages.

A development build can remain playable with procedural fallbacks. A release candidate cannot pass while those fallbacks substitute for final authored content.

## Runtime budgets

The `ProductionQuality` autoload samples Godot performance monitors once per second and evaluates them against device-specific budgets.

| Metric | Mobile | Tablet | Desktop |
|---|---:|---:|---:|
| Minimum FPS | 50 | 55 | 58 |
| Maximum frame time | 22 ms | 19 ms | 17.5 ms |
| Static memory | 384 MiB | 640 MiB | 1024 MiB |
| Video memory | 512 MiB | 768 MiB | 1536 MiB |
| Scene-tree nodes | 2,500 | 4,000 | 6,500 |
| Objects | 6,000 | 9,000 | 14,000 |
| Draw calls | 900 | 1,400 | 2,200 |
| Orphan nodes | 0 | 0 | 0 |
| Audio latency | 160 ms | 140 ms | 120 ms |

One violation produces `WATCH`. Three consecutive degraded samples produce `RED`. Sustained healthy samples recover the state. The service keeps a bounded history and periodically writes a diagnostic JSON report.

These budgets are initial production constraints, not proof of device-wide performance. Physical-device profiling remains required before release.

## Development gate

Every ordinary CI run blocks on:

- project and autoload integrity;
- minimum project version;
- bounded script size and consistent GDScript indentation;
- at least six Godot regression suites;
- at least sixty authored dialogue cores;
- at least six evolution routes;
- at least six partner techniques;
- five primary actions and five audio buses;
- a fourteen-animation character contract;
- six responsive visual captures;
- runtime budget success, degradation and recovery tests;
- Godot import, main-scene boot and six platform export packs;
- existing save, migration, stress, social, localization and visual regressions.

## Strict release gate

The workflow `.github/workflows/aaa-release-gate.yml` runs for version tags and manual release approval. It stops before building artifacts unless all release assets and content floors exist.

### Required authored package

- final Bitling GLB;
- final character material profile;
- final animation library;
- final Neon Loft GLB;
- final lighting profile;
- final UI theme;
- authored Home and Partner World music;
- authored Neon Loft and Signal Settlement ambience.

### Minimum release content

- three music tracks;
- three ambience loops;
- fifteen sound effects;
- twenty voice files;
- two supported localization resources.

These are floors, not ideal totals. Passing them does not replace art direction, mix review, animation review or external playtesting.

## Current status

The systemic 0.5.0 build can satisfy the development contract after the new gate passes CI. The strict release gate is intentionally expected to remain blocked until the authored production package is committed.

This prevents the following false positives:

- a procedural sound generator being treated as a final soundtrack;
- a generated 3D fallback being treated as the final character;
- six screenshots being treated as professional art review;
- successful export packs being treated as device certification;
- automated tests being treated as evidence of commercial quality;
- an internal version number being treated as an AAA release.

## Required production order

1. Final character model, topology, materials and scalable LODs.
2. Full facial, ear, tail, body and interaction rig.
3. Authored animation set with transition review.
4. Final environment kit and lighting profiles.
5. Authored score, ambience, Foley, UI and creature vocal package.
6. Expanded gameplay spaces, minigames, expedition encounters and settlement activities.
7. Accessibility, localization and physical-device profiling.
8. Closed playtest, telemetry review and balancing.
9. External art, audio, UX and release-candidate review.
10. Strict release-gate approval on the exact shipping commit.

No branch may remove or lower these thresholds without a documented production review and replacement evidence.
