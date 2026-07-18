# BITLING Privacy and Child-Safety Release Gate

This document is an engineering release gate, not a substitute for legal review or a final public privacy policy.

## Product classification decision

Before store submission, the publisher must choose and document one of these positions:

1. **General-audience companion game with a neutral age screen.** Child accounts receive restricted social features and adult-managed permissions.
2. **Children's-category product.** The entire app, SDK inventory, analytics, commerce, links and social features must meet the stricter children's-category requirements.

The release must not market itself as specifically "for children" while bypassing the corresponding store and privacy obligations.

## Mandatory safeguards for microphone, camera and social play

- Microphone, camera, discovery, passport sharing and egg creation default to disabled.
- Each capability requires a separate, specific and reversible consent.
- A permission granted to the operating system is not sufficient product consent.
- The active microphone/camera state is continuously visible.
- Capture stops immediately when the social session ends, the app backgrounds, consent is withdrawn or the relevant scene closes.
- No background recording, hidden recording or automatic upload is permitted.
- Camera frames and microphone samples must never enter the semantic Bitling packet channel.
- Social sessions must provide mute, block, leave and report controls before public availability.
- Child-mode social features require adult action before personal information, voice, images or free-form media can be exchanged.
- Stranger matching, anonymous open chat and unmoderated public rooms are prohibited for child mode.

## Data minimization

The public Bitling passport may contain only fictional companion data and a user-selected coarse birth label. It must not silently add:

- GPS coordinates,
- device identifiers,
- owner names,
- email addresses,
- contact-book data,
- raw face images,
- raw voice recordings.

Local portrait references remain private. Any future network portrait feature needs a separate retention, deletion and consent design.

## Account and deletion requirements

Before any cloud account or relay service is released, the product must provide:

- an in-app privacy policy entry,
- a publicly accessible privacy-policy page,
- a clear inventory of collected and shared data,
- retention periods,
- a revoke-consent flow,
- deletion of account and associated server data,
- a privacy contact,
- transport encryption,
- authentication and rate limiting,
- incident-response and abuse-reporting procedures.

Local-only builds must still disclose local storage, camera/microphone access and how to erase local data.

## Age-adaptive content

Age adaptation may change vocabulary, complexity and available topics. It must not secretly infer a user's age from their face, voice, contacts or behavior. Age configuration and adult controls must be transparent.

The app must avoid presenting the Bitling as genuinely conscious, medically diagnostic or a replacement for human relationships, education, therapy or emergency support.

## Required tests before release

### Permission tests

- First launch with every permission denied.
- Grant and revoke microphone permission while the app is running.
- Grant and revoke camera permission while the app is running.
- End a session during capture and confirm immediate shutdown.
- Background and foreground the app during capture.
- Interrupt audio with a call, alarm, Bluetooth route change and headphone removal.

### Child-safety tests

- Child mode cannot enable social media exchange without adult action.
- Child mode cannot expose open stranger chat.
- Personal-information exchange is blocked until the adult gate succeeds.
- Block/report/mute/leave controls remain reachable with screen readers and large text.
- No external links or purchases are reachable from child-facing screens without the selected store-compliant parental gate.

### Data tests

- Network inspection confirms no undisclosed data leaves the device.
- Logs contain no raw audio, images, tokens or precise location.
- Deletion removes server-side and local account-linked data.
- Backups and crash reports do not contain sensitive media.

## Release sign-off

The following roles must sign off before voice/video/social functionality is enabled in production:

- product owner,
- gameplay lead,
- privacy/legal reviewer,
- child-safety reviewer,
- security reviewer,
- accessibility reviewer,
- iOS device QA,
- Android device QA when Android is supported.
