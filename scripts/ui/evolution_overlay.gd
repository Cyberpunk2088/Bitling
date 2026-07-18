extends CanvasLayer

## Presents newly available original BITLING forms as explicit player choices.

const COLOR_BACKDROP := Color(0.01, 0.02, 0.05, 0.9)
const COLOR_PANEL := Color("10182a")
const COLOR_BORDER := Color("b783ff")
const COLOR_TEXT := Color("f4f7ff")
const COLOR_MUTED := Color("aab4cf")
const COLOR_ACCENT := Color("6de7ff")

var backdrop: ColorRect
var choices: VBoxContainer
var description_label: Label
var close_button: Button
var _pending_forms: Array[String] = []

func _ready() -> void:
	layer = 30
	_build_ui()
	backdrop.visible = false
	var evolution := get_node_or_null("/root/EvolutionService")
	if evolution != null:
		evolution.form_available.connect(_on_form_available)
		evolution.evolved.connect(_on_evolved)
		_pending_forms = evolution.evaluate_runtime()
		if not _pending_forms.is_empty():
			call_deferred("_show_choices")

func _build_ui() -> void:
	backdrop = ColorRect.new()
	backdrop.color = COLOR_BACKDROP
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(backdrop)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(330, 430)
	panel.add_theme_stylebox_override("panel", _panel_style())
	center.add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 14)
	panel.add_child(column)
	var header := HBoxContainer.new()
	column.add_child(header)
	var title := Label.new()
	title.text = "NEUE FORM MÖGLICH"
	title.add_theme_color_override("font_color", COLOR_TEXT)
	title.add_theme_font_size_override("font_size", 22)
	header.add_child(title)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(spacer)
	close_button = Button.new()
	close_button.text = "×"
	close_button.tooltip_text = "Später entscheiden"
	close_button.custom_minimum_size = Vector2(48, 48)
	close_button.pressed.connect(_close)
	header.add_child(close_button)
	var intro := Label.new()
	intro.text = "Deine Entscheidungen haben neue Entwicklungswege geöffnet. Keine Form ist objektiv besser – sie verändert Fähigkeiten und Ausdruck."
	intro.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	intro.add_theme_color_override("font_color", COLOR_MUTED)
	intro.add_theme_font_size_override("font_size", 15)
	column.add_child(intro)
	choices = VBoxContainer.new()
	choices.add_theme_constant_override("separation", 10)
	column.add_child(choices)
	description_label = Label.new()
	description_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	description_label.add_theme_color_override("font_color", COLOR_ACCENT)
	description_label.add_theme_font_size_override("font_size", 15)
	column.add_child(description_label)

func _on_form_available(form_id: String) -> void:
	if not _pending_forms.has(form_id):
		_pending_forms.append(form_id)
	call_deferred("_show_choices")

func _show_choices() -> void:
	var evolution := get_node_or_null("/root/EvolutionService")
	if evolution == null:
		return
	_pending_forms = evolution.evaluate_runtime()
	if _pending_forms.is_empty():
		return
	for child in choices.get_children():
		child.queue_free()
	for form_id in _pending_forms:
		var form: Dictionary = evolution.get_form(form_id)
		var button := Button.new()
		button.text = "%s  •  ab Level %d" % [str(form.get("name", form_id)), int(form.get("level", 1))]
		button.tooltip_text = str(form.get("description", ""))
		button.custom_minimum_size = Vector2(290, 58)
		button.add_theme_font_size_override("font_size", 17)
		button.add_theme_stylebox_override("normal", _choice_style(Color("17223a"), COLOR_BORDER))
		button.add_theme_stylebox_override("hover", _choice_style(Color("1e2e4b"), COLOR_ACCENT))
		button.pressed.connect(_select_form.bind(form_id))
		button.mouse_entered.connect(_preview_form.bind(form_id))
		choices.add_child(button)
	_preview_form(_pending_forms[0])
	backdrop.visible = true

func _preview_form(form_id: String) -> void:
	var evolution := get_node_or_null("/root/EvolutionService")
	if evolution == null:
		return
	var form: Dictionary = evolution.get_form(form_id)
	description_label.text = str(form.get("description", ""))

func _select_form(form_id: String) -> void:
	var evolution := get_node_or_null("/root/EvolutionService")
	if evolution == null or not evolution.select_evolution(form_id):
		return
	var form: Dictionary = evolution.get_current_form()
	var state := get_node_or_null("/root/GameState")
	if state != null:
		state.add_memory("evolution_%s" % form_id, "BITLING developed into %s." % str(form.get("name", form_id)))
		state.save_game_state()
	_close()

func _on_evolved(_old_form: String, _new_form: String) -> void:
	_pending_forms.clear()

func _close() -> void:
	backdrop.visible = false

func _panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = COLOR_PANEL
	style.border_color = COLOR_BORDER
	style.set_border_width_all(2)
	style.set_corner_radius_all(24)
	style.content_margin_left = 22.0
	style.content_margin_right = 22.0
	style.content_margin_top = 20.0
	style.content_margin_bottom = 20.0
	return style

func _choice_style(background: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(14)
	style.content_margin_left = 14.0
	style.content_margin_right = 14.0
	style.content_margin_top = 12.0
	style.content_margin_bottom = 12.0
	return style
