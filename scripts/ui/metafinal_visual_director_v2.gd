extends "res://scripts/ui/metafinal_visual_director.gd"

const ProductionStage3DV2 := preload("res://scripts/ui/production_bitling_stage_3d_v2.gd")

func _install_production_stage() -> void:
	var previous_variant: Variant = _dashboard.get("stage")
	if not previous_variant is Control:
		return
	var previous := previous_variant as Control
	var parent := previous.get_parent()
	if parent == null:
		return
	var child_index := previous.get_index()
	_stage = ProductionStage3DV2.new()
	_stage.name = "MetafinalProductionBitlingStage3D"
	_stage.custom_minimum_size = previous.custom_minimum_size
	_stage.size_flags_horizontal = previous.size_flags_horizontal
	_stage.size_flags_vertical = previous.size_flags_vertical
	parent.add_child(_stage)
	parent.move_child(_stage, child_index)
	if _stage.has_signal("bitling_pressed") and _dashboard.has_method("_on_stage_pressed"):
		_stage.connect("bitling_pressed", Callable(_dashboard, "_on_stage_pressed"))
	_dashboard.set("stage", _stage)
	previous.queue_free()
