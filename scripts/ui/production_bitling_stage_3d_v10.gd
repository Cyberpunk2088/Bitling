extends "res://scripts/ui/production_bitling_stage_3d_v9.gd"

## Wave 3 Living Home stage. The room is a reactive 3D layer driven by the
## persistent LivingHome service and remains replaceable by authored GLB assets.

var _home_root: Node3D
var _window_root: Node3D
var _weather_root: Node3D
var _weather_particles: Array[Node3D] = []
var _home_props: Dictionary = {}
var _clutter_nodes: Array[Node3D] = []
var _decoration_nodes: Dictionary = {}
var _plant_leaves: Array[Node3D] = []
var _holo_elements: Array[Node3D] = []
var _home_lights: Array[OmniLight3D] = []
var _accent_materials: Array[StandardMaterial3D] = []
var _sky_material: StandardMaterial3D
var _window_material: StandardMaterial3D
var _home_snapshot: Dictionary = {}
var _home_clock := 0.0

func _ready() -> void:
	super._ready()
	_build_living_home_layer()
	_connect_living_home()
	_sync_living_home()

func set_story_beat(beat_id: String) -> void:
	super.set_story_beat(beat_id)
	var rooftop_active := beat_id.strip_edges().to_lower() in ["prismatic_rooftops", "promise_of_growth"]
	if _home_root != null:
		_home_root.visible = not rooftop_active

func get_living_home_visual_snapshot() -> Dictionary:
	var visible_decorations: Array[String] = []
	for key_variant in _decoration_nodes.keys():
		var key := str(key_variant)
		var node := _decoration_nodes[key] as Node3D
		if node != null and node.visible:
			visible_decorations.append(key)
	var visible_clutter := 0
	for node in _clutter_nodes:
		if node != null and node.visible:
			visible_clutter += 1
	return {
		"home_layer": _home_root != null,
		"home_visible": _home_root != null and _home_root.visible,
		"prop_count": _home_props.size(),
		"weather_particle_count": _weather_particles.size(),
		"visible_clutter": visible_clutter,
		"visible_decorations": visible_decorations,
		"time_segment": _home_snapshot.get("time_segment", "DAY"),
		"weather": _home_snapshot.get("weather", "CLEAR"),
		"room_mood": _home_snapshot.get("room_mood", "BALANCED")
	}

func _process(delta: float) -> void:
	super._process(delta)
	if not _active or _home_root == null or not _home_root.visible:
		return
	_home_clock += maxf(delta, 0.0)
	var reduce_motion := _reduce_motion_enabled()
	var motion_scale := 0.25 if reduce_motion else 1.0
	_animate_home_props(delta, motion_scale)
	_animate_weather(delta, motion_scale)

func _build_living_home_layer() -> void:
	if _world == null:
		return
	_home_root = Node3D.new()
	_home_root.name = "LivingHomeEnvironment"
	_world.add_child(_home_root)

	var shell := _material(Color("05091a"), 0.70, 0.24)
	var shell_soft := _material(Color("0a1025"), 0.48, 0.30)
	var metal := _material(Color("121936"), 0.42, 0.58)
	var glass := _material(Color("07192c"), 0.20, 0.12)
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass.albedo_color.a = 0.54
	var accent_cyan := _emissive_material(Color("041621"), Color("42e8ff"), 2.3)
	var accent_violet := _emissive_material(Color("140624"), Color("a855f7"), 2.5)
	var accent_magenta := _emissive_material(Color("21051c"), Color("f044d4"), 2.3)
	var accent_green := _emissive_material(Color("052019"), Color("64e6a2"), 2.0)
	_accent_materials = [accent_cyan, accent_violet, accent_magenta, accent_green]

	_mesh(_box(Vector3(11.8, 0.18, 7.2)), shell, Vector3(0.0, -0.48, -0.30), _home_root)
	_mesh(_box(Vector3(11.8, 4.8, 0.18)), shell_soft, Vector3(0.0, 1.75, -3.55), _home_root)
	_mesh(_box(Vector3(0.18, 4.8, 7.2)), shell, Vector3(-5.82, 1.75, -0.30), _home_root)
	_mesh(_box(Vector3(0.18, 4.8, 7.2)), shell, Vector3(5.82, 1.75, -0.30), _home_root)

	_build_weather_window(glass, metal, accent_cyan)
	_build_sleep_pod(shell_soft, metal, accent_violet)
	_build_learning_desk(metal, glass, accent_cyan)
	_build_garden_wall(shell_soft, accent_green)
	_build_holo_projector(metal, accent_magenta, accent_cyan)
	_build_memory_archive(metal, accent_violet)
	_build_cleaning_drone(metal, accent_cyan)
	_build_signal_kitchen(metal, accent_green)
	_build_clutter(shell_soft, accent_magenta)
	_build_decorations(accent_cyan, accent_violet, accent_magenta, accent_green, metal)
	_build_home_lighting()

func _build_weather_window(glass: StandardMaterial3D, metal: StandardMaterial3D, accent: StandardMaterial3D) -> void:
	_window_root = Node3D.new()
	_window_root.name = "WeatherWindow"
	_window_root.position = Vector3(0.0, 1.55, -3.32)
	_home_root.add_child(_window_root)
	_window_material = glass.duplicate() as StandardMaterial3D
	_sky_material = _emissive_material(Color("061124"), Color("173f78"), 1.2)
	_mesh(_box(Vector3(6.8, 3.0, 0.10)), _sky_material, Vector3.ZERO, _window_root)
	_mesh(_box(Vector3(6.4, 2.65, 0.06)), _window_material, Vector3(0.0, 0.0, 0.10), _window_root)
	for x in [-3.5, 0.0, 3.5]:
		_mesh(_box(Vector3(0.10, 3.25, 0.16)), metal, Vector3(float(x), 0.0, 0.22), _window_root)
	_mesh(_box(Vector3(7.15, 0.12, 0.16)), accent, Vector3(0.0, -1.58, 0.24), _window_root)
	_weather_root = Node3D.new()
	_weather_root.name = "WindowWeather"
	_window_root.add_child(_weather_root)
	for index in range(36):
		var drop := _mesh(_capsule(0.012, 0.34 + float(index % 4) * 0.08, 6, 3), accent, Vector3(-3.0 + float(index % 9) * 0.75, 1.2 - float(index / 9) * 0.72, 0.25), _weather_root)
		drop.rotation_degrees.z = -12.0
		drop.visible = false
		_weather_particles.append(drop)
	_home_props["weather_window"] = _window_root

func _build_sleep_pod(shell: StandardMaterial3D, metal: StandardMaterial3D, accent: StandardMaterial3D) -> void:
	var root_node := Node3D.new()
	root_node.name = "SleepPod"
	root_node.position = Vector3(-3.85, -0.15, -1.15)
	_home_root.add_child(root_node)
	var base := _mesh(_capsule(0.72, 2.45, 22, 10), shell, Vector3.ZERO, root_node)
	base.rotation_degrees.z = 90.0
	base.scale = Vector3(1.0, 0.72, 1.35)
	var cushion := _mesh(_capsule(0.56, 1.92, 20, 10), _material(Color("25133b"), 0.92, 0.06), Vector3(0.0, 0.20, 0.15), root_node)
	cushion.rotation_degrees.z = 90.0
	cushion.scale = Vector3(1.0, 0.58, 1.25)
	for side in [-1.0, 1.0]:
		_mesh(_box(Vector3(0.12, 0.70, 1.35)), metal, Vector3(1.22 * side, 0.08, 0.0), root_node)
		_mesh(_sphere(0.11, 12, 8), accent, Vector3(1.18 * side, 0.58, 0.62), root_node)
	_home_props["sleep_pod"] = root_node

func _build_learning_desk(metal: StandardMaterial3D, glass: StandardMaterial3D, accent: StandardMaterial3D) -> void:
	var root_node := Node3D.new()
	root_node.name = "LearningDesk"
	root_node.position = Vector3(3.70, -0.10, -1.15)
	_home_root.add_child(root_node)
	_mesh(_box(Vector3(2.45, 0.16, 1.18)), metal, Vector3(0.0, 0.52, 0.0), root_node)
	for side in [-1.0, 1.0]:
		_mesh(_box(Vector3(0.14, 1.10, 0.18)), metal, Vector3(0.92 * side, -0.02, 0.36), root_node)
	var screen := _mesh(_box(Vector3(1.55, 0.92, 0.06)), glass, Vector3(0.0, 1.14, -0.18), root_node)
	screen.rotation_degrees.x = -8.0
	for index in range(4):
		var line := _mesh(_box(Vector3(1.05 - float(index) * 0.10, 0.025, 0.025)), accent, Vector3(-0.12 + float(index % 2) * 0.20, 1.30 - float(index) * 0.16, -0.12), root_node)
		_holo_elements.append(line)
	_home_props["learning_desk"] = root_node

func _build_garden_wall(shell: StandardMaterial3D, accent: StandardMaterial3D) -> void:
	var root_node := Node3D.new()
	root_node.name = "GardenWall"
	root_node.position = Vector3(-5.25, 1.18, 0.35)
	_home_root.add_child(root_node)
	_mesh(_box(Vector3(0.28, 3.10, 2.35)), shell, Vector3.ZERO, root_node)
	for row in range(4):
		for column in range(3):
			var leaf := _mesh(_capsule(0.07, 0.62, 10, 5), accent, Vector3(0.20, 1.05 - float(row) * 0.65, -0.72 + float(column) * 0.72), root_node)
			leaf.rotation_degrees = Vector3(0.0, 0.0, -28.0 + float(column) * 28.0)
			_plant_leaves.append(leaf)
	_home_props["garden_wall"] = root_node

func _build_holo_projector(metal: StandardMaterial3D, accent_a: StandardMaterial3D, accent_b: StandardMaterial3D) -> void:
	var root_node := Node3D.new()
	root_node.name = "HoloProjector"
	root_node.position = Vector3(3.15, -0.12, 1.45)
	_home_root.add_child(root_node)
	_mesh(_cylinder(0.58, 0.42, 20), metal, Vector3.ZERO, root_node)
	for index in range(3):
		var ring_mesh := TorusMesh.new()
		ring_mesh.inner_radius = 0.52 + float(index) * 0.20
		ring_mesh.outer_radius = 0.56 + float(index) * 0.20
		ring_mesh.rings = 28
		ring_mesh.ring_segments = 6
		var ring := MeshInstance3D.new()
		ring.mesh = ring_mesh
		ring.material_override = accent_a if index % 2 == 0 else accent_b
		ring.position.y = 0.70 + float(index) * 0.26
		ring.rotation_degrees.x = 90.0
		root_node.add_child(ring)
		_holo_elements.append(ring)
	_home_props["holo_projector"] = root_node

func _build_memory_archive(metal: StandardMaterial3D, accent: StandardMaterial3D) -> void:
	var root_node := Node3D.new()
	root_node.name = "MemoryArchive"
	root_node.position = Vector3(5.10, 0.35, 0.55)
	_home_root.add_child(root_node)
	for row in range(4):
		for column in range(2):
			var orb := _mesh(_sphere(0.16, 14, 8), accent, Vector3(0.0, float(row) * 0.48, -0.32 + float(column) * 0.64), root_node)
			_holo_elements.append(orb)
	_mesh(_box(Vector3(0.36, 2.20, 1.25)), metal, Vector3(-0.18, 0.70, 0.0), root_node)
	_home_props["memory_archive"] = root_node

func _build_cleaning_drone(metal: StandardMaterial3D, accent: StandardMaterial3D) -> void:
	var root_node := Node3D.new()
	root_node.name = "CleaningDrone"
	root_node.position = Vector3(-2.60, -0.26, 2.00)
	_home_root.add_child(root_node)
	_mesh(_sphere(0.32, 18, 10), metal, Vector3.ZERO, root_node)
	for side in [-1.0, 1.0]:
		_mesh(_sphere(0.09, 10, 6), accent, Vector3(0.22 * side, 0.06, 0.27), root_node)
	_home_props["cleaning_drone"] = root_node

func _build_signal_kitchen(metal: StandardMaterial3D, accent: StandardMaterial3D) -> void:
	var root_node := Node3D.new()
	root_node.name = "SignalKitchen"
	root_node.position = Vector3(-4.55, -0.05, 1.90)
	_home_root.add_child(root_node)
	_mesh(_box(Vector3(1.50, 1.05, 1.20)), metal, Vector3.ZERO, root_node)
	for index in range(3):
		_mesh(_sphere(0.10, 12, 7), accent, Vector3(-0.40 + float(index) * 0.40, 0.36, 0.62), root_node)
	_home_props["signal_kitchen"] = root_node

func _build_clutter(shell: StandardMaterial3D, accent: StandardMaterial3D) -> void:
	for index in range(12):
		var root_node := Node3D.new()
		root_node.name = "Clutter%02d" % index
		root_node.position = Vector3(-4.4 + float(index % 6) * 1.72, -0.34, 2.20 - float(index / 6) * 0.72)
		root_node.rotation_degrees.y = float(index * 29)
		_home_root.add_child(root_node)
		if index % 3 == 0:
			_mesh(_box(Vector3(0.38, 0.12, 0.30)), shell, Vector3.ZERO, root_node)
		elif index % 3 == 1:
			_mesh(_sphere(0.14, 10, 6), accent, Vector3.ZERO, root_node)
		else:
			var scrap := _mesh(_capsule(0.05, 0.42, 8, 4), shell, Vector3.ZERO, root_node)
			scrap.rotation_degrees.z = 70.0
		root_node.visible = false
		_clutter_nodes.append(root_node)

func _build_decorations(cyan: StandardMaterial3D, violet: StandardMaterial3D, magenta: StandardMaterial3D, green: StandardMaterial3D, metal: StandardMaterial3D) -> void:
	_add_decoration_orb("moon_lantern", Vector3(-2.65, 2.70, -2.85), cyan, 0.30)
	_add_decoration_mobile("prism_mobile", Vector3(2.55, 2.62, -2.75), violet)
	_add_decoration_ribbon("memory_ribbon", Vector3(-4.95, 2.65, -2.65), magenta)
	_add_decoration_cushion("moss_cushion", Vector3(-2.70, -0.20, 0.95), green)
	_add_decoration_panel("star_map", Vector3(4.55, 2.30, -3.20), cyan)
	_add_decoration_orb("tiny_planet", Vector3(2.00, 2.15, -2.85), violet, 0.24)
	_add_decoration_totem("friend_totem", Vector3(4.85, -0.05, 1.85), magenta, metal)
	_add_decoration_mobile("signal_chimes", Vector3(-1.80, 2.72, -2.60), cyan)
	_add_decoration_rug("aurora_rug", Vector3(0.0, -0.37, 1.30), violet)
	_add_decoration_orb("archive_orb", Vector3(4.50, 1.75, 0.20), magenta, 0.22)
	for node_variant in _decoration_nodes.values():
		var node := node_variant as Node3D
		if node != null:
			node.visible = false

func _add_decoration_orb(id: String, position: Vector3, material: StandardMaterial3D, radius: float) -> void:
	var root_node := Node3D.new()
	root_node.name = id.capitalize()
	root_node.position = position
	_home_root.add_child(root_node)
	_mesh(_sphere(radius, 18, 10), material, Vector3.ZERO, root_node)
	var ring := TorusMesh.new()
	ring.inner_radius = radius * 1.35
	ring.outer_radius = radius * 1.48
	ring.rings = 24
	ring.ring_segments = 5
	var ring_node := MeshInstance3D.new()
	ring_node.mesh = ring
	ring_node.material_override = material
	ring_node.rotation_degrees.x = 68.0
	root_node.add_child(ring_node)
	_decoration_nodes[id] = root_node

func _add_decoration_mobile(id: String, position: Vector3, material: StandardMaterial3D) -> void:
	var root_node := Node3D.new()
	root_node.name = id.capitalize()
	root_node.position = position
	_home_root.add_child(root_node)
	for index in range(4):
		var shard := _mesh(_cone(0.02, 0.13, 0.42, 8), material, Vector3(-0.30 + float(index) * 0.20, -0.18 - float(index % 2) * 0.22, 0.0), root_node)
		shard.rotation_degrees.z = float(index * 24)
	_decoration_nodes[id] = root_node

func _add_decoration_ribbon(id: String, position: Vector3, material: StandardMaterial3D) -> void:
	var root_node := Node3D.new()
	root_node.name = id.capitalize()
	root_node.position = position
	_home_root.add_child(root_node)
	for index in range(5):
		var ribbon := _mesh(_capsule(0.025, 0.72, 8, 4), material, Vector3(float(index) * 0.08, -float(index) * 0.24, 0.0), root_node)
		ribbon.rotation_degrees.z = -16.0 + float(index) * 8.0
	_decoration_nodes[id] = root_node

func _add_decoration_cushion(id: String, position: Vector3, material: StandardMaterial3D) -> void:
	var root_node := Node3D.new()
	root_node.name = id.capitalize()
	root_node.position = position
	_home_root.add_child(root_node)
	var cushion := _mesh(_sphere(0.46, 18, 10), material, Vector3.ZERO, root_node)
	cushion.scale = Vector3(1.50, 0.38, 1.10)
	_decoration_nodes[id] = root_node

func _add_decoration_panel(id: String, position: Vector3, material: StandardMaterial3D) -> void:
	var root_node := Node3D.new()
	root_node.name = id.capitalize()
	root_node.position = position
	_home_root.add_child(root_node)
	_mesh(_box(Vector3(1.35, 0.92, 0.04)), material, Vector3.ZERO, root_node)
	_decoration_nodes[id] = root_node

func _add_decoration_totem(id: String, position: Vector3, material: StandardMaterial3D, metal: StandardMaterial3D) -> void:
	var root_node := Node3D.new()
	root_node.name = id.capitalize()
	root_node.position = position
	_home_root.add_child(root_node)
	_mesh(_cylinder(0.20, 0.82, 14), metal, Vector3.ZERO, root_node)
	_mesh(_sphere(0.20, 14, 8), material, Vector3(0.0, 0.55, 0.0), root_node)
	_decoration_nodes[id] = root_node

func _add_decoration_rug(id: String, position: Vector3, material: StandardMaterial3D) -> void:
	var root_node := Node3D.new()
	root_node.name = id.capitalize()
	root_node.position = position
	_home_root.add_child(root_node)
	var rug := _mesh(_cylinder(1.35, 0.035, 36), material, Vector3.ZERO, root_node)
	rug.scale.z = 0.72
	_decoration_nodes[id] = root_node

func _build_home_lighting() -> void:
	for data in [
		{"position": Vector3(-3.8, 2.25, 0.5), "color": Color("42e8ff"), "energy": 2.2},
		{"position": Vector3(3.8, 2.10, 0.2), "color": Color("a855f7"), "energy": 2.4},
		{"position": Vector3(0.0, 3.10, -1.8), "color": Color("f044d4"), "energy": 1.5}
	]:
		var light := OmniLight3D.new()
		light.position = data["position"] as Vector3
		light.light_color = data["color"] as Color
		light.light_energy = float(data["energy"])
		light.omni_range = 7.0
		_home_root.add_child(light)
		_home_lights.append(light)

func _connect_living_home() -> void:
	var service := get_node_or_null("/root/LivingHome")
	if service == null or not service.has_signal("home_changed"):
		return
	var callback := Callable(self, "_on_living_home_changed")
	if not service.is_connected("home_changed", callback):
		service.connect("home_changed", callback)

func _sync_living_home() -> void:
	var service := get_node_or_null("/root/LivingHome")
	if service != null and service.has_method("get_snapshot"):
		_apply_home_snapshot(service.call("get_snapshot") as Dictionary)

func _on_living_home_changed(snapshot: Dictionary) -> void:
	_apply_home_snapshot(snapshot)

func _apply_home_snapshot(snapshot: Dictionary) -> void:
	if snapshot.is_empty():
		return
	_home_snapshot = snapshot.duplicate(true)
	_apply_theme_colors()
	_apply_time_lighting()
	_apply_weather_visibility()
	_apply_cleanliness()
	_apply_plant_health()
	_apply_decorations()
	_apply_object_levels()

func _apply_theme_colors() -> void:
	var theme: Dictionary = _home_snapshot.get("theme", {})
	var accent := Color("#%s" % str(theme.get("accent", "42e8ff")))
	var secondary := Color("#%s" % str(theme.get("secondary", "a855f7")))
	for index in range(_accent_materials.size()):
		var material := _accent_materials[index]
		if material == null:
			continue
		var target := accent.lerp(secondary, float(index) / maxf(float(_accent_materials.size() - 1), 1.0))
		material.emission = target
		material.albedo_color = Color(target, material.albedo_color.a)
	for index in range(_home_lights.size()):
		_home_lights[index].light_color = accent.lerp(secondary, float(index) / maxf(float(_home_lights.size() - 1), 1.0))

func _apply_time_lighting() -> void:
	var segment := str(_home_snapshot.get("time_segment", "DAY"))
	var sky_color := Color("173f78")
	var energy := 1.0
	match segment:
		"MORNING":
			sky_color = Color("d46b78")
			energy = 1.10
		"DAY":
			sky_color = Color("348fbd")
			energy = 1.18
		"EVENING":
			sky_color = Color("713f9f")
			energy = 1.00
		"NIGHT":
			sky_color = Color("071733")
			energy = 0.72
	if _sky_material != null:
		_sky_material.emission = sky_color
		_sky_material.emission_energy_multiplier = 1.15 + energy
	for light in _home_lights:
		if light != null:
			light.light_energy = (1.45 + energy) * (0.82 + 0.18 * sin(_home_clock * 0.6 + float(light.get_index())))

func _apply_weather_visibility() -> void:
	var weather := str(_home_snapshot.get("weather", "CLEAR"))
	for index in range(_weather_particles.size()):
		var particle := _weather_particles[index]
		if particle != null:
			particle.visible = weather in ["RAIN", "STORM", "SNOW"]
	if _window_material != null:
		_window_material.albedo_color.a = 0.68 if weather in ["RAIN", "STORM"] else 0.48

func _apply_cleanliness() -> void:
	var value := float(_home_snapshot.get("cleanliness", 100.0))
	var visible_count := clampi(int(round((100.0 - value) / 8.0)), 0, _clutter_nodes.size())
	for index in range(_clutter_nodes.size()):
		_clutter_nodes[index].visible = index < visible_count

func _apply_plant_health() -> void:
	var health := float(_home_snapshot.get("plant_health", 70.0)) / 100.0
	for index in range(_plant_leaves.size()):
		var leaf := _plant_leaves[index]
		if leaf == null:
			continue
		leaf.scale = Vector3(0.76 + health * 0.42, 0.62 + health * 0.58, 0.76 + health * 0.42)
		leaf.rotation.z = sin(float(index) * 0.92) * (0.22 - health * 0.10)

func _apply_decorations() -> void:
	var active: Array = _home_snapshot.get("decorations", [])
	for key_variant in _decoration_nodes.keys():
		var key := str(key_variant)
		var node := _decoration_nodes[key] as Node3D
		if node != null:
			node.visible = active.has(key)

func _apply_object_levels() -> void:
	var levels: Dictionary = _home_snapshot.get("object_levels", {})
	for key_variant in _home_props.keys():
		var key := str(key_variant)
		var node := _home_props[key] as Node3D
		if node == null:
			continue
		var level := clampi(int(levels.get(key, 1)), 1, 5)
		node.scale = Vector3.ONE * (0.94 + float(level) * 0.025)

func _animate_home_props(delta: float, motion_scale: float) -> void:
	for index in range(_holo_elements.size()):
		var node := _holo_elements[index]
		if node == null:
			continue
		node.rotation.y += delta * (0.18 + float(index % 5) * 0.06) * motion_scale
		node.position.y += sin(_home_clock * 1.4 + float(index)) * 0.0008 * motion_scale
	for index in range(_plant_leaves.size()):
		var leaf := _plant_leaves[index]
		if leaf != null:
			leaf.rotation.y = sin(_home_clock * 0.72 + float(index) * 0.44) * 0.08 * motion_scale
	var drone := _home_props.get("cleaning_drone") as Node3D
	if drone != null:
		drone.position.y = -0.26 + sin(_home_clock * 1.7) * 0.08 * motion_scale
		drone.rotation.y += delta * 0.38 * motion_scale
	for key_variant in _decoration_nodes.keys():
		var node := _decoration_nodes[key_variant] as Node3D
		if node != null and node.visible:
			node.rotation.y += delta * 0.06 * motion_scale

func _animate_weather(delta: float, motion_scale: float) -> void:
	var weather := str(_home_snapshot.get("weather", "CLEAR"))
	if weather not in ["RAIN", "STORM", "SNOW"]:
		return
	var speed := 1.8 if weather == "RAIN" else 3.6 if weather == "STORM" else 0.55
	for index in range(_weather_particles.size()):
		var particle := _weather_particles[index]
		if particle == null or not particle.visible:
			continue
		particle.position.y -= delta * speed * motion_scale
		particle.position.x += sin(_home_clock * 2.0 + float(index)) * delta * (0.14 if weather == "SNOW" else 0.04)
		if particle.position.y < -1.25:
			particle.position.y = 1.35
