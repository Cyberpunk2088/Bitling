extends Node

## Individual development model for one Bitling. IQ, attributes, skills,
## preferences and upbringing belong to the Bitling, never to the player.

signal profile_changed(snapshot: Dictionary)
signal specialization_ranked_up(specialization_id: String, rank_name: String)
signal ability_unlocked(ability_id: String)
signal favorite_bitling_changed(bitling_id: String)

const SAVE_VERSION := 1
const SAVE_PATH := "user://bitling_development.json"
const TEMP_PATH := "user://bitling_development.tmp"
const BACKUP_PATH := "user://bitling_development.backup.json"

const RANK_BRONZE := 0
const RANK_SILVER := 1
const RANK_GOLD := 2
const RANK_PLATINUM := 3
const RANK_NAMES := ["BRONZE", "SILBER", "GOLD", "PLATIN"]
const RANK_THRESHOLDS := [0.0, 200.0, 600.0, 1400.0]
const VALID_AGE_BANDS := ["child", "teen", "adult", "senior"]
const HOBBY_POOL := [
	"Muster erforschen", "Musik bauen", "Kochen", "Geschichten erzählen",
	"Sterne beobachten", "Tanzen", "Sammeln", "Rätsel lösen",
	"Gärtnern", "Erfinden", "Malen", "Andere unterrichten"
]
const FOOD_POOL := [
	"Pixelbeeren", "Knisterkekse", "Mondnudeln", "Glitzermais",
	"Signal-Suppe", "Wolkenpudding", "Kometenbrot", "Sternenapfel"
]

var intelligence_quotient: int = 100
var iq_growth_points: float = 0.0
var attributes: Dictionary = {}
var skills: Dictionary = {}
var abilities: Dictionary = {}
var specializations: Dictionary = {}
var upbringing: Dictionary = {}
var preferences: Dictionary = {}
var favorite_bitling_id: String = ""
var favorite_bitling_affinity: float = 0.0
var rarity: Dictionary = {}
var player_age_band: String = "adult"
var social_history: Dictionary = {}

func _ready() -> void:
	if not load_profile():
		reset_state()
	_connect_runtime()
	_sync_identity()

func _connect_runtime() -> void:
	var event_bus: Node = get_node_or_null("/root/EventBus")
	if event_bus != null and not event_bus.interaction_completed.is_connected(_on_interaction_completed):
		event_bus.interaction_completed.connect(_on_interaction_completed)
	call_deferred("_connect_game_state")

func _connect_game_state() -> void:
	var state: Node = get_node_or_null("/root/GameState")
	if state != null and not state.state_changed.is_connected(_on_game_state_changed):
		state.state_changed.connect(_on_game_state_changed)

func reset_state() -> void:
	var identity_id: String = _identity_id()
	var source: String = identity_id if not identity_id.is_empty() else "new-bitling"
	var seed_value: int = int(abs(hash(source)))
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	intelligence_quotient = rng.randi_range(82, 128)
	iq_growth_points = 0.0
	attributes = {
		"intelligence": float(intelligence_quotient), "empathy": rng.randf_range(42.0, 68.0),
		"humor": rng.randf_range(38.0, 72.0), "coordination": rng.randf_range(34.0, 66.0),
		"discipline": rng.randf_range(24.0, 48.0), "creativity": rng.randf_range(45.0, 76.0),
		"charisma": rng.randf_range(36.0, 70.0), "resilience": rng.randf_range(40.0, 70.0),
		"curiosity": rng.randf_range(48.0, 78.0)
	}
	skills = {}
	for skill_id in ["logic", "language", "teaching", "debate", "humor", "cooking", "exploration", "music", "social", "self_care"]:
		skills[skill_id] = {"level": 1, "xp": 0.0, "rating": rng.randf_range(12.0, 30.0)}
	abilities = {}
	specializations = {}
	upbringing = {
		"discipline": 15.0, "routine": 15.0, "independence": 10.0,
		"social_confidence": 12.0, "self_control": 12.0, "teaching_habit": 0.0
	}
	preferences = {
		"hobbies": _pick_unique(HOBBY_POOL, rng, 3),
		"favorite_food": FOOD_POOL[rng.randi_range(0, FOOD_POOL.size() - 1)],
		"favorite_topic": ["Weltraum", "Tiere", "Technik", "Geschichten", "Musik", "Natur"][rng.randi_range(0, 5)],
		"conversation_style": ["witzig", "neugierig", "nachdenklich", "begeistert", "trocken"][rng.randi_range(0, 4)]
	}
	favorite_bitling_id = ""
	favorite_bitling_affinity = 0.0
	rarity = _create_rarity(seed_value)
	player_age_band = "adult"
	social_history = {}
	_update_abilities()
	save_profile()
	_emit_change()

func record_interaction(interaction_id: String, tags: Array[String] = [], quality: float = 1.0) -> void:
	var amount: float = clampf(quality, 0.1, 5.0)
	var normalized: String = interaction_id.to_lower()
	if normalized.contains("learn"):
		_add_skill_xp("logic", 22.0 * amount)
		_shift_attribute("intelligence", 0.08 * amount)
		_shift_attribute("curiosity", 0.18 * amount)
		progress_specialization("researcher", 18.0 * amount)
		_add_iq_growth(1.2 * amount)
	elif normalized.contains("teach"):
		_add_skill_xp("teaching", 28.0 * amount)
		_add_skill_xp("language", 12.0 * amount)
		upbringing["teaching_habit"] = _clamp100(float(upbringing.get("teaching_habit", 0.0)) + 0.5 * amount)
		progress_specialization("mentor", 24.0 * amount)
		_add_iq_growth(0.8 * amount)
	elif normalized.contains("debate") or normalized.contains("discuss"):
		_add_skill_xp("debate", 25.0 * amount)
		_add_skill_xp("language", 14.0 * amount)
		_shift_attribute("charisma", 0.12 * amount)
		progress_specialization("orator", 21.0 * amount)
		_add_iq_growth(0.6 * amount)
	elif normalized.contains("care"):
		_add_skill_xp("self_care", 18.0 * amount)
		_shift_attribute("empathy", 0.22 * amount)
		progress_specialization("caregiver", 16.0 * amount)
	elif normalized.contains("play") or normalized.contains("exploration"):
		_add_skill_xp("exploration", 18.0 * amount)
		_add_skill_xp("humor", 12.0 * amount)
		_shift_attribute("coordination", 0.16 * amount)
		_shift_attribute("humor", 0.12 * amount)
		progress_specialization("adventurer", 17.0 * amount)
	elif normalized.contains("rest"):
		_add_skill_xp("self_care", 12.0 * amount)
		train_upbringing("routine", 0.35 * amount)
		train_upbringing("self_control", 0.25 * amount)

	for tag in tags:
		match tag:
			"music":
				_add_skill_xp("music", 18.0 * amount)
				progress_specialization("musician", 16.0 * amount)
			"cooking", "food":
				_add_skill_xp("cooking", 18.0 * amount)
				progress_specialization("chef", 16.0 * amount)
			"social", "bond":
				_add_skill_xp("social", 12.0 * amount)
				train_upbringing("social_confidence", 0.22 * amount)
			"routine":
				train_upbringing("routine", 0.3 * amount)
			"discipline":
				train_upbringing("discipline", 0.3 * amount)
	_update_abilities()
	save_profile()
	_sync_identity()
	_emit_change()

func train_upbringing(kind: String, amount: float) -> bool:
	if not upbringing.has(kind):
		return false
	upbringing[kind] = _clamp100(float(upbringing[kind]) + maxf(amount, 0.0))
	if kind == "discipline":
		_shift_attribute("discipline", amount * 0.35)
	elif kind == "independence":
		_shift_attribute("resilience", amount * 0.18)
	_update_abilities()
	return true

func progress_specialization(specialization_id: String, amount: float) -> Dictionary:
	if specialization_id.is_empty() or amount <= 0.0:
		return {}
	var entry: Dictionary = specializations.get(specialization_id, {
		"rank": RANK_BRONZE, "xp": 0.0, "started_at": int(Time.get_unix_time_from_system())
	})
	var old_rank: int = int(entry.get("rank", RANK_BRONZE))
	entry["xp"] = maxf(float(entry.get("xp", 0.0)) + amount, 0.0)
	entry["rank"] = _rank_for_xp(float(entry["xp"]))
	entry["updated_at"] = int(Time.get_unix_time_from_system())
	specializations[specialization_id] = entry
	var new_rank: int = int(entry["rank"])
	if new_rank > old_rank:
		specialization_ranked_up.emit(specialization_id, get_rank_name(new_rank))
	return entry.duplicate(true)

func get_rank_name(rank: int) -> String:
	return RANK_NAMES[clampi(rank, RANK_BRONZE, RANK_PLATINUM)]

func get_autonomy_score() -> float:
	return clampf(
		float(upbringing.get("discipline", 0.0)) * 0.24
		+ float(upbringing.get("routine", 0.0)) * 0.24
		+ float(upbringing.get("independence", 0.0)) * 0.26
		+ float(upbringing.get("self_control", 0.0)) * 0.16
		+ _skill_rating("self_care") * 0.10,
		0.0, 100.0
	)

func get_autonomous_action_efficiency() -> float:
	return clampf(0.35 + get_autonomy_score() / 135.0, 0.35, 1.0)

func can_self_entertain() -> bool:
	return get_autonomy_score() >= 35.0

func can_teach_peer() -> bool:
	return get_autonomy_score() >= 58.0 and _skill_rating("teaching") >= 38.0

func choose_autonomous_action(peer_available: bool = false) -> Dictionary:
	var options: Array[Dictionary] = [
		{"id": "practice_hobby", "weight": 20.0, "requires": 0.0},
		{"id": "self_care", "weight": 16.0, "requires": 25.0},
		{"id": "invent_game", "weight": 12.0, "requires": 35.0},
		{"id": "study", "weight": 11.0, "requires": 42.0},
		{"id": "teach_peer", "weight": 15.0 if peer_available else 0.0, "requires": 58.0}
	]
	var autonomy: float = get_autonomy_score()
	var eligible: Array[Dictionary] = []
	for option in options:
		if autonomy >= float(option.get("requires", 0.0)) and float(option.get("weight", 0.0)) > 0.0:
			eligible.append(option)
	if eligible.is_empty():
		return {"id": "wait_for_guidance", "efficiency": 0.25}
	var seed_value: int = hash("%s:%d:%d" % [_identity_id(), int(Time.get_unix_time_from_system() / 300.0), social_history.size()])
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var total: float = 0.0
	for option in eligible:
		total += float(option.get("weight", 0.0))
	var roll: float = rng.randf_range(0.0, total)
	var running: float = 0.0
	for option in eligible:
		running += float(option.get("weight", 0.0))
		if roll <= running:
			return {"id": option.get("id", "practice_hobby"), "efficiency": get_autonomous_action_efficiency()}
	return {"id": "practice_hobby", "efficiency": get_autonomous_action_efficiency()}

func calculate_affinity(peer_profile: Dictionary) -> Dictionary:
	var peer_preferences: Dictionary = peer_profile.get("preferences", {})
	var peer_attributes: Dictionary = peer_profile.get("attributes", {})
	var peer_skills: Dictionary = peer_profile.get("skills", {})
	var hobby_similarity: float = _array_similarity(preferences.get("hobbies", []), peer_preferences.get("hobbies", []))
	var food_match: float = 1.0 if str(preferences.get("favorite_food", "")) == str(peer_preferences.get("favorite_food", "")) else 0.0
	var style_match: float = 1.0 if str(preferences.get("conversation_style", "")) == str(peer_preferences.get("conversation_style", "")) else 0.0
	var attribute_similarity: float = _dictionary_similarity(attributes, peer_attributes)
	var skill_similarity: float = _skill_similarity(skills, peer_skills)
	var score: float = clampf(hobby_similarity * 30.0 + food_match * 12.0 + style_match * 8.0 + attribute_similarity * 30.0 + skill_similarity * 20.0, 0.0, 100.0)
	return {"score": score, "label": _affinity_label(score)}

func register_social_encounter(peer_id: String, peer_profile: Dictionary) -> Dictionary:
	if peer_id.is_empty() or peer_id == _identity_id():
		return {"accepted": false}
	var affinity: Dictionary = calculate_affinity(peer_profile)
	var entry: Dictionary = social_history.get(peer_id, {"encounters": 0, "best_affinity": 0.0})
	entry["encounters"] = int(entry.get("encounters", 0)) + 1
	entry["last_affinity"] = float(affinity.get("score", 0.0))
	entry["best_affinity"] = maxf(float(entry.get("best_affinity", 0.0)), float(affinity.get("score", 0.0)))
	entry["last_seen_at"] = int(Time.get_unix_time_from_system())
	social_history[peer_id] = entry
	if float(affinity.get("score", 0.0)) >= favorite_bitling_affinity and float(affinity.get("score", 0.0)) >= 65.0:
		favorite_bitling_id = peer_id
		favorite_bitling_affinity = float(affinity.get("score", 0.0))
		favorite_bitling_changed.emit(peer_id)
	save_profile()
	_emit_change()
	return {"accepted": true, "affinity": affinity, "favorite": favorite_bitling_id == peer_id}

func choose_conversation_mode(peer_profile: Dictionary = {}) -> String:
	var affinity: float = 50.0
	if not peer_profile.is_empty():
		affinity = float(calculate_affinity(peer_profile).get("score", 50.0))
	if can_teach_peer() and _skill_rating("teaching") >= 55.0:
		return "teach"
	if _skill_rating("debate") >= 50.0 and affinity >= 45.0:
		return "debate"
	if _skill_rating("humor") >= 48.0:
		return "joke"
	if affinity >= 70.0:
		return "discussion"
	if float(attributes.get("charisma", 0.0)) >= 60.0:
		return "monologue"
	return "chat"

func set_player_age_band(value: String) -> bool:
	var normalized: String = value.to_lower()
	if not VALID_AGE_BANDS.has(normalized):
		return false
	player_age_band = normalized
	save_profile()
	_emit_change()
	return true

func get_age_adjusted_style() -> Dictionary:
	match player_age_band:
		"child": return {"vocabulary": "simple", "complexity": 0.35, "max_monologue_seconds": 25, "sensitive_topics": false}
		"teen": return {"vocabulary": "casual", "complexity": 0.65, "max_monologue_seconds": 45, "sensitive_topics": true}
		"senior": return {"vocabulary": "clear", "complexity": 0.72, "max_monologue_seconds": 55, "sensitive_topics": true}
		_: return {"vocabulary": "standard", "complexity": 0.82, "max_monologue_seconds": 60, "sensitive_topics": true}

func get_display_snapshot() -> Dictionary:
	return {
		"intelligence_quotient": intelligence_quotient,
		"attributes": attributes.duplicate(true), "skills": skills.duplicate(true),
		"abilities": abilities.duplicate(true), "specializations": specializations.duplicate(true),
		"upbringing": upbringing.duplicate(true), "autonomy_score": get_autonomy_score(),
		"autonomy_efficiency": get_autonomous_action_efficiency(),
		"preferences": preferences.duplicate(true), "favorite_bitling_id": favorite_bitling_id,
		"favorite_bitling_affinity": favorite_bitling_affinity, "rarity": rarity.duplicate(true),
		"player_age_band": player_age_band, "age_style": get_age_adjusted_style()
	}

func export_state() -> Dictionary:
	return {
		"save_version": SAVE_VERSION, "intelligence_quotient": intelligence_quotient,
		"iq_growth_points": iq_growth_points, "attributes": attributes.duplicate(true),
		"skills": skills.duplicate(true), "abilities": abilities.duplicate(true),
		"specializations": specializations.duplicate(true), "upbringing": upbringing.duplicate(true),
		"preferences": preferences.duplicate(true), "favorite_bitling_id": favorite_bitling_id,
		"favorite_bitling_affinity": favorite_bitling_affinity, "rarity": rarity.duplicate(true),
		"player_age_band": player_age_band, "social_history": social_history.duplicate(true)
	}

func import_state(data: Dictionary) -> void:
	if data.is_empty():
		reset_state()
		return
	intelligence_quotient = clampi(int(data.get("intelligence_quotient", 100)), 40, 220)
	iq_growth_points = maxf(float(data.get("iq_growth_points", 0.0)), 0.0)
	attributes = data.get("attributes", {}).duplicate(true)
	skills = data.get("skills", {}).duplicate(true)
	abilities = data.get("abilities", {}).duplicate(true)
	specializations = data.get("specializations", {}).duplicate(true)
	upbringing = data.get("upbringing", {}).duplicate(true)
	preferences = data.get("preferences", {}).duplicate(true)
	favorite_bitling_id = str(data.get("favorite_bitling_id", ""))
	favorite_bitling_affinity = clampf(float(data.get("favorite_bitling_affinity", 0.0)), 0.0, 100.0)
	rarity = data.get("rarity", {}).duplicate(true)
	player_age_band = str(data.get("player_age_band", "adult"))
	if not VALID_AGE_BANDS.has(player_age_band):
		player_age_band = "adult"
	social_history = data.get("social_history", {}).duplicate(true)
	attributes["intelligence"] = float(intelligence_quotient)
	_update_abilities()
	_sync_identity()
	_emit_change()

func save_profile() -> bool:
	var file := FileAccess.open(TEMP_PATH, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(export_state()))
	file.close()
	if FileAccess.file_exists(SAVE_PATH):
		_copy_file(SAVE_PATH, BACKUP_PATH)
		DirAccess.remove_absolute(SAVE_PATH)
	return DirAccess.rename_absolute(TEMP_PATH, SAVE_PATH) == OK

func load_profile() -> bool:
	for path in [SAVE_PATH, BACKUP_PATH]:
		if not FileAccess.file_exists(path):
			continue
		var file := FileAccess.open(path, FileAccess.READ)
		if file == null:
			continue
		var parsed: Variant = JSON.parse_string(file.get_as_text())
		file.close()
		if parsed is Dictionary:
			import_state(parsed)
			return true
	return false

func get_intelligence_quotient() -> int:
	return intelligence_quotient

func get_rarity_visual_profile() -> Dictionary:
	return rarity.get("visual", {}).duplicate(true)

func has_legendary_language() -> bool:
	return str(rarity.get("tier", "COMMON")) == "LEGENDARY"

func _on_interaction_completed(interaction_id: String, tags: Array[String]) -> void:
	record_interaction(interaction_id, tags, 1.0)

func _on_game_state_changed(key: String, _value: Variant) -> void:
	if key == "new_game":
		reset_state()

func _add_skill_xp(skill_id: String, amount: float) -> void:
	if not skills.has(skill_id):
		skills[skill_id] = {"level": 1, "xp": 0.0, "rating": 10.0}
	var entry: Dictionary = skills[skill_id]
	entry["xp"] = maxf(float(entry.get("xp", 0.0)) + amount, 0.0)
	entry["level"] = clampi(1 + int(float(entry["xp"]) / 100.0), 1, 100)
	entry["rating"] = clampf(10.0 + sqrt(float(entry["xp"])) * 2.5, 0.0, 100.0)
	skills[skill_id] = entry

func _skill_rating(skill_id: String) -> float:
	var entry: Dictionary = skills.get(skill_id, {})
	return float(entry.get("rating", 0.0))

func _add_iq_growth(amount: float) -> void:
	iq_growth_points += maxf(amount, 0.0)
	while iq_growth_points >= 25.0 and intelligence_quotient < 220:
		iq_growth_points -= 25.0
		intelligence_quotient += 1
	attributes["intelligence"] = float(intelligence_quotient)

func _shift_attribute(attribute_id: String, amount: float) -> void:
	if attributes.has(attribute_id):
		attributes[attribute_id] = _clamp100(float(attributes[attribute_id]) + amount)

func _update_abilities() -> void:
	_unlock_if("self_entertainment", get_autonomy_score() >= 35.0)
	_unlock_if("independent_self_care", get_autonomy_score() >= 50.0)
	_unlock_if("peer_teaching", can_teach_peer())
	_unlock_if("structured_debate", _skill_rating("debate") >= 50.0)
	_unlock_if("long_monologue", _skill_rating("language") >= 55.0)
	_unlock_if("bitling_language_teacher", _skill_rating("teaching") >= 65.0)
	_unlock_if("human_language_speech", has_legendary_language())

func _unlock_if(ability_id: String, condition: bool) -> void:
	if condition and not bool(abilities.get(ability_id, false)):
		abilities[ability_id] = true
		ability_unlocked.emit(ability_id)
	elif not abilities.has(ability_id):
		abilities[ability_id] = false

func _rank_for_xp(value: float) -> int:
	for index in range(RANK_THRESHOLDS.size() - 1, -1, -1):
		if value >= RANK_THRESHOLDS[index]:
			return index
	return RANK_BRONZE

func _create_rarity(seed_value: int) -> Dictionary:
	var roll: int = int(abs(seed_value)) % 10000
	var tier: String = "COMMON"
	var multiplier: float = 1.0
	var visual: Dictionary = {"shimmer": 0.0, "glow": 0.0, "sparkles": false, "hue_shift": 0.0}
	if roll < 25:
		tier = "LEGENDARY"
		multiplier = 1.12
		visual = {"shimmer": 1.0, "glow": 1.0, "sparkles": true, "hue_shift": 0.18}
	elif roll < 450:
		tier = "RARE"
		multiplier = 1.06
		visual = {"shimmer": 0.45, "glow": 0.45, "sparkles": true, "hue_shift": 0.08}
	elif roll < 2200:
		tier = "UNCOMMON"
		multiplier = 1.02
		visual = {"shimmer": 0.12, "glow": 0.18, "sparkles": false, "hue_shift": 0.03}
	return {"tier": tier, "growth_multiplier": multiplier, "visual": visual, "roll": roll}

func _sync_identity() -> void:
	var identity: Node = get_node_or_null("/root/BitlingIdentity")
	if identity != null and identity.has_method("set_intelligence_quotient"):
		identity.set_intelligence_quotient(intelligence_quotient)

func _identity_id() -> String:
	var identity: Node = get_node_or_null("/root/BitlingIdentity")
	if identity == null:
		return ""
	var passport: Dictionary = identity.get_public_passport()
	return str(passport.get("bitling_id", ""))

func _pick_unique(pool: Array, rng: RandomNumberGenerator, count: int) -> Array[String]:
	var copy: Array = pool.duplicate()
	var result: Array[String] = []
	while not copy.is_empty() and result.size() < count:
		var index: int = rng.randi_range(0, copy.size() - 1)
		result.append(str(copy[index]))
		copy.remove_at(index)
	return result

func _array_similarity(a: Array, b: Array) -> float:
	if a.is_empty() and b.is_empty():
		return 1.0
	var matches: int = 0
	for value in a:
		if b.has(value):
			matches += 1
	return float(matches) / float(maxi(maxi(a.size(), b.size()), 1))

func _dictionary_similarity(a: Dictionary, b: Dictionary) -> float:
	if a.is_empty() or b.is_empty():
		return 0.5
	var total: float = 0.0
	var count: int = 0
	for key in a.keys():
		if b.has(key):
			total += 1.0 - abs(float(a[key]) - float(b[key])) / 100.0
			count += 1
	return total / float(maxi(count, 1))

func _skill_similarity(a: Dictionary, b: Dictionary) -> float:
	if a.is_empty() or b.is_empty():
		return 0.5
	var total: float = 0.0
	var count: int = 0
	for key in a.keys():
		if b.has(key):
			var a_entry: Dictionary = a[key]
			var b_entry: Dictionary = b[key]
			total += 1.0 - abs(float(a_entry.get("rating", 0.0)) - float(b_entry.get("rating", 0.0))) / 100.0
			count += 1
	return total / float(maxi(count, 1))

func _affinity_label(score: float) -> String:
	if score >= 85.0: return "SEELENFREQUENZ"
	if score >= 70.0: return "SEHR VERTRAUT"
	if score >= 55.0: return "FREUNDSCHAFT"
	if score >= 40.0: return "NEUGIER"
	return "VORSICHTIGES KENNENLERNEN"

func _clamp100(value: float) -> float:
	return clampf(value, 0.0, 100.0)

func _copy_file(source_path: String, destination_path: String) -> void:
	var source := FileAccess.open(source_path, FileAccess.READ)
	if source == null:
		return
	var destination := FileAccess.open(destination_path, FileAccess.WRITE)
	if destination != null:
		destination.store_buffer(source.get_buffer(source.get_length()))
		destination.close()
	source.close()

func _emit_change() -> void:
	profile_changed.emit(get_display_snapshot())
