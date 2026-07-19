extends Control

## Lightweight procedural presentation layer for the three Wave 1 activities.
## It uses CanvasItem drawing only, remains mobile-safe and carries no gameplay state.

var activity_id := "pattern_focus"
var elapsed := 0.0
var intensity := 0.0
var success_flash := 0.0
var failure_flash := 0.0
var reduced_motion := false

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	set_process(true)

func set_activity(value: String) -> void:
	activity_id = value.strip_edges().to_lower()
	queue_redraw()

func pulse(success: bool, score: float = 1.0) -> void:
	intensity = clampf(score, 0.0, 1.0)
	if success:
		success_flash = 1.0
	else:
		failure_flash = 1.0
	queue_redraw()

func get_visual_snapshot() -> Dictionary:
	return {
		"activity": activity_id,
		"intensity": intensity,
		"success_flash": success_flash,
		"failure_flash": failure_flash,
		"reduced_motion": reduced_motion
	}

func _process(delta: float) -> void:
	elapsed += delta * (0.25 if reduced_motion else 1.0)
	intensity = move_toward(intensity, 0.0, delta * 0.6)
	success_flash = move_toward(success_flash, 0.0, delta * 1.8)
	failure_flash = move_toward(failure_flash, 0.0, delta * 2.2)
	queue_redraw()

func _draw() -> void:
	var rect := get_rect()
	if rect.size.x <= 1.0 or rect.size.y <= 1.0:
		return
	var center := rect.size * 0.5
	var cyan := Color("42e8ff")
	var violet := Color("a855f7")
	var magenta := Color("f044d4")
	var green := Color("64e6a2")
	var red := Color("ff6d8e")

	draw_rect(Rect2(Vector2.ZERO, rect.size), Color("030616"), true)
	for index in range(10):
		var y := rect.size.y * float(index) / 9.0
		var alpha := 0.045 + 0.025 * sin(elapsed * 0.7 + float(index))
		draw_line(Vector2(0.0, y), Vector2(rect.size.x, y), Color(cyan, alpha), 1.0)
	for index in range(8):
		var x := rect.size.x * float(index) / 7.0
		draw_line(Vector2(x, 0.0), Vector2(x, rect.size.y), Color(violet, 0.035), 1.0)

	match activity_id:
		"resonance_rhythm":
			_draw_rhythm(center, rect.size, cyan, magenta)
		"signal_translation":
			_draw_translation(center, rect.size, cyan, violet)
		_:
			_draw_pattern(center, rect.size, cyan, violet)

	if success_flash > 0.0:
		draw_circle(center, minf(rect.size.x, rect.size.y) * (0.34 + 0.18 * (1.0 - success_flash)), Color(green, 0.16 * success_flash), false, 6.0)
	if failure_flash > 0.0:
		draw_rect(Rect2(Vector2.ZERO, rect.size), Color(red, 0.10 * failure_flash), true)

func _draw_rhythm(center: Vector2, size_value: Vector2, cyan: Color, magenta: Color) -> void:
	var radius := minf(size_value.x, size_value.y) * 0.34
	for index in range(5):
		var phase := elapsed * (0.45 + float(index) * 0.08) + float(index)
		var ring_radius := radius * (0.45 + float(index) * 0.15) + sin(phase) * 8.0
		draw_circle(center, ring_radius, Color(cyan if index % 2 == 0 else magenta, 0.10 + float(index) * 0.018), false, 2.0 + float(index % 2))
	for index in range(16):
		var x := size_value.x * float(index) / 15.0
		var amplitude := 18.0 + 36.0 * (0.5 + 0.5 * sin(float(index) * 1.7 + elapsed * 2.0))
		draw_line(Vector2(x, center.y - amplitude), Vector2(x, center.y + amplitude), Color(cyan, 0.10), 2.0)

func _draw_translation(center: Vector2, size_value: Vector2, cyan: Color, violet: Color) -> void:
	var columns := 7
	var rows := 9
	for y_index in range(rows):
		for x_index in range(columns):
			var seed := float(x_index * 19 + y_index * 31)
			var drift := sin(elapsed * 0.7 + seed) * 5.0
			var point := Vector2(
				size_value.x * (0.12 + 0.76 * float(x_index) / float(columns - 1)),
				size_value.y * (0.10 + 0.80 * float(y_index) / float(rows - 1)) + drift
			)
			var color := cyan if int(seed) % 3 == 0 else violet
			draw_circle(point, 2.2 + float((x_index + y_index) % 3), Color(color, 0.10 + 0.04 * sin(elapsed + seed)), true)
	for index in range(4):
		var offset := Vector2(cos(elapsed * 0.35 + float(index) * 1.6), sin(elapsed * 0.35 + float(index) * 1.6)) * (90.0 + 22.0 * float(index))
		draw_line(center - offset, center + offset, Color(cyan if index % 2 == 0 else violet, 0.08), 2.0)

func _draw_pattern(center: Vector2, size_value: Vector2, cyan: Color, violet: Color) -> void:
	var base_radius := minf(size_value.x, size_value.y) * 0.31
	for index in range(8):
		var angle := TAU * float(index) / 8.0 + elapsed * (0.08 if index % 2 == 0 else -0.06)
		var point := center + Vector2(cos(angle), sin(angle)) * base_radius
		var next_angle := TAU * float((index + 1) % 8) / 8.0 + elapsed * (0.08 if (index + 1) % 2 == 0 else -0.06)
		var next_point := center + Vector2(cos(next_angle), sin(next_angle)) * base_radius
		draw_line(point, next_point, Color(cyan, 0.12), 2.0)
		draw_circle(point, 6.0 + 2.0 * sin(elapsed + float(index)), Color(violet if index % 2 else cyan, 0.17), true)
	for radius_index in range(3):
		draw_circle(center, base_radius * (0.32 + float(radius_index) * 0.24), Color(violet, 0.06), false, 2.0)
