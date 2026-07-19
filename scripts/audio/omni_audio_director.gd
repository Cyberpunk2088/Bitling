extends Node

## Runtime-safe audio foundation for BITLING OMNI.
## It produces audible feedback even before authored sound assets exist.
## Final OGG/WAV assets can replace individual presets without changing callers.

signal audio_event_started(event_name: String)
signal audio_event_finished(event_name: String)

const SAMPLE_RATE := 22050.0
const MAX_SIMULTANEOUS_VOICES := 8
const BUS_LEVELS := {
	"Music": -18.0,
	"Ambience": -20.0,
	"Voice": -8.0,
	"SFX": -10.0,
	"UI": -12.0
}

const ACTION_PRESETS := {
	"check_in": {"frequency": 620.0, "glide": 210.0, "duration": 0.18, "wave": "sine", "bus": "UI", "gain": 0.28},
	"feed": {"frequency": 420.0, "glide": 540.0, "duration": 0.32, "wave": "round", "bus": "SFX", "gain": 0.34},
	"play": {"frequency": 510.0, "glide": 880.0, "duration": 0.38, "wave": "spark", "bus": "SFX", "gain": 0.36},
	"learn": {"frequency": 690.0, "glide": 330.0, "duration": 0.42, "wave": "crystal", "bus": "SFX", "gain": 0.30},
	"care": {"frequency": 360.0, "glide": 180.0, "duration": 0.46, "wave": "warm", "bus": "SFX", "gain": 0.32},
	"rest": {"frequency": 310.0, "glide": -120.0, "duration": 0.58, "wave": "soft", "bus": "SFX", "gain": 0.26},
	"level": {"frequency": 520.0, "glide": 920.0, "duration": 0.70, "wave": "crystal", "bus": "SFX", "gain": 0.34},
	"navigation": {"frequency": 760.0, "glide": 80.0, "duration": 0.11, "wave": "sine", "bus": "UI", "gain": 0.20}
}

var _voices: Array[Dictionary] = []
var _scheduled: Array[Dictionary] = []
var _timbre_seed := 0
var _enabled := true

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_ensure_audio_buses()
	_timbre_seed = _resolve_timbre_seed()
	var dialogue := get_node_or_null("/root/DialogueDirector")
	if dialogue != null and dialogue.has_signal("line_ready"):
		var callback := Callable(self, "_on_dialogue_line")
		if not dialogue.is_connected("line_ready", callback):
			dialogue.connect("line_ready", callback)
	set_process(true)

func set_audio_enabled(value: bool) -> void:
	_enabled = value
	var master_index := AudioServer.get_bus_index("Master")
	if master_index >= 0:
		AudioServer.set_bus_mute(master_index, not value)

func set_bus_volume(bus_name: String, linear_value: float) -> void:
	var index := AudioServer.get_bus_index(bus_name)
	if index < 0:
		return
	var safe_value := clampf(linear_value, 0.0, 1.0)
	AudioServer.set_bus_volume_db(index, linear_to_db(maxf(safe_value, 0.0001)))

func play_action(action_name: String, intensity: float = 1.0) -> void:
	if not _enabled:
		return
	var normalized := action_name.to_lower()
	var preset: Dictionary = ACTION_PRESETS.get(normalized, ACTION_PRESETS["check_in"])
	_spawn_voice(normalized, preset, clampf(intensity, 0.25, 1.5), 0.0)
	if normalized in ["feed", "play", "learn", "care", "level"]:
		var accent := preset.duplicate(true)
		accent["frequency"] = float(preset.get("frequency", 440.0)) * 1.48
		accent["glide"] = float(preset.get("glide", 0.0)) * 0.45
		accent["duration"] = float(preset.get("duration", 0.25)) * 0.62
		accent["gain"] = float(preset.get("gain", 0.25)) * 0.72
		_schedule_voice(normalized + "_accent", accent, clampf(intensity, 0.25, 1.5), 0.085)

func play_navigation() -> void:
	play_action("navigation", 0.8)

func play_voice_chirp(text: String, mood: String = "HAPPY") -> void:
	if not _enabled or text.strip_edges().is_empty():
		return
	var syllable_estimate := clampi(int(ceil(float(text.length()) / 18.0)), 1, 4)
	var mood_name := mood.to_upper()
	var base_frequency := 560.0
	var glide := 120.0
	match mood_name:
		"ECSTATIC":
			base_frequency = 760.0
			glide = 320.0
		"HAPPY":
			base_frequency = 650.0
			glide = 180.0
		"TIRED":
			base_frequency = 390.0
			glide = -80.0
		"SAD", "DISTRESSED":
			base_frequency = 430.0
			glide = -140.0
		_:
			base_frequency = 540.0
			glide = 60.0
	for index in range(syllable_estimate):
		var personality_offset := float((_timbre_seed >> (index * 3)) & 31) - 15.0
		var preset := {
			"frequency": base_frequency + personality_offset + float(index % 2) * 54.0,
			"glide": glide,
			"duration": 0.11 + 0.018 * float(index % 3),
			"wave": "voice",
			"bus": "Voice",
			"gain": 0.20
		}
		_schedule_voice("voice", preset, 1.0, float(index) * 0.105)

func stop_all() -> void:
	for voice in _voices:
		var player := voice.get("player") as AudioStreamPlayer
		if player != null:
			player.stop()
			player.queue_free()
	_voices.clear()
	_scheduled.clear()

func get_audio_status() -> Dictionary:
	return {
		"enabled": _enabled,
		"voices": _voices.size(),
		"scheduled": _scheduled.size(),
		"buses": BUS_LEVELS.keys()
	}

func _process(delta: float) -> void:
	_update_schedule(delta)
	for index in range(_voices.size() - 1, -1, -1):
		var voice: Dictionary = _voices[index]
		var player := voice.get("player") as AudioStreamPlayer
		var playback := voice.get("playback") as AudioStreamGeneratorPlayback
		if player == null or playback == null:
			_cleanup_voice(index, str(voice.get("name", "audio")))
			continue
		var frames_available := mini(playback.get_frames_available(), 1536)
		for _frame_index in range(frames_available):
			var time := float(voice.get("time", 0.0))
			var duration := float(voice.get("duration", 0.2))
			var sample := 0.0
			if time <= duration:
				sample = _sample_voice(voice, time, duration)
			playback.push_frame(Vector2(sample, sample))
			voice["time"] = time + 1.0 / SAMPLE_RATE
		_voices[index] = voice
		if float(voice.get("time", 0.0)) > float(voice.get("duration", 0.2)) + 0.12:
			_cleanup_voice(index, str(voice.get("name", "audio")))

func _sample_voice(voice: Dictionary, time: float, duration: float) -> float:
	var attack := minf(0.025, duration * 0.25)
	var release := minf(0.11, duration * 0.40)
	var envelope := minf(time / maxf(attack, 0.001), 1.0)
	envelope *= clampf((duration - time) / maxf(release, 0.001), 0.0, 1.0)
	var progress := clampf(time / maxf(duration, 0.001), 0.0, 1.0)
	var base_frequency := float(voice.get("frequency", 440.0))
	var frequency := base_frequency + float(voice.get("glide", 0.0)) * progress
	frequency *= 1.0 + 0.012 * sin(time * 27.0 + float(_timbre_seed % 17))
	var phase := float(voice.get("phase", 0.0))
	phase = fmod(phase + frequency / SAMPLE_RATE, 1.0)
	voice["phase"] = phase
	var wave_name := str(voice.get("wave", "sine"))
	var fundamental := sin(phase * TAU)
	var harmonic_2 := sin(phase * TAU * 2.0)
	var harmonic_3 := sin(phase * TAU * 3.0)
	var value := fundamental
	match wave_name:
		"round":
			value = fundamental * 0.78 + harmonic_2 * 0.16 + harmonic_3 * 0.06
		"spark":
			value = fundamental * 0.58 + harmonic_2 * 0.24 + harmonic_3 * 0.18
			value *= 0.72 + 0.28 * sin(time * 73.0)
		"crystal":
			value = fundamental * 0.50 + harmonic_2 * 0.18 + sin(phase * TAU * 4.01) * 0.32
		"warm":
			value = fundamental * 0.82 + harmonic_2 * 0.13 + harmonic_3 * 0.05
		"soft":
			value = fundamental * 0.90 + harmonic_2 * 0.10
			value *= 0.82 + 0.18 * cos(time * 11.0)
		"voice":
			value = fundamental * 0.66 + harmonic_2 * 0.22 + harmonic_3 * 0.12
			value *= 0.78 + 0.22 * sin(time * 31.0)
		_:
			value = fundamental
	return value * envelope * float(voice.get("gain", 0.25))

func _spawn_voice(event_name: String, preset: Dictionary, intensity: float, delay: float) -> void:
	if delay > 0.0:
		_schedule_voice(event_name, preset, intensity, delay)
		return
	while _voices.size() >= MAX_SIMULTANEOUS_VOICES:
		_cleanup_voice(0, str(_voices[0].get("name", "audio")))
	var generator := AudioStreamGenerator.new()
	generator.mix_rate = SAMPLE_RATE
	generator.buffer_length = 0.24
	var player := AudioStreamPlayer.new()
	player.name = "OmniVoice_%s" % event_name
	player.stream = generator
	player.bus = str(preset.get("bus", "SFX"))
	add_child(player)
	player.play()
	var playback := player.get_stream_playback() as AudioStreamGeneratorPlayback
	if playback == null:
		player.queue_free()
		return
	var identity_variation := 1.0 + float((_timbre_seed % 19) - 9) * 0.0035
	_voices.append({
		"name": event_name,
		"player": player,
		"playback": playback,
		"time": 0.0,
		"phase": 0.0,
		"duration": float(preset.get("duration", 0.25)),
		"frequency": float(preset.get("frequency", 440.0)) * identity_variation,
		"glide": float(preset.get("glide", 0.0)),
		"wave": str(preset.get("wave", "sine")),
		"gain": float(preset.get("gain", 0.25)) * intensity
	})
	audio_event_started.emit(event_name)

func _schedule_voice(event_name: String, preset: Dictionary, intensity: float, delay: float) -> void:
	_scheduled.append({
		"name": event_name,
		"preset": preset.duplicate(true),
		"intensity": intensity,
		"delay": maxf(delay, 0.0)
	})

func _update_schedule(delta: float) -> void:
	for index in range(_scheduled.size() - 1, -1, -1):
		var item: Dictionary = _scheduled[index]
		item["delay"] = float(item.get("delay", 0.0)) - delta
		_scheduled[index] = item
		if float(item["delay"]) <= 0.0:
			_scheduled.remove_at(index)
			_spawn_voice(
				str(item.get("name", "audio")),
				item.get("preset", {}) as Dictionary,
				float(item.get("intensity", 1.0)),
				0.0
			)

func _cleanup_voice(index: int, event_name: String) -> void:
	if index < 0 or index >= _voices.size():
		return
	var voice: Dictionary = _voices[index]
	var player := voice.get("player") as AudioStreamPlayer
	if player != null:
		player.stop()
		player.queue_free()
	_voices.remove_at(index)
	audio_event_finished.emit(event_name)

func _ensure_audio_buses() -> void:
	for bus_name_variant in BUS_LEVELS.keys():
		var bus_name := str(bus_name_variant)
		var index := AudioServer.get_bus_index(bus_name)
		if index < 0:
			AudioServer.add_bus()
			index = AudioServer.bus_count - 1
			AudioServer.set_bus_name(index, bus_name)
		AudioServer.set_bus_send(index, "Master")
		AudioServer.set_bus_volume_db(index, float(BUS_LEVELS[bus_name]))

func _resolve_timbre_seed() -> int:
	var identity := get_node_or_null("/root/BitlingIdentity")
	if identity != null and identity.has_method("get_private_passport"):
		var passport: Dictionary = identity.call("get_private_passport")
		return absi(hash(str(passport.get("voice_seed", passport.get("bitling_id", "bitling")))))
	return absi(hash("bitling-omni-default-voice"))

func _on_dialogue_line(text: String, _trigger: String) -> void:
	var state := get_node_or_null("/root/GameState")
	var mood := "HAPPY"
	if state != null and state.has_method("get_state_summary"):
		mood = str((state.call("get_state_summary") as Dictionary).get("mood", "HAPPY"))
	play_voice_chirp(text, mood)

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		stop_all()
