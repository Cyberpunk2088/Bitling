extends SceneTree

var assertions := 0
var failures: Array[String] = []

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	root.size = Vector2i(430, 932)
	var main := load("res://main.tscn").instantiate() as Node
	root.add_child(main)
	for frame in range(10): await process_frame
	root.get_node("LegendaryOnboarding").call("_close")
	await process_frame
	var learning := root.get_node("LearningAdventureOverlay")
	var backdrop := learning.get("_backdrop") as Control
	var close := learning.get("_close_button") as Button
	var stage := main.get("stage") as Control
	stage.grab_focus()
	learning.call("open_adventures")
	await process_frame
	check(root.gui_get_focus_owner() == close, "opening learning moves focus to its close control")
	for i in range(16):
		await key(KEY_TAB)
		check(valid_focus(backdrop), "catalog Tab stays on a visible enabled modal control")
	for i in range(5):
		await key(KEY_TAB, true)
		check(valid_focus(backdrop), "catalog Shift-Tab stays within the modal")
	close.grab_focus()
	await key(KEY_ENTER)
	check(not bool(learning.call("is_open")), "native Enter on close closes the learning screen")
	check(root.gui_get_focus_owner() == stage, "close restores the previous dashboard focus")
	learning.call("open_adventures")
	await process_frame
	await key(KEY_TAB)
	var selected := root.gui_get_focus_owner()
	check(selected != close and valid_focus(backdrop), "Tab reaches an unlocked catalog activity")
	await key(KEY_ENTER)
	for i in range(4): await process_frame
	check((learning.get("_session_panel") as Control).visible, "native Enter opens the focused adventure")
	check(valid_focus(backdrop), "starting an adventure transfers focus to an active session control")
	for i in range(10):
		await key(KEY_TAB)
		check(valid_focus(backdrop), "session Tab skips hidden catalog and disabled approach controls")
	await key(KEY_ESCAPE)
	check(not bool(learning.call("is_open")) and root.gui_get_focus_owner() == stage, "Escape closes and restores the original focus")
	learning.call("open_adventures")
	learning.call("open_adventures")
	stage.grab_focus()
	for i in range(3): await process_frame
	check(valid_focus(backdrop), "external focus cannot escape an open learning modal")
	await key(KEY_ESCAPE)
	check(root.gui_get_focus_owner() == stage, "repeated open preserves the return focus")
	var temporary := Button.new()
	root.add_child(temporary)
	temporary.grab_focus()
	learning.call("open_adventures")
	temporary.queue_free()
	await process_frame
	learning.call("close_adventures")
	check(not bool(learning.call("is_open")), "close tolerates a destroyed previous focus control")
	main.queue_free()
	await process_frame
	print("[LEARNING-FOCUS] %d checks, %d failures" % [assertions, failures.size()])
	quit(0 if failures.is_empty() else 1)

func key(code: Key, shift: bool = false) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.shift_pressed = shift
	event.pressed = true
	root.push_input(event)
	await process_frame
	event = event.duplicate() as InputEventKey
	event.pressed = false
	root.push_input(event)
	await process_frame

func valid_focus(backdrop: Control) -> bool:
	var focus := root.gui_get_focus_owner()
	return focus != null and backdrop.is_ancestor_of(focus) and focus.is_visible_in_tree() and not focus.is_queued_for_deletion() and (not focus is BaseButton or not focus.disabled)

func check(condition: bool, message: String) -> void:
	assertions += 1
	if condition:
		print("[LEARNING-FOCUS] PASS: %s" % message)
	else:
		failures.append(message)
		push_error("[LEARNING-FOCUS] FAIL: %s" % message)
