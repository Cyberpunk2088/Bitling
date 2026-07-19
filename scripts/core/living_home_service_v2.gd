extends "res://scripts/core/living_home_service.gd"

## Wave 3 simulation hardening. Kitchen use improves comfort and nourishment but
## leaves visible traces; it must never act as an accidental cleaning action.

func interact_object(object_id: String) -> Dictionary:
	var normalized := object_id.strip_edges().to_lower()
	if normalized != "signal_kitchen":
		return super.interact_object(object_id)
	var definition: Dictionary = OBJECT_CATALOG[normalized]
	var level := int(object_levels.get(normalized, 1))
	var count := int(interaction_counts.get(normalized, 0)) + 1
	interaction_counts[normalized] = count
	var comfort_gain := 4.0 * (1.0 + float(level - 1) * 0.16)
	var cleanliness_loss := 2.6 + float(level - 1) * 0.25
	comfort = clampf(comfort + comfort_gain, 0.0, 100.0)
	cleanliness = clampf(cleanliness - cleanliness_loss, 0.0, 100.0)
	room_xp += int(definition.get("xp", 10))
	_apply_gameplay_feedback(normalized, level)
	_check_room_level_up()
	var event := _record_event(
		"object",
		"%s wurde genutzt; danach bleiben ein paar Krümel zurück." % str(definition.get("title", normalized)),
		{"object_id": normalized, "level": level, "cleanliness_loss": cleanliness_loss}
	)
	var result := {
		"accepted": true,
		"object_id": normalized,
		"title": definition.get("title", normalized),
		"level": level,
		"stat": "comfort",
		"gain": comfort_gain,
		"cleanliness_loss": cleanliness_loss,
		"event": event,
		"snapshot": get_snapshot()
	}
	object_interacted.emit(normalized, result.duplicate(true))
	_emit_changed()
	save_state()
	return result
