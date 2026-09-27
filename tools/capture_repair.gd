extends SceneTree

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	DirAccess.make_dir_recursive_absolute("res://review-evidence")
	var dashboard = load("res://main.tscn").instantiate()
	root.size = Vector2i(1200, 820)
	root.add_child(dashboard)
	await capture("first-contact")
	var onboarding := root.get_node("LegendaryOnboarding")
	onboarding.call("_close")
	await capture("desktop-habitat")
	root.size = Vector2i(430, 932)
	await capture("phone-habitat")
	(dashboard.action_buttons["feed"] as Button).pressed.emit()
	await create_timer(2.0).timeout
	await capture("phone-choice")
	quit()

func capture(label: String) -> void:
	for frame in range(12):
		await process_frame
	await RenderingServer.frame_post_draw
	var status := root.get_texture().get_image().save_png("res://review-evidence/%s.png" % label)
	print("[REPAIR-CAPTURE] ", label, " result=", status, " size=", root.size)
