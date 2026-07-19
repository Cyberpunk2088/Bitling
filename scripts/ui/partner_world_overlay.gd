extends CanvasLayer

## Player-facing partner-world dashboard.
## Exposes life seasons, care recovery, techniques, settlement and evolution forecasts.

const COLOR_VOID := Color("03050f")
const COLOR_PANEL := Color("090e22")
const COLOR_CARD := Color("101833")
const COLOR_CARD_ALT := Color("151438")
const COLOR_BORDER := Color("304270")
const COLOR_CYAN := Color("42e8ff")
const COLOR_VIOLET := Color("a855f7")
const COLOR_MAGENTA := Color("f044d4")
const COLOR_GREEN := Color("64e6a2")
const COLOR_GOLD := Color("ffc85a")
const COLOR_RED := Color("ff6d8e")
const COLOR_TEXT := Color("f4f7ff")
const COLOR_MUTED := Color("9ba8c7")

var backdrop: ColorRect
var shell: PanelContainer
var scroll: ScrollContainer
var content: VBoxContainer
var summary_grid: GridContainer
var evolution_grid: GridContainer
var technique_grid: GridContainer
var settlement_grid: GridContainer
var stage_label: Label
var age_label: Label
var generation_label: Label
var care_bar: ProgressBar
var care_label: Label
var strain_label: Label
var settlement_label: Label
var settlement_detail: Label
var legacy_bar: ProgressBar
var legacy_label: Label
var legacy_button: Button
var status_message: Label

func _ready() -> void:
	layer = 45
	_build_ui()
	backdrop.visible = false
	get_viewport().size_changed.connect(_apply_responsive_layout)
	call_deferred("_connect_runtime")

func open_partner_world() -> void:
	_refresh_all()
	backdrop.visible = true
	backdrop.modulate.a = 0.0
	shell.scale = Vector2(0.985, 0.985)
	var tween := create_tween().set_parallel(true)
	tween.tween_property(backdrop, "modulate:a", 1.0, 0.18)
	tween.tween_property(shell, "scale", Vector2.ONE, 0.24).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	_apply_responsive_layout()

func close_partner_world() -> void:
	if not backdrop.visible:
		return
	var tween := create_tween().set_parallel(true)
	tween.tween_property(backdrop, "modulate:a", 0.0, 0.14)
	tween.tween_property(shell, "scale", Vector2(0.985, 0.985), 0.14)
	await tween.finished
	backdrop.visible = false

func _unhandled_input(event: InputEvent) -> void:
	if backdrop.visible and event.is_action_pressed("ui_cancel"):
		close_partner_world()
		get_viewport().set_input_as_handled()

func _build_ui() -> void:
	backdrop = ColorRect.new()
	backdrop.name = "PartnerWorldBackdrop"
	backdrop.color = Color(COLOR_VOID, 0.97)
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(backdrop)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_top", 14)
	margin.add_theme_constant_override("margin_bottom", 14)
	backdrop.add_child(margin)

	shell = PanelContainer.new()
	shell.name = "PartnerWorldShell"
	shell.pivot_offset = Vector2(360, 640)
	shell.add_theme_stylebox_override("panel", _panel_style(COLOR_PANEL, Color(COLOR_CYAN, 0.50), 26, 1))
	margin.add_child(shell)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	shell.add_child(column)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 12)
	column.add_child(header)

	var title_block := VBoxContainer.new()
	title_block.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title_block)
	var title := Label.new()
	title.text = "PARTNERWELT"
	title.add_theme_color_override("font_color", COLOR_TEXT)
	title.add_theme_font_size_override("font_size", 25)
	title_block.add_child(title)
	var subtitle := Label.new()
	subtitle.text = "Pflege • Entwicklung • Techniken • Signalsiedlung • Vermächtnis"
	subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	subtitle.add_theme_color_override("font_color", COLOR_MUTED)
	subtitle.add_theme_font_size_override("font_size", 11)
	title_block.add_child(subtitle)

	var refresh_button := Button.new()
	refresh_button.text = "↻"
	refresh_button.tooltip_text = "Entwicklungsprognose aktualisieren"
	refresh_button.custom_minimum_size = Vector2(48, 48)
	refresh_button.add_theme_font_size_override("font_size", 22)
	refresh_button.add_theme_stylebox_override("normal", _button_style(Color(COLOR_CYAN, 0.08), Color(COLOR_CYAN, 0.35), 15))
	refresh_button.add_theme_stylebox_override("pressed", _button_style(Color(COLOR_CYAN, 0.20), COLOR_CYAN, 15))
	refresh_button.pressed.connect(_refresh_all)
	header.add_child(refresh_button)

	var close_button := Button.new()
	close_button.text = "×"
	close_button.tooltip_text = "Partnerwelt schließen"
	close_button.custom_minimum_size = Vector2(48, 48)
	close_button.add_theme_font_size_override("font_size", 24)
	close_button.add_theme_stylebox_override("normal", _button_style(Color(COLOR_MAGENTA, 0.08), Color(COLOR_MAGENTA, 0.35), 15))
	close_button.add_theme_stylebox_override("pressed", _button_style(Color(COLOR_MAGENTA, 0.20), COLOR_MAGENTA, 15))
	close_button.pressed.connect(close_partner_world)
	header.add_child(close_button)

	status_message = Label.new()
	status_message.text = "Jede Entscheidung verändert mehrere Entwicklungspfade. Kein einzelner Wert bestimmt die Zukunft."
	status_message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status_message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_message.add_theme_color_override("font_color", COLOR_CYAN)
	status_message.add_theme_font_size_override("font_size", 12)
	column.add_child(status_message)

	scroll = ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_child(scroll)

	content = VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 16)
	scroll.add_child(content)

	summary_grid = GridContainer.new()
	summary_grid.name = "PartnerSummaryGrid"
	summary_grid.columns = 2
	summary_grid.add_theme_constant_override("h_separation", 10)
	summary_grid.add_theme_constant_override("v_separation", 10)
	content.add_child(summary_grid)
	_build_life_card()
	_build_care_card()
	_build_settlement_card()
	_build_legacy_card()

	content.add_child(_section_heading("ENTWICKLUNGSPFADE", "Mehrere Kategorien öffnen verschiedene, gleichwertige Zukunftsformen."))
	evolution_grid = GridContainer.new()
	evolution_grid.name = "EvolutionForecastGrid"
	evolution_grid.columns = 2
	evolution_grid.add_theme_constant_override("h_separation", 10)
	evolution_grid.add_theme_constant_override("v_separation", 10)
	content.add_child(evolution_grid)

	content.add_child(_section_heading("ERLERNTE TECHNIKEN", "Beobachtung, Begabung und Wiederholung erzeugen dauerhafte Meisterschaft."))
	technique_grid = GridContainer.new()
	technique_grid.name = "TechniqueGrid"
	technique_grid.columns = 3
	technique_grid.add_theme_constant_override("h_separation", 10)
	technique_grid.add_theme_constant_override("v_separation", 10)
	content.add_child(technique_grid)

	content.add_child(_section_heading("SIGNALSIEDLUNG", "Entdeckte Bewohner bleiben, bauen Einrichtungen und erweitern die Welt."))
	settlement_grid = GridContainer.new()
	settlement_grid.name = "SettlementGrid"
	settlement_grid.columns = 3
	settlement_grid.add_theme_constant_override("h_separation", 10)
	settlement_grid.add_theme_constant_override("v_separation", 10)
	content.add_child(settlement_grid)

	var legacy_footer := PanelContainer.new()
	legacy_footer.add_theme_stylebox_override("panel", _panel_style(Color("11112d"), Color(COLOR_GOLD, 0.50), 18, 1))
	var legacy_column := VBoxContainer.new()
	legacy_column.add_theme_constant_override("separation", 8)
	legacy_footer.add_child(legacy_column)
	var legacy_title := Label.new()
	legacy_title.text = "FREIWILLIGES VERMÄCHTNIS"
	legacy_title.add_theme_color_override("font_color", COLOR_GOLD)
	legacy_title.add_theme_font_size_override("font_size", 16)
	legacy_column.add_child(legacy_title)
	var legacy_info := Label.new()
	legacy_info.text = "In der weisen Lebensphase kann dein Bitling einen neuen Generationszyklus beginnen. Siedlung und ausgewählte Techniken bleiben erhalten."
	legacy_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	legacy_info.add_theme_color_override("font_color", COLOR_MUTED)
	legacy_info.add_theme_font_size_override("font_size", 12)
	legacy_column.add_child(legacy_info)
	legacy_button = Button.new()
	legacy_button.text = "VERMÄCHTNIS-SAMEN VORBEREITEN"
	legacy_button.custom_minimum_size = Vector2(0, 54)
	legacy_button.add_theme_color_override("font_color", COLOR_TEXT)
	legacy_button.add_theme_stylebox_override("normal", _button_style(Color(COLOR_GOLD, 0.10), Color(COLOR_GOLD, 0.55), 15))
	legacy_button.add_theme_stylebox_override("pressed", _button_style(Color(COLOR_GOLD, 0.24), COLOR_GOLD, 15))
	legacy_button.pressed.connect(_on_legacy_pressed)
	legacy_column.add_child(legacy_button)
	content.add_child(legacy_footer)

func _build_life_card() -> void:
	var card := _summary_card("LEBENSPHASE", COLOR_CYAN)
	var body := card.get_meta("body") as VBoxContainer
	stage_label = Label.new()
	stage_label.text = "JUNG"
	stage_label.add_theme_color_override("font_color", COLOR_CYAN)
	stage_label.add_theme_font_size_override("font_size", 23)
	body.add_child(stage_label)
	age_label = Label.new()
	age_label.add_theme_color_override("font_color", COLOR_TEXT)
	age_label.add_theme_font_size_override("font_size", 12)
	body.add_child(age_label)
	generation_label = Label.new()
	generation_label.add_theme_color_override("font_color", COLOR_MUTED)
	generation_label.add_theme_font_size_override("font_size", 11)
	body.add_child(generation_label)
	summary_grid.add_child(card)

func _build_care_card() -> void:
	var card := _summary_card("PFLEGEQUALITÄT", COLOR_GREEN)
	var body := card.get_meta("body") as VBoxContainer
	care_label = Label.new()
	care_label.add_theme_color_override("font_color", COLOR_GREEN)
	care_label.add_theme_font_size_override("font_size", 22)
	body.add_child(care_label)
	care_bar = ProgressBar.new()
	care_bar.min_value = 0
	care_bar.max_value = 100
	care_bar.show_percentage = false
	care_bar.custom_minimum_size = Vector2(0, 12)
	care_bar.add_theme_stylebox_override("background", _bar_style(Color("050816"), 6))
	care_bar.add_theme_stylebox_override("fill", _bar_style(COLOR_GREEN, 6))
	body.add_child(care_bar)
	strain_label = Label.new()
	strain_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	strain_label.add_theme_color_override("font_color", COLOR_MUTED)
	strain_label.add_theme_font_size_override("font_size", 11)
	body.add_child(strain_label)
	summary_grid.add_child(card)

func _build_settlement_card() -> void:
	var card := _summary_card("SIGNALSIEDLUNG", COLOR_VIOLET)
	var body := card.get_meta("body") as VBoxContainer
	settlement_label = Label.new()
	settlement_label.add_theme_color_override("font_color", COLOR_VIOLET)
	settlement_label.add_theme_font_size_override("font_size", 20)
	body.add_child(settlement_label)
	settlement_detail = Label.new()
	settlement_detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	settlement_detail.add_theme_color_override("font_color", COLOR_MUTED)
	settlement_detail.add_theme_font_size_override("font_size", 11)
	body.add_child(settlement_detail)
	summary_grid.add_child(card)

func _build_legacy_card() -> void:
	var card := _summary_card("VERMÄCHTNIS", COLOR_GOLD)
	var body := card.get_meta("body") as VBoxContainer
	legacy_label = Label.new()
	legacy_label.add_theme_color_override("font_color", COLOR_GOLD)
	legacy_label.add_theme_font_size_override("font_size", 20)
	body.add_child(legacy_label)
	legacy_bar = ProgressBar.new()
	legacy_bar.min_value = 0
	legacy_bar.max_value = 100
	legacy_bar.show_percentage = false
	legacy_bar.custom_minimum_size = Vector2(0, 12)
	legacy_bar.add_theme_stylebox_override("background", _bar_style(Color("050816"), 6))
	legacy_bar.add_theme_stylebox_override("fill", _bar_style(COLOR_GOLD, 6))
	body.add_child(legacy_bar)
	var hint := Label.new()
	hint.text = "Weise Phase + zwei Techniken"
	hint.add_theme_color_override("font_color", COLOR_MUTED)
	hint.add_theme_font_size_override("font_size", 11)
	body.add_child(hint)
	summary_grid.add_child(card)

func _summary_card(title_text: String, accent: Color) -> PanelContainer:
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(230, 128)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.add_theme_stylebox_override("panel", _panel_style(COLOR_CARD, Color(accent, 0.42), 18, 1))
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 6)
	card.add_child(body)
	var title := Label.new()
	title.text = title_text
	title.add_theme_color_override("font_color", COLOR_MUTED)
	title.add_theme_font_size_override("font_size", 11)
	body.add_child(title)
	card.set_meta("body", body)
	return card

func _section_heading(title_text: String, description: String) -> Control:
	var block := VBoxContainer.new()
	block.add_theme_constant_override("separation", 2)
	var title := Label.new()
	title.text = title_text
	title.add_theme_color_override("font_color", COLOR_TEXT)
	title.add_theme_font_size_override("font_size", 17)
	block.add_child(title)
	var subtitle := Label.new()
	subtitle.text = description
	subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	subtitle.add_theme_color_override("font_color", COLOR_MUTED)
	subtitle.add_theme_font_size_override("font_size", 11)
	block.add_child(subtitle)
	return block

func _connect_runtime() -> void:
	var world := get_node_or_null("/root/PartnerWorld")
	if world != null:
		for signal_name in ["care_quality_changed", "care_strain_recorded", "life_stage_changed", "technique_learned", "citizen_recruited", "settlement_rank_changed", "legacy_seed_created"]:
			var callable := Callable(self, "_on_runtime_changed")
			if world.has_signal(signal_name) and not world.is_connected(signal_name, callable):
				world.connect(signal_name, callable)
	var matrix := get_node_or_null("/root/EvolutionMatrix")
	if matrix != null:
		var callable := Callable(self, "_on_forecast_updated")
		if matrix.has_signal("forecast_updated") and not matrix.forecast_updated.is_connected(callable):
			matrix.forecast_updated.connect(callable)

func _refresh_all() -> void:
	var world := get_node_or_null("/root/PartnerWorld")
	var matrix := get_node_or_null("/root/EvolutionMatrix")
	if world == null or matrix == null:
		status_message.text = "Partnerwelt-Dienste sind noch nicht verfügbar."
		return
	var snapshot: Dictionary = world.get_snapshot()
	stage_label.text = _life_stage_name(str(snapshot.get("life_stage", "hatchling")))
	age_label.text = "Entwicklungszeit: %s" % _format_age(float(snapshot.get("age_minutes", 0.0)))
	generation_label.text = "Generation %d" % int(snapshot.get("generation", 1))
	var care := float(snapshot.get("care_quality", 0.0))
	care_label.text = "%d%% • %s" % [int(round(care)), _care_label(care)]
	care_bar.value = care
	strain_label.text = "Belastungen %d • Erholungskette %d" % [int(snapshot.get("care_strain", 0)), int(snapshot.get("recovery_chain", 0))]
	settlement_label.text = str(snapshot.get("settlement_rank_name", "SIGNALPOSTEN"))
	var citizens: Array = snapshot.get("citizens", [])
	var facilities: Array = snapshot.get("facilities", [])
	settlement_detail.text = "%d Bewohner • %d Einrichtungen • %d Siedlungs-XP" % [citizens.size(), facilities.size(), int(snapshot.get("settlement_xp", 0))]
	var legacy := float(snapshot.get("legacy_points", 0.0))
	legacy_bar.value = minf(legacy, 100.0)
	legacy_label.text = "%d / 100" % int(round(legacy))
	legacy_button.disabled = not bool(snapshot.get("legacy_ready", false))
	legacy_button.text = "VERMÄCHTNIS-SAMEN ERZEUGEN" if not legacy_button.disabled else "NOCH NICHT BEREIT"
	var forecast: Array[Dictionary] = matrix.evaluate_runtime()
	_rebuild_evolution_cards(forecast)
	_rebuild_techniques(snapshot)
	_rebuild_settlement(snapshot)
	status_message.text = _status_message(snapshot, forecast)
	_apply_responsive_layout()

func _rebuild_evolution_cards(forecast: Array[Dictionary]) -> void:
	_clear_container(evolution_grid)
	for candidate in forecast:
		var card := PanelContainer.new()
		card.custom_minimum_size = Vector2(260, 210)
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var eligible := bool(candidate.get("eligible", false))
		var accent := COLOR_GREEN if eligible else COLOR_VIOLET
		card.add_theme_stylebox_override("panel", _panel_style(COLOR_CARD_ALT, Color(accent, 0.48), 18, 1))
		var body := VBoxContainer.new()
		body.add_theme_constant_override("separation", 5)
		card.add_child(body)
		var title := Label.new()
		title.text = str(candidate.get("name", "ENTWICKLUNG"))
		title.add_theme_color_override("font_color", accent)
		title.add_theme_font_size_override("font_size", 16)
		body.add_child(title)
		var description := Label.new()
		description.text = str(candidate.get("description", ""))
		description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		description.add_theme_color_override("font_color", COLOR_TEXT)
		description.add_theme_font_size_override("font_size", 11)
		body.add_child(description)
		var progress := ProgressBar.new()
		progress.min_value = 0
		progress.max_value = 100
		progress.value = float(candidate.get("score", 0.0)) * 100.0
		progress.show_percentage = false
		progress.custom_minimum_size = Vector2(0, 9)
		progress.add_theme_stylebox_override("background", _bar_style(Color("050816"), 5))
		progress.add_theme_stylebox_override("fill", _bar_style(accent, 5))
		body.add_child(progress)
		var category_data: Dictionary = candidate.get("categories", {})
		var category_row := HFlowContainer.new()
		category_row.add_theme_constant_override("h_separation", 4)
		category_row.add_theme_constant_override("v_separation", 4)
		body.add_child(category_row)
		for category_value in category_data.keys():
			var category_id := str(category_value)
			var result: Dictionary = category_data[category_id]
			var chip := Label.new()
			var passed := bool(result.get("passed", false))
			chip.text = "%s %s" % ["✓" if passed else "○", _category_name(category_id)]
			chip.add_theme_color_override("font_color", COLOR_GREEN if passed else COLOR_MUTED)
			chip.add_theme_font_size_override("font_size", 9)
			chip.add_theme_stylebox_override("normal", _panel_style(Color(COLOR_GREEN if passed else COLOR_BORDER, 0.08), Color(COLOR_GREEN if passed else COLOR_BORDER, 0.32), 9, 1))
			category_row.add_child(chip)
		var requirement := Label.new()
		requirement.text = "%d/%d Kategorien • Mindestlevel %d%s" % [
			int(candidate.get("passed_categories", 0)),
			int(candidate.get("required_categories", 3)),
			int(candidate.get("minimum_level", 1)),
			" • OFFEN" if eligible else ""
		]
		requirement.add_theme_color_override("font_color", accent if eligible else COLOR_MUTED)
		requirement.add_theme_font_size_override("font_size", 10)
		body.add_child(requirement)
		evolution_grid.add_child(card)

func _rebuild_techniques(snapshot: Dictionary) -> void:
	_clear_container(technique_grid)
	var learned: Array = snapshot.get("learned_techniques", [])
	var exposure: Dictionary = snapshot.get("technique_exposure", {})
	var all_ids: Array[String] = []
	for value in exposure.keys():
		all_ids.append(str(value))
	for value in learned:
		var technique_id := str(value)
		if not all_ids.has(technique_id):
			all_ids.append(technique_id)
	all_ids.sort()
	if all_ids.is_empty():
		technique_grid.add_child(_empty_card("Noch keine Technik beobachtet", "Spielen, Lernen, Pflegen und Erkunden erzeugen erste Spuren."))
		return
	for technique_id in all_ids:
		var mastered := learned.has(technique_id)
		var card := PanelContainer.new()
		card.custom_minimum_size = Vector2(180, 94)
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var accent := COLOR_CYAN if mastered else COLOR_BORDER
		card.add_theme_stylebox_override("panel", _panel_style(COLOR_CARD, Color(accent, 0.45), 15, 1))
		var body := VBoxContainer.new()
		card.add_child(body)
		var title := Label.new()
		title.text = _technique_name(technique_id)
		title.add_theme_color_override("font_color", COLOR_CYAN if mastered else COLOR_TEXT)
		title.add_theme_font_size_override("font_size", 13)
		body.add_child(title)
		var state := Label.new()
		state.text = "GEMEISTERT" if mastered else "Beobachtung %.1f" % float(exposure.get(technique_id, 0.0))
		state.add_theme_color_override("font_color", COLOR_GREEN if mastered else COLOR_MUTED)
		state.add_theme_font_size_override("font_size", 10)
		body.add_child(state)
		technique_grid.add_child(card)

func _rebuild_settlement(snapshot: Dictionary) -> void:
	_clear_container(settlement_grid)
	var citizens: Array = snapshot.get("citizens", [])
	var facilities: Array = snapshot.get("facilities", [])
	for citizen_value in citizens:
		settlement_grid.add_child(_settlement_item(_citizen_name(str(citizen_value)), "BEWOHNER", COLOR_MAGENTA))
	for facility_value in facilities:
		settlement_grid.add_child(_settlement_item(_facility_name(str(facility_value)), "EINRICHTUNG", COLOR_VIOLET))
	if citizens.is_empty() and facilities.is_empty():
		settlement_grid.add_child(_empty_card("Signalposten", "Expeditionen bringen die ersten Bewohner in die Welt."))

func _settlement_item(title_text: String, kind: String, accent: Color) -> PanelContainer:
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(170, 80)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.add_theme_stylebox_override("panel", _panel_style(COLOR_CARD, Color(accent, 0.40), 15, 1))
	var body := VBoxContainer.new()
	card.add_child(body)
	var title := Label.new()
	title.text = title_text
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.add_theme_color_override("font_color", COLOR_TEXT)
	title.add_theme_font_size_override("font_size", 12)
	body.add_child(title)
	var type_label := Label.new()
	type_label.text = kind
	type_label.add_theme_color_override("font_color", accent)
	type_label.add_theme_font_size_override("font_size", 9)
	body.add_child(type_label)
	return card

func _empty_card(title_text: String, detail: String) -> PanelContainer:
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(240, 90)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.add_theme_stylebox_override("panel", _panel_style(COLOR_CARD, Color(COLOR_BORDER, 0.45), 15, 1))
	var body := VBoxContainer.new()
	card.add_child(body)
	var title := Label.new()
	title.text = title_text
	title.add_theme_color_override("font_color", COLOR_TEXT)
	body.add_child(title)
	var label := Label.new()
	label.text = detail
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_color_override("font_color", COLOR_MUTED)
	label.add_theme_font_size_override("font_size", 10)
	body.add_child(label)
	return card

func _on_legacy_pressed() -> void:
	var world := get_node_or_null("/root/PartnerWorld")
	if world == null:
		return
	var result: Dictionary = world.create_legacy_seed()
	if bool(result.get("accepted", false)):
		status_message.text = "Generation %d wurde als Vermächtnis gesichert. Ausgewählte Techniken begleiten den Neubeginn." % int(result.get("generation", 1))
		var store := get_node_or_null("/root/PartnerWorldStore")
		if store != null and store.has_method("save_now"):
			store.save_now()
	else:
		status_message.text = "Vermächtnis noch nicht bereit: weise Lebensphase, 100 Punkte und zwei Techniken erforderlich."
	_refresh_all()

func _on_runtime_changed(_a: Variant = null, _b: Variant = null, _c: Variant = null) -> void:
	if backdrop.visible:
		_refresh_all()

func _on_forecast_updated(_forecast: Array[Dictionary]) -> void:
	if backdrop.visible:
		call_deferred("_refresh_all")

func _apply_responsive_layout() -> void:
	if summary_grid == null:
		return
	var width := get_viewport().get_visible_rect().size.x
	var compact := width < 720.0
	var medium := width < 1120.0
	summary_grid.columns = 1 if compact else 2 if medium else 4
	evolution_grid.columns = 1 if compact else 2 if medium else 3
	technique_grid.columns = 1 if compact else 2 if medium else 3
	settlement_grid.columns = 1 if compact else 2 if medium else 3
	shell.pivot_offset = shell.size * 0.5

func _status_message(snapshot: Dictionary, forecast: Array[Dictionary]) -> String:
	for candidate in forecast:
		if bool(candidate.get("eligible", false)):
			return "%s ist entwicklungsbereit. Du entscheidest, wann der nächste Schritt beginnt." % str(candidate.get("name", "Eine Form"))
	if float(snapshot.get("care_quality", 0.0)) < 45.0:
		return "Die Pflegequalität ist angespannt. Erholung und verlässliche Routinen öffnen neue Wege."
	if int(snapshot.get("settlement_rank", 0)) == 0:
		return "Die Partnerwelt wartet auf ihre ersten Bewohner. Expeditionen verändern die Siedlung dauerhaft."
	return "Mehrere Wege wachsen gleichzeitig. Der schwächste Bereich ist ein Hinweis, keine Bestrafung."

func _clear_container(container: Container) -> void:
	for child in container.get_children():
		child.queue_free()

func _life_stage_name(value: String) -> String:
	match value:
		"hatchling": return "SCHLÜPFLING"
		"young": return "JUNG"
		"prime": return "REIFE"
		"wise": return "WEISE"
		_: return value.to_upper()

func _format_age(minutes: float) -> String:
	var hours := minutes / 60.0
	if hours < 1.0:
		return "%d Minuten" % int(round(minutes))
	if hours < 24.0:
		return "%.1f Stunden" % hours
	return "%.1f Tage" % (hours / 24.0)

func _care_label(value: float) -> String:
	if value >= 85.0: return "HARMONISCH"
	if value >= 65.0: return "STABIL"
	if value >= 45.0: return "AUFMERKSAM"
	if value >= 25.0: return "ANGESANNT"
	return "ERHOLUNG NÖTIG"

func _category_name(value: String) -> String:
	match value:
		"growth": return "Wachstum"
		"bond": return "Bindung"
		"care": return "Pflege"
		"habits": return "Gewohnheit"
		"bonus": return "Entdeckung"
		_: return value.capitalize()

func _technique_name(value: String) -> String:
	match value:
		"signal_dash": return "Signalsprung"
		"echo_shield": return "Echoschild"
		"pattern_focus": return "Musterfokus"
		"comic_trip": return "Komikstolperer"
		"care_pulse": return "Fürsorgepuls"
		"mentor_chorus": return "Mentorenchor"
		_: return value.replace("_", " ").capitalize()

func _citizen_name(value: String) -> String:
	match value:
		"bridgewright_lyra": return "Lyra • Brückenbauerin"
		"archivist_veo": return "Veo • Archivar"
		"gardener_miri": return "Miri • Glitchgärtnerin"
		"listener_oro": return "Oro • Signallauscher"
		"chronologist_nex": return "Nex • Chronologe"
		_: return value.replace("_", " ").capitalize()

func _facility_name(value: String) -> String:
	match value:
		"nest": return "Gemeinschaftsnest"
		"clinic": return "Regenerationsklinik"
		"kitchen": return "Signalküche"
		"academy": return "Musterakademie"
		"workshop": return "Erfinderwerkstatt"
		"social_hub": return "Begegnungsforum"
		"expedition_gate": return "Expeditionstor"
		"legacy_archive": return "Vermächtnisarchiv"
		"translation_spire": return "Übersetzungsturm"
		_: return value.replace("_", " ").capitalize()

func _panel_style(background: Color, border: Color, radius: int, border_width: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(radius)
	style.content_margin_left = 14
	style.content_margin_right = 14
	style.content_margin_top = 12
	style.content_margin_bottom = 12
	return style

func _button_style(background: Color, border: Color, radius: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(radius)
	return style

func _bar_style(color: Color, radius: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(radius)
	return style
