extends CanvasLayer

## Wave 5 fullscreen learning destination. Catalog, challenge and result states are
## presented as a game flow rather than a passive quiz window.

const COLOR_VOID := Color("02040d")
const COLOR_PANEL := Color("091126")
const COLOR_CARD := Color("111b38")
const COLOR_TEXT := Color("f4f7ff")
const COLOR_MUTED := Color("9ba8c7")
const COLOR_CYAN := Color("42e8ff")
const COLOR_VIOLET := Color("a855f7")
const COLOR_MAGENTA := Color("f044d4")
const COLOR_GREEN := Color("64e6a2")
const COLOR_GOLD := Color("ffc85a")

var _backdrop: ColorRect
var _shell: PanelContainer
var _content: VBoxContainer
var _catalog_scroll: ScrollContainer
var _catalog_grid: GridContainer
var _session_panel: PanelContainer
var _title: Label
var _summary: Label
var _prompt: Label
var _progress: Label
var _mastery: ProgressBar
var _answer_box: VBoxContainer
var _approach_row: HBoxContainer
var _feedback: Label
var _close_button: Button
var _selected_approach: String = "observe"
var _answer_buttons: Array[Button] = []
var _approach_buttons: Dictionary = {}
var _compact: bool = false

func _ready() -> void:
	layer = 49
	_build_ui()
	_backdrop.visible = false
	get_viewport().size_changed.connect(_apply_responsive_layout)
	call_deferred("_connect_service")

func open_adventures() -> void:
	_show_catalog()
	_backdrop.visible = true
	_backdrop.modulate.a = 0.0
	_shell.scale = Vector2(0.985, 0.985)
	var tween: Tween = create_tween().set_parallel(true)
	tween.tween_property(_backdrop, "modulate:a", 1.0, 0.18)
	tween.tween_property(_shell, "scale", Vector2.ONE, 0.24).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	_apply_responsive_layout()

func close_adventures() -> void:
	if not is_open():
		return
	var service: Node = get_node_or_null("/root/LearningAdventures")
	if service != null and service.has_method("abandon_session"):
		service.call("abandon_session")
	_backdrop.visible = false

func is_open() -> bool:
	return _backdrop != null and _backdrop.visible

func get_layout_snapshot() -> Dictionary:
	return {
		"visible": is_open(),
		"compact": _compact,
		"catalog_columns": _catalog_grid.columns if _catalog_grid != null else 0,
		"catalog_cards": _catalog_grid.get_child_count() if _catalog_grid != null else 0,
		"answer_count": _answer_buttons.size(),
		"approach_count": _approach_buttons.size(),
		"session_visible": _session_panel.visible if _session_panel != null else false
	}

func _unhandled_input(event: InputEvent) -> void:
	if is_open() and event.is_action_pressed("ui_cancel"):
		close_adventures()
		get_viewport().set_input_as_handled()

func _build_ui() -> void:
	_backdrop = ColorRect.new()
	_backdrop.name = "LearningAdventureBackdrop"
	_backdrop.color = COLOR_VOID
	_backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_backdrop)
	var margin: MarginContainer = MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side: String in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_%s" % side, 10)
	_backdrop.add_child(margin)
	_shell = PanelContainer.new()
	_shell.name = "LearningAdventureShell"
	_shell.add_theme_stylebox_override("panel", _panel_style(COLOR_PANEL, Color(COLOR_CYAN, 0.48), 24, 1))
	margin.add_child(_shell)
	_content = VBoxContainer.new()
	_content.add_theme_constant_override("separation", 10)
	_shell.add_child(_content)
	_content.add_child(_build_header())
	_catalog_scroll = ScrollContainer.new()
	_catalog_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_catalog_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_content.add_child(_catalog_scroll)
	_catalog_grid = GridContainer.new()
	_catalog_grid.columns = 3
	_catalog_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_catalog_grid.add_theme_constant_override("h_separation", 10)
	_catalog_grid.add_theme_constant_override("v_separation", 10)
	_catalog_scroll.add_child(_catalog_grid)
	_session_panel = _build_session_panel()
	_content.add_child(_session_panel)

func _build_header() -> Control:
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	var text: VBoxContainer = VBoxContainer.new()
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(text)
	_title = Label.new()
	_title.text = "LERNABENTEUER"
	_title.add_theme_color_override("font_color", COLOR_TEXT)
	_title.add_theme_font_size_override("font_size", 25)
	text.add_child(_title)
	_summary = Label.new()
	_summary.text = "Zwölf Wege, Wissen in Weltwirkung zu verwandeln."
	_summary.add_theme_color_override("font_color", COLOR_MUTED)
	_summary.add_theme_font_size_override("font_size", 11)
	text.add_child(_summary)
	_close_button = Button.new()
	_close_button.text = "×"
	_close_button.custom_minimum_size = Vector2(48, 48)
	_close_button.add_theme_font_size_override("font_size", 23)
	_close_button.pressed.connect(close_adventures)
	row.add_child(_close_button)
	return row

func _build_session_panel() -> PanelContainer:
	var panel: PanelContainer = PanelContainer.new()
	panel.name = "LearningAdventureSession"
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", _panel_style(Color(COLOR_CARD, 0.94), Color(COLOR_VIOLET, 0.50), 22, 1))
	var margin: MarginContainer = MarginContainer.new()
	for side: String in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_%s" % side, 18)
	panel.add_child(margin)
	var column: VBoxContainer = VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	margin.add_child(column)
	_progress = Label.new()
	_progress.add_theme_color_override("font_color", COLOR_CYAN)
	_progress.add_theme_font_size_override("font_size", 12)
	column.add_child(_progress)
	_mastery = ProgressBar.new()
	_mastery.min_value = 0.0
	_mastery.max_value = 100.0
	_mastery.show_percentage = true
	_mastery.custom_minimum_size = Vector2(0, 24)
	column.add_child(_mastery)
	_prompt = Label.new()
	_prompt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_prompt.add_theme_color_override("font_color", COLOR_TEXT)
	_prompt.add_theme_font_size_override("font_size", 23)
	column.add_child(_prompt)
	var approach_title: Label = Label.new()
	approach_title.text = "WÄHLE DEINEN DENKWEG"
	approach_title.add_theme_color_override("font_color", COLOR_GOLD)
	approach_title.add_theme_font_size_override("font_size", 11)
	column.add_child(approach_title)
	_approach_row = HBoxContainer.new()
	_approach_row.add_theme_constant_override("separation", 6)
	column.add_child(_approach_row)
	for approach_id: String in ["observe", "compare", "experiment", "explain"]:
		var button: Button = Button.new()
		button.text = {"observe": "BEOBACHTEN", "compare": "VERGLEICHEN", "experiment": "AUSPROBIEREN", "explain": "ERKLÄREN"}[approach_id]
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.custom_minimum_size = Vector2(0, 46)
		button.add_theme_font_size_override("font_size", 10)
		button.pressed.connect(_select_approach.bind(approach_id))
		_approach_row.add_child(button)
		_approach_buttons[approach_id] = button
	_answer_box = VBoxContainer.new()
	_answer_box.add_theme_constant_override("separation", 8)
	column.add_child(_answer_box)
	_feedback = Label.new()
	_feedback.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_feedback.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_feedback.add_theme_color_override("font_color", COLOR_MUTED)
	_feedback.add_theme_font_size_override("font_size", 13)
	column.add_child(_feedback)
	panel.visible = false
	return panel

func _connect_service() -> void:
	var service: Node = get_node_or_null("/root/LearningAdventures")
	if service == null:
		return
	if service.has_signal("catalog_changed"):
		service.connect("catalog_changed", Callable(self, "_on_catalog_changed"))
	if service.has_signal("challenge_changed"):
		service.connect("challenge_changed", Callable(self, "_on_challenge_changed"))
	if service.has_signal("session_completed"):
		service.connect("session_completed", Callable(self, "_on_session_completed"))

func _show_catalog() -> void:
	_catalog_scroll.visible = true
	_session_panel.visible = false
	_title.text = "LERNABENTEUER"
	var service: Node = get_node_or_null("/root/LearningAdventures")
	if service == null or not service.has_method("get_snapshot"):
		return
	var snapshot: Dictionary = service.call("get_snapshot")
	_summary.text = "MEISTERSCHAFT %d%% · %d/12 GEMEISTERT · %d SITZUNGEN" % [int(snapshot.get("average_mastery", 0.0)), int(snapshot.get("mastered_count", 0)), int(snapshot.get("total_sessions", 0))]
	_rebuild_catalog(snapshot.get("catalog", []) as Array)

func _rebuild_catalog(catalog: Array) -> void:
	for child: Node in _catalog_grid.get_children():
		child.queue_free()
	for entry_variant: Variant in catalog:
		if not entry_variant is Dictionary:
			continue
		var entry: Dictionary = entry_variant as Dictionary
		var card: Button = Button.new()
		card.custom_minimum_size = Vector2(230, 150)
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		card.text = "%s\n%s\nMEISTERSCHAFT %d%% · %s" % [str(entry.get("title", "Abenteuer")), str(entry.get("description", "")), int(entry.get("mastery", 0.0)), str(entry.get("level", "ENTDECKEND"))]
		card.disabled = not bool(entry.get("unlocked", false))
		var accent: Color = Color(str(entry.get("accent", "42e8ff")))
		card.add_theme_stylebox_override("normal", _panel_style(Color(COLOR_CARD, 0.86), Color(accent, 0.40), 18, 1))
		card.add_theme_stylebox_override("pressed", _panel_style(Color(accent, 0.18), accent, 18, 2))
		card.pressed.connect(_start_adventure.bind(str(entry.get("id", ""))))
		_catalog_grid.add_child(card)

func _start_adventure(adventure_id: String) -> void:
	var service: Node = get_node_or_null("/root/LearningAdventures")
	if service == null:
		return
	var result: Dictionary = service.call("start_session", adventure_id)
	if not bool(result.get("accepted", false)):
		_summary.text = "Dieses Abenteuer ist noch nicht freigeschaltet."
		return
	var session: Dictionary = result.get("session", {}) as Dictionary
	_catalog_scroll.visible = false
	_session_panel.visible = true
	_title.text = str(session.get("title", "Lernabenteuer"))
	_selected_approach = "observe"
	_update_approach_buttons()
	_show_challenge(session.get("challenge", {}) as Dictionary, session)
	_play_feedback("learn", 0.8)

func _show_challenge(challenge: Dictionary, session: Dictionary = {}) -> void:
	var service: Node = get_node_or_null("/root/LearningAdventures")
	var snapshot: Dictionary = service.call("get_snapshot") if service != null else {}
	var active: Dictionary = snapshot.get("active_session", {}) as Dictionary
	if not session.is_empty():
		active = session
	_progress.text = "RUNDE %d/%d · SCHWIERIGKEIT %d/10" % [int(challenge.get("round", 1)), int(active.get("rounds", 3)), int(active.get("difficulty", 1))]
	_prompt.text = str(challenge.get("prompt", "Welche Lösung passt?"))
	_feedback.text = "Fehler kosten keinen Fortschritt. Unterschiedliche Denkwege können zusätzliche Stärke geben."
	_feedback.add_theme_color_override("font_color", COLOR_MUTED)
	var adventure_id: String = str(challenge.get("adventure_id", ""))
	for entry_variant: Variant in snapshot.get("catalog", []):
		if entry_variant is Dictionary and str((entry_variant as Dictionary).get("id", "")) == adventure_id:
			_mastery.value = float((entry_variant as Dictionary).get("mastery", 20.0))
			break
	for child: Node in _answer_box.get_children():
		child.queue_free()
	_answer_buttons.clear()
	var answers: Array = challenge.get("answers", []) as Array
	for index: int in range(answers.size()):
		var button: Button = Button.new()
		button.text = str(answers[index])
		button.custom_minimum_size = Vector2(0, 58)
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		button.add_theme_font_size_override("font_size", 16)
		button.add_theme_stylebox_override("normal", _panel_style(Color("17223a"), Color(COLOR_CYAN, 0.38), 15, 1))
		button.pressed.connect(_submit_answer.bind(index))
		_answer_box.add_child(button)
		_answer_buttons.append(button)

func _select_approach(approach_id: String) -> void:
	_selected_approach = approach_id
	_update_approach_buttons()
	_play_feedback("navigation", 0.45)

func _update_approach_buttons() -> void:
	for approach_id_variant: Variant in _approach_buttons.keys():
		var approach_id: String = str(approach_id_variant)
		var button: Button = _approach_buttons[approach_id]
		button.disabled = approach_id == _selected_approach

func _submit_answer(index: int) -> void:
	for button: Button in _answer_buttons:
		button.disabled = true
	var service: Node = get_node_or_null("/root/LearningAdventures")
	if service == null:
		return
	var result: Dictionary = service.call("submit_solution", index, _selected_approach)
	if not bool(result.get("accepted", false)):
		_feedback.text = "Die Lösung konnte nicht ausgewertet werden."
		return
	var success: bool = bool(result.get("success", false))
	_feedback.add_theme_color_override("font_color", COLOR_GREEN if success else COLOR_VIOLET)
	_feedback.text = "%s %s\n%s" % ["STARK." if success else "FAST.", str(result.get("explanation", "")), str(result.get("transfer_tip", ""))]
	_play_feedback("level" if success else "learn", 0.95 if success else 0.65)
	var haptics: Node = get_node_or_null("/root/HapticService")
	if haptics != null:
		if success and haptics.has_method("success"):
			haptics.call("success")
		elif not success and haptics.has_method("light"):
			haptics.call("light")
	if bool(result.get("completed", false)):
		await get_tree().create_timer(1.1).timeout
		_show_completion(result)
	elif result.has("next_challenge"):
		await get_tree().create_timer(1.0).timeout
		_selected_approach = "observe"
		_update_approach_buttons()
		_show_challenge(result.get("next_challenge", {}) as Dictionary)

func _show_completion(result: Dictionary) -> void:
	_progress.text = "ABENTEUER ABGESCHLOSSEN"
	_mastery.value = float(result.get("mastery", 0.0))
	_prompt.text = "%s\nMEISTERSCHAFT %d%% · %s" % [str(result.get("title", "Lernabenteuer")), int(result.get("mastery", 0.0)), str(result.get("mastery_level", "WACHSEND"))]
	_feedback.add_theme_color_override("font_color", COLOR_GOLD)
	_feedback.text = "+%d XP · Expeditionstransfer %d%%\nTechnik: %s · Evolutionsaffinität: %s" % [int(result.get("xp_reward", 0)), int(float(result.get("expedition_bonus", 0.0)) * 100.0), str(result.get("technique", "-")).replace("_", " ").to_upper(), str(result.get("evolution_affinity", "-")).replace("_", " ")]
	for child: Node in _answer_box.get_children():
		child.queue_free()
	var continue_button: Button = Button.new()
	continue_button.text = "WEITERE LERNABENTEUER"
	continue_button.custom_minimum_size = Vector2(0, 58)
	continue_button.pressed.connect(_show_catalog)
	_answer_box.add_child(continue_button)
	_approach_row.visible = false

func _on_catalog_changed(_snapshot: Dictionary) -> void:
	if is_open() and _catalog_scroll.visible:
		_show_catalog()

func _on_challenge_changed(challenge: Dictionary) -> void:
	if is_open() and _session_panel.visible:
		_show_challenge(challenge)

func _on_session_completed(_result: Dictionary) -> void:
	_approach_row.visible = true

func _apply_responsive_layout() -> void:
	if _catalog_grid == null:
		return
	var design_width: float = get_viewport().get_visible_rect().size.x
	var physical_width: float = float(get_tree().root.size.x)
	var width: float = minf(design_width, physical_width) if physical_width > 0.0 else design_width
	_compact = width < 760.0
	_catalog_grid.columns = 1 if _compact else 2 if width < 1180.0 else 3
	_prompt.add_theme_font_size_override("font_size", 20 if _compact else 23)
	for button_variant: Variant in _approach_buttons.values():
		var button: Button = button_variant as Button
		button.add_theme_font_size_override("font_size", 8 if _compact else 10)

func _play_feedback(action: String, intensity: float) -> void:
	var audio: Node = get_node_or_null("/root/OmniAudio")
	if audio == null:
		return
	if action == "navigation" and audio.has_method("play_navigation"):
		audio.call("play_navigation")
	elif audio.has_method("play_action"):
		audio.call("play_action", action, intensity)

func _panel_style(background: Color, border: Color, radius: int, border_width: int) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(radius)
	style.content_margin_left = 12.0
	style.content_margin_right = 12.0
	style.content_margin_top = 12.0
	style.content_margin_bottom = 12.0
	return style
