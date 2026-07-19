extends SceneTree

var failures: Array[String] = []
var assertions: int = 0
var backup: Dictionary = {}

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	await process_frame
	await process_frame
	var service: Node = root.get_node_or_null("LearningAdventures")
	_check(service != null, "LearningAdventures autoload exists")
	if service == null:
		_finish()
		return
	backup = service.call("export_state") as Dictionary
	service.call("reset_state")
	_test_catalog(service)
	_test_sessions(service)
	_test_transfer(service)
	_test_persistence(service)
	await _test_overlay(service)
	service.call("import_state", backup)
	service.call("save_state")
	_finish()

func _test_catalog(service: Node) -> void:
	var snapshot: Dictionary = service.call("get_snapshot")
	var catalog: Array = snapshot.get("catalog", []) as Array
	_check(catalog.size() == 12, "catalog exposes twelve adventures")
	var domains: Dictionary = {}
	var unlocked: int = 0
	for entry_variant: Variant in catalog:
		if entry_variant is Dictionary:
			var entry: Dictionary = entry_variant as Dictionary
			domains[str(entry.get("domain", ""))] = true
			unlocked += 1 if bool(entry.get("unlocked", false)) else 0
	_check(domains.size() >= 10, "catalog spans ten learning domains")
	_check(unlocked >= 6, "six adventures are playable immediately")

func _test_sessions(service: Node) -> void:
	var before: float = float(service.call("get_average_mastery"))
	for seed_value: int in [401, 402, 403, 404]:
		var start: Dictionary = service.call("start_session", "pattern_observatory", seed_value)
		_check(bool(start.get("accepted", false)), "adaptive session starts")
		if not bool(start.get("accepted", false)):
			continue
		for round_index: int in range(3):
			var active: Dictionary = (service.call("get_snapshot") as Dictionary).get("active_session", {}) as Dictionary
			var challenge: Dictionary = active.get("challenge", {}) as Dictionary
			_check((challenge.get("approaches", {}) as Dictionary).size() == 4, "challenge offers four approaches")
			var correct: Array = challenge.get("correct_indices", []) as Array
			var result: Dictionary = service.call("submit_solution", int(correct[0]), "explain" if round_index % 2 == 0 else "compare")
			_check(bool(result.get("accepted", false)), "valid solution is accepted")
	var after: float = float(service.call("get_average_mastery"))
	_check(after > before, "success creates a mastery curve")
	_check(int((service.call("get_snapshot") as Dictionary).get("total_sessions", 0)) == 4, "sessions are counted")

func _test_transfer(service: Node) -> void:
	_check(float(service.call("get_expedition_bonus", "aurora_foundry")) > 0.0, "learning transfers into expeditions")
	_check(float(service.call("get_affinity_bonus", "LIGHT_SCHOLAR")) > 0.0, "learning transfers into evolution")
	_check(float(service.call("consume_expedition_bonus", "aurora_foundry", 0.5)) > 0.0, "expedition bonus can be consumed")

func _test_persistence(service: Node) -> void:
	var exported: Dictionary = service.call("export_state")
	var mastery: float = float(service.call("get_average_mastery"))
	service.call("reset_state")
	_check(int((service.call("get_snapshot") as Dictionary).get("total_sessions", -1)) == 0, "reset clears progression")
	service.call("import_state", exported)
	_check(is_equal_approx(float(service.call("get_average_mastery")), mastery), "export and import restore mastery")
	_check(bool(service.call("save_state")), "learning state saves atomically")

func _test_overlay(service: Node) -> void:
	var packed: PackedScene = load("res://main.tscn") as PackedScene
	_check(packed != null, "main scene loads")
	if packed == null:
		return
	var main: Node = packed.instantiate()
	root.add_child(main)
	await _settle(8)
	var overlay: Node = root.get_node_or_null("LearningAdventureOverlay")
	_check(overlay != null, "learning overlay exists")
	if overlay != null:
		overlay.call("open_adventures")
		await _settle(4)
		var layout: Dictionary = overlay.call("get_layout_snapshot")
		_check(bool(layout.get("visible", false)), "learning overlay opens")
		_check(int(layout.get("catalog_cards", 0)) == 12, "overlay renders twelve cards")
		var start: Dictionary = service.call("start_session", "emotion_compass", 900)
		_check(bool(start.get("accepted", false)), "overlay session starts")
		await _settle(3)
		layout = overlay.call("get_layout_snapshot")
		_check(int(layout.get("approach_count", 0)) == 4, "overlay renders four approaches")
		_check(int(layout.get("answer_count", 0)) == 3, "overlay renders three answers")
		overlay.call("close_adventures")
	main.queue_free()
	await process_frame

func _settle(count: int) -> void:
	for _index: int in range(count):
		await process_frame

func _check(condition: bool, description: String) -> void:
	assertions += 1
	if condition:
		print("[CI-WAVE5] PASS: %s" % description)
	else:
		failures.append(description)
		push_error("[CI-WAVE5] FAIL: %s" % description)

func _finish() -> void:
	if failures.is_empty():
		print("[CI-WAVE5] PASS: %d assertions" % assertions)
		quit(0)
	else:
		print("[CI-WAVE5] BLOCKED: %d of %d assertions failed" % [failures.size(), assertions])
		quit(1)
