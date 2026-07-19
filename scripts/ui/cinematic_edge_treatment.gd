extends Control

## Lightweight vignette and scanline treatment. It intentionally avoids shaders so
## the effect remains deterministic across Xogot, mobile and compatibility renderers.

const CYAN := Color("35e9ff")
const VIOLET := Color("9e4dff")

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)
	queue_redraw()

func _draw() -> void:
	if size.x <= 1.0 or size.y <= 1.0:
		return
	var edge_steps := 10
	for index in range(edge_steps):
		var t := float(index) / float(edge_steps)
		var alpha := 0.025 * (1.0 - t)
		var inset := float(index) * 4.0
		var rect := Rect2(Vector2(inset, inset), size - Vector2(inset * 2.0, inset * 2.0))
		draw_style_box(_outline(Color(CYAN.lerp(VIOLET, t), alpha), 18.0 + inset * 0.15), rect)

	var line_gap := 5.0
	var line_count := int(size.y / line_gap)
	for line_index in range(line_count):
		if line_index % 2 == 0:
			var y := float(line_index) * line_gap
			draw_line(Vector2(0.0, y), Vector2(size.x, y), Color(0.2, 0.45, 0.8, 0.010), 1.0)

	var corner := minf(size.x, size.y) * 0.18
	draw_circle(Vector2.ZERO, corner, Color(VIOLET, 0.018))
	draw_circle(Vector2(size.x, 0.0), corner, Color(CYAN, 0.018))
	draw_circle(Vector2(0.0, size.y), corner, Color(CYAN, 0.014))
	draw_circle(size, corner, Color(VIOLET, 0.018))

func _outline(color: Color, radius: float) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color.TRANSPARENT
	style.border_color = color
	style.set_border_width_all(1)
	style.set_corner_radius_all(maxi(4, int(radius)))
	return style
