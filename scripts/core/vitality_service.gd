extends Node

## Time-based companion needs with capped, non-punitive offline simulation.
## BITLING cannot die or lose earned progression while the player is absent.

signal vitality_applied(elapsed_seconds: float, offline: bool, deltas: Dictionary)

const LIVE_TICK_SECONDS := 60.0
const MAX_OFFLINE_SECONDS := 43200.0
const OFFLINE_SAFE_FLOOR := 20.0
const RATE_PER_HOUR: Dictionary = {
	"hunger": -1.8,
	"energy": -1.2,
	"happiness": -0.6,
	"curiosity": -0.2
}

var last_update_unix: int = 0
var _elapsed_since_tick: float = 0.0

func _ready() -> void:
	if last_update_unix <= 0:
		last_update_unix = int(Time.get_unix_time_from_system())

func _process(delta: float) -> void:
	_elapsed_since_tick += delta
	if _elapsed_since_tick < LIVE_TICK_SECONDS:
		return
	var elapsed := _elapsed_since_tick
	_elapsed_since_tick = 0.0
	apply_elapsed(elapsed, false)

func apply_elapsed(elapsed_seconds: float, offline: bool) -> Dictionary:
	var state := get_node_or_null("/root/GameState")
	if state == null or elapsed_seconds <= 0.0:
		return {}
	var capped_seconds := minf(elapsed_seconds, MAX_OFFLINE_SECONDS) if offline else elapsed_seconds
	var hours := capped_seconds / 3600.0
	var deltas := {
		"hunger": _safe_delta(float(state.hunger), float(RATE_PER_HOUR.hunger) * hours, offline),
		"energy": _safe_delta(float(state.energy), float(RATE_PER_HOUR.energy) * hours, offline),
		"happiness": _safe_delta(float(state.happiness), float(RATE_PER_HOUR.happiness) * hours, offline),
		"curiosity": _safe_delta(float(state.curiosity), float(RATE_PER_HOUR.curiosity) * hours, offline)
	}
	state.update_stats(
		float(deltas.hunger),
		float(deltas.energy),
		float(deltas.happiness),
		float(deltas.curiosity),
		0.0
	)
	last_update_unix = int(Time.get_unix_time_from_system())
	vitality_applied.emit(capped_seconds, offline, deltas.duplicate(true))
	return deltas

func export_state() -> Dictionary:
	return {
		"last_update_unix": int(Time.get_unix_time_from_system())
	}

func import_state(data: Dictionary) -> void:
	var now := int(Time.get_unix_time_from_system())
	var saved_at := int(data.get("last_update_unix", now))
	last_update_unix = now
	var elapsed := maxi(now - saved_at, 0)
	if elapsed > 0:
		apply_elapsed(float(elapsed), true)

func reset_state() -> void:
	last_update_unix = int(Time.get_unix_time_from_system())
	_elapsed_since_tick = 0.0

func _safe_delta(current: float, requested_delta: float, offline: bool) -> float:
	if not offline or requested_delta >= 0.0:
		return requested_delta
	var target := maxf(current + requested_delta, OFFLINE_SAFE_FLOOR)
	return target - current
