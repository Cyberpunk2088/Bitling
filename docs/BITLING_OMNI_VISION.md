# BITLING OMNI – Product Vision

## Mission

BITLING is a persistent digital companion game that combines the emotional bond of a virtual pet with the retention loops of modern learning, collection and live-service games. The experience must remain understandable in seconds, rewarding in minutes and meaningful over months.

## Product pillars

1. **Emotional attachment** – The Bitling remembers important moments, reacts to the player and develops a recognizable personality.
2. **Daily momentum** – Short sessions, streaks, daily quests and forgiving recovery mechanics create a sustainable habit rather than punishment.
3. **Visible growth** – Levels, life phases, eras, cosmetics and evolving environments make progress immediately legible.
4. **Player agency** – Decisions influence mood, memories, traits, story flags and future interactions.
5. **Cross-platform by default** – Input, layout, performance and save systems are designed for mobile, desktop and web from the start.
6. **Ethical engagement** – No dark patterns, no pay-to-win pressure and no irreversible streak loss without recovery options.

## Reference-game lessons

### Duolingo
- Short, clear sessions
- Streak visibility and streak repair
- Immediate feedback
- Progress broken into small goals

### Tamagotchi and virtual-pet games
- Emotional responsibility
- Persistent needs and life stages
- Strong character identity
- Surprising reactions and events

### Pokémon
- Collection, discovery and attachment
- Clear progression milestones
- Memorable silhouettes and traits

### Animal Crossing
- Calm daily rhythm
- Personalization and long-term world building
- Returning characters and seasonal content

### Habitica
- Real-world actions translated into game progress
- Quests, rewards and social accountability

## Core loop

1. Open BITLING and receive an emotional status summary.
2. Complete one or more bite-sized interactions.
3. Improve needs, earn XP and advance a daily quest.
4. Trigger a reaction, memory, trait change or story event.
5. Receive a clear next goal and return incentive.

## Meta progression

- **Life phases:** Egg, Baby, Toddler, Child, Teen, Adult, Elder
- **Eras:** Terminal, Neural, Quantum
- **Long-term progression:** player level, total XP, bonds, traits, collections and story branches
- **Daily progression:** streak, daily quests, care actions and limited events

## Retention principles

- A session should produce value within 30 seconds.
- The player always sees the next meaningful action.
- Missed days cause recoverable setbacks, not destructive punishment.
- Rewards should introduce choices, expression or story—not only bigger numbers.
- Notifications must be opt-in, contextual and rate-limited.

## Responsive design requirements

- Support touch, mouse, keyboard and controller actions.
- Respect safe areas and device cutouts.
- Use scalable containers and anchors rather than fixed pixel layouts.
- Provide readable typography at small mobile widths.
- Keep primary actions reachable with one hand on phones.
- Allow reduced motion, muted audio and high-contrast presentation.

## Platform targets

- Godot 4 desktop builds
- Android and iOS
- Web export where supported by features
- Optional cloud synchronization behind a provider-independent interface

## Definition of quality

“100/100” is treated as a measurable target, not a claim. Every release should be checked against:

- gameplay clarity
- stability and data safety
- accessibility
- input coverage
- responsive layout
- performance budgets
- automated tests
- privacy and ethical engagement

## Initial implementation roadmap

### Foundation
- Consolidate persistent state into a versioned save model.
- Add a daily streak and recovery system.
- Add daily quest generation and completion tracking.
- Introduce a central event bus for loose coupling.
- Establish responsive UI and input conventions.

### Companion depth
- Trait evolution
- Memory importance and recall
- Mood transitions based on needs and interactions
- Branching story events

### Content and live operations
- Data-driven interactions and quests
- Seasonal content packs
- Analytics events with explicit privacy controls
- Localization-ready text resources

### Validation
- Unit tests for progression and save migrations
- Device-size UI checks
- Performance profiling on low-end mobile hardware
- Accessibility review before public release
