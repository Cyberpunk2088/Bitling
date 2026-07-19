extends CanvasLayer

## Fullscreen Wave 4 destination. The map is the primary interaction surface;
## contextual panels expose residents, mentors, secrets and expeditions.

const SettlementMap := preload("res://scripts/ui/signal_settlement_map.gd")

const COLOR_VOID := Color("02040d")
const COLOR_PANEL := Color("080d20")
const COLOR_CARD := Color("101832")
const COLOR_BORDER := Color("2c477b")
const COLOR_CYAN := Color("42e8ff")
const COLOR_VIOLET := Color("a855f7")
const COLOR_MAGENTA := Color("f044d4")
const COLOR_GREEN := Color("64e6a2")
const COLOR_GOLD := Color("ffc85a")
const COLOR_TEXT := Color("f4f7ff")
const COLOR_MUTED := Color("9ba8c7")

var _backdrop: ColorRect
var _shell: PanelContainer
var _body_scroll: ScrollContainer
var _body: GridContainer
var _map_panel: PanelContainer
var _map: Control
var _left_panel: PanelContainer
var _right_panel: PanelContainer
var _district_title: Label
var _district_description: Label
var _district_meta: Label
var _resident_list: VBoxContainer
var _encounter_label: Label
var _secret_button: Button
var _expedition_select: OptionButton
var _expedition_button: Button
var _expedition_status: Label
var _choice_row: HBoxContainer
var _status: Label
var _rank_label: Label
var _close_button: Button
var _compact := false
var _expedition_ids: Array[String] = []

func _ready() -> void:
	layer = 47
	_build_ui()
	_backdrop.visible = false
	get_viewport().size_changed.connect(_apply_responsive_layout)
	call_deferred("_connect_service")

func open_world() -> void:
	_refresh()
	_backdrop.visible = true
	_backdrop.modulate.a = 0.0
	_shell.scale = Vector2(0.985, 0.985)
	var tween := create_tween().set_parallel(true)
	tween.tween_property(_backdrop, "modulate:a", 1.0, 0.18)
	tween.tween_property(_shell, "scale", Vector2.ONE, 0.24).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	var audio := get_node_or_null("/root/OmniAudio")
	if audio != null and audio.has_method("set_environment"):
		audio.call("set_environment", "SETTLEMENT")
	_apply_responsive_layout()

func close_world() -> void:
	if not _backdrop.visible:
		return
	var tween := create_tween().set_parallel(true)
	tween.tween_property(_backdrop, "modulate:a", 0.0, 0.14)
	tween.tween_property(_shell, "scale", Vector2(0.985, 0.985), 0.14)
	await tween.finished
	_backdrop.visible = false
	var audio := get_node_or_null("/root/OmniAudio")
	if audio != null and audio.has_method("set_environment"):
		audio.call("set_environment", "HOME")

func is_open() -> bool:
	return _backdrop != null and _backdrop.visible

func get_layout_snapshot() -> Dictionary:
	return {
		"visible": is_open(),
		"compact": _compact,
		"body_columns": _body.columns if _body != null else 0,
		"map_present": _map != null,
		"map_snapshot": _map.call("get_visual_snapshot") if _map != null and _map.has_method("get_visual_snapshot") else {},
		"expedition_choices": _choice_row.get_child_count() if _choice_row != null else 0
	}

func _unhandled_input(event: InputEvent) -> void:
	if is_open() and event.is_action_pressed("ui_cancel"):
		close_world()
		get_viewport().set_input_as_handled()

func _build_ui() -> void:
	_backdrop = ColorRect.new()
	_backdrop.name = "SignalSettlementBackdrop"
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
	_shell.name = "SignalSettlementShell"
	_shell.add_theme_stylebox_override("panel", _panel_style(COLOR_PANEL, Color(COLOR_CYAN, 0.48), 24, 1))
	margin.add_child(_shell)

	var root_column := VBoxContainer.new()
	root_column.add_theme_constant_override("separation", 10)
	_shell.add_child(root_column)

	root_column.add_child(_build_header())
	_status = Label.new()
	_status.text = "Tippe einen freigeschalteten Bezirk an. Dein Bitling bewegt sich sichtbar durch die Siedlung."
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status.add_theme_color_override("font_color", COLOR_CYAN)
	_status.add_theme_font_size_override("font_size", 12)
	root_column.add_child(_status)

	_body_scroll = ScrollContainer.new()
	_body_scroll.name = "SettlementBodyScroll"
	_body_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_body_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_body_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root_column.add_child(_body_scroll)

	_body = GridContainer.new()
	_body.name = "SettlementBody"
	_body.columns = 3
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_body.add_theme_constant_override("h_separation", 10)
	_body.add_theme_constant_override("v_separation", 10)
	_body_scroll.add_child(_body)

	_left_panel = _build_left_panel()
	_map_panel = _build_map_panel()
	_right_panel = _build_right_panel()
	_body.add_child(_left_panel)
	_body.add_child(_map_panel)
	_body.add_child(_right_panel)

func _build_header() -> Control:
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 10)
	var title_block := VBoxContainer.new()
	title_block.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title_block)
	var title := Label.new()
	title.text = "SIGNALSIEDLUNG"
	title.add_theme_color_override("font_color", COLOR_TEXT)
	title.add_theme_font_size_override("font_size", 25)
	title_block.add_child(title)
	_rank_label = Label.new()
	_rank_label.text = "SIGNALPOSTEN · GENERATION 1"
	_rank_label.add_theme_color_override("font_color", COLOR_MUTED)
	_rank_label.add_theme_font_size_override("font_size", 11)
	title_block.add_child(_rank_label)
	var partner_button := Button.new()
	partner_button.text = "ENTWICKLUNG"
	partner_button.custom_minimum_size = Vector2(128, 48)
	partner_button.add_theme_stylebox_override("normal", _button_style(Color(COLOR_VIOLET, 0.10), Color(COLOR_VIOLET, 0.50), 15))
	partner_button.pressed.connect(_open_partner_dashboard)
	header.add_child(partner_button)
	_close_button = Button.new()
	_close_button.text = "×"
	_close_button.custom_minimum_size = Vector2(48, 48)
	_close_button.add_theme_font_size_override("font_size", 23)
	_close_button.add_theme_stylebox_override("normal", _button_style(Color(COLOR_MAGENTA, 0.10), Color(COLOR_MAGENTA, 0.50), 15))
	_close_button.pressed.connect(close_world)
	header.add_child(_close_button)
	return header

func _build_left_panel() -> PanelContainer:
	var panel := PanelContainer.new()
	panel.name = "DistrictDetailPanel"
	panel.custom_minimum_size = Vector2(260, 620)
	panel.add_theme_stylebox_override("panel", _panel_style(Color(COLOR_CARD, 0.92), Color(COLOR_GREEN, 0.38), 20, 1))
	var margin := _card_margin()
	panel.add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 9)
	margin.add_child(column)
	var kicker := Label.new()
	kicker.text = "AKTUELLER BEZIRK"
	kicker.add_theme_color_override("font_color", COLOR_GREEN)
	kicker.add_theme_font_size_override("font_size", 11)
	column.add_child(kicker)
	_district_title = Label.new()
	_district_title.text = "Signalplatz"
	_district_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_district_title.add_theme_color_override("font_color", COLOR_TEXT)
	_district_title.add_theme_font_size_override("font_size", 20)
	column.add_child(_district_title)
	_district_description = Label.new()
	_district_description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_district_description.add_theme_color_override("font_color", COLOR_MUTED)
	_district_description.add_theme_font_size_override("font_size", 12)
	column.add_child(_district_description)
	_district_meta = Label.new()
	_district_meta.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_district_meta.add_theme_color_override("font_color", COLOR_CYAN)
	_district_meta.add_theme_font_size_override("font_size", 11)
	column.add_child(_district_meta)
	column.add_child(_separator())
	var residents_title := Label.new()
	residents_title.text = "BEWOHNER & MENTOREN"
	residents_title.add_theme_color_override("font_color", COLOR_GOLD)
	residents_title.add_theme_font_size_override("font_size", 12)
	column.add_child(residents_title)
	_resident_list = VBoxContainer.new()
	_resident_list.add_theme_constant_override("separation", 7)
	column.add_child(_resident_list)
	return panel

func _build_map_panel() -> PanelContainer:
	var panel := PanelContainer.new()
	panel.name = "SettlementMapPanel"
	panel.custom_minimum_size = Vector2(620, 620)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", _panel_style(Color("030817"), Color(COLOR_CYAN, 0.50), 20, 1))
	_map = SettlementMap.new()
	_map.name = "SettlementMap"
	_map.custom_minimum_size = Vector2(600, 600)
	_map.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_map.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_map.connect("district_selected", Callable(self, "_on_district_selected"))
	_map.connect("route_finished", Callable(self, "_on_route_finished"))
	panel.add_child(_map)
	return panel

func _build_right_panel() -> PanelContainer:
	var panel := PanelContainer.new()
	panel.name = "WorldActionPanel"
	panel.custom_minimum_size = Vector2(280, 620)
	panel.add_theme_stylebox_override("panel", _panel_style(Color(COLOR_CARD, 0.92), Color(COLOR_VIOLET, 0.42), 20, 1))
	var margin := _card_margin()
	panel.add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 9)
	margin.add_child(column)
	var encounter_title := Label.new()
	encounter_title.text = "BEGEGNUNG"
	encounter_title.add_theme_color_override("font_color", COLOR_VIOLET)
	encounter_title.add_theme_font_size_override("font_size", 12)
	column.add_child(encounter_title)
	_encounter_label = Label.new()
	_encounter_label.text = "Die Siedlung wartet auf eure nächste Entscheidung."
	_encounter_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_encounter_label.add_theme_color_override("font_color", COLOR_TEXT)
	_encounter_label.add_theme_font_size_override("font_size", 12)
	column.add_child(_encounter_label)
	_secret_button = Button.new()
	_secret_button.text = "VERBORGENE SIGNATUR UNTERSUCHEN"
	_secret_button.custom_minimum_size = Vector2(0, 50)
	_secret_button.add_theme_stylebox_override("normal", _button_style(Color(COLOR_VIOLET, 0.10), Color(COLOR_VIOLET, 0.52), 14))
	_secret_button.pressed.connect(_investigate_secret)
	column.add_child(_secret_button)
	column.add_child(_separator())
	var expedition_title := Label.new()
	expedition_title.text = "EXPEDITIONEN"
	expedition_title.add_theme_color_override("font_color", COLOR_MAGENTA)
	expedition_title.add_theme_font_size_override("font_size", 12)
	column.add_child(expedition_title)
	_expedition_select = OptionButton.new()
	_expedition_select.custom_minimum_size = Vector2(0, 48)
	column.add_child(_expedition_select)
	_expedition_button = Button.new()
	_expedition_button.text = "EXPEDITION STARTEN"
	_expedition_button.custom_minimum_size = Vector2(0, 52)
	_expedition_button.add_theme_stylebox_override("normal", _button_style(Color(COLOR_MAGENTA, 0.12), Color(COLOR_MAGENTA, 0.56), 14))
	_expedition_button.pressed.connect(_start_selected_expedition)
	column.add_child(_expedition_button)
	_expedition_status = Label.new()
	_expedition_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_expedition_status.add_theme_color_override("font_color", COLOR_MUTED)
	_expedition_status.add_theme_font_size_override("font_size", 11)
	column.add_child(_expedition_status)
	_choice_row = HBoxContainer.new()
	_choice_row.add_theme_constant_override("separation", 5)
	column.add_child(_choice_row)
	for choice in ["observe", "assist", "experiment", "rest"]:
		var button := Button.new()
		button.text = {"observe": "BEOBACHTEN", "assist": "HELFEN", "experiment": "VERSUCHEN", "rest": "RUHEN"}[choice]
		button.custom_minimum_size = Vector2(0, 46)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.add_theme_font_size_override("font_size", 9)
		button.pressed.connect(_advance_expedition.bind(choice))
		_choice_row.add_child(button)
	return panel

func _connect_service() -> void:
	var service := get_node_or_null("/root/SignalSettlement")
	if service == null:
		return
	if service.has_signal("settlement_changed"):
		var callback := Callable(self, "_on_settlement_changed")
		if not service.is_connected("settlement_changed", callback):
			service.connect("settlement_changed", callback)
	_refresh()

func _refresh() -> void:
	var service := get_node_or_null("/root/SignalSettlement")
	if service == null or not service.has_method("get_snapshot"):
		return
	var snapshot: Dictionary = service.call("get_snapshot")
	_map.call("set_snapshot", snapshot)
	_rank_label.text = "%s · GENERATION %d · %d BEWOHNER" % [
		str(snapshot.get("settlement_rank_name", "SIGNALPOSTEN")),
		int(snapshot.get("generation", 1)),
		int(snapshot.get("citizen_count", 0))
	]
	var district: Dictionary = snapshot.get("current_district_data", {})
	_district_title.text = str(district.get("label", "Unbekannter Bezirk"))
	_district_description.text = str(district.get("description", ""))
	_district_meta.text = "BESUCHE %d · MEISTERSCHAFT %d%% · %s" % [
		int((snapshot.get("district_visits", {}) as Dictionary).get(str(district.get("id", "")), 0)),
		int((snapshot.get("district_mastery", {}) as Dictionary).get(str(district.get("id", "")), 0.0)),
		str(district.get("facility", "keine Einrichtung")).replace("_", " ").to_upper()
	]
	_rebuild_residents(district.get("citizens", []) as Array)
	var encounter: Dictionary = snapshot.get("last_encounter", {})
	_encounter_label.text = str(encounter.get("message", "Die Siedlung wartet auf eure nächste Entscheidung."))
	_secret_button.disabled = str(district.get("id", "")) in ["academy_quarter", "expedition_gate"]
	_rebuild_expeditions(snapshot)
	_apply_responsive_layout()

func _rebuild_residents(citizens: Array) -> void:
	for child in _resident_list.get_children():
		child.queue_free()
	if citizens.is_empty():
		var empty := Label.new()
		empty.text = "Noch niemand wohnt dauerhaft in diesem Bezirk."
		empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		empty.add_theme_color_override("font_color", COLOR_MUTED)
		empty.add_theme_font_size_override("font_size", 11)
		_resident_list.add_child(empty)
		return
	for citizen_variant in citizens:
		if not citizen_variant is Dictionary:
			continue
		var citizen := citizen_variant as Dictionary
		var button := Button.new()
		button.text = "%s · %s\nTECHNIK: %s · BINDUNG %d%%" % [
			str(citizen.get("name", "Unbekannt")),
			str(citizen.get("role", "Bewohner")),
			str(citizen.get("technique", "-")).replace("_", " ").to_upper(),
			int(citizen.get("bond", 0.0))
		]
		button.custom_minimum_size = Vector2(0, 66)
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		button.add_theme_font_size_override("font_size", 10)
		button.add_theme_stylebox_override("normal", _button_style(Color(COLOR_GOLD, 0.07), Color(COLOR_GOLD, 0.30), 13))
		button.pressed.connect(_train_with_mentor.bind(str(citizen.get("id", ""))))
		_resident_list.add_child(button)

func _rebuild_expeditions(snapshot: Dictionary) -> void:
	_expedition_select.clear()
	_expedition_ids.clear()
	for expedition_variant in snapshot.get("expeditions", []):
		if not expedition_variant is Dictionary:
			continue
		var expedition := expedition_variant as Dictionary
		var region_id := str(expedition.get("id", ""))
		_expedition_ids.append(region_id)
		var prefix := "✓ " if not (expedition.get("record", {}) as Dictionary).is_empty() else ""
		var locked := not bool(expedition.get("unlocked", false))
		_expedition_select.add_item("%s%s · RISIKO %s%s" % [prefix, str(expedition.get("label", region_id)), str(expedition.get("risk", "?")), " · GESPERRT" if locked else ""])
		_expedition_select.set_item_disabled(_expedition_select.item_count - 1, locked)
	var active: Dictionary = snapshot.get("active_expedition", {})
	var active_now := not active.is_empty()
	_expedition_button.disabled = active_now or str(snapshot.get("current_district", "")) != "expedition_gate"
	_choice_row.visible = active_now
	if active_now:
		_expedition_status.text = "%s · SCHRITT %d/%d · EMPFOHLEN: %s" % [
			str(active.get("label", "Expedition")),
			int(active.get("progress", 0)),
			int(active.get("steps", 1)),
			str(active.get("recommended_technique", "-")).replace("_", " ").to_upper()
		]
	else:
		_expedition_status.text = "Reise zuerst zum Expeditionstor. Vier Regionen besitzen eigene Risiken, Techniken und Weltfolgen."

func _on_district_selected(district_id: String) -> void:
	var service := get_node_or_null("/root/SignalSettlement")
	if service == null or not service.has_method("travel_to"):
		return
	var result: Dictionary = service.call("travel_to", district_id)
	if not bool(result.get("accepted", false)):
		_status.text = "Dieser Weg ist noch nicht zugänglich."
		return
	var route: Array = result.get("route", [])
	_map.call("play_route", route)
	_status.text = "Unterwegs nach %s …" % str((service.call("get_district_data", district_id) as Dictionary).get("label", district_id))
	var audio := get_node_or_null("/root/OmniAudio")
	if audio != null and audio.has_method("play_action"):
		audio.call("play_action", "explore", 0.86)
	_refresh()

func _on_route_finished(_district_id: String) -> void:
	_status.text = "Angekommen. Bewohner, Geheimnisse und Möglichkeiten reagieren auf euren Besuch."
	_refresh()

func _train_with_mentor(citizen_id: String) -> void:
	var service := get_node_or_null("/root/SignalSettlement")
	if service == null:
		return
	var result: Dictionary = service.call("train_with_mentor", citizen_id)
	if bool(result.get("accepted", false)):
		_status.text = "%s trainiert %s mit euch. Mentorenbindung: %d%%." % [str(result.get("mentor_name", "Mentor")), str(result.get("technique", "Technik")).replace("_", " "), int(result.get("bond", 0.0))]
	else:
		_status.text = "Diese Mentorenstunde ist gerade nicht verfügbar."
	_refresh()

func _investigate_secret() -> void:
	var service := get_node_or_null("/root/SignalSettlement")
	if service == null:
		return
	var result: Dictionary = service.call("investigate_current_district")
	if bool(result.get("accepted", false)) and result.has("secret"):
		_status.text = "%s · Abschnitt %d/%d%s" % [str(result.get("label", "Geheimnis")), int(result.get("stage", 0)), int(result.get("stages", 1)), " · GELÖST" if bool(result.get("completed", false)) else ""]
	else:
		_status.text = str(result.get("message", "Hier reagiert gerade keine verborgene Signatur."))
	_refresh()

func _start_selected_expedition() -> void:
	if _expedition_select.selected < 0 or _expedition_select.selected >= _expedition_ids.size():
		return
	var service := get_node_or_null("/root/SignalSettlement")
	if service == null:
		return
	var result: Dictionary = service.call("start_expedition", _expedition_ids[_expedition_select.selected])
	_status.text = "Expedition gestartet." if bool(result.get("accepted", false)) else "Expedition kann hier noch nicht beginnen."
	_refresh()

func _advance_expedition(choice: String) -> void:
	var service := get_node_or_null("/root/SignalSettlement")
	if service == null:
		return
	var result: Dictionary = service.call("advance_expedition", choice)
	if bool(result.get("completed", false)):
		_status.text = "Expedition abgeschlossen · Qualität %d%% · die Siedlung hat sich verändert." % int(float(result.get("final_score", 0.0)) * 100.0)
	elif bool(result.get("accepted", false)):
		_status.text = "Entscheidung gespeichert · Schritt %d/%d." % [int(result.get("progress", 0)), int(result.get("steps", 1))]
	else:
		_status.text = "Diese Expeditionsentscheidung ist nicht verfügbar."
	_refresh()

func _on_settlement_changed(_snapshot: Dictionary) -> void:
	if is_open():
		_refresh()

func _open_partner_dashboard() -> void:
	close_world()
	var overlay := get_node_or_null("/root/PartnerWorldOverlay")
	if overlay != null and overlay.has_method("open_partner_world"):
		overlay.call("open_partner_world")

func _apply_responsive_layout() -> void:
	if _body == null:
		return
	var design_width := get_viewport().get_visible_rect().size.x
	var physical_width := float(get_tree().root.size.x)
	var width := minf(design_width, physical_width) if physical_width > 0.0 else design_width
	_compact = width < 760.0
	var medium := width < 1180.0
	if _compact or medium:
		_body.columns = 1
		_body.move_child(_map_panel, 0)
		_body.move_child(_left_panel, 1)
		_body.move_child(_right_panel, 2)
		_map_panel.custom_minimum_size = Vector2(0, 430 if _compact else 540)
		_left_panel.custom_minimum_size = Vector2(0, 330)
		_right_panel.custom_minimum_size = Vector2(0, 390)
		_body_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	else:
		_body.columns = 3
		_body.move_child(_left_panel, 0)
		_body.move_child(_map_panel, 1)
		_body.move_child(_right_panel, 2)
		_left_panel.custom_minimum_size = Vector2(260, 620)
		_map_panel.custom_minimum_size = Vector2(620, 620)
		_right_panel.custom_minimum_size = Vector2(280, 620)
		_body_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_map.custom_minimum_size = _map_panel.custom_minimum_size
	_close_button.custom_minimum_size = Vector2(44, 44) if _compact else Vector2(48, 48)

func _card_margin() -> MarginContainer:
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_top", 14)
	margin.add_theme_constant_override("margin_bottom", 14)
	return margin

func _separator() -> HSeparator:
	var separator := HSeparator.new()
	separator.add_theme_constant_override("separation", 8)
	return separator

func _panel_style(background: Color, border: Color, radius: int, border_width: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(radius)
	style.content_margin_left = 10.0
	style.content_margin_right = 10.0
	style.content_margin_top = 10.0
	style.content_margin_bottom = 10.0
	return style

func _button_style(background: Color, border: Color, radius: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(radius)
	style.content_margin_left = 8.0
	style.content_margin_right = 8.0
	style.content_margin_top = 7.0
	style.content_margin_bottom = 7.0
	return style
