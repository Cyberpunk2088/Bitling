extends "res://scripts/ui/production_bitling_stage_3d_v7.gd"

## Wave 2 character-life pass. It layers a readable facial performance rig,
## direct gaze, phase-specific motion and touch-zone reactions over the existing
## procedural fallback while preserving the authored GLB animation path.

signal touch_zone_pressed(zone_name: String, normalized_position: Vector2)

const EXPRESSION_PROFILES: Dictionary = {
	"attentive": {"eye_open": 1.00, "eye_wide": 1.00, "mouth_x": 0.78, "mouth_y": 0.44, "brow": 0.04, "ear": 0.04, "cheek": 0.10},
	"happy": {"eye_open": 0.86, "eye_wide": 1.04, "mouth_x": 1.12, "mouth_y": 0.66, "brow": 0.10, "ear": 0.10, "cheek": 0.42},
	"bright": {"eye_open": 1.04, "eye_wide": 1.08, "mouth_x": 1.04, "mouth_y": 0.64, "brow": 0.16, "ear": 0.14, "cheek": 0.50},
	"ecstatic": {"eye_open": 1.10, "eye_wide": 1.14, "mouth_x": 1.30, "mouth_y": 0.86, "brow": 0.22, "ear": 0.22, "cheek": 0.78},
	"delighted": {"eye_open": 0.94, "eye_wide": 1.10, "mouth_x": 1.18, "mouth_y": 0.80, "brow": 0.16, "ear": 0.16, "cheek": 0.68},
	"playful": {"eye_open": 0.94, "eye_wide": 1.08, "mouth_x": 1.15, "mouth_y": 0.70, "brow": 0.12, "ear": 0.18, "cheek": 0.58},
	"curious": {"eye_open": 1.06, "eye_wide": 1.08, "mouth_x": 0.58, "mouth_y": 0.38, "brow": 0.20, "ear": 0.22, "cheek": 0.24},
	"alert": {"eye_open": 1.12, "eye_wide": 1.08, "mouth_x": 0.62, "mouth_y": 0.42, "brow": 0.24, "ear": 0.24, "cheek": 0.18},
	"soft": {"eye_open": 0.72, "eye_wide": 1.02, "mouth_x": 1.02, "mouth_y": 0.54, "brow": -0.02, "ear": -0.06, "cheek": 0.52},
	"sleepy": {"eye_open": 0.30, "eye_wide": 1.00, "mouth_x": 0.54, "mouth_y": 0.28, "brow": -0.16, "ear": -0.20, "cheek": 0.05},
	"sad": {"eye_open": 0.68, "eye_wide": 1.02, "mouth_x": 0.66, "mouth_y": 0.26, "brow": -0.18, "ear": -0.20, "cheek": 0.04},
	"worried": {"eye_open": 0.88, "eye_wide": 1.08, "mouth_x": 0.52, "mouth_y": 0.46, "brow": -0.24, "ear": -0.12, "cheek": 0.10},
	"earnest": {"eye_open": 0.86, "eye_wide": 1.02, "mouth_x": 0.72, "mouth_y": 0.48, "brow": -0.08, "ear": -0.05, "cheek": 0.18},
	"astonished": {"eye_open": 1.18, "eye_wide": 1.18, "mouth_x": 0.48, "mouth_y": 0.94, "brow": 0.30, "ear": 0.28, "cheek": 0.42},
	"surprised": {"eye_open": 1.16, "eye_wide": 1.14, "mouth_x": 0.46, "mouth_y": 0.82, "brow": 0.28, "ear": 0.26, "cheek": 0.34},
	"speaking": {"eye_open": 0.96, "eye_wide": 1.04, "mouth_x": 0.82, "mouth_y": 0.62, "brow": 0.08, "ear": 0.06, "cheek": 0.26}
}

const PHASE_MOTION: Dictionary = {
	"EGG": {"tempo": 0.64, "breath": 0.030, "bob": 0.020, "sway": 0.018, "tail": 0.10},
	"BABY": {"tempo": 1.20, "breath": 0.070, "bob": 0.085, "sway": 0.070, "tail": 1.30},
	"CHILD": {"tempo": 1.12, "breath": 0.060, "bob": 0.070, "sway": 0.055, "tail": 1.15},
	"TEEN": {"tempo": 1.04, "breath": 0.050, "bob": 0.055, "sway": 0.044, "tail": 1.00},
	"ADULT": {"tempo": 0.92, "breath": 0.042, "bob": 0.038, "sway": 0.030, "tail": 0.82},
	"SENIOR": {"tempo": 0.72, "breath": 0.034, "bob": 0.024, "sway": 0.020, "tail": 0.56},
	"LEGENDARY": {"tempo": 0.86, "breath": 0.050, "bob": 0.042, "sway": 0.032, "tail": 0.74}
}

var _performance: Dictionary = {
	"serial": 0,
	"event": "idle",
	"intent": "idle",
	"expression": "attentive",
	"gesture": "breathing",
	"gaze": "player",
	"phase": "BABY",
	"mood": "NEUTRAL",
	"intensity": 0.35,
	"phase_tempo": 1.0,
	"speaking": false,
	"speech_rate": 1.0
}
var _performance_clock := 0.0
var _performance_blend := 1.0
var _last_touch_zone := ""
var _left_brow: Node3D
var _right_brow: Node3D
var _left_cheek: Node3D
var _right_cheek: Node3D
var _speech_root: Node3D
var _speech_rings: Array[Node3D] = []
var _emotion_root: Node3D
var _emotion_sparks: Array[Node3D] = []
var _touch_halo: Node3D

func _ready() -> void:
	super._ready()
	_build_performance_rig()
	_connect_performance_director()
	_sync_performance_from_director()

func set_development_phase(phase_name: String, level: int = 1) -> void:
	super.set_development_phase(phase_name, level)
	_performance["phase"] = phase_name.to_upper()

func set_mood(value: String) -> void:
	super.set_mood(value)
	_performance["mood"] = value.to_upper()

func play_action_animation(action_name: String) -> void:
	super.play_action_animation(action_name)
	if _performance.get("intent", "idle") == "idle":
		_performance["intent"] = action_name.to_lower()

func apply_performance(snapshot: Dictionary) -> void:
	if snapshot.is_empty():
		return
	_performance = snapshot.duplicate(true)
	_performance_clock = 0.0
	_performance_blend = 0.0
	var gesture := str(_performance.get("gesture", "breathing"))
	var duration := float(_performance.get("duration", 1.2))
	if not _authored_character_active:
		_set_gesture(_fallback_gesture(gesture), duration)
	else:
		_play_authored_animation(_authored_clip(gesture))
	if _touch_halo != null:
		_touch_halo.visible = str(_performance.get("intent", "")) == "touch"

func get_character_life_snapshot() -> Dictionary:
	var visible_speech_rings := 0
	for ring in _speech_rings:
		if ring != null and ring.visible:
			visible_speech_rings += 1
	return {
		"performance": _performance.duplicate(true),
		"blend": _performance_blend,
		"clock": _performance_clock,
		"last_touch_zone": _last_touch_zone,
		"facial_rig": _left_brow != null and _right_brow != null and _left_cheek != null and _right_cheek != null,
		"speech_ring_count": _speech_rings.size(),
		"visible_speech_rings": visible_speech_rings,
		"emotion_spark_count": _emotion_sparks.size(),
		"authored_character": _authored_character_active
	}

func _process(delta: float) -> void:
	super._process(delta)
	if not _active or _bitling == null:
		return
	_performance_clock += maxf(delta, 0.0)
	_performance_blend = move_toward(_performance_blend, 1.0, delta * 5.5)
	_apply_character_performance(delta)
	_animate_performance_fx(delta)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var click := event as InputEventMouseButton
		if click.pressed and click.button_index == MOUSE_BUTTON_LEFT:
			_request_touch_performance(click.position)
	elif event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed:
			_request_touch_performance(touch.position)
	super._gui_input(event)

func _request_touch_performance(position: Vector2) -> void:
	if size.x <= 1.0 or size.y <= 1.0:
		return
	var zone := _classify_touch_zone(position)
	var normalized := Vector2(
		clampf(position.x / size.x * 2.0 - 1.0, -1.0, 1.0),
		clampf(position.y / size.y * 2.0 - 1.0, -1.0, 1.0)
	)
	_last_touch_zone = zone
	touch_zone_pressed.emit(zone, normalized)
	var director := get_node_or_null("/root/CharacterPerformance")
	if director != null and director.has_method("request_touch"):
		director.call("request_touch", zone, normalized)

func _classify_touch_zone(position: Vector2) -> String:
	var x := clampf(position.x / maxf(size.x, 1.0), 0.0, 1.0)
	var y := clampf(position.y / maxf(size.y, 1.0), 0.0, 1.0)
	if y < 0.32:
		if x < 0.38:
			return "ear_left"
		if x > 0.62:
			return "ear_right"
		return "head"
	if y < 0.62:
		return "belly" if x > 0.30 and x < 0.70 else "body"
	if y < 0.84:
		return "paw_left" if x < 0.50 else "paw_right"
	if x > 0.66:
		return "tail"
	return "body"

func _connect_performance_director() -> void:
	var director := get_node_or_null("/root/CharacterPerformance")
	if director == null or not director.has_signal("performance_changed"):
		return
	var callback := Callable(self, "_on_performance_changed")
	if not director.is_connected("performance_changed", callback):
		director.connect("performance_changed", callback)

func _sync_performance_from_director() -> void:
	var director := get_node_or_null("/root/CharacterPerformance")
	if director != null and director.has_method("get_snapshot"):
		apply_performance(director.call("get_snapshot") as Dictionary)

func _on_performance_changed(snapshot: Dictionary) -> void:
	apply_performance(snapshot)

func _build_performance_rig() -> void:
	if _bitling == null or _authored_character_active or _head == null:
		return
	var brow_material := _emissive_material(Color("17072a"), Color("b783ff"), 2.4)
	_left_brow = _mesh(_capsule(0.040, 0.44, 12, 6), brow_material, Vector3(-0.43, 0.43, 1.02), _head)
	_left_brow.rotation_degrees = Vector3(0.0, 0.0, 76.0)
	_right_brow = _mesh(_capsule(0.040, 0.44, 12, 6), brow_material, Vector3(0.43, 0.43, 1.02), _head)
	_right_brow.rotation_degrees = Vector3(0.0, 0.0, 104.0)

	var cheek_material := _emissive_material(Color("260724"), Color("ff5bd8"), 2.2)
	_left_cheek = _mesh(_sphere(0.105, 16, 10), cheek_material, Vector3(-0.66, -0.30, 0.98), _head)
	_left_cheek.scale = Vector3(1.40, 0.50, 0.32)
	_right_cheek = _mesh(_sphere(0.105, 16, 10), cheek_material, Vector3(0.66, -0.30, 0.98), _head)
	_right_cheek.scale = Vector3(1.40, 0.50, 0.32)

	_speech_root = Node3D.new()
	_speech_root.name = "SpeechPulseRig"
	_speech_root.position = Vector3(0.0, -0.48, 1.18)
	_head.add_child(_speech_root)
	for index in range(3):
		var ring_mesh := TorusMesh.new()
		ring_mesh.inner_radius = 0.13 + float(index) * 0.11
		ring_mesh.outer_radius = 0.155 + float(index) * 0.11
		ring_mesh.rings = 28
		ring_mesh.ring_segments = 6
		var ring := MeshInstance3D.new()
		ring.mesh = ring_mesh
		ring.material_override = _emissive_material(Color("041020"), Color("42e8ff"), 2.0 - float(index) * 0.24)
		ring.rotation_degrees = Vector3(90.0, 0.0, 0.0)
		ring.visible = false
		_speech_root.add_child(ring)
		_speech_rings.append(ring)

	_emotion_root = Node3D.new()
	_emotion_root.name = "EmotionSparkRig"
	_emotion_root.position = Vector3(0.0, 1.05, 0.0)
	_head.add_child(_emotion_root)
	for index in range(8):
		var color := Color("42e8ff") if index % 2 == 0 else Color("ff3ed1")
		var spark := _mesh(_sphere(0.040 + 0.008 * float(index % 3), 10, 6), _emissive_material(Color("061020"), color, 2.8), Vector3.ZERO, _emotion_root)
		_emotion_sparks.append(spark)

	_touch_halo = Node3D.new()
	_touch_halo.name = "TouchHalo"
	_touch_halo.position = Vector3(0.0, 0.90, 0.20)
	_touch_halo.visible = false
	_bitling.add_child(_touch_halo)
	var halo_mesh := TorusMesh.new()
	halo_mesh.inner_radius = 1.42
	halo_mesh.outer_radius = 1.47
	halo_mesh.rings = 48
	halo_mesh.ring_segments = 7
	var halo := MeshInstance3D.new()
	halo.mesh = halo_mesh
	halo.material_override = _emissive_material(Color("100726"), Color("ff5bd8"), 2.6)
	halo.rotation_degrees = Vector3(90.0, 0.0, 0.0)
	_touch_halo.add_child(halo)

func _apply_character_performance(_delta: float) -> void:
	if _authored_character_active:
		_apply_authored_performance_root()
		return
	if _head == null or _left_eye == null or _right_eye == null or _mouth == null:
		return
	var expression_name := str(_performance.get("expression", "attentive"))
	var profile: Dictionary = EXPRESSION_PROFILES.get(expression_name, EXPRESSION_PROFILES["attentive"]) as Dictionary
	var phase_name := str(_performance.get("phase", _development_phase)).to_upper()
	var phase: Dictionary = PHASE_MOTION.get(phase_name, PHASE_MOTION["CHILD"]) as Dictionary
	var tempo := float(phase.get("tempo", 1.0))
	var intensity := clampf(float(_performance.get("intensity", 0.5)), 0.0, 1.35)
	var t := _performance_clock * tempo
	var gesture := str(_performance.get("gesture", "breathing"))
	var breath := sin(_elapsed * 2.1 * tempo)
	var pulse := sin(t * 7.0)
	var blink_closure := sin(_blink * PI) if _blink > 0.0 else 0.0
	var blink_open := maxf(0.06, 1.0 - blink_closure * 0.94)

	var eye_open := float(profile.get("eye_open", 1.0)) * blink_open
	var eye_wide := float(profile.get("eye_wide", 1.0))
	_left_eye.scale = Vector3(eye_wide, maxf(0.06, eye_open), 1.0)
	_right_eye.scale = Vector3(eye_wide, maxf(0.06, eye_open), 1.0)

	var mouth_x := float(profile.get("mouth_x", 0.78))
	var mouth_y := float(profile.get("mouth_y", 0.44))
	if bool(_performance.get("speaking", false)) or gesture == "converse":
		var speech_rate := float(_performance.get("speech_rate", 1.0))
		mouth_y *= 0.58 + 0.62 * absf(sin(_performance_clock * 11.0 * speech_rate))
		mouth_x *= 0.92 + 0.12 * sin(_performance_clock * 5.4 * speech_rate)
	elif gesture == "nibble":
		mouth_y *= 0.55 + 0.70 * absf(sin(t * 8.8))
	elif gesture == "belly_laugh":
		mouth_y *= 1.0 + 0.28 * absf(pulse)
	_mouth.scale = Vector3(mouth_x, mouth_y, 0.35)
	_mouth.position.y = -0.46 + (0.035 if expression_name in ["astonished", "surprised"] else 0.0)
	_mouth.rotation_degrees.z = 90.0

	var brow_value := float(profile.get("brow", 0.0))
	_apply_brows(brow_value, gesture, t)
	var cheek_strength := float(profile.get("cheek", 0.0))
	_apply_cheeks(cheek_strength, pulse)
	_apply_gaze(str(_performance.get("gaze", "player")), t)

	var head_pitch := 0.0
	var head_yaw := 0.0
	var head_roll := sin(_elapsed * 0.55 * tempo) * float(phase.get("sway", 0.03))
	var body_roll := 0.0
	var squash := Vector3.ONE
	var ear_offset := float(profile.get("ear", 0.0))
	var tail_multiplier := float(phase.get("tail", 0.8))
	match gesture:
		"greeting":
			head_roll += 0.12 * sin(t * 4.0)
			head_pitch = -0.06
			tail_multiplier *= 1.55
		"nibble":
			head_pitch = 0.10 + 0.07 * sin(t * 8.0)
			tail_multiplier *= 1.45
		"bounce_spin":
			body_roll = 0.13 * sin(t * 6.8)
			head_roll += 0.12 * sin(t * 5.7)
			squash = Vector3(1.0 + 0.055 * pulse, 1.0 - 0.045 * pulse, 1.0 + 0.055 * pulse)
			_bitling.position.y += absf(sin(t * 4.6)) * 0.12 * intensity
			tail_multiplier *= 2.05
		"focus_tilt":
			head_roll += 0.20
			head_pitch = -0.05
			ear_offset += 0.12
		"nuzzle":
			head_roll -= 0.14
			head_pitch = 0.05
			_head.position.x = -0.05 + 0.08 * sin(t * 2.6)
			tail_multiplier *= 1.20
		"settle", "sleep_breath":
			head_pitch = 0.15
			ear_offset -= 0.16
			squash = Vector3(1.03, 0.94, 1.03)
			tail_multiplier *= 0.36
		"transform":
			head_pitch = -0.08 * sin(t * 4.4)
			squash = Vector3(1.0 + 0.09 * pulse, 1.0 - 0.07 * pulse, 1.0 + 0.09 * pulse)
			ear_offset += 0.18
			tail_multiplier *= 1.65
		"scout":
			head_yaw = sin(t * 1.8) * 0.24
			ear_offset += 0.16
		"head_pat":
			head_pitch = 0.08
			ear_offset -= 0.12
			squash = Vector3(1.04, 0.93, 1.04)
		"ear_twitch_left":
			ear_offset += 0.18 * sin(t * 14.0)
			_left_ear.rotation.z += 0.28 * sin(t * 18.0)
		"ear_twitch_right":
			ear_offset += 0.18 * sin(t * 14.0)
			_right_ear.rotation.z -= 0.28 * sin(t * 18.0)
		"belly_laugh":
			head_roll += 0.10 * sin(t * 7.0)
			squash = Vector3(1.0 + 0.07 * absf(pulse), 1.0 - 0.055 * absf(pulse), 1.0 + 0.07 * absf(pulse))
			tail_multiplier *= 1.80
		"paw_wave_left":
			body_roll = 0.10 + 0.08 * sin(t * 7.0)
			head_roll += 0.08
		"paw_wave_right":
			body_roll = -0.10 - 0.08 * sin(t * 7.0)
			head_roll -= 0.08
		"tail_chase":
			head_yaw = 0.28 + 0.14 * sin(t * 5.0)
			body_roll = -0.12 * sin(t * 6.0)
			tail_multiplier *= 2.30
		"friendly_bob":
			head_pitch = -0.04 + 0.07 * sin(t * 4.0)
			tail_multiplier *= 1.30

	_head.rotation.x += head_pitch * _performance_blend
	_head.rotation.y = head_yaw * _performance_blend
	_head.rotation.z += head_roll * _performance_blend
	_bitling.rotation.z = body_roll * _performance_blend
	_bitling.scale *= Vector3.ONE.lerp(squash, _performance_blend)
	var breath_scale := float(phase.get("breath", 0.05)) * breath
	_body.scale *= Vector3(1.0 + breath_scale * 0.55, 1.0 + breath_scale, 1.0 + breath_scale * 0.55)
	_left_ear.rotation.z += ear_offset * _performance_blend
	_right_ear.rotation.z -= ear_offset * _performance_blend
	_tail.rotation.y = sin(_elapsed * 1.72 * tempo * maxf(tail_multiplier, 0.12)) * (0.24 + 0.22 * tail_multiplier)
	_bitling.position.y += sin(_elapsed * 1.9 * tempo) * float(phase.get("bob", 0.04))

func _apply_brows(value: float, gesture: String, t: float) -> void:
	if _left_brow == null or _right_brow == null:
		return
	var asymmetry := 0.0
	if gesture in ["focus_tilt", "scout"]:
		asymmetry = 0.12
	elif gesture == "ear_twitch_left":
		asymmetry = 0.18 * sin(t * 12.0)
	elif gesture == "ear_twitch_right":
		asymmetry = -0.18 * sin(t * 12.0)
	_left_brow.position.y = 0.43 + value * 0.28 + asymmetry * 0.16
	_right_brow.position.y = 0.43 + value * 0.28 - asymmetry * 0.16
	_left_brow.rotation.z = deg_to_rad(76.0) - value * 0.65 + asymmetry
	_right_brow.rotation.z = deg_to_rad(104.0) + value * 0.65 + asymmetry

func _apply_cheeks(strength: float, pulse: float) -> void:
	if _left_cheek == null or _right_cheek == null:
		return
	var visible_strength := clampf(strength * (0.88 + 0.12 * pulse), 0.0, 1.0)
	_left_cheek.visible = visible_strength > 0.08
	_right_cheek.visible = visible_strength > 0.08
	var scale_value := 0.62 + visible_strength * 0.62
	_left_cheek.scale = Vector3(1.40, 0.50, 0.32) * scale_value
	_right_cheek.scale = Vector3(1.40, 0.50, 0.32) * scale_value

func _apply_gaze(mode: String, t: float) -> void:
	if _left_iris == null or _right_iris == null:
		return
	var offset := Vector3.ZERO
	match mode:
		"scan":
			offset = Vector3(sin(t * 1.7) * 0.105, cos(t * 1.1) * 0.045, 0.0)
		"up":
			offset = Vector3(0.0, 0.075, 0.0)
		"down":
			offset = Vector3(0.0, -0.075, 0.0)
		"object":
			offset = Vector3(0.055, -0.040, 0.0)
		"touch":
			offset = Vector3(_pointer_current.x * 0.12, -_pointer_current.y * 0.09, 0.0)
		_:
			offset = Vector3(_pointer_current.x * 0.075, -_pointer_current.y * 0.055, 0.0)
	var base_z := 0.35 if _left_iris.position.z > 0.33 else 0.31
	_left_iris.position = Vector3(0.0, 0.0, base_z) + offset
	_right_iris.position = Vector3(0.0, 0.0, base_z) + offset

func _animate_performance_fx(_delta: float) -> void:
	var speaking := bool(_performance.get("speaking", false)) or str(_performance.get("gesture", "")) == "converse"
	var speech_rate := float(_performance.get("speech_rate", 1.0))
	for index in range(_speech_rings.size()):
		var ring := _speech_rings[index]
		if ring == null:
			continue
		ring.visible = speaking
		if speaking:
			var cycle := fmod(_performance_clock * speech_rate * 1.8 + float(index) * 0.31, 1.0)
			var scale_value := 0.62 + cycle * 0.85
			ring.scale = Vector3.ONE * scale_value
			var mesh := ring as MeshInstance3D
			if mesh != null:
				mesh.transparency = clampf(cycle, 0.0, 0.92)

	var expression := str(_performance.get("expression", "attentive"))
	var sparks_active := expression in ["ecstatic", "delighted", "astonished", "bright"]
	for index in range(_emotion_sparks.size()):
		var spark := _emotion_sparks[index]
		if spark == null:
			continue
		spark.visible = sparks_active
		if sparks_active:
			var angle := TAU * float(index) / float(maxi(_emotion_sparks.size(), 1)) + _performance_clock * (0.72 + 0.08 * float(index % 3))
			var radius := 0.86 + 0.10 * sin(_performance_clock * 2.1 + float(index))
			spark.position = Vector3(cos(angle) * radius, 0.18 + sin(angle * 1.7) * 0.34, sin(angle) * 0.16)
			spark.scale = Vector3.ONE * (0.72 + 0.28 * absf(sin(_performance_clock * 4.0 + float(index))))

	if _touch_halo != null and _touch_halo.visible:
		_touch_halo.rotation.y += 0.018
		var halo_scale := 0.92 + 0.08 * sin(_performance_clock * 5.2)
		_touch_halo.scale = Vector3.ONE * halo_scale

func _apply_authored_performance_root() -> void:
	if _bitling == null:
		return
	var intensity := clampf(float(_performance.get("intensity", 0.5)), 0.0, 1.35)
	var tempo := float(_performance.get("phase_tempo", 1.0))
	var gesture := str(_performance.get("gesture", "breathing"))
	var pulse := sin(_performance_clock * 6.0 * tempo)
	if gesture in ["bounce_spin", "transform", "belly_laugh"]:
		_bitling.scale *= Vector3(1.0 + 0.035 * pulse * intensity, 1.0 - 0.028 * pulse * intensity, 1.0 + 0.035 * pulse * intensity)
	if gesture in ["focus_tilt", "nuzzle", "head_pat"]:
		_bitling.rotation.z += 0.055 * sin(_performance_clock * 2.6 * tempo)

func _fallback_gesture(gesture: String) -> String:
	match gesture:
		"nibble":
			return "feed"
		"bounce_spin", "belly_laugh", "tail_chase":
			return "play"
		"focus_tilt", "scout":
			return "curious"
		"nuzzle", "head_pat":
			return "cared_for"
		"settle", "sleep_breath":
			return "sleepy"
		"transform":
			return "transform"
		"ear_twitch_left", "ear_twitch_right", "paw_wave_left", "paw_wave_right":
			return "surprised"
		_:
			return "happy" if str(_performance.get("mood", "NEUTRAL")) in ["HAPPY", "CONTENT", "ECSTATIC"] else "idle"

func _authored_clip(gesture: String) -> String:
	match gesture:
		"nibble":
			return "feed"
		"bounce_spin", "belly_laugh", "tail_chase":
			return "play"
		"focus_tilt", "scout":
			return "learn"
		"nuzzle", "head_pat":
			return "care"
		"settle", "sleep_breath":
			return "sleep"
		"transform":
			return "excited"
		_:
			return "idle"
