extends SceneTree

const CAPTURES := [
	{"name": "phone", "size": Vector2i(390, 844)},
	{"name": "tablet", "size": Vector2i(900, 1200)},
	{"name": "laptop", "size": Vector2i(1440, 900)}
]

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var output_directory: String = ProjectSettings.globalize_path("res://builds/visual")
	var directory_error: Error = DirAccess.make_dir_recursive_absolute(output_directory)
	if directory_error != OK and directory_error != ERR_ALREADY_EXISTS:
		push_error("[LEARNING-CAPTURE] Could not create output directory")
		quit(1)
		return
	var packed: PackedScene = load("res://main.tscn") as PackedScene
	if packed == null:
		push_error("[LEARNING-CAPTURE] Main scene could not be loaded")
		quit(1)
		return
	for capture: Dictionary in CAPTURES:
		root.size = capture.get("size", Vector2i(390, 844)) as Vector2i
		var main: Node = packed.instantiate()
		root.add_child(main)
		await _settle(10, 0.20)
		_prepare_state()
		var overlay: Node = root.get_node_or_null("LearningAdventureOverlay")
		var service: Node = root.get_node_or_null("LearningAdventures")
		if overlay == null or service == null:
			push_error("[LEARNING-CAPTURE] Learning runtime unavailable")
			quit(1)
			return
		overlay.call("open_adventures")
		await _settle(10, 0.28)
		if not _save(output_directory, "bitling-%s-learning-catalog.png" % str(capture.get("name", "device"))):
			quit(1)
			return
		service.call("start_session", "emotion_compass", 8800)
		await _settle(10, 0.28)
		if not _save(output_directory, "bitling-%s-learning-session.png" % str(capture.get("name", "device"))):
			quit(1)
			return
		overlay.call("close_adventures")
		main.queue_free()
		await process_frame
	print("[LEARNING-CAPTURE] PASS")
	quit(0)

func _prepare_state() -> void:
	var onboarding: Node = root.get_node_or_null("LegendaryOnboarding")
	if onboarding != null and onboarding.has_method("_close"):
		onboarding.call("_close")
	var state: Node = root.get_node_or_null("GameState")
	if state != null and state.has_method("hatch"):
		state.call("hatch")
	var service: Node = root.get_node_or_null("LearningAdventures")
	if service != null and service.has_method("reset_state"):
		service.call("reset_state")

func _settle(frame_count: int, delay: float) -> void:
	for _frame: int in range(frame_count):
		await process_frame
	if delay > 0.0:
		await create_timer(delay).timeout

func _save(output_directory: String, filename: String) -> bool:
	var image: Image = root.get_texture().get_image()
	if image == null or image.is_empty():
		return false
	var path: String = output_directory.path_join(filename)
	var result: Error = image.save_png(path)
	if result != OK:
		return false
	print("[LEARNING-CAPTURE] %s %dx%d" % [filename, image.get_width(), image.get_height()])
	return true
