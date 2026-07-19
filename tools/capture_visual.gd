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
		if not _save_capture(output_directory, "bitling-%s.png" % capture.name, str(capture.name)):
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

		dashboard.queue_free()
		await process_frame

	print("[VISUAL-CAPTURE] PASS")
	quit(0)

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
