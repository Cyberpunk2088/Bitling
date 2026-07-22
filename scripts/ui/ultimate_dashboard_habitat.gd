extends "res://scripts/ui/ultimate_dashboard.gd"

## Enforces the product promise: the dashboard is not a launcher around the
## game. The visible home is the game, and every primary action is contextual.

const HabitatStage := preload("res://scripts/ui/bitling_habitat_stage.gd")

var habitat_moment_title: Label
var habitat_moment_description: Label
var habitat_moment_prompt: Label
var habitat_location_label: Label
var habitat_lens_label: Label
var habitat_consequence_label: Label
var habitat_status_label: Label
var habitat_memory_label: Label
var habitat_choice_grid: GridContainer
var habitat_choice_buttons: Array[Button] = []
var _last_habitat_result: Dictionary = {}

func _build_center_panel() -> PanelContainer:
	var panel: PanelContainer = super._build_center_panel()
	var column := panel.get_child(0) as VBoxContainer

	var old_stage := stage
	var stage_parent := old_stage.get_parent()
	var stage_index := old_stage.get_index()
	stage_parent.remove_child(old_stage)
	old_stage.queue_free()
	stage = HabitatStage.new()
	stage.name = "LivingHabitatStage"
	stage.custom_minimum_size = Vector2(390.0, 500.0)
	stage.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stage.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stage.bitling_pressed.connect(_on_stage_pressed)
	stage.hotspot_pressed.connect(_on_hotspot_pressed)
	stage_parent.add_child(stage)
	stage_parent.move_child(stage, stage_index)

	var moment_card := PanelContainer.new()
	moment_card.name = "ActiveHabitatMoment"
	moment_card.add_theme_stylebox_override("panel", _panel_style(Color("0b1730"), Color(COLOR_CYAN, 0.48), 16, 1))
	var moment_column := VBoxContainer.new()
	moment_column.add_theme_constant_override("separation", 5)
	moment_card.add_child(moment_column)
	var moment_header := HBoxContainer.new()
	moment_column.add_child(moment_header)
	habitat_location_label = _chip("HABITAT", COLOR_CYAN)
	habitat_location_label.custom_minimum_size = Vector2(106.0, 30.0)
	moment_header.add_child(habitat_location_label)
	var moment_spacer := Control.new()
	moment_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	moment_header.add_child(moment_spacer)
	habitat_lens_label = _chip("BEGLEITEN", COLOR_MAGENTA)
	habitat_lens_label.custom_minimum_size = Vector2(118.0, 30.0)
	moment_header.add_child(habitat_lens_label)
	habitat_moment_title = Label.new()
	habitat_moment_title.text = "Ein stiller Moment"
	habitat_moment_title.add_theme_color_override("font_color", COLOR_TEXT)
	habitat_moment_title.add_theme_font_size_override("font_size", 17)
	moment_column.add_child(habitat_moment_title)
	habitat_moment_description = Label.new()
	habitat_moment_description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	habitat_moment_description.add_theme_color_override("font_color", COLOR_MUTED)
	habitat_moment_description.add_theme_font_size_override("font_size", 12)
	moment_column.add_child(habitat_moment_description)
	habitat_moment_prompt = Label.new()
	habitat_moment_prompt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	habitat_moment_prompt.add_theme_color_override("font_color", COLOR_CYAN)
	habitat_moment_prompt.add_theme_font_size_override("font_size", 12)
	moment_column.add_child(habitat_moment_prompt)
	column.add_child(moment_card)
	column.move_child(moment_card, stage_index)

	var action_grid := column.find_child("PrimaryActions", false, false) as GridContainer
	if action_grid != null:
		(action_buttons.get("feed") as Button).text = "ANBIETEN\nNahrung & Wahl"
		(action_buttons.get("play") as Button).text = "IMPULS\nSpiel & Regeln"
		(action_buttons.get("learn") as Button).text = "FRAGEN\nMuster & Wissen"
		(action_buttons.get("care") as Button).text = "BEGLEITEN\nNähe & Raum"
		(action_buttons.get("rest") as Button).text = "BERUHIGEN\nRitual & Schlaf"

	var choice_card := PanelContainer.new()
	choice_card.name = "HabitatChoiceCard"
	choice_card.add_theme_stylebox_override("panel", _panel_style(Color("0a1022"), Color(COLOR_VIOLET, 0.50), 16, 1))
	var choice_column := VBoxContainer.new()
	choice_column.add_theme_constant_override("separation", 8)
	choice_card.add_child(choice_column)
	var choice_title := Label.new()
	choice_title.text = "DEINE HALTUNG — XOGOTS REAKTION BLEIBT EIGENSTÄNDIG"
	choice_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	choice_title.add_theme_color_override("font_color", COLOR_MUTED)
	choice_title.add_theme_font_size_override("font_size", 11)
	choice_column.add_child(choice_title)
	habitat_choice_grid = GridContainer.new()
	habitat_choice_grid.name = "HabitatChoices"
	habitat_choice_grid.columns = 3
	habitat_choice_grid.add_theme_constant_override("h_separation", 8)
	habitat_choice_grid.add_theme_constant_override("v_separation", 8)
	choice_column.add_child(habitat_choice_grid)
	for index in range(3):
		var choice_button := Button.new()
		choice_button.name = "HabitatChoice%d" % (index + 1)
		choice_button.custom_minimum_size = Vector2(150.0, 74.0)
		choice_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		choice_button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		choice_button.add_theme_font_size_override("font_size", 11)
		choice_button.add_theme_stylebox_override("normal", _button_style(COLOR_PANEL_ALT, COLOR_VIOLET, 14))
		choice_button.add_theme_stylebox_override("hover", _button_style(COLOR_PANEL_BRIGHT, COLOR_CYAN, 14))
		choice_button.add_theme_stylebox_override("pressed", _button_style(Color(COLOR_VIOLET, 0.28), COLOR_CYAN, 14))
		choice_button.pressed.connect(_on_habitat_choice_index.bind(index))
		habitat_choice_grid.add_child(choice_button)
		habitat_choice_buttons.append(choice_button)
	habitat_consequence_label = Label.new()
	habitat_consequence_label.text = "Wähle zuerst eine Haltung. Keine Auswahl ist bloß ein Status-Button."
	habitat_consequence_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	habitat_consequence_label.add_theme_color_override("font_color", COLOR_MUTED)
	habitat_consequence_label.add_theme_font_size_override("font_size", 12)
	choice_column.add_child(habitat_consequence_label)
	column.add_child(choice_card)
	var recommendation := recommendation_label.get_parent().get_parent()
	column.move_child(choice_card, recommendation.get_index())
	return panel

func _build_right_panel() -> PanelContainer:
	var panel: PanelContainer = super._build_right_panel()
	var column := panel.get_child(0) as VBoxContainer
	var title := _section_title("AKTIVE SITUATION")
	column.add_child(title)
	column.move_child(title, 0)
	var situation_card := PanelContainer.new()
	situation_card.name = "HabitatSituationSummary"
	situation_card.add_theme_stylebox_override("panel", _panel_style(Color("101a35"), Color(COLOR_CYAN, 0.38), 15, 1))
	var situation_column := VBoxContainer.new()
	situation_column.add_theme_constant_override("separation", 7)
	situation_card.add_child(situation_column)
	habitat_status_label = Label.new()
	habitat_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	habitat_status_label.add_theme_color_override("font_color", COLOR_TEXT)
	habitat_status_label.add_theme_font_size_override("font_size", 13)
	situation_column.add_child(habitat_status_label)
	var rule := Label.new()
	rule.text = "Du kontrollierst den Kontext. Xogot kontrolliert seine Reaktion."
	rule.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rule.add_theme_color_override("font_color", COLOR_CYAN)
	rule.add_theme_font_size_override("font_size", 11)
	situation_column.add_child(rule)
	column.add_child(situation_card)
	column.move_child(situation_card, 1)

	var memory_title := _section_title("LETZTE GEMEINSAME FOLGE")
	column.add_child(memory_title)
	var memory_card := PanelContainer.new()
	memory_card.add_theme_stylebox_override("panel", _panel_style(COLOR_PANEL_ALT, Color(COLOR_MAGENTA, 0.34), 15, 1))
	habitat_memory_label = Label.new()
	habitat_memory_label.text = "Noch keine Entscheidung in diesem Habitat."
	habitat_memory_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	habitat_memory_label.add_theme_color_override("font_color", COLOR_MUTED)
	habitat_memory_label.add_theme_font_size_override("font_size", 11)
	memory_card.add_child(habitat_memory_label)
	column.add_child(memory_card)
	return panel

func _connect_runtime_signals() -> void:
	super._connect_runtime_signals()
	var service := _habitat()
	if service == null:
		return
	var bindings := {
		"moment_changed": Callable(self, "_on_habitat_moment_changed"),
		"lens_changed": Callable(self, "_on_habitat_lens_changed"),
		"choice_resolved": Callable(self, "_on_habitat_choice_resolved"),
		"hotspot_focused": Callable(self, "_on_habitat_hotspot_focused")
	}
	for signal_variant in bindings.keys():
		var signal_name := str(signal_variant)
		var callback: Callable = bindings[signal_name]
		if service.has_signal(signal_name) and not service.is_connected(signal_name, callback):
			service.connect(signal_name, callback)

func _refresh_all() -> void:
	super._refresh_all()
	_refresh_habitat()

func _refresh_habitat() -> void:
	var service := _habitat()
	if service == null or habitat_moment_title == null:
		return
	var snapshot: Dictionary = service.call("get_snapshot") as Dictionary
	var moment: Dictionary = snapshot.get("active_moment", {}) as Dictionary
	_apply_moment(moment)
	_apply_lens(str(snapshot.get("selected_lens", "care")), service.call("get_lens_options") as Array)
	var recent: Array = snapshot.get("recent_outcomes", []) as Array
	if not recent.is_empty() and _last_habitat_result.is_empty():
		_last_habitat_result = (recent.back() as Dictionary).duplicate(true)
	_apply_last_result()

func _apply_moment(moment: Dictionary) -> void:
	if moment.is_empty() or habitat_moment_title == null:
		return
	habitat_moment_title.text = str(moment.get("title", "Gemeinsamer Moment"))
	habitat_moment_description.text = str(moment.get("description", "Xogot wartet auf deine Haltung."))
	habitat_moment_prompt.text = str(moment.get("prompt", "Wie reagierst du?"))
	var hotspot := str(moment.get("hotspot", "bitling"))
	habitat_location_label.text = _hotspot_label(hotspot)
	if habitat_status_label != null:
		habitat_status_label.text = "%s\nEmpfohlen: %s" % [habitat_moment_title.text, _lens_label(str(moment.get("recommended_lens", "care")))]
	if stage != null:
		stage.call("set_focused_hotspot", hotspot)
		stage.call("set_moment_title", habitat_moment_title.text)

func _apply_lens(lens_id: String, options: Array) -> void:
	if habitat_lens_label == null:
		return
	var accent := _lens_color(lens_id)
	habitat_lens_label.text = _lens_label(lens_id)
	habitat_lens_label.add_theme_color_override("font_color", accent)
	if stage != null:
		stage.call("set_activity_lens", lens_id)
	for index in range(habitat_choice_buttons.size()):
		var button := habitat_choice_buttons[index]
		button.visible = index < options.size()
		button.disabled = index >= options.size()
		if index < options.size():
			var option := options[index] as Dictionary
			button.set_meta("choice_id", str(option.get("id", "")))
			button.text = "%s\n%s" % [str(option.get("title", "Wählen")).to_upper(), str(option.get("detail", ""))]
			button.add_theme_stylebox_override("normal", _button_style(Color(accent, 0.09), Color(accent, 0.72), 14))
			button.add_theme_stylebox_override("pressed", _button_style(Color(accent, 0.28), accent, 14))
	_update_action_button_states(lens_id)

func _apply_last_result() -> void:
	if _last_habitat_result.is_empty():
		return
	if habitat_consequence_label != null:
		habitat_consequence_label.text = "%s  •  +%d XP" % [str(_last_habitat_result.get("consequence", "Der Moment wurde gespeichert.")), int(_last_habitat_result.get("xp_reward", 0))]
		habitat_consequence_label.add_theme_color_override("font_color", COLOR_GREEN if bool(_last_habitat_result.get("resonant", false)) else COLOR_CYAN)
	if habitat_memory_label != null:
		habitat_memory_label.text = "%s\n%s" % [str(_last_habitat_result.get("choice_title", "Entscheidung")), str(_last_habitat_result.get("response", ""))]

func _select_lens(lens_id: String) -> void:
	var service := _habitat()
	if service == null:
		return
	var options: Array = service.call("select_lens", lens_id) as Array
	_apply_lens(lens_id, options)
	message_label.text = "%s ist jetzt deine Haltung. Wähle eine konkrete Form, statt einen Wert direkt zu füllen." % _lens_label(lens_id)
	stage.call("play_reaction")

func _on_habitat_choice_index(index: int) -> void:
	if index < 0 or index >= habitat_choice_buttons.size():
		return
	var choice_id := str(habitat_choice_buttons[index].get_meta("choice_id", ""))
	if choice_id.is_empty():
		return
	var service := _habitat()
	if service != null:
		service.call("resolve_choice", choice_id)

func _on_habitat_choice_resolved(result: Dictionary) -> void:
	if not bool(result.get("accepted", false)):
		return
	_last_habitat_result = result.duplicate(true)
	message_label.text = str(result.get("response", "Xogot reagiert."))
	stage.call("play_reaction")
	_apply_last_result()

func _on_habitat_moment_changed(moment: Dictionary) -> void:
	_apply_moment(moment)

func _on_habitat_lens_changed(lens_id: String, options: Array) -> void:
	_apply_lens(lens_id, options)

func _on_habitat_hotspot_focused(hotspot_id: String) -> void:
	if stage != null:
		stage.call("set_focused_hotspot", hotspot_id)

func _on_hotspot_pressed(hotspot_id: String) -> void:
	var service := _habitat()
	if service == null:
		return
	var moment: Dictionary = service.call("focus_hotspot", hotspot_id) as Dictionary
	var recommended := str(moment.get("recommended_lens", "care"))
	service.call("select_lens", recommended)
	message_label.text = "%s ist jetzt Teil der Situation. Xogot zeigt dir einen möglichen Zugang — die Entscheidung bleibt bei dir." % _hotspot_label(hotspot_id)

func _on_stage_pressed() -> void:
	_on_hotspot_pressed("bitling")

func _on_feed_pressed() -> void:
	_select_lens("feed")

func _on_play_pressed() -> void:
	_select_lens("play")

func _on_learn_pressed() -> void:
	_select_lens("learn")

func _on_care_pressed() -> void:
	_select_lens("care")

func _on_rest_pressed() -> void:
	_select_lens("rest")

func _on_navigation_pressed(destination: String) -> void:
	match destination:
		"SPIELE", "MINIGAMES":
			var exploration := get_node_or_null("/root/ExplorationOverlay")
			if exploration != null and exploration.has_method("open_expedition"):
				exploration.call("open_expedition")
		"LERNEN":
			var learning := get_node_or_null("/root/LearningAdventureOverlay")
			if learning != null and learning.has_method("open_adventures"):
				learning.call("open_adventures")
		"PFLEGE":
			_select_lens("care")
		"QUESTS":
			message_label.text = "Quests dokumentieren gemeinsame Folgen; sie ersetzen nicht den Habitat-Moment."
		"FREUNDE":
			message_label.text = "Begegnungen starten nur mit Freigabe und erscheinen anschließend als Situation im Habitat."
		"MEHR":
			_on_profile_pressed()
		_:
			_on_hotspot_pressed("bitling")
	stage.call("play_reaction")

func _apply_responsive_layout() -> void:
	super._apply_responsive_layout()
	if habitat_choice_grid != null:
		habitat_choice_grid.columns = 1 if _compact else 3
	for button in habitat_choice_buttons:
		button.custom_minimum_size = Vector2(0.0, 82.0 if _compact else 74.0)
		button.add_theme_font_size_override("font_size", 12 if _compact else 11)

func get_habitat_ui_snapshot() -> Dictionary:
	return {
		"stage_type": str(stage.get_script().resource_path) if stage != null and stage.get_script() != null else "",
		"choice_count": habitat_choice_buttons.size(),
		"visible_choice_count": habitat_choice_buttons.filter(func(button: Button) -> bool: return button.visible).size(),
		"active_lens": str(_habitat().get("selected_lens")) if _habitat() != null else "",
		"moment_title": habitat_moment_title.text if habitat_moment_title != null else "",
		"compact": _compact,
		"center_is_game": stage != null and habitat_choice_grid != null
	}

func _update_action_button_states(active_lens: String) -> void:
	for lens_variant in action_buttons.keys():
		var lens := str(lens_variant)
		var button := action_buttons[lens] as Button
		var accent := _lens_color(lens)
		var active := lens == active_lens
		button.add_theme_stylebox_override("normal", _button_style(Color(accent, 0.24 if active else 0.07), accent if active else Color(accent, 0.48), 15))
		button.add_theme_color_override("font_color", Color.WHITE if active else COLOR_TEXT)

func _lens_label(lens_id: String) -> String:
	return str({"feed": "ANBIETEN", "play": "IMPULS", "learn": "FRAGEN", "care": "BEGLEITEN", "rest": "BERUHIGEN"}.get(lens_id, lens_id.to_upper()))

func _lens_color(lens_id: String) -> Color:
	return {"feed": COLOR_GREEN, "play": COLOR_VIOLET, "learn": COLOR_CYAN, "care": COLOR_MAGENTA, "rest": COLOR_YELLOW}.get(lens_id, COLOR_CYAN) as Color

func _hotspot_label(hotspot_id: String) -> String:
	return str({"bitling": "XOGOT", "window": "FENSTER", "workbench": "WERKBANK", "plant": "PFLANZE", "platform": "PLATTFORM", "sleep": "RUHEPOD"}.get(hotspot_id, hotspot_id.to_upper()))

func _habitat() -> Node:
	return get_node_or_null("/root/HabitatInteraction")
