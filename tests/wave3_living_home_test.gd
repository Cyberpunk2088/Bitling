extends SceneTree

var failures: Array[String] = []

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var service_script := load("res://scripts/core/living_home_service.gd")
	var stage_script := load("res://scripts/ui/production_bitling_stage_3d_v10.gd")
	var overlay_script := load("res://scripts/ui/living_home_overlay.gd")
	_assert(service_script != null, "Living Home service parses")
	_assert(stage_script != null, "Stage V10 parses")
	_assert(overlay_script != null, "Living Home overlay parses")
	if service_script == null:
		_finish()
		return

	var service := service_script.new()
	root.add_child(service)
	await process_frame
	service.reset_state()
	var initial: Dictionary = service.get_snapshot()
	_assert((initial.get("objects", {}) as Dictionary).size() == 5, "five room objects exist")
	_assert(float(initial.get("comfort", 0.0)) >= 60.0, "home starts comfortable")
	_assert(not str(initial.get("routine_label", "")).is_empty(), "routine is readable")

	var weather_before := str(initial.get("weather", ""))
	var window_result: Dictionary = service.interact("window")
	_assert(bool(window_result.get("accepted", false)), "window interaction accepted")
	_assert(str(service.get_snapshot().get("weather", "")) != weather_before, "window changes weather")

	var light_before := str(service.get_snapshot().get("light_mode", ""))
	service.interact("lamp")
	_assert(str(service.get_snapshot().get("light_mode", "")) != light_before, "lamp changes lighting")

	service.import_state({"plant_health": 20.0, "cleanliness": 35.0, "comfort": 42.0})
	service.interact("plant")
	_assert(float(service.get_snapshot().get("plant_health", 0.0)) >= 38.0, "plant care restores health")
	service.tidy_room()
	_assert(float(service.get_snapshot().get("cleanliness", 0.0)) >= 59.0, "tidying restores cleanliness")

	_assert(service.unlock_decor("memory_prism"), "new decor unlocks")
	_assert(not service.unlock_decor("memory_prism"), "duplicate decor rejected")
	for object_id in ["window", "lamp", "plant", "shelf", "cushion"]:
		service.interact(object_id)
	var snapshot: Dictionary = service.get_snapshot()
	_assert((snapshot.get("interaction_counts", {}) as Dictionary).size() == 5, "all object interactions tracked")
	_assert((snapshot.get("history", []) as Array).size() <= 40, "history remains bounded")
	_assert(service.save_state(), "home state saves atomically")

	var restored := service_script.new()
	root.add_child(restored)
	await process_frame
	_assert(restored.load_state(), "home state reloads")
	var restored_snapshot: Dictionary = restored.get_snapshot()
	_assert(str(restored_snapshot.get("light_mode", "")) == str(snapshot.get("light_mode", "")), "lighting survives reload")
	_assert((restored_snapshot.get("unlocked_decor", []) as Array).has("memory_prism"), "decor survives reload")

	var packed := load("res://main.tscn") as PackedScene
	_assert(packed != null, "main scene loads")
	if packed != null:
		var main := packed.instantiate()
		root.add_child(main)
		await _settle(10)
		var overlay := root.get_node_or_null("LivingHomeOverlay")
		_assert(overlay != null, "Living Home overlay autoload exists")
		if overlay != null and overlay.has_method("open_living_home"):
			overlay.call("open_living_home")
			await _settle(3)
			var layout: Dictionary = overlay.call("get_layout_snapshot")
			_assert(bool(layout.get("visible", false)), "Living Home overlay opens")
			_assert(int(layout.get("button_count", 0)) == 6, "overlay exposes five objects and tidy action")
		var stage := root.find_child("LegendaryWave3LivingHomeStage3D", true, false)
		_assert(stage != null, "Living Home stage is installed")
		if stage != null and stage.has_method("get_living_home_snapshot"):
			var visual: Dictionary = stage.call("get_living_home_snapshot")
			_assert(bool(visual.get("window_present", false)), "window exists visually")
			_assert(bool(visual.get("plant_present", false)), "plant exists visually")
			_assert(int(visual.get("dust_motes", 0)) >= 12, "room atmosphere has particles")
		main.queue_free()

	restored.queue_free()
	service.queue_free()
	await process_frame
	_finish()

func _settle(count: int) -> void:
	for _index in range(count):
		await process_frame

func _assert(condition: bool, message: String) -> void:
	if condition:
		print("[CI-WAVE3] PASS: %s" % message)
	else:
		failures.append(message)
		push_error("[CI-WAVE3] FAIL: %s" % message)

func _finish() -> void:
	if failures.is_empty():
		print("[CI-WAVE3] PASS")
		quit(0)
	else:
		print("[CI-WAVE3] BLOCKED: %d failure(s)" % failures.size())
		quit(1)
