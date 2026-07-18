# BITLING OMNI – Technical Architecture

## Architecture goals

- Small, testable systems with explicit responsibilities
- Data-driven content instead of hard-coded scene logic
- Versioned, recoverable saves
- Responsive UI independent of device resolution
- Platform services hidden behind interfaces
- Signals/events for communication between gameplay systems

## Recommended autoloads

| Autoload | Responsibility |
|---|---|
| `EventBus` | Global gameplay and UI signals only |
| `GameState` | Persistent player and Bitling state |
| `TimeService` | Calendar-day calculations and offline elapsed time |
| `QuestService` | Daily quest generation and progress |
| `PlatformService` | Safe-area, platform and capability detection |
| `AudioService` | Music/SFX settings and playback |

Autoloads should not own scene presentation. Screens subscribe to state and events, render data and dispatch player intentions.

## Core state domains

### Companion
- life phase
- era
- mood
- needs
- personality traits
- bond level

### Progression
- level
- current XP
- lifetime XP
- unlocks
- achievements

### Daily engagement
- current streak
- longest streak
- last active local date
- available streak repairs
- daily quests
- daily reward status

### Narrative
- memories
- story flags
- completed events
- relationship choices

### Settings
- language
- audio levels
- reduced motion
- high contrast
- notification consent
- analytics consent

## Save format

Use JSON with a schema version and atomic replacement:

```json
{
  "schema_version": 1,
  "profile": {},
  "companion": {},
  "progression": {},
  "daily": {},
  "narrative": {},
  "settings": {}
}
```

Write to a temporary file first, then replace the primary save. Keep one backup. Each future schema change must include a migration function.

## Streak rules

- Same calendar day: no change.
- Next calendar day: increment streak.
- One or more missed days: offer recovery before resetting.
- Streak repair is explicit and limited; never consume it silently.
- Store a normalized local date string, not only elapsed seconds.
- Protect against clock rollback by retaining the latest accepted timestamp.

## Quest model

Each quest definition should be data-driven:

```gdscript
{
    "id": "care_once",
    "event": "care_action_completed",
    "target": 1,
    "xp": 25,
    "weight": 10,
    "minimum_phase": 1
}
```

Daily quest state stores `id`, `progress`, `target`, `completed` and `claimed`. Quest generation must be deterministic per profile and date so reopening the game does not reroll objectives.

## Responsive UI

- Build screens from `Control` containers.
- Use stretch mode `canvas_items` and an intentional base viewport.
- Test compact phone, tall phone, tablet, laptop and ultrawide ratios.
- Read display safe areas for mobile.
- Keep gameplay logic out of nodes that only render UI.
- Use focus neighbors and semantic actions for keyboard/controller navigation.

## Event contract examples

- `interaction_completed(interaction_id, tags)`
- `need_changed(need_name, old_value, new_value)`
- `xp_gained(amount, source)`
- `level_changed(old_level, new_level)`
- `streak_changed(old_value, new_value)`
- `quest_progressed(quest_id, progress, target)`
- `memory_created(memory)`

## Quality gates

Before merging a feature:

1. No save corruption after forced close during save.
2. No fixed-position primary UI that breaks at 360×640.
3. Full keyboard/controller path for every primary action.
4. No uncapped per-frame allocation in gameplay loops.
5. All player-facing strings ready for localization.
6. New progression rules covered by deterministic tests.
7. Privacy-sensitive telemetry disabled until consent.
