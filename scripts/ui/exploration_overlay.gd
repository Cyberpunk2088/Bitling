extends CanvasLayer

## Three-stage choice expedition opened by the SPIELEN interaction.
## Completion also advances the Legendary Slice roof-garden story beat.

const COLOR_BACKDROP := Color(0.01, 0.02, 0.05, 0.88)
const COLOR_PANEL := Color("111a2d")
const COLOR_BORDER := Color("b783ff")
const COLOR_TEXT := Color("f4f7ff")
const COLOR_MUTED := Color("aab4cf")
const COLOR_ACCENT := Color("6de7ff")

var backdrop: ColorRect
var stage_label: Label
var prompt_label: Label
var feedback_label: Label
var choice_buttons: Array[Button] = []
var _resolving: bool = false

func _ready() -> void:
	layer = 21
	_build_ui()
	backdrop.visible = false
	var event_bus := get_node_or_null("/root/EventBus")
	if event_bus != null:
		event_bus.interaction_completed.connect(_on_interaction_completed)

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
	column.add_theme_constant_override("separation", 16)
	panel.add_child(column)
	var header := HBoxContainer.new()
	column.add_child(header)
	var title := Label.new()
	title.text = "PRISMATISCHE DACHGÄRTEN"
	title.add_theme_color_override("font_color", COLOR_TEXT)
	title.add_theme_font_size_override("font_size", 22)
	header.add_child(title)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(spacer)
	var close_button := Button.new()
	close_button.text = "×"
	close_button.tooltip_text = "Expedition pausieren"
	close_button.custom_minimum_size = Vector2(48, 48)
	close_button.pressed.connect(_close)
	header.add_child(close_button)
	stage_label = Label.new()
	stage_label.add_theme_color_override("font_color", COLOR_MUTED)
	stage_label.add_theme_font_size_override("font_size", 14)
	column.add_child(stage_label)
	prompt_label = Label.new()
	prompt_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt_label.custom_minimum_size = Vector2(290, 120)
	prompt_label.add_theme_color_override("font_color", COLOR_TEXT)
	prompt_label.add_theme_font_size_override("font_size", 19)
	column.add_child(prompt_label)
	var choices := VBoxContainer.new()
	choices.add_theme_constant_override("separation", 12)
	column.add_child(choices)
	for index in range(2):
		var button := Button.new()
		button.custom_minimum_size = Vector2(290, 68)
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		button.add_theme_font_size_override("font_size", 16)
		button.add_theme_stylebox_override("normal", _choice_style(Color("17223a"), COLOR_BORDER))
		button.add_theme_stylebox_override("hover", _choice_style(Color("1e2e4b"), COLOR_ACCENT))
		button.add_theme_stylebox_override("pressed", _choice_style(Color("263657"), COLOR_ACCENT))
		button.pressed.connect(_on_choice_pressed.bind(index))
		choices.add_child(button)
		choice_buttons.append(button)
	feedback_label = Label.new()
	feedback_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	feedback_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	feedback_label.add_theme_color_override("font_color", COLOR_ACCENT)
	feedback_label.add_theme_font_size_override("font_size", 15)
	column.add_child(feedback_label)

func open_expedition() -> void:
	if backdrop.visible:
		return
	var service := get_node_or_null("/root/ExplorationService")
	if service == null:
		return
	var stage: Dictionary = service.get_current_stage()
	if stage.is_empty():
		stage = service.start_expedition()
	backdrop.visible = true
	_show_stage(stage)

func _show_stage(stage: Dictionary) -> void:
	if stage.is_empty():
		_close()
		return
	_resolving = false
	stage_label.text = "Etappe %d von %d" % [int(stage.get("stage_number", 1)), int(stage.get("stage_total", 1))]
	prompt_label.text = str(stage.get("prompt", "Ein unbekanntes Signal erscheint."))
	feedback_label.text = "Wähle den Weg, der zu deinem BITLING passt."
	var options: Array = stage.get("choices", [])
	for index in range(choice_buttons.size()):
		choice_buttons[index].disabled = index >= options.size()
		choice_buttons[index].visible = index < options.size()
		if index < options.size():
			choice_buttons[index].text = str(options[index].get("label", "Wählen"))
	choice_buttons[0].grab_focus()

func _on_choice_pressed(index: int) -> void:
	if _resolving:
		return
	_resolving = true
	for button in choice_buttons:
		button.disabled = true
	var service := get_node_or_null("/root/ExplorationService")
	if service == null:
		_close()
		return
	var result: Dictionary = service.choose(index)
	if not bool(result.get("accepted", false)):
		feedback_label.text = "Diese Entscheidung konnte nicht angewendet werden."
		return
	feedback_label.text = "%s  +%d XP" % [str(result.get("result", "")), int(result.get("xp_reward", 0))]
	var state := get_node_or_null("/root/GameState")
	if state != null:
		state.save_game_state()
	await get_tree().create_timer(1.5).timeout
	if bool(result.get("completed", false)):
		var summary: Dictionary = result.get("summary", {})
		feedback_label.text = "Dachgärten erkundet • %d XP gesammelt" % int(summary.get("total_xp", 0))
		_record_legendary_completion(summary)
		await get_tree().create_timer(1.2).timeout
		_close()
	else:
		_show_stage(result.get("next_stage", {}))

func _record_legendary_completion(summary: Dictionary) -> void:
	var director := get_node_or_null("/root/LegendarySlice")
	if director == null or not director.has_method("record_activity"):
		return
	var score := clampf(float(summary.get("total_xp", 0)) / 55.0, 0.55, 1.0)
	director.record_activity("prism_rooftops", {
		"accepted": true,
		"success": true,
		"score": score,
		"xp": int(summary.get("total_xp", 0))
	})

func _on_interaction_completed(interaction_id: String, _tags: Array[String]) -> void:
	if interaction_id == "play":
		call_deferred("open_expedition")

func _close() -> void:
	backdrop.visible = false
	_resolving = false

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
