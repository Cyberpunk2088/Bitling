extends CanvasLayer

## Responsive learning overlay opened by the existing LERNEN interaction.
## Uses only standard Controls for Xogot compatibility.

const COLOR_BACKDROP := Color(0.01, 0.02, 0.05, 0.88)
const COLOR_PANEL := Color("111a2d")
const COLOR_BORDER := Color("6de7ff")
const COLOR_TEXT := Color("f4f7ff")
const COLOR_MUTED := Color("aab4cf")
const COLOR_SUCCESS := Color("70e3a0")
const COLOR_ACCENT := Color("b783ff")

var backdrop: ColorRect
var panel: PanelContainer
var question_label: Label
var progress_label: Label
var feedback_label: Label
var answer_buttons: Array[Button] = []
var close_button: Button
var _current_challenge: Dictionary = {}
var _resolved: bool = false

func _ready() -> void:
	layer = 20
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
	panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(320, 420)
	panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	panel.add_theme_stylebox_override("panel", _panel_style())
	center.add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 16)
	panel.add_child(column)
	var header := HBoxContainer.new()
	column.add_child(header)
	var title := Label.new()
	title.text = "MUSTERLABOR"
	title.add_theme_color_override("font_color", COLOR_TEXT)
	title.add_theme_font_size_override("font_size", 22)
	header.add_child(title)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(spacer)
	close_button = Button.new()
	close_button.text = "×"
	close_button.tooltip_text = "Lernrunde schließen"
	close_button.custom_minimum_size = Vector2(48, 48)
	close_button.pressed.connect(_close_overlay)
	header.add_child(close_button)
	progress_label = Label.new()
	progress_label.add_theme_color_override("font_color", COLOR_MUTED)
	progress_label.add_theme_font_size_override("font_size", 14)
	column.add_child(progress_label)
	question_label = Label.new()
	question_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	question_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	question_label.custom_minimum_size = Vector2(280, 100)
	question_label.add_theme_color_override("font_color", COLOR_TEXT)
	question_label.add_theme_font_size_override("font_size", 20)
	column.add_child(question_label)
	var answers := VBoxContainer.new()
	answers.add_theme_constant_override("separation", 10)
	column.add_child(answers)
	for index in range(3):
		var button := Button.new()
		button.custom_minimum_size = Vector2(280, 58)
		button.add_theme_font_size_override("font_size", 18)
		button.add_theme_stylebox_override("normal", _answer_style(Color("17223a"), COLOR_BORDER))
		button.add_theme_stylebox_override("hover", _answer_style(Color("1e2e4b"), COLOR_BORDER))
		button.add_theme_stylebox_override("pressed", _answer_style(Color("263657"), COLOR_ACCENT))
		button.pressed.connect(_on_answer_pressed.bind(index))
		answers.add_child(button)
		answer_buttons.append(button)
	feedback_label = Label.new()
	feedback_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	feedback_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	feedback_label.add_theme_color_override("font_color", COLOR_MUTED)
	feedback_label.add_theme_font_size_override("font_size", 15)
	column.add_child(feedback_label)

func open_challenge() -> void:
	if backdrop.visible:
		return
	var learning := get_node_or_null("/root/AdaptiveLearning")
	if learning == null:
		return
	_current_challenge = learning.create_challenge("logic")
	_resolved = false
	var answers: Array = _current_challenge.get("answers", [])
	if answers.size() != answer_buttons.size():
		return
	question_label.text = str(_current_challenge.get("prompt", "Welche Antwort passt?"))
	var difficulty := int(_current_challenge.get("difficulty", 1))
	var rating := float(_current_challenge.get("rating_before", 20.0))
	progress_label.text = "Schwierigkeit %d/10 • Logikwert %d" % [difficulty, int(round(rating))]
	feedback_label.text = "Nimm dir Zeit. Ein Fehler kostet keinen Fortschritt."
	feedback_label.add_theme_color_override("font_color", COLOR_MUTED)
	for index in range(answer_buttons.size()):
		answer_buttons[index].text = str(answers[index])
		answer_buttons[index].disabled = false
	backdrop.visible = true
	answer_buttons[0].grab_focus()

func _on_answer_pressed(index: int) -> void:
	if _resolved:
		return
	var learning := get_node_or_null("/root/AdaptiveLearning")
	if learning == null:
		return
	var result: Dictionary = learning.submit_answer(index)
	if not bool(result.get("accepted", false)):
		feedback_label.text = "Die Antwort konnte nicht ausgewertet werden."
		return
	_resolved = true
	for button in answer_buttons:
		button.disabled = true
	var success := bool(result.get("success", false))
	var explanation := str(result.get("explanation", ""))
	if success:
		feedback_label.add_theme_color_override("font_color", COLOR_SUCCESS)
		feedback_label.text = "Richtig. %s  +%d XP" % [explanation, int(result.get("xp_reward", 0))]
	else:
		feedback_label.add_theme_color_override("font_color", COLOR_ACCENT)
		feedback_label.text = "Fast. Die passende Antwort ist %s. %s" % [str(result.get("correct_answer", "")), explanation]
	_apply_result(result)
	await get_tree().create_timer(1.6).timeout
	_close_overlay()

func _apply_result(result: Dictionary) -> void:
	var state := get_node_or_null("/root/GameState")
	if state == null:
		return
	var success := bool(result.get("success", false))
	var effects := {
		"energy": -4.0,
		"happiness": 5.0 if success else 2.0,
		"curiosity": 12.0 if success else 5.0,
		"quest_event": "discovery_completed"
	}
	var tags: Array[String] = ["learn", "growth", "challenge_result"]
	state.perform_interaction("learning_result", effects, int(result.get("xp_reward", 0)), tags)
	var brain := get_node_or_null("/root/CompanionBrain")
	if brain != null:
		brain.observe_interaction("learn", 1.0, {"success": success})
	var evolution := get_node_or_null("/root/EvolutionService")
	if evolution != null:
		evolution.evaluate_runtime()
	state.save_game_state()

func _on_interaction_completed(interaction_id: String, _tags: Array[String]) -> void:
	if interaction_id == "learn":
		call_deferred("open_challenge")

func _close_overlay() -> void:
	backdrop.visible = false
	_current_challenge.clear()
	_resolved = false

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

func _answer_style(background: Color, border: Color) -> StyleBoxFlat:
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
