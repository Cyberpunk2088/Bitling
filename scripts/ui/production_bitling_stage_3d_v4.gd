extends "res://scripts/ui/production_bitling_stage_3d_v3.gd"

## Expression, gesture and visible-development pass for the production stage.
## Authored rigs keep their animation clips; the procedural fallback receives
## equivalent readable body language instead of a generic bounce.

const PHASE_SCALE := {
	"EGG": 0.58,
	"BABY": 0.78,
	"CHILD": 0.90,
	"TEEN": 1.00,
	"ADULT": 1.08,
	"SENIOR": 1.04,
	"LEGENDARY": 1.14
}

var _gesture_name := "idle"
var _gesture_clock := 0.0
var _gesture_duration := 0.0
var _gesture_blend := 0.0
var _development_phase := "BABY"
var _development_level := 1
var _development_scale := 0.78
var _development_scale_target := 0.78
var _next_spontaneous_gesture := 9.0
var _expression_serial := 0

func _ready() -> void:
	super._ready()
	_next_spontaneous_gesture = 7.0 + float(absi(hash(get_instance_id())) % 700) / 100.0
	_set_gesture(_gesture_for_mood(mood), 0.0)

func set_mood(value: String) -> void:
	super.set_mood(value)
	if _gesture_duration <= 0.0:
		_set_gesture(_gesture_for_mood(value), 0.0)

func set_development_phase(phase_name: String, level: int = 1) -> void:
	_development_phase = phase_name.to_upper()
	_development_level = maxi(level, 1)
	var base_scale := float(PHASE_SCALE.get(_development_phase, 1.0))
	var level_trim := clampf(float(_development_level - 1) * 0.0015, 0.0, 0.08)
	_development_scale_target = base_scale + level_trim
	_set_gesture("transform", 0.80)

func play_action_animation(action_name: String) -> void:
	super.play_action_animation(action_name)
	match action_name.to_lower():
		"feed":
			_set_gesture("feed", 1.10)
		"play":
			_set_gesture("play", 1.25)
		"learn":
			_set_gesture("curious", 1.35)
		"care":
			_set_gesture("cared_for", 1.25)
		"rest":
			_set_gesture("sleepy", 1.70)
		"check_in":
			_set_gesture("surprised", 0.90)
		_:
			_set_gesture("surprised", 0.75)

func play_reaction() -> void:
	super.play_reaction()
	if _gesture_duration <= 0.0:
		_set_gesture("surprised", 0.72)

func get_expression_snapshot() -> Dictionary:
	return {
		"gesture": _gesture_name,
		"mood": mood,
		"phase": _development_phase,
		"level": _development_level,
		"scale": _development_scale,
		"authored_character": _authored_character_active
	}

func _process(delta: float) -> void:
	super._process(delta)
	if not _active or _bitling == null:
		return
	_development_scale = lerpf(_development_scale, _development_scale_target, clampf(delta * 3.6, 0.0, 1.0))
	_gesture_clock += delta
	_gesture_blend = move_toward(_gesture_blend, 1.0, delta * 5.0)
	if _gesture_duration > 0.0 and _gesture_clock >= _gesture_duration:
		_set_gesture(_gesture_for_mood(mood), 0.0)
	_next_spontaneous_gesture -= delta
	if _next_spontaneous_gesture <= 0.0 and _gesture_duration <= 0.0 and not _reduce_motion_enabled():
		var spontaneous := "clumsy" if (_expression_serial % 3) == 0 else "curious"
		_set_gesture(spontaneous, 1.15)
		_next_spontaneous_gesture = 10.0 + float((_expression_serial * 37) % 900) / 100.0
	if _authored_character_active:
		_apply_authored_root_motion(delta)
	else:
		_apply_fallback_expression(delta)

func _set_gesture(gesture_name: String, duration: float) -> void:
	_gesture_name = gesture_name
	_gesture_clock = 0.0
	_gesture_duration = maxf(duration, 0.0)
	_gesture_blend = 0.0
	_expression_serial += 1

func _gesture_for_mood(value: String) -> String:
	match value.to_upper():
		"ECSTATIC":
			return "ecstatic"
		"HAPPY":
			return "happy"
		"TIRED":
			return "sleepy"
		"SAD", "DISTRESSED":
			return "sad"
		_:
			return "idle"

func _apply_authored_root_motion(_delta: float) -> void:
	var pulse := sin(_gesture_clock * 8.0)
	var squash := Vector3.ONE
	match _gesture_name:
		"play", "ecstatic":
			squash = Vector3(1.0 + 0.035 * pulse, 1.0 - 0.025 * pulse, 1.0 + 0.035 * pulse)
		"surprised":
			squash = Vector3(1.04, 0.96, 1.04)
		"sleepy":
			squash = Vector3(1.02, 0.94, 1.02)
		_:
			squash = Vector3.ONE
	_bitling.scale = Vector3.ONE * _development_scale * squash

func _apply_fallback_expression(_delta: float) -> void:
	if _head == null or _left_eye == null or _right_eye == null or _mouth == null:
		return
	var t := _gesture_clock
	var pulse := sin(t * 7.0)
	var slow := sin(t * 2.2)
	var head_tilt := 0.0
	var head_pitch := 0.0
	var body_roll := 0.0
	var eye_x := 1.0
	var eye_y := 1.0
	var eye_z := 1.0
	var mouth_x := 1.0
	var mouth_y := 0.58
	var mouth_position_y := -0.48
	var ear_lift := 0.0
	var tail_speed := 1.0
	var squash := Vector3.ONE

	match _gesture_name:
		"happy":
			head_tilt = 0.05 * slow
			mouth_x = 1.12
			mouth_y = 0.68
			ear_lift = 0.07
			tail_speed = 1.55
		"ecstatic":
			head_tilt = 0.12 * pulse
			head_pitch = -0.06
			eye_x = 1.08
			eye_y = 1.10
			mouth_x = 1.28
			mouth_y = 0.82
			ear_lift = 0.15
			tail_speed = 2.2
			squash = Vector3(1.0 + 0.055 * pulse, 1.0 - 0.040 * pulse, 1.0 + 0.055 * pulse)
		"curious":
			head_tilt = 0.20
			head_pitch = -0.05
			eye_x = 1.05
			eye_y = 1.08
			mouth_x = 0.62
			mouth_y = 0.36
			ear_lift = 0.18
		"surprised":
			head_pitch = -0.10
			eye_x = 1.16
			eye_y = 1.20
			mouth_x = 0.46
			mouth_y = 0.86
			mouth_position_y = -0.43
			ear_lift = 0.22
			squash = Vector3(1.08, 0.92, 1.08)
		"feed":
			head_pitch = 0.08 + 0.09 * sin(t * 8.5)
			mouth_x = 0.86
			mouth_y = 1.00 if sin(t * 10.0) > 0.0 else 0.42
			mouth_position_y = -0.43
			tail_speed = 1.8
		"play":
			head_tilt = 0.17 * sin(t * 6.0)
			body_roll = 0.12 * sin(t * 7.0)
			eye_x = 1.08
			eye_y = 1.08
			mouth_x = 1.20
			mouth_y = 0.72
			ear_lift = 0.12
			tail_speed = 2.5
			squash = Vector3(1.0 + 0.065 * pulse, 1.0 - 0.055 * pulse, 1.0 + 0.065 * pulse)
		"cared_for":
			head_tilt = -0.12
			head_pitch = 0.04
			eye_x = 1.04
			eye_y = 0.78
			mouth_x = 1.08
			mouth_y = 0.62
			ear_lift = -0.04
			tail_speed = 1.35
		"sleepy":
			head_pitch = 0.14
			head_tilt = 0.035 * slow
			eye_y = 0.34
			mouth_x = 0.54
			mouth_y = 0.30
			mouth_position_y = -0.41
			ear_lift = -0.18
			tail_speed = 0.35
			squash = Vector3(1.03, 0.94, 1.03)
		"sad":
			head_pitch = 0.12
			head_tilt = -0.06
			eye_y = 0.72
			mouth_x = 0.70
			mouth_y = 0.30
			mouth_position_y = -0.39
			ear_lift = -0.22
			tail_speed = 0.45
		"clumsy":
			head_tilt = 0.26 * sin(t * 11.0) * maxf(0.0, 1.0 - t / 1.15)
			body_roll = -0.20 * sin(t * 8.0)
			eye_x = 1.12
			eye_y = 1.04
			mouth_x = 0.50
			mouth_y = 0.72
			ear_lift = 0.12 * pulse
			squash = Vector3(1.08, 0.90, 1.04)
		"transform":
			head_pitch = -0.10 * sin(t * 5.0)
			eye_x = 1.10
			eye_y = 1.12
			mouth_x = 0.72
			mouth_y = 0.70
			ear_lift = 0.16
			squash = Vector3(1.0 + 0.08 * pulse, 1.0 - 0.06 * pulse, 1.0 + 0.08 * pulse)
		_:
			head_tilt = 0.025 * slow
			mouth_x = 0.78
			mouth_y = 0.48

	var phase_head_scale := 1.0
	var phase_body_scale := 1.0
	var phase_ear_scale := 1.0
	match _development_phase:
		"EGG":
			phase_head_scale = 0.86
			phase_body_scale = 1.16
			phase_ear_scale = 0.18
		"BABY":
			phase_head_scale = 1.16
			phase_body_scale = 0.82
			phase_ear_scale = 0.76
		"CHILD":
			phase_head_scale = 1.10
			phase_body_scale = 0.92
			phase_ear_scale = 0.90
		"TEEN":
			phase_head_scale = 1.03
			phase_body_scale = 1.00
			phase_ear_scale = 1.08
		"ADULT", "LEGENDARY":
			phase_head_scale = 0.98
			phase_body_scale = 1.08
			phase_ear_scale = 1.14
		"SENIOR":
			phase_head_scale = 0.99
			phase_body_scale = 1.05
			phase_ear_scale = 0.98

	_bitling.scale = Vector3.ONE * _development_scale * squash
	_bitling.rotation.z = body_roll
	_head.scale = Vector3.ONE * phase_head_scale
	_head.rotation.x = head_pitch
	_head.rotation.z = head_tilt
	_body.scale = Vector3.ONE * phase_body_scale
	_left_ear.scale = Vector3.ONE * phase_ear_scale
	_right_ear.scale = Vector3.ONE * phase_ear_scale
	_left_ear.rotation.z = deg_to_rad(22.0) + ear_lift + 0.025 * sin(t * 2.7)
	_right_ear.rotation.z = deg_to_rad(-22.0) - ear_lift - 0.025 * sin(t * 2.5)
	_tail.rotation.y = sin(_elapsed * 1.65 * tail_speed) * (0.22 + 0.20 * tail_speed)

	var current_left_y := maxf(_left_eye.scale.y, 0.05)
	var current_right_y := maxf(_right_eye.scale.y, 0.05)
	_left_eye.scale = Vector3(eye_x, maxf(0.05, current_left_y * eye_y), eye_z)
	_right_eye.scale = Vector3(eye_x, maxf(0.05, current_right_y * eye_y), eye_z)
	_mouth.scale = Vector3(mouth_x, mouth_y, 0.35)
	_mouth.position.y = mouth_position_y
