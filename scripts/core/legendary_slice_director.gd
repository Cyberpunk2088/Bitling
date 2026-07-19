extends Node

## Authoritative local story state for the Legendary Vertical Slice.
## The director coordinates narrative beats but never duplicates GameState progression.

signal slice_started(snapshot: Dictionary)
signal beat_changed(previous_index: int, current_index: int, beat: Dictionary)
signal activity_recorded(activity_id: String, result: Dictionary)
signal slice_completed(snapshot: Dictionary)

const SCHEMA_VERSION := 1
const SAVE_PATH := "user://legendary_slice.json"
const TEMP_PATH := "user://legendary_slice.tmp"
const BACKUP_PATH := "user://legendary_slice.backup.json"
const MAX_ACTIVITY_HISTORY := 24

const BEATS: Array[Dictionary] = [
	{
		"id": "signal_in_darkness",
		"title": "Signal im Dunkeln",
		"objective": "Wecke das fremde Signal und gib ihm einen Namen.",
		"expected_event": "slice_started"
	},
	{
		"id": "first_choice",
		"title": "Erste Entscheidung",
		"objective": "Zeige deinem Bitling, wie ihr miteinander umgehen wollt.",
		"expected_event": "first_care"
	},
	{
		"id": "shared_rhythm",
		"title": "Gemeinsamer Rhythmus",
		"objective": "Findet im Resonanzrhythmus einen gemeinsamen Takt.",
		"expected_event": "resonance_rhythm"
	},
	{
		"id": "language_becomes_meaning",
		"title": "Sprache wird Bedeutung",
		"objective": "Entschlüssle die erste Botschaft in Bitling-Sprache.",
		"expected_event": "signal_translation"
	},
	{
		"id": "patterns_become_knowledge",
		"title": "Muster werden Wissen",
		"objective": "Löse gemeinsam eine Musterfolge.",
		"expected_event": "pattern_focus"
	},
	{
		"id": "prismatic_rooftops",
		"title": "Prismatische Dachgärten",
		"objective": "Erkundet die erste Region und trefft eine echte Entscheidung.",
		"expected_event": "prism_rooftops"
	},
	{
		"id": "promise_of_growth",
		"title": "Versprechen der Entwicklung",
		"objective": "Wähle, welche Eigenschaft ihr als Nächstes gemeinsam stärkt.",
		"expected_event": "evolution_promise"
	}
]

var active := false
var completed := false
var current_beat_index := 0
var bitling_name := "BITLING"
var care_style := "ermutigend"
var started_at_unix := 0
var completed_at_unix := 0
var events: Dictionary = {}
var activity_results: Dictionary = {}
var activity_history: Array[Dictionary] = []

func _ready() -> void:
	load_state()

func start_slice(chosen_name: String = "BITLING", chosen_care_style: String = "ermutigend") -> Dictionary:
	if completed:
		return get_snapshot()
	bitling_name = _sanitize_name(chosen_name)
	care_style = _sanitize_care_style(chosen_care_style)
	active = true
	started_at_unix = int(Time.get_unix_time_from_system()) if started_at_unix <= 0 else started_at_unix
	record_story_event("slice_started", {"name": bitling_name, "care_style": care_style})
	var state := get_node_or_null("/root/GameState")
	if state != null:
		state.story_flags["legendary_slice_started"] = true
		state.story_flags["legendary_slice_name"] = bitling_name
		state.story_flags["legendary_slice_care_style"] = care_style
		if state.has_method("add_memory"):
			state.add_memory("legendary_slice_start", "%s antwortete auf das erste Signal." % bitling_name)
		if state.has_method("save_game_state"):
			state.save_game_state()
	slice_started.emit(get_snapshot())
	return get_snapshot()

func record_story_event(event_id: String, payload: Dictionary = {}) -> Dictionary:
	var normalized := event_id.strip_edges().to_lower()
	if normalized.is_empty():
		return get_snapshot()
	active = true
	events[normalized] = {
		"timestamp": int(Time.get_unix_time_from_system()),
		"payload": payload.duplicate(true)
	}
	_advance_ready_beats()
	save_state()
	return get_snapshot()

func record_activity(activity_id: String, result: Dictionary) -> Dictionary:
	var normalized := activity_id.strip_edges().to_lower()
	if normalized.is_empty():
		return get_snapshot()
	var accepted := bool(result.get("accepted", true))
	var success := bool(result.get("success", false))
	var score := clampf(float(result.get("score", 0.0)), 0.0, 1.0)
	var previous: Dictionary = activity_results.get(normalized, {}) as Dictionary
	activity_results[normalized] = {
		"attempts": int(previous.get("attempts", 0)) + 1,
		"successes": int(previous.get("successes", 0)) + (1 if success else 0),
		"best_score": maxf(float(previous.get("best_score", 0.0)), score),
		"last_score": score,
		"last_success": success,
		"last_completed_at": int(Time.get_unix_time_from_system())
	}
	activity_history.append({
		"id": normalized,
		"accepted": accepted,
		"success": success,
		"score": score,
		"timestamp": int(Time.get_unix_time_from_system())
	})
	while activity_history.size() > MAX_ACTIVITY_HISTORY:
		activity_history.pop_front()
	activity_recorded.emit(normalized, result.duplicate(true))
	if accepted and success:
		record_story_event(normalized, {"score": score})
	else:
		save_state()
	return get_snapshot()

func record_first_care(interaction_id: String) -> Dictionary:
	return record_story_event("first_care", {"interaction": interaction_id})

func choose_evolution_promise(focus: String) -> Dictionary:
	var safe_focus := focus.strip_edges().to_lower()
	if safe_focus not in ["wissen", "mut", "fürsorge", "kreativität"]:
		safe_focus = "wissen"
	var state := get_node_or_null("/root/GameState")
	if state != null:
		state.story_flags["legendary_slice_evolution_focus"] = safe_focus
		if state.has_method("add_memory"):
			state.add_memory("evolution_promise", "Gemeinsames Entwicklungsversprechen: %s." % safe_focus)
	record_story_event("evolution_promise", {"focus": safe_focus})
	return get_snapshot()

func get_current_beat() -> Dictionary:
	if BEATS.is_empty():
		return {}
	return BEATS[clampi(current_beat_index, 0, BEATS.size() - 1)].duplicate(true)

func get_current_objective() -> String:
	if completed:
		return "Der erste gemeinsame Bogen ist abgeschlossen. Die nächste Entwicklung kann beginnen."
	return str(get_current_beat().get("objective", "Gemeinsam weitermachen."))

func get_progress_ratio() -> float:
	if completed:
		return 1.0
	return clampf(float(current_beat_index) / float(maxi(BEATS.size(), 1)), 0.0, 1.0)

func get_snapshot() -> Dictionary:
	return {
		"schema_version": SCHEMA_VERSION,
		"active": active,
		"completed": completed,
		"current_beat_index": current_beat_index,
		"current_beat": get_current_beat(),
		"objective": get_current_objective(),
		"progress": get_progress_ratio(),
		"bitling_name": bitling_name,
		"care_style": care_style,
		"started_at_unix": started_at_unix,
		"completed_at_unix": completed_at_unix,
		"events": events.duplicate(true),
		"activity_results": activity_results.duplicate(true),
		"activity_history": activity_history.duplicate(true)
	}

func export_state() -> Dictionary:
	return get_snapshot()

func import_state(data: Dictionary) -> void:
	if data.is_empty():
		return
	active = bool(data.get("active", false))
	completed = bool(data.get("completed", false))
	current_beat_index = clampi(int(data.get("current_beat_index", 0)), 0, BEATS.size() - 1)
	bitling_name = _sanitize_name(str(data.get("bitling_name", "BITLING")))
	care_style = _sanitize_care_style(str(data.get("care_style", "ermutigend")))
	started_at_unix = maxi(int(data.get("started_at_unix", 0)), 0)
	completed_at_unix = maxi(int(data.get("completed_at_unix", 0)), 0)
	events = (data.get("events", {}) as Dictionary).duplicate(true)
	activity_results = (data.get("activity_results", {}) as Dictionary).duplicate(true)
	activity_history = (data.get("activity_history", []) as Array).duplicate(true)
	while activity_history.size() > MAX_ACTIVITY_HISTORY:
		activity_history.pop_front()
	_advance_ready_beats(false)

func reset_state() -> void:
	active = false
	completed = false
	current_beat_index = 0
	bitling_name = "BITLING"
	care_style = "ermutigend"
	started_at_unix = 0
	completed_at_unix = 0
	events.clear()
	activity_results.clear()
	activity_history.clear()
	for path in [SAVE_PATH, TEMP_PATH, BACKUP_PATH]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)

func save_state() -> bool:
	var file := FileAccess.open(TEMP_PATH, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(export_state()))
	file.close()
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

func _advance_ready_beats(emit_signal: bool = true) -> void:
	while not completed and current_beat_index < BEATS.size():
		var expected := str(BEATS[current_beat_index].get("expected_event", ""))
		if expected.is_empty() or not events.has(expected):
			break
		var previous := current_beat_index
		current_beat_index += 1
		if current_beat_index >= BEATS.size():
			completed = true
			active = false
			completed_at_unix = int(Time.get_unix_time_from_system())
			var state := get_node_or_null("/root/GameState")
			if state != null:
				state.story_flags["legendary_slice_complete"] = true
				if state.has_method("add_memory"):
					state.add_memory("legendary_slice_complete", "Der erste gemeinsame Handlungsbogen wurde abgeschlossen.")
				if state.has_method("save_game_state"):
					state.save_game_state()
			if emit_signal:
				slice_completed.emit(get_snapshot())
			break
		if emit_signal:
			beat_changed.emit(previous, current_beat_index, get_current_beat())

func _sanitize_name(value: String) -> String:
	var clean := value.strip_edges()
	if clean.is_empty():
		return "BITLING"
	return clean.substr(0, mini(clean.length(), 20))

func _sanitize_care_style(value: String) -> String:
	var clean := value.strip_edges().to_lower()
	if clean not in ["ermutigend", "routiniert", "neugierig", "ruhig"]:
		return "ermutigend"
	return clean

func _read_state(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if parsed is not Dictionary:
		return {}
	var data := parsed as Dictionary
	if int(data.get("schema_version", 0)) != SCHEMA_VERSION:
		return {}
	return data

func _copy_file(source_path: String, target_path: String) -> bool:
	var source := FileAccess.open(source_path, FileAccess.READ)
	if source == null:
		return false
	var bytes := source.get_buffer(source.get_length())
	source.close()
	var target := FileAccess.open(target_path, FileAccess.WRITE)
	if target == null:
		return false
	target.store_buffer(bytes)
	target.close()
	return true
