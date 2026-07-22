extends SceneTree

var failures: Array[String] = []
var assertions := 0

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	await process_frame
	var overlay_script := load("res://scripts/ui/habitat_live_action_overlay.gd") as Script
	_check(overlay_script != null, "live action overlay script loads")
	if overlay_script == null:
		_finish()
		return
	var overlay := overlay_script.new() as Control
	root.add_child(overlay)
	overlay.position = Vector2.ZERO
	overlay.call("set_snapshot", _awaiting_snapshot())
	await process_frame
	await _test_phone_stack(overlay)
	await _test_tablet_row(overlay)
	await _test_laptop_row(overlay)
	overlay.queue_free()
	await process_frame
	_finish()

func _test_phone_stack(overlay: Control) -> void:
	overlay.size = Vector2(390.0, 650.0)
	await process_frame
	var visual := overlay.call("get_visual_snapshot") as Dictionary
	var regions := overlay.call("get_choice_regions") as Array[Rect2]
	_check(str(visual.get("choice_layout", "")) == "stack", "phone keeps choices in a bounded vertical stack")
	_check(regions.size() == 3, "phone renders exactly three choice regions")
	_check(_regions_inside(regions, overlay.size), "phone choice stack stays inside the stage")
	_check(not _regions_overlap(regions), "phone choice stack has distinct hit targets")
	_check(bool(visual.get("input_passthrough", false)), "phone overlay remains input-transparent")

func _test_tablet_row(overlay: Control) -> void:
	overlay.size = Vector2(520.0, 520.0)
	await process_frame
	var visual := overlay.call("get_visual_snapshot") as Dictionary
	var regions := overlay.call("get_choice_regions") as Array[Rect2]
	_check(str(visual.get("choice_layout", "")) == "row", "tablet reflows in-world choices into a horizontal row")
	_check(regions.size() == 3, "tablet renders exactly three choice regions")
	_check(_regions_inside(regions, overlay.size), "tablet choice row stays inside the stage")
	_check(not _regions_overlap(regions), "tablet choice row has distinct hit targets")
	_check(_same_row(regions), "tablet choices share one readable baseline")

func _test_laptop_row(overlay: Control) -> void:
	overlay.size = Vector2(760.0, 620.0)
	await process_frame
	var visual := overlay.call("get_visual_snapshot") as Dictionary
	var regions := overlay.call("get_choice_regions") as Array[Rect2]
	_check(str(visual.get("choice_layout", "")) == "row", "laptop keeps the horizontal in-world choice row")
	_check(regions.size() == 3, "laptop renders exactly three choice regions")
	_check(_regions_inside(regions, overlay.size), "laptop choice row stays inside the stage")
	_check(not _regions_overlap(regions), "laptop choice row has distinct hit targets")
	_check(_same_row(regions), "laptop choices share one readable baseline")

func _awaiting_snapshot() -> Dictionary:
	return {
		"active": true,
		"phase": "awaiting_choice",
		"source": "xogot",
		"hotspot": "bitling",
		"selected_lens": "care",
		"phase_progress": 1.0,
		"choices": [
			{"id": "check_in", "title": "Nachfragen", "behavior_label": "OFFEN", "friction": 0.0},
			{"id": "practical_help", "title": "Praktisch helfen", "behavior_label": "OFFEN", "friction": 0.0},
			{"id": "give_space", "title": "Raum geben", "behavior_label": "OFFEN", "friction": 0.0}
		]
	}

func _regions_inside(regions: Array[Rect2], stage_size: Vector2) -> bool:
	var bounds := Rect2(Vector2.ZERO, stage_size)
	for region in regions:
		if not bounds.encloses(region):
			return false
	return true

func _regions_overlap(regions: Array[Rect2]) -> bool:
	for left in range(regions.size()):
		for right in range(left + 1, regions.size()):
			if regions[left].intersects(regions[right]):
				return true
	return false

func _same_row(regions: Array[Rect2]) -> bool:
	if regions.size() != 3:
		return false
	var baseline := regions[0].get_center().y
	for region in regions:
		if absf(region.get_center().y - baseline) > 1.0:
			return false
	return regions[0].get_center().x < regions[1].get_center().x and regions[1].get_center().x < regions[2].get_center().x

func _check(condition: bool, description: String) -> void:
	assertions += 1
	if condition:
		print("[LIVE-LAYOUT-GATE] PASS: %s" % description)
	else:
		failures.append(description)
		push_error("[LIVE-LAYOUT-GATE] FAIL: %s" % description)

func _finish() -> void:
	if failures.is_empty():
		print("[LIVE-LAYOUT-GATE] PASS: %d assertions" % assertions)
		quit(0)
	else:
		print("[LIVE-LAYOUT-GATE] BLOCKED: %d of %d assertions failed" % [failures.size(), assertions])
		quit(1)
