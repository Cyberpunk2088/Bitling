extends "res://scripts/ui/production_bitling_stage_3d_v4.gd"

## Atmosphere direction pass: time-of-day lighting, action accents, camera
## breathing and mood-linked room response. Designed for the mobile renderer.

const ATMOSPHERE_PRESETS := {
	"MORNING": {"ambient": Color("263758"), "energy": 0.78, "camera_y": 1.58, "cyan": 0.92, "magenta": 0.62},
	"DAY": {"ambient": Color("2c2b68"), "energy": 0.72, "camera_y": 1.55, "cyan": 1.00, "magenta": 0.82},
	"EVENING": {"ambient": Color("3b205d"), "energy": 0.66, "camera_y": 1.52, "cyan": 0.82, "magenta": 1.12},
	"NIGHT": {"ambient": Color("151a46"), "energy": 0.56, "camera_y": 1.50, "cyan": 1.18, "magenta": 0.96}
}

const ACTION_COLORS := {
	"feed": Color("53f0a6"),
	"play": Color("a855f7"),
	"learn": Color("35e9ff"),
	"care": Color("ff3ed1"),
	"rest": Color("5f7dff"),
	"check_in": Color("8defff")
}

var _time_segment := "DAY"
var _event_mode := "CALM"
var _camera_impulse := 0.0
var _action_light_strength := 0.0
var _action_color := Color("35e9ff")
var _base_camera_position := Vector3(0.0, 1.55, 7.8)
var _world_environment: WorldEnvironment
var _cyan_rim: OmniLight3D
var _magenta_rim: OmniLight3D
var _face_fill: OmniLight3D

func _ready() -> void:
	super._ready()
	_cache_atmosphere_nodes()
	set_atmosphere(_system_time_segment(), "CALM")

func set_atmosphere(time_segment: String, event_mode: String = "CALM") -> void:
	_time_segment = time_segment.to_upper()
	if not ATMOSPHERE_PRESETS.has(_time_segment):
		_time_segment = "DAY"
	_event_mode = event_mode.to_upper()
	_apply_static_atmosphere()

func play_action_animation(action_name: String) -> void:
	super.play_action_animation(action_name)
	var normalized := action_name.to_lower()
	_action_color = ACTION_COLORS.get(normalized, ACTION_COLORS["check_in"])
	_action_light_strength = 1.0
	_camera_impulse = 1.0
	_event_mode = normalized.to_upper()

func get_atmosphere_snapshot() -> Dictionary:
	return {
		"time_segment": _time_segment,
		"event_mode": _event_mode,
		"camera_impulse": _camera_impulse,
		"action_light_strength": _action_light_strength
	}

func _process(delta: float) -> void:
	super._process(delta)
	if not _active or _camera == null:
		return
	_camera_impulse = move_toward(_camera_impulse, 0.0, delta * 2.4)
	_action_light_strength = move_toward(_action_light_strength, 0.0, delta * 1.8)
	var reduce_motion := _reduce_motion_enabled()
	var motion_scale := 0.18 if reduce_motion else 1.0
	var preset: Dictionary = ATMOSPHERE_PRESETS.get(_time_segment, ATMOSPHERE_PRESETS["DAY"])
	var drift_x := sin(_elapsed * 0.17) * 0.055 * motion_scale
	var drift_y := sin(_elapsed * 0.21 + 0.8) * 0.030 * motion_scale
	var shake_x := sin(_elapsed * 34.0) * 0.028 * _camera_impulse * motion_scale
	var shake_y := cos(_elapsed * 29.0) * 0.018 * _camera_impulse * motion_scale
	_camera.position = Vector3(
		_base_camera_position.x + drift_x + shake_x,
		float(preset.get("camera_y", 1.55)) + drift_y + shake_y,
		_base_camera_position.z - 0.045 * _camera_impulse
	)
	_camera.look_at(Vector3(0.0, 1.34 + drift_y * 0.25, 0.0), Vector3.UP)
	_update_atmosphere_lights(preset)

func _cache_atmosphere_nodes() -> void:
	if _world == null:
		return
	_world_environment = _world.get_node_or_null("NeonEnvironment") as WorldEnvironment
	_cyan_rim = _world.get_node_or_null("CyanRim") as OmniLight3D
	_magenta_rim = _world.get_node_or_null("MagentaRim") as OmniLight3D
	_face_fill = _world.get_node_or_null("FaceFill") as OmniLight3D
	if _camera != null:
		_base_camera_position = _camera.position

func _apply_static_atmosphere() -> void:
	var preset: Dictionary = ATMOSPHERE_PRESETS.get(_time_segment, ATMOSPHERE_PRESETS["DAY"])
	if _world_environment != null and _world_environment.environment != null:
		_world_environment.environment.ambient_light_color = preset.get("ambient", Color("2c2b68")) as Color
		_world_environment.environment.ambient_light_energy = float(preset.get("energy", 0.72))

func _update_atmosphere_lights(preset: Dictionary) -> void:
	var action_mix := clampf(_action_light_strength, 0.0, 1.0)
	var cyan_energy := 3.2 * float(preset.get("cyan", 1.0))
	var magenta_energy := 3.0 * float(preset.get("magenta", 1.0))
	if _cyan_rim != null:
		_cyan_rim.light_energy = cyan_energy + 1.5 * action_mix
		_cyan_rim.light_color = Color("35e9ff").lerp(_action_color, action_mix * 0.60)
	if _magenta_rim != null:
		_magenta_rim.light_energy = magenta_energy + 1.2 * action_mix
		_magenta_rim.light_color = Color("ff3ed1").lerp(_action_color, action_mix * 0.48)
	if _face_fill != null:
		var mood_energy := 1.25
		match mood:
			"ECSTATIC":
				mood_energy = 1.80
			"HAPPY":
				mood_energy = 1.48
			"TIRED":
				mood_energy = 0.82
			"SAD", "DISTRESSED":
				mood_energy = 0.72
		_face_fill.light_energy = mood_energy + action_mix * 1.1
		_face_fill.light_color = Color("7edfff").lerp(_action_color, action_mix * 0.36)

func _system_time_segment() -> String:
	var datetime := Time.get_datetime_dict_from_system()
	var hour := int(datetime.get("hour", 12))
	if hour < 11:
		return "MORNING"
	if hour < 18:
		return "DAY"
	if hour < 23:
		return "EVENING"
	return "NIGHT"
