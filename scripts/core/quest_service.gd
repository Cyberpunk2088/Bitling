extends Node

## Data-driven daily quest tracking.
## Generation is deterministic for a profile and local calendar date.

const DAILY_QUEST_COUNT := 3

const QUEST_DEFINITIONS: Array[Dictionary] = [
	{
		"id": "care_once",
		"title": "Show some care",
		"event": "care_action_completed",
		"target": 1,
		"xp": 25,
		"weight": 10
	},
	{
		"id": "care_three_times",
		"title": "Three caring moments",
		"event": "care_action_completed",
		"target": 3,
		"xp": 60,
		"weight": 6
	},
	{
		"id": "play_together",
		"title": "Play together",
		"event": "play_action_completed",
		"target": 1,
		"xp": 35,
		"weight": 8
	},
	{
		"id": "learn_something",
		"title": "Discover something new",
		"event": "discovery_completed",
		"target": 1,
		"xp": 40,
		"weight": 7
	},
	{
		"id": "check_needs",
		"title": "Check in on Bitling",
		"event": "needs_checked",
		"target": 1,
		"xp": 20,
		"weight": 10
	}
]

var active_date: String = ""
var active_quests: Array[Dictionary] = []

func ensure_daily_quests(profile_id: String, date: Dictionary = Time.get_date_dict_from_system()) -> Array[Dictionary]:
	var date_string := _date_to_string(date)
	if active_date == date_string and not active_quests.is_empty():
		return active_quests.duplicate(true)

	active_date = date_string
	active_quests = _generate_quests(profile_id, date_string)
	return active_quests.duplicate(true)

func record_event(event_name: String, amount: int = 1) -> Array[Dictionary]:
	var changed: Array[Dictionary] = []
	for quest in active_quests:
		if quest.get("completed", false) or quest.get("event", "") != event_name:
			continue

		var target := int(quest.get("target", 1))
		quest["progress"] = mini(int(quest.get("progress", 0)) + maxi(amount, 0), target)
		quest["completed"] = int(quest.progress) >= target
		changed.append(quest.duplicate(true))

		if has_node("/root/EventBus"):
			get_node("/root/EventBus").quest_progressed.emit(str(quest.id), int(quest.progress), target)
			if quest.completed:
				get_node("/root/EventBus").quest_completed.emit(str(quest.id))

	return changed

func claim_reward(quest_id: String) -> int:
	for quest in active_quests:
		if str(quest.get("id", "")) != quest_id:
			continue
		if not quest.get("completed", false) or quest.get("claimed", false):
			return 0
		quest["claimed"] = true
		return int(quest.get("xp", 0))
	return 0

func export_state() -> Dictionary:
	return {
		"active_date": active_date,
		"active_quests": active_quests.duplicate(true)
	}

func import_state(data: Dictionary) -> void:
	active_date = str(data.get("active_date", ""))
	active_quests.clear()
	for quest in data.get("active_quests", []):
		if quest is Dictionary:
			active_quests.append(quest.duplicate(true))

func _generate_quests(profile_id: String, date_string: String) -> Array[Dictionary]:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(profile_id + ":" + date_string)

	var pool := QUEST_DEFINITIONS.duplicate(true)
	var generated: Array[Dictionary] = []
	while not pool.is_empty() and generated.size() < DAILY_QUEST_COUNT:
		var total_weight := 0
		for definition in pool:
			total_weight += int(definition.get("weight", 1))

		var roll := rng.randi_range(1, maxi(total_weight, 1))
		var running_weight := 0
		var selected_index := 0
		for index in pool.size():
			running_weight += int(pool[index].get("weight", 1))
			if roll <= running_weight:
				selected_index = index
				break

		var quest: Dictionary = pool.pop_at(selected_index)
		quest["progress"] = 0
		quest["completed"] = false
		quest["claimed"] = false
		generated.append(quest)

	return generated

func _date_to_string(date: Dictionary) -> String:
	return "%04d-%02d-%02d" % [
		int(date.get("year", 1970)),
		int(date.get("month", 1)),
		int(date.get("day", 1))
	]
