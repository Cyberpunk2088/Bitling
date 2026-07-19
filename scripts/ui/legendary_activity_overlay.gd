extends Node

## Three self-contained activities for the Legendary Vertical Slice.
## Each activity owns input and presentation, while GameState owns rewards.

signal activity_opened(activity_id: String)
signal activity_finished(activity_id: String, result: Dictionary)

const COLOR_BACKDROP := Color(0.01, 0.015, 0.04, 0.94)
const COLOR_PANEL := Color("0b1024")
const COLOR_PANEL_ALT := Color("121a35")
const COLOR_TEXT := Color("f4f7ff")
const COLOR_MUTED := Color("9ba8c7")
const COLOR_CYAN := Color("42e8ff")
const COLOR_VIOLET := Color("a855f7")
const COLOR_MAGENTA := Color("f044d4")
const COLOR_GREEN := Color("64e6a2")
const COLOR_YELLOW := Color("ffc85a")
const COLOR_RED := Color("ff6d8e")

const PATTERN_SYMBOLS := ["◇", "△", "○", "□"]
const TRANSLATION_QUESTIONS: Array[Dictionary] = [
	{"word": "miri-lu", "meaning": "gemeinsam neugierig sein", "options": ["gemeinsam neugierig sein", "sofort schlafen", "etwas verstecken"]},
	{"word": "plonka", "meaning": "ein lustiger Fehler", "options": ["eine ernste Warnung", "ein lustiger Fehler", "ein Lieblingsessen"]},
	{"word": "sela-vim", "meaning": "ich vertraue dir", "options": ["ich vertraue dir", "ich bin hungrig", "das Signal ist kalt"]},
	{"word": "noru-kai", "meaning": "wir versuchen es noch einmal", "options": ["wir gehen getrennt", "wir versuchen es noch einmal", "wir haben gewonnen"]},
	{"word": "luma-ren", "meaning": "eine neue Idee leuchtet", "options": ["eine neue Idee leuchtet", "die Tür ist geschlossen", "der Regen beginnt"]}
]

var layer: CanvasLayer
var panel: PanelContainer
var title_label: Label
var instruction_label: Label
var prompt_label: Label
var progress_label: Label
var feedback_label: Label
var option_grid: GridContainer
var primary_button: Button

var _activity_id := ""
var _round := 0
var _round_target := 3
var _successes := 0
var _score_total := 0.0
var _locked := false
var _pattern_sequence: Array[int] = []
var _pattern_input: Array[int] = []
var _translation_order: Array[int] = []
var _rhythm_value := 0.0
var _rhythm_direction := 1.0
var _rhythm_attempts := 0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_process(false)

func open_activity(activity_id: String) -> void:
	var normalized := activity_id.strip_edges().to_lower()
	if normalized not in ["pattern_focus", "signal_translation", "resonance_rhythm"]:
		return
	_close_overlay()
	_activity_id = normalized
	_round = 0
	_successes = 0
	_score_total = 0.0
	_locked = false
	_pattern_sequence.clear()
	_pattern_input.clear()
	_rhythm_value = 0.0
	_rhythm_direction = 1.0
	_rhythm_attempts = 0
	_build_overlay()
	activity_opened.emit(_activity_id)
	match _activity_id:
		"pattern_focus":
			_start_pattern_round()
		"signal_translation":
			_prepare_translation_order()
			_start_translation_round()
		"resonance_rhythm":
			_start_rhythm_round()

func simulate_activity(activity_id: String, scores: Array[float]) -> Dictionary:
	var normalized := activity_id.strip_edges().to_lower()
	if normalized not in ["pattern_focus", "signal_translation", "resonance_rhythm"]:
		return {"accepted": false, "success": false, "score": 0.0}
	var total := 0.0
	for value in scores:
		total += clampf(value, 0.0, 1.0)
	var score := total / float(maxi(scores.size(), 1))
	return _commit_result(normalized, score >= 0.55, score, scores.size(), false)

func _process(delta: float) -> void:
	if _activity_id != "resonance_rhythm" or layer == null or _locked:
		return
	_rhythm_value += delta * 72.0 * _rhythm_direction
	if _rhythm_value >= 100.0:
		_rhythm_value = 100.0
		_rhythm_direction = -1.0
	elif _rhythm_value <= 0.0:
		_rhythm_value = 0.0
		_rhythm_direction = 1.0
	prompt_label.text = _rhythm_bar_text(_rhythm_value)

func _build_overlay() -> void:
	layer = CanvasLayer.new()
	layer.name = "LegendaryActivityLayer"
	layer.layer = 220
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

	panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(320.0, 460.0)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", _style(COLOR_PANEL, COLOR_VIOLET, 22, 2))
	center.add_child(panel)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 14)
	panel.add_child(column)

	var top_row := HBoxContainer.new()
	column.add_child(top_row)
	title_label = Label.new()
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_label.add_theme_color_override("font_color", COLOR_TEXT)
	title_label.add_theme_font_size_override("font_size", 24)
	top_row.add_child(title_label)
	var close_button := Button.new()
	close_button.text = "SCHLIESSEN"
	close_button.add_theme_color_override("font_color", COLOR_MUTED)
	close_button.add_theme_stylebox_override("normal", _style(COLOR_PANEL_ALT, Color(COLOR_MUTED, 0.35), 12, 1))
	close_button.pressed.connect(_close_overlay)
	top_row.add_child(close_button)

	instruction_label = Label.new()
	instruction_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	instruction_label.add_theme_color_override("font_color", COLOR_MUTED)
	instruction_label.add_theme_font_size_override("font_size", 15)
	column.add_child(instruction_label)

	var prompt_panel := PanelContainer.new()
	prompt_panel.custom_minimum_size = Vector2(0.0, 128.0)
	prompt_panel.add_theme_stylebox_override("panel", _style(COLOR_PANEL_ALT, COLOR_CYAN, 18, 1))
	prompt_label = Label.new()
	prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	prompt_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	prompt_label.add_theme_color_override("font_color", COLOR_TEXT)
	prompt_label.add_theme_font_size_override("font_size", 28)
	prompt_panel.add_child(prompt_label)
	column.add_child(prompt_panel)

	progress_label = Label.new()
	progress_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	progress_label.add_theme_color_override("font_color", COLOR_CYAN)
	progress_label.add_theme_font_size_override("font_size", 13)
	column.add_child(progress_label)

	option_grid = GridContainer.new()
	option_grid.columns = 2
	option_grid.add_theme_constant_override("h_separation", 10)
	option_grid.add_theme_constant_override("v_separation", 10)
	column.add_child(option_grid)

	primary_button = Button.new()
	primary_button.visible = false
	primary_button.custom_minimum_size = Vector2(0.0, 68.0)
	primary_button.add_theme_color_override("font_color", COLOR_TEXT)
	primary_button.add_theme_font_size_override("font_size", 18)
	primary_button.add_theme_stylebox_override("normal", _style(Color("161441"), COLOR_MAGENTA, 18, 2))
	primary_button.add_theme_stylebox_override("hover", _style(Color("20205a"), COLOR_CYAN, 18, 2))
	primary_button.add_theme_stylebox_override("pressed", _style(Color("27164b"), COLOR_YELLOW, 18, 2))
	primary_button.pressed.connect(_on_primary_pressed)
	column.add_child(primary_button)

	feedback_label = Label.new()
	feedback_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	feedback_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	feedback_label.add_theme_color_override("font_color", COLOR_MUTED)
	feedback_label.add_theme_font_size_override("font_size", 15)
	column.add_child(feedback_label)
	_apply_responsive_size()

func _apply_responsive_size() -> void:
	if panel == null:
		return
	var width := get_viewport().get_visible_rect().size.x
	if width < 760.0:
		panel.custom_minimum_size = Vector2(320.0, 500.0)
		option_grid.columns = 1 if _activity_id == "signal_translation" else 2
	else:
		panel.custom_minimum_size = Vector2(620.0, 500.0)
		option_grid.columns = 2

func _start_pattern_round() -> void:
	_locked = true
	set_process(false)
	_clear_options()
	title_label.text = "MUSTERFOKUS"
	instruction_label.text = "Merke dir die Signalfolge. Danach wiederholst du sie gemeinsam mit deinem Bitling."
	feedback_label.text = "Beobachten …"
	progress_label.text = "Runde %d von %d" % [_round + 1, _round_target]
	_pattern_sequence.clear()
	_pattern_input.clear()
	var length := 3 + mini(_round, 2)
	var seed := int(Time.get_unix_time_from_system()) + _round * 17
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	for _index in range(length):
		_pattern_sequence.append(rng.randi_range(0, PATTERN_SYMBOLS.size() - 1))
	prompt_label.text = "  ".join(_pattern_sequence.map(func(index: int) -> String: return PATTERN_SYMBOLS[index]))
	for index in range(PATTERN_SYMBOLS.size()):
		var button := _option_button(PATTERN_SYMBOLS[index], COLOR_VIOLET)
		button.disabled = true
		button.pressed.connect(_on_pattern_symbol.bind(index))
		option_grid.add_child(button)
	var timer := get_tree().create_timer(1.35 + float(length) * 0.18, true, false, true)
	timer.timeout.connect(_unlock_pattern_input)

func _unlock_pattern_input() -> void:
	if layer == null or _activity_id != "pattern_focus":
		return
	prompt_label.text = "Wiederhole die Folge"
	feedback_label.text = "Tippe die Symbole in der richtigen Reihenfolge."
	for child in option_grid.get_children():
		if child is Button:
			(child as Button).disabled = false
	_locked = false

func _on_pattern_symbol(index: int) -> void:
	if _locked:
		return
	_pattern_input.append(index)
	var position := _pattern_input.size() - 1
	if position >= _pattern_sequence.size() or _pattern_sequence[position] != index:
		_round_complete(false, float(position) / float(maxi(_pattern_sequence.size(), 1)), "Das Muster ist verrutscht. Wir bauen es neu auf.")
		return
	prompt_label.text = " ".join(_pattern_input.map(func(symbol_index: int) -> String: return PATTERN_SYMBOLS[symbol_index]))
	if _pattern_input.size() == _pattern_sequence.size():
		_round_complete(true, 1.0, "Muster erkannt. Dein Bitling übernimmt den Rhythmus.")

func _prepare_translation_order() -> void:
	_translation_order.clear()
	for index in range(TRANSLATION_QUESTIONS.size()):
		_translation_order.append(index)
	var rng := RandomNumberGenerator.new()
	rng.seed = int(Time.get_unix_time_from_system()) + 941
	for index in range(_translation_order.size() - 1, 0, -1):
		var swap_index := rng.randi_range(0, index)
		var temporary := _translation_order[index]
		_translation_order[index] = _translation_order[swap_index]
		_translation_order[swap_index] = temporary

func _start_translation_round() -> void:
	_locked = false
	set_process(false)
	_clear_options()
	title_label.text = "SIGNALÜBERSETZUNG"
	instruction_label.text = "Achte auf Tonfall und Situation. Wähle die Bedeutung, die am besten zum Signal passt."
	feedback_label.text = "Die fiktive Sprache ist vollständig übersetzbar."
	progress_label.text = "Botschaft %d von %d" % [_round + 1, _round_target]
	var question_index := _translation_order[_round % _translation_order.size()]
	var question: Dictionary = TRANSLATION_QUESTIONS[question_index]
	prompt_label.text = "„%s“" % str(question.get("word", "miri"))
	var options: Array = (question.get("options", []) as Array).duplicate()
	for option_variant in options:
		var option := str(option_variant)
		var button := _option_button(option, COLOR_CYAN)
		button.pressed.connect(_on_translation_answer.bind(option, str(question.get("meaning", ""))))
		option_grid.add_child(button)

func _on_translation_answer(answer: String, meaning: String) -> void:
	if _locked:
		return
	var success := answer == meaning
	_round_complete(success, 1.0 if success else 0.0, "Bedeutung verbunden." if success else "Fast. Achte auf Gefühl und Zusammenhang.")

func _start_rhythm_round() -> void:
	_locked = false
	_clear_options()
	set_process(true)
	title_label.text = "RESONANZRHYTHMUS"
	instruction_label.text = "Triff den hellen Mittelpunkt. Der Zielbereich wird mit jeder Runde schmaler."
	progress_label.text = "Resonanz %d von %d" % [_round + 1, _round_target]
	feedback_label.text = "Höre auf den Impuls und beobachte die Bewegung."
	primary_button.visible = true
	primary_button.text = "RESONANZ TREFFEN"
	_rhythm_value = 0.0
	_rhythm_direction = 1.0
	prompt_label.text = _rhythm_bar_text(_rhythm_value)

func _on_primary_pressed() -> void:
	if _activity_id != "resonance_rhythm" or _locked:
		return
	_rhythm_attempts += 1
	var distance := absf(_rhythm_value - 50.0)
	var score := clampf(1.0 - distance / 50.0, 0.0, 1.0)
	var threshold := 0.62 + float(_round) * 0.06
	_round_complete(score >= threshold, score, "Perfekte Resonanz." if score >= 0.88 else "Der Takt verbindet sich." if score >= threshold else "Noch nicht ganz. Wir stimmen uns erneut ab.")

func _round_complete(success: bool, score: float, feedback: String) -> void:
	_locked = true
	set_process(false)
	for child in option_grid.get_children():
		if child is Button:
			(child as Button).disabled = true
	primary_button.disabled = true
	if success:
		_successes += 1
	_score_total += clampf(score, 0.0, 1.0)
	feedback_label.text = feedback
	feedback_label.add_theme_color_override("font_color", COLOR_GREEN if success else COLOR_YELLOW)
	_play_feedback(success)
	var timer := get_tree().create_timer(0.85, true, false, true)
	timer.timeout.connect(_continue_after_round)

func _continue_after_round() -> void:
	if layer == null:
		return
	_round += 1
	primary_button.disabled = false
	if _round >= _round_target:
		_finish_current_activity()
		return
	match _activity_id:
		"pattern_focus":
			_start_pattern_round()
		"signal_translation":
			_start_translation_round()
		"resonance_rhythm":
			_start_rhythm_round()

func _finish_current_activity() -> void:
	set_process(false)
	var score := clampf(_score_total / float(maxi(_round_target, 1)), 0.0, 1.0)
	var success := _successes >= 2
	var activity := _activity_id
	var result := _commit_result(activity, success, score, _round_target, true)
	title_label.text = "VERBINDUNG GESPEICHERT"
	prompt_label.text = "%d%% Resonanz" % int(round(score * 100.0))
	progress_label.text = "%d von %d Runden gelungen" % [_successes, _round_target]
	feedback_label.text = "Dein Bitling erinnert sich an diesen gemeinsamen Versuch."
	_clear_options()
	primary_button.visible = true
	primary_button.disabled = false
	primary_button.text = "ZURÜCK ZUM BITLING"
	if primary_button.pressed.is_connected(_on_primary_pressed):
		primary_button.pressed.disconnect(_on_primary_pressed)
	primary_button.pressed.connect(_close_overlay, CONNECT_ONE_SHOT)
	activity_finished.emit(activity, result)

func _commit_result(activity: String, success: bool, score: float, attempts: int, apply_rewards: bool) -> Dictionary:
	var result := {
		"accepted": true,
		"success": success,
		"score": clampf(score, 0.0, 1.0),
		"attempts": maxi(attempts, 1),
		"xp_reward": int(round(12.0 + score * 18.0))
	}
	if apply_rewards:
		var state := get_node_or_null("/root/GameState")
		if state != null:
			if activity in ["pattern_focus", "signal_translation"] and state.has_method("apply_learning_result"):
				state.apply_learning_result(result)
			elif state.has_method("perform_interaction"):
				state.perform_interaction(
					"legendary_%s" % activity,
					{"energy": -5.0, "happiness": 8.0 if success else 3.0, "curiosity": 7.0, "quest_event": "discovery_completed"},
					int(result["xp_reward"]),
					["legendary_slice", "activity", activity]
				)
		var director := get_node_or_null("/root/LegendarySlice")
		if director != null and director.has_method("record_activity"):
			director.record_activity(activity, result)
	return result

func _play_feedback(success: bool) -> void:
	var audio := get_node_or_null("/root/OmniAudio")
	if audio != null and audio.has_method("play_action"):
		audio.play_action("level" if success else "check_in", 0.85)

func _rhythm_bar_text(value: float) -> String:
	var slots := 17
	var position := clampi(int(round(value / 100.0 * float(slots - 1))), 0, slots - 1)
	var text := ""
	for index in range(slots):
		if index == position:
			text += "◆"
		elif index in [7, 8, 9]:
			text += "│"
		else:
			text += "·"
	return text

func _option_button(text_value: String, accent: Color) -> Button:
	var button := Button.new()
	button.text = text_value
	button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	button.custom_minimum_size = Vector2(130.0, 62.0)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.add_theme_color_override("font_color", COLOR_TEXT)
	button.add_theme_font_size_override("font_size", 16)
	button.add_theme_stylebox_override("normal", _style(COLOR_PANEL_ALT, accent, 15, 1))
	button.add_theme_stylebox_override("hover", _style(Color("1d2850"), COLOR_CYAN, 15, 2))
	button.add_theme_stylebox_override("pressed", _style(Color(accent, 0.25), accent, 15, 2))
	return button

func _clear_options() -> void:
	if option_grid != null:
		for child in option_grid.get_children():
			child.queue_free()
	if primary_button != null:
		primary_button.visible = false
		primary_button.disabled = false
		if not primary_button.pressed.is_connected(_on_primary_pressed):
			for connection in primary_button.pressed.get_connections():
				primary_button.pressed.disconnect(connection.callable)
			primary_button.pressed.connect(_on_primary_pressed)

func _close_overlay() -> void:
	set_process(false)
	_activity_id = ""
	if layer != null:
		layer.queue_free()
	layer = null
	panel = null

func _style(fill: Color, border: Color, radius: int, width: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(width)
	style.set_corner_radius_all(radius)
	style.content_margin_left = 16.0
	style.content_margin_right = 16.0
	style.content_margin_top = 14.0
	style.content_margin_bottom = 14.0
	return style
