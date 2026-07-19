extends Control

const TRACK := Color("1a2442")
const TEXT := Color("f4f8ff")
const MUTED := Color("9ba8c7")

var value: float = 0.0
var display_value: float = 0.0
var accent: Color = Color("ff3ed1")
var caption: String = "VERTRAUEN"

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(96.0, 96.0)
	set_process(true)
	resized.connect(queue_redraw)

func set_value(new_value: float) -> void:
	value = clampf(new_value, 0.0, 100.0)

func configure(new_caption: String, new_accent: Color) -> void:
	caption = new_caption
	accent = new_accent
	queue_redraw()

func _process(delta: float) -> void:
	var previous := display_value
	display_value = lerpf(display_value, value, clampf(delta * 6.0, 0.0, 1.0))
	if not is_equal_approx(previous, display_value):
		queue_redraw()

func _draw() -> void:
	var center := size * 0.5
	var radius := minf(size.x, size.y) * 0.34
	var start_angle := -PI * 0.5
	var end_angle := start_angle + TAU * display_value / 100.0
	for glow_index in range(4, 0, -1):
		draw_arc(center, radius, start_angle, end_angle, 64, Color(accent, 0.025 * float(glow_index)), 4.0 + float(glow_index) * 2.0, true)
	draw_arc(center, radius, 0.0, TAU, 64, TRACK, 7.0, true)
	if display_value > 0.1:
		draw_arc(center, radius, start_angle, end_angle, 64, accent, 7.0, true)
		var endpoint := center + Vector2(cos(end_angle), sin(end_angle)) * radius
		draw_circle(endpoint, 4.2, Color.WHITE.lerp(accent, 0.45))
	var value_text := "%d%%" % int(round(display_value))
	var font := ThemeDB.fallback_font
	var value_size := font.get_string_size(value_text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 18)
	draw_string(font, center - Vector2(value_size.x * 0.5, -5.0), value_text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 18, TEXT)
	var caption_size := font.get_string_size(caption, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 8)
	draw_string(font, Vector2(center.x - caption_size.x * 0.5, center.y + radius + 18.0), caption, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 8, MUTED)
