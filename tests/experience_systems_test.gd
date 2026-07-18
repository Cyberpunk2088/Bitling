extends SceneTree

var failures: Array[String] = []
var assertions: int = 0

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	_test_contextual_dialogue()
	_test_haptic_patterns()
	_test_controlled_trait_nudge()
	_test_exploration_choice_personality()
	_test_runtime_overlays()
	_test_dialogue_save_roundtrip()
	if failures.is_empty():
		print("[CI-XP] PASS: %d assertions" % assertions)
		quit(0)
		return
	push_error("[CI-XP] FAIL: %d of %d assertions failed" % [failures.size(), assertions])
	for failure in failures:
		push_error("[CI-XP]   - %s" % failure)
	quit(1)

func _test_contextual_dialogue() -> void:
	var director := root.get_node_or_null("DialogueDirector")
	_assert(director != null, "DialogueDirector autoload exists")
	if director == null:
		return
	director.reset_state()
	var first := str(director.compose("care", {"test": 1}))
	var second := str(director.compose("care", {"test": 2}))
	_assert(not first.is_empty(), "DialogueDirector produces a care reaction")
	_assert(first != second, "Immediate contextual dialogue does not repeat")
	var guard := root.get_node_or_null("WellbeingGuard")
	_assert(guard != null and guard.validate_player_message(first), "Generated dialogue passes wellbeing guard")
	var exported: Dictionary = director.export_state()
	director.reset_state()
	director.import_state(exported)
	_assert(not director.recent_line_ids.is_empty(), "Dialogue history survives export/import")

func _test_haptic_patterns() -> void:
	var haptics := root.get_node_or_null("HapticService")
	_assert(haptics != null, "HapticService autoload exists")
	if haptics == null:
		return
	var success_pattern: Dictionary = haptics.get_pattern("success")
	_assert(int(success_pattern.get("duration", 0)) > 0, "Success haptic has a positive duration")
	_assert(float(success_pattern.get("amplitude", 0.0)) > 0.0, "Success haptic has a positive amplitude")
	_assert(haptics.get_pattern("unknown").is_empty(), "Unknown haptic pattern fails closed")

func _test_controlled_trait_nudge() -> void:
	var brain := root.get_node_or_null("CompanionBrain")
	_assert(brain != null, "CompanionBrain autoload exists")
	if brain == null:
		return
	brain.reset_state()
	var old_value := float(brain.personality.get("curiosity", 0.0))
	_assert(brain.nudge_trait("curiosity", 1.0), "Known trait can be nudged")
	_assert(float(brain.personality.get("curiosity", 0.0)) > old_value, "Trait nudge changes personality")
	_assert(not brain.nudge_trait("missing_trait", 1.0), "Unknown trait is rejected")

func _test_exploration_choice_personality() -> void:
	var exploration := root.get_node_or_null("ExplorationService")
	var brain := root.get_node_or_null("CompanionBrain")
	_assert(exploration != null and brain != null, "Exploration and companion services exist")
	if exploration == null or brain == null:
		return
	brain.reset_state()
	exploration.reset_state()
	var stage: Dictionary = exploration.start_expedition(31337)
	var choices: Array = stage.get("choices", [])
	_assert(not choices.is_empty(), "Expedition stage exposes choices")
	if choices.is_empty():
		return
	var trait_name := str(choices[0].get("trait", ""))
	var old_value := float(brain.personality.get(trait_name, 0.0))
	var result: Dictionary = exploration.choose(0)
	_assert(bool(result.get("accepted", false)), "Expedition choice is accepted")
	_assert(float(brain.personality.get(trait_name, 0.0)) > old_value, "Expedition choice shapes its declared trait")

func _test_runtime_overlays() -> void:
	for node_name in ["DialogueToast", "LearningOverlay", "ExplorationOverlay", "EvolutionOverlay"]:
		_assert(root.has_node(node_name), "%s autoload exists" % node_name)

func _test_dialogue_save_roundtrip() -> void:
	var state := root.get_node_or_null("GameState")
	var director := root.get_node_or_null("DialogueDirector")
	_assert(state != null and director != null, "Save and dialogue services exist")
	if state == null or director == null:
		return
	director.reset_state()
	director.compose("rest", {"roundtrip": true})
	_assert(state.save_game_state(), "Dialogue fixture saves")
	director.reset_state()
	_assert(state.load_game_state(), "Dialogue fixture loads")
	_assert(not director.recent_line_ids.is_empty(), "Dialogue anti-repeat history survives game save")

func _assert(condition: bool, description: String) -> void:
	assertions += 1
	if not condition:
		failures.append(description)
