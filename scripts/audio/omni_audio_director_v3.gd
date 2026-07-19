extends "res://scripts/audio/omni_audio_director_v2.gd"

## Wave 4 ambience layer for the navigable settlement and expedition regions.

const WORLD_ENVIRONMENT_PRESETS: Dictionary = {
	"SETTLEMENT": {"frequency": 112.0, "glide": 18.0, "interval": 4.9, "gain": 0.034, "accent": 1.50},
	"GARDENS": {"frequency": 148.0, "glide": 42.0, "interval": 5.4, "gain": 0.030, "accent": 1.72},
	"FOUNDRY": {"frequency": 82.0, "glide": -12.0, "interval": 4.1, "gain": 0.038, "accent": 2.10},
	"ARCHIVE": {"frequency": 104.0, "glide": -30.0, "interval": 6.1, "gain": 0.028, "accent": 1.33},
	"EXPEDITION": {"frequency": 136.0, "glide": 56.0, "interval": 3.9, "gain": 0.042, "accent": 1.88}
}

var _world_cue_count := 0

func set_environment(environment_name: String) -> void:
	var normalized := environment_name.strip_edges().to_upper()
	if WORLD_ENVIRONMENT_PRESETS.has(normalized):
		_environment = normalized
		_ambience_clock = minf(_ambience_clock, 0.8)
		ambience_changed.emit(_environment)
		return
	super.set_environment(normalized)

func play_world_cue(cue_name: String, intensity: float = 1.0) -> void:
	if not _enabled:
		return
	_world_cue_count += 1
	var normalized := cue_name.strip_edges().to_lower()
	var profile: Dictionary = {
		"travel": {"frequency": 340.0, "glide": 260.0, "duration": 0.32, "wave": "crystal", "bus": "SFX", "gain": 0.12},
		"arrival": {"frequency": 440.0, "glide": -80.0, "duration": 0.28, "wave": "warm", "bus": "SFX", "gain": 0.13},
		"mentor": {"frequency": 520.0, "glide": 120.0, "duration": 0.38, "wave": "voice", "bus": "Voice", "gain": 0.12},
		"secret": {"frequency": 620.0, "glide": -260.0, "duration": 0.48, "wave": "crystal", "bus": "SFX", "gain": 0.10},
		"expedition": {"frequency": 280.0, "glide": 330.0, "duration": 0.46, "wave": "spark", "bus": "SFX", "gain": 0.14},
		"world_change": {"frequency": 390.0, "glide": 510.0, "duration": 0.62, "wave": "crystal", "bus": "SFX", "gain": 0.12}
	}.get(normalized, {"frequency": 360.0, "glide": 90.0, "duration": 0.26, "wave": "soft", "bus": "SFX", "gain": 0.10}) as Dictionary
	_spawn_voice("world_%s" % normalized, profile, clampf(intensity, 0.25, 1.35), 0.0)
	if normalized in ["mentor", "secret", "world_change"]:
		var answer := profile.duplicate(true)
		answer["frequency"] = float(profile.get("frequency", 360.0)) * 1.34
		answer["glide"] = -float(profile.get("glide", 90.0)) * 0.42
		answer["duration"] = float(profile.get("duration", 0.28)) * 0.65
		answer["gain"] = float(profile.get("gain", 0.10)) * 0.65
		_schedule_voice("world_%s_answer" % normalized, answer, clampf(intensity, 0.25, 1.35), 0.11)

func get_audio_status() -> Dictionary:
	var status := super.get_audio_status()
	status["world_cues"] = _world_cue_count
	status["world_environments"] = WORLD_ENVIRONMENT_PRESETS.keys()
	return status

func _emit_ambience_pulse() -> void:
	if not WORLD_ENVIRONMENT_PRESETS.has(_environment):
		super._emit_ambience_pulse()
		return
	var profile: Dictionary = WORLD_ENVIRONMENT_PRESETS[_environment]
	var preset := {
		"frequency": float(profile.get("frequency", 112.0)),
		"glide": float(profile.get("glide", 18.0)),
		"duration": 1.35,
		"wave": "soft",
		"bus": "Ambience",
		"gain": float(profile.get("gain", 0.034))
	}
	_spawn_voice("ambience_%s" % _environment.to_lower(), preset, 1.0, 0.0)
	var accent := preset.duplicate(true)
	accent["frequency"] = float(preset["frequency"]) * float(profile.get("accent", 1.5))
	accent["duration"] = 0.42
	accent["gain"] = float(preset["gain"]) * 0.56
	_schedule_voice("ambience_%s_accent" % _environment.to_lower(), accent, 1.0, 0.28)
	var variation := 0.84 + 0.32 * (0.5 + 0.5 * sin(float(Time.get_ticks_msec()) * 0.00031))
	_ambience_clock = float(profile.get("interval", 4.9)) * variation
