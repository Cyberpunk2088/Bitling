extends SceneTree

var assertions := 0
var failures: Array[String] = []

func _init() -> void:
	call_deferred("_run")

func check(condition: bool, message: String) -> void:
	assertions += 1
	if not condition:
		failures.append(message)
		printerr("[JOURNEY] FAIL: ", message)

func settle() -> void:
	for frame in range(6):
		await process_frame

func _run() -> void:
	root.size = Vector2i(430, 932)
	var onboarding := root.get_node("LegendaryOnboarding")
	onboarding.call("_close")
	var dashboard = load("res://main.tscn").instantiate()
	root.add_child(dashboard)
	await settle()
	onboarding.call("_close")
	var habitat := root.get_node("HabitatInteraction")
	habitat.set_process(false)
	var home := root.get_node("LivingHomeOverlay")
	var navigation: Node = dashboard.get_node("PremiumNavigationShell")
	navigation.call("_on_page_pressed", "HOME")
	await settle()
	check(not bool(home.call("is_open")), "HOME returns to the interactive habitat instead of a disconnected showcase")
	home.call("close_home")
	check(dashboard.stage.is_visible_in_tree(), "HOME exposes the actual interactive stage")
	for item in [["OpenLearningAdventures", "LearningAdventureOverlay", "is_open", "close_adventures"], ["OpenRoomDesign", "LivingHomeOverlay", "is_open", "close_home"]]:
		var button := dashboard.find_child(item[0], true, false) as Button
		check(button != null and button.is_visible_in_tree(), "%s is reachable on mobile" % item[0])
		if button != null:
			button.pressed.emit()
			await settle()
			var overlay := root.get_node(item[1])
			check(bool(overlay.call(item[2])), "%s opens its real screen" % item[0])
			overlay.call(item[3])
	var play_button := dashboard.find_child("OpenPlayActivities", true, false) as Button
	check(play_button != null and play_button.is_visible_in_tree(), "play activities are reachable on mobile")
	if play_button != null:
		for activity_id in ["pattern_focus", "signal_translation", "resonance_rhythm"]:
			play_button.pressed.emit()
			await settle()
			var activity_button := dashboard.find_child(activity_id, true, false) as Button
			check(activity_button != null and activity_button.is_visible_in_tree(), "%s is available in the games menu" % activity_id)
			if activity_button != null:
				activity_button.pressed.emit()
				await settle()
				var activity := root.get_node("LegendaryActivities")
				check(is_instance_valid(activity.get("layer")) and str(activity.get("_activity_id")) == activity_id, "%s opens its playable activity" % activity_id)
				activity.call("_close_overlay")
	for action in ["feed", "play", "learn", "care", "rest"]:
		habitat.set("live_action", {})
		var state := root.get_node("GameState")
		var old_xp := int(state.get("total_xp"))
		var old_hunger := float(state.get("hunger"))
		(dashboard.action_buttons[action] as Button).pressed.emit()
		await settle()
		var live: Dictionary = habitat.call("get_live_action_snapshot")
		check(bool(live.get("active", false)), "%s starts a visible choice sequence" % action)
		check(str(live.get("selected_lens", "")) == action, "%s preserves the chosen attitude" % action)
		check(int(state.get("total_xp")) == old_xp and float(state.get("hunger")) == old_hunger, "%s does not grant results before the player's decision" % action)
	# Complete one real choice through the scene signal and authoritative phases.
	habitat.call("advance_live_action", 1.0)
	habitat.call("advance_live_action", 1.0)
	await settle()
	var live: Dictionary = habitat.call("get_live_action_snapshot")
	var choices: Array = live.get("choices", [])
	check(choices.size() == 3, "the initiated action presents three genuine choices")
	if choices.size() == 3:
		var old_count := int(live.get("completed_count", 0))
		dashboard.stage.emit_signal("live_action_choice_pressed", str(choices[0].get("id", "")))
		habitat.call("advance_live_action", 2.0)
		habitat.call("advance_live_action", 2.0)
		check(int((habitat.call("get_live_action_snapshot") as Dictionary).get("completed_count", 0)) == old_count + 1, "a stage choice reaches a single completed outcome")
	# When another scene is open, unhandled Enter must not start the habitat.
	habitat.set("live_action", {})
	var learning := root.get_node("LearningAdventureOverlay")
	(dashboard.action_buttons["feed"] as Button).grab_focus()
	learning.call("open_adventures")
	var input := InputEventAction.new()
	input.action = "ui_accept"
	input.pressed = true
	dashboard.call("_unhandled_input", input)
	check(not bool((habitat.call("get_live_action_snapshot") as Dictionary).get("active", false)), "learning screen blocks background habitat shortcuts")
	root.push_input(input, true)
	var release := InputEventAction.new()
	release.action = "ui_accept"
	release.pressed = false
	root.push_input(release, true)
	await settle()
	check(not bool((habitat.call("get_live_action_snapshot") as Dictionary).get("active", false)), "real GUI Enter cannot activate a focused care button behind the learning screen")
	check(not bool(learning.call("is_open")), "Enter operates the focused learning close button")
	learning.call("open_adventures")
	dashboard.call("_open_activity", "pattern_focus")
	check(not is_instance_valid(root.get_node("LegendaryActivities").get("layer")), "a background activity shortcut cannot stack another modal")
	learning.call("close_adventures")
	# Save errors must be visible, and unsafe saves must stop the playable session.
	var state := root.get_node("GameState")
	var storage = dashboard.get_node("StorageStatusOverlay")
	state.set("storage_status", "error")
	state.set("storage_message", "Test: Datenträger nicht beschreibbar.")
	root.get_node("EventBus").emit_signal("save_failed", "Test")
	check(storage.notice.visible and "NICHT GESPEICHERT" in storage.description.text, "failed writes are visible to the player")
	state.set("storage_status", "saved")
	root.get_node("EventBus").emit_signal("save_completed", "Test")
	check(not storage.notice.visible, "a confirmed successful save clears the failure notice")
	state.set("save_blocked", true)
	storage.call("refresh")
	check(paused and storage.blocker.visible and storage.exit_button.visible, "unsafe saves show an exit-only blocking screen and pause gameplay")
	check(root.get_node("LivingHome").process_mode == Node.PROCESS_MODE_DISABLED, "unsafe saves also stop independent home autosave during pause")
	onboarding.call("open_onboarding", true)
	check(not is_instance_valid(onboarding.get("layer")), "unsafe saves cannot be replaced through forced onboarding")
	check(bool(dashboard.call("_has_modal_screen")), "unsafe saves also block background keyboard actions")
	state.set("save_blocked", false)
	paused = false
	dashboard.queue_free()
	await settle()
	print("[JOURNEY] %s: %d assertions; %d failures" % ["PASS" if failures.is_empty() else "FAIL", assertions, failures.size()])
	quit(0 if failures.is_empty() else 1)
