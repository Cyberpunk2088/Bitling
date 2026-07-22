extends SceneTree

var failures: Array[String] = []
var assertions := 0
var habitat_backup: Dictionary = {}
var game_backup: Dictionary = {}

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	await process_frame
	await process_frame
	var service := root.get_node_or_null("HabitatInteraction")
	var game_state := root.get_node_or_null("GameState")
	_check(service != null, "HabitatInteraction autoload exists")
	_check(game_state != null, "GameState autoload exists")
	if service == null or game_state == null:
		_finish()
		return
	habitat_backup = service.call("export_state") as Dictionary
	game_backup = game_state.call("get_save_data") as Dictionary
	service.call("reset_state")
	_test_contract(service)
	_test_hotspots(service)
	_test_contextual_resolution(service)
	_test_persistence(service)
	await _test_dashboard(service)
	game_state.call("apply_save_data", game_backup)
	service.call("import_state", habitat_backup)
	_finish()

func _test_contract(service: Node) -> void:
	var lenses: Array = service.call("get_lens_ids") as Array
	_check(lenses == ["feed", "play", "learn", "care", "rest"], "five intentional lenses replace direct stat buttons")
	for lens_variant in lenses:
		var lens := str(lens_variant)
		var options: Array = service.call("get_lens_options", lens) as Array
		_check(options.size() == 3, "%s exposes three meaningful approaches" % lens)
		var ids: Dictionary = {}
		for option_variant in options:
			var option := option_variant as Dictionary
			ids[str(option.get("id", ""))] = true
			_check(not str(option.get("title", "")).is_empty(), "%s option has a visible title" % lens)
			_check(not (option.get("effects", {}) as Dictionary).is_empty(), "%s option has gameplay effects" % lens)
		_check(ids.size() == 3, "%s options are unique" % lens)

func _test_hotspots(service: Node) -> void:
	for hotspot in ["bitling", "window", "workbench", "plant", "platform", "sleep"]:
		var moment: Dictionary = service.call("focus_hotspot", hotspot) as Dictionary
		_check(str(moment.get("hotspot", "")) == hotspot, "%s maps to an in-world situation" % hotspot)
		_check(not str(moment.get("prompt", "")).is_empty(), "%s situation requires a decision" % hotspot)
	var unchanged: Dictionary = service.call("focus_hotspot", "invalid") as Dictionary
	_check(not unchanged.is_empty(), "invalid hotspot cannot erase the active situation")

func _test_contextual_resolution(service: Node) -> void:
	var moment: Dictionary = service.call("focus_hotspot", "window") as Dictionary
	_check(str(moment.get("recommended_lens", "")) == "learn", "window signal recommends understanding rather than a blind reward")
	var options: Array = service.call("select_lens", "learn") as Array
	var first := options[0] as Dictionary
	var result: Dictionary = service.call("resolve_choice", str(first.get("id", ""))) as Dictionary
	_check(bool(result.get("accepted", false)), "contextual choice resolves")
	_check(bool(result.get("aligned", false)), "matching lens is recognized as contextually aligned")
	_check(int(result.get("xp_reward", 0)) > int(first.get("xp", 0)), "alignment rewards understanding without forcing one answer")
	_check(not str(result.get("response", "")).is_empty(), "Bitling produces an autonomous response")
	_check(not str(result.get("consequence", "")).is_empty(), "decision exposes its consequence")
	var snapshot: Dictionary = service.call("get_snapshot") as Dictionary
	_check(int(snapshot.get("resolved_count", 0)) == 1, "resolved moments are counted")
	_check((snapshot.get("recent_outcomes", []) as Array).size() == 1, "outcome enters relationship history")
	var rejected: Dictionary = service.call("resolve_choice", "not-an-option") as Dictionary
	_check(not bool(rejected.get("accepted", true)), "unknown choices are rejected")

func _test_persistence(service: Node) -> void:
	var exported: Dictionary = service.call("export_state") as Dictionary
	var count := int(exported.get("resolved_count", 0))
	service.call("reset_state")
	_check(int((service.call("get_snapshot") as Dictionary).get("resolved_count", -1)) == 0, "reset clears habitat progression")
	service.call("import_state", exported)
	_check(int((service.call("get_snapshot") as Dictionary).get("resolved_count", -1)) == count, "import restores habitat progression")
	_check(bool(service.call("save_state")), "habitat state saves atomically")
	_check(bool(service.call("load_state")), "habitat state loads from disk")

func _test_dashboard(service: Node) -> void:
	var packed := load("res://main.tscn") as PackedScene
	_check(packed != null, "main scene loads")
	if packed == null:
		return
	var original_size := root.size
	root.size = Vector2i(390, 844)
	var main := packed.instantiate()
	root.add_child(main)
	await _settle(8)
	_check(main.has_method("get_habitat_ui_snapshot"), "main scene enforces habitat dashboard contract")
	if main.has_method("get_habitat_ui_snapshot"):
		var phone: Dictionary = main.call("get_habitat_ui_snapshot") as Dictionary
		_check(bool(phone.get("center_is_game", false)), "central Bitling stage is the gameplay surface")
		_check(str(phone.get("stage_type", "")).ends_with("bitling_habitat_stage.gd"), "interactive habitat stage replaces passive portrait")
		_check(int(phone.get("choice_count", 0)) == 3, "three contextual decisions are rendered")
		_check(int(phone.get("visible_choice_count", 0)) == 3, "all contextual decisions remain available on phone")
		_check(bool(phone.get("compact", false)), "phone layout activates")
		service.call("select_lens", "play")
		await _settle(2)
		phone = main.call("get_habitat_ui_snapshot") as Dictionary
		_check(str(phone.get("active_lens", "")) == "play", "lens changes propagate into the dashboard")
		root.size = Vector2i(1440, 900)
		await _settle(4)
		var desktop: Dictionary = main.call("get_habitat_ui_snapshot") as Dictionary
		_check(not bool(desktop.get("compact", true)), "desktop layout stays wide")
		_check(int(desktop.get("visible_choice_count", 0)) == 3, "desktop keeps all contextual decisions")
	main.queue_free()
	root.size = original_size
	await process_frame

func _settle(frames: int) -> void:
	for _index in range(frames):
		await process_frame

func _check(condition: bool, description: String) -> void:
	assertions += 1
	if condition:
		print("[HABITAT-GATE] PASS: %s" % description)
	else:
		failures.append(description)
		push_error("[HABITAT-GATE] FAIL: %s" % description)

func _finish() -> void:
	if failures.is_empty():
		print("[HABITAT-GATE] PASS: %d assertions" % assertions)
		quit(0)
	else:
		print("[HABITAT-GATE] BLOCKED: %d of %d assertions failed" % [failures.size(), assertions])
		quit(1)
