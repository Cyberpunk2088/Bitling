extends Node

const GERMAN_TITLES := {
	"care_once": "Zeige deinem Bitling Fürsorge",
	"care_three_times": "Drei fürsorgliche Momente",
	"play_together": "Spielt gemeinsam",
	"learn_something": "Entdeckt etwas Neues",
	"check_needs": "Sieh nach deinem Bitling"
}

var _dashboard: Node
var _quest_rows: Array[Dictionary] = []

func _ready() -> void:
	call_deferred("_bind")

func _bind() -> void:
	_dashboard = get_parent()
	if _dashboard == null:
		return
	var rows_variant: Variant = _dashboard.get("quest_rows")
	if rows_variant is Array:
		for row in rows_variant:
			if row is Dictionary:
				_quest_rows.append(row)
	var event_bus := get_node_or_null("/root/EventBus")
	if event_bus != null:
		if not event_bus.quest_progressed.is_connected(_on_quest_progressed):
			event_bus.quest_progressed.connect(_on_quest_progressed)
		if not event_bus.quest_completed.is_connected(_on_quest_completed):
			event_bus.quest_completed.connect(_on_quest_completed)
	var state := get_node_or_null("/root/GameState")
	if state != null and not state.state_changed.is_connected(_on_state_changed):
		state.state_changed.connect(_on_state_changed)
	_refresh()

func _refresh() -> void:
	var service := get_node_or_null("/root/QuestService")
	if service == null:
		return
	var quests: Array = service.active_quests
	for index in range(_quest_rows.size()):
		if index >= quests.size():
			continue
		var quest: Dictionary = quests[index]
		var row: Dictionary = _quest_rows[index]
		var title_label := row.get("title") as Label
		if title_label == null:
			continue
		var quest_id := str(quest.get("id", ""))
		title_label.text = str(GERMAN_TITLES.get(quest_id, quest.get("title", "Entdecken")))

func _on_quest_progressed(_quest_id: String, _progress: int, _target: int) -> void:
	call_deferred("_refresh")

func _on_quest_completed(_quest_id: String) -> void:
	call_deferred("_refresh")

func _on_state_changed(_key: String, _value: Variant) -> void:
	call_deferred("_refresh")
