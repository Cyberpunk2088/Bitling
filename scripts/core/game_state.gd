extends Node

## Persistent source of truth for BITLING OMNI.
## UI and gameplay systems communicate through methods and EventBus signals.

enum Phase { EGG, BABY, CHILD, TEEN, ADULT, SENIOR, LEGENDARY }
enum Era { TERMINAL, PIXEL, VECTOR, FLAT, FLUID }
enum Mood { ECSTATIC, HAPPY, CONTENT, NEUTRAL, TIRED, SAD, DISTRESSED }

const SAVE_SCHEMA_VERSION := 5
const MAX_LEVEL := 100
const XP_PER_LEVEL := 100
const SAVE_PATH := "user://bitling_save.json"
const LEGACY_SAVE_PATH := "user://bitling_save.dat"
const TEMP_SAVE_PATH := "user://bitling_save.tmp"
const BACKUP_SAVE_PATH := "user://bitling_save.backup.json"
const PHASE_THRESHOLDS := [0, 10, 25, 40, 60, 80, 95]
const ERA_THRESHOLDS := [0, 15, 35, 55, 75]
const AUTOSAVE_INTERVAL_SECONDS := 60.0

var level: int = 1
var xp: int = 0
var total_xp: int = 0
var phase: Phase = Phase.EGG
var era: Era = Era.TERMINAL
var mood: Mood = Mood.NEUTRAL
var play_time_seconds: float = 0.0
var days_played: int = 1
var hunger: float = 50.0
var energy: float = 80.0
var happiness: float = 50.0
var curiosity: float = 50.0
var health: float = 100.0
var skill_points: int = 0
var memories: Array[Dictionary] = []
var story_flags: Dictionary = {}
var settings: Dictionary = {
	"music_volume": 0.7,
	"sfx_volume": 0.8,
	"notifications_enabled": true,
	"quiet_hours_start": 22,
	"quiet_hours_end": 8,
	"haptics_enabled": true,
	"language": "de",
	"theme": "system",
	"font_scale": 1.0,
	"high_contrast": false,
	"reduce_motion": false,
	"screen_reader": false,
	"auto_save": true
}

var _autosave_elapsed: float = 0.0

signal state_changed(key: String, value: Variant)
signal level_up(new_level: int)
signal phase_changed(new_phase: Phase)
signal era_changed(new_era: Era)
signal mood_changed(new_mood: Mood)

func _ready() -> void:
	var loaded := load_game_state()
	if not loaded:
		initialize_new_game()
	_register_daily_activity()
	_evaluate_evolution()

func _process(delta: float) -> void:
	play_time_seconds += delta
	_autosave_elapsed += delta
	if _autosave_elapsed >= AUTOSAVE_INTERVAL_SECONDS:
		_autosave_elapsed = 0.0
		if bool(settings.get("auto_save", true)):
			save_game_state()

func initialize_new_game() -> void:
	level = 1
	xp = 0
	total_xp = 0
	phase = Phase.EGG
	era = Era.TERMINAL
	mood = Mood.NEUTRAL
	play_time_seconds = 0.0
	days_played = 1
	hunger = 50.0
	energy = 80.0
	happiness = 50.0
	curiosity = 50.0
	health = 100.0
	skill_points = 0
	memories.clear()
	story_flags = {"hatched": false, "tutorial_complete": false}
	if has_node("/root/CompanionBrain"):
		get_node("/root/CompanionBrain").reset_state()
	if has_node("/root/AdaptiveLearning"):
		get_node("/root/AdaptiveLearning").reset_state()
	if has_node("/root/EvolutionService"):
		get_node("/root/EvolutionService").reset_state()
	add_memory("awakening", "A faint signal appeared in the dark.")
	save_game_state()
	state_changed.emit("new_game", true)

func hatch() -> void:
	if story_flags.get("hatched", false):
		return
	story_flags["hatched"] = true
	level = maxi(level, 10)
	phase = Phase.BABY
	add_memory("birth", "The screen flickered, and there I was.")
	phase_changed.emit(phase)
	state_changed.emit("hatched", true)
	_evaluate_evolution()
	save_game_state()

func gain_xp(amount: int, source: String = "unknown") -> void:
	if amount <= 0 or level >= MAX_LEVEL:
		return
	var old_level := level
	xp += amount
	total_xp += amount
	while xp >= XP_PER_LEVEL and level < MAX_LEVEL:
		xp -= XP_PER_LEVEL
		level += 1
		skill_points += 1
		level_up.emit(level)
		_update_progression()
	if level >= MAX_LEVEL:
		xp = 0
	state_changed.emit("xp", xp)
	if has_node("/root/EventBus"):
		var event_bus := get_node("/root/EventBus")
		event_bus.xp_gained.emit(float(amount), source)
		if old_level != level:
			event_bus.level_changed.emit(old_level, level)
	_evaluate_evolution()

func perform_interaction(interaction_id: String, effects: Dictionary, xp_reward: int, tags: Array[String] = []) -> Dictionary:
	if interaction_id.is_empty():
		return get_state_summary()
	_apply_need_delta("hunger", float(effects.get("hunger", 0.0)))
	_apply_need_delta("energy", float(effects.get("energy", 0.0)))
	_apply_need_delta("happiness", float(effects.get("happiness", 0.0)))
	_apply_need_delta("curiosity", float(effects.get("curiosity", 0.0)))
	_apply_need_delta("health", float(effects.get("health", 0.0)))
	_update_mood()
	gain_xp(xp_reward, interaction_id)
	if has_node("/root/CompanionBrain"):
		get_node("/root/CompanionBrain").observe_interaction(interaction_id, 1.0, {"tags": tags})
	if has_node("/root/QuestService"):
		var event_name := str(effects.get("quest_event", ""))
		if not event_name.is_empty():
			get_node("/root/QuestService").record_event(event_name)
	if has_node("/root/EventBus"):
		get_node("/root/EventBus").interaction_completed.emit(interaction_id, tags)
	_evaluate_evolution()
	var summary := get_state_summary()
	state_changed.emit("interaction", {"id": interaction_id, "state": summary})
	return summary

func apply_learning_result(result: Dictionary) -> Dictionary:
	if not bool(result.get("accepted", false)):
		return get_state_summary()
	var success := bool(result.get("success", false))
	var reward := maxi(int(result.get("xp_reward", 0)), 0)
	var tags: Array[String] = ["learn", "growth"]
	var effects := {
		"energy": -4.0,
		"happiness": 5.0 if success else 2.0,
		"curiosity": 12.0 if success else 5.0,
		"quest_event": "discovery_completed"
	}
	return perform_interaction("learn", effects, reward, tags)

func update_stats(
	hunger_delta: float = 0.0,
	energy_delta: float = 0.0,
	happiness_delta: float = 0.0,
	curiosity_delta: float = 0.0,
	health_delta: float = 0.0
) -> void:
	_apply_need_delta("hunger", hunger_delta)
	_apply_need_delta("energy", energy_delta)
	_apply_need_delta("happiness", happiness_delta)
	_apply_need_delta("curiosity", curiosity_delta)
	_apply_need_delta("health", health_delta)
	_update_mood()
	state_changed.emit("stats", get_state_summary())

func add_memory(type: String, text: String) -> void:
	if type.is_empty() or text.is_empty():
		return
	if memories.any(func(item: Dictionary) -> bool: return item.get("type") == type and item.get("text") == text):
		return
	var memory := {
		"type": type,
		"text": text,
		"timestamp": int(Time.get_unix_time_from_system()),
		"day": days_played,
		"level": level
	}
	memories.append(memory)
	if memories.size() > 50:
		memories.pop_front()
	if has_node("/root/EventBus"):
		get_node("/root/EventBus").memory_created.emit(memory.duplicate(true))

func save_game_state() -> bool:
	var json := JSON.stringify(get_save_data())
	var temporary := FileAccess.open(TEMP_SAVE_PATH, FileAccess.WRITE)
	if temporary == null:
		_push_save_failure("Could not open temporary save file")
		return false
	temporary.store_string(json)
	temporary.close()
	if FileAccess.file_exists(SAVE_PATH):
		_copy_file(SAVE_PATH, BACKUP_SAVE_PATH)
	if FileAccess.file_exists(SAVE_PATH):
		var remove_error := DirAccess.remove_absolute(SAVE_PATH)
		if remove_error != OK:
			_push_save_failure("Could not replace existing save: %s" % remove_error)
			return false
	var rename_error := DirAccess.rename_absolute(TEMP_SAVE_PATH, SAVE_PATH)
	if rename_error != OK:
		_push_save_failure("Atomic save replacement failed: %s" % rename_error)
		return false
	if has_node("/root/EventBus"):
		get_node("/root/EventBus").save_completed.emit(SAVE_PATH)
	return true

func load_game_state() -> bool:
	for path in [SAVE_PATH, LEGACY_SAVE_PATH, BACKUP_SAVE_PATH]:
		var data := _read_save(path)
		if not data.is_empty():
			apply_save_data(data)
			return true
	return false

func get_save_data() -> Dictionary:
	return {
		"schema_version": SAVE_SCHEMA_VERSION,
		"level": level,
		"xp": xp,
		"total_xp": total_xp,
		"phase": phase,
		"era": era,
		"mood": mood,
		"play_time_seconds": play_time_seconds,
		"days_played": days_played,
		"hunger": hunger,
		"energy": energy,
		"happiness": happiness,
		"curiosity": curiosity,
		"health": health,
		"skill_points": skill_points,
		"memories": memories,
		"story_flags": story_flags,
		"settings": settings,
		"streak": get_node("/root/StreakService").export_state() if has_node("/root/StreakService") else {},
		"quests": get_node("/root/QuestService").export_state() if has_node("/root/QuestService") else {},
		"companion": get_node("/root/CompanionBrain").export_state() if has_node("/root/CompanionBrain") else {},
		"learning": get_node("/root/AdaptiveLearning").export_state() if has_node("/root/AdaptiveLearning") else {},
		"evolution": get_node("/root/EvolutionService").export_state() if has_node("/root/EvolutionService") else {},
		"last_saved_at": Time.get_datetime_string_from_system()
	}

func apply_save_data(data: Dictionary) -> void:
	level = clampi(int(data.get("level", 1)), 1, MAX_LEVEL)
	xp = maxi(int(data.get("xp", 0)), 0)
	total_xp = maxi(int(data.get("total_xp", 0)), 0)
	phase = clampi(int(data.get("phase", Phase.EGG)), Phase.EGG, Phase.LEGENDARY) as Phase
	era = clampi(int(data.get("era", Era.TERMINAL)), Era.TERMINAL, Era.FLUID) as Era
	mood = clampi(int(data.get("mood", Mood.NEUTRAL)), Mood.ECSTATIC, Mood.DISTRESSED) as Mood
	play_time_seconds = maxf(float(data.get("play_time_seconds", data.get("play_time", 0.0))), 0.0)
	days_played = maxi(int(data.get("days_played", 1)), 1)
	hunger = clampf(float(data.get("hunger", 50.0)), 0.0, 100.0)
	energy = clampf(float(data.get("energy", 80.0)), 0.0, 100.0)
	happiness = clampf(float(data.get("happiness", 50.0)), 0.0, 100.0)
	curiosity = clampf(float(data.get("curiosity", 50.0)), 0.0, 100.0)
	health = clampf(float(data.get("health", 100.0)), 0.0, 100.0)
	skill_points = maxi(int(data.get("skill_points", 0)), 0)
	memories.clear()
	for item in data.get("memories", []):
		if item is Dictionary:
			memories.append(item.duplicate(true))
	story_flags = data.get("story_flags", {}).duplicate(true)
	settings.merge(data.get("settings", {}), true)
	if has_node("/root/StreakService"):
		get_node("/root/StreakService").import_state(data.get("streak", {}))
	if has_node("/root/QuestService"):
		get_node("/root/QuestService").import_state(data.get("quests", {}))
	if has_node("/root/CompanionBrain"):
		get_node("/root/CompanionBrain").import_state(data.get("companion", {}))
	if has_node("/root/AdaptiveLearning"):
		get_node("/root/AdaptiveLearning").import_state(data.get("learning", {}))
	if has_node("/root/EvolutionService"):
		get_node("/root/EvolutionService").import_state(data.get("evolution", {}))
	_update_progression()
	_update_mood()
	_evaluate_evolution()
	state_changed.emit("loaded", true)

func has_save_file() -> bool:
	return FileAccess.file_exists(SAVE_PATH) or FileAccess.file_exists(LEGACY_SAVE_PATH)

func get_state_summary() -> Dictionary:
	var form_id := "signal"
	if has_node("/root/EvolutionService"):
		form_id = str(get_node("/root/EvolutionService").current_form)
	return {
		"level": level,
		"xp": xp,
		"phase": Phase.keys()[phase],
		"era": Era.keys()[era],
		"mood": Mood.keys()[mood],
		"form": form_id,
		"hunger": hunger,
		"energy": energy,
		"happiness": happiness,
		"curiosity": curiosity,
		"health": health
	}

func _register_daily_activity() -> void:
	if has_node("/root/StreakService"):
		get_node("/root/StreakService").register_activity()
	if has_node("/root/QuestService"):
		get_node("/root/QuestService").ensure_daily_quests("local-profile")

func _apply_need_delta(need_name: String, delta: float) -> void:
	if is_zero_approx(delta):
		return
	var old_value := 0.0
	var new_value := 0.0
	match need_name:
		"hunger":
			old_value = hunger
			hunger = clampf(hunger + delta, 0.0, 100.0)
			new_value = hunger
		"energy":
			old_value = energy
			energy = clampf(energy + delta, 0.0, 100.0)
			new_value = energy
		"happiness":
			old_value = happiness
			happiness = clampf(happiness + delta, 0.0, 100.0)
			new_value = happiness
		"curiosity":
			old_value = curiosity
			curiosity = clampf(curiosity + delta, 0.0, 100.0)
			new_value = curiosity
		"health":
			old_value = health
			health = clampf(health + delta, 0.0, 100.0)
			new_value = health
		_:
			return
	if has_node("/root/EventBus") and not is_equal_approx(old_value, new_value):
		get_node("/root/EventBus").need_changed.emit(need_name, old_value, new_value)

func _update_progression() -> void:
	var new_phase: Phase = phase
	for index in range(PHASE_THRESHOLDS.size() - 1, -1, -1):
		if level >= PHASE_THRESHOLDS[index]:
			new_phase = index as Phase
			break
	if new_phase != phase:
		phase = new_phase
		phase_changed.emit(phase)
	var new_era: Era = era
	for index in range(ERA_THRESHOLDS.size() - 1, -1, -1):
		if level >= ERA_THRESHOLDS[index]:
			new_era = index as Era
			break
	if new_era != era:
		era = new_era
		era_changed.emit(era)

func _update_mood() -> void:
	var average := (hunger + energy + happiness + health) / 4.0
	var new_mood := Mood.DISTRESSED
	if average >= 85.0:
		new_mood = Mood.ECSTATIC
	elif average >= 70.0:
		new_mood = Mood.HAPPY
	elif average >= 55.0:
		new_mood = Mood.CONTENT
	elif average >= 40.0:
		new_mood = Mood.NEUTRAL
	elif average >= 25.0:
		new_mood = Mood.TIRED
	elif average >= 10.0:
		new_mood = Mood.SAD
	if new_mood != mood:
		mood = new_mood
		mood_changed.emit(mood)

func _evaluate_evolution() -> void:
	if has_node("/root/EvolutionService"):
		get_node("/root/EvolutionService").evaluate_runtime()

func _read_save(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	return parsed if parsed is Dictionary else {}

func _copy_file(source_path: String, destination_path: String) -> void:
	var source := FileAccess.open(source_path, FileAccess.READ)
	if source == null:
		return
	var destination := FileAccess.open(destination_path, FileAccess.WRITE)
	if destination != null:
		destination.store_buffer(source.get_buffer(source.get_length()))
		destination.close()
	source.close()

func _push_save_failure(reason: String) -> void:
	push_error("[GameState] %s" % reason)
	if has_node("/root/EventBus"):
		get_node("/root/EventBus").save_failed.emit(reason)
