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
	_check(service != null, "live action runtime is registered")
	_check(game_state != null, "GameState exists")
	if service == null or game_state == null:
		_finish()
		return
	habitat_backup = service.call("export_state") as Dictionary
	game_backup = game_state.call("get_save_data") as Dictionary
	service.call("reset_state")
	service.set("session_index", 1)
	_test_five_phase_deferred_commit(service)
	_test_lens_changes_in_world_choices(service)
	_test_autonomous_initiative(service)
	_test_transient_and_persistent_state(service)
	await _test_live_action_dashboard(service)
	game_state.call("apply_save_data", game_backup)
	service.call("import_state", habitat_backup)
	_finish()

func _test_five_phase_deferred_commit(service: Node) -> void:
	var idle: Dictionary = service.call("get_live_action_snapshot") as Dictionary
	_check(not bool(idle.get("active", true)), "live loop begins idle")
	_check(str(idle.get("phase", "")) == "idle", "idle phase is explicit")
	var resolved_before := int(service.get("resolved_count"))
	var started: Dictionary = service.call("start_encounter", "window", "player", true) as Dictionary
	_check(bool(started.get("accepted", false)), "player can start an encounter from a room object")
	var snapshot: Dictionary = started.get("snapshot", {}) as Dictionary
	_check(str(snapshot.get("phase", "")) == "approach", "encounter begins with Xogot approaching")
	_check(str(snapshot.get("hotspot", "")) == "window", "approach remains grounded in the selected hotspot")
	_check(str(snapshot.get("source", "")) == "player", "player-started encounter records its source")
	_check(int(service.get("resolved_count")) == resolved_before, "approach cannot commit rewards or consequences")

	service.call("advance_live_action", 0.91)
	snapshot = service.call("get_live_action_snapshot") as Dictionary
	_check(str(snapshot.get("phase", "")) == "observe", "approach advances to observation")
	_check(int(service.get("resolved_count")) == resolved_before, "observation still cannot commit")
	service.call("advance_live_action", 0.63)
	snapshot = service.call("get_live_action_snapshot") as Dictionary
	_check(str(snapshot.get("phase", "")) == "awaiting_choice", "observation opens the in-world choice phase")
	_check(int(snapshot.get("choice_count", 0)) == 3, "exactly three in-world approaches are exposed")
	_check(float(snapshot.get("phase_progress", 0.0)) == 1.0, "awaiting choice has no hidden timer")
	var rejected: Dictionary = service.call("begin_choice_sequence", "not_available") as Dictionary
	_check(not bool(rejected.get("accepted", true)), "unavailable in-world choices are rejected")
	var choice := (snapshot.get("choices", []) as Array)[0] as Dictionary
	var choice_id := str(choice.get("id", ""))
	var begun: Dictionary = service.call("begin_choice_sequence", choice_id) as Dictionary
	_check(bool(begun.get("accepted", false)) and bool(begun.get("pending", false)), "choice starts a visible performance instead of resolving immediately")
	_check(str((service.call("get_live_action_snapshot") as Dictionary).get("phase", "")) == "perform", "choice enters the performance phase")
	_check(int(service.get("resolved_count")) == resolved_before, "selection alone cannot commit the outcome")
	service.call("advance_live_action", 0.60)
	_check(int(service.get("resolved_count")) == resolved_before, "partial performance cannot commit the outcome")
	service.call("advance_live_action", 0.70)
	snapshot = service.call("get_live_action_snapshot") as Dictionary
	_check(str(snapshot.get("phase", "")) == "aftermath", "completed performance enters aftermath")
	_check(int(service.get("resolved_count")) == resolved_before + 1, "outcome commits only after visible performance")
	var result: Dictionary = snapshot.get("result", {}) as Dictionary
	_check(bool(result.get("committed_after_performance", false)), "result publishes the deferred-commit contract")
	_check(not str(result.get("live_action_id", "")).is_empty(), "committed result retains its action sequence identity")
	_check(int(snapshot.get("completed_count", 0)) == 1, "completed action is counted")
	service.call("advance_live_action", 0.83)
	snapshot = service.call("get_live_action_snapshot") as Dictionary
	_check(str(snapshot.get("phase", "")) == "idle" and not bool(snapshot.get("active", true)), "aftermath returns control to the open room")
	_check(not (snapshot.get("last_result", {}) as Dictionary).is_empty(), "last performed consequence remains inspectable")

func _test_lens_changes_in_world_choices(service: Node) -> void:
	service.call("start_encounter", "plant", "player", true)
	service.call("advance_live_action", 2.0)
	service.call("advance_live_action", 2.0)
	var snapshot: Dictionary = service.call("get_live_action_snapshot") as Dictionary
	_check(str(snapshot.get("phase", "")) == "awaiting_choice", "plant encounter reaches in-world choice")
	var before_ids := _choice_ids(snapshot.get("choices", []) as Array)
	service.call("select_lens", "play")
	snapshot = service.call("get_live_action_snapshot") as Dictionary
	var after_ids := _choice_ids(snapshot.get("choices", []) as Array)
	_check(str(snapshot.get("phase", "")) == "awaiting_choice", "changing stance does not restart the encounter")
	_check(str(snapshot.get("selected_lens", "")) == "play", "live encounter records the changed stance")
	_check(before_ids != after_ids, "changing stance replaces the three physical approaches")
	_check(after_ids == ["follow_rule", "invent_together", "let_lead"], "play stance exposes its canonical in-world approaches")
	service.call("begin_choice_sequence", after_ids[1])
	service.call("advance_live_action", 2.0)
	service.call("advance_live_action", 2.0)
	_check(str((service.call("get_live_action_snapshot") as Dictionary).get("phase", "")) == "idle", "second sequence completes cleanly")

func _test_autonomous_initiative(service: Node) -> void:
	var started: Dictionary = service.call("trigger_autonomous_initiative") as Dictionary
	_check(bool(started.get("accepted", false)), "Xogot can initiate the loop without a player hotspot click")
	var snapshot: Dictionary = started.get("snapshot", {}) as Dictionary
	_check(str(snapshot.get("source", "")) == "xogot", "autonomous initiative is explicitly attributed to Xogot")
	_check(str(snapshot.get("phase", "")) == "approach", "Xogot initiative uses the same readable approach phase")
	_check(int(snapshot.get("choice_count", 0)) == 3, "autonomous initiative preserves player agency at the decision point")
	service.call("advance_live_action", 2.0)
	service.call("advance_live_action", 2.0)
	snapshot = service.call("get_live_action_snapshot") as Dictionary
	var choices: Array = snapshot.get("choices", []) as Array
	service.call("begin_choice_sequence", str((choices[0] as Dictionary).get("id", "")))
	service.call("advance_live_action", 2.0)
	service.call("advance_live_action", 2.0)
	_check(str((service.call("get_live_action_snapshot") as Dictionary).get("phase", "")) == "idle", "autonomous initiative resolves through the normal loop")

func _test_transient_and_persistent_state(service: Node) -> void:
	var completed_before := int((service.call("get_live_action_snapshot") as Dictionary).get("completed_count", 0))
	service.call("start_encounter", "sleep", "player", true)
	var exported: Dictionary = service.call("export_state") as Dictionary
	_check(exported.has("completed_live_action_count"), "completed live action count is persisted")
	_check(exported.has("completed_live_actions"), "completed live action history is persisted")
	_check(not exported.has("live_action"), "unfinished animation phase is deliberately not persisted")
	service.call("import_state", exported)
	var restored: Dictionary = service.call("get_live_action_snapshot") as Dictionary
	_check(str(restored.get("phase", "")) == "idle", "loading cannot resume inside a stale animation phase")
	_check(int(restored.get("completed_count", -1)) == completed_before, "completed sequence history survives import")
	_check(bool(service.call("save_state")), "live action history uses the existing atomic save path")
	_check(bool(service.call("load_state")), "live action history loads through the existing atomic path")

func _test_live_action_dashboard(service: Node) -> void:
	service.call("reset_state")
	var packed := load("res://main.tscn") as PackedScene
	_check(packed != null, "live action main scene loads")
	if packed == null:
		return
	var original_size := root.size
	root.size = Vector2i(390, 844)
	var main := packed.instantiate()
	root.add_child(main)
	await _settle(10)
	_check(main.has_method("get_live_action_ui_snapshot"), "main scene exposes the live action UI contract")
	var stage: Control = main.get("stage") as Control
	_check(stage != null, "production stage remains the central surface")
	if main.has_method("get_live_action_ui_snapshot") and stage != null:
		var initial: Dictionary = main.call("get_live_action_ui_snapshot") as Dictionary
		_check(bool(initial.get("dashboard_moment_card_hidden", false)), "central moment card is removed from the primary surface")
		_check(bool(initial.get("dashboard_choice_card_hidden", false)), "dashboard choice card is removed from the primary surface")
		_check(bool(initial.get("stage_live_action_overlay_ready", false)), "production stage owns the live action overlay")
		_check(bool(initial.get("center_is_game", false)), "live action dashboard preserves center-is-game")

		var started: Dictionary = service.call("start_encounter", "platform", "player", true) as Dictionary
		_check(bool(started.get("accepted", false)), "phone UI can start a platform encounter")
		await _settle(8)
		var stage_before: Dictionary = stage.call("get_habitat_interaction_snapshot") as Dictionary
		var position_before := stage_before.get("bitling_world_position", Vector3.ZERO) as Vector3
		var target := stage_before.get("bitling_world_target", Vector3.ZERO) as Vector3
		await _settle(20)
		var stage_after: Dictionary = stage.call("get_habitat_interaction_snapshot") as Dictionary
		var position_after := stage_after.get("bitling_world_position", Vector3.ZERO) as Vector3
		_check(position_after.distance_to(target) < position_before.distance_to(target), "Xogot visibly moves toward the selected room object")

		service.call("advance_live_action", 2.0)
		service.call("advance_live_action", 2.0)
		await _settle(4)
		var awaiting: Dictionary = main.call("get_live_action_ui_snapshot") as Dictionary
		var visual: Dictionary = awaiting.get("stage_live_action_visual", {}) as Dictionary
		_check(bool(awaiting.get("in_world_choice_surface", false)), "phone presents decisions inside the stage")
		_check(int(visual.get("choice_tokens_visible", 0)) == 3, "all three in-world tokens remain visible on phone")
		_check(bool(visual.get("input_passthrough", false)), "visual overlay cannot steal stage input")
		_check(stage.call("activate_live_action_choice", 0), "stage token activates the authoritative choice path")
		await _settle(2)
		_check(str((service.call("get_live_action_snapshot") as Dictionary).get("phase", "")) == "perform", "stage token begins Xogot's visible performance")
		service.call("advance_live_action", 2.0)
		service.call("advance_live_action", 2.0)
		await _settle(3)

		root.size = Vector2i(1440, 900)
		await _settle(8)
		service.call("start_encounter", "workbench", "player", true)
		service.call("advance_live_action", 2.0)
		service.call("advance_live_action", 2.0)
		await _settle(4)
		var desktop: Dictionary = main.call("get_live_action_ui_snapshot") as Dictionary
		var desktop_visual: Dictionary = desktop.get("stage_live_action_visual", {}) as Dictionary
		_check(int(desktop_visual.get("choice_tokens_visible", 0)) == 3, "desktop keeps the same three in-world choices")
		_check(bool(desktop.get("dashboard_choice_card_hidden", false)), "desktop cannot regress to card-first gameplay")
	main.queue_free()
	root.size = original_size
	await process_frame

func _choice_ids(choices: Array) -> Array[String]:
	var result: Array[String] = []
	for choice_variant in choices:
		if choice_variant is Dictionary:
			result.append(str((choice_variant as Dictionary).get("id", "")))
	return result

func _settle(frames: int) -> void:
	for _index in range(frames):
		await process_frame

func _check(condition: bool, description: String) -> void:
	assertions += 1
	if condition:
		print("[LIVE-ACTION-GATE] PASS: %s" % description)
	else:
		failures.append(description)
		push_error("[LIVE-ACTION-GATE] FAIL: %s" % description)

func _finish() -> void:
	if failures.is_empty():
		print("[LIVE-ACTION-GATE] PASS: %d assertions" % assertions)
		quit(0)
	else:
		print("[LIVE-ACTION-GATE] BLOCKED: %d of %d assertions failed" % [failures.size(), assertions])
		quit(1)
