extends "res://scripts/ui/ultimate_dashboard_habitat.gd"

## Makes persistent habits and conflict legible. The player sees Xogot's likely
## response before committing; no resistance is hidden or random.

var behavior_pattern_label: Label
var behavior_conflict_label: Label
var behavior_contract_label: Label

func _build_right_panel() -> PanelContainer:
	var panel: PanelContainer = super._build_right_panel()
	var column := panel.get_child(0) as VBoxContainer
	var title := _section_title("GEWOHNHEITEN & REIBUNG")
	column.add_child(title)
	var card := PanelContainer.new()
	card.name = "PersistentBehaviorCard"
	card.add_theme_stylebox_override("panel", _panel_style(Color("0d1328"), Color(COLOR_YELLOW, 0.42), 15, 1))
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 7)
	card.add_child(content)
	behavior_pattern_label = Label.new()
	behavior_pattern_label.text = "Noch keine belastbare Gewohnheit."
	behavior_pattern_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	behavior_pattern_label.add_theme_color_override("font_color", COLOR_TEXT)
	behavior_pattern_label.add_theme_font_size_override("font_size", 12)
	content.add_child(behavior_pattern_label)
	behavior_conflict_label = Label.new()
	behavior_conflict_label.text = "Keine aktive Reibung."
	behavior_conflict_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	behavior_conflict_label.add_theme_color_override("font_color", COLOR_MUTED)
	behavior_conflict_label.add_theme_font_size_override("font_size", 11)
	content.add_child(behavior_conflict_label)
	behavior_contract_label = Label.new()
	behavior_contract_label.text = "Gewohnheiten brauchen mehrere Sessions und verschiedene Situationen. Grenzen sind vor der Wahl sichtbar."
	behavior_contract_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	behavior_contract_label.add_theme_color_override("font_color", COLOR_CYAN)
	behavior_contract_label.add_theme_font_size_override("font_size", 10)
	content.add_child(behavior_contract_label)
	column.add_child(card)
	return panel

func _apply_lens(lens_id: String, options: Array) -> void:
	super._apply_lens(lens_id, options)
	for index in range(mini(habitat_choice_buttons.size(), options.size())):
		var button := habitat_choice_buttons[index]
		var option := options[index] as Dictionary
		var state := str(option.get("behavior_label", "OFFEN"))
		var strength := roundi(float(option.get("habit_strength", 0.0)))
		var friction := roundi(float(option.get("friction", 0.0)))
		button.text += "\nXOGOT: %s · MUSTER %d · REIBUNG %d" % [state, strength, friction]
		button.set_meta("execution_mode", str(option.get("execution_mode", "embraced")))
		button.set_meta("habit_strength", strength)
		button.set_meta("friction", friction)

func _apply_last_result() -> void:
	super._apply_last_result()
	if _last_habitat_result.is_empty():
		return
	var mode := str(_last_habitat_result.get("execution_mode", "embraced"))
	var mode_label := str({"embraced": "AUFGEGRIFFEN", "negotiated": "VERÄNDERT", "resisted": "GRENZE"}.get(mode, mode.to_upper()))
	var strength := roundi(float(_last_habitat_result.get("habit_strength", 0.0)))
	if habitat_consequence_label != null:
		habitat_consequence_label.text += "  •  %s  •  MUSTER %d" % [mode_label, strength]
	_refresh_behavior_panel()

func _refresh_habitat() -> void:
	super._refresh_habitat()
	_refresh_behavior_panel()

func _refresh_behavior_panel() -> void:
	var service := _habitat()
	if service == null or behavior_pattern_label == null or not service.has_method("get_behavior_snapshot"):
		return
	var behavior: Dictionary = service.call("get_behavior_snapshot") as Dictionary
	var habit: Dictionary = behavior.get("dominant_habit", {}) as Dictionary
	if habit.is_empty():
		behavior_pattern_label.text = "Noch keine belastbare Gewohnheit · Session %d" % int(behavior.get("session_index", 0))
	else:
		var phase := "GEFORMT" if bool(habit.get("formed", false)) else "ENTSTEHEND"
		behavior_pattern_label.text = "%s · %s · %d%% · Sessions %d · Kontexte %d" % [
			str(habit.get("title", habit.get("choice_id", "Muster"))),
			phase,
			roundi(float(habit.get("strength", 0.0))),
			(habit.get("sessions", []) as Array).size(),
			(habit.get("contexts", []) as Array).size()
		]
	var conflict: Dictionary = behavior.get("active_conflict", {}) as Dictionary
	if conflict.is_empty():
		behavior_conflict_label.text = "Keine aktive Reibung · Xogots Intention: %s" % str(behavior.get("dominant_behavior", "observe")).to_upper()
		behavior_conflict_label.add_theme_color_override("font_color", COLOR_MUTED)
	else:
		behavior_conflict_label.text = "%s · %d%% · %s · Intention: %s" % [
			str(conflict.get("label", "Reibung")),
			roundi(float(conflict.get("strength", 0.0))),
			"GRENZE" if bool(conflict.get("severe", false)) else "AUSHANDELN",
			str(behavior.get("dominant_behavior", "observe")).to_upper()
		]
		behavior_conflict_label.add_theme_color_override("font_color", COLOR_MAGENTA if bool(conflict.get("severe", false)) else COLOR_YELLOW)

func get_behavior_ui_snapshot() -> Dictionary:
	var service := _habitat()
	var behavior: Dictionary = service.call("get_behavior_snapshot") as Dictionary if service != null and service.has_method("get_behavior_snapshot") else {}
	return {
		"persistent_behavior_visible": behavior_pattern_label != null and behavior_conflict_label != null,
		"option_preview_visible": habitat_choice_buttons.all(func(button: Button) -> bool: return button.text.contains("XOGOT:")),
		"behavior": behavior,
		"center_is_game": stage != null and habitat_choice_grid != null
	}
