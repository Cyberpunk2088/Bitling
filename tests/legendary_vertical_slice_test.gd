extends SceneTree

var failures: Array[String] = []
var assertions := 0

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	await process_frame
	await process_frame
	_test_complete_story_path()
	_test_out_of_order_recovery()
	_test_activity_scoring()
	_test_bounded_history_and_persistence()
	if failures.is_empty():
		print("[CI-SLICE] PASS: %d assertions" % assertions)
		quit(0)
		return
	push_error("[CI-SLICE] FAIL: %d of %d assertions failed" % [failures.size(), assertions])
	for failure in failures:
		push_error("[CI-SLICE]   - %s" % failure)
	quit(1)

func _test_complete_story_path() -> void:
	var director := root.get_node_or_null("LegendarySlice")
	_assert(director != null, "LegendarySlice autoload exists")
	if director == null:
		return
	director.reset_state()
	var start: Dictionary = director.start_slice("Zumi", "neugierig")
	_assert(bool(start.get("active", false)), "Starting the slice activates the story")
	_assert(int(start.get("current_beat_index", -1)) == 1, "First contact advances to the care decision")
	_assert(str(start.get("bitling_name", "")) == "Zumi", "Local Bitling name is stored")
	director.record_first_care("care")
	_assert(int(director.current_beat_index) == 2, "First care advances to shared rhythm")
	director.record_activity("resonance_rhythm", {"accepted": true, "success": true, "score": 0.84})
	_assert(int(director.current_beat_index) == 3, "Rhythm advances to language")
	director.record_activity("signal_translation", {"accepted": true, "success": true, "score": 0.91})
	_assert(int(director.current_beat_index) == 4, "Translation advances to pattern focus")
	director.record_activity("pattern_focus", {"accepted": true, "success": true, "score": 0.88})
	_assert(int(director.current_beat_index) == 5, "Pattern focus advances to expedition")
	director.record_activity("prism_rooftops", {"accepted": true, "success": true, "score": 0.95})
	_assert(int(director.current_beat_index) == 6, "Expedition advances to evolution promise")
	var complete: Dictionary = director.choose_evolution_promise("kreativität")
	_assert(bool(complete.get("completed", false)), "Evolution promise completes the slice")
	_assert(is_equal_approx(float(complete.get("progress", 0.0)), 1.0), "Completed slice reports full progress")

func _test_out_of_order_recovery() -> void:
	var director := root.get_node("LegendarySlice")
	director.reset_state()
	director.start_slice("Nova", "ruhig")
	director.record_activity("pattern_focus", {"accepted": true, "success": true, "score": 0.8})
	_assert(int(director.current_beat_index) == 1, "Future activity does not skip required relationship beats")
	director.record_first_care("feed")
	director.record_activity("resonance_rhythm", {"accepted": true, "success": true, "score": 0.8})
	director.record_activity("signal_translation", {"accepted": true, "success": true, "score": 0.8})
	_assert(int(director.current_beat_index) == 5, "Previously completed valid activity is consumed when dependencies are met")

func _test_activity_scoring() -> void:
	var activities := root.get_node_or_null("LegendaryActivities")
	_assert(activities != null, "LegendaryActivities autoload exists")
	if activities == null:
		return
	var success: Dictionary = activities.simulate_activity("pattern_focus", [1.0, 0.8, 0.9])
	_assert(bool(success.get("accepted", false)), "Known activity accepts simulated scoring")
	_assert(bool(success.get("success", false)), "Strong average score succeeds")
	_assert(float(success.get("score", 0.0)) > 0.85, "Activity score preserves average quality")
	var failure: Dictionary = activities.simulate_activity("resonance_rhythm", [0.1, 0.3, 0.4])
	_assert(not bool(failure.get("success", true)), "Weak average score fails without rejecting the attempt")
	var invalid: Dictionary = activities.simulate_activity("unknown", [1.0])
	_assert(not bool(invalid.get("accepted", true)), "Unknown activity fails closed")

func _test_bounded_history_and_persistence() -> void:
	var director := root.get_node("LegendarySlice")
	director.reset_state()
	director.start_slice("Luma", "ermutigend")
	for index in range(40):
		director.record_activity("pattern_focus", {
			"accepted": true,
			"success": index % 2 == 0,
			"score": float(index % 10) / 10.0
		})
	_assert(director.activity_history.size() == director.MAX_ACTIVITY_HISTORY, "Activity history remains bounded")
	var expected_name := str(director.bitling_name)
	var expected_attempts := int((director.activity_results.get("pattern_focus", {}) as Dictionary).get("attempts", 0))
	_assert(director.save_state(), "Legendary Slice state writes atomically")
	director.active = false
	director.bitling_name = "VERLOREN"
	director.activity_results.clear()
	_assert(director.load_state(), "Legendary Slice state reloads")
	_assert(str(director.bitling_name) == expected_name, "Bitling name survives persistence")
	_assert(int((director.activity_results.get("pattern_focus", {}) as Dictionary).get("attempts", 0)) == expected_attempts, "Activity mastery survives persistence")

func _assert(condition: bool, description: String) -> void:
	assertions += 1
	if not condition:
		failures.append(description)
