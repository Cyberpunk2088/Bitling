extends Node

## Deterministic local behavior model for BITLING.
## Relationship and personality create continuity without a network dependency.

signal relationship_changed(old_value: float, new_value: float)
signal personality_changed(trait_name: String, old_value: float, new_value: float)
signal intention_changed(intention: String)

const MAX_RECENT_INTERACTIONS := 20

var relationship_score: float = 10.0
var trust: float = 10.0
var familiarity: float = 0.0
var current_intention: String = "observe"
var last_interaction: String = ""
var last_interaction_timestamp: int = 0
var interaction_counts: Dictionary = {}
var recent_interactions: Array[Dictionary] = []
var personality: Dictionary = {
	"curiosity": 55.0,
	"empathy": 50.0,
	"courage": 45.0,
	"humor": 50.0,
	"order": 50.0,
	"creativity": 55.0,
	"independence": 45.0
}

var _autonomy_elapsed: float = 0.0
var _autonomy_interval: float = 18.0
var _rng := RandomNumberGenerator.new()

func _ready() -> void:
	_rng.randomize()

func _process(delta: float) -> void:
	_autonomy_elapsed += delta
	if _autonomy_elapsed >= _autonomy_interval:
		_autonomy_elapsed = 0.0
		_autonomy_interval = _rng.randf_range(14.0, 28.0)
		choose_idle_intention()

func observe_interaction(action: String, strength: float = 1.0, context: Dictionary = {}) -> Dictionary:
	if action.is_empty():
		return get_snapshot()
	var amount := clampf(strength, 0.1, 3.0)
	var old_relationship := relationship_score
	last_interaction = action
	last_interaction_timestamp = int(Time.get_unix_time_from_system())
	interaction_counts[action] = int(interaction_counts.get(action, 0)) + 1
	familiarity = clampf(familiarity + amount * 0.45, 0.0, 100.0)

	match action:
		"care":
			relationship_score += 1.8 * amount
			trust += 1.4 * amount
			_shift_trait("empathy", 0.45 * amount)
		"play":
			relationship_score += 1.4 * amount
			_shift_trait("humor", 0.35 * amount)
			_shift_trait("courage", 0.20 * amount)
		"learn":
			relationship_score += 1.2 * amount
			_shift_trait("curiosity", 0.50 * amount)
			_shift_trait("order", 0.15 * amount)
		"explore":
			relationship_score += 1.0 * amount
			_shift_trait("creativity", 0.45 * amount)
			_shift_trait("independence", 0.25 * amount)
		_:
			relationship_score += 0.5 * amount

	relationship_score = clampf(relationship_score, 0.0, 100.0)
	trust = clampf(trust, 0.0, 100.0)
	_remember_recent(action, context)
	if not is_equal_approx(old_relationship, relationship_score):
		relationship_changed.emit(old_relationship, relationship_score)
	return get_snapshot()

func choose_idle_intention() -> String:
	var choices: Array[String] = ["observe", "play", "discover", "organize", "create", "rest"]
	var weights: Array[float] = [
		15.0,
		8.0 + float(personality.get("humor", 50.0)) * 0.12,
		8.0 + float(personality.get("curiosity", 50.0)) * 0.15,
		5.0 + float(personality.get("order", 50.0)) * 0.10,
		5.0 + float(personality.get("creativity", 50.0)) * 0.12,
		9.0
	]
	var total := 0.0
	for weight in weights:
		total += weight
	var roll := _rng.randf_range(0.0, total)
	var running := 0.0
	var selected := choices[0]
	for index in range(choices.size()):
		running += weights[index]
		if roll <= running:
			selected = choices[index]
			break
	if selected != current_intention:
		current_intention = selected
		intention_changed.emit(current_intention)
	return current_intention

func get_greeting() -> String:
	var hour := int(Time.get_time_dict_from_system().get("hour", 12))
	var opening := "Hallo"
	if hour < 6:
		opening = "Du bist noch wach"
	elif hour < 11:
		opening = "Guten Morgen"
	elif hour < 18:
		opening = "Schön, dass du da bist"
	elif hour < 23:
		opening = "Guten Abend"
	else:
		opening = "Ganz schön spät"
	if familiarity < 5.0:
		return "%s. Ich lerne dich noch kennen." % opening
	if relationship_score >= 75.0:
		return "%s. Ich freue mich auf unseren nächsten Moment." % opening
	if last_interaction == "learn":
		return "%s. Mir ist seit unserem letzten Lernen eine neue Frage eingefallen." % opening
	return "%s. Was entdecken wir heute?" % opening

func get_snapshot() -> Dictionary:
	return {
		"relationship_score": relationship_score,
		"trust": trust,
		"familiarity": familiarity,
		"current_intention": current_intention,
		"last_interaction": last_interaction,
		"personality": personality.duplicate(true),
		"interaction_counts": interaction_counts.duplicate(true)
	}

func export_state() -> Dictionary:
	var state := get_snapshot()
	state["last_interaction_timestamp"] = last_interaction_timestamp
	state["recent_interactions"] = recent_interactions.duplicate(true)
	return state

func import_state(data: Dictionary) -> void:
	relationship_score = clampf(float(data.get("relationship_score", 10.0)), 0.0, 100.0)
	trust = clampf(float(data.get("trust", 10.0)), 0.0, 100.0)
	familiarity = clampf(float(data.get("familiarity", 0.0)), 0.0, 100.0)
	current_intention = str(data.get("current_intention", "observe"))
	last_interaction = str(data.get("last_interaction", ""))
	last_interaction_timestamp = int(data.get("last_interaction_timestamp", 0))
	interaction_counts = data.get("interaction_counts", {}).duplicate(true)
	recent_interactions.clear()
	for item in data.get("recent_interactions", []):
		if item is Dictionary:
			recent_interactions.append(item.duplicate(true))
	var loaded_personality: Dictionary = data.get("personality", {})
	for trait_name in personality.keys():
		personality[trait_name] = clampf(float(loaded_personality.get(trait_name, personality[trait_name])), 0.0, 100.0)

func reset_state() -> void:
	relationship_score = 10.0
	trust = 10.0
	familiarity = 0.0
	current_intention = "observe"
	last_interaction = ""
	last_interaction_timestamp = 0
	interaction_counts.clear()
	recent_interactions.clear()
	personality = {
		"curiosity": 55.0, "empathy": 50.0, "courage": 45.0,
		"humor": 50.0, "order": 50.0, "creativity": 55.0, "independence": 45.0
	}

func _shift_trait(trait_name: String, delta: float) -> void:
	if not personality.has(trait_name):
		return
	var old_value := float(personality[trait_name])
	var new_value := clampf(old_value + delta, 0.0, 100.0)
	personality[trait_name] = new_value
	if not is_equal_approx(old_value, new_value):
		personality_changed.emit(trait_name, old_value, new_value)

func _remember_recent(action: String, context: Dictionary) -> void:
	recent_interactions.append({
		"action": action,
		"timestamp": int(Time.get_unix_time_from_system()),
		"context": context.duplicate(true)
	})
	while recent_interactions.size() > MAX_RECENT_INTERACTIONS:
		recent_interactions.pop_front()
