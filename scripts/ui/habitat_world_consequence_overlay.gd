extends Control

## Persistent room-state layer. It visualizes what the relationship has changed
## inside the habitat without intercepting input from the playable 3D stage.

const TEXT := Color("eefaff")
const MUTED := Color("9fb3c8")

var snapshot: Dictionary = {}
var _elapsed := 0.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	resized.connect(queue_redraw)
	set_process(true)

func set_snapshot(value: Dictionary) -> void:
	snapshot = value.duplicate(true)
	queue_redraw()

func get_visual_snapshot() -> Dictionary:
	return {
		"world_marks_visible": (snapshot.get("world_marks", {}) as Dictionary).size(),
		"active_event_visible": not (snapshot.get("active_event", {}) as Dictionary).is_empty(),
		"input_passthrough": mouse_filter == Control.MOUSE_FILTER_IGNORE
	}

func _process(delta: float) -> void:
	_elapsed += maxf(delta, 0.0)
	queue_redraw()

func _draw() -> void:
	if size.x <= 1.0 or size.y <= 1.0:
		return
	var marks: Dictionary = snapshot.get("world_marks", {}) as Dictionary
	var points := {
		"bitling": Vector2(size.x * 0.50, size.y * 0.54),
		"window": Vector2(size.x * 0.50, size.y * 0.18),
		"workbench": Vector2(size.x * 0.85, size.y * 0.48),
		"plant": Vector2(size.x * 0.13, size.y * 0.48),
		"platform": Vector2(size.x * 0.80, size.y * 0.80),
		"sleep": Vector2(size.x * 0.18, size.y * 0.80)
	}
	for hotspot_variant in marks.keys():
		var hotspot := str(hotspot_variant)
		if not points.has(hotspot):
			continue
		var mark_variant: Variant = marks[hotspot_variant]
		if not mark_variant is Dictionary:
			continue
		var mark := mark_variant as Dictionary
		var point: Vector2 = points[hotspot]
		var accent := _accent(str(mark.get("accent", "cyan")))
		var level := clampi(int(mark.get("level", 1)), 1, 5)
		var intensity := clampf(float(mark.get("intensity", 50.0)), 0.0, 100.0)
		var pulse := 1.0 + sin(_elapsed * 2.2 + point.x * 0.01) * 0.08
		var radius := (12.0 + float(level) * 2.5 + intensity * 0.025) * pulse
		draw_circle(point, radius + 8.0, Color(accent, 0.06 + intensity * 0.0012))
		draw_arc(point, radius, 0.0, TAU, 36, Color(accent, 0.76), 2.5, true)
		for ring in range(level):
			draw_arc(point, radius - 4.0 - float(ring) * 3.0, -PI * 0.65, -PI * 0.15, 14, Color(accent, 0.42), 1.4, true)
		var title := str(mark.get("title", mark.get("state", "Folge")))
		var label_rect := Rect2(point + Vector2(-78.0, radius + 8.0), Vector2(156.0, 26.0))
		draw_rect(label_rect, Color("061126d9"), true)
		draw_rect(label_rect, Color(accent, 0.32), false, 1.0)
		draw_string(ThemeDB.fallback_font, label_rect.position + Vector2(6.0, 18.0), title, HORIZONTAL_ALIGNMENT_CENTER, label_rect.size.x - 12.0, 10, TEXT)

	var event: Dictionary = snapshot.get("active_event", {}) as Dictionary
	if not event.is_empty():
		var banner := Rect2(size.x * 0.13, size.y * 0.89, size.x * 0.74, 42.0)
		var accent := _accent(str(event.get("accent", "magenta")))
		draw_rect(banner, Color("090b1ee8"), true)
		draw_rect(banner, Color(accent, 0.70), false, 2.0)
		var prefix := "FOLGE" if str(event.get("type", "")) == "initiative" else "REIBUNG"
		var text := "%s · %s" % [prefix, str(event.get("title", "Gemeinsamer Moment"))]
		draw_string(ThemeDB.fallback_font, banner.position + Vector2(10.0, 26.0), text, HORIZONTAL_ALIGNMENT_CENTER, banner.size.x - 20.0, 12, TEXT)

func _accent(id: String) -> Color:
	return {
		"cyan": Color("42e8ff"),
		"magenta": Color("f044d4"),
		"violet": Color("a855f7"),
		"green": Color("64e6a2"),
		"yellow": Color("ffc85a")
	}.get(id, Color("42e8ff")) as Color
