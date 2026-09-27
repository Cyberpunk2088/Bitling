extends SceneTree

var failures: Array[String] = []
var assertions := 0

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	if OS.get_environment("BITLING_TEST_ISOLATED") != "1" or not OS.get_user_data_dir().begins_with("/tmp/"):
		var token := OS.get_environment("BITLING_TEST_TOKEN")
		var mac_fixture := OS.get_environment("BITLING_TEST_ISOLATED") == "1" and OS.get_name() == "macOS" and OS.get_user_data_dir().get_file().begins_with("BitlingRepairTests-") and token.length() >= 32 and FileAccess.file_exists("user://.bitling-test-fixture") and FileAccess.get_file_as_string("user://.bitling-test-fixture") == token
		if not mac_fixture:
			printerr("This test requires an isolated test project and BITLING_TEST_ISOLATED=1.")
			quit(2)
			return
	var path := "res://scripts/ui/learning_companion_actor.gd"
	if not ResourceLoader.exists(path):
		_check(false, "the illustrated companion has an articulated actor instead of a moving texture rectangle")
		_finish()
		return
	root.size = Vector2i(640, 800)
	root.get_node("LegendaryOnboarding").call("_close")
	var actor: Control = load(path).new()
	actor.position = Vector2(10, 10)
	actor.size = Vector2(420, 600)
	root.add_child(actor)
	await process_frame
	await process_frame
	root.get_node("LegendaryOnboarding").call("_close")
	await process_frame
	actor.set_process(false)
	var initial: Dictionary = actor.call("get_animation_snapshot")
	_check(bool(initial.get("art_loaded", false)), "the existing companion art is loaded")
	_check((initial.get("vertices", PackedVector2Array()) as PackedVector2Array).size() == 270, "the rendered mesh contains 270 articulated vertices")
	actor.call("_process", 0.37)
	var moved: Dictionary = actor.call("get_animation_snapshot")
	_check(_part_delta(initial, moved, Vector2(0.57, 0.29)).length() > 0.05, "the head actually moves in the render mesh")
	_check(_part_delta(initial, moved, Vector2(0.21, 0.48)).length() > 0.05, "the tail actually moves in the render mesh")
	_check((_part_delta(initial, moved, Vector2(0.15, 0.31)) - _part_delta(initial, moved, Vector2(0.57, 0.29))).length() > 0.05, "ear and head deformation differ, excluding a translated whole image")
	_check(_island_fixed(initial, moved), "every island vertex at or below the anchor stays fixed")
	actor.call("request_reaction", "celebrate")
	actor.call("_process", 0.25)
	var celebration: Dictionary = actor.call("get_animation_snapshot")
	_check(str(celebration.get("reaction", "")) == "celebrate", "success starts a visible reaction")
	_check(_part_delta(moved, celebration, Vector2(0.57, 0.29)).length() > 0.1, "celebration changes the head geometry")
	_check(_island_fixed(initial, celebration), "celebration does not animate the island")
	actor.call("_process", 5.0)
	_check(str((actor.call("get_animation_snapshot") as Dictionary).get("reaction", "")) == "", "a reaction finishes and returns to idle")
	actor.call("_process", fposmod(3.95 - float(actor.get("_clock")), 4.2))
	var blinking: Dictionary = actor.call("get_animation_snapshot")
	_check(bool(blinking.get("blink_available", false)) and float(blinking.get("blink", 0.0)) > 0.98, "the real blink material closes the eye regions at the deterministic cycle peak")
	actor.call("set_reduced_motion", true)
	var reduced: Dictionary = actor.call("get_animation_snapshot")
	actor.call("_process", 0.7)
	_check(_same_vertices(reduced, actor.call("get_animation_snapshot")), "reduced motion freezes idle geometry")
	_check(not actor.is_processing(), "reduced motion disables frame processing")
	_check(float((actor.call("get_animation_snapshot") as Dictionary).get("blink", 1.0)) == 0.0, "reduced motion leaves eyes open without shader time animation")
	actor.call("set_reduced_motion", false)
	actor.hide()
	var hidden: Dictionary = actor.call("get_animation_snapshot")
	actor.call("_process", 0.7)
	_check(_same_vertices(hidden, actor.call("get_animation_snapshot")) and not actor.is_processing(), "hidden actors do not animate or process frames")
	actor.show()
	await process_frame
	_check(actor.is_processing(), "showing the actor resumes animation")
	actor.position = Vector2(2000, 2000)
	await process_frame
	actor.call("_process", 0.1)
	_check(not actor.is_processing(), "an actor beyond the viewport stops processing")
	actor.position = Vector2(10, 10)
	await process_frame
	_check(actor.is_processing(), "returning onscreen resumes processing")
	var motion := InputEventMouseMotion.new()
	motion.position = Vector2(99999, -99999)
	actor.call("_gui_input", motion)
	var looked: Dictionary = actor.call("get_animation_snapshot")
	var gaze: Vector2 = looked.get("gaze", Vector2.ZERO)
	_check(absf(gaze.x) <= 1.0 and absf(gaze.y) <= 1.0, "pointer look is bounded for extreme coordinates")
	var state := root.get_node("GameState")
	var xp := int(state.get("total_xp"))
	var rect: Rect2 = looked.get("art_rect", Rect2())
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.position = actor.position + rect.position + rect.size * Vector2(0.55, 0.35)
	root.push_input(click, true)
	await process_frame
	click = click.duplicate() as InputEventMouseButton
	click.pressed = false
	root.push_input(click, true)
	await process_frame
	var tapped: Dictionary = actor.call("get_animation_snapshot")
	_check(str(tapped.get("reaction", "")) == "greet", "a real viewport mouse press and release on the companion triggers greeting")
	var focus_outline := actor.get_node_or_null("CompanionFocusOutline") as Control
	_check(actor.has_focus() and focus_outline != null and focus_outline.visible and focus_outline.material == null and not focus_outline.use_parent_material, "real tap focus uses a separate visible outline without the blink material")
	_check(int(state.get("total_xp")) == xp, "touch animation does not award gameplay XP")
	_check(bool(tapped.get("topology_valid", false)), "the deformed mesh keeps finite vertices and positive triangle areas")
	actor.call("request_reaction", "think")
	var local_point := rect.position + rect.size * Vector2(0.55, 0.35)
	var touch := InputEventScreenTouch.new()
	touch.index = 0
	touch.position = local_point
	touch.pressed = true
	actor.call("_gui_input", touch)
	var drag := InputEventScreenDrag.new()
	drag.index = 0
	drag.position = local_point + Vector2(0, 70)
	actor.call("_gui_input", drag)
	touch.pressed = false
	touch.position = local_point
	actor.call("_gui_input", touch)
	_check(str((actor.call("get_animation_snapshot") as Dictionary).get("reaction", "")) == "think", "a scroll drag ending back on the actor does not trigger a greeting")
	var stable_topology := true
	for reaction: String in ["greet", "celebrate", "think"]:
		actor.call("request_reaction", reaction)
		for step: int in range(25):
			actor.call("_process", 0.08)
			stable_topology = stable_topology and bool((actor.call("get_animation_snapshot") as Dictionary).get("topology_valid", false))
	_check(stable_topology, "all reaction phases preserve finite geometry without folded triangles")
	await _test_context_reset(actor)
	actor.queue_free()
	await process_frame
	await _test_nested_clips(path)
	_finish()

func _test_context_reset(actor: Control) -> void:
	actor.call("set_context", "pattern_observatory", "logic", 1, "observe")
	actor.call("set_result", true)
	actor.call("_process", 0.35)
	actor.call("set_context", "pattern_observatory", "logic", 2, "observe")
	var next_round: Dictionary = actor.call("get_animation_snapshot")
	_check(str(next_round.get("reaction", "")) == "think", "the next round replaces the previous success celebration")
	_check(float(next_round.get("reaction_elapsed", -1.0)) == 0.0, "a new round begins its own reaction timeline")
	actor.call("_process", 0.45)
	actor.position = Vector2(2000, 2000)
	await process_frame
	actor.call("set_context", "pattern_observatory", "logic", 3, "observe")
	var offscreen_round: Dictionary = actor.call("get_animation_snapshot")
	_check(float(offscreen_round.get("reaction_elapsed", -1.0)) == 0.0 and not actor.is_processing(), "round changes reset paused offscreen feedback without resuming offscreen processing")
	actor.position = Vector2(10, 10)
	await process_frame
	actor.call("set_result", true)
	actor.call("set_context", "catalog")
	_check(str((actor.call("get_animation_snapshot") as Dictionary).get("reaction", "")) == "", "entering the catalog clears the old adventure reaction")
	actor.call("set_context", "pattern_observatory", "logic", 1, "observe")
	actor.call("set_result", true)
	actor.hide()
	await process_frame
	_check(str((actor.call("get_animation_snapshot") as Dictionary).get("reaction", "")) == "", "closing the visible screen clears its feedback")
	actor.show()
	actor.call("set_context", "pattern_observatory", "logic", 1, "observe")
	var reopened: Dictionary = actor.call("get_animation_snapshot")
	_check(str(reopened.get("reaction", "")) == "think" and float(reopened.get("reaction_elapsed", -1.0)) == 0.0, "reopening the same adventure and round starts fresh instead of replaying old feedback")

func _test_nested_clips(actor_path: String) -> void:
	var outer := Control.new()
	outer.position = Vector2(20, 20)
	outer.size = Vector2(280, 100)
	outer.clip_contents = true
	root.add_child(outer)
	var inner := Control.new()
	inner.position = Vector2(0, 150)
	inner.size = Vector2(280, 100)
	inner.clip_contents = true
	outer.add_child(inner)
	var actor: Control = load(actor_path).new()
	actor.position = Vector2(0, -150)
	actor.size = Vector2(270, 280)
	inner.add_child(actor)
	await process_frame
	await process_frame
	# The actor intersects each clip individually, but the clips are disjoint.
	var hidden: Dictionary = actor.call("get_animation_snapshot")
	_check(not actor.is_processing(), "disjoint nested clips stop animation despite intersecting the actor individually")
	actor.call("_process", 0.4)
	_check(_same_vertices(hidden, actor.call("get_animation_snapshot")), "a fully clipped actor does not change render geometry")
	inner.position.y = 50
	await process_frame
	await process_frame
	_check(actor.is_processing(), "moving nested clips into a shared visible area resumes animation")
	var visible: Dictionary = actor.call("get_animation_snapshot")
	actor.call("_process", 0.4)
	_check(not _same_vertices(visible, actor.call("get_animation_snapshot")), "resumed nested-clip animation updates actual mesh vertices")
	outer.queue_free()
	await process_frame

func _part_delta(a: Dictionary, b: Dictionary, point: Vector2) -> Vector2:
	var uvs: PackedVector2Array = a.get("uvs", PackedVector2Array())
	var vertices_a: PackedVector2Array = a.get("vertices", PackedVector2Array())
	var vertices_b: PackedVector2Array = b.get("vertices", PackedVector2Array())
	var nearest := -1
	var distance := INF
	for index: int in range(uvs.size()):
		if uvs[index].distance_squared_to(point) < distance:
			distance = uvs[index].distance_squared_to(point)
			nearest = index
	return vertices_b[nearest] - vertices_a[nearest] if nearest >= 0 else Vector2.ZERO

func _same_vertices(a: Dictionary, b: Dictionary) -> bool:
	return a.get("vertices", PackedVector2Array()) == b.get("vertices", PackedVector2Array())

func _island_fixed(a: Dictionary, b: Dictionary) -> bool:
	var uvs: PackedVector2Array = a.get("uvs", PackedVector2Array())
	var vertices_a: PackedVector2Array = a.get("vertices", PackedVector2Array())
	var vertices_b: PackedVector2Array = b.get("vertices", PackedVector2Array())
	var checked := 0
	for index: int in range(uvs.size()):
		if uvs[index].y >= 0.65 or (uvs[index].x < 0.43 and uvs[index].y >= 0.57) or (uvs[index].x > 0.73 and uvs[index].y >= 0.47):
			checked += 1
			if vertices_a[index] != vertices_b[index]:
				return false
	return checked > 50

func _check(condition: bool, message: String) -> void:
	assertions += 1
	if not condition:
		failures.append(message)
		printerr("[COMPANION-ANIMATION] FAIL: ", message)

func _finish() -> void:
	print("[COMPANION-ANIMATION] %d assertions, %d failures" % [assertions, failures.size()])
	quit(0 if failures.is_empty() else 1)
