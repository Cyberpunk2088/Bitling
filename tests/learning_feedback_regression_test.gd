extends SceneTree

var assertions := 0
var failures: Array[String] = []

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var token := OS.get_environment("BITLING_TEST_TOKEN")
	var mac_fixture := OS.get_name() == "macOS" and OS.get_user_data_dir().get_file().begins_with("BitlingRepairTests-") and token.length() >= 32 and FileAccess.file_exists("user://.bitling-test-fixture") and FileAccess.get_file_as_string("user://.bitling-test-fixture") == token
	if OS.get_environment("BITLING_TEST_ISOLATED") != "1" or not (OS.get_user_data_dir().begins_with("/tmp/") or mac_fixture):
		printerr("Learning feedback tests require an isolated, marked test fixture.")
		quit(2)
		return
	root.size = Vector2i(430, 932)
	await settle()
	root.get_node("LegendaryOnboarding").call("_close")
	var overlay := root.get_node("LearningAdventureOverlay")
	var service := root.get_node("LearningAdventures")
	root.get_node("GameState").set_process(false)
	overlay.call("open_adventures")
	await settle()
	await capture("learning-catalog")
	overlay.call("_start_adventure", "signal_translation")
	await settle()
	var prompt := overlay.get("_prompt") as Label
	var feedback := overlay.get("_feedback") as Label
	var companion := overlay.find_child("LearningSessionCompanionStage", true, false)
	check(companion != null and bool((companion.call("get_visual_snapshot") as Dictionary).illustrated_companion), "reference-directed companion artwork loads in the real learning screen")
	var live_animation: Dictionary = (companion.call("get_visual_snapshot") as Dictionary).get("animation", {})
	check(bool(live_animation.get("art_loaded", false)) and (live_animation.get("vertices", PackedVector2Array()) as PackedVector2Array).size() > 0, "the learning screen embeds the real articulated render mesh")
	var original_prompt := prompt.text
	var challenge: Dictionary = service.active_session.challenge
	var correct: Array = challenge.correct_indices
	var wrong := 0
	while correct.has(wrong): wrong += 1
	var wrong_text := str(challenge.answers[wrong])
	var right_text := str(challenge.answers[int(correct[0])])
	var answers: Array = overlay.get("_answer_buttons")
	var old_answer := answers[wrong] as Button
	old_answer.pressed.emit()
	check(prompt.text == original_prompt, "feedback retains the answered question")
	check(feedback.text.contains(wrong_text) and feedback.text.contains(right_text), "feedback identifies the selected and suitable answers")
	check(feedback.text.contains(str(challenge.explanation)), "feedback explains this question")
	var visual: Dictionary = companion.call("get_visual_snapshot")
	check(int(visual.round) == 1 and int(visual.result_state) == -1, "companion keeps the answered round and its feedback state")
	check(str((visual.get("animation", {}) as Dictionary).get("reaction", "")) == "think", "an actual incorrect learning answer reaches the actor's thinking reaction")
	old_answer.pressed.emit()
	check(int(service.active_session.round) == 1, "rapid duplicate submission cannot consume another round")
	await create_timer(1.35).timeout
	check(prompt.text == original_prompt, "reading time is controlled by the learner")
	var next := continue_button(overlay)
	check(next != null and next.is_visible_in_tree() and not next.disabled, "feedback provides one reachable continue action")
	if next == null:
		overlay.call("close_adventures")
		finish()
		return
	check(root.gui_get_focus_owner() == next, "keyboard focus follows the feedback action")
	check(next.custom_minimum_size.y >= 58.0, "feedback action has a usable phone touch target")
	check((root.get_screen_transform() * feedback.get_global_transform_with_canvas()).get_scale().y * feedback.get_theme_font_size("font_size") >= 13.5, "feedback remains readable after the real window stretch")
	check((root.get_screen_transform() * next.get_global_transform_with_canvas()).get_scale().y * next.size.y >= 44.0, "continue retains a real screen touch height")
	check(not (root.get_node("ProfileOverlay").get("launcher") as Control).visible, "profile launcher does not cover the learning screen")
	var scroll := overlay.find_child("LearningSessionScroll", true, false) as ScrollContainer
	check(scroll.get_global_rect().encloses(next.get_global_rect()), "continue is inside the actual phone scroll viewport")
	check(scroll.get_global_rect().encloses(feedback.get_global_rect()), "explanation is inside the actual phone scroll viewport")
	await capture("learning-feedback")
	check((overlay.get("_approach_row") as Control).visible == false, "answered round cannot change its approach")
	# Keep the old signal callback alive through this synchronous transition.
	next.pressed.emit()
	old_answer.pressed.emit()
	check(int(service.active_session.round) == 1, "previous-question callback cannot answer the next question")
	await settle()
	visual = companion.call("get_visual_snapshot")
	check(int(visual.round) == 2 and int(visual.result_state) == 0, "continue updates the companion to the next question")
	check(prompt.text == str(service.active_session.challenge.prompt), "continue advances to the actual next question")
	check(continue_button(overlay) == null, "consumed feedback cannot remain actionable")
	check((overlay.get("_approach_row") as Control).visible, "next question restores approach controls")
	await settle()
	for round_index in range(2):
		challenge = service.active_session.challenge
		answers = overlay.get("_answer_buttons")
		var correct_button := answers[int(challenge.correct_indices[0])] as Button
		original_prompt = prompt.text
		correct_button.pressed.emit()
		check(str(((companion.call("get_visual_snapshot") as Dictionary).get("animation", {}) as Dictionary).get("reaction", "")) == "celebrate", "an actual correct answer reaches the actor's celebration")
		await settle()
		check(prompt.text == original_prompt, "each round keeps its own feedback visible")
		next = continue_button(overlay)
		check(next != null, "each answer exposes continue")
		if next == null:
			finish()
			return
		if round_index == 1:
			var sessions := int(service.total_sessions)
			correct_button.pressed.emit()
			check(int(service.total_sessions) == sessions, "last-answer duplicate cannot award a second completion")
			check((overlay.get("_progress") as Label).text != "ABENTEUER ABGESCHLOSSEN", "final explanation precedes the completion summary")
		await key(KEY_ENTER)
	check((overlay.get("_progress") as Label).text == "ABENTEUER ABGESCHLOSSEN", "final continue displays the completed adventure")
	check(int((overlay.call("get_mobile_readability_snapshot") as Dictionary).completion_button_count) == 1, "completion has a single catalog action")
	overlay.call("close_adventures")
	overlay.call("open_adventures")
	overlay.call("_start_adventure", "emotion_compass")
	await settle()
	answers = overlay.get("_answer_buttons")
	(answers[0] as Button).pressed.emit()
	await settle()
	var stale_continue := continue_button(overlay)
	check(stale_continue != null, "new session can enter feedback")
	overlay.call("close_adventures")
	overlay.call("open_adventures")
	overlay.call("_start_adventure", "pattern_observatory")
	original_prompt = prompt.text
	if is_instance_valid(stale_continue): stale_continue.pressed.emit()
	await create_timer(1.35).timeout
	check(prompt.text == original_prompt and int(service.active_session.round) == 0, "closed-session callbacks cannot replace a reopened adventure")
	check(continue_button(overlay) == null, "reopened adventure contains no stale feedback action")
	overlay.call("_submit_answer", -1)
	await settle()
	answers = overlay.get("_answer_buttons")
	check(not (answers[0] as Button).disabled, "rejected input leaves valid answers usable")
	check(int(service.active_session.round) == 0, "rejected input does not advance progress")
	overlay.call("close_adventures")
	finish()

func capture(label: String) -> void:
	if "--capture" not in OS.get_cmdline_user_args() or DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	var screenshot := root.get_texture().get_image()
	check(screenshot.save_png("user://" + label + ".png") == OK, "save native-renderer screenshot")

func continue_button(overlay: Node) -> Button:
	for node in overlay.find_children("LearningFeedbackContinue", "Button", true, false):
		if not node.is_queued_for_deletion(): return node as Button
	return null

func settle() -> void:
	for frame in range(5): await process_frame

func key(code: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.pressed = true
	root.push_input(event)
	await process_frame
	event = event.duplicate() as InputEventKey
	event.pressed = false
	root.push_input(event)
	await settle()

func check(condition: bool, description: String) -> void:
	assertions += 1
	if not condition:
		failures.append(description)
		printerr("[LEARNING-FEEDBACK] FAIL: ", description)

func finish() -> void:
	print("[LEARNING-FEEDBACK] %d checks, %d failures" % [assertions, failures.size()])
	quit(0 if failures.is_empty() else 1)
