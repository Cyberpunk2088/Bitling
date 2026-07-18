extends Node

## Authoritative persistent state for BITLING OMNI.
## Domain services expose export_state/import_state contracts; UI never owns saves.

enum Phase { EGG, BABY, CHILD, TEEN, ADULT, SENIOR, LEGENDARY }
enum Era { TERMINAL, PIXEL, VECTOR, FLAT, FLUID }
enum Mood { ECSTATIC, HAPPY, CONTENT, NEUTRAL, TIRED, SAD, DISTRESSED }

const SAVE_SCHEMA_VERSION := 9
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
	"notifications_enabled": false,
	"quiet_hours_start": 22,
	"quiet_hours_end": 8,
	"haptics_enabled": true,
	"language": "de",
	"theme": "system",
	"font_scale": 1.0,
	"high_contrast": false,
	"reduce_motion": false,
	"screen_reader": false,
	"auto_save": true,
	"social_discovery_enabled": false,
	"voice_chat_enabled": false,
	"video_chat_enabled": false,
	"share_public_passport": false
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
	_refresh_identity_and_emotion()
	if has_node("/root/SocialSessionService"):
		get_node("/root/SocialSessionService").reset_state()

func _process(delta: float) -> void:
	play_time_seconds += maxf(delta, 0.0)
	_autosave_elapsed += maxf(delta, 0.0)
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

	for service_path in [
		"/root/CompanionBrain",
		"/root/BitlingIdentity",
		"/root/EmotionModel",
		"/root/AdaptiveLearning",
		"/root/EvolutionService",
		"/root/VitalityService",
		"/root/ExplorationService",
		"/root/DialogueDirector",
		"/root/LineageService",
		"/root/SocialSessionService"
	]:
		if has_node(service_path):
			var service := get_node(service_path)
			if service.has_method("reset_state"):
				service.reset_state()

	# DevelopmentProfile listens for this signal and resets against the newly
	# created Bitling identity before the authoritative save is written.
	state_changed.emit("new_game", true)
	add_memory("awakening", "A faint signal appeared in the dark.")
	_refresh_identity_and_emotion()
	save_game_state()

func hatch() -> void:
	if bool(story_flags.get("hatched", false)):
		return
	story_flags["hatched"] = true
	level = maxi(level, 10)
	phase = Phase.BABY
	add_memory("birth", "The screen flickered, and there I was.")
	phase_changed.emit(phase)
	state_changed.emit("hatched", true)
	_evaluate_evolution()
	_refresh_identity_and_emotion()
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
	_refresh_identity_and_emotion()

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
	if has_node("/root/EmotionModel"):
		get_node("/root/EmotionModel").apply_event(_emotion_event_for_interaction(interaction_id), 1.0, {"tags": tags})
	if has_node("/root/QuestService"):
		var event_name := str(effects.get("quest_event", ""))
		if not event_name.is_empty():
			get_node("/root/QuestService").record_event(event_name)
	if has_node("/root/EventBus"):
		get_node("/root/EventBus").interaction_completed.emit(interaction_id, tags)
	_evaluate_evolution()
	_refresh_identity_and_emotion()
	var summary := get_state_summary()
	state_changed.emit("interaction", {"id": interaction_id, "state": summary})
	return summary

func apply_learning_result(result: Dictionary) -> Dictionary:
	if not bool(result.get("accepted", false)):
		return get_state_summary()
	var success := bool(result.get("success", false))
	var reward := maxi(int(result.get("xp_reward", 0)), 0)
	var tags: Array[String] = ["learn", "growth", "challenge_result"]
	var effects := {
		"energy": -4.0,
		"happiness": 5.0 if success else 2.0,
		"curiosity": 12.0 if success else 5.0,
		"quest_event": "discovery_completed"
	}
	return perform_interaction("learning_result", effects, reward, tags)

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
	_refresh_identity_and_emotion()
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
	while memories.size() > 50:
		memories.pop_front()
	if has_node("/root/EventBus"):
		get_node("/root/EventBus").memory_created.emit(memory.duplicate(true))

func save_game_state() -> bool:
	_refresh_identity_and_emotion()
	var temporary := FileAccess.open(TEMP_SAVE_PATH, FileAccess.WRITE)
	if temporary == null:
		_push_save_failure("Could not open temporary save file")
		return false
	temporary.store_string(JSON.stringify(get_save_data()))
	temporary.close()

	# Preserve only a known-good primary as backup. A corrupt primary must never
	# replace the last recoverable snapshot.
	if FileAccess.file_exists(SAVE_PATH) and not _read_save(SAVE_PATH).is_empty():
		_copy_file(SAVE_PATH, BACKUP_SAVE_PATH)
	if FileAccess.file_exists(SAVE_PATH):
		var remove_error := DirAccess.remove_absolute(SAVE_PATH)
		if remove_error != OK:
			_push_save_failure("Could not replace existing save: %s" % remove_error)
			return false

	var rename_error := DirAccess.rename_absolute(TEMP_SAVE_PATH, SAVE_PATH)
	if rename_error != OK:
		if FileAccess.file_exists(BACKUP_SAVE_PATH):
			_copy_file(BACKUP_SAVE_PATH, SAVE_PATH)
		_push_save_failure("Atomic save replacement failed: %s" % rename_error)
		return false
	if has_node("/root/EventBus"):
		get_node("/root/EventBus").save_completed.emit(SAVE_PATH)
	return true

func load_game_state() -> bool:
	for path in [SAVE_PATH, BACKUP_SAVE_PATH, LEGACY_SAVE_PATH]:
		var data := _read_save(path)
		if data.is_empty():
			continue
		apply_save_data(data)
		if path == LEGACY_SAVE_PATH:
			save_game_state()
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
		"streak": _export_service("/root/StreakService"),
		"quests": _export_service("/root/QuestService"),
		"companion": _export_service("/root/CompanionBrain"),
		"identity": _export_service("/root/BitlingIdentity"),
		"development": _export_service("/root/DevelopmentProfile"),
		"emotion": _export_service("/root/EmotionModel"),
		"learning": _export_service("/root/AdaptiveLearning"),
		"evolution": _export_service("/root/EvolutionService"),
		"vitality": _export_service("/root/VitalityService"),
		"exploration": _export_service("/root/ExplorationService"),
		"dialogue": _export_service("/root/DialogueDirector"),
		"lineage": _export_service("/root/LineageService"),
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
	while memories.size() > 50:
		memories.pop_front()

	story_flags = data.get("story_flags", {}).duplicate(true)
	settings.merge(data.get("settings", {}), true)
	_import_service("/root/StreakService", data.get("streak", {}))
	_import_service("/root/QuestService", data.get("quests", {}))
	_import_service("/root/CompanionBrain", data.get("companion", {}))
	_import_service("/root/BitlingIdentity", data.get("identity", {}))
	if data.has("development"):
		_import_service("/root/DevelopmentProfile", data.get("development", {}))
	_import_service("/root/EmotionModel", data.get("emotion", {}))
	_import_service("/root/AdaptiveLearning", data.get("learning", {}))
	_import_service("/root/EvolutionService", data.get("evolution", {}))
	_import_service("/root/ExplorationService", data.get("exploration", {}))
	_import_service("/root/DialogueDirector", data.get("dialogue", {}))
	_import_service("/root/VitalityService", data.get("vitality", {}))
	_import_service("/root/LineageService", data.get("lineage", {}))
	if has_node("/root/SocialSessionService"):
		get_node("/root/SocialSessionService").reset_state()
	_update_progression()
	_update_mood()
	_evaluate_evolution()
	_refresh_identity_and_emotion()
	state_changed.emit("loaded", true)

func has_save_file() -> bool:
	return FileAccess.file_exists(SAVE_PATH) or FileAccess.file_exists(BACKUP_SAVE_PATH) or FileAccess.file_exists(LEGACY_SAVE_PATH)

func get_state_summary() -> Dictionary:
	var form_id := "signal"
	if has_node("/root/EvolutionService"):
		form_id = str(get_node("/root/EvolutionService").current_form)
	var passport: Dictionary = {}
	if has_node("/root/BitlingIdentity"):
		passport = get_node("/root/BitlingIdentity").get_public_passport()
	var emotion_snapshot: Dictionary = {}
	if has_node("/root/EmotionModel"):
		emotion_snapshot = get_node("/root/EmotionModel").get_snapshot()
	var individual_iq := int(passport.get("intelligence_quotient", 100))
	if has_node("/root/DevelopmentProfile"):
		individual_iq = int(get_node("/root/DevelopmentProfile").get_intelligence_quotient())
	return {
		"level": level,
		"xp": xp,
		"phase": Phase.keys()[phase],
		"era": Era.keys()[era],
		"mood": Mood.keys()[mood],
		"form": form_id,
		"bitling_id": passport.get("bitling_id", ""),
		"intelligence_quotient": individual_iq,
		"dominant_emotion": emotion_snapshot.get("dominant_emotion", "calm"),
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

func _refresh_identity_and_emotion() -> void:
	var form_id := "signal"
	if has_node("/root/EvolutionService"):
		form_id = str(get_node("/root/EvolutionService").current_form)
	var learning_rating := 20.0
	if has_node("/root/AdaptiveLearning"):
		learning_rating = float(get_node("/root/AdaptiveLearning").get_average_rating())
	if has_node("/root/BitlingIdentity"):
		get_node("/root/BitlingIdentity").refresh_development_metrics(
			level,
			str(Phase.keys()[phase]),
			form_id,
			learning_rating,
			curiosity
		)
	if has_node("/root/EmotionModel"):
		var relationship := 10.0
		var trust := 10.0
		if has_node("/root/CompanionBrain"):
			relationship = float(get_node("/root/CompanionBrain").relationship_score)
			trust = float(get_node("/root/CompanionBrain").trust)
		get_node("/root/EmotionModel").update_from_game_state(str(Mood.keys()[mood]), relationship, trust)

func _emotion_event_for_interaction(interaction_id: String) -> String:
	if interaction_id.begins_with("care"):
		return "care"
	if interaction_id.begins_with("play") or interaction_id.begins_with("exploration"):
		return "play"
	if interaction_id.contains("learn"):
		return "learn"
	if interaction_id.begins_with("rest"):
		return "rest"
	return interaction_id

func _export_service(path: String) -> Dictionary:
	if not has_node(path):
		return {}
	var service := get_node(path)
	return service.export_state() if service.has_method("export_state") else {}

func _import_service(path: String, data: Variant) -> void:
	if has_node(path) and data is Dictionary:
		var service := get_node(path)
		if service.has_method("import_state"):
			service.import_state(data)

func _read_save(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}

	# Legacy .dat files may be Variant-encoded binary. Detect that format before
	# any UTF-8 conversion so malformed or binary input never pollutes engine logs.
	if path == LEGACY_SAVE_PATH and not _legacy_file_looks_like_json(path):
		var legacy := FileAccess.open(path, FileAccess.READ)
		if legacy == null:
			return {}
		var legacy_value: Variant = legacy.get_var(true)
		legacy.close()
		return legacy_value if legacy_value is Dictionary and _is_supported_save(legacy_value) else {}

	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var text := file.get_as_text()
	file.close()
	var parser := JSON.new()
	if parser.parse(text) != OK:
		return {}
	var parsed: Variant = parser.data
	return parsed if parsed is Dictionary and _is_supported_save(parsed) else {}

func _legacy_file_looks_like_json(path: String) -> bool:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return false
	while file.get_position() < file.get_length():
		var value := file.get_8()
		if value in [9, 10, 13, 32]:
			continue
		file.close()
		return value == 123 or value == 91
	file.close()
	return false

func _is_supported_save(data: Dictionary) -> bool:
	if data.is_empty():
		return false
	var schema := int(data.get("schema_version", 0))
	if schema > SAVE_SCHEMA_VERSION:
		return false
	return data.has("level") or data.has("story_flags") or schema > 0

func _copy_file(source_path: String, destination_path: String) -> bool:
	var source := FileAccess.open(source_path, FileAccess.READ)
	if source == null:
		return false
	var destination := FileAccess.open(destination_path, FileAccess.WRITE)
	if destination == null:
		source.close()
		return false
	destination.store_buffer(source.get_buffer(source.get_length()))
	destination.close()
	source.close()
	return true

func _push_save_failure(reason: String) -> void:
	push_error("[GameState] %s" % reason)
	if has_node("/root/EventBus"):
		get_node("/root/EventBus").save_failed.emit(reason)
