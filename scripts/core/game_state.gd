extends Node

## Persistent source of truth for BITLING OMNI.
## UI and gameplay systems communicate through methods and EventBus signals.

enum Phase { EGG, BABY, CHILD, TEEN, ADULT, SENIOR, LEGENDARY }
enum Era { TERMINAL, PIXEL, VECTOR, FLAT, FLUID }
enum Mood { ECSTATIC, HAPPY, CONTENT, NEUTRAL, TIRED, SAD, DISTRESSED }

const SAVE_SCHEMA_VERSION := 3
const MAX_LEVEL := 100
const XP_PER_LEVEL := 100
const SAVE_PATH := "user://bitling_save.json"
const LEGACY_SAVE_PATH := "user://bitling_save.dat"
const TEMP_SAVE_PATH := "user://bitling_save.tmp"
const BACKUP_SAVE_PATH := "user://bitling_save.backup.json"
const PHASE_THRESHOLDS := [0, 10, 25, 40, 60, 80, 95]
const ERA_THRESHOLDS := [0, 15, 35, 55, 75]

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

signal state_changed(key: String, value: Variant)
signal level_up(new_level: int)
signal phase_changed(new_phase: Phase)
signal era_changed(new_era: Era)
signal mood_changed(new_mood: Mood)

func _ready() -> void:
	load_game_state()
	if not has_save_file():
		initialize_new_game()
	_register_daily_activity()

func _process(delta: float) -> void:
	play_time_seconds += delta

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
	add_memory("awakening", "A faint signal appeared in the dark.")
	save_game_state()

func hatch() -> void:
	if story_flags.get("hatched", false):
		return
	story_flags["hatched"] = true
	level = maxi(level, 10)
	phase = Phase.BABY
	add_memory("birth", "The screen flickered, and there I was.")
	phase_changed.emit(phase)
	state_changed.emit("hatched", true)
	save_game_state()

func gain_xp(amount: int, source: String = "unknown") -> void:
	if amount <= 0 or level >= MAX_LEVEL:
		return
	xp += amount
	total_xp += amount
	while xp >= XP_PER_LEVEL and level < MAX_LEVEL:
		xp -= XP_PER_LEVEL
		level += 1
		skill_points += 1
		level_up.emit(level)
		_update_progression()
	state_changed.emit("xp", xp)
	if has_node("/root/EventBus"):
		get_node("/root/EventBus").xp_gained.emit(amount, source)

func update_stats(hunger_delta := 0.0, energy_delta := 0.0, happiness_delta := 0.0) -> void:
	hunger = clampf(hunger + hunger_delta, 0.0, 100.0)
	energy = clampf(energy + energy_delta, 0.0, 100.0)
	happiness = clampf(happiness + happiness_delta, 0.0, 100.0)
	_update_mood()
	state_changed.emit("stats", get_state_summary())

func add_memory(type: String, text: String) -> void:
	if memories.any(func(item: Dictionary) -> bool: return item.get("type") == type and item.get("text") == text):
		return
	memories.append({
		"type": type,
		"text": text,
		"timestamp": Time.get_unix_time_from_system(),
		"day": days_played,
		"level": level
	})
	if memories.size() > 50:
		memories.pop_front()

func save_game_state() -> bool:
	var json := JSON.stringify(get_save_data())
	var temporary := FileAccess.open(TEMP_SAVE_PATH, FileAccess.WRITE)
	if temporary == null:
		push_error("[GameState] Could not open temporary save file")
		return false
	temporary.store_string(json)
	temporary.close()

	if FileAccess.file_exists(SAVE_PATH):
		_copy_file(SAVE_PATH, BACKUP_SAVE_PATH)
	DirAccess.remove_absolute(SAVE_PATH)
	var rename_error := DirAccess.rename_absolute(TEMP_SAVE_PATH, SAVE_PATH)
	if rename_error != OK:
		push_error("[GameState] Atomic save replacement failed: %s" % rename_error)
		return false
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
		"streak": StreakService.export_state() if has_node("/root/StreakService") else {},
		"quests": QuestService.export_state() if has_node("/root/QuestService") else {},
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
	memories.assign(data.get("memories", []))
	story_flags = data.get("story_flags", {})
	settings.merge(data.get("settings", {}), true)
	if has_node("/root/StreakService"):
		StreakService.import_state(data.get("streak", {}))
	if has_node("/root/QuestService"):
		QuestService.import_state(data.get("quests", {}))
	_update_progression()
	_update_mood()
	state_changed.emit("loaded", true)

func has_save_file() -> bool:
	return FileAccess.file_exists(SAVE_PATH) or FileAccess.file_exists(LEGACY_SAVE_PATH)

func get_state_summary() -> Dictionary:
	return {
		"level": level,
		"phase": Phase.keys()[phase],
		"era": Era.keys()[era],
		"mood": Mood.keys()[mood],
		"hunger": hunger,
		"energy": energy,
		"happiness": happiness
	}

func _register_daily_activity() -> void:
	if has_node("/root/StreakService"):
		StreakService.register_activity()
	if has_node("/root/QuestService"):
		QuestService.ensure_daily_quests("local-profile")

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
	var average := (hunger + energy + happiness) / 3.0
	var new_mood := Mood.DISTRESSED
	if average >= 85.0: new_mood = Mood.ECSTATIC
	elif average >= 70.0: new_mood = Mood.HAPPY
	elif average >= 55.0: new_mood = Mood.CONTENT
	elif average >= 40.0: new_mood = Mood.NEUTRAL
	elif average >= 25.0: new_mood = Mood.TIRED
	elif average >= 10.0: new_mood = Mood.SAD
	if new_mood != mood:
		mood = new_mood
		mood_changed.emit(mood)

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
