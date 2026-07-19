extends Control

## Resolution-independent action icon used by the production HUD.
## The glyphs are drawn at runtime so they remain sharp on phone, tablet and desktop.

var kind: String = "spark"
var accent: Color = Color("42e8ff")
var glow_strength: float = 1.0

func configure(icon_kind: String, icon_accent: Color) -> void:
	kind = icon_kind
	accent = icon_accent
	queue_redraw()

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(48.0, 42.0)
	resized.connect(queue_redraw)

func _draw() -> void:
	var center := size * 0.5
	var unit := minf(size.x, size.y) / 10.0
	_draw_glow(center, unit)
	match kind:
		"feed":
			_draw_feed(center, unit)
		"play":
			_draw_gamepad(center, unit)
		"learn":
			_draw_book(center, unit)
		"care":
			_draw_heart(center, unit)
		"rest":
			_draw_moon(center, unit)
		"bitling":
			_draw_bitling(center, unit)
		_:
			_draw_spark(center, unit)

func _draw_glow(center: Vector2, unit: float) -> void:
	for ring in range(4, 0, -1):
		var alpha := 0.018 * float(ring) * glow_strength
		draw_circle(center, unit * (2.8 + float(ring) * 0.45), Color(accent, alpha))

func _draw_feed(center: Vector2, unit: float) -> void:
	var fruit_center := center + Vector2(0.0, unit * 0.45)
	draw_circle(fruit_center, unit * 2.15, Color(accent, 0.18))
	draw_circle(fruit_center + Vector2(-unit * 0.75, 0.0), unit * 1.55, accent)
	draw_circle(fruit_center + Vector2(unit * 0.75, 0.0), unit * 1.55, accent)
	draw_line(center + Vector2(0.0, -unit * 1.6), center + Vector2(unit * 0.15, -unit * 2.65), accent, unit * 0.55, true)
	var leaf := PackedVector2Array([
		center + Vector2(unit * 0.15, -unit * 2.3),
		center + Vector2(unit * 2.0, -unit * 2.15),
		center + Vector2(unit * 0.75, -unit * 0.9)
	])
	draw_colored_polygon(leaf, Color(accent, 0.82))

func _draw_gamepad(center: Vector2, unit: float) -> void:
	var body := Rect2(center - Vector2(unit * 3.4, unit * 1.75), Vector2(unit * 6.8, unit * 3.5))
	draw_style_box(_rounded_box(Color(accent, 0.16), accent, unit), body)
	draw_line(center + Vector2(-unit * 1.75, -unit * 0.9), center + Vector2(-unit * 1.75, unit * 0.9), accent, unit * 0.48, true)
	draw_line(center + Vector2(-unit * 2.65, 0.0), center + Vector2(-unit * 0.85, 0.0), accent, unit * 0.48, true)
	draw_circle(center + Vector2(unit * 1.55, -unit * 0.55), unit * 0.48, accent)
	draw_circle(center + Vector2(unit * 2.4, unit * 0.35), unit * 0.48, accent)

func _draw_book(center: Vector2, unit: float) -> void:
	var left := PackedVector2Array([
		center + Vector2(-unit * 3.2, -unit * 2.1),
		center + Vector2(-unit * 0.25, -unit * 1.35),
		center + Vector2(-unit * 0.25, unit * 2.4),
		center + Vector2(-unit * 3.2, unit * 1.65)
	])
	var right := PackedVector2Array([
		center + Vector2(unit * 3.2, -unit * 2.1),
		center + Vector2(unit * 0.25, -unit * 1.35),
		center + Vector2(unit * 0.25, unit * 2.4),
		center + Vector2(unit * 3.2, unit * 1.65)
	])
	draw_colored_polygon(left, Color(accent, 0.22))
	draw_colored_polygon(right, Color(accent, 0.22))
	draw_polyline(left, accent, unit * 0.42, true)
	draw_polyline(right, accent, unit * 0.42, true)
	draw_line(center + Vector2(0.0, -unit * 1.3), center + Vector2(0.0, unit * 2.45), accent, unit * 0.35, true)

func _draw_heart(center: Vector2, unit: float) -> void:
	var points := PackedVector2Array()
	for index in range(64):
		var t := TAU * float(index) / 64.0
		var x := 16.0 * pow(sin(t), 3.0)
		var y := 13.0 * cos(t) - 5.0 * cos(2.0 * t) - 2.0 * cos(3.0 * t) - cos(4.0 * t)
		points.append(center + Vector2(x, -y) * unit * 0.18)
	draw_colored_polygon(points, Color(accent, 0.88))
	draw_polyline(points, Color.WHITE.lerp(accent, 0.55), unit * 0.38, true)

func _draw_moon(center: Vector2, unit: float) -> void:
	draw_circle(center, unit * 2.85, accent)
	draw_circle(center + Vector2(unit * 1.25, -unit * 0.7), unit * 2.75, Color("0b1024"))
	_draw_spark(center + Vector2(unit * 2.7, -unit * 2.25), unit * 0.55)

func _draw_bitling(center: Vector2, unit: float) -> void:
	draw_circle(center + Vector2(0.0, unit * 0.5), unit * 2.45, Color(accent, 0.22))
	draw_circle(center, unit * 2.25, Color("17102f"))
	var left_ear := PackedVector2Array([
		center + Vector2(-unit * 1.5, -unit * 1.2),
		center + Vector2(-unit * 2.8, -unit * 3.5),
		center + Vector2(-unit * 0.45, -unit * 2.2)
	])
	var right_ear := PackedVector2Array([
		center + Vector2(unit * 1.5, -unit * 1.2),
		center + Vector2(unit * 2.8, -unit * 3.5),
		center + Vector2(unit * 0.45, -unit * 2.2)
	])
	draw_colored_polygon(left_ear, Color("17102f"))
	draw_colored_polygon(right_ear, Color("17102f"))
	draw_polyline(left_ear, accent, unit * 0.3, true)
	draw_polyline(right_ear, accent, unit * 0.3, true)
	draw_circle(center + Vector2(-unit * 0.85, -unit * 0.15), unit * 0.65, accent)
	draw_circle(center + Vector2(unit * 0.85, -unit * 0.15), unit * 0.65, accent)
	draw_circle(center + Vector2(-unit * 0.68, -unit * 0.35), unit * 0.18, Color.WHITE)
	draw_circle(center + Vector2(unit * 0.68, -unit * 0.35), unit * 0.18, Color.WHITE)

func _draw_spark(center: Vector2, unit: float) -> void:
	draw_line(center + Vector2(-unit * 3.0, 0.0), center + Vector2(unit * 3.0, 0.0), accent, unit * 0.4, true)
	draw_line(center + Vector2(0.0, -unit * 3.0), center + Vector2(0.0, unit * 3.0), accent, unit * 0.4, true)
	draw_line(center + Vector2(-unit * 1.9, -unit * 1.9), center + Vector2(unit * 1.9, unit * 1.9), Color(accent, 0.68), unit * 0.25, true)
	draw_line(center + Vector2(unit * 1.9, -unit * 1.9), center + Vector2(-unit * 1.9, unit * 1.9), Color(accent, 0.68), unit * 0.25, true)

func _rounded_box(background: Color, border: Color, radius: float) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(maxi(1, int(radius * 0.18)))
	style.set_corner_radius_all(maxi(4, int(radius)))
	return style
