extends "res://scripts/ui/production_bitling_stage_3d_v9.gd"

## Wave 3 Living Home stage. A compact data-driven 3D environment reacts to the
## persistent LivingHome state and can later be replaced by authored GLB assets.

var _home_root: Node3D
var _window_root: Node3D
var _weather_root: Node3D
var _weather_particles: Array[Node3D] = []
var _props: Dictionary = {}
var _clutter: Array[Node3D] = []
var _decorations: Dictionary = {}
var _leaves: Array[Node3D] = []
var _animated: Array[Node3D] = []
var _lights: Array[OmniLight3D] = []
var _accent_materials: Array[StandardMaterial3D] = []
var _sky_material: StandardMaterial3D
var _glass_material: StandardMaterial3D
var _snapshot: Dictionary = {}
var _home_clock := 0.0

func _ready() -> void:
	super._ready()
	_build_living_home()
	_connect_home()
	_sync_home()

func set_story_beat(beat_id: String) -> void:
	super.set_story_beat(beat_id)
	if _home_root != null:
		_home_root.visible = beat_id.strip_edges().to_lower() not in ["prismatic_rooftops", "promise_of_growth"]

func get_living_home_visual_snapshot() -> Dictionary:
	var visible_decorations: Array[String] = []
	for key_variant in _decorations.keys():
		var key := str(key_variant)
		var node := _decorations[key] as Node3D
		if node != null and node.visible:
			visible_decorations.append(key)
	var visible_clutter := 0
	for node in _clutter:
		if node != null and node.visible:
			visible_clutter += 1
	return {
		"home_layer": _home_root != null,
		"home_visible": _home_root != null and _home_root.visible,
		"prop_count": _props.size(),
		"weather_particle_count": _weather_particles.size(),
		"visible_clutter": visible_clutter,
		"visible_decorations": visible_decorations,
		"time_segment": _snapshot.get("time_segment", "DAY"),
		"weather": _snapshot.get("weather", "CLEAR"),
		"room_mood": _snapshot.get("room_mood", "BALANCED")
	}

func _process(delta: float) -> void:
	super._process(delta)
	if not _active or _home_root == null or not _home_root.visible:
		return
	_home_clock += maxf(delta, 0.0)
	var motion_scale := 0.25 if _reduce_motion_enabled() else 1.0
	for index in range(_animated.size()):
		var node := _animated[index]
		if node != null:
			node.rotation.y += delta * (0.10 + float(index % 5) * 0.035) * motion_scale
	for index in range(_leaves.size()):
		var leaf := _leaves[index]
		if leaf != null:
			leaf.rotation.y = sin(_home_clock * 0.72 + float(index) * 0.44) * 0.08 * motion_scale
	var drone := _props.get("cleaning_drone") as Node3D
	if drone != null:
		drone.position.y = -0.26 + sin(_home_clock * 1.7) * 0.08 * motion_scale
		drone.rotation.y += delta * 0.38 * motion_scale
	_animate_weather(delta, motion_scale)

func _build_living_home() -> void:
	if _world == null:
		return
	_home_root = Node3D.new()
	_home_root.name = "LivingHomeEnvironment"
	_world.add_child(_home_root)

	var shell := _material(Color("05091a"), 0.70, 0.24)
	var panel := _material(Color("0b122b"), 0.46, 0.36)
	var metal := _material(Color("151d3c"), 0.42, 0.58)
	var glass := _material(Color("07192c"), 0.20, 0.12)
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass.albedo_color.a = 0.54
	var cyan := _emissive_material(Color("041621"), Color("42e8ff"), 2.3)
	var violet := _emissive_material(Color("140624"), Color("a855f7"), 2.5)
	var magenta := _emissive_material(Color("21051c"), Color("f044d4"), 2.3)
	var green := _emissive_material(Color("052019"), Color("64e6a2"), 2.0)
	_accent_materials = [cyan, violet, magenta, green]

	_mesh(_box(Vector3(11.8, 0.18, 7.2)), shell, Vector3(0.0, -0.48, -0.30), _home_root)
	_mesh(_box(Vector3(11.8, 4.8, 0.18)), panel, Vector3(0.0, 1.75, -3.55), _home_root)
	_mesh(_box(Vector3(0.18, 4.8, 7.2)), shell, Vector3(-5.82, 1.75, -0.30), _home_root)
	_mesh(_box(Vector3(0.18, 4.8, 7.2)), shell, Vector3(5.82, 1.75, -0.30), _home_root)

	_build_window(glass, metal, cyan)
	_build_sleep_pod(panel, metal, violet)
	_build_learning_desk(metal, glass, cyan)
	_build_garden(panel, green)
	_build_projector(metal, magenta, cyan)
	_build_archive(metal, violet)
	_build_drone(metal, cyan)
	_build_kitchen(metal, green)
	_build_clutter(panel, magenta)
	_build_decorations(cyan, violet, magenta, green, metal)
	_build_lighting()

func _build_window(glass: StandardMaterial3D, metal: StandardMaterial3D, accent: StandardMaterial3D) -> void:
	_window_root = Node3D.new()
	_window_root.name = "WeatherWindow"
	_window_root.position = Vector3(0.0, 1.55, -3.32)
	_home_root.add_child(_window_root)
	_glass_material = glass.duplicate() as StandardMaterial3D
	_sky_material = _emissive_material(Color("061124"), Color("173f78"), 1.2)
	_mesh(_box(Vector3(6.8, 3.0, 0.10)), _sky_material, Vector3.ZERO, _window_root)
	_mesh(_box(Vector3(6.4, 2.65, 0.06)), _glass_material, Vector3(0.0, 0.0, 0.10), _window_root)
	for x_value in [-3.5, 0.0, 3.5]:
		_mesh(_box(Vector3(0.10, 3.25, 0.16)), metal, Vector3(float(x_value), 0.0, 0.22), _window_root)
	_mesh(_box(Vector3(7.15, 0.12, 0.16)), accent, Vector3(0.0, -1.58, 0.24), _window_root)
	_weather_root = Node3D.new()
	_weather_root.name = "WindowWeather"
	_window_root.add_child(_weather_root)
	for index in range(36):
		var drop := _mesh(_capsule(0.012, 0.34 + float(index % 4) * 0.08, 6, 3), accent, Vector3(-3.0 + float(index % 9) * 0.75, 1.2 - float(index / 9) * 0.72, 0.25), _weather_root)
		drop.rotation_degrees.z = -12.0
		drop.visible = false
		_weather_particles.append(drop)
	_props["weather_window"] = _window_root

func _build_sleep_pod(panel: StandardMaterial3D, metal: StandardMaterial3D, accent: StandardMaterial3D) -> void:
	var root_node := _prop_root("sleep_pod", Vector3(-3.85, -0.15, -1.15))
	var base := _mesh(_capsule(0.72, 2.45, 22, 10), panel, Vector3.ZERO, root_node)
	base.rotation_degrees.z = 90.0
	base.scale = Vector3(1.0, 0.72, 1.35)
	var cushion := _mesh(_capsule(0.56, 1.92, 20, 10), _material(Color("25133b"), 0.92, 0.06), Vector3(0.0, 0.20, 0.15), root_node)
	cushion.rotation_degrees.z = 90.0
	cushion.scale = Vector3(1.0, 0.58, 1.25)
	for side_value in [-1.0, 1.0]:
		var side := float(side_value)
		_mesh(_box(Vector3(0.12, 0.70, 1.35)), metal, Vector3(1.22 * side, 0.08, 0.0), root_node)
		_mesh(_sphere(0.11, 12, 8), accent, Vector3(1.18 * side, 0.58, 0.62), root_node)

func _build_learning_desk(metal: StandardMaterial3D, glass: StandardMaterial3D, accent: StandardMaterial3D) -> void:
	var root_node := _prop_root("learning_desk", Vector3(3.70, -0.10, -1.15))
	_mesh(_box(Vector3(2.45, 0.16, 1.18)), metal, Vector3(0.0, 0.52, 0.0), root_node)
	for side_value in [-1.0, 1.0]:
		_mesh(_box(Vector3(0.14, 1.10, 0.18)), metal, Vector3(0.92 * float(side_value), -0.02, 0.36), root_node)
	var screen := _mesh(_box(Vector3(1.55, 0.92, 0.06)), glass, Vector3(0.0, 1.14, -0.18), root_node)
	screen.rotation_degrees.x = -8.0
	for index in range(4):
		var line := _mesh(_box(Vector3(1.05 - float(index) * 0.10, 0.025, 0.025)), accent, Vector3(-0.12 + float(index % 2) * 0.20, 1.30 - float(index) * 0.16, -0.12), root_node)
		_animated.append(line)

func _build_garden(panel: StandardMaterial3D, accent: StandardMaterial3D) -> void:
	var root_node := _prop_root("garden_wall", Vector3(-5.25, 1.18, 0.35))
	_mesh(_box(Vector3(0.28, 3.10, 2.35)), panel, Vector3.ZERO, root_node)
	for row in range(4):
		for column in range(3):
			var leaf := _mesh(_capsule(0.07, 0.62, 10, 5), accent, Vector3(0.20, 1.05 - float(row) * 0.65, -0.72 + float(column) * 0.72), root_node)
			leaf.rotation_degrees.z = -28.0 + float(column) * 28.0
			_leaves.append(leaf)

func _build_projector(metal: StandardMaterial3D, accent_a: StandardMaterial3D, accent_b: StandardMaterial3D) -> void:
	var root_node := _prop_root("holo_projector", Vector3(3.15, -0.12, 1.45))
	_mesh(_cylinder(0.58, 0.58, 0.42, 20), metal, Vector3.ZERO, root_node)
	for index in range(3):
		var torus := TorusMesh.new()
		torus.inner_radius = 0.52 + float(index) * 0.20
		torus.outer_radius = 0.56 + float(index) * 0.20
		torus.rings = 28
		torus.ring_segments = 6
		var ring := MeshInstance3D.new()
		ring.mesh = torus
		ring.material_override = accent_a if index % 2 == 0 else accent_b
		ring.position.y = 0.70 + float(index) * 0.26
		ring.rotation_degrees.x = 90.0
		root_node.add_child(ring)
		_animated.append(ring)

func _build_archive(metal: StandardMaterial3D, accent: StandardMaterial3D) -> void:
	var root_node := _prop_root("memory_archive", Vector3(5.10, 0.35, 0.55))
	_mesh(_box(Vector3(0.36, 2.20, 1.25)), metal, Vector3(-0.18, 0.70, 0.0), root_node)
	for row in range(4):
		for column in range(2):
			var orb := _mesh(_sphere(0.16, 14, 8), accent, Vector3(0.0, float(row) * 0.48, -0.32 + float(column) * 0.64), root_node)
			_animated.append(orb)

func _build_drone(metal: StandardMaterial3D, accent: StandardMaterial3D) -> void:
	var root_node := _prop_root("cleaning_drone", Vector3(-2.60, -0.26, 2.00))
	_mesh(_sphere(0.32, 18, 10), metal, Vector3.ZERO, root_node)
	for side_value in [-1.0, 1.0]:
		_mesh(_sphere(0.09, 10, 6), accent, Vector3(0.22 * float(side_value), 0.06, 0.27), root_node)

func _build_kitchen(metal: StandardMaterial3D, accent: StandardMaterial3D) -> void:
	var root_node := _prop_root("signal_kitchen", Vector3(-4.55, -0.05, 1.90))
	_mesh(_box(Vector3(1.50, 1.05, 1.20)), metal, Vector3.ZERO, root_node)
	for index in range(3):
		_mesh(_sphere(0.10, 12, 7), accent, Vector3(-0.40 + float(index) * 0.40, 0.36, 0.62), root_node)

func _build_clutter(panel: StandardMaterial3D, accent: StandardMaterial3D) -> void:
	for index in range(12):
		var root_node := Node3D.new()
		root_node.name = "Clutter%02d" % index
		root_node.position = Vector3(-4.4 + float(index % 6) * 1.72, -0.34, 2.20 - float(index / 6) * 0.72)
		root_node.rotation_degrees.y = float(index * 29)
		_home_root.add_child(root_node)
		if index % 3 == 0:
			_mesh(_box(Vector3(0.38, 0.12, 0.30)), panel, Vector3.ZERO, root_node)
		elif index % 3 == 1:
			_mesh(_sphere(0.14, 10, 6), accent, Vector3.ZERO, root_node)
		else:
			var scrap := _mesh(_capsule(0.05, 0.42, 8, 4), panel, Vector3.ZERO, root_node)
			scrap.rotation_degrees.z = 70.0
		root_node.visible = false
		_clutter.append(root_node)

func _build_decorations(cyan: StandardMaterial3D, violet: StandardMaterial3D, magenta: StandardMaterial3D, green: StandardMaterial3D, metal: StandardMaterial3D) -> void:
	_decor_orb("moon_lantern", Vector3(-2.65, 2.70, -2.85), cyan, 0.30)
	_decor_mobile("prism_mobile", Vector3(2.55, 2.62, -2.75), violet)
	_decor_ribbon("memory_ribbon", Vector3(-4.95, 2.65, -2.65), magenta)
	_decor_cushion("moss_cushion", Vector3(-2.70, -0.20, 0.95), green)
	_decor_panel("star_map", Vector3(4.55, 2.30, -3.20), cyan)
	_decor_orb("tiny_planet", Vector3(2.00, 2.15, -2.85), violet, 0.24)
	_decor_totem("friend_totem", Vector3(4.85, -0.05, 1.85), magenta, metal)
	_decor_mobile("signal_chimes", Vector3(-1.80, 2.72, -2.60), cyan)
	_decor_rug("aurora_rug", Vector3(0.0, -0.37, 1.30), violet)
	_decor_orb("archive_orb", Vector3(4.50, 1.75, 0.20), magenta, 0.22)
	for node_variant in _decorations.values():
		(node_variant as Node3D).visible = false

func _decor_root(id: String, position: Vector3) -> Node3D:
	var root_node := Node3D.new()
	root_node.name = id.to_pascal_case()
	root_node.position = position
	_home_root.add_child(root_node)
	_decorations[id] = root_node
	return root_node

func _decor_orb(id: String, position: Vector3, material: StandardMaterial3D, radius: float) -> void:
	var root_node := _decor_root(id, position)
	_mesh(_sphere(radius, 18, 10), material, Vector3.ZERO, root_node)
	var torus := TorusMesh.new()
	torus.inner_radius = radius * 1.35
	torus.outer_radius = radius * 1.48
	torus.rings = 24
	torus.ring_segments = 5
	var ring := MeshInstance3D.new()
	ring.mesh = torus
	ring.material_override = material
	ring.rotation_degrees.x = 68.0
	root_node.add_child(ring)
	_animated.append(ring)

func _decor_mobile(id: String, position: Vector3, material: StandardMaterial3D) -> void:
	var root_node := _decor_root(id, position)
	for index in range(4):
		var shard := _mesh(_cone(0.02, 0.13, 0.42, 8), material, Vector3(-0.30 + float(index) * 0.20, -0.18 - float(index % 2) * 0.22, 0.0), root_node)
		shard.rotation_degrees.z = float(index * 24)

func _decor_ribbon(id: String, position: Vector3, material: StandardMaterial3D) -> void:
	var root_node := _decor_root(id, position)
	for index in range(5):
		var ribbon := _mesh(_capsule(0.025, 0.72, 8, 4), material, Vector3(float(index) * 0.08, -float(index) * 0.24, 0.0), root_node)
		ribbon.rotation_degrees.z = -16.0 + float(index) * 8.0

func _decor_cushion(id: String, position: Vector3, material: StandardMaterial3D) -> void:
	var cushion := _mesh(_sphere(0.46, 18, 10), material, Vector3.ZERO, _decor_root(id, position))
	cushion.scale = Vector3(1.50, 0.38, 1.10)

func _decor_panel(id: String, position: Vector3, material: StandardMaterial3D) -> void:
	_mesh(_box(Vector3(1.35, 0.92, 0.04)), material, Vector3.ZERO, _decor_root(id, position))

func _decor_totem(id: String, position: Vector3, material: StandardMaterial3D, metal: StandardMaterial3D) -> void:
	var root_node := _decor_root(id, position)
	_mesh(_cylinder(0.20, 0.20, 0.82, 14), metal, Vector3.ZERO, root_node)
	_mesh(_sphere(0.20, 14, 8), material, Vector3(0.0, 0.55, 0.0), root_node)

func _decor_rug(id: String, position: Vector3, material: StandardMaterial3D) -> void:
	var rug := _mesh(_cylinder(1.35, 1.35, 0.035, 36), material, Vector3.ZERO, _decor_root(id, position))
	rug.scale.z = 0.72

func _build_lighting() -> void:
	for data in [
		[Vector3(-3.8, 2.25, 0.5), Color("42e8ff"), 2.2],
		[Vector3(3.8, 2.10, 0.2), Color("a855f7"), 2.4],
		[Vector3(0.0, 3.10, -1.8), Color("f044d4"), 1.5]
	]:
		var light := OmniLight3D.new()
		light.position = data[0] as Vector3
		light.light_color = data[1] as Color
		light.light_energy = float(data[2])
		light.omni_range = 7.0
		_home_root.add_child(light)
		_lights.append(light)

func _prop_root(id: String, position: Vector3) -> Node3D:
	var root_node := Node3D.new()
	root_node.name = id.to_pascal_case()
	root_node.position = position
	_home_root.add_child(root_node)
	_props[id] = root_node
	return root_node

func _connect_home() -> void:
	var service := get_node_or_null("/root/LivingHome")
	if service == null or not service.has_signal("home_changed"):
		return
	var callback := Callable(self, "_on_home_changed")
	if not service.is_connected("home_changed", callback):
		service.connect("home_changed", callback)

func _sync_home() -> void:
	var service := get_node_or_null("/root/LivingHome")
	if service != null and service.has_method("get_snapshot"):
		_apply_home_snapshot(service.call("get_snapshot") as Dictionary)

func _on_home_changed(value: Dictionary) -> void:
	_apply_home_snapshot(value)

func _apply_home_snapshot(value: Dictionary) -> void:
	if value.is_empty():
		return
	_snapshot = value.duplicate(true)
	_apply_theme()
	_apply_time()
	_apply_weather()
	_apply_cleanliness()
	_apply_plants()
	_apply_decorations()
	_apply_levels()

func _apply_theme() -> void:
	var theme: Dictionary = _snapshot.get("theme", {})
	var accent := Color("#%s" % str(theme.get("accent", "42e8ff")))
	var secondary := Color("#%s" % str(theme.get("secondary", "a855f7")))
	for index in range(_accent_materials.size()):
		var material := _accent_materials[index]
		var target := accent.lerp(secondary, float(index) / 3.0)
		material.emission = target
		material.albedo_color = Color(target, material.albedo_color.a)
	for index in range(_lights.size()):
		_lights[index].light_color = accent.lerp(secondary, float(index) / 2.0)

func _apply_time() -> void:
	var segment := str(_snapshot.get("time_segment", "DAY"))
	var sky := Color("348fbd")
	var energy := 1.18
	match segment:
		"MORNING": sky = Color("d46b78"); energy = 1.10
		"EVENING": sky = Color("713f9f"); energy = 1.00
		"NIGHT": sky = Color("071733"); energy = 0.72
	if _sky_material != null:
		_sky_material.emission = sky
		_sky_material.emission_energy_multiplier = 1.15 + energy
	for light in _lights:
		light.light_energy = 1.45 + energy

func _apply_weather() -> void:
	var weather := str(_snapshot.get("weather", "CLEAR"))
	for particle in _weather_particles:
		particle.visible = weather in ["RAIN", "STORM", "SNOW"]
	if _glass_material != null:
		_glass_material.albedo_color.a = 0.68 if weather in ["RAIN", "STORM"] else 0.48

func _apply_cleanliness() -> void:
	var visible_count := clampi(int(round((100.0 - float(_snapshot.get("cleanliness", 100.0))) / 8.0)), 0, _clutter.size())
	for index in range(_clutter.size()):
		_clutter[index].visible = index < visible_count

func _apply_plants() -> void:
	var health := float(_snapshot.get("plant_health", 70.0)) / 100.0
	for index in range(_leaves.size()):
		var leaf := _leaves[index]
		leaf.scale = Vector3(0.76 + health * 0.42, 0.62 + health * 0.58, 0.76 + health * 0.42)
		leaf.rotation.z = sin(float(index) * 0.92) * (0.22 - health * 0.10)

func _apply_decorations() -> void:
	var active: Array = _snapshot.get("decorations", [])
	for key_variant in _decorations.keys():
		var key := str(key_variant)
		(_decorations[key] as Node3D).visible = active.has(key)

func _apply_levels() -> void:
	var levels: Dictionary = _snapshot.get("object_levels", {})
	for key_variant in _props.keys():
		var key := str(key_variant)
		var level := clampi(int(levels.get(key, 1)), 1, 5)
		(_props[key] as Node3D).scale = Vector3.ONE * (0.94 + float(level) * 0.025)

func _animate_weather(delta: float, motion_scale: float) -> void:
	var weather := str(_snapshot.get("weather", "CLEAR"))
	if weather not in ["RAIN", "STORM", "SNOW"]:
		return
	var speed := 1.8 if weather == "RAIN" else 3.6 if weather == "STORM" else 0.55
	for index in range(_weather_particles.size()):
		var particle := _weather_particles[index]
		if not particle.visible:
			continue
		particle.position.y -= delta * speed * motion_scale
		particle.position.x += sin(_home_clock * 2.0 + float(index)) * delta * (0.14 if weather == "SNOW" else 0.04)
		if particle.position.y < -1.25:
			particle.position.y = 1.35
