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
const MAX_SAVE_BYTES := 4 * 1024 * 1024
const IdentityMigration := preload("res://scripts/social/bitling_identity.gd")

# All fields are optional for older saves. Present fields must match their
# domain shape before ANY live state or service is changed.
const SAVE_SHAPE: Dictionary = {
	"schema_version": "integer", "level": "integer", "xp": "integer", "total_xp": "integer",
	"phase": "integer", "era": "integer", "mood": "integer", "play_time_seconds": "number",
	"play_time": "number", "days_played": "integer", "hunger": "number", "energy": "number",
	"happiness": "number", "curiosity": "number", "health": "number", "skill_points": "integer",
	"memories": [{"type": "string", "text": "string", "timestamp": "integer", "day": "integer", "level": "integer"}],
	"story_flags": "dictionary", "last_saved_at": "string",
	"settings": {
		"music_volume": "number", "sfx_volume": "number", "notifications_enabled": "bool",
		"quiet_hours_start": "integer", "quiet_hours_end": "integer", "haptics_enabled": "bool",
		"language": "string", "theme": "string", "font_scale": "number", "high_contrast": "bool",
		"reduce_motion": "bool", "screen_reader": "bool", "auto_save": "bool",
		"social_discovery_enabled": "bool", "voice_chat_enabled": "bool", "video_chat_enabled": "bool", "share_public_passport": "bool"
	},
	"streak": {"current_streak": "integer", "longest_streak": "integer", "last_active_date": "string", "streak_repairs": "integer", "pending_missed_days": "integer"},
	"quests": {"active_date": "string", "active_quests": [{"id": "string", "title": "string", "event": "string", "target": "integer", "xp": "integer", "weight": "integer", "progress": "integer", "completed": "bool", "claimed": "bool"}]},
	"companion": {
		"relationship_score": "number", "trust": "number", "familiarity": "number", "current_intention": "string",
		"last_interaction": "string", "last_interaction_timestamp": "integer", "interaction_counts": "numbers", "personality": "numbers",
		"recent_interactions": [{"action": "string", "timestamp": "integer", "context": "dictionary"}]
	},
	"identity": IdentityMigration.SAVE_IMPORT_SHAPE,
	"development": {
		"save_version": "integer", "intelligence_quotient": "integer", "iq_growth_points": "number", "attributes": "numbers",
		"skills": {"*": {"level": "integer", "xp": "number", "rating": "number"}}, "abilities": "booleans",
		"specializations": {"*": {"xp": "number", "rank": "integer"}}, "upbringing": "numbers",
		"preferences": {"hobbies": "strings", "favorite_food": "string", "favorite_topic": "string", "conversation_style": "string"},
		"favorite_bitling_id": "string", "favorite_bitling_affinity": "number", "player_age_band": "string",
		"social_history": {"*": {"encounters": "integer", "last_affinity": "number", "best_affinity": "number", "last_seen_at": "integer"}},
		"rarity": {"tier": "string", "growth_multiplier": "number", "roll": "integer", "visual": {"shimmer": "number", "glow": "number", "sparkles": "bool", "hue_shift": "number"}}
	},
	"emotion": {"valence": "number", "arousal": "number", "social_safety": "number", "confidence": "number", "empathy": "number", "emotion_weights": "numbers", "recent_events": [{"event_id": "string", "intensity": "number", "context": "dictionary", "timestamp": "integer"}]},
	"learning": {"challenge_counter": "integer", "skills": {"*": {"rating": "number", "attempts": "integer", "successes": "integer", "current_streak": "integer", "best_streak": "integer", "last_difficulty": "integer", "last_response_seconds": "number", "last_played_at": "integer"}}},
	"evolution": {"current_form": "string", "discovered_forms": "strings", "evolution_history": [{"from": "string", "to": "string", "timestamp": "integer"}]},
	"vitality": {"last_update_unix": "integer"},
	"exploration": {"completed_expeditions": "integer", "discovered_events": "strings", "choice_history": [{"event": "string", "choice": "integer", "xp": "integer", "timestamp": "integer"}], "expedition_counter": "integer"},
	"dialogue": {"recent_line_ids": "strings", "recent_text_hashes": "integers", "trigger_counts": "numbers"},
	"lineage": {"last_egg_created_at": "integer", "lineage_history": [{"event": "string", "egg_id": "string", "hatchling_id": "string", "timestamp": "integer"}], "eggs": [{
		"accepted": "bool", "egg_id": "string", "created_at": "integer", "generation": "integer", "parent_ids": "strings", "parent_names": "strings",
		"incubation": "number", "ready": "bool", "hatched": "bool", "origin_session": "string", "hatched_at": "integer", "hatchling_id": "string",
		"genome": {"curiosity": "number", "creativity": "number", "empathy": "number", "courage": "number", "humor": "number", "order": "number", "independence": "number", "color_seed": "integer", "voice_seed": "integer", "quirk_seed": "integer", "inherited_forms": "strings"}
	}]}
}

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
var save_blocked: bool = false
var storage_status: String = "new"
var storage_message: String = "Noch nicht gespeichert."
var _loading_state: bool = false

signal state_changed(key: String, value: Variant)
signal level_up(new_level: int)
signal phase_changed(new_phase: Phase)
signal era_changed(new_era: Era)
signal mood_changed(new_mood: Mood)

func _ready() -> void:
	var loaded := load_game_state()
	if save_blocked:
		return
	if not loaded:
		initialize_new_game()
	_register_daily_activity()
	_evaluate_evolution()
	_refresh_identity_and_emotion()
	if has_node("/root/SocialSessionService"):
		get_node("/root/SocialSessionService").reset_state()

func _process(delta: float) -> void:
	if save_blocked:
		return
	play_time_seconds += maxf(delta, 0.0)
	_autosave_elapsed += maxf(delta, 0.0)
	if _autosave_elapsed >= AUTOSAVE_INTERVAL_SECONDS:
		_autosave_elapsed = 0.0
		if bool(settings.get("auto_save", true)):
			save_game_state()

func initialize_new_game() -> void:
	if save_blocked:
		return
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
	if save_blocked or bool(story_flags.get("hatched", false)):
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
	if save_blocked or amount <= 0 or level >= MAX_LEVEL:
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
	if save_blocked or interaction_id.is_empty():
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
	if save_blocked or not bool(result.get("accepted", false)):
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
	if save_blocked:
		return
	_apply_need_delta("hunger", hunger_delta)
	_apply_need_delta("energy", energy_delta)
	_apply_need_delta("happiness", happiness_delta)
	_apply_need_delta("curiosity", curiosity_delta)
	_apply_need_delta("health", health_delta)
	_update_mood()
	_refresh_identity_and_emotion()
	state_changed.emit("stats", get_state_summary())

func add_memory(type: String, text: String) -> void:
	if save_blocked or type.is_empty() or text.is_empty():
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
	if _loading_state:
		return false
	if save_blocked:
		_push_save_failure(storage_message)
		return false
	var snapshots := _scan_saves()
	if _contains_status(snapshots, "future"):
		return _block_storage("Spielstand einer neueren Version erkannt. Vorhandene Dateien bleiben unverändert.")
	var valid_exists := _contains_status(snapshots, "valid")
	if not valid_exists and _contains_status(snapshots, "invalid"):
		return _block_storage("Der Spielstand ist beschädigt; ohne gültige Sicherung ist Speichern gesperrt.")
	_refresh_identity_and_emotion()
	var outgoing := get_save_data()
	if not _is_supported_save(outgoing):
		_push_save_failure("Der aktuelle Zustand ist ungültig. Vorhandene Dateien bleiben unverändert.")
		return false
	var serialized := JSON.stringify(outgoing)
	if serialized.to_utf8_buffer().size() > MAX_SAVE_BYTES:
		_push_save_failure("Der Spielstand überschreitet das Speicherlimit.")
		return false
	var main: Dictionary = snapshots[SAVE_PATH]
	var backup: Dictionary = snapshots[BACKUP_SAVE_PATH]
	var pending: Dictionary = snapshots[TEMP_SAVE_PATH]
	var recover_pending: bool = pending.status == "valid" and main.status != "valid" and backup.status != "valid"
	var damaged_paths: Array[String] = []
	for path: String in [SAVE_PATH, BACKUP_SAVE_PATH]:
		if snapshots[path].status == "invalid":
			if FileAccess.file_exists(path + ".damaged") or DirAccess.dir_exists_absolute(path + ".damaged"):
				return _block_storage("Eine beschädigte Originaldatei ist bereits gesichert. Bitte die Spielstände prüfen; es wird nichts überschrieben.")
			damaged_paths.append(path)
	if recover_pending:
		if not _preserve_damaged(damaged_paths):
			return false
		if DirAccess.rename_absolute(TEMP_SAVE_PATH, SAVE_PATH) != OK:
			_push_save_failure("Die temporäre Wiederherstellung konnte nicht übernommen werden. Ihre Daten bleiben erhalten.")
			return false
		main = _inspect_save(SAVE_PATH)
		if main.status != "valid":
			_push_save_failure("Die temporäre Wiederherstellung konnte nicht bestätigt werden.")
			return false
	var temporary := FileAccess.open(TEMP_SAVE_PATH, FileAccess.WRITE)
	if temporary == null:
		_push_save_failure("Die temporäre Spielstanddatei ist nicht schreibbar.")
		return false
	temporary.store_string(serialized)
	temporary.flush()
	var write_error := temporary.get_error()
	temporary.close()
	if write_error != OK or _inspect_save(TEMP_SAVE_PATH).status != "valid" or FileAccess.get_file_as_string(TEMP_SAVE_PATH) != serialized:
		_push_save_failure("Der neue Spielstand konnte nicht vollständig bestätigt werden. Bisherige Daten bleiben erhalten.")
		return false
	if not recover_pending and not _preserve_damaged(damaged_paths):
		return false
	if main.status == "valid":
		if DirAccess.rename_absolute(SAVE_PATH, BACKUP_SAVE_PATH) != OK:
			_push_save_failure("Die vorherige Generation konnte nicht gesichert werden.")
			return false
	if DirAccess.rename_absolute(TEMP_SAVE_PATH, SAVE_PATH) != OK:
		_push_save_failure("Der neue Spielstand konnte nicht übernommen werden. Gültige Wiederherstellungsdaten bleiben erhalten.")
		return false
	if _inspect_save(SAVE_PATH).status != "valid" or FileAccess.get_file_as_string(SAVE_PATH) != serialized:
		_push_save_failure("Der gespeicherte Spielstand konnte nicht bestätigt werden.")
		return false
	storage_status = "saved"
	storage_message = "Lokal gespeichert."
	if not damaged_paths.is_empty():
		storage_message += " Beschädigte Originaldateien wurden erhalten."
	if has_node("/root/EventBus"):
		get_node("/root/EventBus").save_completed.emit(SAVE_PATH)
	return true

func load_game_state() -> bool:
	if save_blocked:
		return false
	var snapshots := _scan_saves()
	if _contains_status(snapshots, "future"):
		return _block_storage("Dieser Spielstand stammt aus einer neueren Version. Speichern ist gesperrt; die Dateien bleiben unverändert.")
	# Prefer a committed generation. A pending file can be stale and is used
	# only when no main, backup or compatible legacy generation survives.
	for path: String in [SAVE_PATH, BACKUP_SAVE_PATH, LEGACY_SAVE_PATH, TEMP_SAVE_PATH]:
		var snapshot: Dictionary = snapshots[path]
		if snapshot.status != "valid":
			continue
		if not apply_save_data(snapshot.data):
			continue
		storage_status = "loaded" if path == SAVE_PATH else "recovered"
		storage_message = "Spielstand geladen." if path == SAVE_PATH else "Gültiger Spielstand wiederhergestellt. Vorhandene Originaldateien bleiben erhalten."
		if path == LEGACY_SAVE_PATH:
			save_game_state()
		return true
	if _contains_status(snapshots, "invalid"):
		return _block_storage("Der Spielstand ist nicht lesbar und es gibt keine gültige Sicherung. Speichern ist gesperrt.")
	storage_status = "new"
	storage_message = "Neues Abenteuer."
	return false

func _scan_saves() -> Dictionary:
	var result: Dictionary = {}
	for path: String in [SAVE_PATH, BACKUP_SAVE_PATH, LEGACY_SAVE_PATH, TEMP_SAVE_PATH]:
		result[path] = _inspect_save(path)
	return result

func _contains_status(snapshots: Dictionary, status: String) -> bool:
	for snapshot: Dictionary in snapshots.values():
		if snapshot.status == status:
			return true
	return false

func _block_storage(message: String) -> bool:
	save_blocked = true
	storage_status = "blocked"
	storage_message = message
	_push_save_failure(message)
	return false

func _preserve_damaged(paths: Array[String]) -> bool:
	for path: String in paths:
		if DirAccess.rename_absolute(path, path + ".damaged") != OK:
			_push_save_failure("Eine beschädigte Originaldatei konnte nicht erhalten werden. Speichern wurde angehalten.")
			return false
	return true

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

func apply_save_data(data: Dictionary) -> bool:
	if save_blocked or not _is_supported_save(data):
		return false
	_loading_state = true
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
	_loading_state = false
	state_changed.emit("loaded", true)
	return true

func has_save_file() -> bool:
	return FileAccess.file_exists(SAVE_PATH) or FileAccess.file_exists(BACKUP_SAVE_PATH) or FileAccess.file_exists(LEGACY_SAVE_PATH) or FileAccess.file_exists(TEMP_SAVE_PATH)

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
	var snapshot := _inspect_save(path)
	return snapshot.data if snapshot.status == "valid" else {}

func _inspect_save(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {"status": "invalid" if DirAccess.dir_exists_absolute(path) else "missing", "data": {}}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {"status": "invalid", "data": {}}
	if file.get_length() <= 0 or file.get_length() > MAX_SAVE_BYTES:
		file.close()
		return {"status": "invalid", "data": {}}
	var parsed: Variant
	if path == LEGACY_SAVE_PATH and not _legacy_file_looks_like_json(path):
		# Legacy saves contain data dictionaries. Never instantiate objects from
		# file contents while migrating the previous binary format.
		parsed = file.get_var(false)
	else:
		var parser := JSON.new()
		if parser.parse(file.get_as_text()) != OK:
			file.close()
			return {"status": "invalid", "data": {}}
		parsed = parser.data
	file.close()
	if not parsed is Dictionary:
		return {"status": "invalid", "data": {}}
	var schema: Variant = parsed.get("schema_version", 0)
	if (schema is int or schema is float) and is_finite(float(schema)) and float(schema) > SAVE_SCHEMA_VERSION:
		return {"status": "future", "data": {}}
	if not _is_supported_save(parsed):
		return {"status": "invalid", "data": {}}
	return {"status": "valid", "data": parsed}

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
	if data.is_empty() or not (data.has("level") or data.has("story_flags")):
		return false
	var schema: Variant = data.get("schema_version", 0)
	if not _matches_shape(schema, "integer") or int(schema) < 0 or int(schema) > SAVE_SCHEMA_VERSION:
		return false
	# First bound and validate every nested value, including extension fields.
	# Then validate the known structures used by every imported service.
	return _safe_json_value(data, 0) and _matches_shape(data, SAVE_SHAPE)

func _safe_json_value(value: Variant, depth: int) -> bool:
	if depth > 16:
		return false
	if value == null or value is bool:
		return true
	if value is String:
		return value.length() <= 131072
	if value is int or value is float:
		return is_finite(float(value)) and absf(float(value)) <= 9007199254740991.0
	if value is Array:
		if value.size() > 5000:
			return false
		for item: Variant in value:
			if not _safe_json_value(item, depth + 1):
				return false
		return true
	if value is Dictionary:
		if value.size() > 5000:
			return false
		for key: Variant in value:
			if not key is String or not _safe_json_value(key, depth + 1) or not _safe_json_value(value[key], depth + 1):
				return false
		return true
	return false

func _matches_shape(value: Variant, shape: Variant) -> bool:
	if shape is Dictionary:
		if not value is Dictionary:
			return false
		if shape.has("*"):
			for child: Variant in value.values():
				if not _matches_shape(child, shape["*"]):
					return false
		else:
			for key: String in shape:
				if value.has(key) and not _matches_shape(value[key], shape[key]):
					return false
		return true
	if shape is Array:
		if not value is Array:
			return false
		for child: Variant in value:
			if not _matches_shape(child, shape[0]):
				return false
		return true
	match str(shape):
		"number": return (value is int or value is float) and is_finite(float(value))
		"integer": return (value is int or value is float) and is_finite(float(value)) and float(value) == floor(float(value)) and absf(float(value)) <= 9007199254740991.0
		"string": return value is String
		"bool": return value is bool
		"dictionary": return value is Dictionary
		"numbers", "booleans":
			if not value is Dictionary:
				return false
			for child: Variant in value.values():
				if not _matches_shape(child, "number" if shape == "numbers" else "bool"):
					return false
			return true
		"strings", "integers":
			if not value is Array:
				return false
			for child: Variant in value:
				if not _matches_shape(child, "string" if shape == "strings" else "integer"):
					return false
			return true
	return false

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
	storage_message = reason
	if not save_blocked:
		storage_status = "error"
	push_warning("[GameState] %s" % reason)
	if has_node("/root/EventBus"):
		get_node("/root/EventBus").save_failed.emit(reason)
