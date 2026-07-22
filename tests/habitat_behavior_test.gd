extends SceneTree

var failures: Array[String] = []
var assertions := 0
var habitat_backup: Dictionary = {}
var game_backup: Dictionary = {}

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	await process_frame
	await process_frame
	var service := root.get_node_or_null("HabitatInteraction")
	var game_state := root.get_node_or_null("GameState")
	var brain := root.get_node_or_null("CompanionBrain")
	_check(service != null, "behavior runtime is registered as HabitatInteraction")
	_check(game_state != null, "GameState exists")
	_check(brain != null, "CompanionBrain exists")
	if service == null or game_state == null or brain == null:
		_finish()
		return
	habitat_backup = service.call("export_state") as Dictionary
	game_backup = game_state.call("get_save_data") as Dictionary
	service.call("reset_state")
	service.set("session_index", 1)
	_test_preview_contract(service)
	_test_cross_session_habit(service, brain)
	_test_visible_conflict_and_execution(service)
	_test_persistence(service)
	await _test_behavior_dashboard()
	game_state.call("apply_save_data", game_backup)
	service.call("import_state", habitat_backup)
	_finish()

func _test_preview_contract(service: Node) -> void:
	_check(service.has_method("preview_choice"), "every choice has a deterministic pre-commit preview")
	_check(service.has_method("get_behavior_snapshot"), "persistent behavior state is inspectable")
	service.call("select_lens", "feed")
	var options: Array = service.call("get_lens_options", "feed") as Array
	_check(options.size() == 3, "behavior runtime preserves all three feed approaches")
	for option_variant in options:
		var option := option_variant as Dictionary
		_check(option.has("behavior_label"), "%s exposes Xogot's likely response" % str(option.get("id", "choice")))
		_check(option.has("habit_strength"), "%s exposes habit strength" % str(option.get("id", "choice")))
		_check(option.has("friction"), "%s exposes friction before commitment" % str(option.get("id", "choice")))
	var unknown: Dictionary = service.call("preview_choice", "unknown") as Dictionary
	_check(str(unknown.get("execution_mode", "")) == "embraced", "unknown behavior profiles fail open without hidden randomness")

func _test_cross_session_habit(service: Node, brain: Node) -> void:
	var contexts := ["window", "plant", "platform"]
	for index in range(contexts.size()):
		if index > 0:
			var carried: Dictionary = service.call("export_state") as Dictionary
			carried["session_index"] = int(carried.get("session_index", 0)) + 1
			service.call("import_state", carried)
			service.set("session_choice_ids", {})
		service.call("focus_hotspot", contexts[index])
		service.call("select_lens", "feed")
		var result: Dictionary = service.call("resolve_choice", "new_flavor") as Dictionary
		_check(bool(result.get("accepted", false)), "new flavor resolves in session %d" % (index + 1))
		_check(bool(result.get("behavior_changed", false)), "one habit contribution is allowed in session %d" % (index + 1))
	var behavior: Dictionary = service.call("get_behavior_snapshot") as Dictionary
	var habits: Dictionary = behavior.get("habits", {}) as Dictionary
	var habit: Dictionary = habits.get("new_flavor", {}) as Dictionary
	_check(not habit.is_empty(), "cross-session choice creates a persistent habit record")
	_check((habit.get("sessions", []) as Array).size() == 3, "habit requires three distinct sessions")
	_check((habit.get("contexts", []) as Array).size() >= 2, "habit requires multiple contexts")
	_check(bool(habit.get("formed", false)), "habit becomes formed only after session and context thresholds")
	_check(float(habit.get("strength", 0.0)) >= 55.0, "formed habit crosses the explicit strength threshold")
	_check(str(brain.get("current_intention")) == "discover", "formed novelty habit changes Xogot's actual future intention")
	service.call("select_lens", "feed")
	var result_again: Dictionary = service.call("resolve_choice", "new_flavor") as Dictionary
	_check(not bool(result_again.get("behavior_changed", true)), "same-session repetition cannot strengthen the habit again")

func _test_visible_conflict_and_execution(service: Node) -> void:
	var orientations: Dictionary = service.get("axis_orientations") as Dictionary
	var conflicts: Dictionary = service.get("axis_conflicts") as Dictionary
	orientations["novelty"] = 80.0
	conflicts["novelty"] = 80.0
	service.set("axis_orientations", orientations)
	service.set("axis_conflicts", conflicts)
	var preview: Dictionary = service.call("preview_choice", "familiar_snack") as Dictionary
	_check(str(preview.get("execution_mode", "")) == "resisted", "strong opposing history becomes a visible boundary")
	_check(str(preview.get("behavior_label", "")) == "GRENZE", "boundary is labeled before commitment")
	_check(float(preview.get("friction", 0.0)) >= 74.0, "boundary crosses the explicit resistance threshold")
	var adjusted: Dictionary = service.call("_apply_execution_to_effects", {"hunger": 10.0, "happiness": 10.0}, 0.38) as Dictionary
	_check(is_equal_approx(float(adjusted.get("hunger", 0.0)), 10.0), "resistance never removes essential care utility")
	_check(float(adjusted.get("happiness", 10.0)) < 4.0, "resistance reduces non-essential reward effects")
	service.call("select_lens", "feed")
	var option: Dictionary = (service.call("get_lens_options", "feed") as Array)[0] as Dictionary
	var result: Dictionary = service.call("resolve_choice", "familiar_snack") as Dictionary
	_check(str(result.get("execution_mode", "")) == "resisted", "resolved behavior matches the visible preview")
	_check(is_equal_approx(float(result.get("execution_multiplier", 0.0)), 0.38), "resisted execution uses the bounded multiplier")
	_check(int(result.get("xp_reward", 99)) < int(option.get("xp", 0)), "boundary changes mechanical reward rather than only text")
	_check(str(result.get("response", "")).contains("Grenze"), "Xogot's response names the enacted boundary")

func _test_persistence(service: Node) -> void:
	var exported: Dictionary = service.call("export_state") as Dictionary
	_check(exported.has("habits"), "habits are part of the atomic habitat save")
	_check(exported.has("axis_orientations"), "behavior orientations are persisted")
	_check(exported.has("axis_conflicts"), "relationship conflicts are persisted")
	var session_before := int(exported.get("session_index", 0))
	service.call("reset_state")
	service.call("import_state", exported)
	var restored: Dictionary = service.call("get_behavior_snapshot") as Dictionary
	_check(int(restored.get("session_index", -1)) == session_before, "session history survives import")
	_check(not (restored.get("habits", {}) as Dictionary).is_empty(), "habit records survive import")
	_check(not (restored.get("active_conflict", {}) as Dictionary).is_empty(), "active conflict survives import")
	_check(bool(service.call("save_state")), "behavior state saves through the existing atomic path")
	_check(bool(service.call("load_state")), "behavior state loads through the existing atomic path")

func _test_behavior_dashboard() -> void:
	var packed := load("res://main.tscn") as PackedScene
	_check(packed != null, "behavior dashboard main scene loads")
	if packed == null:
		return
	var original_size := root.size
	root.size = Vector2i(390, 844)
	var main := packed.instantiate()
	root.add_child(main)
	await _settle(8)
	_check(main.has_method("get_behavior_ui_snapshot"), "main scene exposes the persistent behavior UI contract")
	if main.has_method("get_behavior_ui_snapshot"):
		var snapshot: Dictionary = main.call("get_behavior_ui_snapshot") as Dictionary
		_check(bool(snapshot.get("persistent_behavior_visible", false)), "habit and conflict panel is visible")
		_check(bool(snapshot.get("option_preview_visible", false)), "every visible choice shows Xogot's anticipated response")
		_check(bool(snapshot.get("center_is_game", false)), "behavior UI preserves the center-is-game contract")
	main.queue_free()
	root.size = original_size
	await process_frame

func _settle(frames: int) -> void:
	for _index in range(frames):
		await process_frame

func _check(condition: bool, description: String) -> void:
	assertions += 1
	if condition:
		print("[BEHAVIOR-GATE] PASS: %s" % description)
	else:
		failures.append(description)
		push_error("[BEHAVIOR-GATE] FAIL: %s" % description)

func _finish() -> void:
	if failures.is_empty():
		print("[BEHAVIOR-GATE] PASS: %d assertions" % assertions)
		quit(0)
	else:
		print("[BEHAVIOR-GATE] BLOCKED: %d of %d assertions failed" % [failures.size(), assertions])
		quit(1)
