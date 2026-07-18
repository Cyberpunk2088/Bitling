# Xogot Manual Test Matrix

Automated Godot CI is necessary but cannot replace physical-device validation. Record device model, OS version, Xogot version, commit SHA and result for every run.

## Required devices

| Class | Minimum coverage |
|---|---|
| iPhone compact | Narrow portrait display with safe-area inset |
| iPhone large | Modern large portrait display |
| iPad | Portrait and landscape |
| Desktop | Mouse and keyboard at 1280×720 and 1920×1080 |

## A. Project and boot

- Open the repository in Xogot without conversion errors.
- Confirm all autoloads resolve and no missing-resource dialog appears.
- Run from a clean install with no save file.
- Confirm first launch creates a save and hatches once only.
- Force-close and reopen; confirm level, needs, relationship, learning and form persist.
- Background the app for at least 10 minutes; confirm offline vitality changes are gentle and capped.

## B. Responsive layout

For each orientation and target size:

- no content sits behind notch, Dynamic Island or home indicator;
- no control overlaps another control;
- no horizontal clipping or unintended scroll;
- primary action buttons remain at least 44 logical points tall;
- companion, needs and current objective are readable without precision gestures;
- overlays fit entirely on screen and their close controls remain reachable;
- rotating an iPad while an overlay is open keeps the overlay usable.

## C. Input

- Touch: every button responds once per tap with no duplicate activation.
- Mouse: hover and click states are visible and correct.
- Keyboard/controller: focus can reach primary actions and answer choices.
- `ui_accept` activates the focused control rather than an unrelated action.
- Closing an overlay restores focus to the underlying action area.

## D. Gameplay loops

### Care

- increases intended needs only;
- relationship and empathy change gradually;
- no stat exceeds 100;
- repeated tapping does not freeze or duplicate signals.

### Learning

- opens the Musterlabor overlay;
- question, three answers and difficulty are visible;
- correct and incorrect answers both explain the pattern;
- mastery adapts across repeated attempts;
- a wrong answer never removes XP or existing progress;
- overlay closes cleanly and saves the result.

### Exploration

- opens a three-stage Signal Expedition;
- choices produce distinct feedback and state effects;
- all three stages complete without soft-lock;
- closing early does not corrupt the save;
- completed count and discoveries persist after restart.

### Evolution

- newly available forms appear as explicit choices;
- postponing evolution is allowed;
- selected form persists after restart;
- unavailable forms cannot be selected through focus or rapid input;
- evolution does not delete memories, skills or relationship state.

## E. Accessibility

- enable reduced motion and confirm idle/reaction tweens stop;
- increase system text size and verify critical labels remain readable;
- VoiceOver reads button labels and close-button tooltips meaningfully;
- status is not communicated by color alone;
- game remains playable without drag-and-drop;
- animations contain no rapid flashing.

## F. Performance and stability

Run a 30-minute soak test:

- target 60 FPS during normal interaction;
- no repeated frame-time spikes above 50 ms;
- no increasing count of orphaned overlays, timers or tweens;
- memory use stabilizes after repeated learning and exploration loops;
- save operations cause no visible multi-frame stall;
- device temperature remains reasonable under the mobile renderer.

## G. Exit criteria

A result is acceptable only when:

- no blocker or critical issue remains;
- all save/restart checks pass twice;
- all overlays are usable on compact iPhone and iPad landscape;
- CI is green on the exact tested commit;
- device findings are linked to an issue or recorded as passed with evidence.
