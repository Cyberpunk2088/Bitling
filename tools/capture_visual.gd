extends SceneTree

const CAPTURES := [
	{"name": "phone", "size": Vector2i(390, 844)},
	{"name": "tablet", "size": Vector2i(900, 1200)},
	{"name": "laptop", "size": Vector2i(1440, 900)}
]

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var output_directory := ProjectSettings.globalize_path("res://builds/visual")
	var directory_error := DirAccess.make_dir_recursive_absolute(output_directory)
	if directory_error != OK and directory_error != ERR_ALREADY_EXISTS:
		push_error("[VISUAL-CAPTURE] Could not create output directory: %s" % directory_error)
		quit(1)
		return

	var packed_scene := load("res://main.tscn") as PackedScene
	if packed_scene == null:
		push_error("[VISUAL-CAPTURE] Main scene could not be loaded")
		quit(1)
		return

	for capture in CAPTURES:
		root.size = capture.size
		var dashboard := packed_scene.instantiate()
		root.add_child(dashboard)
		await _settle_frames(10, 0.18)
		_prepare_deterministic_story_state()
		await _settle_frames(8, 0.18)
		if not _save_capture(output_directory, "bitling-%s.png" % capture.name, str(capture.name)):
			quit(1)
			return

		if not await _capture_living_home(output_directory, str(capture.name)):
			quit(1)
			return

		if not await _capture_character_performances(output_directory, str(capture.name)):
			quit(1)
			return

		var overlay := root.get_node_or_null("PartnerWorldOverlay")
		if overlay == null or not overlay.has_method("open_partner_world"):
			push_error("[VISUAL-CAPTURE] PartnerWorldOverlay is unavailable")
			quit(1)
			return
		overlay.call("open_partner_world")
		await _settle_frames(12, 0.28)
		if not _save_capture(output_directory, "bitling-%s-partner-world.png" % capture.name, "%s partner-world" % capture.name):
			quit(1)
			return
		if overlay.has_method("close_partner_world"):
			overlay.call("close_partner_world")
		await _settle_frames(4, 0.18)

		_prepare_rooftop_story_beat()
		await _settle_frames(14, 0.35)
		if not _save_capture(output_directory, "bitling-%s-rooftops.png" % capture.name, "%s rooftops" % capture.name):
			quit(1)
			return

		var activities := root.get_node_or_null("LegendaryActivities")
		if activities == null or not activities.has_method("open_activity"):
			push_error("[VISUAL-CAPTURE] LegendaryActivities is unavailable")
			quit(1)
			return
		activities.call("open_activity", "resonance_rhythm")
		await _settle_frames(12, 0.30)
		if not _save_capture(output_directory, "bitling-%s-activity.png" % capture.name, "%s activity" % capture.name):
			quit(1)
			return
		if activities.has_method("_close_overlay"):
			activities.call("_close_overlay")
		await _settle_frames(4, 0.15)

		dashboard.queue_free()
		await process_frame

	print("[VISUAL-CAPTURE] PASS")
	quit(0)

func _capture_living_home(output_directory: String, viewport_name: String) -> bool:
	var living_home := root.get_node_or_null("LivingHomeOverlay")
	if living_home == null or not living_home.has_method("open_living_home"):
		push_error("[VISUAL-CAPTURE] LivingHomeOverlay is unavailable")
		return false
	living_home.call("open_living_home")
	await _settle_frames(10, 0.26)
	if not _save_capture(output_directory, "bitling-%s-living-home.png" % viewport_name, "%s living home" % viewport_name):
		return false
	if living_home.has_method("close_living_home"):
		living_home.call("close_living_home")
	await _settle_frames(4, 0.15)
	return true

func _capture_character_performances(output_directory: String, viewport_name: String) -> bool:
	var performance := root.get_node_or_null("CharacterPerformance")
	if performance == null:
		push_error("[VISUAL-CAPTURE] CharacterPerformance is unavailable")
		return false

	performance.call("request_action", "play", 1.0)
	await _settle_frames(8, 0.22)
	if not _save_capture(output_directory, "bitling-%s-play.png" % viewport_name, "%s play expression" % viewport_name):
		return false

	performance.call("request_touch", "head", Vector2(0.0, -0.45))
	await _settle_frames(8, 0.22)
	if not _save_capture(output_directory, "bitling-%s-touch.png" % viewport_name, "%s head touch" % viewport_name):
		return false

	var dialogue := root.get_node_or_null("DialogueDirector")
	if dialogue != null and dialogue.has_method("emit_line"):
		dialogue.call("emit_line", "learn", {"capture": true})
	else:
		performance.call("request_dialogue", "Ich habe ein neues Muster entdeckt.", "learn")
	await _settle_frames(8, 0.22)
	if not _save_capture(output_directory, "bitling-%s-dialogue.png" % viewport_name, "%s dialogue performance" % viewport_name):
		return false
	return true

func _prepare_deterministic_story_state() -> void:
	var onboarding := root.get_node_or_null("LegendaryOnboarding")
	if onboarding != null and onboarding.has_method("_close"):
		onboarding.call("_close")
	var state := root.get_node_or_null("GameState")
	if state != null and state.has_method("hatch"):
		state.call("hatch")
	var director := root.get_node_or_null("LegendarySlice")
	if director != null:
		director.call("reset_state")
		director.call("start_slice", "Zumi", "neugierig")
	var hud := root.get_node_or_null("LegendaryStoryHUD")
	if hud != null and hud.has_method("_refresh"):
		hud.call("_refresh")
	var performance := root.get_node_or_null("CharacterPerformance")
	if performance != null and performance.has_method("_apply_idle"):
		performance.call("_apply_idle", false)

func _prepare_rooftop_story_beat() -> void:
	var director := root.get_node_or_null("LegendarySlice")
	if director == null:
		return
	director.call("reset_state")
	director.call("start_slice", "Zumi", "neugierig")
	director.call("record_first_care", "care")
	for activity_id in ["resonance_rhythm", "signal_translation", "pattern_focus"]:
		director.call("record_activity", activity_id, {"accepted": true, "success": true, "score": 0.92})
	var hud := root.get_node_or_null("LegendaryStoryHUD")
	if hud != null and hud.has_method("_refresh"):
		hud.call("_refresh")
	var stage := root.find_child("LegendaryWave3LivingHomeStage3D", true, false)
	if stage == null:
		stage = root.find_child("LegendaryWave2CharacterStage3D", true, false)
	if stage != null and stage.has_method("set_story_beat"):
		stage.call("set_story_beat", "prismatic_rooftops")
	var audio := root.get_node_or_null("OmniAudio")
	if audio != null and audio.has_method("set_environment"):
		audio.call("set_environment", "ROOFTOPS")

func _settle_frames(frame_count: int, delay: float) -> void:
	for _frame in range(frame_count):
		await process_frame
	if delay > 0.0:
		await create_timer(delay).timeout

func _save_capture(output_directory: String, filename: String, label: String) -> bool:
	var image := root.get_texture().get_image()
	if image == null or image.is_empty():
		push_error("[VISUAL-CAPTURE] Empty image for %s" % label)
		return false
	var output_path := output_directory.path_join(filename)
	var save_error := image.save_png(output_path)
	if save_error != OK:
		push_error("[VISUAL-CAPTURE] Could not save %s: %s" % [output_path, save_error])
		return false
	print("[VISUAL-CAPTURE] %s %dx%d -> %s" % [label, image.get_width(), image.get_height(), output_path])
	return true
