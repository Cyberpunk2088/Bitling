extends Node

const LearningCompanionStage := preload("res://scripts/ui/learning_companion_stage.gd")

## Re-composes the tested Wave 5 overlay without duplicating its gameplay flow.
## It injects the Bitling, groups challenge and decisions, and makes stacked mobile
## layouts scroll safely while desktop uses two columns.

var _overlay: Node
var _catalog_scroll: ScrollContainer
var _catalog_hero: PanelContainer
var _catalog_hero_grid: GridContainer
var _catalog_stage: Control
var _session_grid: GridContainer
var _session_stage: Control
var _visual_card: PanelContainer
var _decision_card: PanelContainer
var _installed: bool = false
var _last_reduced_motion: bool = false

func _ready() -> void:
	call_deferred("_install")
	set_process(true)

func get_status() -> Dictionary:
	return {
		"installed": _installed,
		"catalog_hero": _catalog_hero != null,
		"session_grid": _session_grid != null,
		"session_columns": _session_grid.columns if _session_grid != null else 0,
		"companion_stage": _session_stage.call("get_visual_snapshot") if _session_stage != null else {}
	}

func _process(_delta: float) -> void:
	if not _installed or not is_instance_valid(_overlay):
		return
	var open_now := bool(_overlay.call("is_open")) if _overlay.has_method("is_open") else false
	if _catalog_hero != null and _catalog_scroll != null:
		_catalog_hero.visible = open_now and _catalog_scroll.visible
	_sync_reduced_motion()

func _install() -> void:
	_overlay = get_node_or_null("/root/LearningAdventureOverlay")
	if _overlay == null:
		return
	var session_panel := _overlay.get("_session_panel") as PanelContainer
	var content := _overlay.get("_content") as VBoxContainer
	_catalog_scroll = _overlay.get("_catalog_scroll") as ScrollContainer
	if session_panel == null or content == null or _catalog_scroll == null:
		return
	_install_catalog_hero(content)
	_install_session_composition(session_panel)
	_connect_learning_signals()
	get_viewport().size_changed.connect(_apply_layout)
	_installed = true
	_apply_layout()
	_sync_reduced_motion()

func _install_catalog_hero(content: VBoxContainer) -> void:
	_catalog_hero = PanelContainer.new()
	_catalog_hero.name = "LearningCatalogHero"
	_catalog_hero.add_theme_stylebox_override("panel", _panel_style(Color("071328"), Color("42e8ff66"), 20))
	var margin := MarginContainer.new()
	for side: String in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_%s" % side, 12)
	_catalog_hero.add_child(margin)
	_catalog_hero_grid = GridContainer.new()
	_catalog_hero_grid.columns = 2
	_catalog_hero_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_catalog_hero_grid.add_theme_constant_override("h_separation", 14)
	_catalog_hero_grid.add_theme_constant_override("v_separation", 8)
	margin.add_child(_catalog_hero_grid)
	_catalog_stage = LearningCompanionStage.new()
	_catalog_stage.name = "LearningCatalogCompanionStage"
	_catalog_stage.custom_minimum_size = Vector2(260, 170)
	_catalog_stage.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_catalog_hero_grid.add_child(_catalog_stage)
	_catalog_stage.call("set_catalog_mode")
	var text := VBoxContainer.new()
	text.alignment = BoxContainer.ALIGNMENT_CENTER
	text.add_theme_constant_override("separation", 7)
	_catalog_hero_grid.add_child(text)
	var kicker := Label.new()
	kicker.text = "DEIN BITLING LERNT MIT DIR"
	kicker.add_theme_color_override("font_color", Color("42e8ff"))
	kicker.add_theme_font_size_override("font_size", 11)
	text.add_child(kicker)
	var headline := Label.new()
	headline.text = "Wissen verändert eure Welt."
	headline.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	headline.add_theme_color_override("font_color", Color("f4f7ff"))
	headline.add_theme_font_size_override("font_size", 22)
	text.add_child(headline)
	var body := Label.new()
	body.text = "Abenteuer stärken Expeditionen, Techniken, Dialoge und Evolutionswege."
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_theme_color_override("font_color", Color("9ba8c7"))
	body.add_theme_font_size_override("font_size", 12)
	text.add_child(body)
	content.add_child(_catalog_hero)
	content.move_child(_catalog_hero, 1)

func _install_session_composition(session_panel: PanelContainer) -> void:
	if session_panel.get_child_count() == 0:
		return
	var outer_margin := session_panel.get_child(0) as MarginContainer
	if outer_margin == null or outer_margin.get_child_count() == 0:
		return
	var old_column := outer_margin.get_child(0) as VBoxContainer
	if old_column == null or old_column.get_child_count() < 7:
		return
	var progress := _overlay.get("_progress") as Label
	var mastery := _overlay.get("_mastery") as ProgressBar
	var prompt := _overlay.get("_prompt") as Label
	var approach_row := _overlay.get("_approach_row") as HBoxContainer
	var answer_box := _overlay.get("_answer_box") as VBoxContainer
	var feedback := _overlay.get("_feedback") as Label
	var approach_title := old_column.get_child(3) as Label
	if progress == null or mastery == null or prompt == null or approach_row == null or answer_box == null or feedback == null or approach_title == null:
		return

	var scroll := ScrollContainer.new()
	scroll.name = "LearningSessionScroll"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	outer_margin.add_child(scroll)
	_session_grid = GridContainer.new()
	_session_grid.name = "LearningSessionPolishGrid"
	_session_grid.columns = 2
	_session_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_session_grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_session_grid.add_theme_constant_override("h_separation", 12)
	_session_grid.add_theme_constant_override("v_separation", 12)
	scroll.add_child(_session_grid)

	_visual_card = _make_card(Color("071328"), Color("42e8ff55"))
	_decision_card = _make_card(Color("0d1730"), Color("ffc85a4d"))
	_session_grid.add_child(_visual_card)
	_session_grid.add_child(_decision_card)
	var visual_column := _card_column(_visual_card)
	var decision_column := _card_column(_decision_card)

	progress.reparent(visual_column)
	mastery.reparent(visual_column)
	_session_stage = LearningCompanionStage.new()
	_session_stage.name = "LearningSessionCompanionStage"
	_session_stage.custom_minimum_size = Vector2(420, 390)
	_session_stage.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_session_stage.size_flags_vertical = Control.SIZE_EXPAND_FILL
	visual_column.add_child(_session_stage)
	prompt.reparent(visual_column)
	prompt.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	prompt.custom_minimum_size = Vector2(0, 82)
	approach_title.reparent(decision_column)
	approach_row.reparent(decision_column)
	answer_box.reparent(decision_column)
	feedback.reparent(decision_column)
	old_column.queue_free()

func _connect_learning_signals() -> void:
	var service := get_node_or_null("/root/LearningAdventures")
	if service == null:
		return
	for pair: Array in [
		["session_started", "_on_session_started"],
		["challenge_changed", "_on_challenge_changed"],
		["round_resolved", "_on_round_resolved"]
	]:
		var signal_name := str(pair[0])
		var callback := Callable(self, str(pair[1]))
		if service.has_signal(signal_name) and not service.is_connected(signal_name, callback):
			service.connect(signal_name, callback)

func _on_session_started(session: Dictionary) -> void:
	_update_stage(session.get("challenge", {}) as Dictionary, session)

func _on_challenge_changed(challenge: Dictionary) -> void:
	_update_stage(challenge, {})

func _on_round_resolved(result: Dictionary) -> void:
	if _session_stage != null:
		_session_stage.call("set_result", bool(result.get("success", false)))

func _update_stage(challenge: Dictionary, session: Dictionary) -> void:
	if _session_stage == null:
		return
	var adventure_id := str(challenge.get("adventure_id", session.get("adventure_id", "")))
	var round_number := int(challenge.get("round", int(session.get("round", 0)) + 1))
	var approach := str(_overlay.get("_selected_approach"))
	_session_stage.call("set_context", adventure_id, _domain_for_adventure(adventure_id), round_number, approach)

func _apply_layout() -> void:
	if not _installed:
		return
	var viewport_width := get_viewport().get_visible_rect().size.x
	var physical_width := float(get_tree().root.size.x)
	var width := minf(viewport_width, physical_width) if physical_width > 0.0 else viewport_width
	var compact := width < 760.0
	var stacked := width < 1040.0
	_session_grid.columns = 1 if stacked else 2
	_catalog_hero_grid.columns = 1 if compact else 2
	_catalog_stage.custom_minimum_size = Vector2(0, 135 if compact else 175)
	_session_stage.custom_minimum_size = Vector2(0, 195 if compact else 280 if stacked else 430)
	_visual_card.custom_minimum_size = Vector2(0, 350 if compact else 480 if stacked else 620)
	_decision_card.custom_minimum_size = Vector2(0, 300 if compact else 330 if stacked else 620)
	var prompt := _overlay.get("_prompt") as Label
	if prompt != null:
		prompt.custom_minimum_size = Vector2(0, 78 if compact else 88)
		prompt.add_theme_font_size_override("font_size", 20 if compact else 21)
	var approach_buttons := _overlay.get("_approach_buttons") as Dictionary
	for approach_id_variant: Variant in approach_buttons.keys():
		var approach_id := str(approach_id_variant)
		var button := approach_buttons[approach_id] as Button
		button.text = _approach_label(approach_id, compact)
		button.add_theme_font_size_override("font_size", 12 if compact else 13)
		button.custom_minimum_size = Vector2(0, 50 if compact else 48)
	_sync_reduced_motion()

func _domain_for_adventure(adventure_id: String) -> String:
	var service := get_node_or_null("/root/LearningAdventures")
	if service == null or not service.has_method("get_catalog"):
		return "discovery"
	for entry_variant: Variant in service.call("get_catalog"):
		if entry_variant is Dictionary and str((entry_variant as Dictionary).get("id", "")) == adventure_id:
			return str((entry_variant as Dictionary).get("domain", "discovery"))
	return "discovery"

func _approach_label(approach_id: String, compact: bool) -> String:
	if compact:
		return {"observe": "SEHEN", "compare": "VERGLEICH", "experiment": "TESTEN", "explain": "ERKLÄREN"}.get(approach_id, approach_id.to_upper())
	return {"observe": "BEOBACHTEN", "compare": "VERGLEICHEN", "experiment": "AUSPROBIEREN", "explain": "ERKLÄREN"}.get(approach_id, approach_id.to_upper())

func _sync_reduced_motion() -> void:
	var reduced_motion := _reduced_motion_enabled()
	if reduced_motion == _last_reduced_motion and _installed:
		return
	_last_reduced_motion = reduced_motion
	for stage_variant: Variant in [_catalog_stage, _session_stage]:
		var stage: Control = stage_variant as Control
		if stage != null and stage.has_method("set_reduced_motion"):
			stage.call("set_reduced_motion", reduced_motion)

func _reduced_motion_enabled() -> bool:
	var state := get_node_or_null("/root/GameState")
	if state == null:
		return false
	var settings := state.get("settings") as Dictionary
	return bool(settings.get("reduce_motion", false))

func _make_card(background: Color, border: Color) -> PanelContainer:
	var card := PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.size_flags_vertical = Control.SIZE_EXPAND_FILL
	card.add_theme_stylebox_override("panel", _panel_style(background, border, 18))
	return card

func _card_column(card: PanelContainer) -> VBoxContainer:
	var margin := MarginContainer.new()
	for side: String in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_%s" % side, 12)
	card.add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 9)
	margin.add_child(column)
	return column

func _panel_style(background: Color, border: Color, radius: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(radius)
	style.content_margin_left = 8.0
	style.content_margin_right = 8.0
	style.content_margin_top = 8.0
	style.content_margin_bottom = 8.0
	return style
