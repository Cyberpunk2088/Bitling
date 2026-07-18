extends Node

## Protects player autonomy while allowing deep, long-term engagement.
## No earned reward is removed because of absence and no message may shame the player.

signal break_suggested(session_minutes: int, severity: int)
signal notification_blocked(reason: String)
signal copy_rejected(reason: String)

enum ReminderSeverity { GENTLE, STRONG }

const GENTLE_BREAK_MINUTES := 45
const STRONG_BREAK_MINUTES := 90
const FORBIDDEN_COPY_FRAGMENTS: Array[String] = [
	"du hast mich im stich gelassen",
	"komm zurück oder",
	"dein streak ist verloren",
	"ich bin traurig weil du nicht",
	"nur noch heute",
	"letzte chance",
	"du enttäuschst mich"
]

var session_seconds: float = 0.0
var gentle_break_emitted: bool = false
var strong_break_emitted: bool = false
var notifications_sent_today: int = 0
var notification_day_key: String = ""

func _ready() -> void:
	set_process(true)
	_refresh_notification_day()

func _process(delta: float) -> void:
	session_seconds += delta
	var minutes := int(session_seconds / 60.0)
	if minutes >= GENTLE_BREAK_MINUTES and not gentle_break_emitted:
		gentle_break_emitted = true
		break_suggested.emit(minutes, ReminderSeverity.GENTLE)
	if minutes >= STRONG_BREAK_MINUTES and not strong_break_emitted:
		strong_break_emitted = true
		break_suggested.emit(minutes, ReminderSeverity.STRONG)

func reset_session() -> void:
	session_seconds = 0.0
	gentle_break_emitted = false
	strong_break_emitted = false

func validate_player_message(message: String) -> bool:
	var normalized := message.strip_edges().to_lower()
	for fragment in FORBIDDEN_COPY_FRAGMENTS:
		if normalized.contains(fragment):
			copy_rejected.emit("Manipulative or guilt-inducing copy detected")
			return false
	return true

func can_send_notification(settings: Dictionary, recent_count: int = 0, hour_override: int = -1) -> bool:
	_refresh_notification_day()
	if not bool(settings.get("notifications_enabled", true)):
		notification_blocked.emit("Notifications disabled")
		return false
	if notifications_sent_today >= 2 or recent_count >= 2:
		notification_blocked.emit("Daily notification limit reached")
		return false

	var hour := hour_override
	if hour < 0:
		hour = int(Time.get_time_dict_from_system().get("hour", 12))
	var quiet_start := clampi(int(settings.get("quiet_hours_start", 22)), 0, 23)
	var quiet_end := clampi(int(settings.get("quiet_hours_end", 8)), 0, 23)
	if _is_in_quiet_hours(hour, quiet_start, quiet_end):
		notification_blocked.emit("Quiet hours active")
		return false
	return true

func register_notification_sent() -> void:
	_refresh_notification_day()
	notifications_sent_today += 1

func get_session_summary() -> Dictionary:
	return {
		"session_seconds": session_seconds,
		"gentle_break_emitted": gentle_break_emitted,
		"strong_break_emitted": strong_break_emitted,
		"notifications_sent_today": notifications_sent_today
	}

func _is_in_quiet_hours(hour: int, start: int, end: int) -> bool:
	if start == end:
		return false
	if start < end:
		return hour >= start and hour < end
	return hour >= start or hour < end

func _refresh_notification_day() -> void:
	var date := Time.get_date_dict_from_system()
	var current_key := "%04d-%02d-%02d" % [
		int(date.get("year", 1970)),
		int(date.get("month", 1)),
		int(date.get("day", 1))
	]
	if current_key != notification_day_key:
		notification_day_key = current_key
		notifications_sent_today = 0
