extends SceneTree

var failures: Array[String] = []

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var packed := load("res://main.tscn") as PackedScene
	_check(packed != null, "premium main scene loads")
	if packed == null:
		_finish()
		return
	var main := packed.instantiate()
	root.add_child(main)
	for _index in range(10):
		await process_frame
	var overlay := root.get_node_or_null("LivingHomeOverlay")
	_check(overlay != null, "Living Home overlay exists")
	if overlay != null and overlay.has_method("open_home"):
		overlay.call("open_home")
		for _index in range(8):
			await process_frame
		var snapshot: Dictionary = overlay.call("get_overlay_snapshot")
		_check(bool(snapshot.get("open", false)), "Living Home opens")
		_check(bool(snapshot.get("fullscreen_stage", false)), "dedicated stage exists")
		_check(bool(snapshot.get("fullscreen_stage_visible", false)), "dedicated stage is visible")
		var stage := overlay.find_child("LivingHomeFullscreenStage3D", true, false)
		_check(stage != null, "Stage V12 is instantiated")
		if stage is Control:
			var control := stage as Control
			_check(control.anchor_right == 1.0 and control.anchor_bottom == 1.0, "stage fills viewport anchors")
		overlay.call("close_home")
		_check(not bool((overlay.call("get_overlay_snapshot") as Dictionary).get("open", true)), "Living Home closes")
	main.queue_free()
	await process_frame
	_finish()

func _check(condition: bool, message: String) -> void:
	if condition:
		print("[CI-WAVE3-FULL] PASS: %s" % message)
	else:
		failures.append(message)
		push_error("[CI-WAVE3-FULL] FAIL: %s" % message)

func _finish() -> void:
	if failures.is_empty():
		print("[CI-WAVE3-FULL] PASS")
		quit(0)
	else:
		print("[CI-WAVE3-FULL] BLOCKED: %d failure(s)" % failures.size())
		quit(1)
