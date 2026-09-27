extends Control

## A small textured puppet. The island is pinned; head, ears, tail and breathing
## deform separate regions of the original illustration. No gameplay state is owned here.

const ART_PATH := "res://assets/learning/lumo_companion_island.png"
const BLINK_PATH := "res://assets/learning/lumo_companion_blink.png"
const COLUMNS := 14
const ROWS := 17
const REACTION_DURATION := {"greet": 1.45, "celebrate": 1.80, "think": 1.65}

var _texture: Texture2D
var _mesh := ArrayMesh.new()
var _uvs := PackedVector2Array()
var _indices := PackedInt32Array()
var _vertices := PackedVector2Array()
var _art_rect := Rect2()
var _clock := 0.0
var _frame := 0
var _reaction := ""
var _reaction_clock := 0.0
var _reaction_duration := 0.0
var _reduced_motion := false
var _gaze := Vector2.ZERO
var _pose: Dictionary = {}
var _context := "catalog"
var _domain := "discovery"
var _approach := "observe"
var _round := 0
var _semantic_serial := -1
var _semantic_gesture := "breathing"
var _blink := 0.0
var _blink_material: ShaderMaterial
var _focus_outline: Panel
var _press_position := Vector2.ZERO
var _press_active := false
var _press_dragged := false
var _touch_index := -1

func _ready() -> void:
	name = "LearningCompanionActor"
	mouse_filter = Control.MOUSE_FILTER_PASS
	focus_mode = Control.FOCUS_ALL
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	set_notify_transform(true)
	if ResourceLoader.exists(ART_PATH):
		_texture = load(ART_PATH) as Texture2D
	_build_topology()
	_build_blink_material()
	_focus_outline = Panel.new()
	_focus_outline.name = "CompanionFocusOutline"
	_focus_outline.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_focus_outline.use_parent_material = false
	_focus_outline.add_theme_stylebox_override("panel", get_theme_stylebox("focus", "Button"))
	add_child(_focus_outline)
	_focus_outline.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_focus_outline.offset_left = 4.0
	_focus_outline.offset_top = 4.0
	_focus_outline.offset_right = -4.0
	_focus_outline.offset_bottom = -4.0
	_focus_outline.visible = has_focus()
	resized.connect(_refresh_geometry)
	get_viewport().size_changed.connect(_sync_running)
	visibility_changed.connect(_on_visibility_changed)
	mouse_exited.connect(_reset_gaze)
	for ancestor: Node in _ancestors():
		if ancestor is ScrollContainer:
			(ancestor as ScrollContainer).get_v_scroll_bar().value_changed.connect(_on_scroll)
			(ancestor as ScrollContainer).get_h_scroll_bar().value_changed.connect(_on_scroll)
	var director := get_node_or_null("/root/CharacterPerformance")
	if director != null and director.has_signal("performance_changed"):
		director.connect("performance_changed", _on_performance_changed)
		if director.has_method("get_snapshot"):
			_on_performance_changed(director.call("get_snapshot") as Dictionary)
	_refresh_geometry()
	_sync_running()

func set_context(adventure_id: String, domain: String = "discovery", round_number: int = 0, approach: String = "observe") -> void:
	var changed := _context != adventure_id or _domain != domain or _round != round_number or _approach != approach
	_context = adventure_id
	_domain = domain
	_round = round_number
	_approach = approach
	if changed or adventure_id == "catalog":
		_clear_reaction()
		if adventure_id != "catalog":
			request_reaction("think")
		else:
			_refresh_geometry()

func set_result(success: bool) -> void:
	request_reaction("celebrate" if success else "think")

func set_reduced_motion(enabled: bool) -> void:
	if _reduced_motion == enabled:
		return
	_reduced_motion = enabled
	if enabled:
		_reaction = ""
		_gaze = Vector2.ZERO
	_refresh_geometry()
	_sync_running()

func request_reaction(kind: String) -> void:
	if not REACTION_DURATION.has(kind):
		return
	_reaction = kind if not _reduced_motion else ""
	_reaction_clock = 0.0
	_reaction_duration = float(REACTION_DURATION[kind])
	_refresh_geometry()
	_sync_running()

func _clear_reaction() -> void:
	_reaction = ""
	_reaction_clock = 0.0
	_reaction_duration = 0.0
	_gaze = Vector2.ZERO
	_press_active = false
	_press_dragged = false
	_touch_index = -1

func get_animation_snapshot() -> Dictionary:
	# Read back the resource used by draw_mesh, not a separate diagnostic model.
	var drawn_vertices := PackedVector2Array()
	if _mesh.get_surface_count() > 0:
		drawn_vertices = _mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX] as PackedVector2Array
	return {
		"vertices": drawn_vertices,
		"uvs": _uvs.duplicate(),
		"pose": _pose.duplicate(true),
		"running": is_processing(),
		"frame": _frame,
		"reaction": _reaction,
		"reaction_elapsed": _reaction_clock,
		"context": _context,
		"round": _round,
		"gaze": _gaze,
		"art_rect": _art_rect,
		"art_loaded": _texture != null,
		"reduced_motion": _reduced_motion,
		"semantic_gesture": _semantic_gesture,
		"blink": float(_blink_material.get_shader_parameter("blink")) if _blink_material != null else 0.0,
		"blink_available": _blink_material != null,
		"topology_valid": _topology_valid(drawn_vertices)
	}

func _process(delta: float) -> void:
	if _reduced_motion or not _onscreen():
		_sync_running()
		return
	var elapsed := maxf(delta, 0.0)
	_clock = fmod(_clock + elapsed, 120.0)
	if not _reaction.is_empty():
		_reaction_clock += elapsed
		if _reaction_clock >= _reaction_duration:
			_reaction = ""
	_frame += 1
	_refresh_geometry()

func _draw() -> void:
	if _texture != null and _mesh.get_surface_count() > 0:
		draw_mesh(_mesh, _texture)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		if _press_active and (event as InputEventMouseMotion).position.distance_to(_press_position) > 12.0:
			_press_dragged = true
		var center := _art_rect.position + _art_rect.size * Vector2(0.55, 0.32)
		var offset := ((event as InputEventMouseMotion).position - center) / Vector2(maxf(_art_rect.size.x * 0.45, 1.0), maxf(_art_rect.size.y * 0.35, 1.0))
		_gaze = offset.clamp(Vector2(-1, -1), Vector2.ONE)
		if not _reduced_motion:
			_refresh_geometry()
	elif event is InputEventMouseButton:
		var click := event as InputEventMouseButton
		if click.button_index == MOUSE_BUTTON_LEFT:
			if click.pressed:
				_begin_press(click.position)
			elif _finish_press(click.position):
				accept_event()
	elif event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed:
			_touch_index = touch.index
			_begin_press(touch.position)
		elif touch.index == _touch_index:
			_touch_index = -1
			if _finish_press(touch.position):
				accept_event()
	elif event is InputEventScreenDrag:
		var drag := event as InputEventScreenDrag
		if drag.index == _touch_index and drag.position.distance_to(_press_position) > 12.0:
			_press_dragged = true
	elif event.is_action_pressed("ui_accept") and has_focus():
		request_reaction("greet")
		accept_event()

func _begin_press(point: Vector2) -> void:
	_press_position = point
	_press_active = _over_companion(point)
	_press_dragged = false

func _finish_press(point: Vector2) -> bool:
	var tapped := _press_active and not _press_dragged and point.distance_to(_press_position) <= 12.0 and _over_companion(point)
	_press_active = false
	if tapped:
		request_reaction("greet")
	return tapped

func _over_companion(point: Vector2) -> bool:
	if not _art_rect.has_point(point) or _art_rect.size.x <= 0.0 or _art_rect.size.y <= 0.0:
		return false
	var uv := (point - _art_rect.position) / _art_rect.size
	return uv.y < 0.65 and uv.x > 0.08 and uv.x < 0.94

func _build_topology() -> void:
	for row: int in range(ROWS + 1):
		for column: int in range(COLUMNS + 1):
			_uvs.append(Vector2(float(column) / COLUMNS, float(row) / ROWS))
	for row: int in range(ROWS):
		for column: int in range(COLUMNS):
			var index := row * (COLUMNS + 1) + column
			_indices.append_array(PackedInt32Array([index, index + 1, index + COLUMNS + 1, index + 1, index + COLUMNS + 2, index + COLUMNS + 1]))

func _refresh_geometry() -> void:
	if _uvs.is_empty():
		return
	var source := _texture.get_size() if _texture != null else Vector2(1156, 1361)
	var available := Vector2(maxf(size.x - 16.0, 1.0), maxf(size.y - 12.0, 1.0))
	var art_size := source * minf(available.x / source.x, available.y / source.y)
	_art_rect = Rect2((size - art_size) * 0.5, art_size)
	_pose = _current_pose()
	_vertices.resize(_uvs.size())
	for index: int in range(_uvs.size()):
		_vertices[index] = _art_rect.position + _deform(_uvs[index]) * _art_rect.size
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = _vertices
	arrays[Mesh.ARRAY_TEX_UV] = _uvs
	arrays[Mesh.ARRAY_INDEX] = _indices
	_mesh.clear_surfaces()
	_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	_blink = 0.0
	if not _reduced_motion:
		var phase := fmod(_clock, 4.2)
		if phase > 3.85 and phase < 4.05:
			_blink = sin((phase - 3.85) / 0.20 * PI)
	if _blink_material != null:
		_blink_material.set_shader_parameter("blink", _blink)
	queue_redraw()
	_sync_running()

func _current_pose() -> Dictionary:
	if _reduced_motion:
		return {"head": 0.0, "ear_left": 0.0, "ear_right": 0.0, "tail": 0.0, "breath": 0.0, "paw": 0.0, "nod": 0.0}
	var envelope := sin(clampf(_reaction_clock / maxf(_reaction_duration, 0.01), 0.0, 1.0) * PI) if not _reaction.is_empty() else 0.0
	var pose := {
		"head": sin(_clock * 1.4) * 0.024 + _gaze.x * 0.025,
		"ear_left": sin(_clock * 2.7) * 0.070,
		"ear_right": sin(_clock * 2.2 + 0.8) * -0.060,
		"tail": sin(_clock * 2.4) * 0.085,
		"breath": sin(_clock * 2.0) * 0.014,
		"paw": 0.0,
		"nod": _gaze.y * 0.003
	}
	match _reaction:
		"greet":
			pose["ear_left"] += envelope * sin(_reaction_clock * 12.0) * 0.14
			pose["head"] += envelope * 0.055
			pose["paw"] = envelope * (0.5 + 0.5 * sin(_reaction_clock * 10.0)) * 0.020
			pose["tail"] += envelope * sin(_reaction_clock * 9.0) * 0.11
		"celebrate":
			pose["head"] += envelope * sin(_reaction_clock * 8.0) * 0.055
			pose["nod"] -= envelope * absf(sin(_reaction_clock * 7.0)) * 0.013
			pose["ear_left"] += envelope * 0.09
			pose["ear_right"] -= envelope * 0.09
			pose["tail"] += envelope * sin(_reaction_clock * 10.0) * 0.13
		"think":
			pose["head"] += envelope * 0.085
			pose["ear_left"] += envelope * 0.08
			pose["ear_right"] += envelope * 0.025
	return pose

func _deform(uv: Vector2) -> Vector2:
	# Everything below the paws, including the floating island, remains exact.
	# Pin the raised flowers and plant too; they share the illustration with the fur.
	if (uv.x < 0.43 and uv.y >= 0.57) or (uv.x > 0.73 and uv.y >= 0.47):
		return uv
	var planted := 1.0 - smoothstep(0.57, 0.64, uv.y)
	if planted <= 0.0:
		return uv
	var head := 1.0 - smoothstep(0.39, 0.51, uv.y)
	var head_pivot := Vector2(0.56, 0.43)
	var displacement := ((uv - head_pivot).rotated(float(_pose["head"])) - (uv - head_pivot)) * head
	displacement.y += float(_pose["nod"]) * head
	var left := _weight(uv, Vector2(0.26, 0.28), Vector2(0.24, 0.15)) * (1.0 - smoothstep(0.36, 0.48, uv.x))
	var right := _weight(uv, Vector2(0.80, 0.20), Vector2(0.20, 0.13)) * smoothstep(0.62, 0.76, uv.x)
	displacement += _rotation_delta(uv, Vector2(0.40, 0.27), float(_pose["ear_left"])) * left
	displacement += _rotation_delta(uv, Vector2(0.69, 0.21), float(_pose["ear_right"])) * right
	var tail := _weight(uv, Vector2(0.22, 0.50), Vector2(0.23, 0.18)) * (1.0 - smoothstep(0.33, 0.46, uv.x))
	displacement += _rotation_delta(uv, Vector2(0.38, 0.57), float(_pose["tail"])) * tail
	var chest := _weight(uv, Vector2(0.55, 0.49), Vector2(0.24, 0.16))
	displacement += (uv - Vector2(0.55, 0.60)) * float(_pose["breath"]) * chest
	var paw := _weight(uv, Vector2(0.54, 0.59), Vector2(0.09, 0.075))
	displacement += Vector2(float(_pose["paw"]) * 0.35, -float(_pose["paw"])) * paw
	return uv + displacement * planted

func _rotation_delta(point: Vector2, pivot: Vector2, angle: float) -> Vector2:
	return (point - pivot).rotated(angle) - (point - pivot)

func _weight(point: Vector2, center: Vector2, radius: Vector2) -> float:
	return 1.0 - smoothstep(0.0, 1.0, ((point - center) / radius).length())

func _topology_valid(vertices: PackedVector2Array) -> bool:
	if vertices.size() != _uvs.size() or vertices.is_empty():
		return false
	for vertex: Vector2 in vertices:
		if not vertex.is_finite():
			return false
	for index: int in range(0, _indices.size(), 3):
		var a := vertices[_indices[index]]
		var b := vertices[_indices[index + 1]]
		var c := vertices[_indices[index + 2]]
		if (b - a).cross(c - a) <= 0.0:
			return false
	return true

func _onscreen() -> bool:
	if not is_inside_tree() or not is_visible_in_tree():
		return false
	var screen_rect := get_global_transform_with_canvas() * Rect2(Vector2.ZERO, size)
	var visible_rect := screen_rect.intersection(get_viewport().get_visible_rect())
	if not visible_rect.has_area():
		return false
	for ancestor: Node in _ancestors():
		if ancestor is Control and (ancestor as Control).clip_contents:
			var clip_control := ancestor as Control
			var clip_rect := clip_control.get_global_transform_with_canvas() * Rect2(Vector2.ZERO, clip_control.size)
			visible_rect = visible_rect.intersection(clip_rect)
			if not visible_rect.has_area():
				return false
	return true

func _ancestors() -> Array[Node]:
	var result: Array[Node] = []
	var ancestor := get_parent()
	while ancestor != null:
		result.append(ancestor)
		ancestor = ancestor.get_parent()
	return result

func _sync_running() -> void:
	if is_node_ready():
		set_process(not _reduced_motion and _onscreen())

func _on_visibility_changed() -> void:
	# Closing a screen ends its visual episode. Clipping while scrolling only
	# pauses processing and deliberately does not invalidate the current round.
	if not is_visible_in_tree():
		_clear_reaction()
		_context = ""
		_round = -1
		_refresh_geometry()
	_sync_running()

func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSFORM_CHANGED and is_node_ready():
		_sync_running()
	elif what in [NOTIFICATION_FOCUS_ENTER, NOTIFICATION_FOCUS_EXIT]:
		if _focus_outline != null:
			_focus_outline.visible = has_focus()

func _on_scroll(_value: float) -> void:
	_sync_running()

func _reset_gaze() -> void:
	_gaze = Vector2.ZERO
	_press_active = false
	_refresh_geometry()

func _on_performance_changed(snapshot: Dictionary) -> void:
	var serial := int(snapshot.get("serial", -1))
	if serial == _semantic_serial:
		return
	_semantic_serial = serial
	_semantic_gesture = str(snapshot.get("gesture", "breathing"))
	if not is_visible_in_tree() or not _reaction.is_empty():
		return
	match _semantic_gesture:
		"greeting", "paw_wave_left", "paw_wave_right", "head_pat": request_reaction("greet")
		"bounce_spin", "belly_laugh", "transform": request_reaction("celebrate")
		"focus_tilt", "scout": request_reaction("think")

func _build_blink_material() -> void:
	if not ResourceLoader.exists(BLINK_PATH):
		return
	var shader := Shader.new()
	shader.code = """shader_type canvas_item;
uniform sampler2D blink_texture : source_color;
uniform float blink = 0.0;
varying vec4 vertex_color;
void vertex() { vertex_color = COLOR; }
void fragment() {
	vec4 opened = texture(TEXTURE, UV);
	vec4 closed = texture(blink_texture, UV);
	float left_eye = 1.0 - smoothstep(0.6, 1.0, length((UV - vec2(0.484, 0.302)) / vec2(0.100, 0.095)));
	float right_eye = 1.0 - smoothstep(0.6, 1.0, length((UV - vec2(0.676, 0.226)) / vec2(0.085, 0.095)));
	COLOR = vertex_color * mix(opened, closed, clamp(blink * max(left_eye, right_eye), 0.0, 1.0));
}
"""
	_blink_material = ShaderMaterial.new()
	_blink_material.shader = shader
	_blink_material.set_shader_parameter("blink_texture", load(BLINK_PATH))
	material = _blink_material
