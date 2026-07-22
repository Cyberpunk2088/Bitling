extends "res://scripts/ui/bitling_stage.gd"

## The home is a playable surface. Every visible zone can become context for
## a relationship decision; the Bitling remains the actor, not a menu avatar.

signal hotspot_pressed(hotspot_id: String)

const HOTSPOT_COLOR := Color("77efff")
const HOTSPOT_ACTIVE := Color("ff62dc")

var focused_hotspot := "bitling"
var activity_lens := "care"
var moment_title := ""
var _hotspot_flash := 0.0

func set_focused_hotspot(hotspot_id: String) -> void:
	focused_hotspot = hotspot_id
	_hotspot_flash = 1.0
	queue_redraw()

func set_activity_lens(lens_id: String) -> void:
	activity_lens = lens_id
	queue_redraw()

func set_moment_title(value: String) -> void:
	moment_title = value
	queue_redraw()

func _process(delta: float) -> void:
	super._process(delta)
	_hotspot_flash = move_toward(_hotspot_flash, 0.0, delta * 1.8)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		super._gui_input(event)
		return
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.pressed and mouse_event.button_index == MOUSE_BUTTON_LEFT:
			var hotspot := _hotspot_at(mouse_event.position)
			if not hotspot.is_empty() and hotspot != "bitling":
				focused_hotspot = hotspot
				_hotspot_flash = 1.0
				play_reaction()
				hotspot_pressed.emit(hotspot)
				accept_event()
				queue_redraw()
				return
	if event is InputEventScreenTouch:
		var touch_event := event as InputEventScreenTouch
		if touch_event.pressed:
			var hotspot := _hotspot_at(touch_event.position)
			if not hotspot.is_empty() and hotspot != "bitling":
				focused_hotspot = hotspot
				_hotspot_flash = 1.0
				play_reaction()
				hotspot_pressed.emit(hotspot)
				accept_event()
				queue_redraw()
				return
	super._gui_input(event)

func _draw() -> void:
	super._draw()
	_draw_sleep_pod()
	_draw_habitat_markers()
	_draw_context_ribbon()

func _draw_sleep_pod() -> void:
	var pod := Rect2(size.x * 0.73, size.y * 0.72, size.x * 0.21, size.y * 0.10)
	draw_rect(pod, Color("10172f"), true)
	draw_rect(pod, Color(CYAN, 0.22), false, 2.0)
	draw_arc(Vector2(pod.position.x + pod.size.x * 0.50, pod.position.y), pod.size.x * 0.42, PI, TAU, 32, Color(VIOLET, 0.45), 3.0, true)
	draw_line(pod.position + Vector2(12.0, pod.size.y * 0.70), pod.end - Vector2(12.0, pod.size.y * 0.30), Color(MAGENTA, 0.24), 3.0, true)

func _draw_habitat_markers() -> void:
	var markers := {
		"window": Vector2(size.x * 0.80, size.y * 0.20),
		"workbench": Vector2(size.x * 0.17, size.y * 0.47),
		"plant": Vector2(size.x * 0.90, size.y * 0.47),
		"platform": Vector2(size.x * 0.25, size.y * 0.82),
		"sleep": Vector2(size.x * 0.83, size.y * 0.77)
	}
	for hotspot_variant in markers.keys():
		var hotspot := str(hotspot_variant)
		var point: Vector2 = markers[hotspot]
		var active := hotspot == focused_hotspot
		var pulse := 1.0 + 0.16 * sin(_elapsed * 3.0 + point.x * 0.01)
		var radius := (10.0 + 5.0 * _hotspot_flash if active else 8.0) * pulse
		var color := HOTSPOT_ACTIVE if active else HOTSPOT_COLOR
		draw_circle(point, radius + 7.0, Color(color, 0.08 if not active else 0.18))
		draw_arc(point, radius, 0.0, TAU, 28, Color(color, 0.76 if active else 0.42), 2.0, true)
		draw_circle(point, 2.5, color)

func _draw_context_ribbon() -> void:
	if moment_title.is_empty():
		return
	var ribbon := Rect2(size.x * 0.05, size.y * 0.025, size.x * 0.90, 34.0)
	draw_rect(ribbon, Color("071326d9"), true)
	draw_rect(ribbon, Color(HOTSPOT_COLOR, 0.30), false, 1.0)
	var label := "%s  •  %s" % [_hotspot_label(focused_hotspot), moment_title]
	draw_string(ThemeDB.fallback_font, ribbon.position + Vector2(12.0, 22.0), label, HORIZONTAL_ALIGNMENT_LEFT, ribbon.size.x - 24.0, 12, Color("eafaff"))

func _hotspot_at(position: Vector2) -> String:
	var zones := {
		"bitling": Rect2(size.x * 0.29, size.y * 0.31, size.x * 0.42, size.y * 0.43),
		"window": Rect2(size.x * 0.58, size.y * 0.10, size.x * 0.33, size.y * 0.29),
		"workbench": Rect2(size.x * 0.02, size.y * 0.34, size.x * 0.31, size.y * 0.25),
		"plant": Rect2(size.x * 0.78, size.y * 0.33, size.x * 0.21, size.y * 0.27),
		"platform": Rect2(size.x * 0.04, size.y * 0.70, size.x * 0.49, size.y * 0.28),
		"sleep": Rect2(size.x * 0.66, size.y * 0.66, size.x * 0.33, size.y * 0.30)
	}
	for hotspot_variant in ["bitling", "window", "workbench", "plant", "platform", "sleep"]:
		var hotspot := str(hotspot_variant)
		if (zones[hotspot] as Rect2).has_point(position):
			return hotspot
	return ""

func _hotspot_label(hotspot_id: String) -> String:
	return str({
		"bitling": "XOGOT",
		"window": "FENSTER-SIGNAL",
		"workbench": "WERKBANK",
		"plant": "RESONANZPFLANZE",
		"platform": "SPIELPLATTFORM",
		"sleep": "RUHEPOD"
	}.get(hotspot_id, hotspot_id.to_upper()))
