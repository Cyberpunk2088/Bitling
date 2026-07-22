extends "res://scripts/ui/ultimate_dashboard_behavior.gd"

## Keeps room consequences inside the same central product surface. Persistent
## changes and follow-up moments are visible without opening a separate menu.

var world_consequence_label: Label
var world_event_label: Label
var world_contract_label: Label

func _build_right_panel() -> PanelContainer:
	var panel: PanelContainer = super._build_right_panel()
	var column := panel.get_child(0) as VBoxContainer
	var title := _section_title("WAS IM RAUM GEBLIEBEN IST")
	column.add_child(title)
	var card := PanelContainer.new()
	card.name = "WorldConsequenceCard"
	card.add_theme_stylebox_override("panel", _panel_style(Color("0b162b"), Color(COLOR_GREEN, 0.40), 15, 1))
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 7)
	card.add_child(content)
	world_consequence_label = Label.new()
	world_consequence_label.text = "Noch keine Gewohnheit hat den Raum dauerhaft verändert."
	world_consequence_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	world_consequence_label.add_theme_color_override("font_color", COLOR_TEXT)
	world_consequence_label.add_theme_font_size_override("font_size", 11)
	content.add_child(world_consequence_label)
	world_event_label = Label.new()
	world_event_label.text = "Keine offene gemeinsame Folge."
	world_event_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	world_event_label.add_theme_color_override("font_color", COLOR_MUTED)
	world_event_label.add_theme_font_size_override("font_size", 11)
	content.add_child(world_event_label)
	world_contract_label = Label.new()
	world_contract_label.text = "Eine geformte Gewohnheit muss im Habitat erscheinen. Reibung muss als spielbarer Folgemoment zurückkehren."
	world_contract_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	world_contract_label.add_theme_color_override("font_color", COLOR_CYAN)
	world_contract_label.add_theme_font_size_override("font_size", 10)
	content.add_child(world_contract_label)
	column.add_child(card)
	return panel

func _connect_runtime_signals() -> void:
	super._connect_runtime_signals()
	var service := _habitat()
	if service == null or not service.has_signal("world_consequences_changed"):
		return
	var callback := Callable(self, "_on_world_consequences_changed")
	if not service.is_connected("world_consequences_changed", callback):
		service.connect("world_consequences_changed", callback)

func _refresh_habitat() -> void:
	super._refresh_habitat()
	_refresh_world_consequences()

func _on_world_consequences_changed(snapshot: Dictionary) -> void:
	_apply_world_consequences(snapshot)

func _refresh_world_consequences() -> void:
	var service := _habitat()
	if service == null or not service.has_method("get_world_consequence_snapshot"):
		return
	_apply_world_consequences(service.call("get_world_consequence_snapshot") as Dictionary)

func _apply_world_consequences(snapshot: Dictionary) -> void:
	if stage != null and stage.has_method("set_world_consequence_snapshot"):
		stage.call("set_world_consequence_snapshot", snapshot)
	if world_consequence_label == null:
		return
	var marks: Dictionary = snapshot.get("world_marks", {}) as Dictionary
	if marks.is_empty():
		world_consequence_label.text = "Noch keine Gewohnheit hat den Raum dauerhaft verändert."
	else:
		var lines: Array[String] = []
		for hotspot_variant in ["bitling", "window", "workbench", "plant", "platform", "sleep"]:
			var hotspot := str(hotspot_variant)
			if not marks.has(hotspot):
				continue
			var mark := marks[hotspot] as Dictionary
			lines.append("%s · %s · STUFE %d" % [_hotspot_label(hotspot), str(mark.get("title", mark.get("state", "Folge"))).to_upper(), int(mark.get("level", 1))])
		world_consequence_label.text = "\n".join(lines)
	var event: Dictionary = snapshot.get("active_event", {}) as Dictionary
	if event.is_empty():
		world_event_label.text = "Keine offene gemeinsame Folge · %d gelöste Folgen" % (snapshot.get("resolved_events", []) as Array).size()
		world_event_label.add_theme_color_override("font_color", COLOR_MUTED)
	else:
		var kind := "XOGOTS INITIATIVE" if str(event.get("type", "")) == "initiative" else "OFFENE REIBUNG"
		world_event_label.text = "%s · %s · %s" % [kind, _hotspot_label(str(event.get("hotspot", "bitling"))), str(event.get("title", "Gemeinsame Folge"))]
		world_event_label.add_theme_color_override("font_color", COLOR_MAGENTA if str(event.get("type", "")) == "conflict" else COLOR_GREEN)

func _apply_last_result() -> void:
	super._apply_last_result()
	if _last_habitat_result.is_empty() or habitat_consequence_label == null:
		return
	if _last_habitat_result.has("world_resolution"):
		habitat_consequence_label.text += "  •  RAUM: %s" % str(_last_habitat_result.get("world_resolution", "changed")).to_upper()

func get_world_consequence_ui_snapshot() -> Dictionary:
	var service := _habitat()
	var world: Dictionary = service.call("get_world_consequence_snapshot") as Dictionary if service != null and service.has_method("get_world_consequence_snapshot") else {}
	var stage_snapshot: Dictionary = stage.call("get_habitat_interaction_snapshot") as Dictionary if stage != null and stage.has_method("get_habitat_interaction_snapshot") else {}
	return {
		"world_panel_visible": world_consequence_label != null and world_event_label != null,
		"world": world,
		"stage_world_overlay_ready": bool(stage_snapshot.get("world_consequence_overlay_ready", false)),
		"stage_world_visual": stage_snapshot.get("world_consequence_visual", {}),
		"center_is_game": stage != null and habitat_choice_grid != null
	}
