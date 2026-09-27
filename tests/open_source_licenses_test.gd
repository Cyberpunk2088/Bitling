extends SceneTree

var assertions := 0
var failures: Array[String] = []

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	root.size = Vector2i(430, 932)
	var main := load("res://main.tscn").instantiate() as Node
	root.add_child(main)
	for _frame in range(12): await process_frame
	root.get_node("LegendaryOnboarding").call("_close")
	var profile := root.get_node("ProfileOverlay")
	var stage := main.get("stage") as Control
	stage.grab_focus()
	profile.call("open_profile")
	await process_frame
	var launcher := profile.find_child("OpenSourceLicenses", true, false) as Button
	check(launcher != null and launcher.is_visible_in_tree(), "profile offers a visible license entry")
	if launcher == null:
		_finish()
		return
	# Navigate using real keyboard events and activate the actual profile button.
	await key(KEY_TAB)
	await key(KEY_TAB)
	check(root.gui_get_focus_owner() == launcher, "Tab reaches the license entry")
	await key(KEY_ENTER)
	for _frame in range(4): await process_frame
	var dialog := profile.find_child("OpenSourceLicenseDialog", true, false) as Control
	check(dialog != null and dialog.is_visible_in_tree(), "Enter on the entry opens licenses")
	if dialog == null:
		_finish()
		return
	var text := dialog.find_child("LicenseText", true, false) as RichTextLabel
	var close := dialog.find_child("LicenseClose", true, false) as Button
	check(text != null and close != null, "license view has readable content and a close control")
	if text == null or close == null:
		_finish()
		return
	check(text.text.contains(Engine.get_license_text()), "complete engine license is included verbatim")
	var copyright_complete := true
	for component in Engine.get_copyright_info():
		copyright_complete = copyright_complete and text.text.contains(str(component.get("name", "")))
		for part in component.get("parts", []):
			for owner in part.get("copyright", []):
				copyright_complete = copyright_complete and text.text.contains(str(owner))
	check(copyright_complete, "all engine component names and copyright holders are present")
	var licenses_complete := true
	for license_text in Engine.get_license_info().values():
		licenses_complete = licenses_complete and text.text.contains(str(license_text))
	check(licenses_complete, "all engine third-party license texts are included verbatim")
	check(not text.bbcode_enabled, "legal text is shown literally without markup interpretation")
	check(root.gui_get_focus_owner() == close, "opening licenses focuses the close control")
	for _step in range(6):
		await key(KEY_TAB)
		check(dialog.is_ancestor_of(root.gui_get_focus_owner()), "Tab remains within the license modal")
	await key(KEY_TAB, true)
	check(root.gui_get_focus_owner() == text, "Shift-Tab reaches the reading area")
	var before := text.get_v_scroll_bar().value
	await key(KEY_PAGEDOWN)
	check(text.get_v_scroll_bar().value > before, "keyboard scrolls the legal text")
	stage.grab_focus()
	for _frame in range(3): await process_frame
	check(dialog.is_ancestor_of(root.gui_get_focus_owner()), "external focus cannot escape the license modal")
	root.size = Vector2i(390, 600)
	for _frame in range(5): await process_frame
	var bounds := Rect2(Vector2.ZERO, root.get_visible_rect().size)
	check(bounds.encloses(close.get_global_rect()), "close remains within a short phone viewport")
	check(bounds.encloses(text.get_global_rect()), "license reading area fits a short phone viewport")
	await key(KEY_ESCAPE)
	check(not dialog.visible and bool(profile.call("is_open")), "Escape closes licenses and keeps the profile open")
	check(root.gui_get_focus_owner() == launcher, "closing licenses restores focus to the entry")
	await key(KEY_ENTER)
	await key(KEY_ENTER)
	check(not dialog.visible and root.gui_get_focus_owner() == launcher, "Enter opens and closes through the actual controls")
	await key(KEY_ESCAPE)
	check(not bool(profile.call("is_open")) and root.gui_get_focus_owner() == stage, "closing profile restores original gameplay focus")
	main.queue_free()
	await process_frame
	_finish()

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

func check(condition: bool, message: String) -> void:
	assertions += 1
	if condition:
		print("[OPEN-SOURCE-LICENSES] PASS: %s" % message)
	else:
		failures.append(message)
		push_error("[OPEN-SOURCE-LICENSES] FAIL: %s" % message)

func _finish() -> void:
	print("[OPEN-SOURCE-LICENSES] %d checks, %d failures" % [assertions, failures.size()])
	quit(0 if failures.is_empty() else 1)
