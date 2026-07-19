extends "res://scripts/core/evolution_matrix_service.gd"

## Runtime adapter for the existing DevelopmentProfile public contract.

func _build_runtime_context() -> Dictionary:
	var context: Dictionary = {}
	var state := get_node_or_null("/root/GameState")
	if state != null:
		context.merge(state.get_state_summary(), true)
		context["level"] = int(state.level)
		context["health"] = float(state.health)
	var brain := get_node_or_null("/root/CompanionBrain")
	if brain != null:
		var brain_snapshot: Dictionary = brain.get_snapshot()
		context["trust"] = float(brain_snapshot.get("trust", 0.0))
		context["relationship"] = float(brain_snapshot.get("relationship_score", 0.0))
		context["familiarity"] = float(brain_snapshot.get("familiarity", 0.0))
		var personality: Dictionary = brain_snapshot.get("personality", {})
		for key in personality.keys():
			context[str(key)] = float(personality[key])
	var development := get_node_or_null("/root/DevelopmentProfile")
	if development != null:
		var profile: Dictionary = {}
		if development.has_method("get_display_snapshot"):
			profile = development.get_display_snapshot()
		elif development.has_method("export_state"):
			profile = development.export_state()
		context["iq"] = float(profile.get("intelligence_quotient", 100))
		_merge_numeric(context, profile.get("attributes", {}))
		_merge_upbringing(context, profile.get("upbringing", {}))
		_merge_skills(context, profile.get("skills", {}))
	var world := get_node_or_null("/root/PartnerWorld")
	if world != null:
		var world_snapshot: Dictionary = world.get_snapshot()
		context["care_quality"] = float(world_snapshot.get("care_quality", 0.0))
		context["care_strain"] = float(world_snapshot.get("care_strain", 0))
		context["recovery_chain"] = float(world_snapshot.get("recovery_chain", 0))
		context["generation"] = float(world_snapshot.get("generation", 1))
		context["legacy_points"] = float(world_snapshot.get("legacy_points", 0.0))
		context["settlement_rank"] = float(world_snapshot.get("settlement_rank", 0))
		var citizen_values: Array = world_snapshot.get("citizens", [])
		var technique_values: Array = world_snapshot.get("learned_techniques", [])
		context["citizens_count"] = float(citizen_values.size())
		context["learned_techniques_count"] = float(technique_values.size())
		for technique_value in technique_values:
			context["%s_mastery" % str(technique_value)] = 1.0
	var exploration := get_node_or_null("/root/ExplorationService")
	if exploration != null and exploration.has_method("export_state"):
		var exploration_state: Dictionary = exploration.export_state()
		context["completed_expeditions"] = float(exploration_state.get("completed_expeditions", 0))
	return context
