extends Node

const LearningTransferMap := preload("res://scripts/ui/learning_transfer_map.gd")

var _overlay: Node
var _service: Node
var _map: Control
var _active_adventure_id: String = ""
var _last_approach: String = ""
var _installed: bool = false

func _ready() -> void:
	call_deferred("_install")
	set_process(true)

func get_status() -> Dictionary:
	return {
		"installed": _installed,
		"map": _map.call("get_snapshot") if _map != null else {},
		"minimum_height": _map.custom_minimum_size.y if _map != null else 0.0
	}

func _process(_delta: float) -> void:
	if not _installed:
		return
	var approach := str(_overlay.get("_selected_approach"))
	if approach != _last_approach:
		_last_approach = approach
		_refresh()
	elif _map != null and _map.has_method("set_reduced_motion"):
		_map.call("set_reduced_motion", _reduced_motion_enabled())

func _install() -> void:
	_overlay = get_node_or_null("/root/LearningAdventureOverlay")
	_service = get_node_or_null("/root/LearningAdventures")
	if _overlay == null or _service == null:
		return
	var grid := _overlay.find_child("LearningSessionPolishGrid", true, false) as GridContainer
	if grid == null or grid.get_child_count() < 2:
		return
	var decision_card := grid.get_child(1) as PanelContainer
	if decision_card == null or decision_card.get_child_count() == 0:
		return
	var margin := decision_card.get_child(0) as MarginContainer
	if margin == null or margin.get_child_count() == 0:
		return
	var column := margin.get_child(0) as VBoxContainer
	if column == null:
		return
	_map = LearningTransferMap.new()
	_map.name = "LearningTransferConstellation"
	_map.custom_minimum_size = Vector2(0, 250)
	_map.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_map.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(_map)
	_connect_signals()
	get_viewport().size_changed.connect(_apply_layout)
	_installed = true
	_last_approach = str(_overlay.get("_selected_approach"))
	_refresh_from_snapshot()
	_apply_layout()

func _connect_signals() -> void:
	for pair: Array in [
		["session_started", "_on_session_started"],
		["challenge_changed", "_on_challenge_changed"],
		["session_completed", "_on_session_completed"]
	]:
		var signal_name := str(pair[0])
		var callback := Callable(self, str(pair[1]))
		if _service.has_signal(signal_name) and not _service.is_connected(signal_name, callback):
			_service.connect(signal_name, callback)

func _on_session_started(session: Dictionary) -> void:
	_active_adventure_id = str(session.get("adventure_id", ""))
	_refresh()

func _on_challenge_changed(challenge: Dictionary) -> void:
	_active_adventure_id = str(challenge.get("adventure_id", _active_adventure_id))
	_refresh()

func _on_session_completed(result: Dictionary) -> void:
	_active_adventure_id = str(result.get("adventure_id", _active_adventure_id))
	_refresh()

func _refresh_from_snapshot() -> void:
	var snapshot := _service.call("get_snapshot") as Dictionary
	var active := snapshot.get("active_session", {}) as Dictionary
	_active_adventure_id = str(active.get("adventure_id", ""))
	_refresh()

func _refresh() -> void:
	if not _installed:
		return
	var data := _adventure_data(_active_adventure_id)
	_map.call("set_context", str(data.get("domain", "lernen")), str(data.get("technique", "technik")), str(data.get("expedition", "expedition")), str(data.get("evolution_affinity", "evolution")), _last_approach if not _last_approach.is_empty() else "observe")
	if _map.has_method("set_reduced_motion"):
		_map.call("set_reduced_motion", _reduced_motion_enabled())

func _apply_layout() -> void:
	if not _installed:
		return
	var viewport_width := get_viewport().get_visible_rect().size.x
	var physical_width := float(get_tree().root.size.x)
	var width := minf(viewport_width, physical_width) if physical_width > 0.0 else viewport_width
	var stacked := width < 1040.0
	_map.custom_minimum_size = Vector2(0, 175 if width < 760.0 else 230 if stacked else 310)
	_map.size_flags_vertical = Control.SIZE_SHRINK_BEGIN if stacked else Control.SIZE_EXPAND_FILL
	if _map.has_method("set_reduced_motion"):
		_map.call("set_reduced_motion", _reduced_motion_enabled())

func _adventure_data(adventure_id: String) -> Dictionary:
	if adventure_id.is_empty() or not _service.has_method("get_catalog"):
		return {}
	for entry_variant: Variant in _service.call("get_catalog"):
		if entry_variant is Dictionary and str((entry_variant as Dictionary).get("id", "")) == adventure_id:
			return (entry_variant as Dictionary).duplicate(true)
	return {}

func _reduced_motion_enabled() -> bool:
	var state := get_node_or_null("/root/GameState")
	if state == null:
		return false
	var settings := state.get("settings") as Dictionary
	return bool(settings.get("reduce_motion", false))
