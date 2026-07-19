extends "res://scripts/ui/metafinal_visual_director_v7.gd"

## Wave 2 integration layer. Gameplay actions, dialogue, story beats and lifecycle
## state all drive one semantic performance stream shared by animation and audio.

const ProductionStage3DV9 := preload("res://scripts/ui/production_bitling_stage_3d_v9.gd")

var _performance_callback := Callable()
var _touch_callback := Callable()
var _last_action := ""
var _last_dialogue_trigger := ""

func _install() -> void:
	super._install()
	_connect_character_performance()
	call_deferred("_sync_wave2_performance")
	call_deferred("_sync_audio_environment")

func _install_production_stage() -> void:
	var previous_variant: Variant = _dashboard.get("stage")
	if not previous_variant is Control:
		return
	var previous := previous_variant as Control
	var parent := previous.get_parent()
	if parent == null:
		return
	var child_index := previous.get_index()
	_stage = ProductionStage3DV9.new()
	_stage.name = "LegendaryWave2CharacterStage3D"
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

func _on_action_feedback(action_name: String) -> void:
	_last_action = action_name.to_lower()
	var performance := get_node_or_null("/root/CharacterPerformance")
	if performance != null and performance.has_method("request_action"):
		performance.call("request_action", action_name, 1.0)
	elif _stage != null and _stage.has_method("play_action_animation"):
		_stage.call("play_action_animation", action_name)

func _on_dialogue_line(text: String, trigger: String) -> void:
	super._on_dialogue_line(text, trigger)
	_last_dialogue_trigger = trigger.to_lower()
	var performance := get_node_or_null("/root/CharacterPerformance")
	if performance != null and performance.has_method("request_dialogue"):
		performance.call("request_dialogue", text, trigger)

func _on_state_sync(key: String, value: Variant) -> void:
	super._on_state_sync(key, value)
	if key in ["mood", "phase", "stats", "loaded", "hatched"]:
		call_deferred("_sync_wave2_performance")
	if key in ["mood", "energy", "stats", "interaction"]:
		call_deferred("_sync_audio_environment")

func _on_slice_beat_changed(previous_index: int, current_index: int, beat: Dictionary) -> void:
	super._on_slice_beat_changed(previous_index, current_index, beat)
	var performance := get_node_or_null("/root/CharacterPerformance")
	if performance != null and performance.has_method("request_story_beat"):
		performance.call("request_story_beat", str(beat.get("id", "")))
	call_deferred("_sync_audio_environment")

func get_wave2_status() -> Dictionary:
	var performance_snapshot: Dictionary = {}
	var performance := get_node_or_null("/root/CharacterPerformance")
	if performance != null and performance.has_method("get_snapshot"):
		performance_snapshot = performance.call("get_snapshot") as Dictionary
	var stage_snapshot: Dictionary = {}
	if _stage != null and _stage.has_method("get_character_life_snapshot"):
		stage_snapshot = _stage.call("get_character_life_snapshot") as Dictionary
	var audio_snapshot: Dictionary = {}
	var audio := get_node_or_null("/root/OmniAudio")
	if audio != null and audio.has_method("get_audio_status"):
		audio_snapshot = audio.call("get_audio_status") as Dictionary
	return {
		"last_action": _last_action,
		"last_dialogue_trigger": _last_dialogue_trigger,
		"performance": performance_snapshot,
		"stage": stage_snapshot,
		"audio": audio_snapshot
	}

func _connect_character_performance() -> void:
	var performance := get_node_or_null("/root/CharacterPerformance")
	if performance == null or not performance.has_signal("performance_changed"):
		return
	_performance_callback = Callable(self, "_on_performance_changed")
	if not performance.is_connected("performance_changed", _performance_callback):
		performance.connect("performance_changed", _performance_callback)

func _sync_wave2_performance() -> void:
	var performance := get_node_or_null("/root/CharacterPerformance")
	if performance == null:
		return
	if performance.has_method("sync_state"):
		performance.call("sync_state")
	if _stage != null and _stage.has_method("apply_performance") and performance.has_method("get_snapshot"):
		_stage.call("apply_performance", performance.call("get_snapshot") as Dictionary)

func _on_performance_changed(snapshot: Dictionary) -> void:
	if _stage != null and _stage.has_method("apply_performance"):
		_stage.call("apply_performance", snapshot)

func _on_touch_zone_pressed(zone_name: String, _normalized_position: Vector2) -> void:
	_last_action = "touch_%s" % zone_name

func _sync_audio_environment() -> void:
	var audio := get_node_or_null("/root/OmniAudio")
	if audio == null or not audio.has_method("set_environment"):
		return
	var environment := "HOME"
	var slice := get_node_or_null("/root/LegendarySlice")
	if slice != null and slice.has_method("get_current_beat"):
		var beat: Dictionary = slice.call("get_current_beat")
		if str(beat.get("id", "")) in ["prismatic_rooftops", "promise_of_growth"]:
			environment = "ROOFTOPS"
	var state := get_node_or_null("/root/GameState")
	if state != null and state.has_method("get_state_summary"):
		var summary: Dictionary = state.call("get_state_summary")
		if float(summary.get("energy", 70.0)) < 24.0:
			environment = "REST"
		elif _last_action == "learn":
			environment = "LEARNING"
	audio.call("set_environment", environment)
