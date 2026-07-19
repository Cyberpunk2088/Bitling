extends "res://scripts/ui/metafinal_visual_director_v8.gd"

const ProductionStage3DV10 := preload("res://scripts/ui/production_bitling_stage_3d_v10.gd")
var _home_callback := Callable()

func _install() -> void:
	super._install()
	_connect_living_home()
	call_deferred("_sync_living_home")

func _install_production_stage() -> void:
	var previous_variant: Variant = _dashboard.get("stage")
	if not previous_variant is Control:
		return
	var previous := previous_variant as Control
	var parent := previous.get_parent()
	if parent == null:
		return
	var child_index := previous.get_index()
	_stage = ProductionStage3DV10.new()
	_stage.name = "LegendaryWave3LivingHomeStage3D"
	_stage.custom_minimum_size = previous.custom_minimum_size
	_stage.size_flags_horizontal = previous.size_flags_horizontal
	_stage.size_flags_vertical = previous.size_flags_vertical
	parent.add_child(_stage)
	parent.move_child(_stage, child_index)
	if _stage.has_signal("bitling_pressed") and _dashboard.has_method("_on_stage_pressed"):
		_stage.connect("bitling_pressed", Callable(_dashboard, "_on_stage_pressed"))
	if _stage.has_signal("touch_zone_pressed"):
		_touch_callback = Callable(self, "_on_touch_zone_pressed")
		if not _stage.is_connected("touch_zone_pressed", _touch_callback):
			_stage.connect("touch_zone_pressed", _touch_callback)
	_dashboard.set("stage", _stage)
	previous.queue_free()

func get_wave3_status() -> Dictionary:
	var result := get_wave2_status()
	var service := get_node_or_null("/root/LivingHome")
	result["living_home"] = service.call("get_snapshot") if service != null and service.has_method("get_snapshot") else {}
	result["stage_home"] = _stage.call("get_living_home_snapshot") if _stage != null and _stage.has_method("get_living_home_snapshot") else {}
	return result

func _connect_living_home() -> void:
	var service := get_node_or_null("/root/LivingHome")
	if service == null or not service.has_signal("home_changed"):
		return
	_home_callback = Callable(self, "_on_home_changed")
	if not service.is_connected("home_changed", _home_callback):
		service.connect("home_changed", _home_callback)

func _sync_living_home() -> void:
	var service := get_node_or_null("/root/LivingHome")
	if service != null and service.has_method("get_snapshot"):
		_on_home_changed(service.call("get_snapshot") as Dictionary)

func _on_home_changed(snapshot: Dictionary) -> void:
	if _stage != null and _stage.has_method("apply_home_snapshot"):
		_stage.call("apply_home_snapshot", snapshot)
	var audio := get_node_or_null("/root/OmniAudio")
	if audio != null and audio.has_method("set_environment"):
		audio.call("set_environment", "REST" if str(snapshot.get("time_segment", "DAY")) == "NIGHT" else "HOME")
