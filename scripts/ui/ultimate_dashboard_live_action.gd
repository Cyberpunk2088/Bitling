extends "res://scripts/ui/ultimate_dashboard_consequences.gd"

## Removes the central dashboard-card interaction from the primary loop. The
## moment, Xogot's approach and the three choices are rendered inside the stage.
## Existing buttons remain hidden compatibility/accessibility fallbacks.

var live_action_phase_label: Label
var live_action_instruction_label: Label
var _moment_card: Control
var _choice_card: Control

func _build_center_panel() -> PanelContainer:
	var panel := super._build_center_panel()
	var column := panel.get_child(0) as VBoxContainer
	_moment_card = column.find_child("ActiveHabitatMoment", true, false) as Control
	_choice_card = column.find_child("HabitatChoiceCard", true, false) as Control
	if _moment_card != null:
		_moment_card.visible = false
	if _choice_card != null:
		_choice_card.visible = false
	if stage != null:
		stage.custom_minimum_size = Vector2(420.0, 650.0)
		if stage.has_signal("live_action_choice_pressed"):
			var stage_callback := Callable(self, "_on_live_action_choice_pressed")
			if not stage.is_connected("live_action_choice_pressed", stage_callback):
				stage.connect("live_action_choice_pressed", stage_callback)

	var rail := PanelContainer.new()
	rail.name = "LiveActionStatusRail"
	rail.add_theme_stylebox_override("panel", _panel_style(Color("071126"), Color(COLOR_CYAN, 0.34), 12, 1))
	var rail_row := HBoxContainer.new()
	rail_row.add_theme_constant_override("separation", 10)
	rail.add_child(rail_row)
	live_action_phase_label = _chip("XOGOT IST BEREIT", COLOR_CYAN)
	live_action_phase_label.custom_minimum_size = Vector2(150.0, 32.0)
	rail_row.add_child(live_action_phase_label)
	live_action_instruction_label = Label.new()
	live_action_instruction_label.text = "Tippe ein Objekt im Raum. Xogot geht selbst hin."
	live_action_instruction_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	live_action_instruction_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	live_action_instruction_label.add_theme_color_override("font_color", COLOR_MUTED)
	live_action_instruction_label.add_theme_font_size_override("font_size", 11)
	rail_row.add_child(live_action_instruction_label)
	column.add_child(rail)
	var stage_parent := stage.get_parent()
	if stage_parent == column:
		column.move_child(rail, stage.get_index() + 1)
	return panel

func _connect_runtime_signals() -> void:
	super._connect_runtime_signals()
	var service := _habitat()
	if service == null:
		return
	var bindings := {
		"live_action_changed": Callable(self, "_on_live_action_changed"),
		"live_action_completed": Callable(self, "_on_live_action_completed")
	}
	for signal_variant in bindings.keys():
		var signal_name := str(signal_variant)
		var callback: Callable = bindings[signal_name]
		if service.has_signal(signal_name) and not service.is_connected(signal_name, callback):
			service.connect(signal_name, callback)

func _refresh_habitat() -> void:
	super._refresh_habitat()
	var service := _habitat()
	if service != null and service.has_method("get_live_action_snapshot"):
		_apply_live_action(service.call("get_live_action_snapshot") as Dictionary)

func _apply_lens(lens_id: String, options: Array) -> void:
	super._apply_lens(lens_id, options)
	var service := _habitat()
	if service != null and service.has_method("get_live_action_snapshot"):
		_apply_live_action(service.call("get_live_action_snapshot") as Dictionary)

func _on_hotspot_pressed(hotspot_id: String) -> void:
	var service := _habitat()
	if service == null or not service.has_method("start_encounter"):
		super._on_hotspot_pressed(hotspot_id)
		return
	var started: Dictionary = service.call("start_encounter", hotspot_id, "player", true) as Dictionary
	if bool(started.get("accepted", false)):
		_apply_live_action(started.get("snapshot", {}) as Dictionary)
		message_label.text = "%s ist jetzt die Bühne. Xogot nähert sich selbstständig." % _hotspot_label(hotspot_id)
	else:
		message_label.text = "Xogot beendet zuerst die laufende Handlung."

func _on_stage_pressed() -> void:
	_on_hotspot_pressed("bitling")

func _on_habitat_choice_index(index: int) -> void:
	if index < 0 or index >= habitat_choice_buttons.size():
		return
	var choice_id := str(habitat_choice_buttons[index].get_meta("choice_id", ""))
	_on_live_action_choice_pressed(choice_id)

func _on_live_action_choice_pressed(choice_id: String) -> void:
	if choice_id.is_empty():
		return
	var service := _habitat()
	if service == null or not service.has_method("begin_choice_sequence"):
		return
	var response: Dictionary = service.call("begin_choice_sequence", choice_id) as Dictionary
	if not bool(response.get("accepted", false)):
		message_label.text = "Diese Handlung ist erst möglich, wenn Xogot die Situation gelesen hat."
		return
	message_label.text = "Xogot führt die gewählte Absicht jetzt sichtbar im Raum aus."

func _on_live_action_changed(snapshot: Dictionary) -> void:
	_apply_live_action(snapshot)

func _on_live_action_completed(result: Dictionary) -> void:
	message_label.text = "%s Die Konsequenz wurde erst nach Xogots Handlung gespeichert." % str(result.get("response", "Xogot hat gehandelt."))
	_refresh_habitat()

func _apply_live_action(snapshot: Dictionary) -> void:
	if stage != null and stage.has_method("set_live_action_snapshot"):
		stage.call("set_live_action_snapshot", snapshot)
	if live_action_phase_label == null:
		return
	var active := bool(snapshot.get("active", false))
	var phase := str(snapshot.get("phase", "idle"))
	var source := str(snapshot.get("source", "none"))
	var choice_count := int(snapshot.get("choice_count", 0))
	live_action_phase_label.text = _live_phase_label(phase)
	live_action_phase_label.add_theme_color_override("font_color", _live_phase_color(phase))
	if not active:
		live_action_instruction_label.text = "Tippe ein Objekt im Raum. Nach 24 Sekunden startet Xogot selbst eine Initiative."
	elif phase == "approach":
		live_action_instruction_label.text = "Xogot geht selbst zum %s." % _hotspot_label(str(snapshot.get("hotspot", "bitling")))
	elif phase == "observe":
		live_action_instruction_label.text = "Xogot liest erst die Situation. Noch wird nichts entschieden."
	elif phase == "awaiting_choice":
		live_action_instruction_label.text = "%d Möglichkeiten liegen direkt im Raum. Quelle: %s." % [choice_count, "Xogot" if source == "xogot" else "du"]
	elif phase == "perform":
		live_action_instruction_label.text = "Die Wahl ist gesperrt. Xogot handelt; Werte und Welt sind noch nicht verbucht."
	else:
		live_action_instruction_label.text = "Die sichtbare Handlung wird jetzt zur bleibenden Folge."
	var locked := active and phase in ["perform", "aftermath"]
	for button_variant in action_buttons.values():
		(button_variant as Button).disabled = locked

func _apply_responsive_layout() -> void:
	super._apply_responsive_layout()
	if stage != null:
		stage.custom_minimum_size = Vector2(0.0, 590.0 if _compact else 650.0)
	if live_action_instruction_label != null:
		live_action_instruction_label.add_theme_font_size_override("font_size", 10 if _compact else 11)

func get_live_action_ui_snapshot() -> Dictionary:
	var service := _habitat()
	var live: Dictionary = service.call("get_live_action_snapshot") as Dictionary if service != null and service.has_method("get_live_action_snapshot") else {}
	var stage_snapshot: Dictionary = stage.call("get_habitat_interaction_snapshot") as Dictionary if stage != null and stage.has_method("get_habitat_interaction_snapshot") else {}
	return {
		"live_action": live,
		"stage_live_action_overlay_ready": bool(stage_snapshot.get("live_action_overlay_ready", false)),
		"stage_live_action_visual": stage_snapshot.get("live_action_visual", {}),
		"dashboard_moment_card_hidden": _moment_card != null and not _moment_card.visible,
		"dashboard_choice_card_hidden": _choice_card != null and not _choice_card.visible,
		"in_world_choice_surface": bool((stage_snapshot.get("live_action_visual", {}) as Dictionary).get("in_world_choice_surface", false)),
		"center_is_game": stage != null,
		"deferred_commit": true
	}

func _live_phase_label(phase: String) -> String:
	return str({
		"idle": "RAUM IST OFFEN",
		"approach": "XOGOT GEHT HIN",
		"observe": "XOGOT BEOBACHTET",
		"awaiting_choice": "WÄHLE IM RAUM",
		"perform": "XOGOT HANDELT",
		"aftermath": "FOLGE ENTSTEHT"
	}.get(phase, phase.to_upper()))

func _live_phase_color(phase: String) -> Color:
	return {
		"idle": COLOR_CYAN,
		"approach": COLOR_VIOLET,
		"observe": COLOR_YELLOW,
		"awaiting_choice": COLOR_GREEN,
		"perform": COLOR_MAGENTA,
		"aftermath": COLOR_CYAN
	}.get(phase, COLOR_CYAN) as Color
