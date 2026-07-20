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
	var context := root.get_node_or_null("LearningDecisionContextPolish")
	var transfer := root.get_node_or_null("LearningTransferMapPolish")
	_check(service != null, "learning service exists")
	_check(overlay != null, "learning overlay exists")
	_check(polish != null, "visual polish exists")
	_check(context != null, "decision context exists")
	_check(transfer != null, "transfer constellation exists")
	if service == null or overlay == null or polish == null or context == null or transfer == null:
		_finish()
		return
	var backup: Dictionary = service.call("export_state") as Dictionary
	var original_size := root.size
	var state := root.get_node_or_null("GameState")
	var original_reduce_motion: bool = false
	if state != null:
		original_reduce_motion = bool(state.settings.get("reduce_motion", false))
		state.settings["reduce_motion"] = true
	service.call("reset_state")
	root.size = Vector2i(390, 844)
	await _settle(5)
	overlay.call("open_adventures")
	await _settle(5)
	var status: Dictionary = polish.call("get_status")
	var context_status: Dictionary = context.call("get_status")
	var transfer_status: Dictionary = transfer.call("get_status")
	_check(bool(status.get("installed", false)), "polish installs")
	_check(bool(status.get("catalog_hero", false)), "catalog hero is present")
	_check(bool(context_status.get("installed", false)), "decision context installs")
	_check(int(context_status.get("context_cards", 0)) == 4, "four useful context cards replace empty space")
	_check(bool(transfer_status.get("installed", false)), "transfer constellation installs")
	_check(int((transfer_status.get("map", {}) as Dictionary).get("nodes", 0)) == 4, "transfer constellation exposes four connected nodes")
	var start: Dictionary = service.call("start_session", "emotion_compass", 905)
	_check(bool(start.get("accepted", false)), "session starts")
	await _settle(5)
	status = polish.call("get_status")
	context_status = context.call("get_status")
	transfer_status = transfer.call("get_status")
	_check(int(status.get("session_columns", 0)) == 1, "phone layout is stacked")
	_check(bool((status.get("companion_stage", {}) as Dictionary).get("bitling_visible", false)), "Bitling is visible in the session")
	_check(bool((status.get("companion_stage", {}) as Dictionary).get("reduced_motion", false)), "learning stage respects reduced motion")
	_check(str(context_status.get("active_adventure", "")) == "emotion_compass", "context follows the active adventure")
	_check(float(context_status.get("minimum_text_font", 0.0)) >= 12.0, "phone transfer context text stays readable")
	_check(str((transfer_status.get("map", {}) as Dictionary).get("domain", "")) == "EMPATHY", "constellation follows the learning domain")
	_check(bool((transfer_status.get("map", {}) as Dictionary).get("reduced_motion", false)), "transfer constellation respects reduced motion")
	if overlay.has_method("get_mobile_readability_snapshot"):
		var readable: Dictionary = overlay.call("get_mobile_readability_snapshot")
		_check(int(readable.get("approach_columns", 0)) == 2, "phone visual polish preserves two-column Denkweg layout")
		_check(int(readable.get("approach_min_font", 0)) >= 12, "phone visual polish keeps Denkweg labels readable")
	root.size = Vector2i(1440, 900)
	await _settle(5)
	status = polish.call("get_status")
	transfer_status = transfer.call("get_status")
	_check(int(status.get("session_columns", 0)) == 2, "laptop layout is two-column")
	_check(float(transfer_status.get("minimum_height", 0.0)) >= 300.0, "desktop constellation fills the decision space")
	overlay.call("close_adventures")
	if state != null:
		state.settings["reduce_motion"] = original_reduce_motion
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
