extends Control

## Lightweight authored-looking learning stage. It keeps the Bitling emotionally
## present during catalog browsing and every challenge without requiring final art.

const COLOR_VOID := Color("030713")
const COLOR_INK := Color("07111f")
const COLOR_CYAN := Color("42e8ff")
const COLOR_VIOLET := Color("a855f7")
const COLOR_MAGENTA := Color("f044d4")
const COLOR_GREEN := Color("64e6a2")
const COLOR_GOLD := Color("ffc85a")
const COLOR_TEXT := Color("f4f7ff")

var _adventure_id: String = "catalog"
var _domain: String = "discovery"
var _approach: String = "observe"
var _round: int = 0
var _pulse: float = 0.0
var _result_state: int = 0
var _reduced_motion: bool = false

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true
	set_process(true)

func set_catalog_mode() -> void:
	_adventure_id = "catalog"
	_domain = "discovery"
	_approach = "observe"
	_round = 0
	_result_state = 0
	queue_redraw()

func set_context(adventure_id: String, domain: String, round_number: int, approach: String) -> void:
	_adventure_id = adventure_id
	_domain = domain
	_round = maxi(round_number, 1)
	_approach = approach
	_result_state = 0
	queue_redraw()

func set_approach(approach: String) -> void:
	_approach = approach
	_result_state = 0
	queue_redraw()

func set_result(success: bool) -> void:
	_result_state = 1 if success else -1
	queue_redraw()

func set_reduced_motion(enabled: bool) -> void:
	_reduced_motion = enabled

func get_visual_snapshot() -> Dictionary:
	return {
		"adventure_id": _adventure_id,
		"domain": _domain,
		"approach": _approach,
		"round": _round,
		"result_state": _result_state,
		"bitling_visible": true,
		"reduced_motion": _reduced_motion
	}

func _process(delta: float) -> void:
	if not _reduced_motion:
		_pulse = fmod(_pulse + maxf(delta, 0.0), TAU * 20.0)
	queue_redraw()

func _draw() -> void:
	var accent: Color = _domain_color(_domain)
	draw_rect(Rect2(Vector2.ZERO, size), COLOR_VOID)
	_draw_grid(accent)
	_draw_orbits(accent)
	_draw_platform(accent)
	_draw_bitling(accent)
	_draw_symbols(accent)
	_draw_caption(accent)

func _draw_grid(accent: Color) -> void:
	var spacing: float = maxf(minf(size.x, size.y) / 9.0, 30.0)
	var y: float = 0.0
	while y <= size.y:
		draw_line(Vector2(0.0, y), Vector2(size.x, y), Color(accent, 0.045), 1.0)
		y += spacing
	var x: float = 0.0
	while x <= size.x:
		draw_line(Vector2(x, 0.0), Vector2(x, size.y), Color(accent, 0.035), 1.0)
		x += spacing

func _draw_orbits(accent: Color) -> void:
	var center := Vector2(size.x * 0.50, size.y * 0.48)
	var base_radius := minf(size.x, size.y) * 0.27
	for index: int in range(3):
		var radius := base_radius + float(index) * 18.0
		draw_arc(center, radius, -PI * 0.92, PI * 0.32, 52, Color(accent, 0.12 - float(index) * 0.025), 2.0, true)
	var orbit_angle := _pulse * 0.55
	for index: int in range(5):
		var angle := orbit_angle + TAU * float(index) / 5.0
		var position := center + Vector2(cos(angle), sin(angle)) * (base_radius + 11.0)
		draw_circle(position, 4.0, Color(accent, 0.82))
		draw_circle(position, 10.0, Color(accent, 0.08))

func _draw_platform(accent: Color) -> void:
	var center := Vector2(size.x * 0.50, size.y * 0.78)
	var width := minf(size.x * 0.58, 340.0)
	draw_line(center - Vector2(width * 0.5, 0.0), center + Vector2(width * 0.5, 0.0), Color(accent, 0.65), 3.0, true)
	draw_line(center - Vector2(width * 0.38, -8.0), center + Vector2(width * 0.38, -8.0), Color(accent, 0.20), 8.0, true)
	draw_circle(center, width * 0.24, Color(accent, 0.028))

func _draw_bitling(accent: Color) -> void:
	var bob := 0.0 if _reduced_motion else sin(_pulse * 2.4) * 4.0
	var center := Vector2(size.x * 0.50, size.y * 0.52 + bob)
	var scale_factor := clampf(minf(size.x / 420.0, size.y / 330.0), 0.62, 1.28)
	var body_radius := 64.0 * scale_factor
	var head_radius := 58.0 * scale_factor
	var body_center := center + Vector2(0.0, 48.0 * scale_factor)
	var head_center := center - Vector2(0.0, 22.0 * scale_factor)

	draw_circle(body_center, body_radius + 13.0 * scale_factor, Color(accent, 0.08))
	draw_circle(body_center, body_radius, COLOR_INK)
	draw_circle(head_center, head_radius, Color("091626"))

	var ear_height := 70.0 * scale_factor
	var ear_width := 27.0 * scale_factor
	var left_ear := PackedVector2Array([
		head_center + Vector2(-34.0, -35.0) * scale_factor,
		head_center + Vector2(-24.0, -35.0 - ear_height) * scale_factor,
		head_center + Vector2(-7.0, -42.0) * scale_factor
	])
	var right_ear := PackedVector2Array([
		head_center + Vector2(34.0, -35.0) * scale_factor,
		head_center + Vector2(24.0, -35.0 - ear_height) * scale_factor,
		head_center + Vector2(7.0, -42.0) * scale_factor
	])
	draw_colored_polygon(left_ear, COLOR_INK)
	draw_colored_polygon(right_ear, COLOR_INK)
	draw_polyline(PackedVector2Array([left_ear[0], left_ear[1], left_ear[2]]), Color(accent, 0.45), 2.0, true)
	draw_polyline(PackedVector2Array([right_ear[0], right_ear[1], right_ear[2]]), Color(accent, 0.45), 2.0, true)

	var eye_y := head_center.y - 3.0 * scale_factor
	var eye_offset := 19.0 * scale_factor
	var eye_radius := 10.0 * scale_factor
	var blink := 1.0
	if not _reduced_motion and fmod(_pulse, 5.4) > 5.15:
		blink = 0.18
	for direction: float in [-1.0, 1.0]:
		var eye_center := Vector2(head_center.x + direction * eye_offset, eye_y)
		draw_circle(eye_center, eye_radius, Color(accent, 0.98))
		draw_circle(eye_center + Vector2(direction * 1.5, 1.5), eye_radius * 0.45, Color("02101a"))
		if blink < 1.0:
			draw_line(eye_center - Vector2(eye_radius, 0.0), eye_center + Vector2(eye_radius, 0.0), COLOR_INK, eye_radius * 1.6, true)

	var mouth_center := head_center + Vector2(0.0, 22.0) * scale_factor
	if _result_state > 0:
		draw_arc(mouth_center, 12.0 * scale_factor, 0.15, PI - 0.15, 18, COLOR_MAGENTA, 3.0, true)
	elif _result_state < 0:
		draw_arc(mouth_center + Vector2(0.0, 8.0 * scale_factor), 10.0 * scale_factor, PI + 0.25, TAU - 0.25, 18, Color(accent, 0.85), 2.5, true)
	else:
		draw_arc(mouth_center, 9.0 * scale_factor, 0.35, PI - 0.35, 16, Color(accent, 0.88), 2.4, true)

	var arm_lift := 0.0
	match _approach:
		"compare": arm_lift = -15.0
		"experiment": arm_lift = -28.0
		"explain": arm_lift = -38.0
		_: arm_lift = -5.0
	var shoulder_y := body_center.y + 4.0 * scale_factor
	for direction: float in [-1.0, 1.0]:
		var start := Vector2(body_center.x + direction * body_radius * 0.78, shoulder_y)
		var end := start + Vector2(direction * 34.0, 28.0 + arm_lift) * scale_factor
		draw_line(start, end, COLOR_INK, 15.0 * scale_factor, true)
		draw_circle(end, 9.0 * scale_factor, Color(accent, 0.70))

	draw_circle(body_center + Vector2(-23.0, 22.0) * scale_factor, 7.0 * scale_factor, Color(accent, 0.16))
	draw_circle(body_center + Vector2(23.0, 22.0) * scale_factor, 7.0 * scale_factor, Color(accent, 0.16))

func _draw_symbols(accent: Color) -> void:
	var labels: Array[String] = _domain_symbols(_domain)
	var font: Font = ThemeDB.fallback_font
	var center := Vector2(size.x * 0.50, size.y * 0.43)
	var radius := minf(size.x, size.y) * 0.34
	for index: int in range(labels.size()):
		var angle := -PI * 0.82 + float(index) * PI * 0.54 + _pulse * 0.08
		var position := center + Vector2(cos(angle), sin(angle)) * radius
		draw_circle(position, 20.0, Color(COLOR_VOID, 0.88))
		draw_arc(position, 20.0, 0.0, TAU, 24, Color(accent, 0.50), 1.5, true)
		draw_string(font, position + Vector2(-18.0, 5.0), labels[index], HORIZONTAL_ALIGNMENT_CENTER, 36.0, 13, COLOR_TEXT)

func _draw_caption(accent: Color) -> void:
	var font: Font = ThemeDB.fallback_font
	var caption := "ZWÖLF WEGE · EIN WACHSENDER VERSTAND" if _adventure_id == "catalog" else "%s · RUNDE %d" % [_domain.to_upper(), _round]
	draw_string(font, Vector2(12.0, size.y - 13.0), caption, HORIZONTAL_ALIGNMENT_LEFT, size.x - 24.0, 11, Color(accent, 0.78))

func _domain_color(domain: String) -> Color:
	match domain:
		"language", "memory": return COLOR_VIOLET
		"rhythm", "creativity": return COLOR_MAGENTA
		"empathy": return Color("ff7aa8")
		"math", "reasoning": return COLOR_GOLD
		"science", "systems": return COLOR_GREEN
		"media", "spatial": return Color("6fa8ff")
		_: return COLOR_CYAN

func _domain_symbols(domain: String) -> Array[String]:
	match domain:
		"logic": return ["△", "7", "↗"]
		"language": return ["A", "?", "↔"]
		"rhythm": return ["♪", "●", "Ⅱ"]
		"empathy": return ["♡", "…", "☺"]
		"math": return ["+", "÷", "≈"]
		"media": return ["?", "◉", "!"]
		"science": return ["?", "⚗", "✓"]
		"spatial": return ["◇", "↻", "⌂"]
		"memory": return ["1", "2", "3"]
		"creativity": return ["✦", "+", "?"]
		"reasoning": return ["!", "↔", "✓"]
		"systems": return ["○", "→", "∞"]
		_: return ["?", "✦", "→"]
