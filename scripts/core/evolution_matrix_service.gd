extends Node

## Explainable clean-room evolution forecast.
## Routes qualify through several independent categories instead of a single level gate.

signal forecast_updated(candidates: Array[Dictionary])

const CATEGORY_PASS_SCORE := 0.80
const ROUTES: Dictionary = {
	"radiant_scholar": {
		"name": "LICHTGELEHRTER",
		"description": "Verbindet präzises Lernen mit neugieriger Eigenständigkeit.",
		"minimum_level": 24,
		"required_categories": 3,
		"categories": {
			"growth": {"iq": 108.0, "logic": 34.0, "curiosity": 58.0},
			"bond": {"trust": 32.0, "relationship": 34.0},
			"care": {"care_quality": 62.0, "care_strain_max": 10.0},
			"habits": {"routine": 28.0, "discipline": 24.0},
			"bonus": {"learned_techniques_count": 2.0, "completed_expeditions": 2.0}
		}
	},
	"heart_bastion": {
		"name": "HERZBASTION",
		"description": "Eine beschützende Form aus Fürsorge, Vertrauen und Selbstkontrolle.",
		"minimum_level": 24,
		"required_categories": 3,
		"categories": {
			"growth": {"empathy": 60.0, "resilience": 52.0},
			"bond": {"trust": 48.0, "relationship": 46.0},
			"care": {"care_quality": 74.0, "recovery_chain": 5.0},
			"habits": {"self_control": 36.0, "discipline": 30.0},
			"bonus": {"settlement_rank": 1.0, "citizens_count": 2.0}
		}
	},
	"mosaic_trickster": {
		"name": "MOSAIKSCHELM",
		"description": "Improvisiert mit Humor, Bewegung und unvorhersehbaren Ideen.",
		"minimum_level": 26,
		"required_categories": 3,
		"categories": {
			"growth": {"humor": 62.0, "creativity": 60.0, "coordination": 48.0},
			"bond": {"familiarity": 36.0, "relationship": 34.0},
			"care": {"care_quality": 56.0, "care_strain_max": 16.0},
			"habits": {"independence": 34.0, "social_confidence": 28.0},
			"bonus": {"comic_trip_mastery": 1.0, "completed_expeditions": 3.0}
		}
	},
	"signal_wanderer": {
		"name": "SIGNALWANDERER",
		"description": "Wächst durch Mut, Erkundung und Entscheidungen unter Unsicherheit.",
		"minimum_level": 34,
		"required_categories": 3,
		"categories": {
			"growth": {"courage": 58.0, "curiosity": 62.0, "exploration": 42.0},
			"bond": {"trust": 36.0, "relationship": 42.0},
			"care": {"care_quality": 58.0, "health": 68.0},
			"habits": {"independence": 46.0, "resilience": 54.0},
			"bonus": {"completed_expeditions": 6.0, "citizens_count": 3.0}
		}
	},
	"chorus_mentor": {
		"name": "CHORMENTOR",
		"description": "Lehrt andere Bitlings und verbindet unterschiedliche Talente.",
		"minimum_level": 42,
		"required_categories": 4,
		"categories": {
			"growth": {"teaching": 46.0, "language": 42.0, "empathy": 62.0},
			"bond": {"trust": 58.0, "relationship": 60.0},
			"care": {"care_quality": 70.0, "recovery_chain": 4.0},
			"habits": {"teaching_habit": 36.0, "social_confidence": 48.0},
			"bonus": {"mentor_chorus_mastery": 1.0, "settlement_rank": 2.0}
		}
	},
	"elderstar_oracle": {
		"name": "ALTSTERN-ORAKEL",
		"description": "Verdichtet mehrere Lebensphasen zu übertragbarer Weisheit.",
		"minimum_level": 64,
		"required_categories": 4,
		"categories": {
			"growth": {"iq": 118.0, "logic": 56.0, "empathy": 64.0},
			"bond": {"trust": 72.0, "relationship": 74.0},
			"care": {"care_quality": 76.0, "care_strain_max": 12.0},
			"habits": {"routine": 58.0, "self_control": 56.0, "independence": 54.0},
			"bonus": {"legacy_points": 100.0, "generation": 2.0, "settlement_rank": 3.0}
		}
	}
}

var discovered_routes: Array[String] = []
var last_forecast: Array[Dictionary] = []

func evaluate_runtime() -> Array[Dictionary]:
	return evaluate_context(_build_runtime_context())

func evaluate_context(context: Dictionary) -> Array[Dictionary]:
	var candidates: Array[Dictionary] = []
	for route_value in ROUTES.keys():
		var route_id := str(route_value)
		var route: Dictionary = ROUTES[route_id]
		var result := _evaluate_route(route_id, route, context)
		candidates.append(result)
		if bool(result.get("eligible", false)) and not discovered_routes.has(route_id):
			discovered_routes.append(route_id)
	candidates.sort_custom(_sort_candidates)
	last_forecast = candidates.duplicate(true)
	forecast_updated.emit(last_forecast.duplicate(true))
	return last_forecast

func get_route(route_id: String) -> Dictionary:
	if not ROUTES.has(route_id):
		return {}
	var route: Dictionary = ROUTES[route_id].duplicate(true)
	route["id"] = route_id
	return route

func get_best_candidate() -> Dictionary:
	if last_forecast.is_empty():
		evaluate_runtime()
	return last_forecast[0].duplicate(true) if not last_forecast.is_empty() else {}

func get_hint(route_id: String) -> String:
	for result in last_forecast:
		if str(result.get("id", "")) != route_id:
			continue
		if bool(result.get("eligible", false)):
			return "Entwicklungsfenster offen: %s Kategorien erfüllt." % int(result.get("passed_categories", 0))
		var missing: Array = result.get("weakest_categories", [])
		if missing.is_empty():
			return "Mehr gemeinsame Erfahrung wird benötigt."
		return "Stärkster nächster Hebel: %s." % str(missing[0]).capitalize()
	return "Diese Route wurde noch nicht ausgewertet."

func export_state() -> Dictionary:
	return {"discovered_routes": discovered_routes.duplicate()}

func import_state(data: Dictionary) -> void:
	discovered_routes.clear()
	for value in data.get("discovered_routes", []):
		var route_id := str(value)
		if ROUTES.has(route_id) and not discovered_routes.has(route_id):
			discovered_routes.append(route_id)
	last_forecast.clear()

func reset_state() -> void:
	discovered_routes.clear()
	last_forecast.clear()

func _evaluate_route(route_id: String, route: Dictionary, context: Dictionary) -> Dictionary:
	var minimum_level := int(route.get("minimum_level", 1))
	var level := int(context.get("level", 1))
	var category_results: Dictionary = {}
	var passed_categories := 0
	var score_total := 0.0
	var categories: Dictionary = route.get("categories", {})
	for category_value in categories.keys():
		var category_id := str(category_value)
		var requirements: Dictionary = categories[category_id]
		var score := _category_score(requirements, context)
		var passed := score >= CATEGORY_PASS_SCORE
		category_results[category_id] = {"score": score, "passed": passed}
		score_total += score
		if passed:
			passed_categories += 1
	var required_categories := int(route.get("required_categories", 3))
	var level_score := clampf(float(level) / float(maxi(minimum_level, 1)), 0.0, 1.0)
	var category_average := score_total / float(maxi(categories.size(), 1))
	var total_score := category_average * 0.86 + level_score * 0.14
	var weakest := _weakest_categories(category_results)
	return {
		"id": route_id,
		"name": route.get("name", route_id),
		"description": route.get("description", ""),
		"eligible": level >= minimum_level and passed_categories >= required_categories,
		"score": total_score,
		"level": level,
		"minimum_level": minimum_level,
		"passed_categories": passed_categories,
		"required_categories": required_categories,
		"categories": category_results,
		"weakest_categories": weakest
	}

func _category_score(requirements: Dictionary, context: Dictionary) -> float:
	if requirements.is_empty():
		return 1.0
	var total := 0.0
	var count := 0
	for metric_value in requirements.keys():
		var metric := str(metric_value)
		var target := float(requirements[metric])
		var is_maximum := metric.ends_with("_max")
		var context_key := metric.trim_suffix("_max") if is_maximum else metric
		var actual := float(context.get(context_key, 0.0))
		var score := 0.0
		if is_maximum:
			if actual <= target:
				score = 1.0
			else:
				score = clampf(1.0 - (actual - target) / maxf(target, 1.0), 0.0, 1.0)
		else:
			score = 1.0 if target <= 0.0 else clampf(actual / target, 0.0, 1.0)
		total += score
		count += 1
	return total / float(maxi(count, 1))

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
	if development != null and development.has_method("get_snapshot"):
		var profile: Dictionary = development.get_snapshot()
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
		context["citizens_count"] = float((world_snapshot.get("citizens", []) as Array).size())
		context["learned_techniques_count"] = float((world_snapshot.get("learned_techniques", []) as Array).size())
		for technique_value in world_snapshot.get("learned_techniques", []):
			context["%s_mastery" % str(technique_value)] = 1.0
	var exploration := get_node_or_null("/root/ExplorationService")
	if exploration != null:
		var exploration_state: Dictionary = exploration.export_state()
		context["completed_expeditions"] = float(exploration_state.get("completed_expeditions", 0))
	return context

func _merge_numeric(target: Dictionary, source_variant: Variant) -> void:
	if not source_variant is Dictionary:
		return
	var source := source_variant as Dictionary
	for key in source.keys():
		target[str(key)] = float(source[key])

func _merge_upbringing(target: Dictionary, source_variant: Variant) -> void:
	_merge_numeric(target, source_variant)

func _merge_skills(target: Dictionary, source_variant: Variant) -> void:
	if not source_variant is Dictionary:
		return
	var source := source_variant as Dictionary
	for key in source.keys():
		var skill_value: Variant = source[key]
		if skill_value is Dictionary:
			target[str(key)] = float((skill_value as Dictionary).get("rating", 0.0))

func _weakest_categories(category_results: Dictionary) -> Array[String]:
	var ordered: Array[Dictionary] = []
	for category_value in category_results.keys():
		var category_id := str(category_value)
		var result: Dictionary = category_results[category_id]
		ordered.append({"id": category_id, "score": float(result.get("score", 0.0))})
	ordered.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a.get("score", 0.0)) < float(b.get("score", 0.0)))
	var values: Array[String] = []
	for entry in ordered:
		if float(entry.get("score", 0.0)) < CATEGORY_PASS_SCORE:
			values.append(str(entry.get("id", "")))
	return values

func _sort_candidates(a: Dictionary, b: Dictionary) -> bool:
	if bool(a.get("eligible", false)) != bool(b.get("eligible", false)):
		return bool(a.get("eligible", false))
	var score_a := float(a.get("score", 0.0))
	var score_b := float(b.get("score", 0.0))
	if is_equal_approx(score_a, score_b):
		return str(a.get("id", "")) < str(b.get("id", ""))
	return score_a > score_b
