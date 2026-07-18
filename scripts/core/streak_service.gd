extends Node

## Calendar-based daily streak service.
## Persist the dictionary returned by export_state() inside GameState.

const DATE_FORMAT := "%04d-%02d-%02d"

var current_streak: int = 0
var longest_streak: int = 0
var last_active_date: String = ""
var streak_repairs: int = 1
var pending_missed_days: int = 0

func register_activity(date: Dictionary = Time.get_date_dict_from_system()) -> Dictionary:
	var today := _date_to_string(date)
	var previous_streak := current_streak

	if last_active_date.is_empty():
		current_streak = 1
		last_active_date = today
		longest_streak = maxi(longest_streak, current_streak)
		_emit_change(previous_streak)
		return _result("started")

	var day_delta := _days_between(last_active_date, today)
	if day_delta <= 0:
		return _result("already_registered")

	if day_delta == 1:
		current_streak += 1
		last_active_date = today
		longest_streak = maxi(longest_streak, current_streak)
		pending_missed_days = 0
		_emit_change(previous_streak)
		return _result("continued")

	pending_missed_days = day_delta - 1
	return _result("recovery_available" if streak_repairs > 0 else "reset_required")

func recover_streak(date: Dictionary = Time.get_date_dict_from_system()) -> bool:
	if pending_missed_days <= 0 or streak_repairs <= 0:
		return false

	var previous_streak := current_streak
	streak_repairs -= 1
	current_streak += 1
	longest_streak = maxi(longest_streak, current_streak)
	last_active_date = _date_to_string(date)
	pending_missed_days = 0
	_emit_change(previous_streak)
	return true

func reset_after_missed_days(date: Dictionary = Time.get_date_dict_from_system()) -> void:
	var previous_streak := current_streak
	current_streak = 1
	last_active_date = _date_to_string(date)
	pending_missed_days = 0
	_emit_change(previous_streak)

func export_state() -> Dictionary:
	return {
		"current_streak": current_streak,
		"longest_streak": longest_streak,
		"last_active_date": last_active_date,
		"streak_repairs": streak_repairs,
		"pending_missed_days": pending_missed_days
	}

func import_state(data: Dictionary) -> void:
	current_streak = int(data.get("current_streak", 0))
	longest_streak = int(data.get("longest_streak", current_streak))
	last_active_date = str(data.get("last_active_date", ""))
	streak_repairs = int(data.get("streak_repairs", 1))
	pending_missed_days = int(data.get("pending_missed_days", 0))

func _result(status: String) -> Dictionary:
	return {
		"status": status,
		"current_streak": current_streak,
		"longest_streak": longest_streak,
		"streak_repairs": streak_repairs,
		"pending_missed_days": pending_missed_days
	}

func _emit_change(previous_streak: int) -> void:
	if previous_streak != current_streak and has_node("/root/EventBus"):
		get_node("/root/EventBus").streak_changed.emit(previous_streak, current_streak)

func _date_to_string(date: Dictionary) -> String:
	return DATE_FORMAT % [int(date.year), int(date.month), int(date.day)]

func _days_between(from_date: String, to_date: String) -> int:
	var from_parts := from_date.split("-")
	var to_parts := to_date.split("-")
	if from_parts.size() != 3 or to_parts.size() != 3:
		return 0

	var from_unix := Time.get_unix_time_from_datetime_dict({
		"year": int(from_parts[0]),
		"month": int(from_parts[1]),
		"day": int(from_parts[2]),
		"hour": 12,
		"minute": 0,
		"second": 0
	})
	var to_unix := Time.get_unix_time_from_datetime_dict({
		"year": int(to_parts[0]),
		"month": int(to_parts[1]),
		"day": int(to_parts[2]),
		"hour": 12,
		"minute": 0,
		"second": 0
	})
	return int(round((to_unix - from_unix) / 86400.0))
