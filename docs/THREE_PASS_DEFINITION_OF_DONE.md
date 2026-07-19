# Three-pass definition of done

A feature is not accepted after one implementation pass.

## Pass 1 — Functional
- Parses and imports in Godot/Xogot 4.6.
- Uses authoritative game state.
- Handles missing assets and unavailable hardware safely.
- Has deterministic tests for state transitions and edge cases.

## Pass 2 — Experience
- Communicates player intent and result clearly.
- Produces coordinated visual, audio and motion feedback.
- Avoids repetitive dialogue and repetitive animation selection.
- Works in phone, tablet and desktop compositions.

## Pass 3 — Polish
- Timing, easing, blend durations and audio levels are tuned.
- Reduced-motion, captions, text scaling and color-independent cues work.
- Performance budgets and device-focus behavior are enforced.
- Visual captures and physical-device checks show no regression.
