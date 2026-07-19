extends "res://scripts/core/legendary_slice_director.gd"

## Typed-state restoration hardening for the Legendary Slice director.

func import_state(data: Dictionary) -> void:
	if data.is_empty():
		return
	active = bool(data.get("active", false))
	completed = bool(data.get("completed", false))
	current_beat_index = clampi(int(data.get("current_beat_index", 0)), 0, BEATS.size() - 1)
	bitling_name = _sanitize_name(str(data.get("bitling_name", "BITLING")))
	care_style = _sanitize_care_style(str(data.get("care_style", "ermutigend")))
	started_at_unix = maxi(int(data.get("started_at_unix", 0)), 0)
	completed_at_unix = maxi(int(data.get("completed_at_unix", 0)), 0)
	events = (data.get("events", {}) as Dictionary).duplicate(true)
	activity_results = (data.get("activity_results", {}) as Dictionary).duplicate(true)
	activity_history.clear()
	for item in data.get("activity_history", []):
		if item is Dictionary:
			activity_history.append((item as Dictionary).duplicate(true))
	while activity_history.size() > MAX_ACTIVITY_HISTORY:
		activity_history.pop_front()
	_advance_ready_beats(false)
