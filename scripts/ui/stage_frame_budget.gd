extends Node

const ACTIVE_INTERVAL := 1.0 / 30.0
const REDUCED_MOTION_INTERVAL := 0.20

var _stage: Control
var _timer: Timer
var _last_tick_usec := 0

func _ready() -> void:
	call_deferred("_bind_stage")

func _bind_stage() -> void:
	var dashboard := get_parent()
	if dashboard == null:
		return
	_stage = dashboard.get("stage") as Control
	if _stage == null:
		return
	_stage.set_process(false)
	_timer = Timer.new()
	_timer.name = "StageFrameTimer"
	_timer.one_shot = false
	_timer.ignore_time_scale = true
	_timer.wait_time = _target_interval()
	_timer.timeout.connect(_on_tick)
	add_child(_timer)
	_last_tick_usec = Time.get_ticks_usec()
	_timer.start()

func _on_tick() -> void:
	if _stage == null or not _stage.is_visible_in_tree():
		return
	var now_usec := Time.get_ticks_usec()
	var delta := clampf(float(now_usec - _last_tick_usec) / 1000000.0, 0.0, 0.25)
	_last_tick_usec = now_usec
	_stage.call("_process", delta)
	var desired_interval := _target_interval()
	if not is_equal_approx(_timer.wait_time, desired_interval):
		_timer.wait_time = desired_interval

func _target_interval() -> float:
	var state := get_node_or_null("/root/GameState")
	if state != null and bool(state.settings.get("reduce_motion", false)):
		return REDUCED_MOTION_INTERVAL
	return ACTIVE_INTERVAL

func _notification(what: int) -> void:
	if _timer == null:
		return
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		_timer.stop()
	elif what == NOTIFICATION_APPLICATION_FOCUS_IN:
		_last_tick_usec = Time.get_ticks_usec()
		_timer.start()
