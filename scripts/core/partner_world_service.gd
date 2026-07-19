extends Node

## Original clean-room partner-world simulation.
## It turns care, aging, techniques, autonomy and exploration into one persistent loop.

signal care_quality_changed(old_value: float, new_value: float, reason: String)
signal care_strain_recorded(reason: String, total: int)
signal life_stage_changed(old_stage: String, new_stage: String)
signal technique_learned(technique_id: String)
signal autonomous_action_resolved(result: Dictionary)
signal citizen_recruited(citizen_id: String)
signal settlement_rank_changed(old_rank: int, new_rank: int)
signal legacy_seed_created(seed: Dictionary)

const LIVE_TICK_SECONDS := 60.0
const AUTONOMY_INTERVAL_SECONDS := 180.0
const MAX_HISTORY := 80
const LIFE_STAGE_ORDER: Array[String] = ["hatchling", "young", "prime", "wise"]
const LIFE_STAGE_THRESHOLDS: Array[float] = [0.0, 180.0, 900.0, 2400.0]
const SETTLEMENT_RANK_THRESHOLDS: Array[int] = [0, 100, 300, 700, 1400]
const SETTLEMENT_RANK_NAMES: Array[String] = ["SIGNALPOSTEN", "ZUFLUCHT", "GEMEINSCHAFT", "METROPOLE", "KONSTELLATION"]
const FACILITIES_BY_RANK: Array[Array] = [
	["nest"],
	["clinic", "kitchen"],
	["academy", "workshop"],
	["social_hub", "expedition_gate"],
	["legacy_archive", "translation_spire"]
]
const DISCOVERY_RECRUITS: Dictionary = {
	"signal_bridge": {"citizen": "bridgewright_lyra", "xp": 45},
	"echo_archive": {"citizen": "archivist_veo", "xp": 50},
	"glitch_garden": {"citizen": "gardener_miri", "xp": 55},
	"quiet_node": {"citizen": "listener_oro", "xp": 45},
	"loop_storm": {"citizen": "chronologist_nex", "xp": 60}
}
const TECHNIQUE_THRESHOLDS: Dictionary = {
	"signal_dash": 4.0,
	"echo_shield": 5.0,
	"pattern_focus": 4.0,
	"comic_trip": 3.0,
	"care_pulse": 4.0,
	"mentor_chorus": 6.0
}

var age_minutes: float = 0.0
var life_stage: String = "hatchling"
var care_quality: float = 72.0
var care_strain: int = 0
var recovery_chain: int = 0
var generation: int = 1
var legacy_points: float = 0.0
var legacy_archive: Array[Dictionary] = []
var technique_exposure: Dictionary = {}
var learned_techniques: Array[String] = []
var citizens: Array[String] = []
var settlement_xp: int = 0
var settlement_rank: int = 0
var history: Array[Dictionary] = []
var active_need_alerts: Dictionary = {}

var _tick_elapsed: float = 0.0
var _autonomy_elapsed: float = 0.0
var _resolving_autonomy: bool = false

func _ready() -> void:
	var event_bus := get_node_or_null("/root/EventBus")
	if event_bus != null:
		if not event_bus.interaction_completed.is_connected(_on_interaction_completed):
			event_bus.interaction_completed.connect(_on_interaction_completed)
		if not event_bus.need_changed.is_connected(_on_need_changed):
			event_bus.need_changed.connect(_on_need_changed)
	call_deferred("_connect_exploration")
	set_process(true)

func _process(delta: float) -> void:
	var safe_delta := maxf(delta, 0.0)
	_tick_elapsed += safe_delta
	_autonomy_elapsed += safe_delta
	if _tick_elapsed >= LIVE_TICK_SECONDS:
		var elapsed := _tick_elapsed
		_tick_elapsed = 0.0
		advance_time(elapsed, false)
	if _autonomy_elapsed >= AUTONOMY_INTERVAL_SECONDS:
		_autonomy_elapsed = 0.0
		resolve_autonomous_cycle(false)

func advance_time(elapsed_seconds: float, offline: bool = false) -> Dictionary:
	if elapsed_seconds <= 0.0:
		return get_snapshot()
	var capped_seconds := minf(elapsed_seconds, 43200.0) if offline else elapsed_seconds
	var activity_factor := 0.35 if offline else 1.0
	age_minutes += capped_seconds / 60.0 * activity_factor
	legacy_points = clampf(legacy_points + capped_seconds / 3600.0 * (0.25 if offline else 0.7), 0.0, 200.0)
	_update_life_stage()
	return get_snapshot()

func register_care_strain(reason: String, severity: float = 1.0) -> void:
	if reason.is_empty():
		return
	var old_quality := care_quality
	var normalized_severity := clampf(severity, 0.25, 3.0)
	care_strain += maxi(1, int(ceil(normalized_severity)))
	recovery_chain = 0
	care_quality = clampf(care_quality - 5.0 * normalized_severity, 0.0, 100.0)
	_remember("care_strain", {"reason": reason, "severity": normalized_severity})
	care_strain_recorded.emit(reason, care_strain)
	if not is_equal_approx(old_quality, care_quality):
		care_quality_changed.emit(old_quality, care_quality, reason)

func register_care_success(reason: String, strength: float = 1.0) -> void:
	var old_quality := care_quality
	var amount := clampf(strength, 0.1, 4.0)
	recovery_chain += 1
	var recovery_bonus := minf(float(recovery_chain) * 0.12, 1.8)
	care_quality = clampf(care_quality + 1.2 * amount + recovery_bonus, 0.0, 100.0)
	legacy_points = clampf(legacy_points + 0.35 * amount, 0.0, 200.0)
	_remember("care_success", {"reason": reason, "strength": amount})
	if not is_equal_approx(old_quality, care_quality):
		care_quality_changed.emit(old_quality, care_quality, reason)

func observe_technique(technique_id: String, exposure_quality: float = 1.0) -> Dictionary:
	if technique_id.is_empty():
		return {}
	var threshold := float(TECHNIQUE_THRESHOLDS.get(technique_id, 5.0))
	var current := float(technique_exposure.get(technique_id, 0.0))
	var aptitude := 1.0
	var development := get_node_or_null("/root/DevelopmentProfile")
	if development != null and development.has_method("get_snapshot"):
		var profile: Dictionary = development.get_snapshot()
		var attributes: Dictionary = profile.get("attributes", {})
		aptitude = clampf((float(attributes.get("curiosity", 50.0)) + float(attributes.get("coordination", 50.0))) / 100.0, 0.6, 1.6)
	current += clampf(exposure_quality, 0.1, 4.0) * aptitude
	technique_exposure[technique_id] = current
	var learned_now := current >= threshold and not learned_techniques.has(technique_id)
	if learned_now:
		learned_techniques.append(technique_id)
		legacy_points = clampf(legacy_points + 6.0, 0.0, 200.0)
		technique_learned.emit(technique_id)
		_remember("technique_learned", {"id": technique_id})
	return {
		"id": technique_id,
		"exposure": current,
		"threshold": threshold,
		"learned": learned_techniques.has(technique_id),
		"learned_now": learned_now
	}

func register_world_discovery(event_id: String) -> Dictionary:
	if not DISCOVERY_RECRUITS.has(event_id):
		return {"accepted": false, "reason": "unknown_discovery"}
	var entry: Dictionary = DISCOVERY_RECRUITS[event_id]
	var citizen_id := str(entry.get("citizen", ""))
	var xp_reward := maxi(int(entry.get("xp", 0)), 0)
	var recruited_now := false
	if not citizen_id.is_empty() and not citizens.has(citizen_id):
		citizens.append(citizen_id)
		recruited_now = true
		citizen_recruited.emit(citizen_id)
		_remember("citizen_recruited", {"citizen": citizen_id, "event": event_id})
	add_settlement_xp(xp_reward)
	return {
		"accepted": true,
		"event": event_id,
		"citizen": citizen_id,
		"recruited_now": recruited_now,
		"settlement_xp": settlement_xp,
		"settlement_rank": settlement_rank
	}

func add_settlement_xp(amount: int) -> void:
	if amount <= 0:
		return
	var old_rank := settlement_rank
	settlement_xp += amount
	settlement_rank = _rank_for_settlement_xp(settlement_xp)
	if settlement_rank != old_rank:
		settlement_rank_changed.emit(old_rank, settlement_rank)
		_remember("settlement_rank", {"rank": settlement_rank})

func resolve_autonomous_cycle(peer_available: bool = false) -> Dictionary:
	if _resolving_autonomy:
		return {"accepted": false, "reason": "already_resolving"}
	var development := get_node_or_null("/root/DevelopmentProfile")
	var state := get_node_or_null("/root/GameState")
	if development == null or state == null or not development.has_method("choose_autonomous_action"):
		return {"accepted": false, "reason": "runtime_unavailable"}
	if not bool(state.story_flags.get("hatched", false)):
		return {"accepted": false, "reason": "not_hatched"}
	var choice: Dictionary = development.choose_autonomous_action(peer_available)
	var action_id := str(choice.get("id", "wait_for_guidance"))
	var efficiency := clampf(float(choice.get("efficiency", 0.25)), 0.0, 1.0)
	var effects := _autonomous_effects(action_id, efficiency)
	var xp_reward := int(round(4.0 * efficiency))
	_resolving_autonomy = true
	state.perform_interaction("autonomous_%s" % action_id, effects, xp_reward, ["autonomy", action_id])
	_resolving_autonomy = false
	var result := {
		"accepted": true,
		"action": action_id,
		"efficiency": efficiency,
		"effects": effects.duplicate(true),
		"xp": xp_reward
	}
	_remember("autonomous_action", result)
	autonomous_action_resolved.emit(result.duplicate(true))
	return result

func award_legacy_points(amount: float, reason: String = "milestone") -> void:
	if amount <= 0.0:
		return
	legacy_points = clampf(legacy_points + amount, 0.0, 200.0)
	_remember("legacy_points", {"amount": amount, "reason": reason})

func can_create_legacy_seed() -> bool:
	return life_stage == "wise" and legacy_points >= 100.0 and learned_techniques.size() >= 2

func create_legacy_seed() -> Dictionary:
	if not can_create_legacy_seed():
		return {"accepted": false, "reason": "requirements_not_met"}
	var inherited: Array[String] = []
	for technique_id in learned_techniques:
		inherited.append(technique_id)
		if inherited.size() >= 3:
			break
	var seed := {
		"accepted": true,
		"generation": generation,
		"care_quality": care_quality,
		"settlement_rank": settlement_rank,
		"inherited_techniques": inherited,
		"created_at": int(Time.get_unix_time_from_system())
	}
	legacy_archive.append(seed.duplicate(true))
	while legacy_archive.size() > 20:
		legacy_archive.pop_front()
	generation += 1
	age_minutes = 0.0
	life_stage = "hatchling"
	care_strain = 0
	recovery_chain = 0
	care_quality = clampf(50.0 + care_quality * 0.25, 50.0, 78.0)
	legacy_points = 0.0
	technique_exposure.clear()
	learned_techniques = inherited.duplicate()
	_remember("legacy_seed", seed)
	legacy_seed_created.emit(seed.duplicate(true))
	return seed

func get_snapshot() -> Dictionary:
	return {
		"age_minutes": age_minutes,
		"life_stage": life_stage,
		"care_quality": care_quality,
		"care_strain": care_strain,
		"recovery_chain": recovery_chain,
		"generation": generation,
		"legacy_points": legacy_points,
		"legacy_ready": can_create_legacy_seed(),
		"learned_techniques": learned_techniques.duplicate(),
		"technique_exposure": technique_exposure.duplicate(true),
		"citizens": citizens.duplicate(),
		"settlement_xp": settlement_xp,
		"settlement_rank": settlement_rank,
		"settlement_rank_name": get_settlement_rank_name(),
		"facilities": get_unlocked_facilities()
	}

func get_settlement_rank_name() -> String:
	return SETTLEMENT_RANK_NAMES[clampi(settlement_rank, 0, SETTLEMENT_RANK_NAMES.size() - 1)]

func get_unlocked_facilities() -> Array[String]:
	var facilities: Array[String] = []
	for rank_index in range(mini(settlement_rank + 1, FACILITIES_BY_RANK.size())):
		for facility_value in FACILITIES_BY_RANK[rank_index]:
			var facility := str(facility_value)
			if not facilities.has(facility):
				facilities.append(facility)
	return facilities

func export_state() -> Dictionary:
	var data := get_snapshot()
	data["legacy_archive"] = legacy_archive.duplicate(true)
	data["history"] = history.duplicate(true)
	return data

func import_state(data: Dictionary) -> void:
	age_minutes = maxf(float(data.get("age_minutes", 0.0)), 0.0)
	care_quality = clampf(float(data.get("care_quality", 72.0)), 0.0, 100.0)
	care_strain = maxi(int(data.get("care_strain", 0)), 0)
	recovery_chain = maxi(int(data.get("recovery_chain", 0)), 0)
	generation = maxi(int(data.get("generation", 1)), 1)
	legacy_points = clampf(float(data.get("legacy_points", 0.0)), 0.0, 200.0)
	technique_exposure = data.get("technique_exposure", {}).duplicate(true)
	learned_techniques.clear()
	for value in data.get("learned_techniques", []):
		var technique_id := str(value)
		if not technique_id.is_empty() and not learned_techniques.has(technique_id):
			learned_techniques.append(technique_id)
	citizens.clear()
	for value in data.get("citizens", []):
		var citizen_id := str(value)
		if not citizen_id.is_empty() and not citizens.has(citizen_id):
			citizens.append(citizen_id)
	settlement_xp = maxi(int(data.get("settlement_xp", 0)), 0)
	settlement_rank = _rank_for_settlement_xp(settlement_xp)
	legacy_archive.clear()
	for item in data.get("legacy_archive", []):
		if item is Dictionary:
			legacy_archive.append(item.duplicate(true))
	history.clear()
	for item in data.get("history", []):
		if item is Dictionary:
			history.append(item.duplicate(true))
	while history.size() > MAX_HISTORY:
		history.pop_front()
	active_need_alerts.clear()
	_update_life_stage(false)

func reset_state() -> void:
	age_minutes = 0.0
	life_stage = "hatchling"
	care_quality = 72.0
	care_strain = 0
	recovery_chain = 0
	generation = 1
	legacy_points = 0.0
	legacy_archive.clear()
	technique_exposure.clear()
	learned_techniques.clear()
	citizens.clear()
	settlement_xp = 0
	settlement_rank = 0
	history.clear()
	active_need_alerts.clear()
	_tick_elapsed = 0.0
	_autonomy_elapsed = 0.0
	_resolving_autonomy = false

func _connect_exploration() -> void:
	var exploration := get_node_or_null("/root/ExplorationService")
	if exploration != null and not exploration.expedition_completed.is_connected(_on_expedition_completed):
		exploration.expedition_completed.connect(_on_expedition_completed)

func _on_interaction_completed(interaction_id: String, tags: Array[String]) -> void:
	if _resolving_autonomy or interaction_id.begins_with("autonomous_"):
		return
	match interaction_id:
		"feed":
			register_care_success("fed_on_time", 1.3)
			observe_technique("care_pulse", 0.35)
		"care":
			register_care_success("direct_care", 1.6)
			observe_technique("care_pulse", 0.65)
		"rest":
			register_care_success("healthy_rest", 1.1)
		"play":
			observe_technique("comic_trip", 0.8)
			observe_technique("signal_dash", 0.45)
		"learn", "learning_result":
			observe_technique("pattern_focus", 0.75)
		"explore":
			observe_technique("signal_dash", 0.65)
			add_settlement_xp(4)
	for tag in tags:
		if tag == "teaching" or tag == "teach":
			observe_technique("mentor_chorus", 0.8)
		elif tag == "defense":
			observe_technique("echo_shield", 0.8)

func _on_need_changed(need_name: String, old_value: float, new_value: float) -> void:
	if new_value < 15.0 and old_value >= 15.0 and not bool(active_need_alerts.get(need_name, false)):
		active_need_alerts[need_name] = true
		register_care_strain("critical_%s" % need_name, 1.0)
	elif new_value >= 35.0 and bool(active_need_alerts.get(need_name, false)):
		active_need_alerts.erase(need_name)
		register_care_success("recovered_%s" % need_name, 0.8)

func _on_expedition_completed(summary: Dictionary) -> void:
	for value in summary.get("discovered_events", []):
		register_world_discovery(str(value))
	award_legacy_points(4.0, "expedition")

func _autonomous_effects(action_id: String, efficiency: float) -> Dictionary:
	match action_id:
		"practice_hobby":
			return {"happiness": 2.5 * efficiency, "curiosity": 1.5 * efficiency}
		"self_care":
			return {"hunger": 3.0 * efficiency, "energy": 4.0 * efficiency, "health": 1.0 * efficiency}
		"invent_game":
			return {"happiness": 4.0 * efficiency, "energy": -2.0 * efficiency, "curiosity": 2.0 * efficiency}
		"study":
			return {"curiosity": 4.5 * efficiency, "energy": -2.5 * efficiency}
		"teach_peer":
			return {"happiness": 3.0 * efficiency, "curiosity": 2.0 * efficiency}
		_:
			return {"happiness": 0.5 * efficiency}

func _update_life_stage(emit_signal: bool = true) -> void:
	var new_stage := LIFE_STAGE_ORDER[0]
	for index in range(LIFE_STAGE_THRESHOLDS.size() - 1, -1, -1):
		if age_minutes >= LIFE_STAGE_THRESHOLDS[index]:
			new_stage = LIFE_STAGE_ORDER[index]
			break
	if new_stage == life_stage:
		return
	var old_stage := life_stage
	life_stage = new_stage
	_remember("life_stage", {"from": old_stage, "to": new_stage})
	if emit_signal:
		life_stage_changed.emit(old_stage, new_stage)

func _rank_for_settlement_xp(value: int) -> int:
	var rank := 0
	for index in range(SETTLEMENT_RANK_THRESHOLDS.size() - 1, -1, -1):
		if value >= SETTLEMENT_RANK_THRESHOLDS[index]:
			rank = index
			break
	return rank

func _remember(event_type: String, payload: Dictionary) -> void:
	history.append({
		"type": event_type,
		"payload": payload.duplicate(true),
		"timestamp": int(Time.get_unix_time_from_system()),
		"generation": generation
	})
	while history.size() > MAX_HISTORY:
		history.pop_front()
