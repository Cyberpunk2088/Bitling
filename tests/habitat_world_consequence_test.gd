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
	_check(service != null, "world consequence runtime is registered")
	_check(game_state != null, "GameState exists")
	if service == null or game_state == null:
		_finish()
		return
	habitat_backup = service.call("export_state") as Dictionary
	game_backup = game_state.call("get_save_data") as Dictionary
	service.call("reset_state")
	service.set("session_index", 1)
	_test_habit_manifestation(service)
	_test_follow_up_resolution(service)
	_test_conflict_returns_as_gameplay(service)
	_test_repaired_conflict_does_not_requeue(service)
	_test_world_persistence(service)
	await _test_world_ui(service)
	game_state.call("apply_save_data", game_backup)
	service.call("import_state", habitat_backup)
	_finish()

func _test_habit_manifestation(service: Node) -> void:
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
		_check(bool(result.get("accepted", false)), "habit contribution resolves in session %d" % (index + 1))
	var world: Dictionary = service.call("get_world_consequence_snapshot") as Dictionary
	var marks: Dictionary = world.get("world_marks", {}) as Dictionary
	_check(marks.has("window"), "formed novelty habit changes the physical window zone")
	var mark: Dictionary = marks.get("window", {}) as Dictionary
	_check(str(mark.get("state", "")) == "taste_lab", "habit produces its specific room state")
	_check(int(mark.get("level", 0)) == 1, "first manifestation starts at room level one")
	_check(int(world.get("pending_event_count", 0)) == 1, "formed habit creates a follow-up event")
	var moment: Dictionary = service.call("get_current_moment") as Dictionary
	_check(bool(moment.get("world_event", false)), "follow-up event becomes the active habitat moment")
	_check(str(moment.get("event_type", "")) == "initiative", "formed habit returns as Xogot's initiative")
	_check(str(moment.get("hotspot", "")) == "window", "initiative remains grounded in the changed room zone")
	_check(bool(moment.get("no_correct_answer", false)), "world follow-up preserves open-ended agency")

func _test_follow_up_resolution(service: Node) -> void:
	service.call("select_lens", "feed")
	var result: Dictionary = service.call("resolve_choice", "new_flavor") as Dictionary
	_check(str(result.get("world_resolution", "")) == "reinforced", "matching approach reinforces rather than merely closes the event")
	_check(not str(result.get("world_event_resolved", "")).is_empty(), "resolved world event is identified")
	var world: Dictionary = service.call("get_world_consequence_snapshot") as Dictionary
	_check(int(world.get("pending_event_count", -1)) == 0, "resolved initiative leaves the pending queue")
	_check((world.get("resolved_events", []) as Array).size() == 1, "resolved initiative enters durable world history")
	var mark: Dictionary = (world.get("world_marks", {}) as Dictionary).get("window", {}) as Dictionary
	_check(int(mark.get("level", 0)) == 2, "reinforcement visibly upgrades the room mark")
	_check(float(mark.get("intensity", 0.0)) > 55.0, "reinforcement increases visible room intensity")

func _test_conflict_returns_as_gameplay(service: Node) -> void:
	var orientations: Dictionary = service.get("axis_orientations") as Dictionary
	var conflicts: Dictionary = service.get("axis_conflicts") as Dictionary
	orientations["novelty"] = 80.0
	conflicts["novelty"] = 80.0
	service.set("axis_orientations", orientations)
	service.set("axis_conflicts", conflicts)
	service.call("select_lens", "feed")
	var trigger: Dictionary = service.call("resolve_choice", "familiar_snack") as Dictionary
	_check(not str(trigger.get("conflict_event_created", "")).is_empty(), "severe conflict creates a follow-up event")
	var world: Dictionary = service.call("get_world_consequence_snapshot") as Dictionary
	var event: Dictionary = world.get("active_event", {}) as Dictionary
	_check(str(event.get("type", "")) == "conflict", "conflict returns as gameplay instead of remaining a hidden meter")
	_check(str(event.get("axis", "")) == "novelty", "conflict event retains its causal relationship axis")
	var moment: Dictionary = service.call("get_current_moment") as Dictionary
	_check(str(moment.get("title", "")).begins_with("GRENZE:"), "severe conflict is explicit in the active situation")
	var before := float((service.get("axis_conflicts") as Dictionary).get("novelty", 0.0))
	service.call("select_lens", "care")
	var resolved: Dictionary = service.call("resolve_choice", "check_in") as Dictionary
	var after := float((service.get("axis_conflicts") as Dictionary).get("novelty", 0.0))
	_check(str(resolved.get("world_resolution", "")) == "redirected", "a different axis redirects the conflict without becoming a wrong answer")
	_check(float(resolved.get("conflict_repair", 0.0)) > 0.0, "living through the event mechanically changes conflict")
	_check(after < before, "resolved follow-up reduces persistent conflict")
	_check(int((service.call("get_world_consequence_snapshot") as Dictionary).get("pending_event_count", -1)) == 0, "conflict event must be played through once")

func _test_repaired_conflict_does_not_requeue(service: Node) -> void:
	var orientations: Dictionary = service.get("axis_orientations") as Dictionary
	var conflicts: Dictionary = service.get("axis_conflicts") as Dictionary
	var tiers: Dictionary = service.get("conflict_tiers") as Dictionary
	orientations["contact"] = -40.0
	conflicts["contact"] = 0.0
	conflicts["novelty"] = 38.0
	tiers["novelty"] = 0
	service.set("axis_orientations", orientations)
	service.set("axis_conflicts", conflicts)
	service.set("conflict_tiers", tiers)

	var manifestation: Dictionary = service.call("_conflict_manifestation", "novelty", 1) as Dictionary
	var event: Dictionary = service.call("_build_world_event", "conflict", manifestation, "stale-repair-test") as Dictionary
	event["axis"] = "novelty"
	event["conflict_strength"] = 38.0
	event["tier"] = 1
	var pending: Array = service.get("pending_world_events") as Array
	pending.clear()
	pending.append(event)
	service.set("pending_world_events", pending)

	service.call("select_lens", "care")
	var preview: Dictionary = service.call("preview_choice", "check_in") as Dictionary
	_check(str(preview.get("execution_mode", "")) == "negotiated", "repair scenario uses the negotiated conflict multiplier")
	var resolved: Dictionary = service.call("resolve_choice", "check_in") as Dictionary
	var novelty_after := float((service.get("axis_conflicts") as Dictionary).get("novelty", 0.0))
	_check(is_equal_approx(float(resolved.get("conflict_repair", 0.0)), 26.0), "negotiated follow-up applies the stronger repair amount")
	_check(novelty_after < 20.0, "negotiated repair lowers the source conflict below reset threshold")
	_check(int((service.call("get_world_consequence_snapshot") as Dictionary).get("pending_event_count", -1)) == 0, "repaired conflict does not requeue from a stale result snapshot")

func _test_world_persistence(service: Node) -> void:
	var exported: Dictionary = service.call("export_state") as Dictionary
	_check(exported.has("world_marks"), "room changes are part of the atomic save")
	_check(exported.has("pending_world_events"), "open follow-ups are persisted")
	_check(exported.has("resolved_world_events"), "resolved follow-ups are persisted")
	var resolved_count := (exported.get("resolved_world_events", []) as Array).size()
	service.call("reset_state")
	_check((service.call("get_world_consequence_snapshot") as Dictionary).get("marked_hotspot_count", -1) == 0, "reset clears persistent room marks")
	service.call("import_state", exported)
	var restored: Dictionary = service.call("get_world_consequence_snapshot") as Dictionary
	_check(int(restored.get("marked_hotspot_count", 0)) > 0, "room marks survive import")
	_check((restored.get("resolved_events", []) as Array).size() == resolved_count, "world event history survives import")
	_check(bool(service.call("save_state")), "world state saves through the existing atomic path")
	_check(bool(service.call("load_state")), "world state loads through the existing atomic path")

func _test_world_ui(_service: Node) -> void:
	var packed := load("res://main.tscn") as PackedScene
	_check(packed != null, "world consequence dashboard loads")
	if packed == null:
		return
	var original_size := root.size
	root.size = Vector2i(390, 844)
	var main := packed.instantiate()
	root.add_child(main)
	await _settle(10)
	_check(main.has_method("get_world_consequence_ui_snapshot"), "main scene exposes the world consequence UI contract")
	if main.has_method("get_world_consequence_ui_snapshot"):
		var snapshot: Dictionary = main.call("get_world_consequence_ui_snapshot") as Dictionary
		_check(bool(snapshot.get("world_panel_visible", false)), "persistent room state has a visible in-product panel")
		_check(bool(snapshot.get("stage_world_overlay_ready", false)), "production 3D stage owns a world consequence overlay")
		_check(bool(snapshot.get("center_is_game", false)), "world consequences preserve the center-is-game contract")
		var visual: Dictionary = snapshot.get("stage_world_visual", {}) as Dictionary
		_check(bool(visual.get("input_passthrough", false)), "persistent room visuals cannot steal habitat input")
		_check(int(visual.get("world_marks_visible", 0)) > 0, "persistent room change is rendered on the stage")
	main.queue_free()
	root.size = original_size
	await process_frame

func _settle(frames: int) -> void:
	for _index in range(frames):
		await process_frame

func _check(condition: bool, description: String) -> void:
	assertions += 1
	if condition:
		print("[WORLD-GATE] PASS: %s" % description)
	else:
		failures.append(description)
		push_error("[WORLD-GATE] FAIL: %s" % description)

func _finish() -> void:
	if failures.is_empty():
		print("[WORLD-GATE] PASS: %d assertions" % assertions)
		quit(0)
	else:
		print("[WORLD-GATE] BLOCKED: %d of %d assertions failed" % [failures.size(), assertions])
		quit(1)
