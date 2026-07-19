extends SceneTree

var failures: Array[String] = []
var assertions: int = 0

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	await process_frame
	await process_frame
	_test_care_strain_and_recovery()
	_test_technique_learning()
	_test_settlement_growth()
	_test_life_stage_and_legacy()
	_test_multi_category_evolution()
	_test_round_trip_persistence()
	if failures.is_empty():
		print("[CI-PARTNER] PASS: %d assertions" % assertions)
		quit(0)
		return
	push_error("[CI-PARTNER] FAIL: %d of %d assertions failed" % [failures.size(), assertions])
	for failure in failures:
		push_error("[CI-PARTNER]   - %s" % failure)
	quit(1)

func _test_care_strain_and_recovery() -> void:
	var world := root.get_node_or_null("PartnerWorld")
	_assert(world != null, "PartnerWorld autoload exists")
	if world == null:
		return
	world.reset_state()
	var initial := float(world.care_quality)
	world.register_care_strain("test_hunger", 1.0)
	_assert(int(world.care_strain) == 1, "Care strain is counted")
	_assert(float(world.care_quality) < initial, "Care strain lowers quality")
	for _index in range(6):
		world.register_care_success("recovery", 1.0)
	_assert(float(world.care_quality) > initial - 5.0, "Repeated good care repairs strain impact")
	_assert(int(world.recovery_chain) == 6, "Recovery chain records consistent care")

func _test_technique_learning() -> void:
	var world := root.get_node("PartnerWorld")
	world.reset_state()
	var result: Dictionary = {}
	for _index in range(12):
		result = world.observe_technique("comic_trip", 1.0)
		if bool(result.get("learned", false)):
			break
	_assert(bool(result.get("learned", false)), "Repeated observation teaches an original technique")
	_assert(world.learned_techniques.has("comic_trip"), "Learned technique is stored")
	_assert(float(result.get("aptitude", 0.0)) >= 0.65, "Development attributes influence learning aptitude")

func _test_settlement_growth() -> void:
	var world := root.get_node("PartnerWorld")
	world.reset_state()
	var first: Dictionary = world.register_world_discovery("glitch_garden")
	var repeated: Dictionary = world.register_world_discovery("glitch_garden")
	_assert(bool(first.get("recruited_now", false)), "First discovery recruits a settlement citizen")
	_assert(not bool(repeated.get("recruited_now", true)), "Repeated discovery does not duplicate citizens")
	for event_id in ["signal_bridge", "echo_archive", "quiet_node", "loop_storm"]:
		world.register_world_discovery(event_id)
	var snapshot: Dictionary = world.get_snapshot()
	_assert((snapshot.get("citizens", []) as Array).size() == 5, "All authored discoveries create five unique citizens")
	_assert(int(snapshot.get("settlement_rank", 0)) >= 1, "Recruitment advances settlement rank")
	_assert((snapshot.get("facilities", []) as Array).has("clinic"), "Settlement rank unlocks facilities")

func _test_life_stage_and_legacy() -> void:
	var world := root.get_node("PartnerWorld")
	world.reset_state()
	world.advance_time(2500.0 * 60.0, false)
	_assert(str(world.life_stage) == "wise", "Long-term play reaches the wise life stage")
	for technique_id in ["pattern_focus", "care_pulse"]:
		for _index in range(12):
			world.observe_technique(technique_id, 1.0)
			if world.learned_techniques.has(technique_id):
				break
	world.award_legacy_points(120.0, "test_milestone")
	_assert(world.can_create_legacy_seed(), "Wise Bitling with mastery can create a legacy seed")
	var seed: Dictionary = world.create_legacy_seed()
	_assert(bool(seed.get("accepted", false)), "Legacy renewal succeeds when requirements are met")
	_assert(int(world.generation) == 2, "Legacy renewal advances the generation")
	_assert(str(world.life_stage) == "hatchling", "New generation begins at hatchling stage")
	_assert(world.learned_techniques.size() >= 2, "Selected techniques survive as inherited mastery")

func _test_multi_category_evolution() -> void:
	var matrix := root.get_node_or_null("EvolutionMatrix")
	_assert(matrix != null, "EvolutionMatrix autoload exists")
	if matrix == null:
		return
	matrix.reset_state()
	var context := {
		"level": 30,
		"iq": 118.0, "logic": 48.0, "curiosity": 72.0,
		"trust": 50.0, "relationship": 52.0,
		"care_quality": 82.0, "care_strain": 2.0,
		"routine": 0.0, "discipline": 0.0,
		"learned_techniques_count": 0.0, "completed_expeditions": 0.0
	}
	var forecast: Array[Dictionary] = matrix.evaluate_context(context)
	var scholar := _find_candidate(forecast, "radiant_scholar")
	_assert(bool(scholar.get("eligible", false)), "Three strong categories can qualify an evolution route")
	_assert(int(scholar.get("passed_categories", 0)) >= 3, "Forecast exposes passed category count")
	_assert((scholar.get("categories", {}) as Dictionary).has("care"), "Forecast explains every category")
	context["level"] = 10
	forecast = matrix.evaluate_context(context)
	scholar = _find_candidate(forecast, "radiant_scholar")
	_assert(not bool(scholar.get("eligible", true)), "Minimum developmental level remains a hard safety gate")
	_assert(not str(matrix.get_hint("radiant_scholar")).is_empty(), "Forecast provides a readable next-step hint")

func _test_round_trip_persistence() -> void:
	var world := root.get_node("PartnerWorld")
	var matrix := root.get_node("EvolutionMatrix")
	var store := root.get_node_or_null("PartnerWorldStore")
	_assert(store != null, "PartnerWorldStore autoload exists")
	if store == null:
		return
	world.reset_state()
	matrix.reset_state()
	world.register_world_discovery("echo_archive")
	world.register_care_success("persistence", 2.0)
	matrix.evaluate_context({
		"level": 80, "iq": 150.0, "logic": 90.0, "empathy": 90.0,
		"trust": 90.0, "relationship": 90.0, "care_quality": 90.0,
		"care_strain": 0.0, "routine": 90.0, "self_control": 90.0,
		"independence": 90.0, "legacy_points": 150.0, "generation": 3.0,
		"settlement_rank": 4.0
	})
	var expected: Dictionary = world.export_state()
	_assert(store.save_now(), "Partner-world state writes atomically")
	world.reset_state()
	matrix.reset_state()
	_assert(store.load_now(), "Partner-world state reloads from disk")
	var restored: Dictionary = world.get_snapshot()
	_assert(int(restored.get("settlement_xp", 0)) == int(expected.get("settlement_xp", -1)), "Settlement progression survives round trip")
	_assert(is_equal_approx(float(restored.get("care_quality", 0.0)), float(expected.get("care_quality", -1.0))), "Care quality survives round trip")
	_assert(matrix.discovered_routes.size() > 0, "Discovered evolution routes survive round trip")

func _find_candidate(forecast: Array[Dictionary], route_id: String) -> Dictionary:
	for candidate in forecast:
		if str(candidate.get("id", "")) == route_id:
			return candidate
	return {}

func _assert(condition: bool, description: String) -> void:
	assertions += 1
	if not condition:
		failures.append(description)
