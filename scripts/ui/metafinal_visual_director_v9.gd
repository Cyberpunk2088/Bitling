extends "res://scripts/ui/metafinal_visual_director_v8.gd"

## Wave 3 integration layer. It installs the Living Home stage and keeps the
## persistent room simulation synchronized with story, performance and audio.
## Habitat gameplay is fused into that production stage and may not be replaced
## by a passive visual-only stage.

const ProductionHabitatStage := preload("res://scripts/ui/bitling_habitat_stage.gd")

var _home_callback := Callable()
var _last_home_snapshot: Dictionary = {}

func _install() -> void:
	super._install()
	_connect_living_home_runtime()
	call_deferred("_sync_living_home_runtime")

func _install_production_stage() -> void:
	var previous_variant: Variant = _dashboard.get("stage")
	if not previous_variant is Control:
		return
	var previous: Control = previous_variant as Control
	var previous_script: Script = previous.get_script() as Script
	if previous_script != null and str(previous_script.resource_path).ends_with("bitling_habitat_stage.gd"):
		_stage = previous
		_wire_habitat_stage()
		return
	var parent: Node = previous.get_parent()
	if parent == null:
		return
	var child_index: int = previous.get_index()
	_stage = ProductionHabitatStage.new()
	_stage.name = "LegendaryLivingHabitatStage3D"
	_stage.custom_minimum_size = previous.custom_minimum_size
	_stage.size_flags_horizontal = previous.size_flags_horizontal
	_stage.size_flags_vertical = previous.size_flags_vertical
	parent.add_child(_stage)
	parent.move_child(_stage, child_index)
	_wire_habitat_stage()
	previous.queue_free()

func _wire_habitat_stage() -> void:
	if _stage == null:
		return
	if _stage.has_signal("bitling_pressed") and _dashboard.has_method("_on_stage_pressed"):
		var bitling_callback := Callable(_dashboard, "_on_stage_pressed")
		if not _stage.is_connected("bitling_pressed", bitling_callback):
			_stage.connect("bitling_pressed", bitling_callback)
	if _stage.has_signal("hotspot_pressed") and _dashboard.has_method("_on_hotspot_pressed"):
		var hotspot_callback := Callable(_dashboard, "_on_hotspot_pressed")
		if not _stage.is_connected("hotspot_pressed", hotspot_callback):
			_stage.connect("hotspot_pressed", hotspot_callback)
	if _stage.has_signal("touch_zone_pressed"):
		_touch_callback = Callable(self, "_on_touch_zone_pressed")
		if not _stage.is_connected("touch_zone_pressed", _touch_callback):
			_stage.connect("touch_zone_pressed", _touch_callback)
	_dashboard.set("stage", _stage)

func get_wave3_status() -> Dictionary:
	var parent_status := get_wave2_status()
	var stage_home: Dictionary = {}
	if _stage != null and _stage.has_method("get_living_home_visual_snapshot"):
		stage_home = _stage.call("get_living_home_visual_snapshot") as Dictionary
	var habitat: Dictionary = {}
	if _stage != null and _stage.has_method("get_habitat_interaction_snapshot"):
		habitat = _stage.call("get_habitat_interaction_snapshot") as Dictionary
	var overlay_snapshot: Dictionary = {}
	var overlay := get_node_or_null("/root/LivingHomeOverlay")
	if overlay != null and overlay.has_method("get_overlay_snapshot"):
		overlay_snapshot = overlay.call("get_overlay_snapshot") as Dictionary
	return {
		"wave2": parent_status,
		"home": _last_home_snapshot.duplicate(true),
		"stage_home": stage_home,
		"habitat": habitat,
		"overlay": overlay_snapshot
	}

func _on_action_feedback(action_name: String) -> void:
	super._on_action_feedback(action_name)
	var home := get_node_or_null("/root/LivingHome")
	if home != null and home.has_method("record_external_action"):
		home.call("record_external_action", action_name)

func _on_slice_beat_changed(previous_index: int, current_index: int, beat: Dictionary) -> void:
	super._on_slice_beat_changed(previous_index, current_index, beat)
	_sync_home_visibility(str(beat.get("id", "")))

func _connect_living_home_runtime() -> void:
	var home := get_node_or_null("/root/LivingHome")
	if home == null or not home.has_signal("home_changed"):
		return
	_home_callback = Callable(self, "_on_living_home_changed")
	if not home.is_connected("home_changed", _home_callback):
		home.connect("home_changed", _home_callback)

func _sync_living_home_runtime() -> void:
	var home := get_node_or_null("/root/LivingHome")
	if home != null and home.has_method("get_snapshot"):
		_on_living_home_changed(home.call("get_snapshot") as Dictionary)
	var slice := get_node_or_null("/root/LegendarySlice")
	if slice != null and slice.has_method("get_current_beat"):
		var beat: Dictionary = slice.call("get_current_beat")
		_sync_home_visibility(str(beat.get("id", "")))

func _on_living_home_changed(snapshot: Dictionary) -> void:
	_last_home_snapshot = snapshot.duplicate(true)
	if _stage != null and _stage.has_method("_apply_home_snapshot"):
		_stage.call("_apply_home_snapshot", snapshot)
	var audio := get_node_or_null("/root/OmniAudio")
	if audio != null and audio.has_method("set_environment"):
		var segment := str(snapshot.get("time_segment", "DAY"))
		var room_mood := str(snapshot.get("room_mood", "BALANCED"))
		if segment == "NIGHT" or room_mood == "COZY":
			audio.call("set_environment", "REST")
		else:
			audio.call("set_environment", "HOME")

func _sync_home_visibility(beat_id: String) -> void:
	if _stage != null and _stage.has_method("set_story_beat"):
		_stage.call("set_story_beat", beat_id)
