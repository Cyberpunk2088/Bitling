extends "res://scripts/ui/learning_overlay.gd"

## Wave 5 bridge. The authored Wave 1 sequence remains intact; all normal Learn
## interactions now open the twelve-adventure hub instead of one number question.

func open_challenge() -> void:
	var director: Node = get_node_or_null("/root/LegendarySlice")
	var activities: Node = get_node_or_null("/root/LegendaryActivities")
	if director != null and activities != null and director.has_method("get_current_beat"):
		var beat: Dictionary = director.call("get_current_beat") as Dictionary
		var expected: String = str(beat.get("expected_event", ""))
		if expected in ["resonance_rhythm", "signal_translation", "pattern_focus"] and not bool(director.get("completed")):
			activities.call_deferred("open_activity", expected)
			return
	var overlay: Node = get_node_or_null("/root/LearningAdventureOverlay")
	if overlay != null and overlay.has_method("open_hub"):
		overlay.call_deferred("open_hub")

func _on_interaction_completed(interaction_id: String, _tags: Array[String]) -> void:
	if interaction_id == "learn":
		call_deferred("open_challenge")
