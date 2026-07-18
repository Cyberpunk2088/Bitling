# BITLING Social Life Architecture

## Product intent

BITLING social sessions let two fictional companions exchange semantic messages, react to one another, learn bounded insights and—after mutual owner consent and mature development—create a resonance egg.

The system simulates emotions and empathy. It does not claim consciousness or genuine subjective feeling.

## Core services

| Service | Responsibility |
| --- | --- |
| `BitlingIdentity` | Persistent passport, Bitling ID, birth record, generation, body metrics, portrait reference and fictional Cognitive Index. |
| `EmotionModel` | Bounded simulated affect, peer-emotion response and mood-derived voice modulation. |
| `BitlingLanguage` | Validated semantic packets plus original procedural gibberish rendering. |
| `MediaCapabilityService` | Read-only microphone, camera and transport capability checks. It never starts capture. |
| `SocialSessionService` | Pair-code handshake, per-channel consent, packet validation and bounded peer learning. |
| `LineageService` | Mature, mutually approved resonance pairing, inherited traits, eggs, incubation and hatchling records. |

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

Godot WebRTC classes are automatic in web exports, but native platforms normally require an external GDExtension. Xogot does not generally support native plugins. Therefore `MediaCapabilityService.native_video_transport_ready` remains false until a Xogot-supported implementation is proven on physical hardware.

No camera frames or microphone samples may be routed through the semantic packet API.

## Voice identity

BITLING uses an original procedural voice identity based on a persistent `voice_seed` and simulated emotion:

- pitch,
- speaking rate,
- brightness,
- wobble,
- breathiness.

The target is playful, clumsy and expressive—not an imitation of Minions or any other protected character voice.

## Feelings and character

Each Bitling has a stable personality and a changing affect state. Social input may influence it only within bounded limits. One peer cannot overwrite another Bitling's personality, memories, evolution or learning profile.

Supported simulated emotions include joy, curiosity, affection, surprise, pride, calm, confusion, embarrassment, worry, sadness and frustration.

## Identity card

The passport contains:

- local display name,
- permanent Bitling ID,
- birth timestamp and optional coarse birth label,
- generation and lineage,
- current development phase and form,
- height and weight,
- fictional BITLING Cognitive Index (BCI),
- local portrait reference.

BCI is a game progression statistic derived from learning mastery, curiosity and development level. It is not a human IQ score and must never be presented as a psychological diagnosis.

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
- network failure and reconnect behavior.
