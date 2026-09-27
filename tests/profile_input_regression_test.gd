extends SceneTree

var failures: Array[String] = []
var assertions := 0

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	root.size = Vector2i(720, 1280)
	var main := load("res://main.tscn").instantiate() as Node
	root.add_child(main)
	for _frame in range(12):
		await process_frame
	root.get_node("LegendaryOnboarding").call("_close")
	await process_frame
	var habitat := root.get_node("HabitatInteraction")
	habitat.set_process(false)
	habitat.call("reset_state")
	var overlay := root.get_node("ProfileOverlay")
	var backdrop := overlay.get("backdrop") as Control
	var stage := main.get("stage") as Control
	stage.grab_focus()
	overlay.call("open_profile")
	await process_frame
	_check(overlay.has_method("is_open"), "profile exposes its modal state")
	var close := _close_button(backdrop)
	_check(close != null and root.gui_get_focus_owner() == close, "opening profile focuses its close control")
	_check(overlay.layer > root.get_node("LegendaryStoryHUD").layer, "profile blocks story HUD controls visually and by pointer")
	await _key(KEY_TAB)
	_check(_inside(backdrop, root.gui_get_focus_owner()) and root.gui_get_focus_owner() != close, "native Tab enters reading area")
	await _key(KEY_TAB, true)
	_check(root.gui_get_focus_owner() == close, "native Shift-Tab returns to close")
	for _step in range(8):
		await _action("ui_focus_next")
		_check(_inside(backdrop, root.gui_get_focus_owner()), "Tab stays inside profile")
	for _step in range(4):
		await _action("ui_focus_prev")
		_check(_inside(backdrop, root.gui_get_focus_owner()), "Shift-Tab stays inside profile")
	await _action("ui_accept")
	_check(not bool((habitat.call("get_live_action_snapshot") as Dictionary).get("active", true)), "Enter does not activate background habitat")
	overlay.call("close_profile")
	await process_frame
	_check(root.gui_get_focus_owner() == stage, "closing restores previous focus")
	overlay.call("open_profile")
	overlay.call("open_profile")
	await _action("ui_cancel")
	_check(not backdrop.visible and root.gui_get_focus_owner() == stage, "Escape closes repeated open and restores focus")
	root.size = Vector2i(390, 600)
	overlay.call("open_profile")
	for _frame in range(5):
		await process_frame
	var bounds := Rect2(Vector2.ZERO, root.get_visible_rect().size)
	_check(bounds.encloses(close.get_global_rect()), "close control remains inside short phone viewport")
	var scroll := _scroll(backdrop)
	_check(scroll != null and bounds.encloses(scroll.get_global_rect()), "reading scroll remains inside short phone viewport")
	var before := scroll.scroll_vertical if scroll != null else 0
	await _action("ui_down")
	_check(scroll != null and scroll.scroll_vertical > before, "keyboard scrolls the profile contents")
	overlay.call("close_profile")
	var temporary := Button.new()
	temporary.text = "Temporary background"
	root.add_child(temporary)
	temporary.grab_focus()
	overlay.call("open_profile")
	temporary.queue_free()
	await process_frame
	overlay.call("close_profile")
	_check(not backdrop.visible, "closing tolerates a freed prior focus owner")
	main.queue_free()
	await process_frame
	print("[PROFILE-INPUT] %d checks, %d failures" % [assertions, failures.size()])
	quit(0 if failures.is_empty() else 1)

func _action(name: String) -> void:
	var down := InputEventAction.new()
	down.action = name
	down.pressed = true
	root.push_input(down)
	await process_frame
	var up := InputEventAction.new()
	up.action = name
	up.pressed = false
	root.push_input(up)
	await process_frame

func _key(code: Key, shift: bool = false) -> void:
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

func _inside(parent: Node, child: Node) -> bool:
	return child != null and (parent == child or parent.is_ancestor_of(child))

func _close_button(node: Node) -> Button:
	if node is Button and node.tooltip_text == "Profil schließen":
		return node as Button
	for child in node.get_children():
		var found := _close_button(child)
		if found != null:
			return found
	return null

func _scroll(node: Node) -> ScrollContainer:
	if node is ScrollContainer:
		return node as ScrollContainer
	for child in node.get_children():
		var found := _scroll(child)
		if found != null:
			return found
	return null

func _check(condition: bool, message: String) -> void:
	assertions += 1
	if condition:
		print("[PROFILE-INPUT] PASS: %s" % message)
	else:
		failures.append(message)
		push_error("[PROFILE-INPUT] FAIL: %s" % message)
