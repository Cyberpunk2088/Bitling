extends Node

## First-contact onboarding for the Legendary Vertical Slice.
## It asks only for a local Bitling name and an upbringing tone.

signal onboarding_opened
signal onboarding_completed(snapshot: Dictionary)

const COLOR_BACKDROP := Color(0.005, 0.008, 0.025, 0.97)
const COLOR_PANEL := Color("091126")
const COLOR_PANEL_ALT := Color("111a35")
const COLOR_TEXT := Color("f4f7ff")
const COLOR_MUTED := Color("9ba8c7")
const COLOR_CYAN := Color("42e8ff")
const COLOR_VIOLET := Color("a855f7")
const COLOR_MAGENTA := Color("f044d4")
const COLOR_GREEN := Color("64e6a2")

const CARE_STYLES: Array[Dictionary] = [
	{"id": "ermutigend", "title": "ERMUTIGEND", "description": "Mut wächst durch Unterstützung und gemeinsames Ausprobieren."},
	{"id": "routiniert", "title": "ROUTINIERT", "description": "Sicherheit wächst durch klare Abläufe und verlässliche Gewohnheiten."},
	{"id": "neugierig", "title": "NEUGIERIG", "description": "Entwicklung wächst durch Fragen, Experimente und Entdeckungen."},
	{"id": "ruhig", "title": "RUHIG", "description": "Vertrauen wächst durch Geduld, Beobachtung und sanfte Grenzen."}
]

var layer: CanvasLayer
var name_input: LineEdit
var selected_style := "ermutigend"
var style_buttons: Dictionary = {}
var style_description: Label
var confirm_button: Button
var status_label: Label

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	call_deferred("_open_if_needed")

func _open_if_needed() -> void:
	var state := get_node_or_null("/root/GameState")
	if state == null:
		return
	if bool(state.story_flags.get("legendary_slice_started", false)):
		return
	open_onboarding()

func open_onboarding(force: bool = false) -> void:
	if layer != null:
		return
	var state := get_node_or_null("/root/GameState")
	if not force and state != null and bool(state.story_flags.get("legendary_slice_started", false)):
		return
	_build_ui()
	onboarding_opened.emit()

func _build_ui() -> void:
	layer = CanvasLayer.new()
	layer.name = "LegendaryOnboardingLayer"
	layer.layer = 240
	add_child(layer)

	var backdrop := ColorRect.new()
	backdrop.color = COLOR_BACKDROP
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(backdrop)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 18)
	margin.add_theme_constant_override("margin_right", 18)
	margin.add_theme_constant_override("margin_top", 24)
	margin.add_theme_constant_override("margin_bottom", 24)
	layer.add_child(margin)

	var center := CenterContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(330.0, 620.0)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", _style(COLOR_PANEL, COLOR_VIOLET, 26, 2))
	center.add_child(panel)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 15)
	panel.add_child(column)

	var eyebrow := Label.new()
	eyebrow.text = "ERSTER KONTAKT"
	eyebrow.add_theme_color_override("font_color", COLOR_CYAN)
	eyebrow.add_theme_font_size_override("font_size", 13)
	column.add_child(eyebrow)

	var title := Label.new()
	title.text = "Ein Signal antwortet dir."
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.add_theme_color_override("font_color", COLOR_TEXT)
	title.add_theme_font_size_override("font_size", 30)
	column.add_child(title)

	var intro := Label.new()
	intro.text = "Noch kennt dieses Wesen weder seinen Namen noch eure gemeinsame Art, mit Fehlern und Entdeckungen umzugehen. Deine erste Entscheidung bestimmt keine perfekte Route – sie eröffnet eine Beziehung."
	intro.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	intro.add_theme_color_override("font_color", COLOR_MUTED)
	intro.add_theme_font_size_override("font_size", 16)
	column.add_child(intro)

	var name_title := Label.new()
	name_title.text = "Wie möchtest du dein Bitling nennen?"
	name_title.add_theme_color_override("font_color", COLOR_TEXT)
	name_title.add_theme_font_size_override("font_size", 16)
	column.add_child(name_title)

	name_input = LineEdit.new()
	name_input.placeholder_text = "BITLING"
	name_input.max_length = 20
	name_input.custom_minimum_size = Vector2(0.0, 54.0)
	name_input.add_theme_color_override("font_color", COLOR_TEXT)
	name_input.add_theme_color_override("font_placeholder_color", COLOR_MUTED)
	name_input.add_theme_font_size_override("font_size", 18)
	name_input.add_theme_stylebox_override("normal", _style(COLOR_PANEL_ALT, COLOR_CYAN, 15, 1))
	name_input.text_changed.connect(_on_name_changed)
	column.add_child(name_input)

	var style_title := Label.new()
	style_title.text = "Welche Grundhaltung soll eure ersten Schritte prägen?"
	style_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	style_title.add_theme_color_override("font_color", COLOR_TEXT)
	style_title.add_theme_font_size_override("font_size", 16)
	column.add_child(style_title)

	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 9)
	grid.add_theme_constant_override("v_separation", 9)
	column.add_child(grid)
	for style_data in CARE_STYLES:
		var style_id := str(style_data.get("id", "ermutigend"))
		var button := Button.new()
		button.text = str(style_data.get("title", style_id.to_upper()))
		button.custom_minimum_size = Vector2(140.0, 54.0)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.add_theme_color_override("font_color", COLOR_TEXT)
		button.add_theme_font_size_override("font_size", 13)
		button.pressed.connect(_select_style.bind(style_id))
		grid.add_child(button)
		style_buttons[style_id] = button

	style_description = Label.new()
	style_description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	style_description.add_theme_color_override("font_color", COLOR_MUTED)
	style_description.add_theme_font_size_override("font_size", 14)
	column.add_child(style_description)

	confirm_button = Button.new()
	confirm_button.text = "DAS SIGNAL BEANTWORTEN"
	confirm_button.custom_minimum_size = Vector2(0.0, 68.0)
	confirm_button.add_theme_color_override("font_color", COLOR_TEXT)
	confirm_button.add_theme_font_size_override("font_size", 18)
	confirm_button.add_theme_stylebox_override("normal", _style(Color("20144a"), COLOR_MAGENTA, 18, 2))
	confirm_button.add_theme_stylebox_override("hover", _style(Color("27205c"), COLOR_CYAN, 18, 2))
	confirm_button.add_theme_stylebox_override("pressed", _style(Color("172a43"), COLOR_GREEN, 18, 2))
	confirm_button.pressed.connect(_confirm)
	column.add_child(confirm_button)

	status_label = Label.new()
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status_label.add_theme_color_override("font_color", COLOR_CYAN)
	status_label.add_theme_font_size_override("font_size", 14)
	column.add_child(status_label)

	_select_style(selected_style)
	_apply_responsive_layout(panel, grid)
	name_input.grab_focus()

func _apply_responsive_layout(panel: PanelContainer, grid: GridContainer) -> void:
	var width := get_viewport().get_visible_rect().size.x
	if width < 760.0:
		panel.custom_minimum_size = Vector2(330.0, 640.0)
		grid.columns = 1
	else:
		panel.custom_minimum_size = Vector2(700.0, 620.0)
		grid.columns = 2

func _select_style(style_id: String) -> void:
	selected_style = style_id if style_buttons.has(style_id) else "ermutigend"
	for key in style_buttons.keys():
		var button := style_buttons[key] as Button
		var active := str(key) == selected_style
		button.add_theme_stylebox_override("normal", _style(Color("1d2141") if active else COLOR_PANEL_ALT, COLOR_GREEN if active else Color(COLOR_VIOLET, 0.55), 14, 2 if active else 1))
	var style_data := _style_data(selected_style)
	style_description.text = str(style_data.get("description", "Gemeinsam wachsen."))

func _style_data(style_id: String) -> Dictionary:
	for style_data in CARE_STYLES:
		if str(style_data.get("id", "")) == style_id:
			return style_data
	return CARE_STYLES[0]

func _on_name_changed(value: String) -> void:
	confirm_button.disabled = value.strip_edges().length() > 20

func _confirm() -> void:
	confirm_button.disabled = true
	var chosen_name := name_input.text.strip_edges()
	if chosen_name.is_empty():
		chosen_name = "BITLING"
	var state := get_node_or_null("/root/GameState")
	if state != null and state.has_method("hatch"):
		state.hatch()
	var director := get_node_or_null("/root/LegendarySlice")
	var snapshot: Dictionary = {}
	if director != null and director.has_method("start_slice"):
		snapshot = director.start_slice(chosen_name, selected_style)
	var audio := get_node_or_null("/root/OmniAudio")
	if audio != null:
		if audio.has_method("play_action"):
			audio.play_action("level", 1.0)
		if audio.has_method("play_voice_chirp"):
			audio.play_voice_chirp("Ich bin da. Gemeinsam finden wir heraus, wer ich werde.", "ECSTATIC")
	status_label.text = "%s hat geantwortet. Eure erste Erinnerung wurde gespeichert." % chosen_name
	onboarding_completed.emit(snapshot)
	await get_tree().create_timer(1.1, true, false, true).timeout
	_close()

func _close() -> void:
	if layer != null:
		layer.queue_free()
	layer = null

func _style(fill: Color, border: Color, radius: int, width: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(width)
	style.set_corner_radius_all(radius)
	style.content_margin_left = 18.0
	style.content_margin_right = 18.0
	style.content_margin_top = 14.0
	style.content_margin_bottom = 14.0
	return style
