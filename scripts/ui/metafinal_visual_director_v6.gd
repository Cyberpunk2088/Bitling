extends "res://scripts/ui/metafinal_visual_director_v5.gd"

const ProductionStage3DV5 := preload("res://scripts/ui/production_bitling_stage_3d_v5.gd")

var _entrance_completed := false

func _install() -> void:
	super._install()
	call_deferred("_animate_interface_in")
	call_deferred("_sync_atmosphere")
	_connect_button_motion()

func _install_production_stage() -> void:
	var previous_variant: Variant = _dashboard.get("stage")
	if not previous_variant is Control:
		return
	var previous := previous_variant as Control
	var parent := previous.get_parent()
	if parent == null:
		return
	var child_index := previous.get_index()
	_stage = ProductionStage3DV5.new()
	_stage.name = "MetafinalOmniAtmosphereStage3D"
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
	if key in ["mood", "energy", "happiness", "curiosity", "phase", "level"]:
		call_deferred("_sync_atmosphere")

func _sync_atmosphere() -> void:
	if _stage == null or not _stage.has_method("set_atmosphere"):
		return
	var datetime := Time.get_datetime_dict_from_system()
	var hour := int(datetime.get("hour", 12))
	var segment := "MORNING" if hour < 11 else "DAY" if hour < 18 else "EVENING" if hour < 23 else "NIGHT"
	var state := get_node_or_null("/root/GameState")
	var event_mode := "CALM"
	if state != null and state.has_method("get_state_summary"):
		var summary: Dictionary = state.call("get_state_summary")
		var mood_name := str(summary.get("mood", "NEUTRAL")).to_upper()
		if mood_name in ["ECSTATIC", "HAPPY"]:
			event_mode = "BRIGHT"
		elif mood_name in ["SAD", "DISTRESSED"]:
			event_mode = "QUIET"
	_stage.call("set_atmosphere", segment, event_mode)

func _animate_interface_in() -> void:
	if _entrance_completed or _dashboard == null:
		return
	_entrance_completed = true
	var controls: Array[Control] = []
	for property_name in ["header_panel", "left_panel", "center_panel", "right_panel", "bottom_navigation"]:
		var value: Variant = _dashboard.get(property_name)
		if value is Control:
			controls.append(value as Control)
	for index in range(controls.size()):
		var control := controls[index]
		control.modulate.a = 0.0
		control.scale = Vector2(0.985, 0.985)
		control.pivot_offset = control.size * 0.5
		var tween := create_tween().set_parallel(true).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.tween_interval(float(index) * 0.045)
		tween.tween_property(control, "modulate:a", 1.0, 0.24 + float(index) * 0.025)
		tween.tween_property(control, "scale", Vector2.ONE, 0.30 + float(index) * 0.025)

func _connect_button_motion() -> void:
	if _dashboard == null:
		return
	var root_variant: Variant = _dashboard.get("ui_root")
	if not root_variant is Node:
		return
	var root_node := root_variant as Node
	for candidate in root_node.find_children("*", "Button", true, false):
		if not candidate is Button:
			continue
		var button := candidate as Button
		var pressed_callback := Callable(self, "_animate_button_press").bind(button)
		if not button.pressed.is_connected(pressed_callback):
			button.pressed.connect(pressed_callback)
		var enter_callback := Callable(self, "_animate_button_hover").bind(button, true)
		var exit_callback := Callable(self, "_animate_button_hover").bind(button, false)
		if not button.mouse_entered.is_connected(enter_callback):
			button.mouse_entered.connect(enter_callback)
		if not button.mouse_exited.is_connected(exit_callback):
			button.mouse_exited.connect(exit_callback)

func _animate_button_press(button: Button) -> void:
	if button == null:
		return
	button.pivot_offset = button.size * 0.5
	var tween := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(button, "scale", Vector2(0.955, 0.955), 0.06)
	tween.tween_property(button, "scale", Vector2.ONE, 0.18)

func _animate_button_hover(button: Button, active: bool) -> void:
	if button == null or _reduce_motion_enabled():
		return
	button.pivot_offset = button.size * 0.5
	var target := Vector2(1.025, 1.025) if active else Vector2.ONE
	var tween := create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(button, "scale", target, 0.12)

func _reduce_motion_enabled() -> bool:
	var state := get_node_or_null("/root/GameState")
	return state != null and bool(state.settings.get("reduce_motion", false))
