extends CanvasLayer

## Fullscreen Wave 5 destination. The hub presents all twelve fields as adventures;
## sessions include adaptive rounds, hints, transfer tasks, mastery and world impact.

const AdventureBackdrop := preload("res://scripts/ui/learning_adventure_backdrop.gd")

const COLOR_VOID := Color("02040d")
const COLOR_PANEL := Color("080d20")
const COLOR_CARD := Color("101832")
const COLOR_CARD_ALT := Color("151f3d")
const COLOR_TEXT := Color("f4f7ff")
const COLOR_MUTED := Color("9ba8c7")
const COLOR_CYAN := Color("42e8ff")
const COLOR_VIOLET := Color("a855f7")
const COLOR_MAGENTA := Color("f044d4")
const COLOR_GREEN := Color("64e6a2")
const COLOR_GOLD := Color("ffc85a")
const COLOR_RED := Color("ff6d8e")

var _backdrop: ColorRect
var _shell: PanelContainer
var _header_title: Label
var _header_meta: Label
var _close_button: Button
var _hub: VBoxContainer
var _hub_scroll: ScrollContainer
var _hub_grid: GridContainer
var _hub_summary: Label
var _session: VBoxContainer
var _session_title: Label
var _session_meta: Label
var _progress: ProgressBar
var _visual_panel: PanelContainer
var _visual_backdrop: Control
var _prompt: Label
var _option_grid: GridContainer
var _primary_button: Button
var _hint_button: Button
var _feedback: Label
var _explanation: Label
var _completion_actions: HBoxContainer
var _completion_replay: Button
var _completion_hub: Button
var _abandon_button: Button
var _compact: bool = false
var _medium: bool = false
var _locked: bool = false
var _timing_active: bool = false
var _timing_value: float = 0.0
var _timing_direction: float = 1.0
var _timing_speed: float = 0.75
var _current_round: Dictionary = {}
var _last_adventure_id: String = ""

func _ready() -> void:
	layer = 235
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()
	_backdrop.visible = false
	set_process(false)
	get_viewport().size_changed.connect(_apply_responsive_layout)
	call_deferred("_connect_service")

func open_hub() -> void:
	var service: Node = get_node_or_null("/root/LearningAdventures")
	if service == null:
		return
	_show_overlay()
	var active: Dictionary = service.call("get_active_session") as Dictionary
	if not active.is_empty():
		_show_session()
		_render_round(active.get("current_round", {}) as Dictionary)
	else:
		_show_hub()

func open_catalog() -> void:
	_show_overlay()
	_show_hub()

func open_adventure(adventure_id: String) -> void:
	var service: Node = get_node_or_null("/root/LearningAdventures")
	if service == null:
		return
	_show_overlay()
	var active: Dictionary = service.call("get_active_session") as Dictionary
	if not active.is_empty():
		service.call("abandon_session")
	var started: Dictionary = service.call("start_adventure", adventure_id)
	if not bool(started.get("accepted", false)):
		_show_hub()
		return
	_last_adventure_id = adventure_id
	_show_session()
	_render_round(started.get("round", {}) as Dictionary)
	_play_learning_cue("start", 0.8)

func close_overlay() -> void:
	if _backdrop == null or not _backdrop.visible:
		return
	set_process(false)
	_timing_active = false
	var tween: Tween = create_tween().set_parallel(true)
	tween.tween_property(_backdrop, "modulate:a", 0.0, 0.14)
	tween.tween_property(_shell, "scale", Vector2(0.985, 0.985), 0.14)
	await tween.finished
	_backdrop.visible = false
	var audio: Node = get_node_or_null("/root/OmniAudio")
	if audio != null and audio.has_method("set_environment"):
		audio.call("set_environment", "HOME")

func is_open() -> bool:
	return _backdrop != null and _backdrop.visible

func get_layout_snapshot() -> Dictionary:
	return {
		"visible": is_open(),
		"compact": _compact,
		"medium": _medium,
		"hub_visible": _hub != null and _hub.visible,
		"session_visible": _session != null and _session.visible,
		"hub_columns": _hub_grid.columns if _hub_grid != null else 0,
		"catalog_cards": _hub_grid.get_child_count() if _hub_grid != null else 0,
		"option_count": _option_grid.get_child_count() if _option_grid != null else 0,
		"timing_active": _timing_active,
		"current_adventure": str(_current_round.get("adventure_id", "")),
		"visual": _visual_backdrop.call("get_visual_snapshot") if _visual_backdrop != null and _visual_backdrop.has_method("get_visual_snapshot") else {}
	}

func _process(delta: float) -> void:
	if not _timing_active or _locked or not is_open():
		return
	_timing_value += maxf(delta, 0.0) * _timing_speed * _timing_direction
	if _timing_value >= 1.0:
		_timing_value = 1.0
		_timing_direction = -1.0
	elif _timing_value <= 0.0:
		_timing_value = 0.0
		_timing_direction = 1.0
	if _visual_backdrop != null and _visual_backdrop.has_method("set_timing"):
		_visual_backdrop.call("set_timing", _timing_value, float(_current_round.get("target", 0.5)), float(_current_round.get("window", 0.15)))
	_primary_button.text = "RESONANZ TREFFEN · %d%%" % int(round(_timing_value * 100.0))

func _unhandled_input(event: InputEvent) -> void:
	if is_open() and event.is_action_pressed("ui_cancel"):
		close_overlay()
		get_viewport().set_input_as_handled()

func _build_ui() -> void:
	_backdrop = ColorRect.new()
	_backdrop.name = "LearningAdventureBackdrop"
	_backdrop.color = COLOR_VOID
	_backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_backdrop)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_bottom", 10)
	_backdrop.add_child(margin)

	_shell = PanelContainer.new()
	_shell.name = "LearningAdventureShell"
	_shell.add_theme_stylebox_override("panel", _panel_style(COLOR_PANEL, Color(COLOR_CYAN, 0.48), 24, 1))
	margin.add_child(_shell)

	var root_column := VBoxContainer.new()
	root_column.add_theme_constant_override("separation", 10)
	_shell.add_child(root_column)
	root_column.add_child(_build_header())

	_hub = _build_hub()
	root_column.add_child(_hub)
	_session = _build_session()
	root_column.add_child(_session)

func _build_header() -> Control:
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 10)
	var title_column := VBoxContainer.new()
	title_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title_column)
	_header_title = Label.new()
	_header_title.text = "LERNABENTEUER"
	_header_title.add_theme_color_override("font_color", COLOR_TEXT)
	_header_title.add_theme_font_size_override("font_size", 25)
	title_column.add_child(_header_title)
	_header_meta = Label.new()
	_header_meta.text = "12 FELDER · 60 VARIANTEN · TRANSFER STATT AUSWENDIGLERNEN"
	_header_meta.add_theme_color_override("font_color", COLOR_MUTED)
	_header_meta.add_theme_font_size_override("font_size", 10)
	title_column.add_child(_header_meta)
	_close_button = Button.new()
	_close_button.text = "×"
	_close_button.tooltip_text = "Lernabenteuer schließen"
	_close_button.custom_minimum_size = Vector2(48, 48)
	_close_button.add_theme_font_size_override("font_size", 24)
	_close_button.add_theme_stylebox_override("normal", _button_style(Color(COLOR_MAGENTA, 0.10), Color(COLOR_MAGENTA, 0.48), 15))
	_close_button.pressed.connect(close_overlay)
	header.add_child(_close_button)
	return header

func _build_hub() -> VBoxContainer:
	var hub := VBoxContainer.new()
	hub.name = "LearningHub"
	hub.size_flags_vertical = Control.SIZE_EXPAND_FILL
	hub.add_theme_constant_override("separation", 10)
	_hub_summary = Label.new()
	_hub_summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hub_summary.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hub_summary.add_theme_color_override("font_color", COLOR_CYAN)
	_hub_summary.add_theme_font_size_override("font_size", 12)
	hub.add_child(_hub_summary)
	_hub_scroll = ScrollContainer.new()
	_hub_scroll.name = "LearningHubScroll"
	_hub_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_hub_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_hub_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hub.add_child(_hub_scroll)
	_hub_grid = GridContainer.new()
	_hub_grid.name = "LearningHubGrid"
	_hub_grid.columns = 3
	_hub_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_hub_grid.add_theme_constant_override("h_separation", 10)
	_hub_grid.add_theme_constant_override("v_separation", 10)
	_hub_scroll.add_child(_hub_grid)
	return hub

func _build_session() -> VBoxContainer:
	var session := VBoxContainer.new()
	session.name = "LearningSession"
	session.visible = false
	session.size_flags_vertical = Control.SIZE_EXPAND_FILL
	session.add_theme_constant_override("separation", 9)

	var session_header := HBoxContainer.new()
	session_header.add_theme_constant_override("separation", 8)
	session.add_child(session_header)
	var title_column := VBoxContainer.new()
	title_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	session_header.add_child(title_column)
	_session_title = Label.new()
	_session_title.text = "MUSTERSTAFFEL"
	_session_title.add_theme_color_override("font_color", COLOR_TEXT)
	_session_title.add_theme_font_size_override("font_size", 21)
	title_column.add_child(_session_title)
	_session_meta = Label.new()
	_session_meta.add_theme_color_override("font_color", COLOR_MUTED)
	_session_meta.add_theme_font_size_override("font_size", 10)
	title_column.add_child(_session_meta)
	_abandon_button = Button.new()
	_abandon_button.text = "ZUM HUB"
	_abandon_button.custom_minimum_size = Vector2(94, 44)
	_abandon_button.add_theme_stylebox_override("normal", _button_style(Color(COLOR_VIOLET, 0.08), Color(COLOR_VIOLET, 0.36), 13))
	_abandon_button.pressed.connect(_abandon_to_hub)
	session_header.add_child(_abandon_button)

	_progress = ProgressBar.new()
	_progress.min_value = 0.0
	_progress.max_value = 100.0
	_progress.value = 0.0
	_progress.show_percentage = false
	_progress.custom_minimum_size = Vector2(0, 12)
	_progress.add_theme_stylebox_override("background", _panel_style(Color("111a35"), Color.TRANSPARENT, 6, 0))
	_progress.add_theme_stylebox_override("fill", _panel_style(Color(COLOR_CYAN, 0.78), Color.TRANSPARENT, 6, 0))
	session.add_child(_progress)

	_visual_panel = PanelContainer.new()
	_visual_panel.name = "LearningVisualPanel"
	_visual_panel.custom_minimum_size = Vector2(0, 285)
	_visual_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_visual_panel.add_theme_stylebox_override("panel", _panel_style(Color("030817"), Color(COLOR_CYAN, 0.44), 20, 1))
	session.add_child(_visual_panel)
	var visual_root := Control.new()
	visual_root.custom_minimum_size = Vector2(0, 285)
	visual_root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	visual_root.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_visual_panel.add_child(visual_root)
	_visual_backdrop = AdventureBackdrop.new()
	_visual_backdrop.name = "LearningAdventureVisual"
	_visual_backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	visual_root.add_child(_visual_backdrop)
	var prompt_margin := MarginContainer.new()
	prompt_margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	prompt_margin.add_theme_constant_override("margin_left", 24)
	prompt_margin.add_theme_constant_override("margin_right", 24)
	prompt_margin.add_theme_constant_override("margin_top", 42)
	prompt_margin.add_theme_constant_override("margin_bottom", 55)
	visual_root.add_child(prompt_margin)
	var prompt_center := CenterContainer.new()
	prompt_center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	prompt_center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	prompt_margin.add_child(prompt_center)
	var prompt_card := PanelContainer.new()
	prompt_card.custom_minimum_size = Vector2(280, 120)
	prompt_card.add_theme_stylebox_override("panel", _panel_style(Color(COLOR_CARD, 0.88), Color(COLOR_CYAN, 0.32), 17, 1))
	prompt_center.add_child(prompt_card)
	_prompt = Label.new()
	_prompt.text = "Welche Lösung passt?"
	_prompt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_prompt.add_theme_color_override("font_color", COLOR_TEXT)
	_prompt.add_theme_font_size_override("font_size", 19)
	prompt_card.add_child(_prompt)

	_option_grid = GridContainer.new()
	_option_grid.name = "LearningOptions"
	_option_grid.columns = 3
	_option_grid.add_theme_constant_override("h_separation", 8)
	_option_grid.add_theme_constant_override("v_separation", 8)
	session.add_child(_option_grid)

	_primary_button = Button.new()
	_primary_button.visible = false
	_primary_button.custom_minimum_size = Vector2(0, 62)
	_primary_button.add_theme_font_size_override("font_size", 17)
	_primary_button.add_theme_stylebox_override("normal", _button_style(Color(COLOR_MAGENTA, 0.14), Color(COLOR_MAGENTA, 0.72), 17))
	_primary_button.add_theme_stylebox_override("pressed", _button_style(Color(COLOR_MAGENTA, 0.30), COLOR_CYAN, 17))
	_primary_button.pressed.connect(_submit_timing)
	session.add_child(_primary_button)

	var support_row := HBoxContainer.new()
	support_row.add_theme_constant_override("separation", 8)
	session.add_child(support_row)
	_hint_button = Button.new()
	_hint_button.text = "HINWEIS"
	_hint_button.custom_minimum_size = Vector2(104, 48)
	_hint_button.add_theme_stylebox_override("normal", _button_style(Color(COLOR_GOLD, 0.08), Color(COLOR_GOLD, 0.40), 14))
	_hint_button.pressed.connect(_request_hint)
	support_row.add_child(_hint_button)
	_feedback = Label.new()
	_feedback.text = "Nimm dir Zeit. Ein Fehler entfernt keinen Fortschritt."
	_feedback.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_feedback.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_feedback.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_feedback.add_theme_color_override("font_color", COLOR_MUTED)
	_feedback.add_theme_font_size_override("font_size", 12)
	support_row.add_child(_feedback)
	_explanation = Label.new()
	_explanation.visible = false
	_explanation.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_explanation.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_explanation.add_theme_color_override("font_color", COLOR_MUTED)
	_explanation.add_theme_font_size_override("font_size", 11)
	session.add_child(_explanation)

	_completion_actions = HBoxContainer.new()
	_completion_actions.visible = false
	_completion_actions.alignment = BoxContainer.ALIGNMENT_CENTER
	_completion_actions.add_theme_constant_override("separation", 8)
	session.add_child(_completion_actions)
	_completion_replay = Button.new()
	_completion_replay.text = "NOCH EINMAL"
	_completion_replay.custom_minimum_size = Vector2(136, 52)
	_completion_replay.add_theme_stylebox_override("normal", _button_style(Color(COLOR_GREEN, 0.10), Color(COLOR_GREEN, 0.48), 15))
	_completion_replay.pressed.connect(_replay_last)
	_completion_actions.add_child(_completion_replay)
	_completion_hub = Button.new()
	_completion_hub.text = "ALLE ABENTEUER"
	_completion_hub.custom_minimum_size = Vector2(150, 52)
	_completion_hub.add_theme_stylebox_override("normal", _button_style(Color(COLOR_VIOLET, 0.10), Color(COLOR_VIOLET, 0.48), 15))
	_completion_hub.pressed.connect(_show_hub)
	_completion_actions.add_child(_completion_hub)
	return session

func _show_overlay() -> void:
	_backdrop.visible = true
	_backdrop.modulate.a = 0.0
	_shell.scale = Vector2(0.985, 0.985)
	var tween: Tween = create_tween().set_parallel(true)
	tween.tween_property(_backdrop, "modulate:a", 1.0, 0.18)
	tween.tween_property(_shell, "scale", Vector2.ONE, 0.24).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	_apply_responsive_layout()
	var audio: Node = get_node_or_null("/root/OmniAudio")
	if audio != null and audio.has_method("set_environment"):
		audio.call("set_environment", "LEARNING_ADVENTURE")

func _show_hub() -> void:
	set_process(false)
	_timing_active = false
	_locked = false
	_current_round.clear()
	_hub.visible = true
	_session.visible = false
	_header_title.text = "LERNABENTEUER"
	_header_meta.text = "12 FELDER · 60 VARIANTEN · TRANSFER STATT AUSWENDIGLERNEN"
	_rebuild_hub()
	_apply_responsive_layout()

func _show_session() -> void:
	_hub.visible = false
	_session.visible = true
	_header_title.text = "GEMEINSAM LERNEN"
	_header_meta.text = "ADAPTIV · FEHLERTOLERANT · MIT WELTFOLGEN"
	_completion_actions.visible = false
	_abandon_button.visible = true
	_hint_button.visible = true
	_apply_responsive_layout()

func _rebuild_hub() -> void:
	for child: Node in _hub_grid.get_children():
		child.queue_free()
	var service: Node = get_node_or_null("/root/LearningAdventures")
	if service == null:
		return
	var snapshot: Dictionary = service.call("get_snapshot") as Dictionary
	_hub_summary.text = "DURCHSCHNITT %d%% · %d/12 GEMEISTERT · %d TRANSFERERFOLGE" % [
		int(round(float(snapshot.get("average_rating", 20.0)))),
		int(snapshot.get("mastered_adventures", 0)),
		int(snapshot.get("total_transfer_masteries", 0))
	]
	for entry_variant: Variant in snapshot.get("catalog", []):
		if not entry_variant is Dictionary:
			continue
		var entry: Dictionary = entry_variant as Dictionary
		var card := Button.new()
		var accent: Color = Color(str(entry.get("accent", "42e8ff")))
		card.name = "Adventure%s" % str(entry.get("id", "unknown")).to_pascal_case()
		card.text = "%s  %s\n%s\n\nMEISTERSCHAFT %d%% · STUFE %d\nTRANSFER %d · %s" % [
			str(entry.get("icon", "◇")),
			str(entry.get("title", "Lernabenteuer")),
			str(entry.get("description", "")),
			int(round(float(entry.get("rating", 20.0)))),
			int(entry.get("mastery_level", 1)),
			int(entry.get("transfer_masteries", 0)),
			str(entry.get("world_hook", "Partnerwelt")).to_upper()
		]
		card.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		card.alignment = HORIZONTAL_ALIGNMENT_LEFT
		card.custom_minimum_size = Vector2(250, 176)
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.add_theme_color_override("font_color", COLOR_TEXT)
		card.add_theme_font_size_override("font_size", 11)
		card.add_theme_stylebox_override("normal", _button_style(Color(COLOR_CARD, 0.94), Color(accent, 0.38), 18))
		card.add_theme_stylebox_override("hover", _button_style(Color(accent, 0.12), Color(accent, 0.78), 18))
		card.add_theme_stylebox_override("pressed", _button_style(Color(accent, 0.22), accent, 18))
		card.pressed.connect(open_adventure.bind(str(entry.get("id", ""))))
		_hub_grid.add_child(card)

func _render_round(round_data: Dictionary) -> void:
	if round_data.is_empty():
		_show_hub()
		return
	_current_round = round_data.duplicate(true)
	_locked = false
	_explanation.visible = false
	_completion_actions.visible = false
	_abandon_button.visible = true
	_hint_button.visible = true
	_session_title.text = "%s%s" % [str(round_data.get("title", "Lernabenteuer")), " · TRANSFER" if bool(round_data.get("transfer", false)) else ""]
	_session_meta.text = "%s · SCHWIERIGKEIT %d/10 · RUNDE %d/%d" % [
		str(round_data.get("age_label", "VERTIEFT")),
		int(round_data.get("difficulty", 1)),
		int(round_data.get("round_number", 1)),
		int(round_data.get("total_rounds", 1))
	]
	_progress.value = float(int(round_data.get("round_number", 1)) - 1) / float(maxi(int(round_data.get("total_rounds", 1)), 1)) * 100.0
	_prompt.text = str(round_data.get("prompt", "Welche Lösung passt?"))
	_feedback.text = "Transferaufgabe: Nutze die Idee in einer neuen Situation." if bool(round_data.get("transfer", false)) else "Nimm dir Zeit. Ein Fehler entfernt keinen Fortschritt."
	_feedback.add_theme_color_override("font_color", COLOR_GOLD if bool(round_data.get("transfer", false)) else COLOR_MUTED)
	var definition: Dictionary = _definition_for(str(round_data.get("adventure_id", "")))
	var accent: Color = Color(str(definition.get("accent", "42e8ff")))
	_visual_panel.add_theme_stylebox_override("panel", _panel_style(Color("030817"), Color(accent, 0.50), 20, 1))
	_visual_backdrop.call("set_adventure", str(round_data.get("adventure_id", "")), str(round_data.get("domain", "logic")), str(round_data.get("mechanic", "choice")))
	_visual_backdrop.set("reduced_motion", _reduced_motion())
	_clear_options()
	var mechanic: String = str(round_data.get("mechanic", "choice"))
	_timing_active = mechanic == "timing"
	set_process(_timing_active)
	if _timing_active:
		_timing_value = 0.0
		_timing_direction = 1.0
		_timing_speed = clampf(float(round_data.get("speed", 0.75)) + float(int(round_data.get("difficulty", 1)) - 1) * 0.018, 0.55, 1.15)
		_primary_button.visible = true
		_primary_button.disabled = false
		_primary_button.text = "RESONANZ TREFFEN"
		_visual_backdrop.call("set_timing", _timing_value, float(round_data.get("target", 0.5)), float(round_data.get("window", 0.15)))
	else:
		_primary_button.visible = false
		var options: Array = round_data.get("options", []) as Array
		for index: int in range(options.size()):
			var button := Button.new()
			button.text = str(options[index])
			button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			button.custom_minimum_size = Vector2(150, 68)
			button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			button.add_theme_color_override("font_color", COLOR_TEXT)
			button.add_theme_font_size_override("font_size", 13)
			button.add_theme_stylebox_override("normal", _button_style(Color(COLOR_CARD_ALT, 0.96), Color(accent, 0.42), 15))
			button.add_theme_stylebox_override("hover", _button_style(Color(accent, 0.13), Color(accent, 0.82), 15))
			button.add_theme_stylebox_override("pressed", _button_style(Color(accent, 0.24), accent, 15))
			button.pressed.connect(_submit_choice.bind(index))
			_option_grid.add_child(button)
	_apply_responsive_layout()

func _submit_choice(index: int) -> void:
	if _locked:
		return
	var service: Node = get_node_or_null("/root/LearningAdventures")
	if service == null:
		return
	_locked = true
	_disable_inputs()
	var result: Dictionary = service.call("submit_choice", index) as Dictionary
	_handle_round_result(result)

func _submit_timing() -> void:
	if _locked or not _timing_active:
		return
	var service: Node = get_node_or_null("/root/LearningAdventures")
	if service == null:
		return
	_locked = true
	_timing_active = false
	set_process(false)
	_disable_inputs()
	var result: Dictionary = service.call("submit_timing", _timing_value) as Dictionary
	_handle_round_result(result)

func _request_hint() -> void:
	if _locked:
		return
	var service: Node = get_node_or_null("/root/LearningAdventures")
	if service == null:
		return
	var result: Dictionary = service.call("request_hint") as Dictionary
	if bool(result.get("accepted", false)):
		_feedback.text = "HINWEIS: %s" % str(result.get("hint", ""))
		_feedback.add_theme_color_override("font_color", COLOR_GOLD)
		_play_learning_cue("hint", 0.6)

func _handle_round_result(result: Dictionary) -> void:
	if not bool(result.get("accepted", false)):
		_feedback.text = "Die Antwort konnte nicht ausgewertet werden."
		_feedback.add_theme_color_override("font_color", COLOR_RED)
		_locked = false
		return
	var success: bool = bool(result.get("success", false))
	var score: float = float(result.get("score", 0.0))
	_feedback.text = "STARK VERBUNDEN · %d%%" % int(round(score * 100.0)) if success else "NEUER MESSPUNKT · %d%%" % int(round(score * 100.0))
	_feedback.add_theme_color_override("font_color", COLOR_GREEN if success else COLOR_GOLD)
	_explanation.text = str(result.get("explanation", "Jeder Versuch liefert neue Information."))
	if not success and not str(result.get("best_answer", "")).is_empty():
		_explanation.text += "\nStärkste Lösung: %s" % str(result.get("best_answer", ""))
	_explanation.visible = true
	_visual_backdrop.call("pulse", success, score)
	_play_learning_cue("round_success" if success else "round_retry", score)
	var performance: Node = get_node_or_null("/root/CharacterPerformance")
	if performance != null and performance.has_method("request_action"):
		performance.call("request_action", "happy" if success else "curious", clampf(0.5 + score * 0.5, 0.5, 1.0))
	if bool(result.get("session_complete", false)):
		_show_completion(result.get("completion", {}) as Dictionary)
		return
	var next_round: Dictionary = result.get("next_round", {}) as Dictionary
	await get_tree().create_timer(1.05, true, false, true).timeout
	if is_open() and _session.visible:
		_render_round(next_round)

func _show_completion(completion: Dictionary) -> void:
	set_process(false)
	_timing_active = false
	_locked = true
	_last_adventure_id = str(completion.get("adventure_id", _last_adventure_id))
	_progress.value = 100.0
	_session_title.text = "WISSEN WIRKT WEITER"
	_session_meta.text = "%s · MEISTERSCHAFT %d%% · STUFE %d" % [
		str(completion.get("title", "Lernabenteuer")),
		int(round(float(completion.get("rating", 20.0)))),
		int(completion.get("mastery_level", 1))
	]
	_prompt.text = "%d%% Gesamtresonanz\n%s" % [
		int(round(float(completion.get("score", 0.0)) * 100.0)),
		"TRANSFER GEMEISTERT" if bool(completion.get("transfer_mastered", false)) else "TRANSFER WIRD WEITER GEÜBT"
	]
	_feedback.text = "+%d XP · Technik, Siedlung und Entwicklung wurden aktualisiert." % int(completion.get("xp_reward", 0))
	_feedback.add_theme_color_override("font_color", COLOR_GREEN if bool(completion.get("success", false)) else COLOR_GOLD)
	_explanation.text = "Das Ergebnis wirkt auf Dialoge, Fähigkeiten, Mentorenfortschritt, Expeditionen und Evolutionsprognosen."
	_explanation.visible = true
	_clear_options()
	_primary_button.visible = false
	_hint_button.visible = false
	_abandon_button.visible = false
	_completion_actions.visible = true
	_visual_backdrop.call("pulse", bool(completion.get("success", false)), float(completion.get("score", 0.0)))
	_play_learning_cue("transfer" if bool(completion.get("transfer_mastered", false)) else "complete", float(completion.get("score", 0.0)))

func _replay_last() -> void:
	if _last_adventure_id.is_empty():
		_show_hub()
		return
	open_adventure(_last_adventure_id)

func _abandon_to_hub() -> void:
	var service: Node = get_node_or_null("/root/LearningAdventures")
	if service != null and not (service.call("get_active_session") as Dictionary).is_empty():
		service.call("abandon_session")
	_show_hub()

func _disable_inputs() -> void:
	for child: Node in _option_grid.get_children():
		if child is Button:
			(child as Button).disabled = true
	_primary_button.disabled = true
	_hint_button.disabled = true

func _clear_options() -> void:
	for child: Node in _option_grid.get_children():
		child.queue_free()
	_primary_button.disabled = false
	_hint_button.disabled = false

func _definition_for(adventure_id: String) -> Dictionary:
	var service: Node = get_node_or_null("/root/LearningAdventures")
	if service == null:
		return {}
	for entry_variant: Variant in service.call("get_catalog") as Array:
		if entry_variant is Dictionary and str((entry_variant as Dictionary).get("id", "")) == adventure_id:
			return entry_variant as Dictionary
	return {}

func _connect_service() -> void:
	var service: Node = get_node_or_null("/root/LearningAdventures")
	if service == null:
		return
	if service.has_signal("catalog_changed"):
		var callback: Callable = Callable(self, "_on_catalog_changed")
		if not service.is_connected("catalog_changed", callback):
			service.connect("catalog_changed", callback)

func _on_catalog_changed(_catalog: Array[Dictionary]) -> void:
	if is_open() and _hub.visible:
		_rebuild_hub()

func _apply_responsive_layout() -> void:
	if _shell == null:
		return
	var design_width: float = get_viewport().get_visible_rect().size.x
	var physical_width: float = float(get_tree().root.size.x)
	var width: float = minf(design_width, physical_width) if physical_width > 0.0 else design_width
	_compact = width < 760.0
	_medium = width >= 760.0 and width < 1180.0
	_hub_grid.columns = 1 if _compact else 2 if _medium else 3
	_option_grid.columns = 1 if _compact else 3
	_visual_panel.custom_minimum_size.y = 255.0 if _compact else 310.0 if _medium else 360.0
	_prompt.add_theme_font_size_override("font_size", 16 if _compact else 19 if _medium else 22)
	_session_title.add_theme_font_size_override("font_size", 18 if _compact else 21)
	_header_title.add_theme_font_size_override("font_size", 21 if _compact else 25)
	_header_meta.visible = not _compact
	_close_button.custom_minimum_size = Vector2(44, 44) if _compact else Vector2(48, 48)
	for child: Node in _hub_grid.get_children():
		if child is Button:
			(child as Button).custom_minimum_size = Vector2(0, 164 if _compact else 176)

func _reduced_motion() -> bool:
	var state: Node = get_node_or_null("/root/GameState")
	return state != null and bool(state.get("settings").get("reduce_motion", false))

func _play_learning_cue(cue_name: String, intensity: float) -> void:
	var audio: Node = get_node_or_null("/root/OmniAudio")
	if audio != null and audio.has_method("play_learning_cue"):
		audio.call("play_learning_cue", cue_name, intensity)
	elif audio != null and audio.has_method("play_action"):
		audio.call("play_action", "learn", intensity)

func _panel_style(background: Color, border: Color, radius: int, border_width: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(radius)
	style.content_margin_left = 12.0
	style.content_margin_right = 12.0
	style.content_margin_top = 10.0
	style.content_margin_bottom = 10.0
	return style

func _button_style(background: Color, border: Color, radius: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(radius)
	style.content_margin_left = 12.0
	style.content_margin_right = 12.0
	style.content_margin_top = 9.0
	style.content_margin_bottom = 9.0
	return style
