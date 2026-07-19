extends "res://scripts/ui/metafinal_visual_director_v4.gd"

const ProductionStage3DV4 := preload("res://scripts/ui/production_bitling_stage_3d_v4.gd")

var _dialogue_callback := Callable()
var _state_callback := Callable()
var _level_callback := Callable()

func _install() -> void:
	super._install()
	_connect_omni_feedback()
	_sync_development_state()

func _install_production_stage() -> void:
	var previous_variant: Variant = _dashboard.get("stage")
	if not previous_variant is Control:
		return
	var previous := previous_variant as Control
	var parent := previous.get_parent()
	if parent == null:
		return
	var child_index := previous.get_index()
	_stage = ProductionStage3DV4.new()
	_stage.name = "MetafinalOmniExpressiveStage3D"
	_stage.custom_minimum_size = previous.custom_minimum_size
	_stage.size_flags_horizontal = previous.size_flags_horizontal
	_stage.size_flags_vertical = previous.size_flags_vertical
	parent.add_child(_stage)
	parent.move_child(_stage, child_index)
	if _stage.has_signal("bitling_pressed") and _dashboard.has_method("_on_stage_pressed"):
		_stage.connect("bitling_pressed", Callable(_dashboard, "_on_stage_pressed"))
	_dashboard.set("stage", _stage)
	previous.queue_free()

func _connect_omni_feedback() -> void:
	var dialogue := get_node_or_null("/root/DialogueDirector")
	if dialogue != null and dialogue.has_signal("line_ready"):
		_dialogue_callback = Callable(self, "_on_dialogue_line")
		if not dialogue.is_connected("line_ready", _dialogue_callback):
			dialogue.connect("line_ready", _dialogue_callback)

	var state := get_node_or_null("/root/GameState")
	if state != null:
		_state_callback = Callable(self, "_on_state_sync")
		_level_callback = Callable(self, "_on_level_feedback")
		if state.has_signal("state_changed") and not state.is_connected("state_changed", _state_callback):
			state.connect("state_changed", _state_callback)
		if state.has_signal("level_up") and not state.is_connected("level_up", _level_callback):
			state.connect("level_up", _level_callback)

	var buttons_variant: Variant = _dashboard.get("action_buttons")
	if buttons_variant is Dictionary:
		var buttons := buttons_variant as Dictionary
		for key_variant in buttons.keys():
			var key := str(key_variant)
			var button_variant: Variant = buttons[key]
			if not button_variant is Button:
				continue
			var button := button_variant as Button
			var callback := Callable(self, "_on_action_feedback").bind(key)
			if not button.pressed.is_connected(callback):
				button.pressed.connect(callback)

	_connect_navigation_feedback(_dashboard.get("desktop_navigation") as Node)
	_connect_navigation_feedback(_dashboard.get("bottom_navigation") as Node)

func _connect_navigation_feedback(root_node: Node) -> void:
	if root_node == null:
		return
	for candidate in root_node.find_children("*", "Button", true, false):
		if not candidate is Button:
			continue
		var button := candidate as Button
		var callback := Callable(self, "_on_navigation_feedback")
		if not button.pressed.is_connected(callback):
			button.pressed.connect(callback)

func _on_action_feedback(action_name: String) -> void:
	var audio := get_node_or_null("/root/OmniAudio")
	if audio != null and audio.has_method("play_action"):
		audio.call("play_action", action_name, 1.0)
	if _stage != null and _stage.has_method("play_action_animation"):
		_stage.call("play_action_animation", action_name)

func _on_navigation_feedback() -> void:
	var audio := get_node_or_null("/root/OmniAudio")
	if audio != null and audio.has_method("play_navigation"):
		audio.call("play_navigation")

func _on_dialogue_line(text: String, _trigger: String) -> void:
	call_deferred("_apply_dialogue_line", text)

func _apply_dialogue_line(text: String) -> void:
	if _dashboard == null:
		return
	var label_variant: Variant = _dashboard.get("message_label")
	if not label_variant is Label:
		return
	var label := label_variant as Label
	label.text = text
	label.modulate.a = 0.30
	var tween := create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "modulate:a", 1.0, 0.22)

func _on_state_sync(_key: String, _value: Variant) -> void:
	call_deferred("_sync_development_state")

func _on_level_feedback(_new_level: int) -> void:
	var audio := get_node_or_null("/root/OmniAudio")
	if audio != null and audio.has_method("play_action"):
		audio.call("play_action", "level", 1.15)
	call_deferred("_sync_development_state")

func _sync_development_state() -> void:
	if _stage == null or not _stage.has_method("set_development_phase"):
		return
	var state := get_node_or_null("/root/GameState")
	if state == null or not state.has_method("get_state_summary"):
		return
	var summary: Dictionary = state.call("get_state_summary")
	var phase := str(summary.get("phase", summary.get("development_phase", "BABY")))
	var level := int(state.get("level"))
	_stage.call("set_development_phase", phase, level)
