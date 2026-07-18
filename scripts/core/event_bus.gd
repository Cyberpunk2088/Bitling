extends Node

## Central signal hub for gameplay systems.
## Keep payloads small and avoid putting game logic in this autoload.

signal interaction_completed(interaction_id: String, tags: Array[String])
signal need_changed(need_name: String, old_value: float, new_value: float)
signal xp_gained(amount: float, source: String)
signal level_changed(old_level: int, new_level: int)
signal streak_changed(old_value: int, new_value: int)
signal quest_progressed(quest_id: String, progress: int, target: int)
signal quest_completed(quest_id: String)
signal memory_created(memory: Dictionary)
signal save_completed(path: String)
signal save_failed(reason: String)
