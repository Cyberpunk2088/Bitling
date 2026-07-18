extends Node

## Short authored expeditions that combine discovery, choice and companion growth.

signal expedition_started(expedition: Dictionary)
signal stage_resolved(result: Dictionary)
signal expedition_completed(summary: Dictionary)

const STAGES_PER_EXPEDITION := 3
const EVENTS: Array[Dictionary] = [
	{
		"id": "signal_bridge",
		"prompt": "Eine instabile Signalbrücke flackert über einem Datenstrom. Wie gehen wir vor?",
		"choices": [
			{"label": "Rhythmus analysieren", "result": "Das Muster stabilisiert die Brücke.", "xp": 14, "effects": {"curiosity": 5.0, "energy": -3.0}, "trait": "order"},
			{"label": "Gemeinsam hinüberspringen", "result": "Der mutige Sprung wird zu einer gemeinsamen Erinnerung.", "xp": 16, "effects": {"happiness": 5.0, "energy": -5.0}, "trait": "courage"}
		]
	},
	{
		"id": "echo_archive",
		"prompt": "Im Echo-Archiv liegt eine beschädigte Erinnerung ohne Besitzer.",
		"choices": [
			{"label": "Behutsam rekonstruieren", "result": "Aus Fragmenten entsteht eine friedliche Melodie.", "xp": 15, "effects": {"happiness": 4.0, "curiosity": 4.0}, "trait": "empathy"},
			{"label": "Die Struktur kartieren", "result": "Die Architektur des Archivs wird sichtbar.", "xp": 15, "effects": {"curiosity": 6.0, "energy": -2.0}, "trait": "order"}
		]
	},
	{
		"id": "glitch_garden",
		"prompt": "Ein Garten aus Glitches wächst in unmöglichen Formen.",
		"choices": [
			{"label": "Eine neue Form züchten", "result": "Ein unbekanntes Muster beginnt zu leuchten.", "xp": 17, "effects": {"curiosity": 7.0, "happiness": 3.0}, "trait": "creativity"},
			{"label": "Die wilden Glitches ordnen", "result": "Der Garten wird stabil, ohne seine Eigenart zu verlieren.", "xp": 14, "effects": {"health": 2.0, "curiosity": 3.0}, "trait": "order"}
		]
	},
	{
		"id": "quiet_node",
		"prompt": "Ein stiller Knoten sendet kein Signal, reagiert aber auf unsere Nähe.",
		"choices": [
			{"label": "Geduldig warten", "result": "Der Knoten antwortet mit einem sanften Puls.", "xp": 13, "effects": {"energy": 4.0, "happiness": 4.0}, "trait": "empathy"},
			{"label": "Eine Frage senden", "result": "Die Antwort ist eine Karte zu einem neuen Gebiet.", "xp": 18, "effects": {"curiosity": 8.0, "energy": -3.0}, "trait": "curiosity"}
		]
	},
	{
		"id": "loop_storm",
		"prompt": "Ein Schleifensturm wiederholt denselben Moment in immer neuen Varianten.",
		"choices": [
			{"label": "Den kleinsten Unterschied finden", "result": "Eine winzige Abweichung öffnet den Ausgang.", "xp": 19, "effects": {"curiosity": 6.0, "energy": -4.0}, "trait": "curiosity"},
			{"label": "Eine eigene Variante erschaffen", "result": "Der Sturm übernimmt unsere Idee und löst sich auf.", "xp": 19, "effects": {"happiness": 5.0, "curiosity": 5.0}, "trait": "creativity"}
		]
	}
]

var active_expedition: Dictionary = {}
var completed_expeditions: int = 0
var discovered_events: Array[String] = []
var choice_history: Array[Dictionary] = []
var expedition_counter: int = 0

func start_expedition(seed_value: int = -1) -> Dictionary:
	var resolved_seed := seed_value
	if resolved_seed < 0:
		resolved_seed = hash("%s:%d" % [_date_key(), expedition_counter])
	var rng := RandomNumberGenerator.new()
	rng.seed = resolved_seed
	var indices: Array[int] = []
	for index in range(EVENTS.size()):
		indices.append(index)
	_shuffle_indices(indices, rng)
	var stages: Array[Dictionary] = []
	for index in range(mini(STAGES_PER_EXPEDITION, indices.size())):
		stages.append(EVENTS[indices[index]].duplicate(true))
	expedition_counter += 1
	active_expedition = {
		"seed": resolved_seed,
		"stage_index": 0,
		"total_xp": 0,
		"stages": stages,
		"started_at": int(Time.get_unix_time_from_system())
	}
	expedition_started.emit(active_expedition.duplicate(true))
	return get_current_stage()

func get_current_stage() -> Dictionary:
	if active_expedition.is_empty():
		return {}
	var stages: Array = active_expedition.get("stages", [])
	var stage_index := int(active_expedition.get("stage_index", 0))
	if stage_index < 0 or stage_index >= stages.size():
		return {}
	var stage: Dictionary = stages[stage_index].duplicate(true)
	stage["stage_number"] = stage_index + 1
	stage["stage_total"] = stages.size()
	return stage

func choose(choice_index: int) -> Dictionary:
	var stage := get_current_stage()
	if stage.is_empty():
		return {"accepted": false, "reason": "no_active_stage"}
	var choices: Array = stage.get("choices", [])
	if choice_index < 0 or choice_index >= choices.size():
		return {"accepted": false, "reason": "invalid_choice"}
	var choice: Dictionary = choices[choice_index]
	var event_id := str(stage.get("id", "unknown"))
	var xp_reward := maxi(int(choice.get("xp", 0)), 0)
	var effects: Dictionary = choice.get("effects", {}).duplicate(true)
	var tags: Array[String] = ["explore", "choice", event_id]
	var state := get_node_or_null("/root/GameState")
	if state != null:
		state.perform_interaction("explore", effects, xp_reward, tags)
	var brain := get_node_or_null("/root/CompanionBrain")
	if brain != null:
		brain.observe_interaction("explore", 1.0, {"event": event_id, "choice": choice_index})
		var trait_name := str(choice.get("trait", ""))
		if not trait_name.is_empty() and brain.has_method("nudge_trait"):
			brain.nudge_trait(trait_name, 0.4)
	if not discovered_events.has(event_id):
		discovered_events.append(event_id)
	var history_entry := {
		"event": event_id,
		"choice": choice_index,
		"timestamp": int(Time.get_unix_time_from_system()),
		"xp": xp_reward
	}
	choice_history.append(history_entry)
	while choice_history.size() > 100:
		choice_history.pop_front()
	active_expedition["total_xp"] = int(active_expedition.get("total_xp", 0)) + xp_reward
	active_expedition["stage_index"] = int(active_expedition.get("stage_index", 0)) + 1
	var result := {
		"accepted": true,
		"event_id": event_id,
		"result": str(choice.get("result", "")),
		"xp_reward": xp_reward,
		"completed": get_current_stage().is_empty(),
		"next_stage": get_current_stage()
	}
	stage_resolved.emit(result.duplicate(true))
	if bool(result.completed):
		completed_expeditions += 1
		var summary := {
			"completed_expeditions": completed_expeditions,
			"total_xp": int(active_expedition.get("total_xp", 0)),
			"discovered_events": discovered_events.duplicate()
		}
		active_expedition.clear()
		expedition_completed.emit(summary.duplicate(true))
		result["summary"] = summary
	return result

func export_state() -> Dictionary:
	return {
		"completed_expeditions": completed_expeditions,
		"discovered_events": discovered_events.duplicate(),
		"choice_history": choice_history.duplicate(true),
		"expedition_counter": expedition_counter
	}

func import_state(data: Dictionary) -> void:
	completed_expeditions = maxi(int(data.get("completed_expeditions", 0)), 0)
	discovered_events.clear()
	for value in data.get("discovered_events", []):
		var event_id := str(value)
		if not event_id.is_empty() and not discovered_events.has(event_id):
			discovered_events.append(event_id)
	choice_history.clear()
	for item in data.get("choice_history", []):
		if item is Dictionary:
			choice_history.append(item.duplicate(true))
	expedition_counter = maxi(int(data.get("expedition_counter", 0)), 0)
	active_expedition.clear()

func reset_state() -> void:
	active_expedition.clear()
	completed_expeditions = 0
	discovered_events.clear()
	choice_history.clear()
	expedition_counter = 0

func _shuffle_indices(values: Array[int], rng: RandomNumberGenerator) -> void:
	for index in range(values.size() - 1, 0, -1):
		var swap_index := rng.randi_range(0, index)
		var temporary := values[index]
		values[index] = values[swap_index]
		values[swap_index] = temporary

func _date_key() -> String:
	var date := Time.get_date_dict_from_system()
	return "%04d-%02d-%02d" % [
		int(date.get("year", 1970)),
		int(date.get("month", 1)),
		int(date.get("day", 1))
	]
