# BITLING OMNI

BITLING OMNI is a cross-platform digital-companion game built with Godot 4.2+. The project combines long-term creature progression, short daily interactions, ethical retention mechanics, adaptive presentation, and local-first player data.

## Product pillars

- **Companion first:** the Bitling develops through phases, memories, moods, and player interactions.
- **Short meaningful sessions:** daily quests and small actions provide clear progress without forced grinding.
- **Ethical retention:** streak recovery, no shame messaging, no punitive reward removal, and no pay-to-win systems.
- **Cross-platform UI:** portrait-first 720×1280 reference layout with responsive scaling for mobile, tablet, desktop, and web.
- **Local-first persistence:** versioned JSON saves, atomic replacement, legacy migration, and backup recovery.
- **Data-driven systems:** quests, progression, events, and platform capabilities are separated from scene presentation.

## Implemented core

- `GameState` — progression, needs, mood, memories, versioned persistence, save migration, and backups.
- `EventBus` — decoupled gameplay and UI signals.
- `StreakService` — calendar-based streaks with one recovery charge and no automatic punishment.
- `QuestService` — deterministic daily quest generation and reward claiming.
- `PlatformService` — viewport, input, safe-area, and device-class information.

## Current architecture

```text
project.godot
main.tscn
Bitling_Core.gd
scripts/
  core/
    event_bus.gd
    game_state.gd
    platform_service.gd
    quest_service.gd
    streak_service.gd
```

The current `main.tscn` remains the boot scene while the OMNI services are introduced incrementally. New presentation scenes should consume the autoload services rather than duplicate game state.

## Next implementation slices

1. Responsive title and onboarding flow.
2. Companion home scene with needs, mood, and daily quest cards.
3. Accessible design-token/theme layer.
4. Minigame contract and first vertical slice.
5. Save/export tests and CI validation.
6. Audio, haptics, localization, notifications, and Guardian Protocol.

## Engineering rules

- No scene owns persistent profile data.
- All reward changes pass through `GameState`.
- Daily mechanics use calendar dates rather than raw 24-hour timers.
- Missing a day never removes earned rewards.
- Touch targets should remain at least 48 logical pixels.
- Features must remain usable with reduced motion and without audio or haptics.
