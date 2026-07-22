extends "res://scripts/core/habitat_interaction_service.gd"

## Persistent relationship behavior layered over the anti-grind habitat loop.
## Habits require multiple sessions and multiple contexts. Conflicts are
## deterministic, visible before commitment and change Xogot's future intention.

signal behavior_profile_changed(snapshot: Dictionary)

const BEHAVIOR_VERSION := 1
const SESSION_HABIT_GAIN := 18.0
const CONTEXT_HABIT_GAIN := 7.0
const EXPOSURE_HABIT_GAIN := 2.0
const HABIT_FORMED_THRESHOLD := 55.0
const HABIT_MIN_SESSIONS := 3
const HABIT_MIN_CONTEXTS := 2
const CONFLICT_NEGOTIATE_THRESHOLD := 38.0
const CONFLICT_RESIST_THRESHOLD := 74.0
const EXECUTION_MULTIPLIERS := {
	"embraced": 1.0,
	"negotiated": 0.72,
	"resisted": 0.38
}
const BEHAVIOR_AXES: Array[String] = ["agency", "novelty", "arousal", "contact"]
const CHOICE_PROFILES := {
	"familiar_snack": {"axis": "novelty", "direction": -1.0, "intention": "organize"},
	"new_flavor": {"axis": "novelty", "direction": 1.0, "intention": "discover"},
	"let_choose": {"axis": "agency", "direction": 1.0, "intention": "observe"},
	"follow_rule": {"axis": "agency", "direction": -1.0, "intention": "organize"},
	"invent_together": {"axis": "novelty", "direction": 1.0, "intention": "create"},
	"let_lead": {"axis": "agency", "direction": 1.0, "intention": "play"},
	"observe_first": {"axis": "arousal", "direction": -1.0, "intention": "observe"},
	"explain_connection": {"axis": "contact", "direction": 1.0, "intention": "discover"},
	"ask_back": {"axis": "agency", "direction": 1.0, "intention": "discover"},
	"check_in": {"axis": "contact", "direction": 1.0, "intention": "observe"},
	"practical_help": {"axis": "agency", "direction": -1.0, "intention": "organize"},
	"give_space": {"axis": "contact", "direction": -1.0, "intention": "observe"},
	"dim_lights": {"axis": "arousal", "direction": -1.0, "intention": "rest"},
	"quiet_story": {"axis": "contact", "direction": 1.0, "intention": "rest"},
	"dream_archive": {"axis": "novelty", "direction": 1.0, "intention": "create"}
}

var session_index := 0
var habits: Dictionary = {}
var axis_orientations: Dictionary = {}
var axis_conflicts: Dictionary = {}
var session_choice_ids: Dictionary = {}
var dominant_behavior := "observe"
var _pending_preview: Dictionary = {}

func _ready() -> void:
	super._ready()
	session_index += 1
	session_choice_ids.clear()
	_apply_persistent_behavior()
	save_state()
	behavior_profile_changed.emit(get_behavior_snapshot())

func get_lens_options(lens_id: String = selected_lens) -> Array:
	var options: Array = super.get_lens_options(lens_id)
	for item_variant in options:
		if not item_variant is Dictionary:
			continue
		var option := item_variant as Dictionary
		var preview := preview_choice(str(option.get("id", "")))
		option["execution_mode"] = preview.get("execution_mode", "embraced")
		option["behavior_label"] = preview.get("behavior_label", "OFFEN")
		option["habit_strength"] = preview.get("habit_strength", 0.0)
		option["habit_formed"] = preview.get("habit_formed", false)
		option["friction"] = preview.get("friction", 0.0)
		option["behavior_axis"] = preview.get("axis", "")
	return options

func get_snapshot() -> Dictionary:
	var snapshot := super.get_snapshot()
	snapshot["behavior"] = get_behavior_snapshot()
	var contract: Dictionary = snapshot.get("agency_contract", {}) as Dictionary
	contract["persistent_habits"] = true
	contract["visible_conflict"] = true
	contract["deterministic_responses"] = true
	snapshot["agency_contract"] = contract
	return snapshot

func get_behavior_snapshot() -> Dictionary:
	return {
		"version": BEHAVIOR_VERSION,
		"session_index": session_index,
		"habits": habits.duplicate(true),
		"axis_orientations": axis_orientations.duplicate(true),
		"axis_conflicts": axis_conflicts.duplicate(true),
		"dominant_behavior": dominant_behavior,
		"dominant_habit": _dominant_habit(),
		"active_conflict": _active_conflict()
	}

func preview_choice(choice_id: String) -> Dictionary:
	var profile: Dictionary = CHOICE_PROFILES.get(choice_id, {}) as Dictionary
	if profile.is_empty():
		return {"execution_mode": "embraced", "behavior_label": "OFFEN", "habit_strength": 0.0, "habit_formed": false, "friction": 0.0, "axis": ""}
	var axis := str(profile.get("axis", ""))
	var direction := float(profile.get("direction", 0.0))
	var orientation := float(axis_orientations.get(axis, 0.0))
	var conflict := float(axis_conflicts.get(axis, 0.0))
	var habit: Dictionary = habits.get(choice_id, {}) as Dictionary
	var strength := float(habit.get("strength", 0.0))
	var formed := bool(habit.get("formed", false))
	var opposition := maxf(0.0, -direction * orientation)
	var friction := clampf(opposition + conflict - (25.0 if formed else 0.0), 0.0, 100.0)
	var mode := "embraced"
	var label := "OFFEN"
	if friction >= CONFLICT_RESIST_THRESHOLD:
		mode = "resisted"
		label = "GRENZE"
	elif friction >= CONFLICT_NEGOTIATE_THRESHOLD:
		mode = "negotiated"
		label = "AUSHANDELN"
	elif formed:
		label = "GEWOHNHEIT"
	return {
		"choice_id": choice_id,
		"axis": axis,
		"direction": direction,
		"execution_mode": mode,
		"execution_multiplier": float(EXECUTION_MULTIPLIERS.get(mode, 1.0)),
		"behavior_label": label,
		"habit_strength": strength,
		"habit_formed": formed,
		"friction": friction,
		"orientation": orientation,
		"conflict": conflict,
		"intention": str(profile.get("intention", "observe"))
	}

func resolve_choice(choice_id: String) -> Dictionary:
	var option := _find_option(selected_lens, choice_id)
	if option.is_empty():
		return {"accepted": false, "reason": "unknown_choice"}
	_pending_preview = preview_choice(choice_id)
	var moment := get_current_moment()
	var repeat_count := _repeat_count(choice_id)
	var progression_state := _progression_state(repeat_count)
	var xp_multiplier := _xp_multiplier(repeat_count)
	var effect_multiplier := _effect_multiplier(repeat_count)
	var execution_mode := str(_pending_preview.get("execution_mode", "embraced"))
	var execution_multiplier := float(_pending_preview.get("execution_multiplier", 1.0))
	var trait_id := str(option.get("trait", "curiosity"))
	var trait_value := _trait_value(trait_id)
	var resonant := trait_value >= 60.0
	var xp := roundi(float(option.get("xp", 0)) * xp_multiplier * execution_multiplier)
	var effects := _scaled_effects(option.get("effects", {}) as Dictionary, repeat_count)
	effects = _apply_execution_to_effects(effects, execution_multiplier)
	var tags: Array[String] = ["habitat", selected_lens, choice_id, str(moment.get("id", "")), progression_state, "no_correct_answer", execution_mode]
	var state := _game_state()
	if state != null:
		state.call("perform_interaction", str(option.get("interaction", selected_lens)), effects, xp, tags)
	var brain := _brain()
	if brain != null:
		brain.call("nudge_trait", trait_id, float(option.get("trait_delta", 0.0)) * xp_multiplier * execution_multiplier)
	resolved_count += 1
	var result := {
		"accepted": true,
		"lens": selected_lens,
		"choice_id": choice_id,
		"choice_title": str(option.get("title", choice_id)),
		"moment_id": str(moment.get("id", "")),
		"hotspot": focused_hotspot,
		"resonant": resonant,
		"novel": repeat_count == 0,
		"repeat_count": repeat_count,
		"progression_state": progression_state,
		"xp_multiplier": xp_multiplier,
		"effect_multiplier": effect_multiplier,
		"execution_mode": execution_mode,
		"execution_multiplier": execution_multiplier,
		"friction_before": float(_pending_preview.get("friction", 0.0)),
		"trait": trait_id,
		"trait_value": trait_value,
		"xp_reward": xp,
		"no_correct_answer": true,
		"response": _behavior_response(_response_for_repeat(str(option.get("response", "Xogot reagiert aufmerksam.")), repeat_count), execution_mode),
		"consequence": _behavior_consequence(_consequence_for(repeat_count, resonant, trait_id), execution_mode)
	}
	_store_outcome(result)
	_create_memory_when_meaningful(result)
	choice_resolved.emit(result.duplicate(true))
	refresh_moment(true)
	save_state()
	_pending_preview.clear()
	return result

func export_state() -> Dictionary:
	var data := super.export_state()
	data["behavior_version"] = BEHAVIOR_VERSION
	data["session_index"] = session_index
	data["habits"] = habits.duplicate(true)
	data["axis_orientations"] = axis_orientations.duplicate(true)
	data["axis_conflicts"] = axis_conflicts.duplicate(true)
	data["dominant_behavior"] = dominant_behavior
	return data

func import_state(data: Dictionary) -> void:
	super.import_state(data)
	session_index = maxi(int(data.get("session_index", 0)), 0)
	habits = (data.get("habits", {}) as Dictionary).duplicate(true)
	axis_orientations = (data.get("axis_orientations", {}) as Dictionary).duplicate(true)
	axis_conflicts = (data.get("axis_conflicts", {}) as Dictionary).duplicate(true)
	dominant_behavior = str(data.get("dominant_behavior", "observe"))
	_sanitize_behavior_state()
	_apply_persistent_behavior()

func reset_state() -> void:
	super.reset_state()
	session_index = 0
	habits.clear()
	axis_orientations.clear()
	axis_conflicts.clear()
	session_choice_ids.clear()
	dominant_behavior = "observe"
	save_state()

func _store_outcome(result: Dictionary) -> void:
	_update_behavior_from_result(result)
	super._store_outcome(result)
	behavior_profile_changed.emit(get_behavior_snapshot())

func _apply_execution_to_effects(effects: Dictionary, multiplier: float) -> Dictionary:
	var adjusted := effects.duplicate(true)
	for key_variant in adjusted.keys():
		var key := str(key_variant)
		var value: Variant = adjusted[key_variant]
		if not (value is int or value is float):
			continue
		if key in NEED_EFFECTS:
			continue
		adjusted[key_variant] = float(value) * multiplier
	return adjusted

func _update_behavior_from_result(result: Dictionary) -> void:
	var choice_id := str(result.get("choice_id", ""))
	var profile: Dictionary = CHOICE_PROFILES.get(choice_id, {}) as Dictionary
	if profile.is_empty():
		return
	var axis := str(profile.get("axis", ""))
	var direction := float(profile.get("direction", 0.0))
	var context_key := "%s:%s" % [str(result.get("moment_id", "")), str(result.get("hotspot", ""))]
	var habit: Dictionary = (habits.get(choice_id, {}) as Dictionary).duplicate(true)
	var sessions: Array = (habit.get("sessions", []) as Array).duplicate()
	var contexts: Array = (habit.get("contexts", []) as Array).duplicate()
	var first_this_session := not session_choice_ids.has(choice_id)
	if first_this_session:
		session_choice_ids[choice_id] = true
		if not sessions.has(session_index):
			sessions.append(session_index)
	if not contexts.has(context_key):
		contexts.append(context_key)
	var exposures := maxi(int(habit.get("exposures", 0)) + 1, 1)
	var strength := clampf(float(sessions.size()) * SESSION_HABIT_GAIN + float(contexts.size()) * CONTEXT_HABIT_GAIN + float(exposures) * EXPOSURE_HABIT_GAIN, 0.0, 100.0)
	var formed := strength >= HABIT_FORMED_THRESHOLD and sessions.size() >= HABIT_MIN_SESSIONS and contexts.size() >= HABIT_MIN_CONTEXTS
	habit = {
		"choice_id": choice_id,
		"title": str(result.get("choice_title", choice_id)),
		"axis": axis,
		"direction": direction,
		"intention": str(profile.get("intention", "observe")),
		"exposures": exposures,
		"sessions": sessions,
		"contexts": contexts,
		"strength": strength,
		"formed": formed,
		"last_session": session_index
	}
	habits[choice_id] = habit
	var old_orientation := float(axis_orientations.get(axis, 0.0))
	var orientation_gain := 12.0 if first_this_session else 2.0
	axis_orientations[axis] = clampf(old_orientation + direction * orientation_gain, -100.0, 100.0)
	var old_conflict := float(axis_conflicts.get(axis, 0.0))
	var opposed := direction * old_orientation < -35.0
	var conflict_delta := (16.0 if first_this_session else 4.0) if opposed else -8.0
	axis_conflicts[axis] = clampf(old_conflict + conflict_delta, 0.0, 100.0)
	var preview_after := preview_choice(choice_id)
	result["habit_strength"] = strength
	result["habit_formed"] = formed
	result["friction_after"] = float(preview_after.get("friction", 0.0))
	result["behavior_axis"] = axis
	result["behavior_changed"] = first_this_session
	result["dominant_habit"] = _dominant_habit()
	result["active_conflict"] = _active_conflict()
	_apply_persistent_behavior()

func _apply_persistent_behavior() -> void:
	var dominant := _dominant_habit()
	if not dominant.is_empty():
		dominant_behavior = str(dominant.get("intention", "observe"))
	else:
		dominant_behavior = _intention_from_axes()
	var brain := _brain()
	if brain != null:
		brain.set("current_intention", dominant_behavior)

func _dominant_habit() -> Dictionary:
	var best: Dictionary = {}
	var best_strength := -1.0
	for habit_variant in habits.values():
		if not habit_variant is Dictionary:
			continue
		var habit := habit_variant as Dictionary
		var strength := float(habit.get("strength", 0.0))
		var formed := bool(habit.get("formed", false))
		var score := strength + (30.0 if formed else 0.0)
		if score > best_strength:
			best_strength = score
			best = habit.duplicate(true)
	return best

func _active_conflict() -> Dictionary:
	var axis := ""
	var value := 0.0
	for axis_variant in BEHAVIOR_AXES:
		var axis_id := str(axis_variant)
		var candidate := float(axis_conflicts.get(axis_id, 0.0))
		if candidate > value:
			value = candidate
			axis = axis_id
	if axis.is_empty() or value < CONFLICT_NEGOTIATE_THRESHOLD:
		return {}
	return {"axis": axis, "label": _axis_label(axis), "strength": value, "severe": value >= CONFLICT_RESIST_THRESHOLD}

func _intention_from_axes() -> String:
	var strongest_axis := ""
	var strongest_value := 0.0
	for axis_variant in BEHAVIOR_AXES:
		var axis := str(axis_variant)
		var value := float(axis_orientations.get(axis, 0.0))
		if absf(value) > absf(strongest_value):
			strongest_axis = axis
			strongest_value = value
	match strongest_axis:
		"agency": return "observe" if strongest_value >= 0.0 else "organize"
		"novelty": return "discover" if strongest_value >= 0.0 else "organize"
		"arousal": return "play" if strongest_value >= 0.0 else "rest"
		"contact": return "observe" if strongest_value >= 0.0 else "rest"
		_: return "observe"

func _behavior_response(base_response: String, mode: String) -> String:
	match mode:
		"negotiated": return "%s Xogot übernimmt die Absicht, verändert aber die Ausführung." % base_response
		"resisted": return "%s Xogot setzt eine erkennbare Grenze und führt nur den notwendigen Teil aus." % base_response
		_: return "%s Xogot greift die Absicht selbstständig auf." % base_response

func _behavior_consequence(base_consequence: String, mode: String) -> String:
	match mode:
		"negotiated": return "%s Die Reibung wird Teil eurer Beziehung und bleibt für spätere Situationen wirksam." % base_consequence
		"resisted": return "%s Die Grenze verändert Xogots zukünftige Bereitschaft und aktuelle Intention." % base_consequence
		_: return "%s Diese Erfahrung kann über mehrere Sessions zu einer echten Gewohnheit werden." % base_consequence

func _axis_label(axis: String) -> String:
	return str({
		"agency": "Autonomie ↔ Struktur",
		"novelty": "Neugier ↔ Sicherheit",
		"arousal": "Stimulation ↔ Ruhe",
		"contact": "Nähe ↔ Abstand"
	}.get(axis, axis))

func _sanitize_behavior_state() -> void:
	for axis_variant in BEHAVIOR_AXES:
		var axis := str(axis_variant)
		axis_orientations[axis] = clampf(float(axis_orientations.get(axis, 0.0)), -100.0, 100.0)
		axis_conflicts[axis] = clampf(float(axis_conflicts.get(axis, 0.0)), 0.0, 100.0)
	var sanitized: Dictionary = {}
	for choice_variant in habits.keys():
		var choice_id := str(choice_variant)
		if not CHOICE_PROFILES.has(choice_id):
			continue
		var habit_variant: Variant = habits[choice_variant]
		if not habit_variant is Dictionary:
			continue
		var habit := (habit_variant as Dictionary).duplicate(true)
		habit["strength"] = clampf(float(habit.get("strength", 0.0)), 0.0, 100.0)
		habit["exposures"] = maxi(int(habit.get("exposures", 0)), 0)
		sanitized[choice_id] = habit
	habits = sanitized
