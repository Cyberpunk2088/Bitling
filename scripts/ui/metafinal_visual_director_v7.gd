extends "res://scripts/ui/metafinal_visual_director_v6.gd"

const ProductionStage3DV7 := preload("res://scripts/ui/production_bitling_stage_3d_v7.gd")

func _install() -> void:
	super._install()
	_connect_slice_visuals()
	call_deferred("_sync_wave1_visuals")

func _install_production_stage() -> void:
	var previous_variant: Variant = _dashboard.get("stage")
	if not previous_variant is Control:
		return
	var previous := previous_variant as Control
	var parent := previous.get_parent()
	if parent == null:
		return
	var child_index := previous.get_index()
	_stage = ProductionStage3DV7.new()
	_stage.name = "LegendaryWave1Stage3D"
	_stage.custom_minimum_size = previous.custom_minimum_size
	_stage.size_flags_horizontal = previous.size_flags_horizontal
	_stage.size_flags_vertical = previous.size_flags_vertical
	parent.add_child(_stage)
	parent.move_child(_stage, child_index)
	if _stage.has_signal("bitling_pressed") and _dashboard.has_method("_on_stage_pressed"):
		_stage.connect("bitling_pressed", Callable(_dashboard, "_on_stage_pressed"))
	_dashboard.set("stage", _stage)
	previous.queue_free()

func _on_state_sync(key: String, value: Variant) -> void:
	super._on_state_sync(key, value)
	if key in ["phase", "level", "interaction", "mood"]:
		call_deferred("_sync_wave1_visuals")

func _connect_slice_visuals() -> void:
	var director := get_node_or_null("/root/LegendarySlice")
	if director == null:
		return
	var beat_callback := Callable(self, "_on_slice_beat_changed")
	var snapshot_callback := Callable(self, "_on_slice_snapshot")
	if director.has_signal("beat_changed") and not director.is_connected("beat_changed", beat_callback):
		director.connect("beat_changed", beat_callback)
	if director.has_signal("slice_started") and not director.is_connected("slice_started", snapshot_callback):
		director.connect("slice_started", snapshot_callback)
	if director.has_signal("slice_completed") and not director.is_connected("slice_completed", snapshot_callback):
		director.connect("slice_completed", snapshot_callback)

func _on_slice_beat_changed(_previous_index: int, _current_index: int, _beat: Dictionary) -> void:
	call_deferred("_sync_wave1_visuals")

func _on_slice_snapshot(_snapshot: Dictionary) -> void:
	call_deferred("_sync_wave1_visuals")

func _sync_wave1_visuals() -> void:
	if _stage == null:
		return
	_sync_development_state()
	var director := get_node_or_null("/root/LegendarySlice")
	if director != null and director.has_method("get_current_beat") and _stage.has_method("set_story_beat"):
		var beat: Dictionary = director.call("get_current_beat")
		_stage.call("set_story_beat", str(beat.get("id", "")))
