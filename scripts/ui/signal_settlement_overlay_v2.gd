extends "res://scripts/ui/signal_settlement_overlay.gd"

const SettlementMapV2 := preload("res://scripts/ui/signal_settlement_map_v2.gd")

## Wave 4 hardening: typed map renderer and one semantic audio response for every
## world action. The visual layout and gameplay authority remain in the base layer.

func _build_map_panel() -> PanelContainer:
	var panel := PanelContainer.new()
	panel.name = "SettlementMapPanel"
	panel.custom_minimum_size = Vector2(620, 620)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", _panel_style(Color("030817"), Color(COLOR_CYAN, 0.50), 20, 1))
	_map = SettlementMapV2.new()
	_map.name = "SettlementMap"
	_map.custom_minimum_size = Vector2(600, 600)
	_map.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_map.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_map.connect("district_selected", Callable(self, "_on_district_selected"))
	_map.connect("route_finished", Callable(self, "_on_route_finished"))
	panel.add_child(_map)
	return panel

func _refresh() -> void:
	super._refresh()
	var service := get_node_or_null("/root/SignalSettlement")
	if service == null or not service.has_method("get_snapshot"):
		return
	var snapshot: Dictionary = service.call("get_snapshot")
	var district: Dictionary = snapshot.get("current_district_data", {})
	_set_world_environment(str(district.get("ambience", "SETTLEMENT")))

func _on_district_selected(district_id: String) -> void:
	var before := _current_district_id()
	super._on_district_selected(district_id)
	if _current_district_id() != before:
		_play_world_cue("travel", 0.86)

func _on_route_finished(district_id: String) -> void:
	super._on_route_finished(district_id)
	_play_world_cue("arrival", 0.82)

func _train_with_mentor(citizen_id: String) -> void:
	var service := get_node_or_null("/root/SignalSettlement")
	var before := 0.0
	if service != null and service.has_method("get_snapshot"):
		before = float((service.call("get_snapshot") as Dictionary).get("mentor_bonds", {}).get(citizen_id, 0.0))
	super._train_with_mentor(citizen_id)
	if service != null and service.has_method("get_snapshot"):
		var after := float((service.call("get_snapshot") as Dictionary).get("mentor_bonds", {}).get(citizen_id, 0.0))
		if after > before:
			_play_world_cue("mentor", 0.88)

func _investigate_secret() -> void:
	var service := get_node_or_null("/root/SignalSettlement")
	var before := 0
	if service != null and service.has_method("get_snapshot"):
		before = (service.call("get_snapshot") as Dictionary).get("completed_secrets", []).size()
	super._investigate_secret()
	_play_world_cue("world_change" if service != null and (service.call("get_snapshot") as Dictionary).get("completed_secrets", []).size() > before else "secret", 0.90)

func _start_selected_expedition() -> void:
	var was_active := _has_active_expedition()
	super._start_selected_expedition()
	if not was_active and _has_active_expedition():
		_play_world_cue("expedition", 0.95)
		_set_world_environment("EXPEDITION")

func _advance_expedition(choice: String) -> void:
	var was_active := _has_active_expedition()
	super._advance_expedition(choice)
	if was_active and not _has_active_expedition():
		_play_world_cue("world_change", 1.0)
	else:
		_play_world_cue("expedition", 0.72)

func _current_district_id() -> String:
	var service := get_node_or_null("/root/SignalSettlement")
	if service != null and service.has_method("get_snapshot"):
		return str((service.call("get_snapshot") as Dictionary).get("current_district", ""))
	return ""

func _has_active_expedition() -> bool:
	var service := get_node_or_null("/root/SignalSettlement")
	if service != null and service.has_method("get_snapshot"):
		return not ((service.call("get_snapshot") as Dictionary).get("active_expedition", {}) as Dictionary).is_empty()
	return false

func _set_world_environment(environment_name: String) -> void:
	var audio := get_node_or_null("/root/OmniAudio")
	if audio != null and audio.has_method("set_environment"):
		audio.call("set_environment", environment_name)

func _play_world_cue(cue_name: String, intensity: float) -> void:
	var audio := get_node_or_null("/root/OmniAudio")
	if audio != null and audio.has_method("play_world_cue"):
		audio.call("play_world_cue", cue_name, intensity)
