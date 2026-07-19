extends CanvasLayer

## Persistent story guidance that never owns progression state.
## The HUD is anchored through a full-rect Control, capped to a strict height,
## and rendered below modal overlays so Home, Partner World and activities remain visible.

const COLOR_PANEL := Color("071024e8")
const COLOR_PANEL_ALT := Color("101a35")
const COLOR_TEXT := Color("f4f7ff")
const COLOR_MUTED := Color("9ba8c7")
const COLOR_CYAN := Color("42e8ff")
const COLOR_VIOLET := Color("a855f7")
const COLOR_MAGENTA := Color("f044d4")
const COLOR_GREEN := Color("64e6a2")

const MOBILE_TOP := 68.0
const MOBILE_HEIGHT_EXPANDED := 158.0
const MOBILE_HEIGHT_COLLAPSED := 72.0
const DESKTOP_TOP := 86.0
const DESKTOP_HEIGHT_EXPANDED := 170.0
const DESKTOP_HEIGHT_COLLAPSED := 76.0
const MODAL_LAYER_CEILING := 45

var root_control: Control
var panel: PanelContainer
var details_container: VBoxContainer
var chapter_label: Label
var title_label: Label
var objective_label: Label
var progress_bar: ProgressBar
var progress_label: Label
var continue_button: Button
var collapse_button: Button
var _collapsed := false
var _compact := false
var _last_beat_id := ""

func _ready() -> void:
	layer = 35
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_hud()
	_connect_story()
	get_viewport().size_changed.connect(_apply_layout)
	_apply_layout()
	_refresh()

func _build_hud() -> void:
	root_control = Control.new()
	root_control.name = "LegendaryStoryHUDRoot"
	root_control.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root_control.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root_control)

	panel = PanelContainer.new()
	panel.name = "LegendaryStoryHUD"
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.clip_contents = true
	panel.add_theme_stylebox_override("panel", _style(COLOR_PANEL, Color(COLOR_CYAN, 0.62), 18, 1))
	root_control.add_child(panel)

	var column := VBoxContainer.new()
	column.name = "StoryHUDColumn"
	column.add_theme_constant_override("separation", 5)
	panel.add_child(column)

	var top_row := HBoxContainer.new()
	top_row.add_theme_constant_override("separation", 7)
	column.add_child(top_row)
	chapter_label = Label.new()
	chapter_label.text = "LEGENDARY SLICE"
	chapter_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	chapter_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	chapter_label.add_theme_color_override("font_color", COLOR_CYAN)
	chapter_label.add_theme_font_size_override("font_size", 11)
	top_row.add_child(chapter_label)
	progress_label = Label.new()
	progress_label.text = "0/7"
	progress_label.add_theme_color_override("font_color", COLOR_MUTED)
	progress_label.add_theme_font_size_override("font_size", 11)
	top_row.add_child(progress_label)
	collapse_button = Button.new()
	collapse_button.text = "–"
	collapse_button.tooltip_text = "Story-Hinweis ein- oder ausklappen"
	collapse_button.custom_minimum_size = Vector2(36.0, 30.0)
	collapse_button.add_theme_color_override("font_color", COLOR_TEXT)
	collapse_button.add_theme_stylebox_override("normal", _style(COLOR_PANEL_ALT, Color(COLOR_VIOLET, 0.35), 9, 1))
	collapse_button.pressed.connect(_toggle_collapsed)
	top_row.add_child(collapse_button)

	title_label = Label.new()
	title_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	title_label.add_theme_color_override("font_color", COLOR_TEXT)
	title_label.add_theme_font_size_override("font_size", 17)
	column.add_child(title_label)

	details_container = VBoxContainer.new()
	details_container.add_theme_constant_override("separation", 5)
	column.add_child(details_container)

	progress_bar = ProgressBar.new()
	progress_bar.min_value = 0.0
	progress_bar.max_value = 1.0
	progress_bar.show_percentage = false
	progress_bar.custom_minimum_size = Vector2(0.0, 6.0)
	progress_bar.add_theme_stylebox_override("background", _bar_style(Color("030711"), 3))
	progress_bar.add_theme_stylebox_override("fill", _bar_style(COLOR_CYAN, 3))
	details_container.add_child(progress_bar)

	objective_label = Label.new()
	objective_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	objective_label.max_lines_visible = 2
	objective_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	objective_label.add_theme_color_override("font_color", COLOR_MUTED)
	objective_label.add_theme_font_size_override("font_size", 12)
	details_container.add_child(objective_label)

	continue_button = Button.new()
	continue_button.text = "FORTSETZEN"
	continue_button.custom_minimum_size = Vector2(0.0, 38.0)
	continue_button.add_theme_color_override("font_color", COLOR_TEXT)
	continue_button.add_theme_font_size_override("font_size", 12)
	continue_button.add_theme_stylebox_override("normal", _style(Color("191642"), COLOR_MAGENTA, 11, 1))
	continue_button.add_theme_stylebox_override("hover", _style(Color("20265a"), COLOR_CYAN, 11, 2))
	continue_button.add_theme_stylebox_override("pressed", _style(Color("153b3f"), COLOR_GREEN, 11, 2))
	continue_button.pressed.connect(_continue_story)
	details_container.add_child(continue_button)

func _connect_story() -> void:
	var director := get_node_or_null("/root/LegendarySlice")
	if director == null:
		return
	for signal_name in ["slice_started", "slice_completed"]:
		if director.has_signal(signal_name):
			var callback := Callable(self, "_on_story_snapshot")
			if not director.is_connected(signal_name, callback):
				director.connect(signal_name, callback)
	if director.has_signal("beat_changed"):
		var beat_callback := Callable(self, "_on_beat_changed")
		if not director.is_connected("beat_changed", beat_callback):
			director.connect("beat_changed", beat_callback)

func _on_story_snapshot(_snapshot: Dictionary) -> void:
	call_deferred("_refresh")

func _on_beat_changed(_previous_index: int, _current_index: int, _beat: Dictionary) -> void:
	call_deferred("_refresh")

func _refresh() -> void:
	var director := get_node_or_null("/root/LegendarySlice")
	if director == null or not director.has_method("get_snapshot"):
		panel.visible = false
		return
	var snapshot: Dictionary = director.get_snapshot()
	var active := bool(snapshot.get("active", false))
	var completed := bool(snapshot.get("completed", false))
	var events: Dictionary = snapshot.get("events", {}) as Dictionary
	panel.visible = active or completed or not events.has("slice_started")
	var beat: Dictionary = snapshot.get("current_beat", {}) as Dictionary
	var beat_id := str(beat.get("id", "signal_in_darkness"))
	var beat_index := int(snapshot.get("current_beat_index", 0))
	var total := maxi(int(director.BEATS.size()), 1)
	chapter_label.text = "LEGENDARY SLICE • KAPITEL %d" % mini(beat_index + 1, total)
	progress_label.text = "%d/%d" % [total if completed else mini(beat_index + 1, total), total]
	progress_bar.value = float(snapshot.get("progress", 0.0))
	title_label.text = "Gemeinsamer Bogen abgeschlossen" if completed else str(beat.get("title", "Signal im Dunkeln"))
	objective_label.text = str(snapshot.get("objective", "Beantworte das erste Signal."))
	continue_button.text = _continue_label(beat_id, active, completed)
	continue_button.disabled = completed
	if beat_id != _last_beat_id:
		_last_beat_id = beat_id
		_animate_beat_change()
	_apply_collapsed_state()

func _continue_label(beat_id: String, active: bool, completed: bool) -> String:
	if completed:
		return "BOGEN ABGESCHLOSSEN"
	if not active or beat_id == "signal_in_darkness":
		return "ERSTEN KONTAKT STARTEN"
	match beat_id:
		"first_choice":
			return "PFLEGEAKTION WÄHLEN"
		"shared_rhythm":
			return "RESONANZRHYTHMUS STARTEN"
		"language_becomes_meaning":
			return "SIGNAL ÜBERSETZEN"
		"patterns_become_knowledge":
			return "MUSTERFOKUS STARTEN"
		"prismatic_rooftops":
			return "DACHGÄRTEN BETRETEN"
		"promise_of_growth":
			return "ENTWICKLUNG VERSPRECHEN"
		_:
			return "FORTSETZEN"

func _continue_story() -> void:
	var director := get_node_or_null("/root/LegendarySlice")
	if director == null:
		return
	var beat: Dictionary = director.get_current_beat()
	var beat_id := str(beat.get("id", "signal_in_darkness"))
	match beat_id:
		"signal_in_darkness":
			var onboarding := get_node_or_null("/root/LegendaryOnboarding")
			if onboarding != null and onboarding.has_method("open_onboarding"):
				onboarding.call("open_onboarding", true)
		"first_choice":
			objective_label.text = "Nutze Füttern oder Pflegen. Deine Handlung zählt, nicht ein Menüklick."
			_pulse_panel(COLOR_GREEN)
		"shared_rhythm":
			_open_activity("resonance_rhythm")
		"language_becomes_meaning":
			_open_activity("signal_translation")
		"patterns_become_knowledge":
			_open_activity("pattern_focus")
		"prismatic_rooftops":
			var exploration := get_node_or_null("/root/ExplorationOverlay")
			if exploration != null and exploration.has_method("open_expedition"):
				exploration.call("open_expedition")
		"promise_of_growth":
			var promise := get_node_or_null("/root/LegendaryPromise")
			if promise != null and promise.has_method("open_promise"):
				promise.call("open_promise")
	var audio := get_node_or_null("/root/OmniAudio")
	if audio != null and audio.has_method("play_navigation"):
		audio.call("play_navigation")

func _open_activity(activity_id: String) -> void:
	var activities := get_node_or_null("/root/LegendaryActivities")
	if activities != null and activities.has_method("open_activity"):
		activities.call("open_activity", activity_id)

func _toggle_collapsed() -> void:
	_collapsed = not _collapsed
	collapse_button.text = "+" if _collapsed else "–"
	_apply_collapsed_state()

func _apply_collapsed_state() -> void:
	if panel == null or details_container == null:
		return
	details_container.visible = not _collapsed
	var top_value := MOBILE_TOP if _compact else DESKTOP_TOP
	var height_value := MOBILE_HEIGHT_COLLAPSED if _compact and _collapsed else MOBILE_HEIGHT_EXPANDED if _compact else DESKTOP_HEIGHT_COLLAPSED if _collapsed else DESKTOP_HEIGHT_EXPANDED
	panel.offset_top = top_value
	panel.offset_bottom = top_value + height_value

func _apply_layout() -> void:
	if panel == null:
		return
	var design_size := get_viewport().get_visible_rect().size
	var physical_size := Vector2(get_tree().root.size)
	var effective_width := minf(design_size.x, physical_size.x) if physical_size.x > 0.0 else design_size.x
	_compact = effective_width < 760.0
	panel.custom_minimum_size = Vector2.ZERO
	panel.anchor_top = 0.0
	panel.anchor_bottom = 0.0
	if _compact:
		panel.anchor_left = 0.0
		panel.anchor_right = 1.0
		panel.offset_left = 10.0
		panel.offset_right = -10.0
		title_label.add_theme_font_size_override("font_size", 15)
		objective_label.add_theme_font_size_override("font_size", 11)
		continue_button.add_theme_font_size_override("font_size", 11)
	else:
		panel.anchor_left = 1.0
		panel.anchor_right = 1.0
		panel.offset_left = -420.0
		panel.offset_right = -20.0
		title_label.add_theme_font_size_override("font_size", 18)
		objective_label.add_theme_font_size_override("font_size", 13)
		continue_button.add_theme_font_size_override("font_size", 12)
	_apply_collapsed_state()

func get_hud_snapshot() -> Dictionary:
	return {
		"visible": panel != null and panel.visible,
		"collapsed": _collapsed,
		"compact": _compact,
		"canvas_layer": layer,
		"modal_layer_ceiling": MODAL_LAYER_CEILING,
		"panel_position": panel.position if panel != null else Vector2.ZERO,
		"panel_size": panel.size if panel != null else Vector2.ZERO,
		"beat_id": _last_beat_id,
		"title": title_label.text if title_label != null else "",
		"objective": objective_label.text if objective_label != null else "",
		"progress": progress_bar.value if progress_bar != null else 0.0,
		"continue_label": continue_button.text if continue_button != null else ""
	}

func _animate_beat_change() -> void:
	if panel == null:
		return
	panel.modulate = Color(0.72, 0.90, 1.0, 0.68)
	panel.scale = Vector2(0.985, 0.985)
	panel.pivot_offset = panel.size * 0.5
	var tween := create_tween().set_parallel(true).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(panel, "modulate", Color.WHITE, 0.28)
	tween.tween_property(panel, "scale", Vector2.ONE, 0.32)

func _pulse_panel(accent: Color) -> void:
	if panel == null:
		return
	panel.add_theme_stylebox_override("panel", _style(COLOR_PANEL, accent, 18, 2))
	var timer := get_tree().create_timer(0.65, true, false, true)
	timer.timeout.connect(func() -> void:
		if panel != null:
			panel.add_theme_stylebox_override("panel", _style(COLOR_PANEL, Color(COLOR_CYAN, 0.62), 18, 1))
	)

func _style(fill: Color, border: Color, radius: int, width: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(width)
	style.set_corner_radius_all(radius)
	style.content_margin_left = 12.0
	style.content_margin_right = 12.0
	style.content_margin_top = 8.0
	style.content_margin_bottom = 8.0
	return style

func _bar_style(fill: Color, radius: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.set_corner_radius_all(radius)
	return style
