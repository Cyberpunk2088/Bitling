extends SceneTree

var _failures: Array[String] = []
var _original_state: Dictionary = {}

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var home := root.get_node_or_null("LivingHome")
	_expect(home != null, "LivingHome autoload exists")
	if home == null:
		_finish()
		return
	_original_state = home.call("export_state") as Dictionary
	home.call("reset_state")
	_test_initial_contract(home)
	_test_object_interactions(home)
	_test_upgrades_and_progression(home)
	_test_decorations(home)
	_test_atmosphere_controls(home)
	_test_export_import(home)
	await _test_running_scene(home)
	home.call("import_state", _original_state)
	home.call("save_state")
	_finish()

func _test_initial_contract(home: Node) -> void:
	var snapshot: Dictionary = home.call("get_snapshot")
	_expect(int(snapshot.get("room_level", 0)) == 1, "room starts at level one")
	_expect(float(snapshot.get("cleanliness", 0.0)) >= 80.0, "room starts cared for")
	_expect((snapshot.get("object_levels", {}) as Dictionary).size() == 8, "eight room objects exist")
	_expect(int(snapshot.get("decoration_limit", 0)) == 8, "decoration limit is explicit")
	_expect(str(snapshot.get("recommended_action", "")).length() > 0, "room recommends an action")
	_expect(str(snapshot.get("time_segment", "")) in ["MORNING", "DAY", "EVENING", "NIGHT"], "automatic time segment resolves")

func _test_object_interactions(home: Node) -> void:
	var before: Dictionary = home.call("get_snapshot")
	var learn_result: Dictionary = home.call("interact_object", "learning_desk")
	var after_learn: Dictionary = home.call("get_snapshot")
	_expect(bool(learn_result.get("accepted", false)), "learning desk interaction accepted")
	_expect(float(after_learn.get("inspiration", 0.0)) > float(before.get("inspiration", 0.0)), "learning desk raises inspiration")
	var sleep_result: Dictionary = home.call("interact_object", "sleep_pod")
	var after_sleep: Dictionary = home.call("get_snapshot")
	_expect(bool(sleep_result.get("accepted", false)), "sleep pod interaction accepted")
	_expect(float(after_sleep.get("comfort", 0.0)) > float(after_learn.get("comfort", 0.0)), "sleep pod raises comfort")
	var kitchen_before := float(after_sleep.get("cleanliness", 0.0))
	home.call("interact_object", "signal_kitchen")
	var kitchen_after := float((home.call("get_snapshot") as Dictionary).get("cleanliness", 0.0))
	_expect(kitchen_after <= kitchen_before, "kitchen use can leave visible traces")
	var invalid: Dictionary = home.call("interact_object", "missing_object")
	_expect(not bool(invalid.get("accepted", true)), "unknown room object rejected")
	var dirty_before := float((home.call("get_snapshot") as Dictionary).get("cleanliness", 0.0))
	var clean_result: Dictionary = home.call("clean_room")
	var clean_after := float((home.call("get_snapshot") as Dictionary).get("cleanliness", 0.0))
	_expect(bool(clean_result.get("accepted", false)), "clean room action accepted")
	_expect(clean_after > dirty_before, "clean room repairs cleanliness")

func _test_upgrades_and_progression(home: Node) -> void:
	var blocked: Dictionary = home.call("upgrade_object", "learning_desk")
	_expect(not bool(blocked.get("accepted", true)), "upgrade is gated by room level")
	home.set("room_level", 5)
	var upgraded: Dictionary = home.call("upgrade_object", "learning_desk")
	_expect(bool(upgraded.get("accepted", false)), "upgrade succeeds at required room level")
	_expect(int(upgraded.get("level", 0)) == 2, "object level increments exactly once")
	for _index in range(4):
		home.call("upgrade_object", "learning_desk")
	var maximum: Dictionary = home.call("upgrade_object", "learning_desk")
	_expect(not bool(maximum.get("accepted", true)), "max-level object cannot exceed catalog limit")
	_expect(str(maximum.get("reason", "")) == "max_level", "max-level rejection is explained")

func _test_decorations(home: Node) -> void:
	var decoration_ids := [
		"moon_lantern", "prism_mobile", "memory_ribbon", "moss_cushion",
		"star_map", "tiny_planet", "friend_totem", "signal_chimes"
	]
	for decoration_id in decoration_ids:
		var result: Dictionary = home.call("place_decoration", decoration_id)
		_expect(bool(result.get("accepted", false)), "decoration placed: %s" % decoration_id)
	var overflow: Dictionary = home.call("place_decoration", "aurora_rug")
	_expect(not bool(overflow.get("accepted", true)), "decoration capacity enforced")
	_expect(str(overflow.get("reason", "")) == "decoration_limit", "decoration limit has explicit reason")
	_expect(bool(home.call("remove_decoration", "moon_lantern")), "placed decoration can be removed")
	var replacement: Dictionary = home.call("place_decoration", "aurora_rug")
	_expect(bool(replacement.get("accepted", false)), "free decoration slot can be reused")
	var snapshot: Dictionary = home.call("get_snapshot")
	_expect((snapshot.get("decorations", []) as Array).size() == 8, "decoration list remains bounded")

func _test_atmosphere_controls(home: Node) -> void:
	_expect(bool(home.call("set_theme", "botanical_lab")), "valid theme accepted")
	_expect(not bool(home.call("set_theme", "unknown_theme")), "unknown theme rejected")
	_expect(bool(home.call("set_time_mode", "NIGHT")), "manual night mode accepted")
	_expect(not bool(home.call("set_time_mode", "MIDDAYISH")), "invalid time mode rejected")
	_expect(bool(home.call("set_weather", "RAIN")), "rain weather accepted")
	_expect(bool(home.call("set_weather", "AURORA")), "aurora weather accepted")
	_expect(not bool(home.call("set_weather", "FIRE")), "invalid weather rejected")
	var snapshot: Dictionary = home.call("get_snapshot")
	_expect(str(snapshot.get("theme_id", "")) == "botanical_lab", "theme persisted in snapshot")
	_expect(str(snapshot.get("time_segment", "")) == "NIGHT", "manual time controls resolved segment")
	_expect(str(snapshot.get("weather", "")) == "AURORA", "weather persisted in snapshot")

func _test_export_import(home: Node) -> void:
	var exported: Dictionary = home.call("export_state")
	home.call("reset_state")
	home.call("import_state", exported)
	var restored: Dictionary = home.call("get_snapshot")
	_expect(int(restored.get("room_level", 0)) == int(exported.get("room_level", -1)), "room level survives export/import")
	_expect(str(restored.get("theme_id", "")) == str(exported.get("theme_id", "missing")), "theme survives export/import")
	_expect((restored.get("decorations", []) as Array).size() == (exported.get("decorations", []) as Array).size(), "decorations survive export/import")
	_expect(bool(home.call("save_state")), "atomic Living Home save succeeds")

func _test_running_scene(home: Node) -> void:
	var packed := load("res://main.tscn") as PackedScene
	_expect(packed != null, "main scene loads for Living Home visual test")
	if packed == null:
		return
	var dashboard := packed.instantiate()
	root.add_child(dashboard)
	await _settle_frames(12)
	var stage := root.find_child("LegendaryWave3LivingHomeStage3D", true, false)
	_expect(stage != null, "Wave 3 Living Home stage is active")
	if stage != null and stage.has_method("get_living_home_visual_snapshot"):
		var stage_snapshot: Dictionary = stage.call("get_living_home_visual_snapshot")
		_expect(bool(stage_snapshot.get("home_layer", false)), "3D home layer exists")
		_expect(int(stage_snapshot.get("prop_count", 0)) >= 8, "all core home props are built")
		_expect(int(stage_snapshot.get("weather_particle_count", 0)) >= 30, "weather layer has sufficient particles")
		home.call("set_weather", "RAIN")
		home.call("set_time_mode", "NIGHT")
		await _settle_frames(5)
		stage_snapshot = stage.call("get_living_home_visual_snapshot")
		_expect(str(stage_snapshot.get("weather", "")) == "RAIN", "stage receives weather changes")
		_expect(str(stage_snapshot.get("time_segment", "")) == "NIGHT", "stage receives time changes")
	var overlay := root.get_node_or_null("LivingHomeOverlay")
	_expect(overlay != null, "Living Home overlay autoload exists")
	if overlay != null and overlay.has_method("open_home"):
		overlay.call("open_home")
		await _settle_frames(3)
		var overlay_snapshot: Dictionary = overlay.call("get_overlay_snapshot")
		_expect(bool(overlay_snapshot.get("open", false)), "Living Home overlay opens")
		_expect(int(overlay_snapshot.get("object_button_count", 0)) == 8, "overlay exposes eight room objects")
		_expect(int(overlay_snapshot.get("decoration_button_count", 0)) >= 10, "overlay exposes decoration catalog")
		overlay.call("close_home")
		_expect(not bool((overlay.call("get_overlay_snapshot") as Dictionary).get("open", true)), "Living Home overlay closes")
	dashboard.queue_free()
	await process_frame

func _settle_frames(count: int) -> void:
	for _index in range(count):
		await process_frame

func _expect(condition: bool, message: String) -> void:
	if condition:
		print("[CI-WAVE3] PASS: %s" % message)
	else:
		_failures.append(message)
		push_error("[CI-WAVE3] FAIL: %s" % message)

func _finish() -> void:
	if _failures.is_empty():
		print("[CI-WAVE3] PASS")
		quit(0)
	else:
		print("[CI-WAVE3] BLOCKED: %d failure(s)" % _failures.size())
		quit(1)
