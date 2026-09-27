extends SceneTree

var failures: Array[String] = []
var assertions := 0
var finished_count := 0

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	await process_frame
	root.get_node("LegendaryOnboarding").call("_close")
	var activity := root.get_node("LegendaryActivities")
	activity.activity_finished.connect(func(_id: String, _result: Dictionary): finished_count += 1)
	# An old answer's delayed continuation must not advance another game.
	activity.call("open_activity", "signal_translation")
	activity.call("_on_translation_answer", "wrong", "correct")
	activity.call("_close_overlay")
	activity.call("open_activity", "resonance_rhythm")
	await create_timer(1.0).timeout
	_check(int(activity.get("_round")) == 0, "a canceled translation timer cannot advance a fresh rhythm game")
	_check(int(activity.get("_rhythm_attempts")) == 0 and finished_count == 0, "canceled rounds create no attempts or completion")
	activity.call("_close_overlay")
	# Reopening the SAME game also needs a distinct session identity.
	activity.call("open_activity", "pattern_focus")
	await create_timer(1.0).timeout
	activity.call("_close_overlay")
	activity.call("open_activity", "pattern_focus")
	await create_timer(1.1).timeout
	_check(bool(activity.get("_locked")), "an old pattern timer cannot end the new observation period early")
	await create_timer(1.1).timeout
	_check(not bool(activity.get("_locked")), "the new pattern session unlocks on its own timer")
	activity.call("_close_overlay")
	# Positive control: normal current-session rounds still complete and reward once.
	activity.call("open_activity", "signal_translation")
	for index in range(3):
		var order: Array = activity.get("_translation_order")
		var question: Dictionary = activity.TRANSLATION_QUESTIONS[order[index]]
		var expected := str(question["meaning"])
		for option: Button in (activity.get("option_grid") as GridContainer).get_children():
			if option.text == expected:
				option.pressed.emit()
				break
		await create_timer(1.0).timeout
		_check(int(activity.get("_round")) == index + 1, "current-session round %d advances exactly once" % (index + 1))
	_check(finished_count == 1 and str((activity.get("primary_button") as Button).text) == "ZURÜCK ZUM BITLING", "three played rounds reach one completion and return control")
	activity.call("_close_overlay")
	await process_frame
	print("[ACTIVITY-SESSION] %d checks, %d failures" % [assertions, failures.size()])
	quit(0 if failures.is_empty() else 1)

func _check(condition: bool, message: String) -> void:
	assertions += 1
	if condition:
		print("[ACTIVITY-SESSION] PASS: %s" % message)
	else:
		failures.append(message)
		push_error("[ACTIVITY-SESSION] FAIL: %s" % message)
