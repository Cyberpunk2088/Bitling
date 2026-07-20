extends SceneTree

var failures: Array[String] = []
var assertions: int = 0

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	await _settle(10)
	var service := root.get_node_or_null("LearningAdventures")
	var overlay := root.get_node_or_null("LearningAdventureOverlay")
	var polish := root.get_node_or_null("LearningAdventureVisualPolish")
	_check(service != null, "learning service exists")
	_check(overlay != null, "learning overlay exists")
	_check(polish != null, "visual polish exists")
	if service == null or overlay == null or polish == null:
		_finish()
		return
	var backup: Dictionary = service.call("export_state") as Dictionary
	var original_size := root.size
	service.call("reset_state")
	root.size = Vector2i(390, 844)
	await _settle(5)
	overlay.call("open_adventures")
	await _settle(5)
	var status: Dictionary = polish.call("get_status")
	_check(bool(status.get("installed", false)), "polish installs")
	_check(bool(status.get("catalog_hero", false)), "catalog hero is present")
	var start: Dictionary = service.call("start_session", "emotion_compass", 905)
	_check(bool(start.get("accepted", false)), "session starts")
	await _settle(5)
	status = polish.call("get_status")
	_check(int(status.get("session_columns", 0)) == 1, "phone layout is stacked")
	_check(bool((status.get("companion_stage", {}) as Dictionary).get("bitling_visible", false)), "Bitling is visible in the session")
	root.size = Vector2i(1440, 900)
	await _settle(5)
	status = polish.call("get_status")
	_check(int(status.get("session_columns", 0)) == 2, "laptop layout is two-column")
	overlay.call("close_adventures")
	service.call("import_state", backup)
	service.call("save_state")
	root.size = original_size
	_finish()

func _settle(count: int) -> void:
	for _index: int in range(count):
		await process_frame

func _check(condition: bool, description: String) -> void:
	assertions += 1
	if condition:
		print("[CI-WAVE5-VISUAL] PASS: %s" % description)
	else:
		failures.append(description)
		push_error("[CI-WAVE5-VISUAL] FAIL: %s" % description)

func _finish() -> void:
	if failures.is_empty():
		print("[CI-WAVE5-VISUAL] PASS: %d assertions" % assertions)
		quit(0)
	else:
		print("[CI-WAVE5-VISUAL] BLOCKED: %d of %d assertions failed" % [failures.size(), assertions])
		quit(1)
