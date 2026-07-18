extends Node

## Simulated affect model. It creates believable reactions but does not claim sentience.

signal emotion_changed(dominant_emotion: String, snapshot: Dictionary)

const EMOTIONS: Array[String] = [
	"joy", "curiosity", "affection", "surprise", "pride", "calm",
	"confusion", "embarrassment", "worry", "sadness", "frustration"
]

var valence: float = 0.2
var arousal: float = 0.35
var social_safety: float = 0.6
var confidence: float = 0.45
var empathy: float = 0.5
var emotion_weights: Dictionary = {}
var recent_events: Array[Dictionary] = []

func _ready() -> void:
	if emotion_weights.is_empty():
		_reset_weights()

func apply_event(event_id: String, intensity: float = 1.0, context: Dictionary = {}) -> Dictionary:
	var amount := clampf(intensity, 0.0, 2.0)
	match event_id:
		"care", "social_greeting", "shared_success":
			_adjust("affection", 0.26 * amount)
			_adjust("joy", 0.20 * amount)
			valence += 0.18 * amount
			social_safety += 0.12 * amount
		"learn", "peer_insight", "discovery":
			_adjust("curiosity", 0.30 * amount)
			_adjust("pride", 0.10 * amount)
			arousal += 0.10 * amount
		"play", "surprise":
			_adjust("joy", 0.24 * amount)
			_adjust("surprise", 0.22 * amount)
			arousal += 0.20 * amount
		"mistake", "clumsy_moment":
			_adjust("embarrassment", 0.18 * amount)
			_adjust("confusion", 0.15 * amount)
			valence -= 0.05 * amount
		"rest", "reassurance":
			_adjust("calm", 0.28 * amount)
			arousal -= 0.18 * amount
			social_safety += 0.08 * amount
		"separation":
			_adjust("sadness", 0.10 * amount)
			valence -= 0.08 * amount
		_:
			_adjust("curiosity", 0.05 * amount)
	_normalize_axes()
	_record_event(event_id, amount, context)
	_decay_competing_emotions()
	var snapshot := get_snapshot()
	emotion_changed.emit(str(snapshot.get("dominant_emotion", "calm")), snapshot)
	return snapshot

func perceive_peer_emotion(peer_snapshot: Dictionary, openness: float = 0.5) -> Dictionary:
	var peer_emotion := str(peer_snapshot.get("dominant_emotion", "calm"))
	if not EMOTIONS.has(peer_emotion):
		return get_snapshot()
	var bounded_openness := clampf(openness, 0.0, 1.0) * clampf(empathy, 0.0, 1.0)
	_adjust(peer_emotion, 0.16 * bounded_openness)
	valence = lerpf(valence, clampf(float(peer_snapshot.get("valence", 0.0)), -1.0, 1.0), 0.10 * bounded_openness)
	arousal = lerpf(arousal, clampf(float(peer_snapshot.get("arousal", 0.3)), 0.0, 1.0), 0.10 * bounded_openness)
	_normalize_axes()
	return apply_event("peer_emotion", bounded_openness, {"peer_emotion": peer_emotion})

func update_from_game_state(mood_name: String, relationship: float, trust: float) -> Dictionary:
	var target_safety := clampf((relationship + trust) / 200.0, 0.0, 1.0)
	social_safety = lerpf(social_safety, target_safety, 0.2)
	match mood_name:
		"ECSTATIC":
			_adjust("joy", 0.15)
			valence = maxf(valence, 0.75)
		"HAPPY":
			_adjust("joy", 0.10)
			valence = maxf(valence, 0.5)
		"TIRED":
			_adjust("calm", 0.08)
			arousal = minf(arousal, 0.3)
		"SAD":
			_adjust("sadness", 0.10)
			valence = minf(valence, -0.25)
		"DISTRESSED":
			_adjust("worry", 0.14)
			arousal = maxf(arousal, 0.65)
	_normalize_axes()
	return get_snapshot()

func get_dominant_emotion() -> String:
	var dominant := "calm"
	var highest := -1.0
	for emotion_name in EMOTIONS:
		var value := float(emotion_weights.get(emotion_name, 0.0))
		if value > highest:
			highest = value
			dominant = emotion_name
	return dominant

func get_snapshot() -> Dictionary:
	return {
		"dominant_emotion": get_dominant_emotion(),
		"valence": valence,
		"arousal": arousal,
		"social_safety": social_safety,
		"confidence": confidence,
		"empathy": empathy,
		"weights": emotion_weights.duplicate(true)
	}

func export_state() -> Dictionary:
	return {
		"valence": valence,
		"arousal": arousal,
		"social_safety": social_safety,
		"confidence": confidence,
		"empathy": empathy,
		"emotion_weights": emotion_weights.duplicate(true),
		"recent_events": recent_events.duplicate(true)
	}

func import_state(data: Dictionary) -> void:
	valence = clampf(float(data.get("valence", 0.2)), -1.0, 1.0)
	arousal = clampf(float(data.get("arousal", 0.35)), 0.0, 1.0)
	social_safety = clampf(float(data.get("social_safety", 0.6)), 0.0, 1.0)
	confidence = clampf(float(data.get("confidence", 0.45)), 0.0, 1.0)
	empathy = clampf(float(data.get("empathy", 0.5)), 0.0, 1.0)
	_reset_weights()
	var loaded_weights: Dictionary = data.get("emotion_weights", {})
	for emotion_name in EMOTIONS:
		emotion_weights[emotion_name] = clampf(float(loaded_weights.get(emotion_name, emotion_weights[emotion_name])), 0.0, 1.0)
	recent_events.clear()
	for item in data.get("recent_events", []):
		if item is Dictionary:
			recent_events.append(item.duplicate(true))

func reset_state() -> void:
	valence = 0.2
	arousal = 0.35
	social_safety = 0.6
	confidence = 0.45
	empathy = 0.5
	recent_events.clear()
	_reset_weights()

func _reset_weights() -> void:
	emotion_weights.clear()
	for emotion_name in EMOTIONS:
		emotion_weights[emotion_name] = 0.05
	emotion_weights["calm"] = 0.35
	emotion_weights["curiosity"] = 0.25

func _adjust(emotion_name: String, delta: float) -> void:
	if not EMOTIONS.has(emotion_name):
		return
	emotion_weights[emotion_name] = clampf(float(emotion_weights.get(emotion_name, 0.0)) + delta, 0.0, 1.0)

func _decay_competing_emotions() -> void:
	var dominant := get_dominant_emotion()
	for emotion_name in EMOTIONS:
		if emotion_name != dominant:
			emotion_weights[emotion_name] = maxf(float(emotion_weights.get(emotion_name, 0.0)) * 0.94, 0.02)

func _normalize_axes() -> void:
	valence = clampf(valence, -1.0, 1.0)
	arousal = clampf(arousal, 0.0, 1.0)
	social_safety = clampf(social_safety, 0.0, 1.0)
	confidence = clampf(confidence, 0.0, 1.0)
	empathy = clampf(empathy, 0.0, 1.0)

func _record_event(event_id: String, intensity: float, context: Dictionary) -> void:
	recent_events.append({
		"event_id": event_id,
		"intensity": intensity,
		"context": context.duplicate(true),
		"timestamp": int(Time.get_unix_time_from_system())
	})
	while recent_events.size() > 24:
		recent_events.pop_front()
