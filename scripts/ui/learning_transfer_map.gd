extends Control

## Visualizes how one learning adventure reaches technique, expedition and
## evolution. It turns the final decision space into a readable game-system map.

const COLOR_VOID := Color("071020")
const COLOR_CYAN := Color("42e8ff")
const COLOR_GREEN := Color("64e6a2")
const COLOR_VIOLET := Color("a855f7")
const COLOR_MAGENTA := Color("f044d4")
const COLOR_GOLD := Color("ffc85a")
const COLOR_TEXT := Color("f4f7ff")
const COLOR_MUTED := Color("9ba8c7")

var _domain: String = "LERNEN"
var _technique: String = "TECHNIK"
var _expedition: String = "EXPEDITION"
var _evolution: String = "EVOLUTION"
var _approach: String = "BEOBACHTEN"
var _pulse: float = 0.0
var _reduced_motion: bool = false

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(true)

func set_context(domain: String, technique: String, expedition: String, evolution: String, approach: String) -> void:
	_domain = _clean(domain, "LERNEN")
	_technique = _clean(technique, "TECHNIK")
	_expedition = _clean(expedition, "EXPEDITION")
	_evolution = _clean(evolution, "EVOLUTION")
	_approach = _clean(approach, "BEOBACHTEN")
	queue_redraw()

func set_reduced_motion(enabled: bool) -> void:
	if _reduced_motion == enabled:
		return
	_reduced_motion = enabled
	set_process(not enabled)
	queue_redraw()

func get_snapshot() -> Dictionary:
	return {
		"domain": _domain,
		"technique": _technique,
		"expedition": _expedition,
		"evolution": _evolution,
		"approach": _approach,
		"nodes": 4,
		"processing": is_processing(),
		"reduced_motion": _reduced_motion
	}

func _process(delta: float) -> void:
	if _reduced_motion:
		return
	_pulse = fmod(_pulse + maxf(delta, 0.0), TAU * 20.0)
	queue_redraw()

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), COLOR_VOID)
	var center := Vector2(size.x * 0.50, size.y * 0.50)
	var radius_x := minf(size.x * 0.34, 240.0)
	var radius_y := minf(size.y * 0.30, 120.0)
	var nodes := [
		{"position": center + Vector2(-radius_x, -radius_y * 0.55), "title": "TECHNIK", "value": _technique, "color": COLOR_GREEN},
		{"position": center + Vector2(radius_x, -radius_y * 0.55), "title": "EXPEDITION", "value": _expedition, "color": COLOR_CYAN},
		{"position": center + Vector2(0.0, radius_y), "title": "EVOLUTION", "value": _evolution, "color": COLOR_VIOLET}
	]
	for node_variant: Variant in nodes:
		var node := node_variant as Dictionary
		var target := node.get("position", center) as Vector2
		var accent := node.get("color", COLOR_CYAN) as Color
		draw_line(center, target, Color(accent, 0.30), 3.0, true)
		var travel := 0.5 if _reduced_motion else 0.5 + 0.5 * sin(_pulse * 1.7 + target.x * 0.01)
		draw_circle(center.lerp(target, travel), 4.0, Color(accent, 0.92))
		_draw_node(target, str(node.get("title", "TRANSFER")), str(node.get("value", "-")), accent, 47.0)
	_draw_node(center, _domain, _approach, COLOR_GOLD, 58.0)
	var font := ThemeDB.fallback_font
	draw_string(font, Vector2(12.0, 18.0), "WISSENSTRANSFER-KONSTELLATION", HORIZONTAL_ALIGNMENT_LEFT, size.x - 24.0, 10, COLOR_MUTED)

func _draw_node(position: Vector2, title: String, value: String, accent: Color, radius: float) -> void:
	var pulse_radius := radius + 4.0 if _reduced_motion else radius + 4.0 + 2.5 * sin(_pulse * 2.0 + position.x * 0.02)
	draw_circle(position, pulse_radius, Color(accent, 0.055))
	draw_circle(position, radius, Color("0c1930"))
	draw_arc(position, radius, 0.0, TAU, 38, Color(accent, 0.74), 2.0, true)
	var font := ThemeDB.fallback_font
	var width := radius * 1.65
	draw_string(font, position + Vector2(-width * 0.5, -4.0), title, HORIZONTAL_ALIGNMENT_CENTER, width, 11, accent)
	draw_string(font, position + Vector2(-width * 0.5, 13.0), _shorten(value, 18), HORIZONTAL_ALIGNMENT_CENTER, width, 10, COLOR_TEXT)

func _clean(value: String, fallback: String) -> String:
	var cleaned := value.strip_edges().replace("_", " ").to_upper()
	return fallback if cleaned.is_empty() else cleaned

func _shorten(value: String, limit: int) -> String:
	return value if value.length() <= limit else "%s…" % value.left(limit - 1)
