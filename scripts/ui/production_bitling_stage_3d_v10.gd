extends "res://scripts/ui/production_bitling_stage_3d_v9.gd"

## Wave 3 living-home layer: room objects, weather, lighting and routine animation.

var _home_root: Node3D
var _window_panel: MeshInstance3D
var _lamp_orb: OmniLight3D
var _plant_root: Node3D
var _memory_orbs: Array[Node3D] = []
var _dust_motes: Array[Node3D] = []
var _home_snapshot: Dictionary = {}
var _home_clock := 0.0

func _ready() -> void:
	super._ready()
	_build_living_home_layer()
	_connect_living_home()
	_sync_living_home()

func _process(delta: float) -> void:
	super._process(delta)
	_home_clock += maxf(delta, 0.0)
	_animate_living_home(delta)

func apply_home_snapshot(snapshot: Dictionary) -> void:
	_home_snapshot = snapshot.duplicate(true)
	_apply_home_palette()
	_apply_home_objects()

func get_living_home_snapshot() -> Dictionary:
	return {
		"home": _home_snapshot.duplicate(true),
		"window_present": _window_panel != null,
		"lamp_present": _lamp_orb != null,
		"plant_present": _plant_root != null,
		"memory_orbs": _memory_orbs.size(),
		"dust_motes": _dust_motes.size(),
		"art_direction_pass": "wave3_v10"
	}

func _build_living_home_layer() -> void:
	if _world == null:
		return
	_home_root = Node3D.new()
	_home_root.name = "LivingHomeLayer"
	_world.add_child(_home_root)

	var window_material := _emissive_material(Color("071631"), Color("26d9ff"), 1.8)
	_window_panel = _mesh(_box(Vector3(5.2, 3.2, 0.08)), window_material, Vector3(0.0, 2.1, -3.1), _home_root)
	_window_panel.name = "LivingWindow"
	for index in range(6):
		var tower := _mesh(_box(Vector3(0.45 + float(index % 2) * 0.18, 1.2 + float(index % 3) * 0.45, 0.16)), _emissive_material(Color("081226"), Color("7f4dff"), 1.5), Vector3(-2.1 + float(index) * 0.82, 0.55 + float(index % 3) * 0.18, -2.92), _home_root)
		tower.name = "WindowTower%02d" % index

	var lamp_mesh := _mesh(_sphere(0.24, 18, 12), _emissive_material(Color("17102f"), Color("a855f7"), 4.0), Vector3(-2.45, 2.35, -0.55), _home_root)
	lamp_mesh.name = "PrismLamp"
	_lamp_orb = OmniLight3D.new()
	_lamp_orb.name = "PrismLampLight"
	_lamp_orb.position = lamp_mesh.position
	_lamp_orb.omni_range = 6.0
	_lamp_orb.light_energy = 2.2
	_home_root.add_child(_lamp_orb)

	_plant_root = Node3D.new()
	_plant_root.name = "SignalPlant"
	_plant_root.position = Vector3(2.2, 0.1, -0.65)
	_home_root.add_child(_plant_root)
	_mesh(_cylinder(0.42, 0.34, 0.58, 18), _material(Color("28143b"), 0.35, 0.62), Vector3.ZERO, _plant_root)
	for index in range(7):
		var angle := TAU * float(index) / 7.0
		var leaf := _mesh(_capsule(0.08, 0.58, 12, 6), _emissive_material(Color("06221c"), Color("55f0a8"), 1.6), Vector3(cos(angle) * 0.22, 0.48 + float(index % 2) * 0.12, sin(angle) * 0.16), _plant_root)
		leaf.rotation_degrees.z = rad_to_deg(angle) + 18.0

	for index in range(6):
		var orb := _mesh(_sphere(0.08, 12, 8), _emissive_material(Color("140b2e"), Color("ff5ecb"), 2.4), Vector3(-1.65 + float(index) * 0.34, 1.05 + float(index % 2) * 0.20, -1.85), _home_root)
		orb.visible = index == 0
		_memory_orbs.append(orb)
	for index in range(18):
		var mote := _mesh(_sphere(0.018 + float(index % 3) * 0.006, 8, 5), _emissive_material(Color("071426"), Color("42e8ff"), 1.3), Vector3(-2.6 + float(index % 6) * 1.0, 0.45 + float(index / 6) * 0.72, -1.2 + sin(float(index)) * 0.6), _home_root)
		_dust_motes.append(mote)

func _connect_living_home() -> void:
	var service := get_node_or_null("/root/LivingHome")
	if service == null or not service.has_signal("home_changed"):
		return
	var callback := Callable(self, "apply_home_snapshot")
	if not service.is_connected("home_changed", callback):
		service.connect("home_changed", callback)

func _sync_living_home() -> void:
	var service := get_node_or_null("/root/LivingHome")
	if service != null and service.has_method("get_snapshot"):
		apply_home_snapshot(service.call("get_snapshot") as Dictionary)

func _apply_home_palette() -> void:
	if _lamp_orb == null:
		return
	var mode := str(_home_snapshot.get("light_mode", "CYAN"))
	var color := {"CYAN": Color("42e8ff"), "VIOLET": Color("a855f7"), "SUNSET": Color("ff8b5c"), "MOON": Color("8da8ff")}.get(mode, Color("42e8ff"))
	_lamp_orb.light_color = color
	if _window_panel != null:
		var material := _window_panel.material_override as StandardMaterial3D
		if material != null:
			var weather := str(_home_snapshot.get("weather", "CLEAR"))
			material.emission = {"CLEAR": Color("26d9ff"), "RAIN": Color("4f7cff"), "AURORA": Color("9b5cff"), "STORM": Color("ff4fc8")}.get(weather, Color("26d9ff"))

func _apply_home_objects() -> void:
	if _plant_root != null:
		var health := clampf(float(_home_snapshot.get("plant_health", 70.0)) / 100.0, 0.25, 1.0)
		_plant_root.scale = Vector3(0.88 + health * 0.18, 0.72 + health * 0.36, 0.88 + health * 0.18)
	var visible_memories := mini(int((_home_snapshot.get("displayed_memories", []) as Array).size()) + 1, _memory_orbs.size())
	for index in range(_memory_orbs.size()):
		_memory_orbs[index].visible = index < visible_memories

func _animate_living_home(delta: float) -> void:
	if _plant_root != null:
		_plant_root.rotation.y = sin(_home_clock * 0.42) * 0.08
	for index in range(_memory_orbs.size()):
		var orb := _memory_orbs[index]
		orb.position.y += sin(_home_clock * 1.1 + float(index)) * delta * 0.018
		orb.rotation.y += delta * (0.3 + float(index) * 0.04)
	var cleanliness := clampf(float(_home_snapshot.get("cleanliness", 75.0)) / 100.0, 0.0, 1.0)
	for index in range(_dust_motes.size()):
		var mote := _dust_motes[index]
		mote.visible = index >= int(cleanliness * float(_dust_motes.size()))
		mote.position.y += delta * (0.04 + float(index % 4) * 0.01)
		if mote.position.y > 3.0:
			mote.position.y = 0.35
