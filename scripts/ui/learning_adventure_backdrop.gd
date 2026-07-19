extends Control

## Lightweight procedural art layer for the twelve Learning Adventures. It keeps
## each field visually distinct while respecting reduced-motion and mobile budgets.

const COLOR_VOID := Color("02040d")
const COLORS: Dictionary = {
	"logic": Color("42e8ff"),
	"language": Color("a855f7"),
	"music": Color("f044d4"),
	"math": Color("ffc85a"),
	"media": Color("6fa8ff"),
	"emotion": Color("ff8eb6"),
	"science": Color("65f0b2"),
	"creativity": Color("e78cff"),
	"debate": Color("ff9f6f"),
	"spatial": Color("42d5ff"),
	"teaching": Color("ffd56f")
}

var adventure_id: String = "pattern_relay"
var domain: String = "logic"
var mechanic: String = "choice"
var reduced_motion: bool = false
var timing_value: float = 0.0
var timing_target: float = 0.5
var timing_window: float = 0.15
var _clock: float = 0.0
var _pulse_strength: float = 0.0
var _pulse_success: bool = true
var _nodes: Array[Dictionary] = []

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(true)
	_build_nodes()

func set_adventure(next_id: String, next_domain: String, next_mechanic: String) -> void:
	adventure_id = next_id
	domain = next_domain
	mechanic = next_mechanic
	_build_nodes()
	queue_redraw()

func set_timing(value: float, target: float, window: float) -> void:
	timing_value = clampf(value, 0.0, 1.0)
	timing_target = clampf(target, 0.0, 1.0)
	timing_window = clampf(window, 0.04, 0.30)
	queue_redraw()

func pulse(success: bool, score: float) -> void:
	_pulse_success = success
	_pulse_strength = clampf(0.45 + score * 0.75, 0.45, 1.2)
	queue_redraw()

func get_visual_snapshot() -> Dictionary:
	return {
		"adventure_id": adventure_id,
		"domain": domain,
		"mechanic": mechanic,
		"reduced_motion": reduced_motion,
		"node_count": _nodes.size(),
		"timing_value": timing_value,
		"pulse_strength": _pulse_strength
	}

func _process(delta: float) -> void:
	var safe_delta: float = maxf(delta, 0.0)
	if not reduced_motion:
		_clock = fmod(_clock + safe_delta, TAU * 100.0)
	for node: Dictionary in _nodes:
		var position: Vector2 = node.get("position", Vector2.ZERO) as Vector2
		position.y -= float(node.get("speed", 0.003)) * safe_delta
		if position.y < -0.06:
			position.y = 1.06
		node["position"] = position
	_pulse_strength = maxf(_pulse_strength - safe_delta * 1.9, 0.0)
	queue_redraw()

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), COLOR_VOID)
	var accent: Color = COLORS.get(domain, COLORS["logic"]) as Color
	_draw_atmosphere(accent)
	match domain:
		"logic", "math":
			_draw_pattern_field(accent)
		"language", "debate", "teaching":
			_draw_signal_threads(accent)
		"music":
			_draw_rhythm_field(accent)
		"emotion":
			_draw_emotion_field(accent)
		"science":
			_draw_ecosystem_field(accent)
		"creativity":
			_draw_story_field(accent)
		"media":
			_draw_evidence_field(accent)
		"spatial":
			_draw_navigation_field(accent)
		_:
			_draw_pattern_field(accent)
	if mechanic == "timing":
		_draw_timing_track(accent)
	if _pulse_strength > 0.0:
		var pulse_color: Color = Color("64e6a2") if _pulse_success else Color("ffc85a")
		draw_circle(size * 0.5, minf(size.x, size.y) * (0.12 + _pulse_strength * 0.08), Color(pulse_color, 0.08 * _pulse_strength))

func _draw_atmosphere(accent: Color) -> void:
	var center: Vector2 = size * Vector2(0.52, 0.45)
	for index: int in range(8, 0, -1):
		var radius: float = minf(size.x, size.y) * (0.10 + float(index) * 0.075)
		draw_circle(center, radius, Color(accent, 0.009 + float(8 - index) * 0.004))
	for node: Dictionary in _nodes:
		var normalized: Vector2 = node.get("position", Vector2.ZERO) as Vector2
		var position: Vector2 = Vector2(normalized.x * size.x, normalized.y * size.y)
		var radius: float = float(node.get("radius", 1.5))
		var phase: float = float(node.get("phase", 0.0))
		var glow: float = 0.55 + 0.35 * sin(_clock * 0.8 + phase)
		draw_circle(position, radius * 3.0, Color(accent, 0.035 * glow))
		draw_circle(position, radius, Color(accent, 0.42 * glow))

func _draw_pattern_field(accent: Color) -> void:
	var center: Vector2 = size * 0.5
	var radius: float = minf(size.x, size.y) * 0.27
	for ring: int in range(3):
		var ring_radius: float = radius * (0.45 + float(ring) * 0.27)
		draw_arc(center, ring_radius, 0.0, TAU, 72, Color(accent, 0.16), 2.0, true)
	for index: int in range(10):
		var angle: float = TAU * float(index) / 10.0 + _clock * (0.04 if not reduced_motion else 0.0)
		var point: Vector2 = center + Vector2(cos(angle), sin(angle)) * radius
		draw_line(center, point, Color(accent, 0.09), 1.0, true)
		draw_circle(point, 5.0 + float(index % 3), Color(accent, 0.38))

func _draw_signal_threads(accent: Color) -> void:
	var left: float = size.x * 0.10
	var right: float = size.x * 0.90
	for row: int in range(7):
		var y: float = size.y * (0.17 + float(row) * 0.105)
		var points := PackedVector2Array()
		for step: int in range(25):
			var ratio: float = float(step) / 24.0
			var wave: float = sin(ratio * TAU * (1.0 + float(row % 3)) + _clock * 0.65 + float(row)) * 13.0
			points.append(Vector2(lerpf(left, right, ratio), y + wave))
		draw_polyline(points, Color(accent, 0.12 + float(row % 2) * 0.05), 2.0, true)

func _draw_rhythm_field(accent: Color) -> void:
	var center: Vector2 = size * 0.5
	for index: int in range(16):
		var angle: float = TAU * float(index) / 16.0
		var beat: float = 0.5 + 0.5 * sin(_clock * 2.4 + float(index) * 0.72)
		var inner: Vector2 = center + Vector2(cos(angle), sin(angle)) * minf(size.x, size.y) * 0.17
		var outer: Vector2 = center + Vector2(cos(angle), sin(angle)) * minf(size.x, size.y) * (0.23 + beat * 0.07)
		draw_line(inner, outer, Color(accent, 0.18 + beat * 0.22), 3.0, true)

func _draw_emotion_field(accent: Color) -> void:
	var center: Vector2 = size * 0.5
	var orbit: float = minf(size.x, size.y) * 0.22
	for index: int in range(6):
		var angle: float = TAU * float(index) / 6.0 + sin(_clock * 0.3) * 0.18
		var point: Vector2 = center + Vector2(cos(angle), sin(angle)) * orbit
		draw_circle(point, 22.0, Color(accent, 0.08))
		draw_arc(point, 15.0, 0.0, TAU, 32, Color(accent, 0.40), 2.0, true)
		draw_line(center, point, Color(accent, 0.11), 2.0, true)

func _draw_ecosystem_field(accent: Color) -> void:
	var baseline: float = size.y * 0.72
	for index: int in range(9):
		var x: float = size.x * (0.10 + float(index) * 0.10)
		var height: float = size.y * (0.12 + float((index * 7) % 5) * 0.025)
		var sway: float = sin(_clock * 0.7 + float(index)) * 8.0
		draw_line(Vector2(x, baseline), Vector2(x + sway, baseline - height), Color(accent, 0.30), 4.0, true)
		draw_circle(Vector2(x + sway, baseline - height), 12.0, Color(accent, 0.16))
	for index: int in range(5):
		var y: float = size.y * (0.26 + float(index) * 0.065)
		draw_arc(size * Vector2(0.55, y / size.y), size.x * (0.12 + float(index) * 0.025), 0.15, PI - 0.15, 48, Color(accent, 0.10), 2.0, true)

func _draw_story_field(accent: Color) -> void:
	var points := PackedVector2Array()
	for index: int in range(7):
		var ratio: float = float(index) / 6.0
		var point: Vector2 = Vector2(size.x * (0.12 + ratio * 0.76), size.y * (0.55 + sin(ratio * TAU * 1.4 + _clock * 0.22) * 0.16))
		points.append(point)
		draw_circle(point, 12.0, Color(accent, 0.20))
		draw_arc(point, 12.0, 0.0, TAU, 24, Color(accent, 0.55), 2.0, true)
	draw_polyline(points, Color(accent, 0.24), 3.0, true)

func _draw_evidence_field(accent: Color) -> void:
	var center: Vector2 = size * 0.5
	for index: int in range(8):
		var angle: float = TAU * float(index) / 8.0 + _clock * 0.03
		var distance: float = minf(size.x, size.y) * (0.18 + float(index % 2) * 0.08)
		var point: Vector2 = center + Vector2(cos(angle), sin(angle)) * distance
		draw_line(center, point, Color(accent, 0.12), 2.0, true)
		draw_rect(Rect2(point - Vector2(13, 9), Vector2(26, 18)), Color(accent, 0.13), true)
		draw_rect(Rect2(point - Vector2(13, 9), Vector2(26, 18)), Color(accent, 0.45), false, 2.0)
	draw_circle(center, 30.0, Color(accent, 0.12))
	draw_arc(center, 30.0, 0.0, TAU, 48, Color(accent, 0.58), 3.0, true)

func _draw_navigation_field(accent: Color) -> void:
	var inset: Vector2 = size * Vector2(0.14, 0.16)
	var bounds: Vector2 = size - inset * 2.0
	for row: int in range(6):
		for column: int in range(8):
			if (row + column * 2) % 4 == 0:
				continue
			var position: Vector2 = inset + Vector2(float(column) / 7.0 * bounds.x, float(row) / 5.0 * bounds.y)
			draw_circle(position, 3.0, Color(accent, 0.25))
	var route := PackedVector2Array([
		inset + Vector2(0.0, bounds.y * 0.85),
		inset + Vector2(bounds.x * 0.24, bounds.y * 0.64),
		inset + Vector2(bounds.x * 0.47, bounds.y * 0.72),
		inset + Vector2(bounds.x * 0.68, bounds.y * 0.38),
		inset + Vector2(bounds.x, bounds.y * 0.18)
	])
	draw_polyline(route, Color(accent, 0.42), 5.0, true)
	for point: Vector2 in route:
		draw_circle(point, 8.0, Color(accent, 0.38))

func _draw_timing_track(accent: Color) -> void:
	var track_rect := Rect2(size.x * 0.10, size.y * 0.84, size.x * 0.80, 26.0)
	draw_rect(track_rect, Color("111a35"), true)
	var target_x: float = track_rect.position.x + track_rect.size.x * timing_target
	var window_width: float = track_rect.size.x * timing_window * 2.0
	draw_rect(Rect2(target_x - window_width * 0.5, track_rect.position.y, window_width, track_rect.size.y), Color(accent, 0.24), true)
	draw_line(Vector2(target_x, track_rect.position.y - 8.0), Vector2(target_x, track_rect.end.y + 8.0), Color(accent, 0.80), 3.0, true)
	var marker_x: float = track_rect.position.x + track_rect.size.x * timing_value
	draw_circle(Vector2(marker_x, track_rect.get_center().y), 11.0, Color("f4f7ff"))
	draw_circle(Vector2(marker_x, track_rect.get_center().y), 6.0, accent)

func _build_nodes() -> void:
	_nodes.clear()
	var seed_value: int = int(abs(hash("%s:%s" % [adventure_id, domain])))
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_value
	for index: int in range(42):
		_nodes.append({
			"position": Vector2(rng.randf(), rng.randf()),
			"radius": rng.randf_range(1.0, 2.8),
			"speed": rng.randf_range(0.002, 0.008),
			"phase": rng.randf_range(0.0, TAU)
		})
