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
		for _frame in range(8):
			await process_frame
		await create_timer(0.15).timeout
		var image := root.get_texture().get_image()
		if image == null or image.is_empty():
			push_error("[VISUAL-CAPTURE] Empty image for %s" % capture.name)
			quit(1)
			return
		var output_path := output_directory.path_join("bitling-%s.png" % capture.name)
		var save_error := image.save_png(output_path)
		if save_error != OK:
			push_error("[VISUAL-CAPTURE] Could not save %s: %s" % [output_path, save_error])
			quit(1)
			return
		print("[VISUAL-CAPTURE] %s %dx%d -> %s" % [capture.name, image.get_width(), image.get_height(), output_path])
		dashboard.queue_free()
		await process_frame

	print("[VISUAL-CAPTURE] PASS")
	quit(0)
