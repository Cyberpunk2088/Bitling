extends SceneTree

var failures: Array[String] = []
var assertions := 0

func _init() -> void:
	call_deferred("_run")

func check(condition: bool, message: String) -> void:
	assertions += 1
	if not condition:
		failures.append(message)
		printerr("[ACTIVITY-SAVE] FAIL: ", message)

func _run() -> void:
	var token := OS.get_environment("BITLING_TEST_TOKEN")
	var mac_fixture := OS.get_name() == "macOS" and OS.get_user_data_dir().get_file().begins_with("BitlingRepairTests-") and token.length() >= 32 and FileAccess.file_exists("user://.bitling-test-fixture") and FileAccess.get_file_as_string("user://.bitling-test-fixture") == token
	if OS.get_environment("BITLING_TEST_ISOLATED") != "1" or not (OS.get_user_data_dir().begins_with("/tmp/") or mac_fixture):
		printerr("This test requires an isolated test project and BITLING_TEST_ISOLATED=1.")
		quit(2)
		return
	var state := root.get_node("GameState")
	state.set_process(false)
	var director := root.get_node("LegendarySlice")
	var activities := root.get_node("LegendaryActivities")
	root.get_node("LegendaryOnboarding").call("_close")
	if "--verify-restart" in OS.get_cmdline_user_args():
		var expected: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("user://activity-expectation.json"))
		check(int(state.get("total_xp")) == int(expected["total_xp"]), "XP survives a fresh process")
		for id: String in expected["attempts"]:
			check(int(director.activity_results.get(id, {}).get("attempts", 0)) == int(expected["attempts"][id]), id + " history survives a fresh process")
		_finish()
		return
	state.call("initialize_new_game")
	state.call("hatch")
	director.call("reset_state")
	state.call("save_game_state")
	for id in ["pattern_focus", "signal_translation", "resonance_rhythm"]:
		complete_activity(activities, id)
		var saved: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(state.SAVE_PATH))
		check(int(saved.get("total_xp", -1)) == int(state.get("total_xp")), id + " persists XP before reporting saved")
		check(is_equal_approx(float(saved.get("energy", -1)), float(state.get("energy"))), id + " persists care effects")
		check(activities.title_label.text == "VERBINDUNG GESPEICHERT", id + " confirms successful storage")
		activities.call("_close_overlay")
	# Cause a real write failure, keeping committed data intact.
	check(DirAccess.make_dir_absolute(state.TEMP_SAVE_PATH) == OK, "create isolated core I/O failure")
	var committed := FileAccess.get_file_as_string(state.SAVE_PATH)
	complete_activity(activities, "signal_translation")
	check(activities.title_label.text != "VERBINDUNG GESPEICHERT", "core I/O failure cannot claim saved")
	check(FileAccess.get_file_as_string(state.SAVE_PATH) == committed, "core I/O failure preserves committed bytes")
	DirAccess.remove_absolute(state.TEMP_SAVE_PATH)
	await retry_without_rewards(activities, state, director)
	activities.call("_close_overlay")
	check(DirAccess.make_dir_absolute(director.TEMP_PATH) == OK, "create isolated history I/O failure")
	complete_activity(activities, "resonance_rhythm")
	check(activities.title_label.text != "VERBINDUNG GESPEICHERT", "history I/O failure cannot claim saved")
	DirAccess.remove_absolute(director.TEMP_PATH)
	await retry_without_rewards(activities, state, director)
	activities.call("_close_overlay")
	var prior_xp := int(state.get("total_xp"))
	var prior_history: Dictionary = director.call("export_state")
	state.set("save_blocked", true)
	var rejected: Dictionary = activities.call("_commit_result", "pattern_focus", true, 1.0, 3, true)
	check(not bool(rejected.get("accepted", true)), "protected saves reject activity commits")
	check(int(state.get("total_xp")) == prior_xp and (director.call("export_state") as Dictionary) == prior_history, "protected saves preserve XP and activity history")
	state.set("save_blocked", false)
	var expected := {"total_xp": state.get("total_xp"), "attempts": {}}
	for id: String in director.activity_results:
		expected["attempts"][id] = director.activity_results[id]["attempts"]
	var file := FileAccess.open("user://activity-expectation.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(expected))
	file.close()
	_finish()

func complete_activity(activities: Node, id: String) -> void:
	activities.call("open_activity", id)
	activities.set("_successes", 3)
	activities.set("_score_total", 2.4)
	activities.call("_finish_current_activity")

func retry_without_rewards(activities: Node, state: Node, director: Node) -> void:
	var xp := int(state.get("total_xp"))
	var history: Dictionary = director.call("export_state")
	var retry := activities.find_child("RetryActivitySave", true, false) as Button
	check(retry != null, "failed storage offers a retry")
	if retry != null:
		retry.pressed.emit()
		await process_frame
		check(activities.title_label.text == "VERBINDUNG GESPEICHERT", "retry confirms recovered storage")
		check(int(state.get("total_xp")) == xp, "retry never grants duplicate XP")
		check((director.call("export_state") as Dictionary) == history, "retry never records another attempt")

func _finish() -> void:
	print("[ACTIVITY-SAVE] %d assertions, %d failures" % [assertions, failures.size()])
	quit(0 if failures.is_empty() else 1)
