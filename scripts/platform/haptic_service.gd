extends Node

## Centralized haptic patterns. Non-mobile platforms safely no-op.

const PATTERNS: Dictionary = {
	"tap": {"duration": 24, "amplitude": 0.25},
	"success": {"duration": 65, "amplitude": 0.55},
	"level": {"duration": 110, "amplitude": 0.75},
	"evolution": {"duration": 180, "amplitude": 0.9}
}

func _ready() -> void:
	var event_bus := get_node_or_null("/root/EventBus")
	if event_bus != null:
		event_bus.interaction_completed.connect(_on_interaction_completed)
		event_bus.level_changed.connect(_on_level_changed)
	var evolution := get_node_or_null("/root/EvolutionService")
	if evolution != null:
		evolution.evolved.connect(_on_evolved)

func pulse(pattern_id: String) -> bool:
	if not PATTERNS.has(pattern_id) or not _is_enabled():
		return false
	if OS.get_name() not in ["iOS", "Android"]:
		return false
	var pattern: Dictionary = PATTERNS[pattern_id]
	Input.vibrate_handheld(int(pattern.get("duration", 40)), float(pattern.get("amplitude", -1.0)))
	return true

func get_pattern(pattern_id: String) -> Dictionary:
	return PATTERNS.get(pattern_id, {}).duplicate(true)

func _is_enabled() -> bool:
	var state := get_node_or_null("/root/GameState")
	return state == null or bool(state.settings.get("haptics_enabled", true))

func _on_interaction_completed(_interaction_id: String, _tags: Array[String]) -> void:
	pulse("tap")

func _on_level_changed(_old_level: int, _new_level: int) -> void:
	pulse("level")

func _on_evolved(_old_form: String, _new_form: String) -> void:
	pulse("evolution")
