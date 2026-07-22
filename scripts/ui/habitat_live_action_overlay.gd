extends Control

## Non-blocking in-world action HUD. The production stage owns input; this layer
## only renders Xogot's movement path, action phase and three contextual tokens.

const TEXT := Color("eefaff")
const MUTED := Color("9fb3c8")
const CYAN := Color("42e8ff")
const MAGENTA := Color("f044d4")
const VIOLET := Color("a855f7")
const GREEN := Color("64e6a2")
const YELLOW := Color("ffc85a")
const ROW_LAYOUT_MIN_WIDTH := 430.0

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

func get_choice_regions() -> Array[Rect2]:
	var result: Array[Rect2] = []
	if not bool(snapshot.get("active", false)) or str(snapshot.get("phase", "")) != "awaiting_choice":
		return result
	var choices: Array = snapshot.get("choices", []) as Array
	var centers := _choice_centers(str(snapshot.get("hotspot", "bitling")))
	for index in range(mini(choices.size(), centers.size())):
		var center: Vector2 = centers[index]
		var width := clampf(size.x * 0.26, 94.0, 162.0)
		var height := clampf(size.y * 0.105, 70.0, 92.0)
		result.append(Rect2(center - Vector2(width, height) * 0.5, Vector2(width, height)))
	return result

func get_visual_snapshot() -> Dictionary:
	return {
		"active": bool(snapshot.get("active", false)),
		"phase": str(snapshot.get("phase", "idle")),
		"source": str(snapshot.get("source", "none")),
		"choice_tokens_visible": get_choice_regions().size(),
		"choice_layout": _choice_layout(),
		"in_world_choice_surface": get_choice_regions().size() == 3,
		"input_passthrough": mouse_filter == Control.MOUSE_FILTER_IGNORE
	}

func _process(delta: float) -> void:
	_elapsed += maxf(delta, 0.0)
	queue_redraw()

func _draw() -> void:
	if size.x <= 1.0 or size.y <= 1.0 or not bool(snapshot.get("active", false)):
		return
	var phase := str(snapshot.get("phase", "approach"))
	var hotspot := str(snapshot.get("hotspot", "bitling"))
	var accent := _lens_color(str(snapshot.get("selected_lens", "care")))
	var target := _hotspot_point(hotspot)
	var source_point := Vector2(size.x * 0.50, size.y * 0.58)
	var progress := clampf(float(snapshot.get("phase_progress", 0.0)), 0.0, 1.0)

	_draw_phase_ribbon(phase, hotspot, accent, progress)
	_draw_motion_path(source_point, target, accent, progress, phase)
	_draw_target_pulse(target, accent, phase)
	if phase == "awaiting_choice":
		_draw_choice_tokens(accent)
	elif phase == "perform":
		_draw_perform_feedback(target, accent)
	elif phase == "aftermath":
		_draw_aftermath_feedback(target, accent)

func _draw_phase_ribbon(phase: String, hotspot: String, accent: Color, progress: float) -> void:
	var ribbon := Rect2(size.x * 0.06, size.y * 0.025, size.x * 0.88, 42.0)
	draw_rect(ribbon, Color("061126e8"), true)
	draw_rect(ribbon, Color(accent, 0.58), false, 1.5)
	var source_label := "XOGOTS INITIATIVE" if str(snapshot.get("source", "player")) == "xogot" else "GEMEINSAMER MOMENT"
	var label := "%s · %s · %s" % [source_label, _hotspot_label(hotspot), _phase_label(phase)]
	draw_string(ThemeDB.fallback_font, ribbon.position + Vector2(10.0, 19.0), label, HORIZONTAL_ALIGNMENT_CENTER, ribbon.size.x - 20.0, 11, TEXT)
	var track := Rect2(ribbon.position + Vector2(10.0, 29.0), Vector2(ribbon.size.x - 20.0, 4.0))
	draw_rect(track, Color(accent, 0.16), true)
	draw_rect(Rect2(track.position, Vector2(track.size.x * progress, track.size.y)), accent, true)

func _draw_motion_path(from: Vector2, to: Vector2, accent: Color, progress: float, phase: String) -> void:
	if phase not in ["approach", "observe", "awaiting_choice", "perform"]:
		return
	var control := (from + to) * 0.5 + Vector2(0.0, -size.y * 0.07)
	var previous := from
	for index in range(1, 25):
		var t := float(index) / 24.0
		var point := from * pow(1.0 - t, 2.0) + control * 2.0 * (1.0 - t) * t + to * t * t
		var alpha := 0.16 + 0.42 * minf(t, maxf(progress, 0.18))
		draw_line(previous, point, Color(accent, alpha), 2.0, true)
		previous = point
	var traveler_t := progress if phase == "approach" else 1.0
	var traveler := from * pow(1.0 - traveler_t, 2.0) + control * 2.0 * (1.0 - traveler_t) * traveler_t + to * traveler_t * traveler_t
	draw_circle(traveler, 5.0 + 2.0 * sin(_elapsed * 6.0), Color(accent, 0.90))

func _draw_target_pulse(point: Vector2, accent: Color, phase: String) -> void:
	var pulse := 1.0 + 0.12 * sin(_elapsed * 3.8)
	var radius := (15.0 if phase == "awaiting_choice" else 11.0) * pulse
	draw_circle(point, radius + 10.0, Color(accent, 0.08))
	draw_arc(point, radius, 0.0, TAU, 36, Color(accent, 0.78), 2.0, true)
	draw_circle(point, 3.0, accent)

func _draw_choice_tokens(accent: Color) -> void:
	var choices: Array = snapshot.get("choices", []) as Array
	var regions := get_choice_regions()
	for index in range(mini(choices.size(), regions.size())):
		var option := choices[index] as Dictionary
		var region := regions[index]
		var behavior := str(option.get("behavior_label", "OFFEN"))
		var friction := roundi(float(option.get("friction", 0.0)))
		var token_accent := MAGENTA if behavior == "GRENZE" else YELLOW if behavior == "AUSHANDELN" else accent
		var pulse := 0.06 + 0.03 * sin(_elapsed * 4.2 + float(index))
		draw_rect(region, Color(token_accent, 0.12 + pulse), true)
		draw_rect(region, Color(token_accent, 0.82), false, 2.0)
		var number_center := region.position + Vector2(15.0, 15.0)
		draw_circle(number_center, 10.0, Color(token_accent, 0.26))
		draw_string(ThemeDB.fallback_font, number_center + Vector2(-4.0, 4.0), str(index + 1), HORIZONTAL_ALIGNMENT_LEFT, -1.0, 10, TEXT)
		var title := str(option.get("title", "Wählen")).to_upper()
		draw_string(ThemeDB.fallback_font, region.position + Vector2(30.0, 18.0), title, HORIZONTAL_ALIGNMENT_LEFT, region.size.x - 36.0, 10, TEXT)
		var state := "%s · REIBUNG %d" % [behavior, friction]
		draw_string(ThemeDB.fallback_font, region.position + Vector2(8.0, region.size.y - 11.0), state, HORIZONTAL_ALIGNMENT_CENTER, region.size.x - 16.0, 9, Color(token_accent, 0.95))

func _draw_perform_feedback(point: Vector2, accent: Color) -> void:
	var progress := clampf(float(snapshot.get("phase_progress", 0.0)), 0.0, 1.0)
	for index in range(3):
		var radius := 24.0 + float(index) * 14.0 + progress * 22.0
		draw_arc(point, radius, -PI * 0.82, PI * 0.82, 40, Color(accent, 0.62 - float(index) * 0.14), 3.0, true)
	var selected := str(snapshot.get("selected_choice", ""))
	draw_string(ThemeDB.fallback_font, point + Vector2(-90.0, 72.0), selected.replace("_", " ").to_upper(), HORIZONTAL_ALIGNMENT_CENTER, 180.0, 11, TEXT)

func _draw_aftermath_feedback(point: Vector2, accent: Color) -> void:
	var progress := clampf(float(snapshot.get("phase_progress", 0.0)), 0.0, 1.0)
	var radius := 28.0 + progress * 34.0
	draw_arc(point, radius, 0.0, TAU, 48, Color(accent, 0.78 * (1.0 - progress)), 3.0, true)
	draw_string(ThemeDB.fallback_font, point + Vector2(-100.0, 70.0), "FOLGE WIRD IM RAUM GESPEICHERT", HORIZONTAL_ALIGNMENT_CENTER, 200.0, 10, MUTED)

func _choice_centers(hotspot: String) -> Array[Vector2]:
	var center := _hotspot_point(hotspot)
	if _choice_layout() == "row":
		var y := clampf(center.y + size.y * 0.20, size.y * 0.58, size.y * 0.82)
		return [Vector2(size.x * 0.22, y), Vector2(size.x * 0.50, y), Vector2(size.x * 0.78, y)]
	var base_y := clampf(center.y + size.y * 0.18, size.y * 0.50, size.y * 0.70)
	return [Vector2(size.x * 0.50, base_y), Vector2(size.x * 0.50, base_y + size.y * 0.115), Vector2(size.x * 0.50, base_y + size.y * 0.230)]

func _choice_layout() -> String:
	return "row" if size.x >= ROW_LAYOUT_MIN_WIDTH else "stack"

func _hotspot_point(hotspot: String) -> Vector2:
	return {
		"bitling": Vector2(size.x * 0.50, size.y * 0.54),
		"window": Vector2(size.x * 0.50, size.y * 0.18),
		"workbench": Vector2(size.x * 0.84, size.y * 0.48),
		"plant": Vector2(size.x * 0.13, size.y * 0.48),
		"platform": Vector2(size.x * 0.79, size.y * 0.79),
		"sleep": Vector2(size.x * 0.18, size.y * 0.79)
	}.get(hotspot, Vector2(size.x * 0.50, size.y * 0.54)) as Vector2

func _phase_label(phase: String) -> String:
	return str({
		"approach": "XOGOT GEHT HIN",
		"observe": "XOGOT LIEST DIE SITUATION",
		"awaiting_choice": "WÄHLE IM RAUM",
		"perform": "XOGOT HANDELT",
		"aftermath": "DIE FOLGE BLEIBT"
	}.get(phase, phase.to_upper()))

func _hotspot_label(hotspot: String) -> String:
	return str({"bitling": "XOGOT", "window": "FENSTER", "workbench": "WERKBANK", "plant": "PFLANZE", "platform": "PLATTFORM", "sleep": "RUHEPOD"}.get(hotspot, hotspot.to_upper()))

func _lens_color(lens: String) -> Color:
	return {"feed": GREEN, "play": VIOLET, "learn": CYAN, "care": MAGENTA, "rest": YELLOW}.get(lens, CYAN) as Color
