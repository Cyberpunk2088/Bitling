extends "res://scripts/core/habitat_world_consequence_runtime.gd"

## Authoritative moment-to-moment loop for the playable home. A habitat action
## is no longer resolved by a dashboard click. Xogot approaches the object,
## observes it, exposes three in-world approaches, performs the chosen action
## and only then commits the persistent relationship/world consequence.

signal live_action_changed(snapshot: Dictionary)
signal live_action_completed(result: Dictionary)

const LIVE_ACTION_VERSION := 1
const AUTO_INITIATIVE_INTERVAL := 24.0
const MAX_COMPLETED_LIVE_ACTIONS := 20
const LIVE_ACTION_PHASES: Array[String] = ["approach", "observe", "awaiting_choice", "perform", "aftermath"]
const PHASE_DURATIONS := {
	"approach": 0.90,
	"observe": 0.62,
	"awaiting_choice": 0.0,
	"perform": 1.24,
	"aftermath": 0.82
}
const HOTSPOT_ACTIONS := {
	"bitling": "care",
	"window": "learn",
	"workbench": "learn",
	"plant": "care",
	"platform": "play",
	"sleep": "rest"
}

var live_action: Dictionary = {}
var live_action_serial := 0
var completed_live_action_count := 0
var completed_live_actions: Array[Dictionary] = []
var last_live_action_result: Dictionary = {}
var _live_idle_elapsed := 0.0

func _ready() -> void:
	super._ready()
	_live_idle_elapsed = 0.0
	live_action_changed.emit(get_live_action_snapshot())

func _process(delta: float) -> void:
	var safe_delta := maxf(delta, 0.0)
	if live_action.is_empty():
		super._process(safe_delta)
		_live_idle_elapsed += safe_delta
		if _live_idle_elapsed >= AUTO_INITIATIVE_INTERVAL:
			trigger_autonomous_initiative()
		return
	advance_live_action(safe_delta)

func get_snapshot() -> Dictionary:
	var snapshot := super.get_snapshot()
	snapshot["live_action"] = get_live_action_snapshot()
	var contract: Dictionary = snapshot.get("agency_contract", {}) as Dictionary
	contract["in_world_choices"] = true
	contract["deferred_commit"] = true
	contract["autonomous_approach"] = true
	contract["five_phase_loop"] = true
	snapshot["agency_contract"] = contract
	return snapshot

func get_live_action_snapshot() -> Dictionary:
	if live_action.is_empty():
		return {
			"version": LIVE_ACTION_VERSION,
			"active": false,
			"phase": "idle",
			"phase_progress": 0.0,
			"source": "none",
			"hotspot": focused_hotspot,
			"selected_lens": selected_lens,
			"choices": [],
			"choice_count": 0,
			"completed_count": completed_live_action_count,
			"last_result": last_live_action_result.duplicate(true)
		}
	var snapshot := live_action.duplicate(true)
	snapshot["version"] = LIVE_ACTION_VERSION
	snapshot["active"] = true
	snapshot["phase_progress"] = _phase_progress()
	snapshot["choice_count"] = (snapshot.get("choices", []) as Array).size()
	snapshot["completed_count"] = completed_live_action_count
	snapshot["last_result"] = last_live_action_result.duplicate(true)
	return snapshot

func start_encounter(hotspot_id: String, source: String = "player", replace_pending: bool = true) -> Dictionary:
	if not HOTSPOT_MOMENTS.has(hotspot_id):
		return {"accepted": false, "reason": "unknown_hotspot"}
	if not live_action.is_empty():
		var phase := str(live_action.get("phase", ""))
		if phase in ["perform", "aftermath"] or not replace_pending:
			return {"accepted": false, "reason": "sequence_busy", "snapshot": get_live_action_snapshot()}
		live_action.clear()
	var requested_moment := super.focus_hotspot(hotspot_id)
	var moment := get_current_moment()
	if moment.is_empty():
		moment = requested_moment
	var actual_hotspot := str(moment.get("hotspot", hotspot_id))
	focused_hotspot = actual_hotspot
	live_action_serial += 1
	_live_idle_elapsed = 0.0
	live_action = {
		"id": "live_%05d" % live_action_serial,
		"source": "xogot" if source == "xogot" else "player",
		"hotspot": actual_hotspot,
		"moment": moment.duplicate(true),
		"selected_lens": selected_lens,
		"choices": _live_choices_for_lens(selected_lens),
		"selected_choice": "",
		"phase": "approach",
		"phase_elapsed": 0.0,
		"phase_duration": float(PHASE_DURATIONS["approach"]),
		"resolved": false,
		"result": {}
	}
	live_action_changed.emit(get_live_action_snapshot())
	return {"accepted": true, "snapshot": get_live_action_snapshot()}

func trigger_autonomous_initiative() -> Dictionary:
	if not live_action.is_empty():
		return {"accepted": false, "reason": "sequence_busy"}
	var moment := get_current_moment()
	var hotspot := str(moment.get("hotspot", focused_hotspot))
	return start_encounter(hotspot, "xogot", false)

func select_lens(lens_id: String) -> Array:
	var options := super.select_lens(lens_id)
	if not live_action.is_empty() and str(live_action.get("phase", "")) in ["approach", "observe", "awaiting_choice"]:
		live_action["selected_lens"] = selected_lens
		live_action["choices"] = _live_choices_for_lens(selected_lens)
		live_action_changed.emit(get_live_action_snapshot())
	return options

func begin_choice_sequence(choice_id: String) -> Dictionary:
	if live_action.is_empty():
		return {"accepted": false, "reason": "no_active_sequence"}
	if str(live_action.get("phase", "")) != "awaiting_choice":
		return {"accepted": false, "reason": "choice_not_open", "phase": live_action.get("phase", "")}
	var available := false
	for choice_variant in live_action.get("choices", []) as Array:
		if choice_variant is Dictionary and str((choice_variant as Dictionary).get("id", "")) == choice_id:
			available = true
			break
	if not available:
		return {"accepted": false, "reason": "choice_not_available"}
	live_action["selected_choice"] = choice_id
	_set_live_phase("perform")
	return {"accepted": true, "pending": true, "snapshot": get_live_action_snapshot()}

func advance_live_action(delta: float) -> Dictionary:
	if live_action.is_empty():
		return get_live_action_snapshot()
	var phase := str(live_action.get("phase", ""))
	if phase == "awaiting_choice":
		return get_live_action_snapshot()
	live_action["phase_elapsed"] = float(live_action.get("phase_elapsed", 0.0)) + maxf(delta, 0.0)
	var duration := float(live_action.get("phase_duration", 0.0))
	if duration <= 0.0 or float(live_action.get("phase_elapsed", 0.0)) < duration:
		live_action_changed.emit(get_live_action_snapshot())
		return get_live_action_snapshot()
	match phase:
		"approach":
			_set_live_phase("observe")
		"observe":
			_set_live_phase("awaiting_choice")
		"perform":
			_complete_perform_phase()
		"aftermath":
			_finish_live_action()
		_:
			_finish_live_action()
	return get_live_action_snapshot()

func export_state() -> Dictionary:
	var data := super.export_state()
	data["live_action_version"] = LIVE_ACTION_VERSION
	data["live_action_serial"] = live_action_serial
	data["completed_live_action_count"] = completed_live_action_count
	data["completed_live_actions"] = completed_live_actions.duplicate(true)
	data["last_live_action_result"] = last_live_action_result.duplicate(true)
	return data

func import_state(data: Dictionary) -> void:
	super.import_state(data)
	live_action_serial = maxi(int(data.get("live_action_serial", 0)), 0)
	completed_live_action_count = maxi(int(data.get("completed_live_action_count", 0)), 0)
	completed_live_actions.clear()
	for item_variant in data.get("completed_live_actions", []):
		if item_variant is Dictionary:
			completed_live_actions.append((item_variant as Dictionary).duplicate(true))
	while completed_live_actions.size() > MAX_COMPLETED_LIVE_ACTIONS:
		completed_live_actions.pop_front()
	last_live_action_result = (data.get("last_live_action_result", {}) as Dictionary).duplicate(true)
	live_action.clear()
	_live_idle_elapsed = 0.0

func reset_state() -> void:
	super.reset_state()
	live_action.clear()
	live_action_serial = 0
	completed_live_action_count = 0
	completed_live_actions.clear()
	last_live_action_result.clear()
	_live_idle_elapsed = 0.0
	save_state()

func _complete_perform_phase() -> void:
	var choice_id := str(live_action.get("selected_choice", ""))
	if choice_id.is_empty():
		_set_live_phase("awaiting_choice")
		return
	var result := super.resolve_choice(choice_id)
	if not bool(result.get("accepted", false)):
		live_action["selected_choice"] = ""
		_set_live_phase("awaiting_choice")
		return
	result["live_action_id"] = str(live_action.get("id", ""))
	result["live_action_source"] = str(live_action.get("source", "player"))
	result["live_action_hotspot"] = str(live_action.get("hotspot", "bitling"))
	result["committed_after_performance"] = true
	live_action["resolved"] = true
	live_action["result"] = result.duplicate(true)
	last_live_action_result = result.duplicate(true)
	completed_live_action_count += 1
	completed_live_actions.append({
		"id": result.get("live_action_id", ""),
		"choice_id": result.get("choice_id", ""),
		"hotspot": result.get("live_action_hotspot", "bitling"),
		"source": result.get("live_action_source", "player"),
		"execution_mode": result.get("execution_mode", "embraced"),
		"world_resolution": result.get("world_resolution", ""),
		"timestamp": int(Time.get_unix_time_from_system())
	})
	while completed_live_actions.size() > MAX_COMPLETED_LIVE_ACTIONS:
		completed_live_actions.pop_front()
	_set_live_phase("aftermath")
	save_state()

func _finish_live_action() -> void:
	var result := (live_action.get("result", {}) as Dictionary).duplicate(true)
	live_action.clear()
	_live_idle_elapsed = 0.0
	live_action_changed.emit(get_live_action_snapshot())
	if not result.is_empty():
		live_action_completed.emit(result)

func _set_live_phase(phase: String) -> void:
	if phase not in LIVE_ACTION_PHASES:
		return
	live_action["phase"] = phase
	live_action["phase_elapsed"] = 0.0
	live_action["phase_duration"] = float(PHASE_DURATIONS.get(phase, 0.0))
	live_action_changed.emit(get_live_action_snapshot())

func _phase_progress() -> float:
	if live_action.is_empty():
		return 0.0
	var phase := str(live_action.get("phase", ""))
	if phase == "awaiting_choice":
		return 1.0
	var duration := float(live_action.get("phase_duration", 0.0))
	if duration <= 0.0:
		return 0.0
	return clampf(float(live_action.get("phase_elapsed", 0.0)) / duration, 0.0, 1.0)

func _live_choices_for_lens(lens_id: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for option_variant in super.get_lens_options(lens_id):
		if not option_variant is Dictionary:
			continue
		var option := option_variant as Dictionary
		result.append({
			"id": str(option.get("id", "")),
			"title": str(option.get("title", "Wählen")),
			"detail": str(option.get("detail", "")),
			"progression_state": str(option.get("progression_state", "fresh")),
			"behavior_label": str(option.get("behavior_label", "OFFEN")),
			"habit_strength": float(option.get("habit_strength", 0.0)),
			"friction": float(option.get("friction", 0.0)),
			"execution_mode": str(option.get("execution_mode", "embraced"))
		})
	return result

func action_for_hotspot(hotspot_id: String) -> String:
	return str(HOTSPOT_ACTIONS.get(hotspot_id, selected_lens))
