extends Control

## Procedural world map for Wave 4. Districts remain data-driven and tappable,
## while the Bitling marker visibly travels through the unlocked path graph.

signal district_selected(district_id: String)
signal route_finished(district_id: String)

const COLOR_VOID := Color("020612")
const COLOR_GRID := Color("13234b")
const COLOR_PATH := Color("315287")
const COLOR_PATH_ACTIVE := Color("42e8ff")
const COLOR_LOCKED := Color("3d4668")
const COLOR_CYAN := Color("42e8ff")
const COLOR_VIOLET := Color("a855f7")
const COLOR_MAGENTA := Color("f044d4")
const COLOR_GREEN := Color("64e6a2")
const COLOR_GOLD := Color("ffc85a")
const COLOR_TEXT := Color("f4f7ff")
const COLOR_MUTED := Color("9ba8c7")

var _snapshot: Dictionary = {}
var _districts: Dictionary = {}
var _route: Array[String] = []
var _route_index := 0
var _route_progress := 0.0
var _avatar_position := Vector2(0.5, 0.52)
var _pulse := 0.0
var _particles: Array[Dictionary] = []

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_ALL
	clip_contents = true
	set_process(true)
	_build_particles()

func set_snapshot(snapshot: Dictionary) -> void:
	_snapshot = snapshot.duplicate(true)
	_districts.clear()
	for district_variant in snapshot.get("districts", []):
		if not district_variant is Dictionary:
			continue
		var district := district_variant as Dictionary
		_districts[str(district.get("id", ""))] = district.duplicate(true)
	var current_id := str(snapshot.get("current_district", "signal_plaza"))
	if _route.is_empty() and _districts.has(current_id):
		_avatar_position = _district_position(current_id)
	queue_redraw()

func play_route(route_variant: Array) -> void:
	_route.clear()
	for entry in route_variant:
		var district_id := str(entry)
		if _districts.has(district_id):
			_route.append(district_id)
	if _route.size() <= 1:
		if not _route.is_empty():
			_avatar_position = _district_position(_route[0])
			route_finished.emit(_route[0])
		_route.clear()
		queue_redraw()
		return
	_route_index = 0
	_route_progress = 0.0
	_avatar_position = _district_position(_route[0])
	queue_redraw()

func get_visual_snapshot() -> Dictionary:
	return {
		"district_count": _districts.size(),
		"route_size": _route.size(),
		"traveling": not _route.is_empty(),
		"avatar_position": [_avatar_position.x, _avatar_position.y]
	}

func _process(delta: float) -> void:
	_pulse = fmod(_pulse + maxf(delta, 0.0), TAU * 20.0)
	_animate_particles(delta)
	if not _route.is_empty() and _route_index < _route.size() - 1:
		_route_progress += maxf(delta, 0.0) * 1.45
		var from_pos := _district_position(_route[_route_index])
		var to_pos := _district_position(_route[_route_index + 1])
		_avatar_position = from_pos.lerp(to_pos, _smoothstep(clampf(_route_progress, 0.0, 1.0)))
		if _route_progress >= 1.0:
			_route_index += 1
			_route_progress = 0.0
			_avatar_position = to_pos
			if _route_index >= _route.size() - 1:
				var destination := _route[_route.size() - 1]
				_route.clear()
				route_finished.emit(destination)
	queue_redraw()

func _gui_input(event: InputEvent) -> void:
	var pointer := Vector2.ZERO
	var pressed := false
	if event is InputEventMouseButton:
		var mouse := event as InputEventMouseButton
		pressed = mouse.pressed and mouse.button_index == MOUSE_BUTTON_LEFT
		pointer = mouse.position
	elif event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		pressed = touch.pressed
		pointer = touch.position
	if not pressed or not _route.is_empty():
		return
	var nearest_id := ""
	var nearest_distance := 58.0
	for district_id_variant in _districts.keys():
		var district_id := str(district_id_variant)
		var district: Dictionary = _districts[district_id]
		if not bool(district.get("unlocked", false)):
			continue
		var screen_position := _to_screen(_district_position(district_id))
		var distance := pointer.distance_to(screen_position)
		if distance < nearest_distance:
			nearest_distance = distance
			nearest_id = district_id
	if not nearest_id.is_empty():
		district_selected.emit(nearest_id)
		accept_event()

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), COLOR_VOID)
	_draw_atmosphere()
	_draw_grid()
	_draw_paths()
	_draw_districts()
	_draw_avatar()

func _draw_atmosphere() -> void:
	var center := size * Vector2(0.52, 0.48)
	for index in range(8, 0, -1):
		var radius := minf(size.x, size.y) * (0.10 + float(index) * 0.07)
		var alpha := 0.012 + float(8 - index) * 0.004
		draw_circle(center, radius, Color(COLOR_VIOLET, alpha))
	for particle in _particles:
		var normalized := particle.get("position", Vector2.ZERO) as Vector2
		var position := Vector2(normalized.x * size.x, normalized.y * size.y)
		var radius := float(particle.get("radius", 1.5))
		var phase := float(particle.get("phase", 0.0))
		var glow := 0.35 + 0.30 * sin(_pulse * 1.3 + phase)
		draw_circle(position, radius * 2.2, Color(COLOR_CYAN, 0.06 * glow))
		draw_circle(position, radius, Color(COLOR_CYAN, 0.40 * glow))

func _draw_grid() -> void:
	var spacing := maxf(minf(size.x, size.y) / 14.0, 34.0)
	var y := 0.0
	while y < size.y:
		draw_line(Vector2(0, y), Vector2(size.x, y), Color(COLOR_GRID, 0.30), 1.0)
		y += spacing
	var x := 0.0
	while x < size.x:
		draw_line(Vector2(x, 0), Vector2(x, size.y), Color(COLOR_GRID, 0.24), 1.0)
		x += spacing

func _draw_paths() -> void:
	var drawn: Dictionary = {}
	for district_id_variant in _districts.keys():
		var district_id := str(district_id_variant)
		var district: Dictionary = _districts[district_id]
		var start := _to_screen(_district_position(district_id))
		for neighbor_variant in district.get("neighbors", []):
			var neighbor := str(neighbor_variant)
			if not _districts.has(neighbor):
				continue
			var edge_key := "%s:%s" % [min(district_id, neighbor), max(district_id, neighbor)]
			if drawn.has(edge_key):
				continue
			drawn[edge_key] = true
			var end := _to_screen(_district_position(neighbor))
			var unlocked := bool(district.get("unlocked", false)) and bool((_districts[neighbor] as Dictionary).get("unlocked", false))
			var color := Color(COLOR_PATH, 0.72) if unlocked else Color(COLOR_LOCKED, 0.30)
			draw_line(start, end, color, 7.0, true)
			draw_line(start, end, Color(COLOR_PATH_ACTIVE, 0.12) if unlocked else Color.TRANSPARENT, 2.0, true)

func _draw_districts() -> void:
	var font := ThemeDB.fallback_font
	for district_id_variant in _districts.keys():
		var district_id := str(district_id_variant)
		var district: Dictionary = _districts[district_id]
		var position := _to_screen(_district_position(district_id))
		var unlocked := bool(district.get("unlocked", false))
		var current := district_id == str(_snapshot.get("current_district", ""))
		var visits := int(district.get("visits", 0))
		var mastery := float(district.get("mastery", 0.0))
		var accent := _district_color(district_id)
		if not unlocked:
			accent = COLOR_LOCKED
		var pulse_radius := 36.0 + 5.0 * sin(_pulse * 2.1 + float(visits))
		if current:
			draw_circle(position, pulse_radius + 12.0, Color(accent, 0.10))
			draw_arc(position, pulse_radius + 8.0, 0.0, TAU, 48, Color(accent, 0.88), 3.0, true)
		draw_circle(position, 31.0, Color(COLOR_VOID, 0.96))
		draw_circle(position, 27.0, Color(accent, 0.22 if unlocked else 0.10))
		draw_arc(position, 30.0, 0.0, TAU, 40, Color(accent, 0.85), 2.0, true)
		if unlocked:
			var mastery_angle := TAU * clampf(mastery / 100.0, 0.0, 1.0)
			draw_arc(position, 35.0, -PI / 2.0, -PI / 2.0 + mastery_angle, 32, Color(COLOR_GREEN, 0.82), 3.0, true)
		else:
			draw_string(font, position + Vector2(-7, 7), "×", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, COLOR_MUTED)
		var label := str(district.get("label", district_id.capitalize()))
		var width := 150.0
		draw_string(font, position + Vector2(-width * 0.5, 52), label, HORIZONTAL_ALIGNMENT_CENTER, width, 15, COLOR_TEXT if unlocked else COLOR_MUTED)
		var citizen_count := 0
		for citizen in _snapshot.get("visible_citizens", []):
			if citizen is Dictionary and str((citizen as Dictionary).get("district", "")) == district_id:
				citizen_count += 1
		for index in range(mini(citizen_count, 5)):
			var angle := TAU * float(index) / maxf(float(citizen_count), 1.0) + _pulse * 0.18
			var orb := position + Vector2(cos(angle), sin(angle)) * 43.0
			draw_circle(orb, 4.5, Color(COLOR_GOLD, 0.90))

func _draw_avatar() -> void:
	var position := _to_screen(_avatar_position)
	var bob := sin(_pulse * 4.0) * 3.0
	position.y += bob
	draw_circle(position, 19.0, Color(COLOR_CYAN, 0.14))
	draw_circle(position, 12.0, Color("07111f"))
	draw_circle(position + Vector2(-4.0, -1.5), 3.2, COLOR_CYAN)
	draw_circle(position + Vector2(4.0, -1.5), 3.2, COLOR_CYAN)
	draw_arc(position + Vector2(0.0, 3.0), 5.0, 0.20, PI - 0.20, 16, COLOR_MAGENTA, 1.8, true)
	var ear_left := PackedVector2Array([position + Vector2(-9, -8), position + Vector2(-6, -18), position + Vector2(-1, -9)])
	var ear_right := PackedVector2Array([position + Vector2(9, -8), position + Vector2(6, -18), position + Vector2(1, -9)])
	draw_colored_polygon(ear_left, Color("07111f"))
	draw_colored_polygon(ear_right, Color("07111f"))

func _district_position(district_id: String) -> Vector2:
	if not _districts.has(district_id):
		return Vector2(0.5, 0.5)
	var position_variant: Variant = (_districts[district_id] as Dictionary).get("position", [0.5, 0.5])
	if position_variant is Array and (position_variant as Array).size() >= 2:
		return Vector2(float((position_variant as Array)[0]), float((position_variant as Array)[1]))
	return Vector2(0.5, 0.5)

func _to_screen(normalized: Vector2) -> Vector2:
	var inset := Vector2(72.0, 64.0)
	var drawable := Vector2(maxf(size.x - inset.x * 2.0, 1.0), maxf(size.y - inset.y * 2.0, 1.0))
	return inset + normalized * drawable

func _district_color(district_id: String) -> Color:
	match district_id:
		"academy_quarter":
			return COLOR_CYAN
		"garden_terraces":
			return COLOR_GREEN
		"workshop_docks":
			return COLOR_GOLD
		"echo_archive":
			return COLOR_VIOLET
		"expedition_gate":
			return COLOR_MAGENTA
		_:
			return Color("6fa8ff")

func _build_particles() -> void:
	_particles.clear()
	for index in range(44):
		var x := fmod(0.137 * float(index * 7 + 3), 1.0)
		var y := fmod(0.193 * float(index * 5 + 11), 1.0)
		_particles.append({"position": Vector2(x, y), "radius": 1.0 + float(index % 3), "speed": 0.004 + float(index % 5) * 0.0015, "phase": float(index) * 0.61})

func _animate_particles(delta: float) -> void:
	for particle in _particles:
		var position := particle.get("position", Vector2.ZERO) as Vector2
		position.y -= float(particle.get("speed", 0.005)) * delta
		position.x += sin(_pulse * 0.35 + float(particle.get("phase", 0.0))) * delta * 0.0012
		if position.y < -0.02:
			position.y = 1.02
		particle["position"] = position

func _smoothstep(value: float) -> float:
	return value * value * (3.0 - 2.0 * value)
