extends SubViewportContainer

## Production-grade, asset-independent 3D presentation for the living companion.
## Everything is built from standard Godot meshes/materials so it runs in Xogot
## without native extensions while a final authored character asset is produced.

signal bitling_pressed

const COLOR_VOID := Color("03040d")
const COLOR_ROOM := Color("080b1d")
const COLOR_CYAN := Color("35e9ff")
const COLOR_BLUE := Color("337cff")
const COLOR_VIOLET := Color("9e4dff")
const COLOR_MAGENTA := Color("ff3ed1")
const COLOR_GREEN := Color("53f0a6")
const COLOR_GOLD := Color("ffc85a")
const COLOR_FUR := Color("10091e")
const COLOR_FUR_LIFT := Color("251044")
const COLOR_EYE := Color("43deff")

var mood: String = "HAPPY"
var rarity: String = "COMMON"

var _viewport: SubViewport
var _world: Node3D
var _camera: Camera3D
var _bitling: Node3D
var _head: Node3D
var _body: Node3D
var _left_ear: Node3D
var _right_ear: Node3D
var _tail: Node3D
var _left_eye: Node3D
var _right_eye: Node3D
var _left_iris: Node3D
var _right_iris: Node3D
var _mouth: Node3D
var _platform_rings: Array[Node3D] = []
var _spark_lights: Array[OmniLight3D] = []
var _elapsed := 0.0
var _reaction := 0.0
var _blink := 0.0
var _next_blink := 2.8
var _pointer_target := Vector2.ZERO
var _pointer_current := Vector2.ZERO
var _active := true

func _ready() -> void:
	stretch = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_ALL
	clip_contents = true
	_build_viewport()
	_build_world()
	resized.connect(_sync_viewport_size)
	_sync_viewport_size()
	set_process(true)

func set_mood(value: String) -> void:
	mood = value.to_upper()
	_update_expression()

func set_rarity(value: String) -> void:
	rarity = value.to_upper()
	_update_rarity()

func play_reaction() -> void:
	_reaction = 1.0
	if _bitling != null:
		var tween := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tween.tween_property(_bitling, "scale", Vector3(1.10, 0.90, 1.10), 0.10)
		tween.tween_property(_bitling, "scale", Vector3.ONE, 0.28)

func _build_viewport() -> void:
	_viewport = SubViewport.new()
	_viewport.name = "Production3DViewport"
	_viewport.own_world_3d = true
	_viewport.transparent_bg = false
	_viewport.render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE
	_viewport.msaa_3d = Viewport.MSAA_2X
	add_child(_viewport)

func _build_world() -> void:
	_world = Node3D.new()
	_world.name = "ProductionWorld"
	_viewport.add_child(_world)
	_build_environment()
	_build_camera()
	_build_lighting()
	_build_room()
	_build_platform()
	_build_bitling()

func _build_environment() -> void:
	var world_environment := WorldEnvironment.new()
	world_environment.name = "NeonEnvironment"
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = COLOR_VOID
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("372463")
	environment.ambient_light_energy = 0.72
	environment.reflected_light_source = Environment.REFLECTION_SOURCE_BG
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.glow_enabled = true
	environment.glow_intensity = 1.35
	environment.glow_strength = 1.12
	environment.glow_bloom = 0.18
	world_environment.environment = environment
	_world.add_child(world_environment)

func _build_camera() -> void:
	_camera = Camera3D.new()
	_camera.name = "HeroCamera"
	_camera.current = true
	_camera.fov = 42.0
	_camera.position = Vector3(0.0, 1.55, 7.8)
	_world.add_child(_camera)
	_camera.look_at(Vector3(0.0, 1.35, 0.0), Vector3.UP)

func _build_lighting() -> void:
	var key := DirectionalLight3D.new()
	key.name = "MoonKey"
	key.light_color = Color("b6d7ff")
	key.light_energy = 0.72
	key.rotation_degrees = Vector3(-42.0, -28.0, 0.0)
	key.shadow_enabled = true
	_world.add_child(key)

	_add_omni("CyanRim", Vector3(-3.2, 2.4, 1.2), COLOR_CYAN, 5.8, 3.2)
	_add_omni("MagentaRim", Vector3(3.4, 2.0, 0.6), COLOR_MAGENTA, 5.4, 3.0)
	_add_omni("VioletFill", Vector3(0.0, 4.4, -1.8), COLOR_VIOLET, 7.2, 2.4)
	_add_omni("FaceFill", Vector3(0.0, 1.5, 3.0), Color("7edfff"), 4.5, 1.5)

func _build_room() -> void:
	var floor_material := _material(Color("060817"), 0.42, 0.58)
	var floor := _mesh(_box(Vector3(11.5, 0.18, 9.0)), floor_material, Vector3(0.0, -0.55, 0.0))
	floor.name = "ReflectiveFloor"

	var wall_material := _material(COLOR_ROOM, 0.18, 0.78)
	_mesh(_box(Vector3(11.5, 6.2, 0.18)), wall_material, Vector3(0.0, 2.25, -3.35))
	_mesh(_box(Vector3(0.18, 6.2, 7.0)), wall_material, Vector3(-5.6, 2.25, 0.0))
	_mesh(_box(Vector3(0.18, 6.2, 7.0)), wall_material, Vector3(5.6, 2.25, 0.0))

	_build_window_city()
	_build_floor_grid()
	_build_room_props()

func _build_window_city() -> void:
	var glass := _emissive_material(Color("08052a"), Color("2810a0"), 0.55)
	var window := _mesh(_box(Vector3(7.4, 3.9, 0.09)), glass, Vector3(0.0, 2.3, -3.22))
	window.name = "SkyWindow"

	var frame_material := _emissive_material(Color("07101d"), COLOR_CYAN, 1.7)
	_mesh(_box(Vector3(7.8, 0.07, 0.13)), frame_material, Vector3(0.0, 4.25, -3.12))
	_mesh(_box(Vector3(7.8, 0.07, 0.13)), frame_material, Vector3(0.0, 0.35, -3.12))
	_mesh(_box(Vector3(0.07, 3.9, 0.13)), frame_material, Vector3(-3.9, 2.3, -3.12))
	_mesh(_box(Vector3(0.07, 3.9, 0.13)), frame_material, Vector3(3.9, 2.3, -3.12))

	var moon := _mesh(_sphere(0.42, 20, 12), _emissive_material(Color("b8f8ff"), COLOR_CYAN, 3.6), Vector3(2.55, 3.48, -3.0))
	moon.scale = Vector3(1.0, 1.0, 0.22)

	for index in range(18):
		var x := -3.55 + float(index) * 0.42
		var height := 0.8 + 1.75 * (0.5 + 0.5 * sin(float(index) * 1.91))
		var width := 0.26 + 0.10 * float(index % 3)
		var building := _mesh(
			_box(Vector3(width, height, 0.28)),
			_material(Color("040817"), 0.55, 0.80),
			Vector3(x, 0.45 + height * 0.5, -3.02)
		)
		building.name = "CityBuilding%02d" % index
		var window_color := COLOR_CYAN if index % 2 == 0 else COLOR_MAGENTA
		for floor_index in range(3):
			var window_y := 0.72 + float(floor_index) * 0.42
			if window_y < height:
				_mesh(
					_box(Vector3(width * 0.58, 0.055, 0.035)),
					_emissive_material(window_color, window_color, 2.6),
					Vector3(x, 0.45 + window_y, -2.83)
				)

func _build_floor_grid() -> void:
	var grid_material := _emissive_material(Color("050914"), COLOR_VIOLET, 1.4)
	for index in range(13):
		var z := -2.6 + float(index) * 0.48
		_mesh(_box(Vector3(9.2, 0.018, 0.025)), grid_material, Vector3(0.0, -0.44, z))
	for index in range(17):
		var x := -4.6 + float(index) * 0.575
		_mesh(_box(Vector3(0.025, 0.018, 6.4)), grid_material, Vector3(x, -0.44, 0.25))

func _build_room_props() -> void:
	var furniture := _material(Color("0b1025"), 0.28, 0.72)
	var trim := _emissive_material(Color("101020"), COLOR_MAGENTA, 1.8)
	_mesh(_box(Vector3(2.0, 0.18, 0.95)), furniture, Vector3(-3.65, 0.12, -1.5))
	_mesh(_box(Vector3(0.12, 1.0, 0.12)), furniture, Vector3(-4.4, -0.22, -1.5))
	_mesh(_box(Vector3(0.12, 1.0, 0.12)), furniture, Vector3(-2.9, -0.22, -1.5))
	_mesh(_box(Vector3(1.25, 0.82, 0.08)), trim, Vector3(-3.65, 0.92, -1.62))

	var couch_material := _material(Color("211034"), 0.12, 0.92)
	_mesh(_box(Vector3(2.2, 0.55, 1.0)), couch_material, Vector3(3.65, -0.10, -1.4))
	_mesh(_box(Vector3(2.2, 0.78, 0.28)), couch_material, Vector3(3.65, 0.43, -1.83))
	_mesh(_box(Vector3(0.30, 0.74, 1.0)), couch_material, Vector3(2.62, 0.0, -1.4))
	_mesh(_box(Vector3(0.30, 0.74, 1.0)), couch_material, Vector3(4.68, 0.0, -1.4))

	var pot := _mesh(_cylinder(0.36, 0.48, 0.55, 18), _material(Color("351341"), 0.30, 0.70), Vector3(4.45, -0.18, 0.25))
	pot.rotation_degrees = Vector3(0.0, 0.0, 0.0)
	for index in range(7):
		var leaf := _mesh(_capsule(0.08, 1.0, 12, 6), _material(Color("163d35"), 0.05, 0.72), Vector3(4.45, 0.55, 0.25))
		leaf.rotation_degrees = Vector3(-28.0 + float(index % 3) * 16.0, float(index) * 51.0, 0.0)

func _build_platform() -> void:
	var base_material := _material(Color("091126"), 0.62, 0.28)
	var base := _mesh(_cylinder(2.15, 2.32, 0.22, 64), base_material, Vector3(0.0, -0.30, 0.22))
	base.name = "SignalPlatform"

	for index in range(4):
		var ring := Node3D.new()
		ring.name = "EnergyRing%02d" % index
		ring.position = Vector3(0.0, -0.16 + float(index) * 0.035, 0.22)
		_world.add_child(ring)
		var torus := TorusMesh.new()
		torus.inner_radius = 1.28 + float(index) * 0.18
		torus.outer_radius = 1.35 + float(index) * 0.18
		torus.rings = 48
		torus.ring_segments = 8
		var ring_mesh := MeshInstance3D.new()
		ring_mesh.mesh = torus
		ring_mesh.material_override = _emissive_material(
			Color("06101e"),
			COLOR_CYAN if index % 2 == 0 else COLOR_VIOLET,
			3.2 - float(index) * 0.35
		)
		ring.add_child(ring_mesh)
		_platform_rings.append(ring)

func _build_bitling() -> void:
	_bitling = Node3D.new()
	_bitling.name = "Bitling3D"
	_bitling.position = Vector3(0.0, -0.10, 0.2)
	_world.add_child(_bitling)

	var fur := _material(COLOR_FUR, 0.04, 0.84)
	var fur_lift := _material(COLOR_FUR_LIFT, 0.08, 0.76)
	var paw := _material(Color("28104d"), 0.16, 0.58)
	var crystal := _emissive_material(Color("3a1459"), COLOR_MAGENTA, 3.4)
	var white_eye := _material(Color("dffbff"), 0.05, 0.22)
	var iris_material := _emissive_material(Color("052040"), COLOR_EYE, 4.1)
	var pupil_material := _material(Color("00020a"), 0.0, 0.18)

	_body = Node3D.new()
	_body.name = "BodyRig"
	_body.position = Vector3(0.0, 0.78, 0.0)
	_bitling.add_child(_body)
	var body_mesh := _mesh(_sphere(0.92, 28, 16), fur, Vector3.ZERO, _body)
	body_mesh.scale = Vector3(1.0, 1.12, 0.82)

	_head = Node3D.new()
	_head.name = "HeadRig"
	_head.position = Vector3(0.0, 1.70, 0.02)
	_bitling.add_child(_head)
	var head_mesh := _mesh(_sphere(1.20, 32, 18), fur, Vector3.ZERO, _head)
	head_mesh.scale = Vector3(1.16, 1.02, 0.88)

	_left_ear = _build_ear(-1.0, fur, fur_lift)
	_right_ear = _build_ear(1.0, fur, fur_lift)
	_build_horns(crystal)

	_left_eye = _build_eye(-0.48, white_eye, iris_material, pupil_material)
	_right_eye = _build_eye(0.48, white_eye, iris_material, pupil_material)

	_mouth = _mesh(_capsule(0.075, 0.34, 16, 8), _emissive_material(Color("3f092e"), Color("ff6ed8"), 2.8), Vector3(0.0, -0.48, 1.00), _head)
	_mouth.rotation_degrees = Vector3(0.0, 0.0, 90.0)
	_mouth.scale = Vector3(1.0, 0.55, 0.35)

	_build_limbs(fur, paw)
	_build_tail(fur, fur_lift)
	_build_fur_tufts(fur_lift)
	_update_expression()
	_update_rarity()

func _build_ear(side: float, fur: StandardMaterial3D, inner: StandardMaterial3D) -> Node3D:
	var rig := Node3D.new()
	rig.name = "LeftEar" if side < 0.0 else "RightEar"
	rig.position = Vector3(0.72 * side, 0.72, 0.0)
	rig.rotation_degrees = Vector3(-4.0, 0.0, -22.0 * side)
	_head.add_child(rig)
	var ear := _mesh(_capsule(0.34, 1.45, 20, 10), fur, Vector3(0.0, 0.48, 0.0), rig)
	ear.scale = Vector3(0.88, 1.0, 0.70)
	var inner_ear := _mesh(_capsule(0.20, 1.02, 16, 8), inner, Vector3(0.0, 0.50, 0.24), rig)
	inner_ear.scale = Vector3(0.75, 1.0, 0.42)
	return rig

func _build_horns(crystal: StandardMaterial3D) -> void:
	for side in [-1.0, 1.0]:
		var horn := _mesh(_cone(0.0, 0.19, 0.58, 8), crystal, Vector3(0.28 * side, 0.95, 0.20), _head)
		horn.rotation_degrees = Vector3(-12.0, 0.0, -16.0 * side)

func _build_eye(x: float, white_eye: StandardMaterial3D, iris: StandardMaterial3D, pupil: StandardMaterial3D) -> Node3D:
	var eye_rig := Node3D.new()
	eye_rig.position = Vector3(x, 0.02, 0.86)
	_head.add_child(eye_rig)
	var eye := _mesh(_sphere(0.43, 24, 14), white_eye, Vector3.ZERO, eye_rig)
	eye.scale = Vector3(0.94, 1.12, 0.42)
	var iris_node := Node3D.new()
	iris_node.position = Vector3(0.0, 0.0, 0.31)
	eye_rig.add_child(iris_node)
	var iris_mesh := _mesh(_sphere(0.28, 20, 12), iris, Vector3.ZERO, iris_node)
	iris_mesh.scale = Vector3(0.95, 1.08, 0.30)
	var pupil_mesh := _mesh(_sphere(0.14, 16, 10), pupil, Vector3(0.0, 0.0, 0.18), iris_node)
	pupil_mesh.scale = Vector3(0.80, 1.0, 0.25)
	var highlight := _mesh(_sphere(0.065, 12, 8), _emissive_material(Color.WHITE, Color.WHITE, 4.5), Vector3(-0.09, 0.12, 0.25), iris_node)
	highlight.scale = Vector3(1.0, 1.0, 0.35)
	if x < 0.0:
		_left_iris = iris_node
	else:
		_right_iris = iris_node
	return eye_rig

func _build_limbs(fur: StandardMaterial3D, paw: StandardMaterial3D) -> void:
	for side in [-1.0, 1.0]:
		var arm := _mesh(_capsule(0.22, 0.92, 16, 8), fur, Vector3(0.86 * side, 0.80, 0.04), _bitling)
		arm.rotation_degrees = Vector3(0.0, 0.0, -34.0 * side)
		var foot := _mesh(_sphere(0.45, 20, 12), paw, Vector3(0.58 * side, 0.02, 0.30), _bitling)
		foot.scale = Vector3(1.25, 0.72, 1.20)
		for toe_index in range(3):
			var toe_x := (float(toe_index) - 1.0) * 0.15
			var toe := _mesh(_sphere(0.10, 12, 8), _emissive_material(Color("2b0c4c"), COLOR_VIOLET, 2.2), Vector3(0.58 * side + toe_x, 0.04, 0.70), _bitling)
			toe.scale = Vector3(0.88, 0.72, 0.50)

func _build_tail(fur: StandardMaterial3D, fur_lift: StandardMaterial3D) -> void:
	_tail = Node3D.new()
	_tail.name = "TailRig"
	_tail.position = Vector3(0.78, 0.55, -0.22)
	_bitling.add_child(_tail)
	for index in range(5):
		var segment := _mesh(_sphere(0.28 - float(index) * 0.025, 16, 10), fur if index < 3 else fur_lift, Vector3(0.28 + float(index) * 0.30, 0.12 + sin(float(index) * 0.75) * 0.16, 0.0), _tail)
		segment.scale = Vector3(1.30, 0.92, 0.92)

func _build_fur_tufts(material: StandardMaterial3D) -> void:
	for index in range(24):
		var angle := TAU * float(index) / 24.0
		var y := 1.68 + 0.95 * sin(angle * 1.5)
		var radius := 1.04 + 0.08 * sin(float(index) * 2.3)
		var tuft := _mesh(_sphere(0.18, 12, 8), material, Vector3(cos(angle) * radius, y, sin(angle) * 0.34), _bitling)
		tuft.scale = Vector3(0.72, 1.45, 0.72)

func _process(delta: float) -> void:
	if not _active or _bitling == null:
		return
	_elapsed += delta
	_reaction = move_toward(_reaction, 0.0, delta * 2.8)
	_pointer_current = _pointer_current.lerp(_pointer_target, clampf(delta * 8.0, 0.0, 1.0))
	var reduce_motion := _reduce_motion_enabled()
	var motion_scale := 0.25 if reduce_motion else 1.0
	_bitling.position.y = -0.10 + sin(_elapsed * 1.85) * 0.045 * motion_scale + _reaction * 0.08
	_bitling.rotation.y = sin(_elapsed * 0.55) * 0.035 * motion_scale
	_head.rotation.z = sin(_elapsed * 0.72) * 0.025 * motion_scale
	_left_ear.rotation.z = deg_to_rad(22.0) + sin(_elapsed * 1.20) * 0.045 * motion_scale
	_right_ear.rotation.z = deg_to_rad(-22.0) - sin(_elapsed * 1.12) * 0.045 * motion_scale
	_tail.rotation.y = sin(_elapsed * 1.65) * 0.48 * motion_scale
	for index in range(_platform_rings.size()):
		_platform_rings[index].rotation.y += delta * (0.22 + float(index) * 0.08) * (1.0 if index % 2 == 0 else -1.0)
	_update_blink(delta)
	_update_eye_tracking()
	_update_light_pulse()

func _update_blink(delta: float) -> void:
	_next_blink -= delta
	if _next_blink <= 0.0 and _blink <= 0.0:
		_blink = 1.0
		_next_blink = 2.2 + 2.8 * (0.5 + 0.5 * sin(_elapsed * 1.37))
	if _blink > 0.0:
		_blink = move_toward(_blink, 0.0, delta * 5.8)
		var closure := sin(_blink * PI)
		var eye_scale := maxf(0.08, 1.0 - closure * 0.92)
		_left_eye.scale.y = eye_scale
		_right_eye.scale.y = eye_scale
	else:
		_left_eye.scale.y = 1.0
		_right_eye.scale.y = 1.0

func _update_eye_tracking() -> void:
	var offset := Vector3(_pointer_current.x * 0.10, -_pointer_current.y * 0.08, 0.0)
	if _left_iris != null:
		_left_iris.position = Vector3(0.0, 0.0, 0.31) + offset
	if _right_iris != null:
		_right_iris.position = Vector3(0.0, 0.0, 0.31) + offset

func _update_light_pulse() -> void:
	for index in range(_spark_lights.size()):
		_spark_lights[index].light_energy = 2.2 + 0.45 * sin(_elapsed * 1.4 + float(index))

func _update_expression() -> void:
	if _mouth == null:
		return
	match mood:
		"ECSTATIC", "HAPPY":
			_mouth.scale = Vector3(1.0, 0.58, 0.35)
			_mouth.rotation_degrees.z = 90.0
		"TIRED", "SAD", "DISTRESSED":
			_mouth.scale = Vector3(0.72, 0.34, 0.30)
			_mouth.rotation_degrees.z = 90.0
			_mouth.position.y = -0.42
		_:
			_mouth.scale = Vector3(0.62, 0.42, 0.32)
			_mouth.rotation_degrees.z = 90.0

func _update_rarity() -> void:
	if _spark_lights.is_empty():
		return
	var enabled_count := 0
	match rarity:
		"LEGENDARY":
			enabled_count = _spark_lights.size()
		"RARE":
			enabled_count = mini(3, _spark_lights.size())
		"UNCOMMON":
			enabled_count = mini(1, _spark_lights.size())
		_:
			enabled_count = 0
	for index in range(_spark_lights.size()):
		_spark_lights[index].visible = index < enabled_count

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var mouse := event as InputEventMouseMotion
		_update_pointer(mouse.position)
	elif event is InputEventMouseButton:
		var click := event as InputEventMouseButton
		if click.pressed and click.button_index == MOUSE_BUTTON_LEFT:
			_update_pointer(click.position)
			play_reaction()
			bitling_pressed.emit()
			accept_event()
	elif event is InputEventScreenDrag:
		var drag := event as InputEventScreenDrag
		_update_pointer(drag.position)
	elif event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		_update_pointer(touch.position)
		if touch.pressed:
			play_reaction()
			bitling_pressed.emit()
			accept_event()

func _update_pointer(position: Vector2) -> void:
	if size.x <= 1.0 or size.y <= 1.0:
		return
	_pointer_target = Vector2(
		clampf(position.x / size.x * 2.0 - 1.0, -1.0, 1.0),
		clampf(position.y / size.y * 2.0 - 1.0, -1.0, 1.0)
	)

func _sync_viewport_size() -> void:
	if _viewport == null:
		return
	var target := Vector2i(maxi(480, int(size.x)), maxi(540, int(size.y)))
	_viewport.size = target

func _notification(what: int) -> void:
	if _viewport == null:
		return
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		_active = false
		_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	elif what == NOTIFICATION_APPLICATION_FOCUS_IN:
		_active = true
		_viewport.render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE

func _reduce_motion_enabled() -> bool:
	var state := get_node_or_null("/root/GameState")
	return state != null and bool(state.settings.get("reduce_motion", false))

func _add_omni(node_name: String, position: Vector3, color: Color, range_value: float, energy: float) -> OmniLight3D:
	var light := OmniLight3D.new()
	light.name = node_name
	light.position = position
	light.light_color = color
	light.light_energy = energy
	light.omni_range = range_value
	light.shadow_enabled = false
	_world.add_child(light)
	_spark_lights.append(light)
	return light

func _mesh(mesh_resource: PrimitiveMesh, material: Material, position: Vector3, parent: Node3D = null) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.mesh = mesh_resource
	instance.material_override = material
	instance.position = position
	(parent if parent != null else _world).add_child(instance)
	return instance

func _material(color: Color, metallic: float, roughness: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.metallic = metallic
	material.roughness = roughness
	material.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
	return material

func _emissive_material(base_color: Color, emission_color: Color, energy: float) -> StandardMaterial3D:
	var material := _material(base_color, 0.28, 0.36)
	material.emission_enabled = true
	material.emission = emission_color
	material.emission_energy_multiplier = energy
	return material

func _sphere(radius: float, radial_segments: int, rings: int) -> SphereMesh:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = radial_segments
	mesh.rings = rings
	return mesh

func _box(size_value: Vector3) -> BoxMesh:
	var mesh := BoxMesh.new()
	mesh.size = size_value
	return mesh

func _capsule(radius: float, height: float, radial_segments: int, rings: int) -> CapsuleMesh:
	var mesh := CapsuleMesh.new()
	mesh.radius = radius
	mesh.height = height
	mesh.radial_segments = radial_segments
	mesh.rings = rings
	return mesh

func _cylinder(top_radius: float, bottom_radius: float, height: float, radial_segments: int) -> CylinderMesh:
	var mesh := CylinderMesh.new()
	mesh.top_radius = top_radius
	mesh.bottom_radius = bottom_radius
	mesh.height = height
	mesh.radial_segments = radial_segments
	return mesh

func _cone(top_radius: float, bottom_radius: float, height: float, radial_segments: int) -> CylinderMesh:
	return _cylinder(top_radius, bottom_radius, height, radial_segments)
