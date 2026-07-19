extends "res://scripts/ui/metafinal_visual_director_v3.gd"

const ProductionStage3DV3 := preload("res://scripts/ui/production_bitling_stage_3d_v3.gd")

func _install() -> void:
	super._install()
	_connect_action_visuals()

func _install_production_stage() -> void:
	var previous_variant: Variant = _dashboard.get("stage")
	if not previous_variant is Control:
		return
	var previous := previous_variant as Control
	var parent := previous.get_parent()
	if parent == null:
		return
	var child_index := previous.get_index()
	_stage = ProductionStage3DV3.new()
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

func _connect_action_visuals() -> void:
	var buttons_variant: Variant = _dashboard.get("action_buttons")
	if not buttons_variant is Dictionary:
		return
	var buttons := buttons_variant as Dictionary
	for key_variant in buttons.keys():
		var key := str(key_variant)
		var button_variant: Variant = buttons[key]
		if not button_variant is Button:
			continue
		var button := button_variant as Button
		var callable := Callable(self, "_on_action_visual").bind(key)
		if not button.pressed.is_connected(callable):
			button.pressed.connect(callable)

func _on_action_visual(action_name: String) -> void:
	if _stage != null and _stage.has_method("play_action_animation"):
		_stage.call("play_action_animation", action_name)
