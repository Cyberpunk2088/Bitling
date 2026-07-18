extends Node

## Lightweight, deterministic behavior model for BITLING.
## It creates continuity through personality, relationship and meaningful memories
## without requiring a network service or generative model.

signal relationship_changed(old_value: float, new_value: float)
signal personality_changed(trait: String, old_value: float, new_value: float)
signal intention_changed(intention: String)

const MAX_RECENT_INTERACTIONS := 20
const TRAIT_MIN := 0.0
const TRAIT_MAX := 100.0

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
	set_process(true)

func _process(delta: float) -> void:
	_autonomy_elapsed += delta
	if _autonomy_elapsed < _autonomy_interval:
		return
	_autonomy_elapsed = 0.0
	_autonomy_interval = _rng.randf_range(14.0, 28.0)
	choose_idle_intention()

func observe_interaction(action: String, strength: float = 1.0, context: Dictionary = {}) -> Dictionary:
	if action.is_empty():
		return get_snapshot()

	var normalized_strength := clampf(strength, 0.1, 3.0)
	var old_relationship := relationship_score
	last_interaction = action
	last_interaction_timestamp = int(Time.get_unix_time_from_system())
	interaction_counts[action] = int(interaction_counts.get(action, 0)) + 1
	familiarity = clampf(familiarity + normalized_strength * 0.45, 0.0, 100.0)

	match action:
		"care":
			relationship_score += 1.8 * normalized_strength
			trust += 1.4 * normalized_strength
			_shift_trait("empathy", 0.45 * normalized_strength)
		"play":
			relationship_score += 1.4 * normalized_strength
			_shift_trait("humor", 0.35 * normalized_strength)
			_shift_trait("courage", 0.20 * normalized_strength)
		"learn":
			relationship_score += 1.2 * normalized_strength
			_shift_trait("curiosity", 0.50 * normalized_strength)
			_shift_trait("order", 0.15 * normalized_strength)
		"explore":
			relationship_score += 1.0 * normalized_strength
			_shift_trait("creativity", 0.45 * normalized_strength)
			_shift_trait("independence", 0.25 * normalized_strength)
		_:
			relationship_score += 0.5 * normalized_strength

	relationship_score = clampf(relationship_score, 0.0, 100.0)
	trust = clampf(trust, 0.0, 100.0)
	_remember_recent(action, context)
	if not is_equal_approx(old_relationship, relationship_score):
		relationship_changed.emit(old_relationship, relationship_score)
	return get_snapshot()

func choose_idle_intention() -> String:
	var weighted: Array[Dictionary] = [
		{"id": "observe", "weight": 15.0},
		{"id": "play", "weight": 8.0 + float(personality.get("humor", 50.0)) * 0.12},
		{"id": "discover", "weight": 8.0 + float(personality.get("curiosity", 50.0)) * 0.15},
		{"id": "organize", "weight": 5.0 + float(personality.get("order", 50.0)) * 0.10},
		{"id": "create", "weight": 5.0 + float(personality.get("creativity", 50.0)) * 0.12},
		{"id": "rest", "weight": 9.0}
	]
	var total := 0.0
	for entry in weighted:
		total += float(entry.weight)
	var roll := _rng.randf_range(0.0, total)
	var running := 0.0
	var selected := "observe"
	for entry in weighted:
		running += float(entry.weight)
		if roll <= running:
			selected = str(entry.id)
			break
	if selected != current_intention:
		current_intention = selected
		intention_changed.emit(current_intention)
	return current_intention

func get_greeting() -> String:
	var hour := int(Time.get_time_dict_from_system().get("hour", 12))
	var period := "Hallo"
	if hour < 6:
		period = "Du bist noch wach"
	elif hour < 11:
		period = "Guten Morgen"
	elif hour < 18:
		period = "Schön, dass du da bist"
	elif hour < 23:
		period = "Guten Abend"
	else:
		period = "Ganz schön spät"

	if familiarity < 5.0:
		return "%s. Ich lerne dich noch kennen." % period
	if relationship_score >= 75.0:
		return "%s. Ich habe schon auf unseren nächsten Moment gehofft." % period
	if last_interaction == "learn":
		return "%s. Mir ist seit unserem letzten Lernen eine neue Frage eingefallen." % period
	if last_interaction == "play":
		return "%s. Bereit für eine neue Runde?" % period
	return "%s. Was entdecken wir heute?" % period

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
	for trait in personality.keys():
		personality[trait] = clampf(float(loaded_personality.get(trait, personality[trait])), TRAIT_MIN, TRAIT_MAX)

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
		"curiosity": 55.0,
		"empathy": 50.0,
		"courage": 45.0,
		"humor": 50.0,
		"order": 50.0,
		"creativity": 55.0,
		"independence": 45.0
	}

func _shift_trait(trait: String, delta: float) -> void:
	if not personality.has(trait):
		return
	var old_value := float(personality[trait])
	var new_value := clampf(old_value + delta, TRAIT_MIN, TRAIT_MAX)
	personality[trait] = new_value
	if not is_equal_approx(old_value, new_value):
		personality_changed.emit(trait, old_value, new_value)

func _remember_recent(action: String, context: Dictionary) -> void:
	recent_interactions.append({
		"action": action,
		"timestamp": int(Time.get_unix_time_from_system()),
		"context": context.duplicate(true)
	})
	while recent_interactions.size() > MAX_RECENT_INTERACTIONS:
		recent_interactions.pop_front()
