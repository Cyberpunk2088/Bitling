extends Control

signal bitling_pressed

const STAGE_DARK := Color("07101f")
const STAGE_MID := Color("111a3c")
const CYAN := Color("42e8ff")
const BLUE := Color("2b77ff")
const VIOLET := Color("9d4dff")
const MAGENTA := Color("ff3fd4")
const TEXT_LIGHT := Color("edf7ff")
const BODY_DARK := Color("120c25")
const BODY_MID := Color("241146")
const BODY_LIGHT := Color("54267f")

var mood: String = "HAPPY"
var rarity: String = "COMMON"
var _elapsed := 0.0
var _reaction := 0.0
var _pointer := Vector2.ZERO
var _has_pointer := false

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_ALL
	set_process(true)
	resized.connect(queue_redraw)

func set_mood(value: String) -> void:
	mood = value.to_upper()
	queue_redraw()

func set_rarity(value: String) -> void:
	rarity = value.to_upper()
	queue_redraw()

func play_reaction() -> void:
	_reaction = 1.0
	queue_redraw()

func _process(delta: float) -> void:
	_elapsed += delta
	_reaction = move_toward(_reaction, 0.0, delta * 2.2)
	queue_redraw()

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		_pointer = event.position
		_has_pointer = true
		queue_redraw()
	elif event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.pressed and mouse_event.button_index == MOUSE_BUTTON_LEFT:
			_pointer = mouse_event.position
			_has_pointer = true
			play_reaction()
			bitling_pressed.emit()
			accept_event()
	elif event is InputEventScreenTouch:
		var touch_event := event as InputEventScreenTouch
		_pointer = touch_event.position
		_has_pointer = true
		if touch_event.pressed:
			play_reaction()
			bitling_pressed.emit()
			accept_event()

func _draw() -> void:
	if size.x <= 1.0 or size.y <= 1.0:
		return
	_draw_room()
	_draw_platform()
	_draw_bitling()
	_draw_foreground_glow()

func _draw_room() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), STAGE_DARK)
	var stripe_count := 14
	for index in range(stripe_count):
		var ratio := float(index) / float(stripe_count)
		var stripe_color := STAGE_MID.lerp(Color("24114a"), ratio)
		stripe_color.a = 0.48
		var stripe_rect := Rect2(0.0, size.y * ratio, size.x, size.y / float(stripe_count) + 1.0)
		draw_rect(stripe_rect, stripe_color)

	var window_rect := Rect2(size.x * 0.12, size.y * 0.10, size.x * 0.76, size.y * 0.48)
	draw_rect(window_rect.grow(5.0), Color(CYAN, 0.16))
	draw_rect(window_rect, Color("120b35"))

	for index in range(12):
		var ratio := float(index) / 11.0
		var sky_color := Color("4b1777").lerp(Color("071a4c"), ratio)
		draw_rect(
			Rect2(window_rect.position.x, window_rect.position.y + ratio * window_rect.size.y, window_rect.size.x, window_rect.size.y / 11.0 + 1.0),
			sky_color
		)

	var moon_position := window_rect.position + Vector2(window_rect.size.x * 0.78, window_rect.size.y * 0.20)
	draw_circle(moon_position, minf(size.x, size.y) * 0.035, Color(CYAN, 0.18))
	draw_circle(moon_position, minf(size.x, size.y) * 0.018, Color("bff9ff"))

	var building_heights := [0.31, 0.48, 0.24, 0.57, 0.38, 0.68, 0.42, 0.54, 0.29, 0.62]
	var building_width := window_rect.size.x / float(building_heights.size())
	for index in range(building_heights.size()):
		var building_height := window_rect.size.y * float(building_heights[index])
		var building_rect := Rect2(
			window_rect.position.x + building_width * float(index),
			window_rect.end.y - building_height,
			building_width * 0.82,
			building_height
		)
		draw_rect(building_rect, Color("080d24"))
		var light_color := CYAN if index % 2 == 0 else MAGENTA
		for floor_index in range(3):
			var light_y := building_rect.position.y + 12.0 + floor_index * 18.0
			if light_y < building_rect.end.y - 8.0:
				draw_rect(Rect2(building_rect.position.x + 8.0, light_y, 5.0, 3.0), Color(light_color, 0.72))
				draw_rect(Rect2(building_rect.position.x + 19.0, light_y, 5.0, 3.0), Color(light_color, 0.42))

	var horizon_y := size.y * 0.59
	draw_line(Vector2(0.0, horizon_y), Vector2(size.x, horizon_y), Color(CYAN, 0.20), 2.0)
	for index in range(9):
		var floor_y := lerpf(horizon_y, size.y, float(index) / 8.0)
		draw_line(Vector2(0.0, floor_y), Vector2(size.x, floor_y), Color(VIOLET, 0.10), 1.0)
	for index in range(11):
		var x := size.x * float(index) / 10.0
		draw_line(Vector2(size.x * 0.5, horizon_y), Vector2(x, size.y), Color(CYAN, 0.08), 1.0)

	_draw_room_details()

func _draw_room_details() -> void:
	var desk_rect := Rect2(size.x * 0.05, size.y * 0.43, size.x * 0.23, size.y * 0.09)
	draw_rect(desk_rect, Color("11152b"))
	draw_rect(Rect2(desk_rect.position + Vector2(10.0, -34.0), Vector2(desk_rect.size.x * 0.65, 32.0)), Color("091631"))
	draw_rect(Rect2(desk_rect.position + Vector2(16.0, -28.0), Vector2(desk_rect.size.x * 0.53, 21.0)), Color(CYAN, 0.14))
	draw_line(desk_rect.position + Vector2(0.0, desk_rect.size.y), desk_rect.position + Vector2(-8.0, desk_rect.size.y + 42.0), Color("222a45"), 5.0)
	draw_line(desk_rect.end, desk_rect.end + Vector2(8.0, 42.0), Color("222a45"), 5.0)

	var plant_base := Vector2(size.x * 0.90, size.y * 0.53)
	draw_rect(Rect2(plant_base - Vector2(18.0, 0.0), Vector2(36.0, 28.0)), Color("30183e"))
	for index in range(5):
		var angle := -2.55 + float(index) * 0.32
		var end_point := plant_base + Vector2(cos(angle), sin(angle)) * (45.0 + float(index % 2) * 9.0)
		draw_line(plant_base, end_point, Color("43d99d"), 5.0, true)

	for index in range(7):
		var sparkle_x := size.x * (0.16 + float(index) * 0.105)
		var sparkle_y := size.y * (0.18 + 0.05 * sin(_elapsed * 0.7 + float(index)))
		_draw_sparkle(Vector2(sparkle_x, sparkle_y), 2.0 + float(index % 3), Color(CYAN, 0.28))

func _draw_platform() -> void:
	var center := Vector2(size.x * 0.5, size.y * 0.79)
	var radius := minf(size.x, size.y) * 0.22
	for ring_index in range(4):
		var ring_radius := radius * (0.58 + float(ring_index) * 0.16)
		var color := CYAN if ring_index % 2 == 0 else VIOLET
		draw_arc(center, ring_radius, 0.0, TAU, 96, Color(color, 0.30 - float(ring_index) * 0.045), 2.0, true)
	draw_circle(center, radius * 0.62, Color(VIOLET, 0.08))
	draw_arc(center, radius * 0.72, _elapsed * 0.35, _elapsed * 0.35 + PI * 1.30, 72, Color(CYAN, 0.72), 3.0, true)
	draw_arc(center, radius * 0.92, -_elapsed * 0.22, -_elapsed * 0.22 + PI * 0.85, 72, Color(MAGENTA, 0.48), 2.0, true)

func _draw_bitling() -> void:
	var base_scale := minf(size.x, size.y) / 520.0
	var bob := sin(_elapsed * 2.1) * 4.0 * base_scale
	var squash := _reaction * 0.08
	var center := Vector2(size.x * 0.5, size.y * 0.62 + bob + _reaction * 7.0)
	var body_radius := 74.0 * base_scale
	var head_radius := 91.0 * base_scale
	var head_center := center - Vector2(0.0, 52.0 * base_scale)

	_draw_tail(center, base_scale)
	_draw_ears(head_center, head_radius, base_scale)

	var glow_color := CYAN if rarity in ["RARE", "LEGENDARY"] else VIOLET
	draw_circle(head_center, head_radius * 1.19, Color(glow_color, 0.09 + 0.04 * sin(_elapsed * 1.6)))
	draw_circle(center + Vector2(0.0, 42.0 * base_scale), body_radius * 1.14, Color(glow_color, 0.07))

	draw_circle(center + Vector2(0.0, 38.0 * base_scale), body_radius * (1.0 + squash), BODY_DARK)
	draw_circle(center + Vector2(0.0, 32.0 * base_scale), body_radius * 0.83, BODY_MID)
	draw_circle(head_center, head_radius * (1.0 - squash * 0.35), BODY_DARK)
	draw_circle(head_center - Vector2(0.0, 4.0 * base_scale), head_radius * 0.88, BODY_MID)

	var face_glow := Color("421b70")
	draw_circle(head_center + Vector2(0.0, 8.0 * base_scale), head_radius * 0.70, Color(face_glow, 0.38))
	_draw_face(head_center, head_radius, base_scale)
	_draw_limbs(center, body_radius, base_scale)
	_draw_markings(head_center, head_radius, base_scale)

	if rarity in ["UNCOMMON", "RARE", "LEGENDARY"]:
		var sparkle_count := 4 if rarity == "UNCOMMON" else 7 if rarity == "RARE" else 11
		for index in range(sparkle_count):
			var angle := _elapsed * (0.25 + float(index % 3) * 0.06) + TAU * float(index) / float(sparkle_count)
			var distance := head_radius * (1.18 + 0.12 * sin(_elapsed + float(index)))
			var point := head_center + Vector2(cos(angle), sin(angle)) * distance
			_draw_sparkle(point, 3.0 * base_scale, Color(CYAN if index % 2 == 0 else MAGENTA, 0.76))

func _draw_ears(head_center: Vector2, head_radius: float, base_scale: float) -> void:
	var left_points := PackedVector2Array([
		head_center + Vector2(-head_radius * 0.70, -head_radius * 0.55),
		head_center + Vector2(-head_radius * 1.04, -head_radius * 1.23),
		head_center + Vector2(-head_radius * 0.22, -head_radius * 0.88)
	])
	var right_points := PackedVector2Array([
		head_center + Vector2(head_radius * 0.70, -head_radius * 0.55),
		head_center + Vector2(head_radius * 1.04, -head_radius * 1.23),
		head_center + Vector2(head_radius * 0.22, -head_radius * 0.88)
	])
	draw_colored_polygon(left_points, BODY_DARK)
	draw_colored_polygon(right_points, BODY_DARK)
	draw_polyline(left_points, Color(VIOLET, 0.74), 3.0 * base_scale, true)
	draw_polyline(right_points, Color(VIOLET, 0.74), 3.0 * base_scale, true)

func _draw_tail(center: Vector2, base_scale: float) -> void:
	var start := center + Vector2(54.0, 54.0) * base_scale
	var middle := center + Vector2(112.0, 36.0) * base_scale
	var end := center + Vector2(124.0, -4.0) * base_scale
	draw_line(start, middle, BODY_DARK, 22.0 * base_scale, true)
	draw_line(middle, end, BODY_DARK, 17.0 * base_scale, true)
	draw_line(start, middle, Color(VIOLET, 0.40), 4.0 * base_scale, true)

func _draw_limbs(center: Vector2, body_radius: float, base_scale: float) -> void:
	var arm_y := center.y + 25.0 * base_scale
	var arm_swing := sin(_elapsed * 1.7) * 5.0 * base_scale + _reaction * 15.0 * base_scale
	draw_line(Vector2(center.x - body_radius * 0.65, arm_y), Vector2(center.x - body_radius * 1.02, arm_y + 34.0 * base_scale - arm_swing), BODY_DARK, 22.0 * base_scale, true)
	draw_line(Vector2(center.x + body_radius * 0.65, arm_y), Vector2(center.x + body_radius * 1.02, arm_y + 34.0 * base_scale + arm_swing), BODY_DARK, 22.0 * base_scale, true)
	draw_circle(Vector2(center.x - body_radius * 1.03, arm_y + 35.0 * base_scale - arm_swing), 14.0 * base_scale, BODY_MID)
	draw_circle(Vector2(center.x + body_radius * 1.03, arm_y + 35.0 * base_scale + arm_swing), 14.0 * base_scale, BODY_MID)

	var foot_y := center.y + body_radius * 0.92
	draw_circle(Vector2(center.x - body_radius * 0.43, foot_y), 23.0 * base_scale, BODY_DARK)
	draw_circle(Vector2(center.x + body_radius * 0.43, foot_y), 23.0 * base_scale, BODY_DARK)
	draw_arc(Vector2(center.x - body_radius * 0.43, foot_y), 16.0 * base_scale, 0.15, PI - 0.15, 20, Color(CYAN, 0.48), 2.0 * base_scale, true)
	draw_arc(Vector2(center.x + body_radius * 0.43, foot_y), 16.0 * base_scale, 0.15, PI - 0.15, 20, Color(CYAN, 0.48), 2.0 * base_scale, true)

func _draw_face(head_center: Vector2, head_radius: float, base_scale: float) -> void:
	var look_offset := Vector2.ZERO
	if _has_pointer:
		var direction := (_pointer - head_center).normalized()
		look_offset = direction * 6.0 * base_scale
	var eye_y := head_center.y - 1.0 * base_scale
	var eye_dx := head_radius * 0.39
	var blink_cycle := fmod(_elapsed, 4.4)
	var blinking := blink_cycle > 4.22
	var eye_color := Color("d9fbff")
	var iris_color := CYAN if mood not in ["SAD", "DISTRESSED"] else Color("7fb8ff")

	for side in [-1.0, 1.0]:
		var eye_center := Vector2(head_center.x + eye_dx * side, eye_y)
		draw_circle(eye_center, 27.0 * base_scale, Color(CYAN, 0.16))
		if blinking:
			draw_line(eye_center - Vector2(18.0, 0.0) * base_scale, eye_center + Vector2(18.0, 0.0) * base_scale, eye_color, 5.0 * base_scale, true)
		else:
			draw_circle(eye_center, 21.0 * base_scale, eye_color)
			draw_circle(eye_center + look_offset, 12.0 * base_scale, iris_color)
			draw_circle(eye_center + look_offset, 6.0 * base_scale, Color("07111d"))
			draw_circle(eye_center + look_offset - Vector2(4.0, 5.0) * base_scale, 3.5 * base_scale, Color.WHITE)

	var mouth_y := head_center.y + head_radius * 0.43
	match mood:
		"SAD", "DISTRESSED":
			draw_arc(Vector2(head_center.x, mouth_y + 12.0 * base_scale), 15.0 * base_scale, PI + 0.30, TAU - 0.30, 24, TEXT_LIGHT, 3.0 * base_scale, true)
		"TIRED":
			draw_line(Vector2(head_center.x - 12.0 * base_scale, mouth_y), Vector2(head_center.x + 12.0 * base_scale, mouth_y), TEXT_LIGHT, 3.0 * base_scale, true)
		_:
			draw_arc(Vector2(head_center.x, mouth_y - 7.0 * base_scale), 17.0 * base_scale, 0.25, PI - 0.25, 24, TEXT_LIGHT, 3.0 * base_scale, true)

func _draw_markings(head_center: Vector2, head_radius: float, base_scale: float) -> void:
	var pulse := 0.55 + 0.25 * sin(_elapsed * 2.8)
	var mark_color := Color(CYAN, pulse)
	draw_arc(head_center, head_radius * 0.74, PI * 1.08, PI * 1.42, 18, mark_color, 3.0 * base_scale, true)
	draw_arc(head_center, head_radius * 0.74, PI * 1.58, PI * 1.92, 18, Color(MAGENTA, pulse * 0.75), 3.0 * base_scale, true)
	_draw_sparkle(head_center - Vector2(0.0, head_radius * 0.73), 5.0 * base_scale, Color(CYAN, pulse))

func _draw_foreground_glow() -> void:
	var edge_color := Color(VIOLET, 0.11)
	draw_rect(Rect2(0.0, 0.0, size.x, 4.0), edge_color)
	draw_rect(Rect2(0.0, size.y - 4.0, size.x, 4.0), Color(CYAN, 0.08))

func _draw_sparkle(position: Vector2, radius: float, color: Color) -> void:
	draw_line(position - Vector2(radius, 0.0), position + Vector2(radius, 0.0), color, 1.5, true)
	draw_line(position - Vector2(0.0, radius), position + Vector2(0.0, radius), color, 1.5, true)
