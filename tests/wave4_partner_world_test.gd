extends SceneTree

var failures: Array[String] = []
var assertions := 0
var _partner_backup: Dictionary = {}
var _settlement_backup: Dictionary = {}

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	await process_frame
	await process_frame
	var partner := root.get_node_or_null("PartnerWorld")
	var settlement := root.get_node_or_null("SignalSettlement")
	_assert(partner != null, "PartnerWorld autoload exists")
	_assert(settlement != null, "SignalSettlement autoload exists")
	if partner == null or settlement == null:
		_finish()
		return
	_partner_backup = partner.call("export_state") as Dictionary
	_settlement_backup = settlement.call("export_state") as Dictionary
	partner.call("reset_state")
	settlement.call("reset_state")
	await process_frame

	_test_world_contract(settlement)
	_test_navigation_and_locking(partner, settlement)
	_test_mentor_and_secret(partner, settlement)
	_test_expedition_and_consequences(partner, settlement)
	_test_persistence_roundtrip(settlement)
	await _test_audio_and_ui_integration(settlement)

	partner.call("import_state", _partner_backup)
	settlement.call("import_state", _settlement_backup)
	settlement.call("save_state")
	_finish()

func _test_world_contract(settlement: Node) -> void:
	var snapshot: Dictionary = settlement.call("get_snapshot")
	_assert((snapshot.get("districts", []) as Array).size() == 6, "world exposes six navigable districts")
	_assert((snapshot.get("expeditions", []) as Array).size() == 4, "world exposes four expedition regions")
	_assert(int(snapshot.get("citizen_count", 0)) >= 3, "initial settlement contains visible residents")
	_assert(str(snapshot.get("current_district", "")) == "signal_plaza", "new world begins at Signal Plaza")
	var district_ids: Array[String] = []
	for district_variant in snapshot.get("districts", []):
		if district_variant is Dictionary:
			district_ids.append(str((district_variant as Dictionary).get("id", "")))
	for required in ["signal_plaza", "academy_quarter", "garden_terraces", "workshop_docks", "echo_archive", "expedition_gate"]:
		_assert(district_ids.has(required), "district contract contains %s" % required)

func _test_navigation_and_locking(partner: Node, settlement: Node) -> void:
	var locked: Dictionary = settlement.call("travel_to", "workshop_docks")
	_assert(not bool(locked.get("accepted", true)), "rank-locked district rejects premature travel")
	_assert(str(locked.get("reason", "")) == "district_locked", "locked district returns explicit reason")
	var academy: Dictionary = settlement.call("travel_to", "academy_quarter")
	_assert(bool(academy.get("accepted", false)), "unlocked academy accepts travel")
	_assert((academy.get("route", []) as Array).size() >= 2, "travel resolves a visible path")
	_assert(str(settlement.call("get_snapshot").get("current_district", "")) == "academy_quarter", "current district changes after travel")
	partner.call("add_settlement_xp", 130)
	var workshop: Dictionary = settlement.call("travel_to", "workshop_docks")
	_assert(bool(workshop.get("accepted", false)), "settlement rank unlocks workshop district")
	_assert((workshop.get("route", []) as Array).front() == "academy_quarter", "route begins at previous district")
	_assert((workshop.get("route", []) as Array).back() == "workshop_docks", "route ends at requested district")

func _test_mentor_and_secret(partner: Node, settlement: Node) -> void:
	settlement.call("travel_to", "academy_quarter")
	var mentor: Dictionary = settlement.call("train_with_mentor", "mentor_sora")
	_assert(bool(mentor.get("accepted", false)), "resident mentor can train in matching district")
	_assert(str(mentor.get("technique", "")) == "pattern_focus", "mentor teaches a specific technique")
	_assert(float(mentor.get("bond", 0.0)) >= 8.0, "mentor session increases persistent bond")
	var wrong_place: Dictionary = settlement.call("train_with_mentor", "medic_aro")
	_assert(not bool(wrong_place.get("accepted", true)), "mentor cannot train from another district")

	settlement.call("travel_to", "signal_plaza")
	var secret_result: Dictionary = {}
	for _step in range(3):
		secret_result = settlement.call("investigate_current_district")
	_assert(bool(secret_result.get("completed", false)), "multi-stage district secret completes")
	_assert((settlement.call("get_snapshot").get("completed_secrets", []) as Array).has("broken_constellation"), "completed secret persists in world state")
	_assert(float(partner.call("get_snapshot").get("legacy_points", 0.0)) >= 8.0, "secret rewards partner legacy")

func _test_expedition_and_consequences(partner: Node, settlement: Node) -> void:
	partner.call("add_settlement_xp", 260)
	var travel: Dictionary = settlement.call("travel_to", "expedition_gate")
	_assert(bool(travel.get("accepted", false)), "rank two unlocks Expedition Gate")
	var start: Dictionary = settlement.call("start_expedition", "prismatic_rooftops")
	_assert(bool(start.get("accepted", false)), "expedition starts at the gate")
	var completed: Dictionary = {}
	for choice in ["observe", "assist", "experiment"]:
		completed = settlement.call("advance_expedition", choice)
	_assert(bool(completed.get("completed", false)), "expedition resolves after several decisions")
	_assert(float(completed.get("final_score", 0.0)) > 0.75, "expedition produces a meaningful quality score")
	var snapshot: Dictionary = settlement.call("get_snapshot")
	_assert((snapshot.get("expedition_records", {}) as Dictionary).has("prismatic_rooftops"), "completed expedition creates permanent record")
	_assert((snapshot.get("world_flags", {}) as Dictionary).get("sky_lanes", false), "settlement rank visibly changes the world")
	_assert((partner.call("get_snapshot").get("citizens", []) as Array).has("bridgewright_lyra"), "expedition discovery recruits a resident")

func _test_persistence_roundtrip(settlement: Node) -> void:
	var exported: Dictionary = settlement.call("export_state")
	settlement.call("reset_state")
	_assert(str(settlement.call("get_snapshot").get("current_district", "")) == "signal_plaza", "reset returns to Signal Plaza")
	settlement.call("import_state", exported)
	var restored: Dictionary = settlement.call("get_snapshot")
	_assert((restored.get("completed_secrets", []) as Array).has("broken_constellation"), "secret survives export/import")
	_assert((restored.get("expedition_records", {}) as Dictionary).has("prismatic_rooftops"), "expedition record survives export/import")
	_assert(settlement.call("save_state"), "Signal Settlement saves atomically")

func _test_audio_and_ui_integration(settlement: Node) -> void:
	var audio := root.get_node_or_null("OmniAudio")
	_assert(audio != null, "OmniAudio remains available")
	if audio != null:
		audio.call("set_environment", "SETTLEMENT")
		var status: Dictionary = audio.call("get_audio_status")
		_assert(str(status.get("environment", "")) == "SETTLEMENT", "settlement has a dedicated ambience profile")
		_assert((status.get("world_environments", []) as Array).size() >= 5, "audio exposes five Partner World environments")
		var before := int(status.get("world_cues", 0))
		audio.call("play_world_cue", "mentor", 0.8)
		_assert(int((audio.call("get_audio_status") as Dictionary).get("world_cues", 0)) == before + 1, "world interaction schedules a dedicated audio cue")
		audio.call("stop_all")

	var packed := load("res://main.tscn") as PackedScene
	_assert(packed != null, "premium main scene loads")
	if packed == null:
		return
	var main := packed.instantiate()
	root.add_child(main)
	await _settle(8)
	var overlay := root.get_node_or_null("SignalSettlementOverlay")
	_assert(overlay != null, "Signal Settlement overlay autoload exists")
	if overlay != null:
		overlay.call("open_world")
		await _settle(5)
		var layout: Dictionary = overlay.call("get_layout_snapshot")
		_assert(bool(layout.get("visible", false)), "fullscreen Partner World opens")
		_assert(bool(layout.get("map_present", false)), "world destination contains navigable map")
		_assert(int((layout.get("map_snapshot", {}) as Dictionary).get("district_count", 0)) == 6, "map renders all six districts")
		overlay.call("close_world")
	var navigation := main.get_node_or_null("PremiumNavigationShell")
	_assert(navigation != null and navigation.get_script().resource_path.ends_with("premium_navigation_shell_v4.gd"), "main scene activates Wave 4 navigation")
	main.queue_free()
	await process_frame

func _settle(count: int) -> void:
	for _index in range(count):
		await process_frame

func _assert(condition: bool, description: String) -> void:
	assertions += 1
	if condition:
		print("[CI-WAVE4] PASS: %s" % description)
	else:
		failures.append(description)
		push_error("[CI-WAVE4] FAIL: %s" % description)

func _finish() -> void:
	if failures.is_empty():
		print("[CI-WAVE4] PASS: %d assertions" % assertions)
		quit(0)
	else:
		print("[CI-WAVE4] BLOCKED: %d of %d assertions failed" % [failures.size(), assertions])
		quit(1)
