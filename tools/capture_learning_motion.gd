extends SceneTree

## Native-renderer recording of the same component embedded in learning screens.
var stage: Control
var caption: Label

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	if OS.get_environment("BITLING_TEST_ISOLATED") != "1":
		quit(2)
		return
	root.size = Vector2i(560, 700)
	root.content_scale_size = Vector2i(560, 700)
	await process_frame
	await process_frame
	var onboarding := root.get_node_or_null("LegendaryOnboarding")
	if onboarding != null: onboarding.call("_close")
	var profile := root.get_node_or_null("ProfileOverlay")
	if profile != null: (profile.get("launcher") as Control).hide()
	var backdrop := ColorRect.new()
	backdrop.color = Color("102428")
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# Component recording: keep unrelated autoload HUDs below this test canvas.
	var canvas := CanvasLayer.new()
	canvas.layer = 1000
	root.add_child(canvas)
	canvas.add_child(backdrop)
	var title := Label.new()
	title.text = "LUMO · BEWEGUNGSPROBE"
	title.position = Vector2(30, 26)
	title.add_theme_font_size_override("font_size", 23)
	backdrop.add_child(title)
	stage = load("res://scripts/ui/learning_companion_stage.gd").new() as Control
	stage.position = Vector2(20, 78)
	stage.size = Vector2(520, 540)
	backdrop.add_child(stage)
	stage.call("set_context", "emotion_compass", "empathy", 1, "observe")
	caption = Label.new()
	caption.position = Vector2(25, 632)
	caption.size = Vector2(510, 54)
	caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	caption.add_theme_font_size_override("font_size", 19)
	backdrop.add_child(caption)
	var folder := ProjectSettings.globalize_path("user://motion-frames")
	DirAccess.make_dir_recursive_absolute(folder)
	var observations: Array[Dictionary] = []
	# Fixed delta for repeatable poses; native render output remains real.
	for frame in range(180):
		if frame == 0: caption.text = "Ruhe: Kopf, Ohren, Atem und Schweif"
		if frame == 45:
			caption.text = "Berührung: LUMO begrüßt dich"
			var actor := stage.get_node_or_null("LearningCompanionActor")
			if actor != null:
				var click := InputEventMouseButton.new()
				click.button_index = MOUSE_BUTTON_LEFT
				var snapshot: Dictionary = actor.call("get_animation_snapshot")
				var art_rect: Rect2 = snapshot.get("art_rect", Rect2())
				click.position = actor.get_global_transform_with_canvas() * (art_rect.position + art_rect.size * Vector2(0.55, 0.35))
				click.pressed = true
				root.push_input(click, true)
				click = click.duplicate() as InputEventMouseButton
				click.pressed = false
				root.push_input(click, true)
				if str((actor.call("get_animation_snapshot") as Dictionary).get("reaction", "")) != "greet":
					printerr("[MOTION-CAPTURE] The real tap did not reach the companion.")
					quit(1)
					return
		if frame == 90:
			caption.text = "Entdeckung: Freude über eure Lösung"
			stage.call("set_result", true)
		if frame == 135:
			caption.text = "Nachdenken: gemeinsam weiterprobieren"
			stage.call("set_result", false)
		await process_frame
		await RenderingServer.frame_post_draw
		var recorded_actor := stage.get_node("LearningCompanionActor")
		var recorded: Dictionary = recorded_actor.call("get_animation_snapshot")
		observations.append({"frame": frame, "blink": recorded.get("blink", 0.0), "reaction": recorded.get("reaction", ""), "focused": (recorded_actor as Control).has_focus(), "topology_valid": recorded.get("topology_valid", false)})
		var screenshot := root.get_texture().get_image()
		if screenshot.save_png(folder.path_join("frame-%04d.png" % frame)) != OK:
			quit(1)
			return
	var report := FileAccess.open(folder.path_join("animation.json"), FileAccess.WRITE)
	if report == null:
		quit(1)
		return
	report.store_string(JSON.stringify(observations, "\t"))
	report.close()
	print("[MOTION-CAPTURE] 180 frames written to ", folder)
	quit(0)
