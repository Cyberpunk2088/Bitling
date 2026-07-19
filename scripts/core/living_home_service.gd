extends Node

## Authoritative, asset-independent home simulation for Wave 3.
## Visuals consume snapshots; this service owns persistence and gameplay effects.

signal home_changed(snapshot: Dictionary)
signal object_interacted(object_id: String, result: Dictionary)
signal routine_changed(routine_id: String)

const SAVE_PATH := "user://bitling_living_home.json"
const TEMP_PATH := "user://bitling_living_home.tmp"
const BACKUP_PATH := "user://bitling_living_home.backup.json"
const SCHEMA_VERSION := 1
const MAX_HISTORY := 40

const OBJECTS: Dictionary = {
	"window": {"label": "Panoramafenster", "action": "Aussicht wechseln", "comfort": 2.0},
	"lamp": {"label": "Prismenlampe", "action": "Lichtstimmung wechseln", "comfort": 4.0},
	"plant": {"label": "Signalpflanze", "action": "Pflanze versorgen", "comfort": 5.0},
	"shelf": {"label": "Erinnerungsregal", "action": "Fundstück ausstellen", "comfort": 3.0},
	"cushion": {"label": "Ruhekissen", "action": "Gemeinsam ausruhen", "comfort": 6.0}
}

const ROUTINES: Dictionary = {
	"morning_scan": {"label": "Morgendlicher Signalscan", "segment": "MORNING", "object": "window"},
	"plant_care": {"label": "Pflanzenpflege", "segment": "DAY", "object": "plant"},
	"memory_hour": {"label": "Erinnerungsstunde", "segment": "EVENING", "object": "shelf"},
	"quiet_nest": {"label": "Ruhiges Nest", "segment": "NIGHT", "object": "cushion"}
}

var light_mode := "CYAN"
var weather_mode := "CLEAR"
var window_scene := 0
var plant_health := 72.0
var cleanliness := 78.0
var comfort := 64.0
var displayed_memories: Array[String] = []
var unlocked_decor: Array[String] = ["starter_prism", "signal_plant", "soft_cushion"]
var interaction_counts: Dictionary = {}
var history: Array[Dictionary] = []
var active_routine := ""
var last_tick_unix := 0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if not load_state():
		reset_state()
	_update_time_based_state()
	set_process(true)

func _process(_delta: float) -> void:
	var now := int(Time.get_unix_time_from_system())
	if now - last_tick_unix >= 60:
		last_tick_unix = now
		_apply_passive_tick()
		_update_time_based_state()

func interact(object_id: String) -> Dictionary:
	var normalized := object_id.to_lower()
	if not OBJECTS.has(normalized):
		return {"accepted": false, "reason": "unknown_object"}
	interaction_counts[normalized] = int(interaction_counts.get(normalized, 0)) + 1
	var result := {"accepted": true, "object": normalized, "label": str(OBJECTS[normalized]["label"])}
	match normalized:
		"window":
			window_scene = (window_scene + 1) % 4
			weather_mode = ["CLEAR", "RAIN", "AURORA", "STORM"][window_scene]
			result["message"] = "Die Aussicht wechselt zu %s." % _weather_label(weather_mode)
		"lamp":
			var modes := ["CYAN", "VIOLET", "SUNSET", "MOON"]
			light_mode = modes[(modes.find(light_mode) + 1) % modes.size()]
			comfort = clampf(comfort + 2.0, 0.0, 100.0)
			result["message"] = "Die Prismenlampe leuchtet jetzt im Modus %s." % light_mode
		"plant":
			plant_health = clampf(plant_health + 18.0, 0.0, 100.0)
			cleanliness = clampf(cleanliness + 2.0, 0.0, 100.0)
			result["message"] = "Die Signalpflanze richtet ihre Blätter zum Bitling aus."
		"shelf":
			_display_next_memory()
			result["message"] = "Ein gemeinsamer Moment wurde im Regal sichtbar."
		"cushion":
			comfort = clampf(comfort + 8.0, 0.0, 100.0)
			cleanliness = clampf(cleanliness - 1.0, 0.0, 100.0)
			result["message"] = "Das Ruhekissen speichert eine warme Mulde."
	_record_history(normalized, str(result.get("message", "")))
	_apply_gameplay_effect(normalized)
	save_state()
	var snapshot := get_snapshot()
	object_interacted.emit(normalized, result.duplicate(true))
	home_changed.emit(snapshot)
	return result

func tidy_room() -> Dictionary:
	cleanliness = clampf(cleanliness + 24.0, 0.0, 100.0)
	comfort = clampf(comfort + 4.0, 0.0, 100.0)
	_record_history("tidy", "Der Raum wurde gemeinsam neu geordnet.")
	save_state()
	var snapshot := get_snapshot()
	home_changed.emit(snapshot)
	return snapshot

func unlock_decor(decor_id: String) -> bool:
	var normalized := decor_id.strip_edges().to_lower()
	if normalized.is_empty() or unlocked_decor.has(normalized):
		return false
	unlocked_decor.append(normalized)
	_record_history("decor", "Dekoration freigeschaltet: %s" % normalized)
	save_state()
	home_changed.emit(get_snapshot())
	return true

func get_snapshot() -> Dictionary:
	return {
		"schema_version": SCHEMA_VERSION,
		"time_segment": _time_segment(),
		"weather": weather_mode,
		"weather_label": _weather_label(weather_mode),
		"light_mode": light_mode,
		"window_scene": window_scene,
		"plant_health": plant_health,
		"cleanliness": cleanliness,
		"comfort": comfort,
		"displayed_memories": displayed_memories.duplicate(),
		"unlocked_decor": unlocked_decor.duplicate(),
		"interaction_counts": interaction_counts.duplicate(true),
		"active_routine": active_routine,
		"routine_label": str(ROUTINES.get(active_routine, {}).get("label", "Freie Zeit")),
		"objects": OBJECTS.duplicate(true),
		"history": history.duplicate(true)
	}

func export_state() -> Dictionary:
	return get_snapshot()

func import_state(data: Dictionary) -> void:
	light_mode = str(data.get("light_mode", "CYAN"))
	weather_mode = str(data.get("weather", "CLEAR"))
	window_scene = clampi(int(data.get("window_scene", 0)), 0, 3)
	plant_health = clampf(float(data.get("plant_health", 72.0)), 0.0, 100.0)
	cleanliness = clampf(float(data.get("cleanliness", 78.0)), 0.0, 100.0)
	comfort = clampf(float(data.get("comfort", 64.0)), 0.0, 100.0)
	displayed_memories.clear()
	for item in data.get("displayed_memories", []):
		displayed_memories.append(str(item))
	unlocked_decor.clear()
	for item in data.get("unlocked_decor", []):
		unlocked_decor.append(str(item))
	interaction_counts = data.get("interaction_counts", {}).duplicate(true)
	history.clear()
	for item in data.get("history", []):
		if item is Dictionary:
			history.append(item.duplicate(true))
	while history.size() > MAX_HISTORY:
		history.pop_front()
	active_routine = str(data.get("active_routine", ""))

func reset_state() -> void:
	light_mode = "CYAN"
	weather_mode = "CLEAR"
	window_scene = 0
	plant_health = 72.0
	cleanliness = 78.0
	comfort = 64.0
	displayed_memories.clear()
	unlocked_decor = ["starter_prism", "signal_plant", "soft_cushion"]
	interaction_counts.clear()
	history.clear()
	active_routine = ""
	last_tick_unix = int(Time.get_unix_time_from_system())
	save_state()

func save_state() -> bool:
	var file := FileAccess.open(TEMP_PATH, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(export_state()))
	file.close()
	if FileAccess.file_exists(SAVE_PATH):
		_copy_file(SAVE_PATH, BACKUP_PATH)
		DirAccess.remove_absolute(SAVE_PATH)
	return DirAccess.rename_absolute(TEMP_PATH, SAVE_PATH) == OK

func load_state() -> bool:
	for path in [SAVE_PATH, BACKUP_PATH]:
		if not FileAccess.file_exists(path):
			continue
		var file := FileAccess.open(path, FileAccess.READ)
		if file == null:
			continue
		var parsed: Variant = JSON.parse_string(file.get_as_text())
		file.close()
		if parsed is Dictionary:
			import_state(parsed as Dictionary)
			return true
	return false

func _apply_passive_tick() -> void:
	plant_health = clampf(plant_health - 0.18, 0.0, 100.0)
	cleanliness = clampf(cleanliness - 0.10, 0.0, 100.0)
	comfort = clampf(comfort + (0.04 if cleanliness >= 55.0 else -0.12), 0.0, 100.0)
	save_state()

func _update_time_based_state() -> void:
	var segment := _time_segment()
	var next_routine := ""
	for routine_id_variant in ROUTINES.keys():
		var routine_id := str(routine_id_variant)
		if str(ROUTINES[routine_id].get("segment", "")) == segment:
			next_routine = routine_id
			break
	if next_routine != active_routine:
		active_routine = next_routine
		routine_changed.emit(active_routine)
		home_changed.emit(get_snapshot())

func _time_segment() -> String:
	var hour := int(Time.get_datetime_dict_from_system().get("hour", 12))
	if hour < 6:
		return "NIGHT"
	if hour < 11:
		return "MORNING"
	if hour < 18:
		return "DAY"
	if hour < 23:
		return "EVENING"
	return "NIGHT"

func _display_next_memory() -> void:
	var state := get_node_or_null("/root/GameState")
	var candidate := "Erstes gemeinsames Signal"
	if state != null:
		var memories_variant: Variant = state.get("memories")
		if memories_variant is Array and not (memories_variant as Array).is_empty():
			var memories := memories_variant as Array
			var index := displayed_memories.size() % memories.size()
			var memory_variant: Variant = memories[index]
			if memory_variant is Dictionary:
				candidate = str((memory_variant as Dictionary).get("text", candidate))
	if not displayed_memories.has(candidate):
		displayed_memories.append(candidate)
	while displayed_memories.size() > 6:
		displayed_memories.pop_front()

func _apply_gameplay_effect(object_id: String) -> void:
	var state := get_node_or_null("/root/GameState")
	if state == null or not state.has_method("perform_interaction"):
		return
	var effects := {"happiness": 3.0, "curiosity": 2.0}
	var tags: Array[String] = ["home", object_id]
	match object_id:
		"plant":
			effects = {"happiness": 3.0, "curiosity": 4.0, "health": 1.0}
		"shelf":
			effects = {"happiness": 4.0, "curiosity": 5.0}
		"cushion":
			effects = {"energy": 8.0, "happiness": 3.0}
		"window":
			effects = {"curiosity": 6.0, "happiness": 2.0}
		"lamp":
			effects = {"happiness": 4.0}
	state.call("perform_interaction", "home_%s" % object_id, effects, 4, tags)

func _record_history(object_id: String, message: String) -> void:
	history.append({"object": object_id, "message": message, "timestamp": int(Time.get_unix_time_from_system())})
	while history.size() > MAX_HISTORY:
		history.pop_front()

func _weather_label(value: String) -> String:
	return {"CLEAR": "klarer Neonhimmel", "RAIN": "leuchtender Regen", "AURORA": "Prismenaurora", "STORM": "fernes Signalgewitter"}.get(value, "wechselndes Wetter")

func _copy_file(source: String, target: String) -> void:
	var input := FileAccess.open(source, FileAccess.READ)
	if input == null:
		return
	var output := FileAccess.open(target, FileAccess.WRITE)
	if output != null:
		output.store_buffer(input.get_buffer(input.get_length()))
		output.close()
	input.close()
