extends "res://scripts/core/learning_adventure_service.gd"

## Strictly typed world-transfer bridge for existing GameState contracts.

func _apply_world_transfer(result: Dictionary) -> void:
	var state: Node = get_node_or_null("/root/GameState")
	if state != null and state.has_method("perform_interaction"):
		var success: bool = float(result.get("average_score", 0.0)) >= 0.65
		var effects: Dictionary = {
			"energy": -5.0,
			"happiness": 6.0 if success else 3.0,
			"curiosity": 14.0 if success else 7.0,
			"quest_event": "discovery_completed"
		}
		var tags: Array[String] = ["learn", "mastery", str(result.get("adventure_id", ""))]
		state.call("perform_interaction", "learning_adventure", effects, int(result.get("xp_reward", 0)), tags)
		if state.has_method("save_game_state"):
			state.call("save_game_state")
	var adaptive: Node = get_node_or_null("/root/AdaptiveLearning")
	if adaptive != null and adaptive.has_method("record_result"):
		var adventure_id: String = str(result.get("adventure_id", ""))
		var adventure: Dictionary = ADVENTURES.get(adventure_id, {}) as Dictionary
		adaptive.call("record_result", str(adventure.get("domain", "logic")), clampi(int(round(float(result.get("mastery", 20.0)) / 10.0)), 1, 10), float(result.get("average_score", 0.0)) >= 0.65, 12.0, 0)
	var partner: Node = get_node_or_null("/root/PartnerWorld")
	if partner != null and partner.has_method("observe_technique"):
		partner.call("observe_technique", str(result.get("technique", "pattern_focus")), 0.72 + float(result.get("average_score", 0.0)) * 0.8)
	var brain: Node = get_node_or_null("/root/CompanionBrain")
	if brain != null and brain.has_method("observe_interaction"):
		brain.call("observe_interaction", "learn", 0.85 + float(result.get("average_score", 0.0)) * 0.25, {"adventure": result.get("adventure_id", ""), "mastery": result.get("mastery", 0.0)})
	var performance: Node = get_node_or_null("/root/CharacterPerformance")
	if performance != null and performance.has_method("request_action"):
		performance.call("request_action", "learn", clampf(float(result.get("average_score", 0.0)), 0.5, 1.0))
	var evolution: Node = get_node_or_null("/root/EvolutionService")
	if evolution != null and evolution.has_method("evaluate_runtime"):
		evolution.call("evaluate_runtime")
