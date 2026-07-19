extends SceneTree

const Wave1Stage := preload("res://scripts/ui/production_bitling_stage_3d_v6.gd")

var failures: Array[String] = []
var assertions := 0

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	await process_frame
	await process_frame
	await _test_phase_signatures_and_rooftops()
	await _test_story_hud_contract()
	await _test_activity_presentation_contract()
	if failures.is_empty():
		print("[CI-WAVE1-VISUAL] PASS: %d assertions" % assertions)
		quit(0)
		return
	push_error("[CI-WAVE1-VISUAL] FAIL: %d of %d assertions failed" % [failures.size(), assertions])
	for failure in failures:
		push_error("[CI-WAVE1-VISUAL]   - %s" % failure)
	quit(1)

func _test_phase_signatures_and_rooftops() -> void:
	var stage := Wave1Stage.new()
	stage.name = "Wave1VisualTestStage"
	stage.size = Vector2(720.0, 720.0)
	stage.custom_minimum_size = Vector2(720.0, 720.0)
	root.add_child(stage)
	await process_frame
	await process_frame
	for phase_name in ["BABY", "CHILD", "TEEN"]:
		stage.set_development_phase(phase_name, 30)
		await process_frame
		var snapshot: Dictionary = stage.get_wave1_visual_snapshot()
		_assert(str(snapshot.get("visible_signature", "")) == phase_name, "%s has its own visible silhouette signature" % phase_name)
	_assert(int(stage.get_wave1_visual_snapshot().get("signature_count", 0)) >= 7, "All seven lifecycle phases have visual signatures")
	stage.set_story_beat("prismatic_rooftops")
	await process_frame
	var rooftop_snapshot: Dictionary = stage.get_wave1_visual_snapshot()
	_assert(bool(rooftop_snapshot.get("rooftop_visible", false)), "Prismatic rooftop story beat activates the 3D garden layer")
	_assert(int(rooftop_snapshot.get("rooftop_crystals", 0)) >= 7, "Rooftop environment contains a substantial prism set")
	_assert(int(rooftop_snapshot.get("rooftop_petals", 0)) >= 18, "Rooftop environment contains animated atmosphere particles")
	stage.set_story_beat("shared_rhythm")
	await process_frame
	_assert(not bool(stage.get_wave1_visual_snapshot().get("rooftop_visible", true)), "Home beats hide the expedition environment")
	stage.queue_free()
	await process_frame

func _test_story_hud_contract() -> void:
	var director := root.get_node_or_null("LegendarySlice")
	var hud := root.get_node_or_null("LegendaryStoryHUD")
	_assert(director != null, "LegendarySlice exists for story HUD")
	_assert(hud != null, "LegendaryStoryHUD autoload exists")
	if director == null or hud == null:
		return
	var previous_size := root.size
	root.size = Vector2i(390, 844)
	await process_frame
	hud.call("_apply_layout")
	director.reset_state()
	director.start_slice("Zumi", "ermutigend")
	hud.call("_refresh")
	await process_frame
	await process_frame
	var first_snapshot: Dictionary = hud.get_hud_snapshot()
	_assert(bool(first_snapshot.get("visible", false)), "Story HUD is visible during an active slice")
	_assert(str(first_snapshot.get("beat_id", "")) == "first_choice", "Story HUD tracks the authoritative current beat")
	_assert(str(first_snapshot.get("continue_label", "")).contains("PFLEGE"), "Story HUD exposes a context-specific next action")
	_assert(bool(first_snapshot.get("compact", false)), "390px physical width selects the compact story HUD")
	var panel_size: Vector2 = first_snapshot.get("panel_size", Vector2.ZERO) as Vector2
	_assert(panel_size.y <= 170.0, "Compact story HUD is height-capped and cannot cover the phone game view")
	_assert(panel_size.x <= 390.0, "Compact story HUD remains within physical phone width")
	_assert(int(first_snapshot.get("canvas_layer", 999)) < int(first_snapshot.get("modal_layer_ceiling", 0)), "Story HUD renders below Partner World and modal activities")
	director.record_first_care("care")
	hud.call("_refresh")
	await process_frame
	var rhythm_snapshot: Dictionary = hud.get_hud_snapshot()
	_assert(str(rhythm_snapshot.get("beat_id", "")) == "shared_rhythm", "Story HUD advances with the story director")
	_assert(str(rhythm_snapshot.get("continue_label", "")).contains("RESONANZ"), "Story HUD launches the matching activity")
	root.size = previous_size
	await process_frame
	hud.call("_apply_layout")

func _test_activity_presentation_contract() -> void:
	var activities := root.get_node_or_null("LegendaryActivities")
	_assert(activities != null, "LegendaryActivities upgraded autoload exists")
	if activities == null:
		return
	activities.open_activity("pattern_focus")
	await process_frame
	await process_frame
	var snapshot: Dictionary = activities.get_presentation_snapshot()
	_assert(bool(snapshot.get("overlay_open", false)), "Activity presentation opens as a full experience layer")
	var visual: Dictionary = snapshot.get("visual_backdrop", {}) as Dictionary
	_assert(str(visual.get("activity", "")) == "pattern_focus", "Activity backdrop reflects the selected game")
	_assert((snapshot.get("panel_minimum", Vector2.ZERO) as Vector2).x >= 320.0, "Activity presentation preserves readable mobile width")
	activities.call("_round_complete", true, 0.92, "Testresonanz")
	await process_frame
	var pulse_snapshot: Dictionary = activities.get_presentation_snapshot()
	var pulse_visual: Dictionary = pulse_snapshot.get("visual_backdrop", {}) as Dictionary
	_assert(float(pulse_visual.get("success_flash", 0.0)) > 0.0, "Successful rounds create a visible feedback pulse")
	activities.call("_close_overlay")
	await process_frame

func _assert(condition: bool, description: String) -> void:
	assertions += 1
	if not condition:
		failures.append(description)
