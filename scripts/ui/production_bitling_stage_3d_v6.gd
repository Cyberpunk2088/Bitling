extends "res://scripts/ui/production_bitling_stage_3d_v5.gd"

## Wave 1 visual-production pass.
## Adds unmistakable phase silhouettes and an authored-in-engine rooftop-garden
## layer while preserving the optional GLB/PBR replacement path.

const PHASE_ACCENTS := {
	"EGG": Color("7bdfff"),
	"BABY": Color("64e6a2"),
	"CHILD": Color("42e8ff"),
	"TEEN": Color("a855f7"),
	"ADULT": Color("f044d4"),
	"SENIOR": Color("ffc85a"),
	"LEGENDARY": Color("fff1a8")
}

var _phase_roots: Dictionary = {}
var _phase_orbiters: Array[Node3D] = []
var _rooftop_root: Node3D
var _rooftop_crystals: Array[Node3D] = []
var _rooftop_petals: Array[Node3D] = []
var _story_beat_id := ""
var _visual_pulse := 0.0

func _ready() -> void:
	super._ready()
	_cache_refined_atmosphere_nodes()
	_build_phase_signatures()
	_build_prismatic_rooftop_layer()
	_apply_phase_signature()
	_sync_story_beat_from_director()

func set_development_phase(phase_name: String, level: int = 1) -> void:
	super.set_development_phase(phase_name, level)
	_apply_phase_signature()
	_visual_pulse = 1.0

func set_story_beat(beat_id: String) -> void:
	_story_beat_id = beat_id.strip_edges().to_lower()
	var rooftop_active := _story_beat_id in ["prismatic_rooftops", "promise_of_growth"]
	if _rooftop_root != null:
		_rooftop_root.visible = rooftop_active
	if rooftop_active:
		set_atmosphere("EVENING", "EXPEDITION")
		_action_color = Color("b783ff")
		_action_light_strength = 0.85
		_camera_impulse = 0.42

func get_wave1_visual_snapshot() -> Dictionary:
	var visible_signature := ""
	for key_variant in _phase_roots.keys():
		var root_node := _phase_roots[key_variant] as Node3D
		if root_node != null and root_node.visible:
			visible_signature = str(key_variant)
			break
	return {
		"phase": _development_phase,
		"visible_signature": visible_signature,
		"signature_count": _phase_roots.size(),
		"story_beat": _story_beat_id,
		"rooftop_visible": _rooftop_root != null and _rooftop_root.visible,
		"rooftop_crystals": _rooftop_crystals.size(),
		"rooftop_petals": _rooftop_petals.size()
	}

func _process(delta: float) -> void:
	super._process(delta)
	_visual_pulse = move_toward(_visual_pulse, 0.0, delta * 1.6)
	_animate_phase_signatures(delta)
	_animate_rooftop(delta)

func _cache_refined_atmosphere_nodes() -> void:
	if _world == null:
		return
	if _world_environment == null:
		_world_environment = _world.get_node_or_null("MetafinalEnvironment") as WorldEnvironment
	if _cyan_rim == null:
		_cyan_rim = _world.get_node_or_null("CyanEdge") as OmniLight3D
	if _magenta_rim == null:
		_magenta_rim = _world.get_node_or_null("MagentaEdge") as OmniLight3D
	if _face_fill == null:
		_face_fill = _world.get_node_or_null("EyeSoftbox") as OmniLight3D

func _build_phase_signatures() -> void:
	if _bitling == null:
		return
	_build_egg_signature()
	_build_baby_signature()
	_build_child_signature()
	_build_teen_signature()
	_build_adult_signature()
	_build_senior_signature()
	_build_legendary_signature()

func _phase_root(phase_name: String, parent: Node3D = null) -> Node3D:
	var root_node := Node3D.new()
	root_node.name = "%sSignature" % phase_name.capitalize()
	(parent if parent != null else _bitling).add_child(root_node)
	_phase_roots[phase_name] = root_node
	return root_node

func _build_egg_signature() -> void:
	var root_node := _phase_root("EGG", _body if _body != null else _bitling)
	var accent := _emissive_material(Color("07152a"), PHASE_ACCENTS["EGG"], 2.4)
	for index in range(3):
		var ring := TorusMesh.new()
		ring.inner_radius = 0.62 + float(index) * 0.13
		ring.outer_radius = 0.66 + float(index) * 0.13
		ring.rings = 32
		ring.ring_segments = 6
		var mesh := MeshInstance3D.new()
		mesh.mesh = ring
		mesh.material_override = accent
		mesh.position = Vector3(0.0, 0.0, 0.50 + float(index) * 0.02)
		mesh.rotation_degrees = Vector3(90.0, float(index) * 24.0, 0.0)
		root_node.add_child(mesh)

func _build_baby_signature() -> void:
	var root_node := _phase_root("BABY", _head if _head != null else _bitling)
	var accent := _emissive_material(Color("06241f"), PHASE_ACCENTS["BABY"], 2.7)
	var sprout := _mesh(_capsule(0.075, 0.42, 12, 6), accent, Vector3(0.0, 1.20, 0.05), root_node)
	sprout.rotation_degrees.z = -8.0
	for side in [-1.0, 1.0]:
		var bulb := _mesh(_sphere(0.115, 16, 10), accent, Vector3(0.15 * side, 1.39, 0.03), root_node)
		bulb.scale = Vector3(1.0, 0.78, 1.0)

func _build_child_signature() -> void:
	var root_node := _phase_root("CHILD", _head if _head != null else _bitling)
	var accent := _emissive_material(Color("06152a"), PHASE_ACCENTS["CHILD"], 2.8)
	for side in [-1.0, 1.0]:
		for index in range(2):
			var mark := _mesh(_capsule(0.035, 0.34, 10, 5), accent, Vector3(0.48 * side, -0.24 + float(index) * 0.18, 0.92), root_node)
			mark.rotation_degrees.z = 58.0 * side
	var crest := _mesh(_sphere(0.12, 18, 10), accent, Vector3(0.0, 0.82, 0.76), root_node)
	crest.scale = Vector3(1.4, 0.55, 0.35)

func _build_teen_signature() -> void:
	var root_node := _phase_root("TEEN", _head if _head != null else _bitling)
	var accent := _emissive_material(Color("16072a"), PHASE_ACCENTS["TEEN"], 2.9)
	for side in [-1.0, 1.0]:
		var horn := _mesh(_cone(0.02, 0.16, 0.72, 14), accent, Vector3(0.52 * side, 0.90, 0.08), root_node)
		horn.rotation_degrees = Vector3(0.0, 0.0, -28.0 * side)
		var cheek_core := _mesh(_sphere(0.09, 16, 8), accent, Vector3(0.48 * side, -0.16, 0.96), root_node)
		cheek_core.scale = Vector3(1.3, 0.72, 0.32)

func _build_adult_signature() -> void:
	var root_node := _phase_root("ADULT", _body if _body != null else _bitling)
	var accent := _emissive_material(Color("2a0826"), PHASE_ACCENTS["ADULT"], 3.0)
	var core := _mesh(_sphere(0.19, 20, 12), accent, Vector3(0.0, 0.48, 0.86), root_node)
	core.scale = Vector3(1.25, 1.0, 0.40)
	for side in [-1.0, 1.0]:
		var shoulder := _mesh(_cone(0.01, 0.13, 0.55, 14), accent, Vector3(0.82 * side, 0.42, 0.18), root_node)
		shoulder.rotation_degrees.z = -62.0 * side

func _build_senior_signature() -> void:
	var root_node := _phase_root("SENIOR", _head if _head != null else _bitling)
	var accent := _emissive_material(Color("2a2107"), PHASE_ACCENTS["SENIOR"], 3.0)
	for index in range(3):
		var orbiter_root := Node3D.new()
		orbiter_root.position = Vector3(0.0, 0.65, 0.0)
		root_node.add_child(orbiter_root)
		var orb := _mesh(_sphere(0.075 + float(index) * 0.012, 14, 8), accent, Vector3(0.72 + float(index) * 0.14, 0.0, 0.0), orbiter_root)
		orb.name = "WisdomOrb%02d" % index
		_phase_orbiters.append(orbiter_root)

func _build_legendary_signature() -> void:
	var root_node := _phase_root("LEGENDARY", _head if _head != null else _bitling)
	var accent := _emissive_material(Color("2a260d"), PHASE_ACCENTS["LEGENDARY"], 3.8)
	for index in range(3):
		var ring := TorusMesh.new()
		ring.inner_radius = 0.72 + float(index) * 0.13
		ring.outer_radius = 0.76 + float(index) * 0.13
		ring.rings = 40
		ring.ring_segments = 7
		var mesh := MeshInstance3D.new()
		mesh.mesh = ring
		mesh.material_override = accent
		mesh.position = Vector3(0.0, 1.20 + float(index) * 0.08, 0.0)
		mesh.rotation_degrees = Vector3(90.0, float(index) * 33.0, 0.0)
		root_node.add_child(mesh)

func _apply_phase_signature() -> void:
	for key_variant in _phase_roots.keys():
		var root_node := _phase_roots[key_variant] as Node3D
		if root_node != null:
			root_node.visible = str(key_variant) == _development_phase
	var accent: Color = PHASE_ACCENTS.get(_development_phase, PHASE_ACCENTS["CHILD"])
	_action_color = accent
	_action_light_strength = maxf(_action_light_strength, 0.32)

func _build_prismatic_rooftop_layer() -> void:
	if _world == null:
		return
	_rooftop_root = Node3D.new()
	_rooftop_root.name = "PrismaticRooftopGardens"
	_rooftop_root.visible = false
	_world.add_child(_rooftop_root)

	var terrace := _material(Color("061022"), 0.72, 0.20)
	var cyan_glass := _emissive_material(Color("041a29"), Color("42e8ff"), 2.3)
	cyan_glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	cyan_glass.albedo_color.a = 0.58
	var violet_glass := _emissive_material(Color("18072b"), Color("a855f7"), 2.6)
	violet_glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	violet_glass.albedo_color.a = 0.52
	var plant_material := _material(Color("0c4838"), 0.05, 0.66)
	var petal_material := _emissive_material(Color("2a0b2a"), Color("f044d4"), 2.5)

	_mesh(_box(Vector3(10.2, 0.16, 6.6)), terrace, Vector3(0.0, -0.39, -0.15), _rooftop_root)
	for side in [-1.0, 1.0]:
		var bridge := _mesh(_box(Vector3(2.8, 0.10, 1.05)), cyan_glass, Vector3(3.72 * side, 0.05, 0.90), _rooftop_root)
		bridge.rotation_degrees.y = -10.0 * side
		for planter_index in range(3):
			var x := 2.75 * side + float(planter_index) * 0.52 * side
			_mesh(_box(Vector3(0.42, 0.34, 0.62)), terrace, Vector3(x, -0.18, -1.25), _rooftop_root)
			for leaf_index in range(4):
				var leaf := _mesh(_capsule(0.055, 0.78, 10, 5), plant_material, Vector3(x, 0.35, -1.25), _rooftop_root)
				leaf.rotation_degrees = Vector3(-36.0 + float(leaf_index) * 17.0, float(leaf_index) * 63.0, 0.0)

	for index in range(7):
		var angle := TAU * float(index) / 7.0
		var radius := 2.35 + 0.22 * float(index % 2)
		var crystal_root := Node3D.new()
		crystal_root.position = Vector3(cos(angle) * radius, 0.08, sin(angle) * radius * 0.52 - 0.20)
		_rooftop_root.add_child(crystal_root)
		var crystal := _mesh(_cone(0.03, 0.22 + 0.04 * float(index % 3), 0.90 + 0.18 * float(index % 2), 8), violet_glass if index % 2 == 0 else cyan_glass, Vector3.ZERO, crystal_root)
		crystal.rotation_degrees.z = -8.0 + float(index % 3) * 7.0
		_rooftop_crystals.append(crystal_root)

	for index in range(18):
		var petal := _mesh(_sphere(0.035 + 0.010 * float(index % 3), 10, 6), petal_material, Vector3(-3.8 + float(index % 9) * 0.92, 0.55 + float(index % 5) * 0.52, -1.75 + float(index % 4) * 0.72), _rooftop_root)
		petal.scale = Vector3(1.4, 0.42, 0.72)
		_rooftop_petals.append(petal)

	for index in range(4):
		var arch := TorusMesh.new()
		arch.inner_radius = 2.7 - float(index) * 0.22
		arch.outer_radius = 2.75 - float(index) * 0.22
		arch.rings = 48
		arch.ring_segments = 6
		var arch_mesh := MeshInstance3D.new()
		arch_mesh.mesh = arch
		arch_mesh.material_override = cyan_glass if index % 2 == 0 else violet_glass
		arch_mesh.position = Vector3(0.0, 1.75, -2.20 - float(index) * 0.04)
		arch_mesh.scale = Vector3(1.0, 0.62, 1.0)
		arch_mesh.rotation_degrees.x = 90.0
		_rooftop_root.add_child(arch_mesh)

func _animate_phase_signatures(delta: float) -> void:
	for index in range(_phase_orbiters.size()):
		var orbiter := _phase_orbiters[index]
		if orbiter.visible:
			orbiter.rotation.y += delta * (0.52 + float(index) * 0.18)
	var active_root := _phase_roots.get(_development_phase) as Node3D
	if active_root != null:
		var pulse := 1.0 + 0.035 * _visual_pulse * sin(_elapsed * 12.0)
		active_root.scale = Vector3.ONE * pulse

func _animate_rooftop(delta: float) -> void:
	if _rooftop_root == null or not _rooftop_root.visible:
		return
	for index in range(_rooftop_crystals.size()):
		var crystal_root := _rooftop_crystals[index]
		crystal_root.rotation.y += delta * (0.18 + 0.035 * float(index % 3))
		crystal_root.position.y = 0.08 + sin(_elapsed * 0.80 + float(index)) * 0.055
	for index in range(_rooftop_petals.size()):
		var petal := _rooftop_petals[index]
		petal.position.y += delta * (0.035 + 0.008 * float(index % 4))
		petal.position.x += sin(_elapsed * 0.55 + float(index)) * delta * 0.025
		petal.rotation.z += delta * (0.25 + 0.06 * float(index % 3))
		if petal.position.y > 3.5:
			petal.position.y = 0.45

func _sync_story_beat_from_director() -> void:
	var director := get_node_or_null("/root/LegendarySlice")
	if director == null or not director.has_method("get_current_beat"):
		return
	var beat: Dictionary = director.get_current_beat()
	set_story_beat(str(beat.get("id", "")))
