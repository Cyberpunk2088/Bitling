extends "res://scripts/audio/omni_audio_director.gd"

## Wave 2 reactive audio layer. It keeps the asset-independent generator as a
## guaranteed fallback, but shapes every cue by lifecycle phase, mood, intent
## and interaction zone. Authored OGG/WAV files can later replace these voices.

signal performance_cue_started(snapshot: Dictionary)
signal ambience_changed(environment_name: String)

const PHASE_PITCH: Dictionary = {
	"EGG": 1.24,
	"BABY": 1.18,
	"CHILD": 1.10,
	"TEEN": 1.02,
	"ADULT": 0.94,
	"SENIOR": 0.82,
	"LEGENDARY": 0.88
}

const MOOD_CONTOUR: Dictionary = {
	"ECSTATIC": {"pitch": 1.16, "glide": 260.0, "gain": 1.10},
	"HAPPY": {"pitch": 1.06, "glide": 140.0, "gain": 1.00},
	"CONTENT": {"pitch": 1.00, "glide": 70.0, "gain": 0.94},
	"NEUTRAL": {"pitch": 1.00, "glide": 40.0, "gain": 0.90},
	"TIRED": {"pitch": 0.86, "glide": -90.0, "gain": 0.76},
	"SAD": {"pitch": 0.90, "glide": -130.0, "gain": 0.78},
	"DISTRESSED": {"pitch": 0.96, "glide": -45.0, "gain": 0.88}
}

const ENVIRONMENT_PRESETS: Dictionary = {
	"HOME": {"frequency": 92.0, "glide": 7.0, "interval": 5.8, "gain": 0.032},
	"ROOFTOPS": {"frequency": 126.0, "glide": 34.0, "interval": 4.6, "gain": 0.040},
	"LEARNING": {"frequency": 174.0, "glide": -18.0, "interval": 5.2, "gain": 0.030},
	"REST": {"frequency": 72.0, "glide": -8.0, "interval": 7.2, "gain": 0.026}
}

const TOUCH_FREQUENCIES: Dictionary = {
	"head": 620.0,
	"ear_left": 810.0,
	"ear_right": 850.0,
	"belly": 470.0,
	"paw_left": 690.0,
	"paw_right": 730.0,
	"tail": 560.0,
	"body": 540.0
}

var _environment := "HOME"
var _ambience_clock := 1.8
var _ambience_enabled := true
var _last_performance: Dictionary = {}
var _performance_cue_count := 0
var _dialogue_cue_count := 0

func _ready() -> void:
	super._ready()
	_ambience_enabled = DisplayServer.get_name().to_lower() != "headless"
	set_environment("HOME")

func _process(delta: float) -> void:
	super._process(delta)
	if not _enabled or not _ambience_enabled:
		return
	_ambience_clock -= maxf(delta, 0.0)
	if _ambience_clock <= 0.0:
		_emit_ambience_pulse()

func play_performance_cue(snapshot: Dictionary) -> void:
	if not _enabled or snapshot.is_empty():
		return
	_last_performance = snapshot.duplicate(true)
	_performance_cue_count += 1
	var intent := str(snapshot.get("intent", "check_in")).to_lower()
	var intensity := clampf(float(snapshot.get("intensity", 0.7)), 0.20, 1.35)
	if intent == "touch":
		play_touch_reaction(str(snapshot.get("touch_zone", "body")), str(snapshot.get("mood", "HAPPY")), str(snapshot.get("phase", "BABY")), intensity)
	elif intent != "dialogue" and intent != "idle":
		play_action(intent, intensity)
		_schedule_phase_accent(intent, snapshot, intensity)
	performance_cue_started.emit(snapshot.duplicate(true))

func play_touch_reaction(zone_name: String, mood: String = "HAPPY", phase: String = "BABY", intensity: float = 1.0) -> void:
	if not _enabled:
		return
	var zone := zone_name.to_lower()
	var phase_pitch := float(PHASE_PITCH.get(phase.to_upper(), 1.0))
	var contour: Dictionary = MOOD_CONTOUR.get(mood.to_upper(), MOOD_CONTOUR["NEUTRAL"]) as Dictionary
	var base_frequency := float(TOUCH_FREQUENCIES.get(zone, TOUCH_FREQUENCIES["body"])) * phase_pitch * float(contour.get("pitch", 1.0))
	var primary := {
		"frequency": base_frequency,
		"glide": float(contour.get("glide", 40.0)) + (150.0 if zone.begins_with("ear") else 70.0),
		"duration": 0.18 if zone.begins_with("ear") else 0.30,
		"wave": "voice" if zone in ["head", "belly", "body"] else "spark",
		"bus": "Voice",
		"gain": 0.20 * float(contour.get("gain", 0.9))
	}
	_spawn_voice("touch_%s" % zone, primary, clampf(intensity, 0.3, 1.3), 0.0)
	var answer := primary.duplicate(true)
	answer["frequency"] = base_frequency * (1.18 if zone != "belly" else 0.84)
	answer["glide"] = -float(primary["glide"]) * 0.42
	answer["duration"] = float(primary["duration"]) * 0.72
	answer["gain"] = float(primary["gain"]) * 0.70
	_schedule_voice("touch_%s_answer" % zone, answer, clampf(intensity, 0.3, 1.3), 0.085)

func play_voice_performance(text: String, mood: String = "HAPPY", phase: String = "BABY", trigger: String = "check_in") -> void:
	if not _enabled or text.strip_edges().is_empty():
		return
	_dialogue_cue_count += 1
	var phase_name := phase.to_upper()
	var mood_name := mood.to_upper()
	var contour: Dictionary = MOOD_CONTOUR.get(mood_name, MOOD_CONTOUR["NEUTRAL"]) as Dictionary
	var phase_pitch := float(PHASE_PITCH.get(phase_name, 1.0))
	var trigger_pitch := _trigger_pitch(trigger)
	var base_frequency := 520.0 * phase_pitch * float(contour.get("pitch", 1.0)) * trigger_pitch
	var syllables := clampi(int(ceil(float(text.length()) / 11.0)), 2, 7)
	var spacing := 0.092 / maxf(phase_pitch, 0.72)
	for index in range(syllables):
		var alternating := 1.0 + (0.075 if index % 2 == 0 else -0.045)
		var identity_offset := float((_timbre_seed >> ((index % 5) * 3)) & 31) - 15.0
		var preset := {
			"frequency": base_frequency * alternating + identity_offset,
			"glide": float(contour.get("glide", 40.0)) * (1.0 if index % 2 == 0 else -0.35),
			"duration": 0.105 + 0.018 * float(index % 3),
			"wave": "voice",
			"bus": "Voice",
			"gain": 0.17 * float(contour.get("gain", 0.9))
		}
		_schedule_voice("speech_%s_%02d" % [trigger.to_lower(), index], preset, 1.0, float(index) * spacing)
	if mood_name in ["ECSTATIC", "HAPPY"] and syllables >= 4:
		var sparkle := {
			"frequency": base_frequency * 1.72,
			"glide": 220.0,
			"duration": 0.16,
			"wave": "crystal",
			"bus": "Voice",
			"gain": 0.075
		}
		_schedule_voice("speech_sparkle", sparkle, 1.0, float(syllables) * spacing * 0.72)

func set_environment(environment_name: String) -> void:
	var normalized := environment_name.strip_edges().to_upper()
	_environment = normalized if ENVIRONMENT_PRESETS.has(normalized) else "HOME"
	_ambience_clock = minf(_ambience_clock, 1.0)
	ambience_changed.emit(_environment)

func set_ambience_enabled(value: bool) -> void:
	_ambience_enabled = value

func get_audio_status() -> Dictionary:
	var status := super.get_audio_status()
	status["environment"] = _environment
	status["ambience_enabled"] = _ambience_enabled
	status["performance_cues"] = _performance_cue_count
	status["dialogue_cues"] = _dialogue_cue_count
	status["last_performance"] = _last_performance.duplicate(true)
	return status

func _on_dialogue_line(text: String, trigger: String) -> void:
	var state := get_node_or_null("/root/GameState")
	var mood := "HAPPY"
	var phase := "BABY"
	if state != null and state.has_method("get_state_summary"):
		var summary: Dictionary = state.call("get_state_summary")
		mood = str(summary.get("mood", "HAPPY"))
		phase = str(summary.get("phase", "BABY"))
	play_voice_performance(text, mood, phase, trigger)

func _schedule_phase_accent(intent: String, snapshot: Dictionary, intensity: float) -> void:
	var phase := str(snapshot.get("phase", "BABY")).to_upper()
	var mood := str(snapshot.get("mood", "NEUTRAL")).to_upper()
	var phase_pitch := float(PHASE_PITCH.get(phase, 1.0))
	var contour: Dictionary = MOOD_CONTOUR.get(mood, MOOD_CONTOUR["NEUTRAL"]) as Dictionary
	var frequency := 280.0 * phase_pitch * float(contour.get("pitch", 1.0))
	match intent:
		"play":
			frequency *= 1.68
		"learn":
			frequency *= 1.42
		"care":
			frequency *= 0.92
		"rest":
			frequency *= 0.72
		"level":
			frequency *= 1.84
		"explore":
			frequency *= 1.26
	var preset := {
		"frequency": frequency,
		"glide": float(contour.get("glide", 40.0)),
		"duration": 0.24 if intent != "level" else 0.52,
		"wave": "warm" if intent in ["care", "rest"] else "crystal",
		"bus": "Voice",
		"gain": 0.105
	}
	_schedule_voice("phase_%s_%s" % [phase.to_lower(), intent], preset, clampf(intensity, 0.3, 1.3), 0.055)

func _emit_ambience_pulse() -> void:
	var profile: Dictionary = ENVIRONMENT_PRESETS.get(_environment, ENVIRONMENT_PRESETS["HOME"]) as Dictionary
	var preset := {
		"frequency": float(profile.get("frequency", 92.0)),
		"glide": float(profile.get("glide", 7.0)),
		"duration": 1.20,
		"wave": "soft",
		"bus": "Ambience",
		"gain": float(profile.get("gain", 0.032))
	}
	_spawn_voice("ambience_%s" % _environment.to_lower(), preset, 1.0, 0.0)
	var variation := 0.82 + 0.36 * (0.5 + 0.5 * sin(float(Time.get_ticks_msec()) * 0.00037))
	_ambience_clock = float(profile.get("interval", 5.8)) * variation

func _trigger_pitch(trigger: String) -> float:
	match trigger.to_lower():
		"play":
			return 1.12
		"learn", "explore":
			return 1.06
		"care":
			return 0.96
		"rest":
			return 0.84
		"level":
			return 1.18
		_:
			return 1.0
