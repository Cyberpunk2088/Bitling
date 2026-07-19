extends "res://scripts/audio/omni_audio_director_v3.gd"

## Wave 5 semantic audio layer for learning starts, hints, round feedback,
## transfer mastery and the dedicated Learning Adventure ambience.

const LEARNING_ENVIRONMENT: Dictionary = {
	"frequency": 126.0,
	"glide": 28.0,
	"interval": 4.4,
	"gain": 0.031,
	"accent": 1.67
}

const LEARNING_CUES: Dictionary = {
	"start": {"frequency": 360.0, "glide": 210.0, "duration": 0.34, "wave": "crystal", "bus": "UI", "gain": 0.12},
	"hint": {"frequency": 420.0, "glide": -90.0, "duration": 0.28, "wave": "soft", "bus": "UI", "gain": 0.09},
	"round_success": {"frequency": 520.0, "glide": 260.0, "duration": 0.30, "wave": "spark", "bus": "SFX", "gain": 0.13},
	"round_retry": {"frequency": 300.0, "glide": 80.0, "duration": 0.32, "wave": "warm", "bus": "SFX", "gain": 0.10},
	"complete": {"frequency": 460.0, "glide": 350.0, "duration": 0.52, "wave": "crystal", "bus": "SFX", "gain": 0.13},
	"transfer": {"frequency": 540.0, "glide": 620.0, "duration": 0.68, "wave": "crystal", "bus": "SFX", "gain": 0.14},
	"retry": {"frequency": 270.0, "glide": 120.0, "duration": 0.38, "wave": "warm", "bus": "SFX", "gain": 0.10}
}

var _learning_cue_count: int = 0
var _transfer_cue_count: int = 0

func set_environment(environment_name: String) -> void:
	var normalized: String = environment_name.strip_edges().to_upper()
	if normalized == "LEARNING_ADVENTURE":
		_environment = normalized
		_ambience_clock = minf(_ambience_clock, 0.55)
		ambience_changed.emit(_environment)
		return
	super.set_environment(normalized)

func play_learning_cue(cue_name: String, intensity: float = 1.0) -> void:
	if not _enabled:
		return
	var normalized: String = cue_name.strip_edges().to_lower()
	var profile: Dictionary = (LEARNING_CUES.get(normalized, LEARNING_CUES["complete"]) as Dictionary).duplicate(true)
	var safe_intensity: float = clampf(intensity, 0.25, 1.35)
	_learning_cue_count += 1
	if normalized == "transfer":
		_transfer_cue_count += 1
	_spawn_voice("learning_%s" % normalized, profile, safe_intensity, 0.0)
	if normalized in ["round_success", "complete", "transfer"]:
		var answer: Dictionary = profile.duplicate(true)
		answer["frequency"] = float(profile.get("frequency", 420.0)) * (1.25 if normalized != "transfer" else 1.50)
		answer["glide"] = float(profile.get("glide", 120.0)) * 0.48
		answer["duration"] = float(profile.get("duration", 0.32)) * 0.64
		answer["gain"] = float(profile.get("gain", 0.10)) * 0.62
		_schedule_voice("learning_%s_answer" % normalized, answer, safe_intensity, 0.10)
	if normalized == "transfer":
		var shimmer: Dictionary = profile.duplicate(true)
		shimmer["frequency"] = float(profile.get("frequency", 540.0)) * 2.01
		shimmer["glide"] = -180.0
		shimmer["duration"] = 0.42
		shimmer["gain"] = 0.065
		_schedule_voice("learning_transfer_shimmer", shimmer, safe_intensity, 0.24)

func get_audio_status() -> Dictionary:
	var status: Dictionary = super.get_audio_status()
	status["learning_cues"] = _learning_cue_count
	status["transfer_cues"] = _transfer_cue_count
	status["learning_environment"] = "LEARNING_ADVENTURE"
	status["learning_cue_types"] = LEARNING_CUES.keys()
	return status

func _emit_ambience_pulse() -> void:
	if _environment != "LEARNING_ADVENTURE":
		super._emit_ambience_pulse()
		return
	var preset: Dictionary = {
		"frequency": float(LEARNING_ENVIRONMENT.get("frequency", 126.0)),
		"glide": float(LEARNING_ENVIRONMENT.get("glide", 28.0)),
		"duration": 1.42,
		"wave": "soft",
		"bus": "Ambience",
		"gain": float(LEARNING_ENVIRONMENT.get("gain", 0.031))
	}
	_spawn_voice("ambience_learning_adventure", preset, 1.0, 0.0)
	var accent: Dictionary = preset.duplicate(true)
	accent["frequency"] = float(preset["frequency"]) * float(LEARNING_ENVIRONMENT.get("accent", 1.67))
	accent["glide"] = -float(preset["glide"]) * 0.55
	accent["duration"] = 0.48
	accent["gain"] = float(preset["gain"]) * 0.55
	_schedule_voice("ambience_learning_adventure_accent", accent, 1.0, 0.31)
	var variation: float = 0.86 + 0.28 * (0.5 + 0.5 * sin(float(Time.get_ticks_msec()) * 0.00027))
	_ambience_clock = float(LEARNING_ENVIRONMENT.get("interval", 4.4)) * variation
