extends Node

## Semantic performance state shared by character animation, dialogue, audio and haptics.
## It contains no rendering code and remains compatible with both the procedural
## Xogot fallback and a later authored character rig.

signal performance_changed(snapshot: Dictionary)
signal performance_event(event_name: String, snapshot: Dictionary)

const INTENT_PROFILES: Dictionary = {
	"idle": {"expression": "attentive", "gesture": "breathing", "gaze": "player", "duration": 0.0, "intensity": 0.35},
	"check_in": {"expression": "bright", "gesture": "greeting", "gaze": "player", "duration": 1.35, "intensity": 0.72},
	"feed": {"expression": "delighted", "gesture": "nibble", "gaze": "object", "duration": 1.55, "intensity": 0.82},
	"play": {"expression": "ecstatic", "gesture": "bounce_spin", "gaze": "player", "duration": 1.75, "intensity": 1.0},
	"learn": {"expression": "curious", "gesture": "focus_tilt", "gaze": "scan", "duration": 1.85, "intensity": 0.78},
	"care": {"expression": "soft", "gesture": "nuzzle", "gaze": "player", "duration": 1.70, "intensity": 0.68},
	"rest": {"expression": "sleepy", "gesture": "settle", "gaze": "down", "duration": 2.20, "intensity": 0.48},
	"level": {"expression": "astonished", "gesture": "transform", "gaze": "up", "duration": 2.10, "intensity": 1.0},
	"explore": {"expression": "alert", "gesture": "scout", "gaze": "scan", "duration": 1.90, "intensity": 0.88},
	"dialogue": {"expression": "speaking", "gesture": "converse", "gaze": "player", "duration": 1.60, "intensity": 0.58}
}

const TOUCH_PROFILES: Dictionary = {
	"head": {"expression": "soft", "gesture": "head_pat", "gaze": "player", "duration": 1.35, "intensity": 0.62},
	"ear_left": {"expression": "surprised", "gesture": "ear_twitch_left", "gaze": "touch", "duration": 1.05, "intensity": 0.76},
	"ear_right": {"expression": "surprised", "gesture": "ear_twitch_right", "gaze": "touch", "duration": 1.05, "intensity": 0.76},
	"belly": {"expression": "delighted", "gesture": "belly_laugh", "gaze": "player", "duration": 1.45, "intensity": 0.86},
	"paw_left": {"expression": "bright", "gesture": "paw_wave_left", "gaze": "touch", "duration": 1.20, "intensity": 0.70},
	"paw_right": {"expression": "bright", "gesture": "paw_wave_right", "gaze": "touch", "duration": 1.20, "intensity": 0.70},
	"tail": {"expression": "playful", "gesture": "tail_chase", "gaze": "touch", "duration": 1.35, "intensity": 0.82},
	"body": {"expression": "happy", "gesture": "friendly_bob", "gaze": "player", "duration": 1.15, "intensity": 0.60}
}

const PHASE_TEMPO: Dictionary = {
	"EGG": 0.62,
	"BABY": 1.18,
	"CHILD": 1.10,
	"TEEN": 1.04,
	"ADULT": 0.92,
	"SENIOR": 0.72,
	"LEGENDARY": 0.86
}

var _snapshot: Dictionary = {}
var _remaining := 0.0
var _serial := 0
var _active_event := "idle"
var _last_event_signature := ""

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_connect_runtime()
	sync_state()
	set_process(true)

func _process(delta: float) -> void:
	if _remaining <= 0.0:
		return
	_remaining = maxf(0.0, _remaining - maxf(delta, 0.0))
	if _remaining <= 0.0 and _active_event != "idle":
		_apply_idle(false)

func request_action(action_name: String, intensity: float = 1.0) -> Dictionary:
	var normalized := _normalize_action(action_name)
	var profile: Dictionary = (INTENT_PROFILES.get(normalized, INTENT_PROFILES["check_in"]) as Dictionary).duplicate(true)
	return _activate(normalized, profile, clampf(intensity, 0.20, 1.35), {}, true)

func request_touch(zone_name: String, normalized_position: Vector2 = Vector2.ZERO) -> Dictionary:
	var zone := zone_name.strip_edges().to_lower()
	if not TOUCH_PROFILES.has(zone):
		zone = "body"
	var profile: Dictionary = (TOUCH_PROFILES[zone] as Dictionary).duplicate(true)
	return _activate("touch_%s" % zone, profile, float(profile.get("intensity", 0.65)), {
		"touch_zone": zone,
		"touch_position": normalized_position
	}, true)

func request_dialogue(text: String, trigger: String = "check_in") -> Dictionary:
	if text.strip_edges().is_empty():
		return get_snapshot()
	var profile: Dictionary = (INTENT_PROFILES["dialogue"] as Dictionary).duplicate(true)
	var state := _runtime_state()
	var mood := str(state.get("mood", "NEUTRAL"))
	profile["expression"] = _dialogue_expression(trigger, mood)
	profile["duration"] = clampf(0.80 + float(text.length()) * 0.026, 1.10, 4.20)
	return _activate("dialogue_%s" % trigger.to_lower(), profile, 0.62, {
		"speaking": true,
		"speech_text_length": text.length(),
		"speech_rate": _speech_rate_for_phase(str(state.get("phase", "BABY"))),
		"dialogue_trigger": trigger.to_lower()
	}, false)

func request_story_beat(beat_id: String) -> Dictionary:
	var normalized := beat_id.strip_edges().to_lower()
	if normalized in ["prismatic_rooftops", "promise_of_growth"]:
		return request_action("explore", 0.82)
	return sync_state()

func sync_state() -> Dictionary:
	if _remaining > 0.0:
		return get_snapshot()
	return _apply_idle(false)

func get_snapshot() -> Dictionary:
	return _snapshot.duplicate(true)

func get_performance_contract() -> Dictionary:
	return {
		"intents": INTENT_PROFILES.keys(),
		"touch_zones": TOUCH_PROFILES.keys(),
		"phases": PHASE_TEMPO.keys(),
		"snapshot": get_snapshot()
	}

func _activate(event_name: String, profile: Dictionary, intensity: float, extra: Dictionary, audible: bool) -> Dictionary:
	var state := _runtime_state()
	_serial += 1
	_active_event = event_name
	_remaining = float(profile.get("duration", 1.2))
	_snapshot = {
		"serial": _serial,
		"event": event_name,
		"intent": _intent_from_event(event_name),
		"expression": str(profile.get("expression", "attentive")),
		"gesture": str(profile.get("gesture", "breathing")),
		"gaze": str(profile.get("gaze", "player")),
		"duration": _remaining,
		"intensity": clampf(intensity, 0.0, 1.35),
		"phase": str(state.get("phase", "BABY")),
		"mood": str(state.get("mood", "NEUTRAL")),
		"energy": float(state.get("energy", 70.0)),
		"happiness": float(state.get("happiness", 50.0)),
		"curiosity": float(state.get("curiosity", 50.0)),
		"trust": float(state.get("trust", 50.0)),
		"phase_tempo": float(PHASE_TEMPO.get(str(state.get("phase", "BABY")), 1.0)),
		"speaking": false,
		"speech_rate": _speech_rate_for_phase(str(state.get("phase", "BABY")))
	}
	_snapshot.merge(extra, true)
	var signature := "%s:%s:%s:%d" % [event_name, _snapshot["phase"], _snapshot["mood"], _serial]
	_last_event_signature = signature
	performance_changed.emit(get_snapshot())
	performance_event.emit(event_name, get_snapshot())
	if audible:
		_play_audio_cue()
		_play_haptic_cue(event_name)
	return get_snapshot()

func _apply_idle(emit_audio: bool) -> Dictionary:
	var state := _runtime_state()
	var mood := str(state.get("mood", "NEUTRAL"))
	var energy := float(state.get("energy", 70.0))
	var profile: Dictionary = (INTENT_PROFILES["idle"] as Dictionary).duplicate(true)
	profile["expression"] = _idle_expression(mood, energy)
	profile["gesture"] = "sleep_breath" if energy < 28.0 else "breathing"
	profile["gaze"] = "down" if energy < 22.0 else "player"
	_remaining = 0.0
	_active_event = "idle"
	_serial += 1
	_snapshot = {
		"serial": _serial,
		"event": "idle",
		"intent": "idle",
		"expression": str(profile["expression"]),
		"gesture": str(profile["gesture"]),
		"gaze": str(profile["gaze"]),
		"duration": 0.0,
		"intensity": float(profile.get("intensity", 0.35)),
		"phase": str(state.get("phase", "BABY")),
		"mood": mood,
		"energy": energy,
		"happiness": float(state.get("happiness", 50.0)),
		"curiosity": float(state.get("curiosity", 50.0)),
		"trust": float(state.get("trust", 50.0)),
		"phase_tempo": float(PHASE_TEMPO.get(str(state.get("phase", "BABY")), 1.0)),
		"speaking": false,
		"speech_rate": _speech_rate_for_phase(str(state.get("phase", "BABY")))
	}
	performance_changed.emit(get_snapshot())
	if emit_audio:
		_play_audio_cue()
	return get_snapshot()

func _runtime_state() -> Dictionary:
	var result := {
		"phase": "BABY",
		"mood": "NEUTRAL",
		"energy": 70.0,
		"happiness": 50.0,
		"curiosity": 50.0,
		"trust": 50.0
	}
	var state := get_node_or_null("/root/GameState")
	if state != null and state.has_method("get_state_summary"):
		result.merge(state.call("get_state_summary") as Dictionary, true)
	var brain := get_node_or_null("/root/CompanionBrain")
	if brain != null:
		result["trust"] = float(brain.get("trust"))
	return result

func _connect_runtime() -> void:
	var state := get_node_or_null("/root/GameState")
	if state != null:
		var state_callback := Callable(self, "_on_state_changed")
		if state.has_signal("state_changed") and not state.is_connected("state_changed", state_callback):
			state.connect("state_changed", state_callback)
		var level_callback := Callable(self, "_on_level_up")
		if state.has_signal("level_up") and not state.is_connected("level_up", level_callback):
			state.connect("level_up", level_callback)
	var evolution := get_node_or_null("/root/EvolutionService")
	if evolution != null and evolution.has_signal("evolved"):
		var evolution_callback := Callable(self, "_on_evolved")
		if not evolution.is_connected("evolved", evolution_callback):
			evolution.connect("evolved", evolution_callback)

func _on_state_changed(key: String, _value: Variant) -> void:
	if key in ["stats", "loaded", "hatched", "new_game"]:
		call_deferred("sync_state")

func _on_level_up(_new_level: int) -> void:
	request_action("level", 1.0)

func _on_evolved(_old_form: String, _new_form: String) -> void:
	request_action("level", 1.2)

func _play_audio_cue() -> void:
	var audio := get_node_or_null("/root/OmniAudio")
	if audio != null and audio.has_method("play_performance_cue"):
		audio.call("play_performance_cue", get_snapshot())
	elif audio != null and audio.has_method("play_action"):
		audio.call("play_action", str(_snapshot.get("intent", "check_in")), float(_snapshot.get("intensity", 0.7)))

func _play_haptic_cue(event_name: String) -> void:
	var haptic := get_node_or_null("/root/HapticService")
	if haptic == null or not haptic.has_method("pulse"):
		return
	var pattern := "success" if event_name in ["level", "play", "touch_belly"] else "tap"
	haptic.call("pulse", pattern)

func _normalize_action(action_name: String) -> String:
	match action_name.to_lower():
		"learning_result":
			return "learn"
		"sleep":
			return "rest"
		"exploration", "signal_expedition":
			return "explore"
		_:
			return action_name.to_lower() if INTENT_PROFILES.has(action_name.to_lower()) else "check_in"

func _intent_from_event(event_name: String) -> String:
	if event_name.begins_with("touch_"):
		return "touch"
	if event_name.begins_with("dialogue_"):
		return "dialogue"
	return event_name

func _idle_expression(mood: String, energy: float) -> String:
	if energy < 25.0 or mood == "TIRED":
		return "sleepy"
	match mood:
		"ECSTATIC":
			return "ecstatic"
		"HAPPY", "CONTENT":
			return "happy"
		"SAD":
			return "sad"
		"DISTRESSED":
			return "worried"
		_:
			return "attentive"

func _dialogue_expression(trigger: String, mood: String) -> String:
	if mood in ["SAD", "DISTRESSED"]:
		return "earnest"
	match trigger.to_lower():
		"feed":
			return "delighted"
		"play":
			return "playful"
		"learn", "explore":
			return "curious"
		"rest":
			return "sleepy"
		"level":
			return "astonished"
		_:
			return "speaking"

func _speech_rate_for_phase(phase: String) -> float:
	match phase.to_upper():
		"EGG":
			return 0.72
		"BABY":
			return 1.18
		"CHILD":
			return 1.08
		"TEEN":
			return 1.02
		"ADULT":
			return 0.94
		"SENIOR":
			return 0.78
		"LEGENDARY":
			return 0.88
		_:
			return 1.0
