extends "res://scripts/ui/production_bitling_stage_3d.gd"

## Second production art pass. Refines composition, eye treatment, silhouette,
## room depth and ambient motion based on automated phone/laptop captures.

var _ambient_sparks: Array[Node3D] = []
var _holograms: Array[Node3D] = []

func _build_environment() -> void:
	var world_environment := WorldEnvironment.new()
	world_environment.name = "MetafinalEnvironment"
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("01030b")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("2a1b55")
	environment.ambient_light_energy = 0.52
	environment.reflected_light_source = Environment.REFLECTION_SOURCE_BG
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.glow_enabled = true
	environment.glow_intensity = 0.78
	environment.glow_strength = 0.92
	environment.glow_bloom = 0.10
	world_environment.environment = environment
	_world.add_child(world_environment)

func _build_camera() -> void:
	_camera = Camera3D.new()
	_camera.name = "MetafinalHeroCamera"
	_camera.current = true
	_camera.fov = 38.0
	_camera.position = Vector3(0.0, 1.50, 9.35)
	_world.add_child(_camera)
	_camera.look_at(Vector3(0.0, 1.28, 0.0), Vector3.UP)

func _build_lighting() -> void:
	var key := DirectionalLight3D.new()
	key.name = "SoftMoonKey"
	key.light_color = Color("c6ddff")
	key.light_energy = 0.50
	key.rotation_degrees = Vector3(-46.0, -30.0, 0.0)
	key.shadow_enabled = true
	_world.add_child(key)
	_add_omni("CyanEdge", Vector3(-3.5, 2.7, 1.5), COLOR_CYAN, 6.2, 1.85)
	_add_omni("MagentaEdge", Vector3(3.7, 2.3, 1.0), COLOR_MAGENTA, 6.0, 1.72)
	_add_omni("VioletCeiling", Vector3(0.0, 4.8, -1.2), COLOR_VIOLET, 7.5, 1.35)
	_add_omni("EyeSoftbox", Vector3(0.0, 1.7, 3.4), Color("7bdfff"), 4.8, 0.82)
	_add_omni("FloorBounce", Vector3(0.0, -0.1, 1.2), Color("8c55ff"), 4.2, 0.75)

func _build_room() -> void:
	super._build_room()
	_build_neon_architecture()
	_build_holographic_props()
	_build_ambient_sparks()

func _build_neon_architecture() -> void:
	var cyan_strip := _emissive_material(Color("06101b"), COLOR_CYAN, 2.15)
	var violet_strip := _emissive_material(Color("0d071b"), COLOR_VIOLET, 2.05)
	for side in [-1.0, 1.0]:
		_mesh(_box(Vector3(0.055, 4.8, 0.055)), cyan_strip, Vector3(4.92 * side, 2.15, -2.25))
		_mesh(_box(Vector3(0.055, 3.9, 0.055)), violet_strip, Vector3(4.58 * side, 1.72, -1.62))
	for height in [0.45, 1.45, 2.45, 3.45]:
		_mesh(_box(Vector3(9.2, 0.035, 0.04)), ColorMaterial(violet_strip), Vector3(0.0, height, -3.0))

	for index in range(5):
		var arc_root := Node3D.new()
		arc_root.position = Vector3(0.0, 0.0, -2.94 + float(index) * 0.015)
		_world.add_child(arc_root)
		var torus := TorusMesh.new()
		torus.inner_radius = 3.85 - float(index) * 0.12
		torus.outer_radius = 3.89 - float(index) * 0.12
		torus.rings = 64
		torus.ring_segments = 6
		var arc := MeshInstance3D.new()
		arc.mesh = torus
		arc.material_override = _emissive_material(Color("080c18"), COLOR_CYAN if index % 2 == 0 else COLOR_VIOLET, 1.45)
		arc.scale = Vector3(1.0, 0.60, 1.0)
		arc.rotation_degrees = Vector3(90.0, 0.0, 0.0)
		arc_root.add_child(arc)

func ColorMaterial(source: StandardMaterial3D) -> StandardMaterial3D:
	return source

func _build_holographic_props() -> void:
	var panel_material := _emissive_material(Color("03142a"), COLOR_CYAN, 1.85)
	panel_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	panel_material.albedo_color.a = 0.42
	panel_material.emission.a = 0.72
	for data in [
		[Vector3(-4.15, 2.45, -1.95), Vector3(0.85, 1.10, 0.035), -7.0],
		[Vector3(4.05, 2.75, -2.05), Vector3(0.95, 1.25, 0.035), 8.0],
		[Vector3(-3.55, 1.25, -1.55), Vector3(0.62, 0.72, 0.030), -4.0]
	]:
		var panel := _mesh(_box(data[1] as Vector3), panel_material, data[0] as Vector3)
		panel.rotation_degrees.y = float(data[2])
		_holograms.append(panel)
		var core := _mesh(_sphere(0.11, 14, 8), _emissive_material(COLOR_CYAN, COLOR_CYAN, 2.6), (data[0] as Vector3) + Vector3(0.0, 0.0, 0.08))
		_holograms.append(core)

	var holo_ring_root := Node3D.new()
	holo_ring_root.position = Vector3(3.7, 1.62, -1.48)
	_world.add_child(holo_ring_root)
	for index in range(3):
		var torus := TorusMesh.new()
		torus.inner_radius = 0.26 + float(index) * 0.12
		torus.outer_radius = 0.29 + float(index) * 0.12
		torus.rings = 32
		torus.ring_segments = 6
		var mesh := MeshInstance3D.new()
		mesh.mesh = torus
		mesh.material_override = _emissive_material(Color("061020"), COLOR_MAGENTA if index % 2 == 0 else COLOR_CYAN, 2.2)
		holo_ring_root.add_child(mesh)
	_holograms.append(holo_ring_root)

func _build_ambient_sparks() -> void:
	for index in range(16):
		var x := -4.0 + 8.0 * float(index % 8) / 7.0
		var y := 0.6 + 0.42 * float(index % 5)
		var z := -1.6 + 0.35 * float(index % 3)
		var material := _emissive_material(Color("061020"), COLOR_CYAN if index % 2 == 0 else COLOR_MAGENTA, 2.0)
		var spark := _mesh(_sphere(0.025 + 0.012 * float(index % 3), 10, 6), material, Vector3(x, y, z))
		_ambient_sparks.append(spark)

func _build_eye(x: float, _white_eye: StandardMaterial3D, _iris: StandardMaterial3D, _pupil: StandardMaterial3D) -> Node3D:
	var eye_rig := Node3D.new()
	eye_rig.position = Vector3(x, 0.01, 0.91)
	_head.add_child(eye_rig)

	var socket_material := _material(Color("01040d"), 0.28, 0.13)
	var socket := _mesh(_sphere(0.47, 28, 16), socket_material, Vector3.ZERO, eye_rig)
	socket.scale = Vector3(0.94, 1.10, 0.42)

	var iris_node := Node3D.new()
	iris_node.position = Vector3(0.0, 0.0, 0.35)
	eye_rig.add_child(iris_node)
	var iris_material := _emissive_material(Color("04152b"), COLOR_EYE, 1.55)
	var iris_mesh := _mesh(_sphere(0.325, 24, 14), iris_material, Vector3.ZERO, iris_node)
	iris_mesh.scale = Vector3(0.96, 1.06, 0.28)

	var inner_iris := _mesh(_sphere(0.235, 22, 12), _emissive_material(Color("081133"), Color("3778ff"), 1.20), Vector3(0.0, 0.0, 0.14), iris_node)
	inner_iris.scale = Vector3(0.93, 1.04, 0.22)
	var pupil := _mesh(_sphere(0.145, 18, 10), _material(Color("000109"), 0.10, 0.08), Vector3(0.0, 0.0, 0.23), iris_node)
	pupil.scale = Vector3(0.82, 1.12, 0.20)

	var primary_highlight := _mesh(_sphere(0.070, 12, 8), _emissive_material(Color.WHITE, Color.WHITE, 2.9), Vector3(-0.105, 0.135, 0.31), iris_node)
	primary_highlight.scale = Vector3(1.0, 1.0, 0.30)
	var secondary_highlight := _mesh(_sphere(0.035, 10, 6), _emissive_material(Color("b8f8ff"), Color("b8f8ff"), 2.1), Vector3(0.10, -0.10, 0.30), iris_node)
	secondary_highlight.scale = Vector3(1.0, 1.0, 0.28)

	var outer_ring := TorusMesh.new()
	outer_ring.inner_radius = 0.375
	outer_ring.outer_radius = 0.405
	outer_ring.rings = 36
	outer_ring.ring_segments = 6
	var ring_mesh := MeshInstance3D.new()
	ring_mesh.mesh = outer_ring
	ring_mesh.material_override = _emissive_material(Color("041020"), COLOR_CYAN, 1.65)
	ring_mesh.position = Vector3(0.0, 0.0, 0.39)
	ring_mesh.rotation_degrees = Vector3(90.0, 0.0, 0.0)
	eye_rig.add_child(ring_mesh)

	if x < 0.0:
		_left_iris = iris_node
	else:
		_right_iris = iris_node
	return eye_rig

func _build_ear(side: float, fur: StandardMaterial3D, inner: StandardMaterial3D) -> Node3D:
	var rig := super._build_ear(side, fur, inner)
	var tip_material := _material(Color("311058"), 0.08, 0.78)
	for index in range(4):
		var tuft := _mesh(_capsule(0.10, 0.62, 12, 6), tip_material, Vector3((float(index) - 1.5) * 0.12, 1.10 + float(index % 2) * 0.08, 0.0), rig)
		tuft.rotation_degrees = Vector3(0.0, 0.0, (float(index) - 1.5) * 12.0)
	return rig

func _build_fur_tufts(material: StandardMaterial3D) -> void:
	super._build_fur_tufts(material)
	for index in range(28):
		var angle := TAU * float(index) / 28.0
		var tuft := _mesh(
			_capsule(0.08, 0.48, 10, 5),
			material,
			Vector3(cos(angle) * 1.18, 1.72 + sin(angle) * 0.90, sin(angle) * 0.28),
			_bitling
		)
		tuft.rotation_degrees = Vector3(0.0, 0.0, -rad_to_deg(angle) + 90.0)

func _process(delta: float) -> void:
	super._process(delta)
	for index in range(_ambient_sparks.size()):
		var spark := _ambient_sparks[index]
		spark.position.y += delta * (0.03 + 0.015 * float(index % 4))
		spark.position.x += sin(_elapsed * 0.7 + float(index)) * delta * 0.015
		if spark.position.y > 3.9:
			spark.position.y = 0.45
	for index in range(_holograms.size()):
		_holograms[index].rotation.y += delta * (0.05 + float(index % 3) * 0.018)

func _sync_viewport_size() -> void:
	super._sync_viewport_size()
	if _camera == null or size.y <= 1.0:
		return
	var aspect := size.x / size.y
	var distance := 9.6 if aspect < 0.78 else 9.15 if aspect < 1.15 else 8.75
	_camera.position = Vector3(0.0, 1.48, distance)
	_camera.look_at(Vector3(0.0, 1.22, 0.0), Vector3.UP)
