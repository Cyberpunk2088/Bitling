# BITLING Social Life Architecture

## Product intent

BITLING social sessions let two fictional companions exchange semantic messages, react to one another, compare interests, discuss ideas, learn bounded insights and—after mutual owner consent and mature development—create a resonance egg.

The system simulates emotions and empathy. It does not claim consciousness or genuine subjective feeling.

## Core services

| Service | Responsibility |
| --- | --- |
| `BitlingIdentity` | Persistent passport, Bitling ID, birth record, generation, body metrics, portrait reference and individual Bitling IQ. |
| `DevelopmentProfile` | Attributes, skills, abilities, Bronze–Platinum specializations, upbringing, autonomy, preferences, affinity and rarity. |
| `EmotionModel` | Bounded simulated affect, peer-emotion response and mood-derived voice modulation. |
| `BitlingLanguage` | Validated semantic packets plus original procedural fictional speech. |
| `LanguageBridge` | Human-language subtitles, locale fallback, peer translation and Bitling-language lessons. |
| `MediaCapabilityService` | Read-only microphone, camera and transport capability checks. It never starts capture. |
| `SocialSessionService` | Pair-code handshake, per-channel consent, packet validation and bounded peer learning. |
| `LineageService` | Mature, mutually approved resonance pairing, inherited traits, eggs, incubation and hatchling records. |

## Individual development

The IQ belongs to the Bitling itself. Initial variation derives from the persistent Bitling identity. Learning and teaching can develop it gradually. The value is never a measurement of the human player and must not be presented as a psychological assessment of the player.

Attributes, skills and specializations remain separate:

- attributes describe broad tendencies such as empathy, humor, discipline and creativity;
- skills describe practiced competence such as logic, language, teaching, debate or cooking;
- abilities are discrete capabilities unlocked by sufficient competence and upbringing;
- specializations progress from Bronze to Silver, Gold and Platinum through matching interactions.

Discipline, routine, independence, self-control and social confidence form a bounded autonomy score. Better upbringing improves autonomous self-care, hobby practice, study, self-entertainment and peer teaching. Autonomous behavior cannot grant itself social consent, activate media capture or bypass player safety controls.

## Preferences and affinity

Every Bitling has deterministic hobbies, favorite food, favorite topic and conversation style. Affinity combines preference overlap, attribute similarity and skill similarity. High affinity can establish a favorite Bitling.

Available social presentation modes include:

- short chat,
- jokes,
- discussion,
- structured debate,
- teaching,
- monologue.

The selected mode depends on skills, autonomy, personality and peer affinity. All modes remain bounded by age policy and the wellbeing guard.

## Consent model

Consent is separate for:

- semantic data,
- microphone/voice,
- front-camera video,
- egg creation.

Both devices must approve each channel. Consent and active session state are intentionally not persisted. Restarting the game closes the session and clears all permissions.

Camera, microphone and precise location are never activated automatically. Public passports omit local portrait paths and private notes. The birth label is a user-entered coarse label; it must never be silently filled from GPS.

## Network transport

The semantic protocol is transport-neutral. WebSocket is suitable for signaling and reliable social messages. Low-latency native voice/video requires an audited transport adapter.

Godot WebRTC classes are available directly in web exports, but native platforms normally require an external GDExtension. Xogot does not generally support arbitrary native plugins. Therefore `MediaCapabilityService.native_video_transport_ready` remains false until a Xogot-supported implementation is proven on physical hardware.

No camera frames or microphone samples may be routed through the semantic packet API.

## Voice and language identity

BITLING uses an original procedural voice identity based on a persistent `voice_seed` and simulated emotion:

- pitch,
- speaking rate,
- brightness,
- wobble,
- breathiness.

The target is playful, clumsy and expressive—not an imitation of Minions or any other named character voice.

The fictional Bitling language carries semantic intents and is translatable. A normal Bitling speaks its fictional language with localized subtitles. Legendary Bitlings may unlock human-language speech, translate another Bitling and teach Bitling-language vocabulary.

The locale system accepts normalized BCP-47-style identifiers and falls back to English when a translation is missing. This preserves gameplay meaning, but it does not replace professional localization, font coverage, right-to-left support, pluralization and cultural review.

## Age adaptation

The local profile can be configured for child, teen, adult or senior presentation. This controls vocabulary complexity, monologue length and sensitive-topic policy.

Age must be provided transparently by the player or guardian. It must not be inferred secretly from camera images, voice, purchasing behavior or gameplay performance.

## Feelings and character

Each Bitling has a stable personality and a changing affect state. Social input may influence it only within bounded limits. One peer cannot overwrite another Bitling's IQ, personality, memories, evolution, skills or learning profile.

Supported simulated emotions include joy, curiosity, affection, surprise, pride, calm, confusion, embarrassment, worry, sadness and frustration.

## Identity card

The passport contains:

- local display name,
- permanent Bitling ID,
- birth timestamp and optional coarse birth label,
- generation and lineage,
- current development phase and form,
- height and weight,
- individual Bitling IQ,
- rarity and visual presentation data through the development profile,
- local portrait reference.

The public passport excludes the local portrait path and private notes.

## Rarity

Rarity is deterministic per persistent identity:

- Common,
- Uncommon,
- Rare,
- Legendary.

Rare and Legendary profiles expose shimmer, glow, sparkle and hue-shift parameters for rendering. Legendary status can unlock translation-related capabilities, but it must not create automatic competitive dominance or a paid statistical advantage.

## Egg and lineage rules

Egg creation requires:

1. distinct Bitling IDs,
2. mature development phases,
3. sufficient relationship and trust,
4. a verified active social session,
5. explicit approval from both owners,
6. a cooldown after successful creation.

The egg combines both personality genomes with a small deterministic mutation and receives its own ID, generation and incubation state. The interaction is portrayed as a non-sexual resonance bond.

## Required device validation

Before enabling voice or video in a release build, verify on physical iPhone and iPad hardware:

- microphone permission denial and revocation,
- camera permission denial and revocation,
- front-camera selection,
- Bluetooth/headset routing,
- echo and feedback handling,
- speaker/microphone interruption handling,
- backgrounding and incoming-call behavior,
- thermal and battery impact,
- session termination on app restart,
- no capture before mutual consent,
- visible recording indicators,
- network failure and reconnect behavior,
- age-mode behavior and guardian controls,
- right-to-left and large-font layouts,
- translated subtitles and fictional-language lessons.
