extends Node

## Persistent simulation for the Bitling's personal living space.
## The room is gameplay state: care, learning and rest visibly change it, while
## room condition feeds back into comfort, inspiration and recommended actions.

signal home_changed(snapshot: Dictionary)
signal object_interacted(object_id: String, result: Dictionary)
signal room_event(event: Dictionary)
signal decoration_changed(decoration_id: String, placed: bool)

const SCHEMA_VERSION := 1
const SAVE_PATH := "user://living_home.json"
const TEMP_PATH := "user://living_home.tmp"
const BACKUP_PATH := "user://living_home.backup.json"
const AUTOSAVE_INTERVAL := 45.0
const MAX_RECENT_EVENTS := 24
const MAX_DECORATIONS := 8

const THEMES: Dictionary = {
	"neon_nest": {"title": "Neon-Nest", "accent": "42e8ff", "secondary": "a855f7", "comfort": 2.0, "inspiration": 3.0},
	"botanical_lab": {"title": "Botanisches Labor", "accent": "64e6a2", "secondary": "42e8ff", "comfort": 4.0, "inspiration": 2.0},
	"star_archive": {"title": "Sternenarchiv", "accent": "ffc85a", "secondary": "b783ff", "comfort": 1.0, "inspiration": 5.0},
	"soft_signal": {"title": "Sanftes Signal", "accent": "ff7ac8", "secondary": "64e6a2", "comfort": 6.0, "inspiration": 0.0}
}

const OBJECT_CATALOG: Dictionary = {
	"sleep_pod": {"title": "Schlafkapsel", "max_level": 5, "stat": "comfort", "base_gain": 7.0, "xp": 12},
	"signal_kitchen": {"title": "Signalküche", "max_level": 5, "stat": "cleanliness", "base_gain": 5.0, "xp": 10},
	"learning_desk": {"title": "Lerntisch", "max_level": 5, "stat": "inspiration", "base_gain": 8.0, "xp": 14},
	"holo_projector": {"title": "Holoprojektor", "max_level": 5, "stat": "comfort", "base_gain": 4.0, "xp": 11},
	"memory_archive": {"title": "Erinnerungsarchiv", "max_level": 5, "stat": "inspiration", "base_gain": 6.0, "xp": 13},
	"garden_wall": {"title": "Gartenwand", "max_level": 5, "stat": "plant_health", "base_gain": 9.0, "xp": 12},
	"cleaning_drone": {"title": "Reinigungsdrohne", "max_level": 5, "stat": "cleanliness", "base_gain": 10.0, "xp": 9},
	"weather_window": {"title": "Wetterfenster", "max_level": 3, "stat": "power_stability", "base_gain": 3.0, "xp": 8}
}

const DECORATION_CATALOG: Dictionary = {
	"moon_lantern": {"title": "Mondlaterne", "comfort": 4.0, "inspiration": 1.0},
	"prism_mobile": {"title": "Prismen-Mobile", "comfort": 1.0, "inspiration": 4.0},
	"memory_ribbon": {"title": "Erinnerungsband", "comfort": 3.0, "inspiration": 3.0},
	"moss_cushion": {"title": "Mooskissen", "comfort": 5.0, "inspiration": 0.0},
	"star_map": {"title": "Sternenkarte", "comfort": 0.0, "inspiration": 6.0},
	"tiny_planet": {"title": "Kleiner Planet", "comfort": 2.0, "inspiration": 4.0},
	"friend_totem": {"title": "Freundschaftstotem", "comfort": 5.0, "inspiration": 2.0},
	"signal_chimes": {"title": "Signalglocken", "comfort": 3.0, "inspiration": 3.0},
	"aurora_rug": {"title": "Aurora-Teppich", "comfort": 6.0, "inspiration": 1.0},
	"archive_orb": {"title": "Archivkugel", "comfort": 1.0, "inspiration": 6.0}
}

var room_level := 1
var room_xp := 0
var cleanliness := 82.0
var comfort := 58.0
var inspiration := 54.0
var plant_health := 76.0
var power_stability := 94.0
var theme_id := "neon_nest"
var time_mode := "AUTO"
var weather_id := "CLEAR"
var object_levels: Dictionary = {}
var interaction_counts: Dictionary = {}
var decorations: Array[String] = []
var recent_events: Array[Dictionary] = []
var _autosave_elapsed := 0.0
var _last_decay_day := -1

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_initialize_defaults()
	load_state()
	_connect_runtime()
	set_process(true)
	_emit_changed()

func _process(delta: float) -> void:
	_autosave_elapsed += maxf(delta, 0.0)
	if _autosave_elapsed >= AUTOSAVE_INTERVAL:
		_autosave_elapsed = 0.0
		_apply_daily_decay_if_needed()
		save_state()

func interact_object(object_id: String) -> Dictionary:
	var normalized := object_id.strip_edges().to_lower()
	if not OBJECT_CATALOG.has(normalized):
		return {"accepted": false, "reason": "unknown_object", "object_id": normalized}
	var definition: Dictionary = OBJECT_CATALOG[normalized]
	var level := int(object_levels.get(normalized, 1))
	var count := int(interaction_counts.get(normalized, 0)) + 1
	interaction_counts[normalized] = count
	var gain := float(definition.get("base_gain", 4.0)) * (1.0 + float(level - 1) * 0.16)
	var stat_name := str(definition.get("stat", "comfort"))
	_apply_room_stat(stat_name, gain)
	cleanliness = clampf(cleanliness - (1.8 if normalized in ["signal_kitchen", "holo_projector"] else 0.6), 0.0, 100.0)
	room_xp += int(definition.get("xp", 8))
	_apply_gameplay_feedback(normalized, level)
	_check_room_level_up()
	var event := _record_event("object", "%s wurde genutzt." % str(definition.get("title", normalized)), {"object_id": normalized, "level": level})
	var result := {
		"accepted": true,
		"object_id": normalized,
		"title": definition.get("title", normalized),
		"level": level,
		"stat": stat_name,
		"gain": gain,
		"event": event,
		"snapshot": get_snapshot()
	}
	object_interacted.emit(normalized, result.duplicate(true))
	_emit_changed()
	save_state()
	return result

func clean_room() -> Dictionary:
	var before := cleanliness
	cleanliness = clampf(cleanliness + 24.0 + float(object_levels.get("cleaning_drone", 1)) * 3.0, 0.0, 100.0)
	comfort = clampf(comfort + 4.0, 0.0, 100.0)
	room_xp += 10
	_check_room_level_up()
	var event := _record_event("care", "Der Raum wurde gemeinsam geordnet.", {"before": before, "after": cleanliness})
	_emit_changed()
	save_state()
	return {"accepted": true, "cleanliness_gain": cleanliness - before, "event": event, "snapshot": get_snapshot()}

func upgrade_object(object_id: String) -> Dictionary:
	var normalized := object_id.strip_edges().to_lower()
	if not OBJECT_CATALOG.has(normalized):
		return {"accepted": false, "reason": "unknown_object"}
	var definition: Dictionary = OBJECT_CATALOG[normalized]
	var current := int(object_levels.get(normalized, 1))
	var maximum := int(definition.get("max_level", 5))
	if current >= maximum:
		return {"accepted": false, "reason": "max_level", "level": current}
	var required_room_level := current + 1
	if room_level < required_room_level:
		return {"accepted": false, "reason": "room_level", "required": required_room_level}
	object_levels[normalized] = current + 1
	room_xp += 8
	_record_event("upgrade", "%s erreicht Stufe %d." % [str(definition.get("title", normalized)), current + 1], {"object_id": normalized, "level": current + 1})
	_emit_changed()
	save_state()
	return {"accepted": true, "object_id": normalized, "level": current + 1, "snapshot": get_snapshot()}

func place_decoration(decoration_id: String) -> Dictionary:
	var normalized := decoration_id.strip_edges().to_lower()
	if not DECORATION_CATALOG.has(normalized):
		return {"accepted": false, "reason": "unknown_decoration"}
	if decorations.has(normalized):
		return {"accepted": false, "reason": "already_placed"}
	if decorations.size() >= MAX_DECORATIONS:
		return {"accepted": false, "reason": "decoration_limit", "limit": MAX_DECORATIONS}
	decorations.append(normalized)
	var definition: Dictionary = DECORATION_CATALOG[normalized]
	comfort = clampf(comfort + float(definition.get("comfort", 0.0)), 0.0, 100.0)
	inspiration = clampf(inspiration + float(definition.get("inspiration", 0.0)), 0.0, 100.0)
	room_xp += 7
	_check_room_level_up()
	_record_event("decoration", "%s wurde platziert." % str(definition.get("title", normalized)), {"decoration_id": normalized})
	decoration_changed.emit(normalized, true)
	_emit_changed()
	save_state()
	return {"accepted": true, "decoration_id": normalized, "snapshot": get_snapshot()}

func remove_decoration(decoration_id: String) -> bool:
	var normalized := decoration_id.strip_edges().to_lower()
	var index := decorations.find(normalized)
	if index < 0:
		return false
	decorations.remove_at(index)
	decoration_changed.emit(normalized, false)
	_record_event("decoration", "Dekoration wurde eingelagert.", {"decoration_id": normalized})
	_emit_changed()
	save_state()
	return true

func set_theme(next_theme_id: String) -> bool:
	var normalized := next_theme_id.strip_edges().to_lower()
	if not THEMES.has(normalized):
		return false
	theme_id = normalized
	_record_event("theme", "Raumstil: %s" % str(THEMES[normalized].get("title", normalized)), {"theme_id": normalized})
	_emit_changed()
	save_state()
	return true

func set_time_mode(next_mode: String) -> bool:
	var normalized := next_mode.strip_edges().to_upper()
	if normalized not in ["AUTO", "MORNING", "DAY", "EVENING", "NIGHT"]:
		return false
	time_mode = normalized
	_emit_changed()
	save_state()
	return true

func set_weather(next_weather: String) -> bool:
	var normalized := next_weather.strip_edges().to_upper()
	if normalized not in ["CLEAR", "RAIN", "STORM", "AURORA", "SNOW"]:
		return false
	weather_id = normalized
	_record_event("weather", "Das Fenster zeigt jetzt %s." % normalized.capitalize(), {"weather": normalized})
	_emit_changed()
	save_state()
	return true

func record_external_action(action_id: String) -> void:
	match action_id.strip_edges().to_lower():
		"feed":
			cleanliness = clampf(cleanliness - 2.4, 0.0, 100.0)
			comfort = clampf(comfort + 1.5, 0.0, 100.0)
		"play":
			cleanliness = clampf(cleanliness - 3.2, 0.0, 100.0)
			inspiration = clampf(inspiration + 3.5, 0.0, 100.0)
		"learn", "learning_result":
			inspiration = clampf(inspiration + 4.0, 0.0, 100.0)
			power_stability = clampf(power_stability - 0.8, 0.0, 100.0)
		"care":
			cleanliness = clampf(cleanliness + 4.0, 0.0, 100.0)
			plant_health = clampf(plant_health + 2.0, 0.0, 100.0)
		"rest", "sleep":
			comfort = clampf(comfort + 3.0, 0.0, 100.0)
			power_stability = clampf(power_stability + 1.5, 0.0, 100.0)
		_:
			return
	_emit_changed()

func get_snapshot() -> Dictionary:
	var theme: Dictionary = THEMES.get(theme_id, THEMES["neon_nest"])
	var decoration_bonus := _decoration_bonus()
	var effective_comfort := clampf(comfort + float(theme.get("comfort", 0.0)) + float(decoration_bonus.get("comfort", 0.0)), 0.0, 100.0)
	var effective_inspiration := clampf(inspiration + float(theme.get("inspiration", 0.0)) + float(decoration_bonus.get("inspiration", 0.0)), 0.0, 100.0)
	return {
		"schema_version": SCHEMA_VERSION,
		"room_level": room_level,
		"room_xp": room_xp,
		"next_level_xp": _xp_for_next_level(),
		"cleanliness": cleanliness,
		"comfort": comfort,
		"effective_comfort": effective_comfort,
		"inspiration": inspiration,
		"effective_inspiration": effective_inspiration,
		"plant_health": plant_health,
		"power_stability": power_stability,
		"theme_id": theme_id,
		"theme": theme.duplicate(true),
		"time_mode": time_mode,
		"time_segment": _resolved_time_segment(),
		"weather": weather_id,
		"object_levels": object_levels.duplicate(true),
		"interaction_counts": interaction_counts.duplicate(true),
		"decorations": decorations.duplicate(),
		"decoration_limit": MAX_DECORATIONS,
		"recent_events": recent_events.duplicate(true),
		"room_mood": _room_mood(effective_comfort, effective_inspiration),
		"recommended_action": _recommended_action()
	}

func export_state() -> Dictionary:
	return get_snapshot()

func import_state(data: Dictionary) -> void:
	room_level = clampi(int(data.get("room_level", 1)), 1, 20)
	room_xp = maxi(int(data.get("room_xp", 0)), 0)
	cleanliness = clampf(float(data.get("cleanliness", 82.0)), 0.0, 100.0)
	comfort = clampf(float(data.get("comfort", 58.0)), 0.0, 100.0)
	inspiration = clampf(float(data.get("inspiration", 54.0)), 0.0, 100.0)
	plant_health = clampf(float(data.get("plant_health", 76.0)), 0.0, 100.0)
	power_stability = clampf(float(data.get("power_stability", 94.0)), 0.0, 100.0)
	theme_id = str(data.get("theme_id", "neon_nest")) if THEMES.has(str(data.get("theme_id", "neon_nest"))) else "neon_nest"
	time_mode = str(data.get("time_mode", "AUTO")).to_upper()
	weather_id = str(data.get("weather", "CLEAR")).to_upper()
	object_levels = data.get("object_levels", {}).duplicate(true)
	interaction_counts = data.get("interaction_counts", {}).duplicate(true)
	decorations.clear()
	for value in data.get("decorations", []):
		var decoration_id := str(value)
		if DECORATION_CATALOG.has(decoration_id) and not decorations.has(decoration_id):
			decorations.append(decoration_id)
	while decorations.size() > MAX_DECORATIONS:
		decorations.pop_back()
	recent_events.clear()
	for value in data.get("recent_events", []):
		if value is Dictionary:
			recent_events.append((value as Dictionary).duplicate(true))
	while recent_events.size() > MAX_RECENT_EVENTS:
		recent_events.pop_front()
	_initialize_defaults()
	_emit_changed()

func reset_state() -> void:
	room_level = 1
	room_xp = 0
	cleanliness = 82.0
	comfort = 58.0
	inspiration = 54.0
	plant_health = 76.0
	power_stability = 94.0
	theme_id = "neon_nest"
	time_mode = "AUTO"
	weather_id = "CLEAR"
	object_levels.clear()
	interaction_counts.clear()
	decorations.clear()
	recent_events.clear()
	_initialize_defaults()
	_emit_changed()
	save_state()

func save_state() -> bool:
	var temporary := FileAccess.open(TEMP_PATH, FileAccess.WRITE)
	if temporary == null:
		return false
	temporary.store_string(JSON.stringify(export_state()))
	temporary.close()
	if FileAccess.file_exists(SAVE_PATH):
		_copy_file(SAVE_PATH, BACKUP_PATH)
		DirAccess.remove_absolute(SAVE_PATH)
	var error := DirAccess.rename_absolute(TEMP_PATH, SAVE_PATH)
	if error != OK:
		if FileAccess.file_exists(BACKUP_PATH):
			_copy_file(BACKUP_PATH, SAVE_PATH)
		return false
	return true

func load_state() -> bool:
	for path in [SAVE_PATH, BACKUP_PATH]:
		var data := _read_state(path)
		if data.is_empty():
			continue
		import_state(data)
		return true
	return false

func _initialize_defaults() -> void:
	for object_id_variant in OBJECT_CATALOG.keys():
		var object_id := str(object_id_variant)
		if not object_levels.has(object_id):
			object_levels[object_id] = 1
		if not interaction_counts.has(object_id):
			interaction_counts[object_id] = 0

func _connect_runtime() -> void:
	var event_bus := get_node_or_null("/root/EventBus")
	if event_bus != null and event_bus.has_signal("interaction_completed"):
		var callback := Callable(self, "_on_interaction_completed")
		if not event_bus.is_connected("interaction_completed", callback):
			event_bus.connect("interaction_completed", callback)
	var state := get_node_or_null("/root/GameState")
	if state != null and state.has_signal("state_changed"):
		var state_callback := Callable(self, "_on_game_state_changed")
		if not state.is_connected("state_changed", state_callback):
			state.connect("state_changed", state_callback)

func _on_interaction_completed(interaction_id: String, _tags: Array[String]) -> void:
	record_external_action(interaction_id)

func _on_game_state_changed(key: String, _value: Variant) -> void:
	if key == "new_game":
		reset_state()

func _apply_room_stat(stat_name: String, amount: float) -> void:
	match stat_name:
		"cleanliness": cleanliness = clampf(cleanliness + amount, 0.0, 100.0)
		"comfort": comfort = clampf(comfort + amount, 0.0, 100.0)
		"inspiration": inspiration = clampf(inspiration + amount, 0.0, 100.0)
		"plant_health": plant_health = clampf(plant_health + amount, 0.0, 100.0)
		"power_stability": power_stability = clampf(power_stability + amount, 0.0, 100.0)

func _apply_gameplay_feedback(object_id: String, level: int) -> void:
	var state := get_node_or_null("/root/GameState")
	if state == null or not state.has_method("update_stats"):
		return
	match object_id:
		"sleep_pod": state.call("update_stats", 0.0, 8.0 + level, 2.0, 0.0, 1.0)
		"signal_kitchen": state.call("update_stats", 7.0 + level, 1.0, 2.0, 0.0, 0.0)
		"learning_desk", "memory_archive": state.call("update_stats", 0.0, -2.0, 2.0, 6.0 + level, 0.0)
		"holo_projector": state.call("update_stats", 0.0, -1.0, 7.0 + level, 2.0, 0.0)
		"garden_wall": state.call("update_stats", 0.0, 1.0, 3.0, 2.0, 3.0)
		"cleaning_drone": state.call("update_stats", 0.0, -1.0, 3.0, 0.0, 1.0)
		_:
			pass

func _check_room_level_up() -> void:
	while room_level < 20 and room_xp >= _xp_for_next_level():
		room_xp -= _xp_for_next_level()
		room_level += 1
		_record_event("level", "Der Lebensraum erreicht Stufe %d." % room_level, {"room_level": room_level})

func _xp_for_next_level() -> int:
	return 80 + room_level * 35

func _record_event(event_type: String, text: String, payload: Dictionary = {}) -> Dictionary:
	var event := {
		"type": event_type,
		"text": text,
		"payload": payload.duplicate(true),
		"timestamp": int(Time.get_unix_time_from_system())
	}
	recent_events.append(event)
	while recent_events.size() > MAX_RECENT_EVENTS:
		recent_events.pop_front()
	room_event.emit(event.duplicate(true))
	return event

func _decoration_bonus() -> Dictionary:
	var result := {"comfort": 0.0, "inspiration": 0.0}
	for decoration_id in decorations:
		var definition: Dictionary = DECORATION_CATALOG.get(decoration_id, {})
		result["comfort"] = float(result["comfort"]) + float(definition.get("comfort", 0.0))
		result["inspiration"] = float(result["inspiration"]) + float(definition.get("inspiration", 0.0))
	return result

func _resolved_time_segment() -> String:
	if time_mode != "AUTO":
		return time_mode
	var hour := int(Time.get_datetime_dict_from_system().get("hour", 12))
	if hour < 7:
		return "NIGHT"
	if hour < 11:
		return "MORNING"
	if hour < 18:
		return "DAY"
	if hour < 23:
		return "EVENING"
	return "NIGHT"

func _room_mood(effective_comfort: float, effective_inspiration: float) -> String:
	if cleanliness < 28.0 or power_stability < 30.0:
		return "UNSETTLED"
	if plant_health > 82.0 and effective_comfort > 82.0:
		return "FLOURISHING"
	if effective_inspiration > 82.0:
		return "INSPIRED"
	if effective_comfort > 76.0:
		return "COZY"
	return "BALANCED"

func _recommended_action() -> String:
	var values := {
		"clean_room": cleanliness,
		"garden_wall": plant_health,
		"sleep_pod": comfort,
		"learning_desk": inspiration,
		"weather_window": power_stability
	}
	var best_id := "holo_projector"
	var lowest := 101.0
	for key_variant in values.keys():
		var key := str(key_variant)
		var value := float(values[key])
		if value < lowest:
			lowest = value
			best_id = key
	return best_id

func _apply_daily_decay_if_needed() -> void:
	var day := int(Time.get_date_dict_from_system().get("day", 1))
	if day == _last_decay_day:
		return
	_last_decay_day = day
	cleanliness = clampf(cleanliness - 1.8, 0.0, 100.0)
	plant_health = clampf(plant_health - 1.1, 0.0, 100.0)
	power_stability = clampf(power_stability - 0.5, 0.0, 100.0)
	_emit_changed()

func _emit_changed() -> void:
	home_changed.emit(get_snapshot())

func _read_state(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	return parsed as Dictionary if parsed is Dictionary else {}

func _copy_file(source: String, destination: String) -> void:
	var input := FileAccess.open(source, FileAccess.READ)
	if input == null:
		return
	var output := FileAccess.open(destination, FileAccess.WRITE)
	if output == null:
		input.close()
		return
	output.store_buffer(input.get_buffer(input.get_length()))
	input.close()
	output.close()
