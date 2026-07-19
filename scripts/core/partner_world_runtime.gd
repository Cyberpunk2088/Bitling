extends "res://scripts/core/partner_world_service.gd"

## Runtime adapter that uses the existing DevelopmentProfile display contract.

func observe_technique(technique_id: String, exposure_quality: float = 1.0) -> Dictionary:
	if technique_id.is_empty():
		return {}
	var threshold := float(TECHNIQUE_THRESHOLDS.get(technique_id, 5.0))
	var current := float(technique_exposure.get(technique_id, 0.0))
	var aptitude := 1.0
	var development := get_node_or_null("/root/DevelopmentProfile")
	if development != null:
		var profile: Dictionary = {}
		if development.has_method("get_display_snapshot"):
			profile = development.get_display_snapshot()
		elif development.has_method("export_state"):
			profile = development.export_state()
		var attributes: Dictionary = profile.get("attributes", {})
		var curiosity := float(attributes.get("curiosity", 50.0))
		var coordination := float(attributes.get("coordination", 50.0))
		var intelligence := float(attributes.get("intelligence", 100.0))
		aptitude = clampf((curiosity * 0.40 + coordination * 0.25 + intelligence * 0.35) / 85.0, 0.65, 1.75)
	current += clampf(exposure_quality, 0.1, 4.0) * aptitude
	technique_exposure[technique_id] = current
	var learned_now := current >= threshold and not learned_techniques.has(technique_id)
	if learned_now:
		learned_techniques.append(technique_id)
		legacy_points = clampf(legacy_points + 6.0, 0.0, 200.0)
		technique_learned.emit(technique_id)
		_remember("technique_learned", {"id": technique_id, "aptitude": aptitude})
	return {
		"id": technique_id,
		"exposure": current,
		"threshold": threshold,
		"aptitude": aptitude,
		"learned": learned_techniques.has(technique_id),
		"learned_now": learned_now
	}
