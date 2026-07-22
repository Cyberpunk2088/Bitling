extends Control

## Non-blocking HUD layer drawn over the production 3D room. Input stays on the
## stage, so the markers cannot turn the habitat back into a panel menu.

const CYAN := Color("42e8ff")
const MAGENTA := Color("f044d4")
const TEXT := Color("eefaff")

var focused_hotspot := "bitling"
var activity_lens := "care"
var moment_title := ""
var _elapsed := 0.0
var _flash := 0.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	resized.connect(queue_redraw)
	set_process(true)

func set_context(hotspot_id: String, lens_id: String, title: String) -> void:
	focused_hotspot = hotspot_id
	activity_lens = lens_id
	moment_title = title
	_flash = 1.0
	queue_redraw()

func set_hotspot(hotspot_id: String) -> void:
	focused_hotspot = hotspot_id
	_flash = 1.0
	queue_redraw()

func set_lens(lens_id: String) -> void:
	activity_lens = lens_id
	queue_redraw()

func set_title(title: String) -> void:
	moment_title = title
	queue_redraw()

func _process(delta: float) -> void:
	_elapsed += maxf(delta, 0.0)
	_flash = move_toward(_flash, 0.0, delta * 1.8)
	queue_redraw()

func _draw() -> void:
	if size.x <= 1.0 or size.y <= 1.0:
		return
	var markers := {
		"window": Vector2(size.x * 0.50, size.y * 0.14),
		"workbench": Vector2(size.x * 0.86, size.y * 0.48),
		"plant": Vector2(size.x * 0.12, size.y * 0.45),
		"platform": Vector2(size.x * 0.82, size.y * 0.79),
		"sleep": Vector2(size.x * 0.16, size.y * 0.80)
	}
	for hotspot_variant in markers.keys():
		var hotspot := str(hotspot_variant)
		var point: Vector2 = markers[hotspot]
		var active := hotspot == focused_hotspot
		var accent := _lens_color(activity_lens) if active else CYAN
		var pulse := 1.0 + sin(_elapsed * 3.2 + point.x * 0.015) * 0.14
		var radius := (11.0 + _flash * 5.0 if active else 7.0) * pulse
		draw_circle(point, radius + 8.0, Color(accent, 0.14 if active else 0.06))
		draw_arc(point, radius, 0.0, TAU, 30, Color(accent, 0.90 if active else 0.48), 2.0, true)
		draw_circle(point, 2.5, accent)

	if not moment_title.is_empty():
		var ribbon := Rect2(size.x * 0.05, size.y * 0.025, size.x * 0.90, 36.0)
		draw_rect(ribbon, Color("061126dd"), true)
		draw_rect(ribbon, Color(_lens_color(activity_lens), 0.42), false, 1.0)
		var text := "%s  •  %s" % [_hotspot_label(focused_hotspot), moment_title]
		draw_string(ThemeDB.fallback_font, ribbon.position + Vector2(12.0, 23.0), text, HORIZONTAL_ALIGNMENT_LEFT, ribbon.size.x - 24.0, 12, TEXT)

func _lens_color(lens_id: String) -> Color:
	return {
		"feed": Color("64e6a2"),
		"play": Color("a855f7"),
		"learn": CYAN,
		"care": MAGENTA,
		"rest": Color("ffc85a")
	}.get(lens_id, CYAN) as Color

func _hotspot_label(hotspot_id: String) -> String:
	return str({
		"bitling": "XOGOT",
		"window": "FENSTER-SIGNAL",
		"workbench": "LERNWERKBANK",
		"plant": "RESONANZGARTEN",
		"platform": "HOLOPROJEKTOR",
		"sleep": "RUHEPOD"
	}.get(hotspot_id, hotspot_id.to_upper()))
