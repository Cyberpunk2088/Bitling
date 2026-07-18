# BITLING Release Readiness Report

**Audit date:** 2026-07-18  
**Verified code commit:** `4ea36117cc47719a5d51f8fe937dc757aac678bf`  
**Verified workflow:** Godot Xogot CI run 183  
**Target engine:** Godot 4.4.1 / Xogot-compatible GDScript runtime

## Executive decision

The automated engineering gate is green. The project imports, parses, boots, exports platform-specific resource packs and passes all current regression and stress tests without strict Godot errors.

The game is **not approved for public store release yet**. Five explicit release blockers remain, along with physical-device, accessibility, content, legal and social-safety validation that cannot be certified by headless CI.

## Verified automated evidence

| Gate | Result |
| --- | --- |
| Repository and Xogot integrity | PASS |
| Secret and unsupported-runtime API scan | PASS |
| Godot resource import | PASS |
| Parser checks for four test entrypoints | PASS |
| Main scene headless boot | PASS |
| Windows resource-pack export | PASS |
| iOS/Xogot resource-pack export | PASS |
| Android resource-pack export | PASS |
| Web resource-pack export | PASS |
| Linux resource-pack export | PASS |
| macOS resource-pack export | PASS |
| Core regression suite | PASS — 61 assertions |
| Experience/social regression suite | PASS — 67 assertions |
| Development/localization contract suite | PASS — 31 assertions |
| Release stress/migration/fuzz suite | PASS — 456 assertions |
| Strict `SCRIPT ERROR` / `ERROR:` log scan | PASS |

**Total current assertions:** 615

The six export-pack checks validate resource packaging and preset recognition. They do not replace signed release builds with installed platform templates, credentials and store tooling.

## Hardening completed during this audit

- Added application and export version `0.1.0`.
- Replaced the placeholder bundle identifier with `com.cyberpunk2088.bitling`.
- Added Android, Web, Linux and macOS export presets.
- Excluded tests, tools, diagnostics, documents and recorder demos from production packs.
- Corrected an invalid packed-scene instance that blocked exports.
- Removed external process execution from the high-quality recorder; runtime video encoding now fails closed and uses an explicit handoff contract.
- Disabled global keep-screen-awake behavior.
- Changed notifications to opt-in by default.
- Preserved separate opt-in defaults for discovery, voice, video and passport sharing.
- Bumped the authoritative save schema to version 9.
- Included the individual Bitling development profile in the authoritative save.
- Added known-good backup preservation and corrupt-primary recovery.
- Added binary legacy `.dat` migration and current-JSON rewrite.
- Migrated hatchlings from the retired cognitive-index field to an inherited individual IQ.
- Added privacy and child-safety release criteria.
- Added static secret, Xogot API, export, metadata and localization audits.
- Added randomized state stress, save recovery, migration, packet fuzzing, autonomy and locale contract tests.

## Current static audit result

| Metric | Result |
| --- | ---: |
| Deterministic code/configuration errors | 0 |
| Public-release blockers | 5 |
| Architecture/content warnings | 24 |
| Runtime GDScript files | 38 |
| Open TODO/FIXME markers in runtime code | 0 |
| Detected forbidden Xogot runtime APIs | 0 |
| Recognized platform presets | 6 |
| Estimated strings still embedded in runtime code | 1,527 |
| Autoloads initialized at startup | 26 |
| Provisional release-readiness score | 25/100 |

The score is intentionally strict and measures release completeness, not only code correctness. Missing legal documents and production assets reduce it heavily even when tests are green.

## P0 — blockers before any public release

### 1. Production localization pipeline

There are no Godot translation resources or registered internationalization assets yet. The current `LanguageBridge` proves semantic fallback behavior but does not localize the complete UI and content library. Approximately 1,527 candidate strings remain embedded in runtime scripts.

Required completion:

- stable string IDs,
- CSV or gettext source files,
- Godot translation registration,
- full `tr()`/automatic-Control integration,
- plural and gender/context handling,
- right-to-left layout validation,
- CJK, Arabic, Devanagari and Cyrillic font coverage,
- native-speaker review,
- pseudolocalization and text-overflow tests.

### 2. Apple signing identity

`application/app_store_team_id` is empty. Resource packaging works, but a signed iOS/App Store build cannot be produced until the publisher supplies the final Apple Team ID and signing setup.

### 3. Production icon and store media

No production app icon is present. Final icon sets, screenshots, previews, store descriptions, age-rating answers and support URLs remain required.

### 4. License decision

The public repository has no explicit software/content license. The owner must choose the intended rights model for source code, artwork, audio, translations and community contributions. This is a publisher/legal decision and must not be guessed by automation.

### 5. Publishable privacy policy

The engineering child-safety gate exists, but no final public privacy policy is present. The final policy must match the actual production architecture, including any relay server, account system, analytics, crash reporting, moderation, retention and deletion behavior.

## P0 — release validation not automatable in this repository

- Complete the physical Xogot matrix on supported iPhones and iPads.
- Produce signed iOS, Android, Windows and macOS builds using installed templates and credentials.
- Test microphone permission grant, denial, revocation and interruption.
- Test camera permission grant, denial, revocation and visible capture state.
- Test Bluetooth, headphones, speaker routing, calls, alarms and backgrounding.
- Verify safe areas, rotation, large text, VoiceOver and keyboard/controller focus.
- Run thermal, battery, memory and frame-time sessions on low- and high-end devices.
- Complete moderation, report, block, mute, leave and adult-gate behavior before social media exchange is enabled.
- Validate account deletion and server-data deletion before any cloud account is released.
- Complete legal/privacy/child-safety review for the selected audience classification.

## P1 — technical optimization after P0 architecture is fixed

### Reduce startup coupling

Twenty-six autoloads initialize globally. Several UI overlays and specialized services should become scene-owned or lazy-loaded where lifecycle permits. Measure startup time and resident memory before and after restructuring; do not optimize solely by node count.

### Centralize content data

Dialogue, quests, learning prompts, hobbies, preferences and UI copy should move from GDScript constants into versioned content resources. This enables localization, balancing, content validation and safer live iteration.

### Add real performance budgets

Headless CI validates logic but not rendering performance. Establish device-tier budgets for:

- cold start,
- first interactive frame,
- frame time and frame pacing,
- memory and texture residency,
- save duration,
- network latency and reconnect,
- microphone/video CPU and thermal load,
- battery consumption over 30- and 60-minute sessions.

### Separate development recorder tooling

Recorder code is excluded from release packs. Consider moving all capture tooling into a dedicated development-only addon or separate project so production imports cannot regress because of tooling scenes.

## P2 — product-quality validation

- Onboarding comprehension tests with children, teenagers, adults and seniors.
- Longitudinal tests for autonomous behavior, repetition and emotional credibility.
- Difficulty and learning-value evaluation with qualified educational reviewers.
- Anti-manipulation review of streaks, notifications, absence behavior and monetization.
- Cultural review of humor, gestures, food, family, age and social-language content.
- Economy and progression simulations across short, medium and long play horizons.
- Save compatibility tests using anonymized real saves from every public version.
- Crash-free-session and supportability targets after telemetry architecture is legally approved.

## Release rule

The strict release gate must remain red until every P0 blocker has an owner, evidence and sign-off. A green CI run means the checked code is internally consistent; it does not mean the game is legally, operationally, artistically or commercially ready for the public.
