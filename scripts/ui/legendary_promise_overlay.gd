extends Node

## Final decision of the Legendary Vertical Slice.

const OPTIONS: Array[Dictionary] = [
	{"id": "wissen", "title": "WISSEN", "text": "Wir wollen Zusammenhänge verstehen und neue Muster sichtbar machen."},
	{"id": "mut", "title": "MUT", "text": "Wir wollen Unsicherheit gemeinsam aushalten und neue Wege betreten."},
	{"id": "fürsorge", "title": "FÜRSORGE", "text": "Wir wollen aufmerksam füreinander und für andere Wesen handeln."},
	{"id": "kreativität", "title": "KREATIVITÄT", "text": "Wir wollen aus Fehlern, Ideen und Experimenten etwas Eigenes erschaffen."}
]

const COLOR_BACKDROP := Color(0.005, 0.008, 0.025, 0.95)
const COLOR_PANEL := Color("091126")
const COLOR_PANEL_ALT := Color("111a35")
const COLOR_TEXT := Color("f4f7ff")
const COLOR_MUTED := Color("9ba8c7")
const COLOR_CYAN := Color("42e8ff")
const COLOR_VIOLET := Color("a855f7")
const COLOR_MAGENTA := Color("f044d4")
const COLOR_GREEN := Color("64e6a2")

var layer: CanvasLayer
var selected_focus := "wissen"
var option_buttons: Dictionary = {}
var description_label: Label

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var director := get_node_or_null("/root/LegendarySlice")
	if director != null and director.has_signal("beat_changed"):
		var callback := Callable(self, "_on_beat_changed")
		if not director.is_connected("beat_changed", callback):
			director.connect("beat_changed", callback)
	call_deferred("_open_if_current")

func _open_if_current() -> void:
	var director := get_node_or_null("/root/LegendarySlice")
	if director == null or not director.has_method("get_current_beat"):
		return
	var beat: Dictionary = director.get_current_beat()
	if str(beat.get("expected_event", "")) == "evolution_promise" and not bool(director.get("completed")):
		open_promise()

func _on_beat_changed(_previous_index: int, _current_index: int, beat: Dictionary) -> void:
	if str(beat.get("expected_event", "")) == "evolution_promise":
		call_deferred("open_promise")

func open_promise() -> void:
	if layer != null:
		return
	_build_ui()

func _build_ui() -> void:
	layer = CanvasLayer.new()
	layer.name = "LegendaryPromiseLayer"
	layer.layer = 230
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
	panel.custom_minimum_size = Vector2(330.0, 560.0)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", _style(COLOR_PANEL, COLOR_VIOLET, 26, 2))
	center.add_child(panel)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 14)
	panel.add_child(column)

	var eyebrow := Label.new()
	eyebrow.text = "ENTWICKLUNGSVERSPRECHEN"
	eyebrow.add_theme_color_override("font_color", COLOR_CYAN)
	eyebrow.add_theme_font_size_override("font_size", 13)
	column.add_child(eyebrow)

	var title := Label.new()
	title.text = "Wofür wollt ihr gemeinsam wachsen?"
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.add_theme_color_override("font_color", COLOR_TEXT)
	title.add_theme_font_size_override("font_size", 28)
	column.add_child(title)

	var intro := Label.new()
	intro.text = "Diese Wahl sperrt keine Entwicklung. Sie setzt einen sichtbaren Schwerpunkt für eure nächsten Erinnerungen, Aktivitäten und Evolutionsprognosen."
	intro.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	intro.add_theme_color_override("font_color", COLOR_MUTED)
	intro.add_theme_font_size_override("font_size", 15)
	column.add_child(intro)

	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	column.add_child(grid)
	for option in OPTIONS:
		var option_id := str(option.get("id", "wissen"))
		var button := Button.new()
		button.text = str(option.get("title", option_id.to_upper()))
		button.custom_minimum_size = Vector2(140.0, 58.0)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.add_theme_color_override("font_color", COLOR_TEXT)
		button.add_theme_font_size_override("font_size", 14)
		button.pressed.connect(_select_focus.bind(option_id))
		grid.add_child(button)
		option_buttons[option_id] = button

	description_label = Label.new()
	description_label.custom_minimum_size = Vector2(0.0, 90.0)
	description_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	description_label.add_theme_color_override("font_color", COLOR_TEXT)
	description_label.add_theme_font_size_override("font_size", 16)
	description_label.add_theme_stylebox_override("normal", _style(COLOR_PANEL_ALT, Color(COLOR_CYAN, 0.45), 16, 1))
	column.add_child(description_label)

	var confirm := Button.new()
	confirm.text = "VERSPRECHEN SPEICHERN"
	confirm.custom_minimum_size = Vector2(0.0, 68.0)
	confirm.add_theme_color_override("font_color", COLOR_TEXT)
	confirm.add_theme_font_size_override("font_size", 18)
	confirm.add_theme_stylebox_override("normal", _style(Color("20144a"), COLOR_MAGENTA, 18, 2))
	confirm.add_theme_stylebox_override("hover", _style(Color("27205c"), COLOR_CYAN, 18, 2))
	confirm.add_theme_stylebox_override("pressed", _style(Color("173a3a"), COLOR_GREEN, 18, 2))
	confirm.pressed.connect(_confirm)
	column.add_child(confirm)

	if get_viewport().get_visible_rect().size.x < 760.0:
		grid.columns = 1
		panel.custom_minimum_size = Vector2(330.0, 620.0)
	else:
		panel.custom_minimum_size = Vector2(680.0, 560.0)
	_select_focus(selected_focus)

func _select_focus(focus: String) -> void:
	selected_focus = focus if option_buttons.has(focus) else "wissen"
	for key in option_buttons.keys():
		var button := option_buttons[key] as Button
		var active := str(key) == selected_focus
		button.add_theme_stylebox_override("normal", _style(Color("1d2141") if active else COLOR_PANEL_ALT, COLOR_GREEN if active else Color(COLOR_VIOLET, 0.55), 14, 2 if active else 1))
	for option in OPTIONS:
		if str(option.get("id", "")) == selected_focus:
			description_label.text = str(option.get("text", "Gemeinsam wachsen."))
			break

func _confirm() -> void:
	var director := get_node_or_null("/root/LegendarySlice")
	if director != null and director.has_method("choose_evolution_promise"):
		director.choose_evolution_promise(selected_focus)
	var audio := get_node_or_null("/root/OmniAudio")
	if audio != null:
		if audio.has_method("play_action"):
			audio.play_action("level", 1.25)
		if audio.has_method("play_voice_chirp"):
			audio.play_voice_chirp("Dieses Versprechen trage ich in meine nächste Form.", "ECSTATIC")
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
