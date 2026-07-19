extends Node

## Wave 4 authoritative settlement exploration. It adds a navigable district graph,
## residents, mentors, secrets, expeditions and generation-dependent world effects
## without duplicating the existing PartnerWorld care/evolution state.

signal settlement_changed(snapshot: Dictionary)
signal district_changed(previous_id: String, current_id: String, route: Array[String])
signal encounter_resolved(result: Dictionary)
signal mentor_session_completed(result: Dictionary)
signal secret_progressed(result: Dictionary)
signal expedition_changed(snapshot: Dictionary)
signal world_consequences_changed(consequences: Dictionary)

const SAVE_VERSION := 1
const SAVE_PATH := "user://signal_settlement.json"
const TEMP_PATH := "user://signal_settlement.tmp"
const BACKUP_PATH := "user://signal_settlement.backup.json"
const MAX_HISTORY := 100

const DISTRICTS: Dictionary = {
	"signal_plaza": {
		"label": "Signalplatz",
		"position": Vector2(0.50, 0.52),
		"neighbors": ["academy_quarter", "garden_terraces", "workshop_docks"],
		"rank": 0,
		"ambience": "SETTLEMENT",
		"description": "Das Herz der Siedlung. Hier kreuzen sich Nachrichten, Bewohner und neue Möglichkeiten.",
		"facility": "social_hub"
	},
	"academy_quarter": {
		"label": "Musterakademie",
		"position": Vector2(0.28, 0.28),
		"neighbors": ["signal_plaza", "echo_archive"],
		"rank": 0,
		"ambience": "LEARNING",
		"description": "Schwebende Tafeln und Resonanzräume machen Wissen sichtbar und hörbar.",
		"facility": "academy"
	},
	"garden_terraces": {
		"label": "Gartenterrassen",
		"position": Vector2(0.72, 0.30),
		"neighbors": ["signal_plaza", "echo_archive", "expedition_gate"],
		"rank": 0,
		"ambience": "GARDENS",
		"description": "Biolumineszente Pflanzen reagieren auf Fürsorge, Wetter und die Stimmung der Siedlung.",
		"facility": "clinic"
	},
	"workshop_docks": {
		"label": "Werkstattdocks",
		"position": Vector2(0.24, 0.72),
		"neighbors": ["signal_plaza", "expedition_gate"],
		"rank": 1,
		"ambience": "FOUNDRY",
		"description": "Hier werden Expeditionsgeräte, Brücken und kleine Wunder aus Licht gebaut.",
		"facility": "workshop"
	},
	"echo_archive": {
		"label": "Echoarchiv",
		"position": Vector2(0.76, 0.70),
		"neighbors": ["academy_quarter", "garden_terraces", "expedition_gate"],
		"rank": 1,
		"ambience": "ARCHIVE",
		"description": "Erinnerungen früherer Generationen bilden ein lebendiges, aber nicht immer zuverlässiges Archiv.",
		"facility": "legacy_archive"
	},
	"expedition_gate": {
		"label": "Expeditionstor",
		"position": Vector2(0.50, 0.88),
		"neighbors": ["garden_terraces", "workshop_docks", "echo_archive"],
		"rank": 2,
		"ambience": "EXPEDITION",
		"description": "Das Tor verbindet die Signalsiedlung mit gefährlichen, lehrreichen Außenregionen.",
		"facility": "expedition_gate"
	}
}

const CITIZENS: Dictionary = {
	"mentor_sora": {"name": "Sora", "role": "Mustermentorin", "district": "academy_quarter", "rank": 0, "technique": "pattern_focus", "native": true},
	"medic_aro": {"name": "Aro", "role": "Regenerationshüter", "district": "garden_terraces", "rank": 0, "technique": "care_pulse", "native": true},
	"courier_zen": {"name": "Zen", "role": "Signalbote", "district": "signal_plaza", "rank": 0, "technique": "signal_dash", "native": true},
	"artist_lum": {"name": "Lum", "role": "Lichtkünstlerin", "district": "signal_plaza", "rank": 1, "technique": "comic_trip", "native": true},
	"engineer_kai": {"name": "Kai", "role": "Resonanzingenieur", "district": "workshop_docks", "rank": 1, "technique": "echo_shield", "native": true},
	"scout_iri": {"name": "Iri", "role": "Grenzpfadfinderin", "district": "expedition_gate", "rank": 2, "technique": "signal_dash", "native": true},
	"bridgewright_lyra": {"name": "Lyra", "role": "Brückenbauerin", "district": "workshop_docks", "rank": 0, "technique": "echo_shield", "native": false},
	"archivist_veo": {"name": "Veo", "role": "Echoarchivar", "district": "echo_archive", "rank": 0, "technique": "mentor_chorus", "native": false},
	"gardener_miri": {"name": "Miri", "role": "Glitchgärtnerin", "district": "garden_terraces", "rank": 0, "technique": "care_pulse", "native": false},
	"listener_oro": {"name": "Oro", "role": "Stillhörer", "district": "echo_archive", "rank": 0, "technique": "pattern_focus", "native": false},
	"chronologist_nex": {"name": "Nex", "role": "Schleifenchronologe", "district": "academy_quarter", "rank": 0, "technique": "mentor_chorus", "native": false},
	"cook_numa": {"name": "Numa", "role": "Signalköchin", "district": "signal_plaza", "rank": 2, "technique": "care_pulse", "native": true}
}

const SECRETS: Dictionary = {
	"broken_constellation": {"label": "Die gebrochene Konstellation", "district": "signal_plaza", "stages": 3, "reward_xp": 80, "reward_legacy": 8.0},
	"garden_whisper": {"label": "Das Flüstern unter den Wurzeln", "district": "garden_terraces", "stages": 3, "reward_xp": 90, "reward_legacy": 10.0},
	"archive_afterimage": {"label": "Das Nachbild im Archiv", "district": "echo_archive", "stages": 4, "reward_xp": 120, "reward_legacy": 14.0},
	"foundry_heartbeat": {"label": "Der Herzschlag der Werkstatt", "district": "workshop_docks", "stages": 4, "reward_xp": 130, "reward_legacy": 15.0}
}

const EXPEDITIONS: Dictionary = {
	"prismatic_rooftops": {"label": "Prismatische Dachgärten", "rank": 0, "steps": 3, "technique": "signal_dash", "discovery": "signal_bridge", "xp": 65, "risk": "niedrig"},
	"echo_marsh": {"label": "Echosumpf", "rank": 1, "steps": 4, "technique": "echo_shield", "discovery": "quiet_node", "xp": 95, "risk": "mittel"},
	"aurora_foundry": {"label": "Auroragießerei", "rank": 2, "steps": 5, "technique": "pattern_focus", "discovery": "glitch_garden", "xp": 130, "risk": "hoch"},
	"quiet_orbit": {"label": "Stiller Orbit", "rank": 3, "steps": 6, "technique": "mentor_chorus", "discovery": "echo_archive", "xp": 180, "risk": "legendär"}
}

var current_district := "signal_plaza"
var district_visits: Dictionary = {"signal_plaza": 1}
var district_mastery: Dictionary = {}
var mentor_bonds: Dictionary = {}
var secret_progress: Dictionary = {}
var completed_secrets: Array[String] = []
var completed_encounters: Array[String] = []
var expedition_records: Dictionary = {}
var active_expedition: Dictionary = {}
var world_flags: Dictionary = {}
var history: Array[Dictionary] = []
var last_encounter: Dictionary = {}

func _ready() -> void:
	load_state()
	call_deferred("_connect_partner_world")
	call_deferred("_refresh_world_consequences")

func get_snapshot() -> Dictionary:
	var partner := _partner_snapshot()
	return {
		"current_district": current_district,
		"current_district_data": get_district_data(current_district),
		"districts": get_map_districts(),
		"district_visits": district_visits.duplicate(true),
		"district_mastery": district_mastery.duplicate(true),
		"mentor_bonds": mentor_bonds.duplicate(true),
		"visible_citizens": get_visible_citizens(),
		"secret_progress": secret_progress.duplicate(true),
		"completed_secrets": completed_secrets.duplicate(),
		"expeditions": get_expedition_catalog(),
		"active_expedition": active_expedition.duplicate(true),
		"expedition_records": expedition_records.duplicate(true),
		"world_flags": world_flags.duplicate(true),
		"last_encounter": last_encounter.duplicate(true),
		"settlement_rank": int(partner.get("settlement_rank", 0)),
		"settlement_rank_name": str(partner.get("settlement_rank_name", "SIGNALPOSTEN")),
		"generation": int(partner.get("generation", 1)),
		"citizen_count": get_visible_citizens().size()
	}

func get_map_districts() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var rank := _settlement_rank()
	for district_id_variant in DISTRICTS.keys():
		var district_id := str(district_id_variant)
		var data: Dictionary = DISTRICTS[district_id]
		var position: Vector2 = data.get("position", Vector2.ZERO)
		result.append({
			"id": district_id,
			"label": str(data.get("label", district_id.capitalize())),
			"position": [position.x, position.y],
			"neighbors": (data.get("neighbors", []) as Array).duplicate(),
			"rank": int(data.get("rank", 0)),
			"unlocked": rank >= int(data.get("rank", 0)),
			"description": str(data.get("description", "")),
			"ambience": str(data.get("ambience", "SETTLEMENT")),
			"facility": str(data.get("facility", "")),
			"visits": int(district_visits.get(district_id, 0)),
			"mastery": float(district_mastery.get(district_id, 0.0))
		})
	return result

func get_district_data(district_id: String) -> Dictionary:
	if not DISTRICTS.has(district_id):
		return {}
	var data: Dictionary = (DISTRICTS[district_id] as Dictionary).duplicate(true)
	var position: Vector2 = data.get("position", Vector2.ZERO)
	data["id"] = district_id
	data["position"] = [position.x, position.y]
	data["unlocked"] = _settlement_rank() >= int(data.get("rank", 0))
	data["citizens"] = get_citizens_in_district(district_id)
	return data

func travel_to(district_id: String) -> Dictionary:
	if not DISTRICTS.has(district_id):
		return {"accepted": false, "reason": "unknown_district"}
	var target: Dictionary = DISTRICTS[district_id]
	if _settlement_rank() < int(target.get("rank", 0)):
		return {"accepted": false, "reason": "district_locked", "required_rank": int(target.get("rank", 0))}
	var route := _find_route(current_district, district_id)
	if route.is_empty():
		return {"accepted": false, "reason": "no_route"}
	var previous := current_district
	current_district = district_id
	district_visits[district_id] = int(district_visits.get(district_id, 0)) + 1
	district_mastery[district_id] = clampf(float(district_mastery.get(district_id, 0.0)) + 3.0, 0.0, 100.0)
	if int(district_visits[district_id]) == 1:
		_award_settlement_xp(10)
	last_encounter = _generate_arrival_encounter(district_id)
	_remember("travel", {"from": previous, "to": district_id, "route": route, "encounter": last_encounter})
	district_changed.emit(previous, current_district, route)
	if not last_encounter.is_empty():
		encounter_resolved.emit(last_encounter.duplicate(true))
	_refresh_world_consequences()
	save_state()
	_emit_changed()
	return {"accepted": true, "from": previous, "to": district_id, "route": route, "encounter": last_encounter.duplicate(true)}

func investigate_current_district() -> Dictionary:
	var secret_id := _secret_for_district(current_district)
	if secret_id.is_empty():
		var result := {"accepted": true, "completed": false, "message": "Keine verborgene Signatur reagiert an diesem Ort."}
		last_encounter = result
		encounter_resolved.emit(result.duplicate(true))
		return result
	var secret: Dictionary = SECRETS[secret_id]
	var current := int(secret_progress.get(secret_id, 0))
	var required := int(secret.get("stages", 3))
	if completed_secrets.has(secret_id):
		return {"accepted": false, "reason": "secret_complete", "secret": secret_id}
	current += 1
	secret_progress[secret_id] = current
	var completed := current >= required
	if completed:
		completed_secrets.append(secret_id)
		_award_settlement_xp(int(secret.get("reward_xp", 60)))
		var partner := get_node_or_null("/root/PartnerWorld")
		if partner != null and partner.has_method("award_legacy_points"):
			partner.call("award_legacy_points", float(secret.get("reward_legacy", 6.0)), "settlement_secret")
	var result := {
		"accepted": true,
		"secret": secret_id,
		"label": str(secret.get("label", secret_id)),
		"stage": current,
		"stages": required,
		"completed": completed
	}
	last_encounter = result.duplicate(true)
	_remember("secret", result)
	secret_progressed.emit(result.duplicate(true))
	_refresh_world_consequences()
	save_state()
	_emit_changed()
	return result

func train_with_mentor(citizen_id: String) -> Dictionary:
	if not CITIZENS.has(citizen_id):
		return {"accepted": false, "reason": "unknown_mentor"}
	var citizen: Dictionary = CITIZENS[citizen_id]
	if str(citizen.get("district", "")) != current_district:
		return {"accepted": false, "reason": "mentor_elsewhere"}
	if not _citizen_is_visible(citizen_id, citizen):
		return {"accepted": false, "reason": "mentor_unavailable"}
	var technique := str(citizen.get("technique", "pattern_focus"))
	var bond := float(mentor_bonds.get(citizen_id, 0.0))
	var quality := 0.75 + minf(bond * 0.025, 1.35)
	var partner := get_node_or_null("/root/PartnerWorld")
	var technique_result: Dictionary = {}
	if partner != null and partner.has_method("observe_technique"):
		technique_result = partner.call("observe_technique", technique, quality)
	bond = clampf(bond + 8.0, 0.0, 100.0)
	mentor_bonds[citizen_id] = bond
	district_mastery[current_district] = clampf(float(district_mastery.get(current_district, 0.0)) + 5.0, 0.0, 100.0)
	var result := {
		"accepted": true,
		"mentor": citizen_id,
		"mentor_name": str(citizen.get("name", citizen_id)),
		"technique": technique,
		"bond": bond,
		"technique_result": technique_result
	}
	_remember("mentor", result)
	mentor_session_completed.emit(result.duplicate(true))
	save_state()
	_emit_changed()
	return result

func start_expedition(region_id: String) -> Dictionary:
	if not EXPEDITIONS.has(region_id):
		return {"accepted": false, "reason": "unknown_region"}
	if not active_expedition.is_empty():
		return {"accepted": false, "reason": "expedition_active"}
	if current_district != "expedition_gate":
		return {"accepted": false, "reason": "travel_to_gate"}
	var data: Dictionary = EXPEDITIONS[region_id]
	if _settlement_rank() < int(data.get("rank", 0)):
		return {"accepted": false, "reason": "region_locked", "required_rank": int(data.get("rank", 0))}
	active_expedition = {
		"id": region_id,
		"label": str(data.get("label", region_id.capitalize())),
		"progress": 0,
		"steps": int(data.get("steps", 3)),
		"score": 0.0,
		"choices": [],
		"recommended_technique": str(data.get("technique", "")),
		"started_at": int(Time.get_unix_time_from_system())
	}
	_remember("expedition_started", active_expedition)
	expedition_changed.emit(active_expedition.duplicate(true))
	save_state()
	_emit_changed()
	return {"accepted": true, "expedition": active_expedition.duplicate(true)}

func advance_expedition(choice: String) -> Dictionary:
	if active_expedition.is_empty():
		return {"accepted": false, "reason": "no_active_expedition"}
	var normalized := choice.strip_edges().to_lower()
	if normalized not in ["observe", "assist", "experiment", "rest"]:
		return {"accepted": false, "reason": "invalid_choice"}
	var region_id := str(active_expedition.get("id", ""))
	var data: Dictionary = EXPEDITIONS.get(region_id, {})
	var recommended := str(data.get("technique", ""))
	var technique_bonus := 0.0
	var partner_snapshot := _partner_snapshot()
	if (partner_snapshot.get("learned_techniques", []) as Array).has(recommended):
		technique_bonus = 0.30
	var choice_quality := {"observe": 0.82, "assist": 0.88, "experiment": 0.92, "rest": 0.68}.get(normalized, 0.70)
	var step_score := clampf(float(choice_quality) + technique_bonus, 0.0, 1.25)
	active_expedition["progress"] = int(active_expedition.get("progress", 0)) + 1
	active_expedition["score"] = float(active_expedition.get("score", 0.0)) + step_score
	(active_expedition.get("choices", []) as Array).append(normalized)
	var completed := int(active_expedition.get("progress", 0)) >= int(active_expedition.get("steps", 1))
	var result := {
		"accepted": true,
		"region": region_id,
		"choice": normalized,
		"step_score": step_score,
		"progress": int(active_expedition.get("progress", 0)),
		"steps": int(active_expedition.get("steps", 1)),
		"completed": completed
	}
	if completed:
		var final_score := float(active_expedition.get("score", 0.0)) / maxf(float(active_expedition.get("steps", 1)), 1.0)
		var record := {
			"completed": true,
			"score": final_score,
			"completed_at": int(Time.get_unix_time_from_system()),
			"choices": (active_expedition.get("choices", []) as Array).duplicate()
		}
		expedition_records[region_id] = record
		_award_settlement_xp(int(data.get("xp", 60)))
		var partner := get_node_or_null("/root/PartnerWorld")
		if partner != null and partner.has_method("register_world_discovery"):
			result["discovery"] = partner.call("register_world_discovery", str(data.get("discovery", "")))
		result["final_score"] = final_score
		active_expedition.clear()
		_refresh_world_consequences()
	_remember("expedition_step", result)
	expedition_changed.emit(active_expedition.duplicate(true))
	save_state()
	_emit_changed()
	return result

func get_visible_citizens() -> Array[Dictionary]:
	var citizens: Array[Dictionary] = []
	for citizen_id_variant in CITIZENS.keys():
		var citizen_id := str(citizen_id_variant)
		var data: Dictionary = CITIZENS[citizen_id]
		if not _citizen_is_visible(citizen_id, data):
			continue
		var entry := data.duplicate(true)
		entry["id"] = citizen_id
		entry["bond"] = float(mentor_bonds.get(citizen_id, 0.0))
		citizens.append(entry)
	return citizens

func get_citizens_in_district(district_id: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for citizen in get_visible_citizens():
		if str(citizen.get("district", "")) == district_id:
			result.append(citizen)
	return result

func get_expedition_catalog() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var rank := _settlement_rank()
	for region_id_variant in EXPEDITIONS.keys():
		var region_id := str(region_id_variant)
		var data: Dictionary = (EXPEDITIONS[region_id] as Dictionary).duplicate(true)
		data["id"] = region_id
		data["unlocked"] = rank >= int(data.get("rank", 0))
		data["record"] = (expedition_records.get(region_id, {}) as Dictionary).duplicate(true)
		result.append(data)
	return result

func export_state() -> Dictionary:
	return {
		"version": SAVE_VERSION,
		"current_district": current_district,
		"district_visits": district_visits.duplicate(true),
		"district_mastery": district_mastery.duplicate(true),
		"mentor_bonds": mentor_bonds.duplicate(true),
		"secret_progress": secret_progress.duplicate(true),
		"completed_secrets": completed_secrets.duplicate(),
		"completed_encounters": completed_encounters.duplicate(),
		"expedition_records": expedition_records.duplicate(true),
		"active_expedition": active_expedition.duplicate(true),
		"world_flags": world_flags.duplicate(true),
		"history": history.duplicate(true),
		"last_encounter": last_encounter.duplicate(true)
	}

func import_state(data: Dictionary) -> void:
	current_district = str(data.get("current_district", "signal_plaza"))
	if not DISTRICTS.has(current_district):
		current_district = "signal_plaza"
	district_visits = (data.get("district_visits", {"signal_plaza": 1}) as Dictionary).duplicate(true)
	district_mastery = (data.get("district_mastery", {}) as Dictionary).duplicate(true)
	mentor_bonds = (data.get("mentor_bonds", {}) as Dictionary).duplicate(true)
	secret_progress = (data.get("secret_progress", {}) as Dictionary).duplicate(true)
	completed_secrets = _string_array(data.get("completed_secrets", []))
	completed_encounters = _string_array(data.get("completed_encounters", []))
	expedition_records = (data.get("expedition_records", {}) as Dictionary).duplicate(true)
	active_expedition = (data.get("active_expedition", {}) as Dictionary).duplicate(true)
	world_flags = (data.get("world_flags", {}) as Dictionary).duplicate(true)
	history = _dictionary_array(data.get("history", []), MAX_HISTORY)
	last_encounter = (data.get("last_encounter", {}) as Dictionary).duplicate(true)
	_refresh_world_consequences()
	_emit_changed()

func reset_state() -> void:
	current_district = "signal_plaza"
	district_visits = {"signal_plaza": 1}
	district_mastery.clear()
	mentor_bonds.clear()
	secret_progress.clear()
	completed_secrets.clear()
	completed_encounters.clear()
	expedition_records.clear()
	active_expedition.clear()
	world_flags.clear()
	history.clear()
	last_encounter.clear()
	for path in [SAVE_PATH, TEMP_PATH, BACKUP_PATH]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)
	_refresh_world_consequences()
	_emit_changed()

func save_state() -> bool:
	var payload := export_state()
	payload["saved_at"] = int(Time.get_unix_time_from_system())
	var file := FileAccess.open(TEMP_PATH, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(payload))
	file.close()
	if FileAccess.file_exists(SAVE_PATH) and not _read_payload(SAVE_PATH).is_empty():
		_copy_file(SAVE_PATH, BACKUP_PATH)
	if FileAccess.file_exists(SAVE_PATH):
		var remove_error := DirAccess.remove_absolute(SAVE_PATH)
		if remove_error != OK:
			return false
	var rename_error := DirAccess.rename_absolute(TEMP_PATH, SAVE_PATH)
	if rename_error != OK:
		if FileAccess.file_exists(BACKUP_PATH):
			_copy_file(BACKUP_PATH, SAVE_PATH)
		return false
	return true

func load_state() -> bool:
	for path in [SAVE_PATH, BACKUP_PATH]:
		var payload := _read_payload(path)
		if payload.is_empty():
			continue
		import_state(payload)
		return true
	return false

func _connect_partner_world() -> void:
	var partner := get_node_or_null("/root/PartnerWorld")
	if partner == null:
		return
	for signal_name in ["citizen_recruited", "settlement_rank_changed", "legacy_seed_created"]:
		if partner.has_signal(signal_name):
			var callback := Callable(self, "_on_partner_world_changed")
			if not partner.is_connected(signal_name, callback):
				partner.connect(signal_name, callback)

func _on_partner_world_changed(_a: Variant = null, _b: Variant = null) -> void:
	_refresh_world_consequences()
	save_state()
	_emit_changed()

func _find_route(from_id: String, to_id: String) -> Array[String]:
	if from_id == to_id:
		return [from_id]
	var queue: Array[String] = [from_id]
	var previous: Dictionary = {from_id: ""}
	while not queue.is_empty():
		var current := queue.pop_front()
		var neighbors: Array = (DISTRICTS.get(current, {}) as Dictionary).get("neighbors", [])
		for neighbor_variant in neighbors:
			var neighbor := str(neighbor_variant)
			if previous.has(neighbor):
				continue
			if _settlement_rank() < int((DISTRICTS.get(neighbor, {}) as Dictionary).get("rank", 0)):
				continue
			previous[neighbor] = current
			if neighbor == to_id:
				var route: Array[String] = [to_id]
				var cursor := current
				while not cursor.is_empty():
					route.push_front(cursor)
					cursor = str(previous.get(cursor, ""))
				return route
			queue.append(neighbor)
	return []

func _generate_arrival_encounter(district_id: String) -> Dictionary:
	var visit := int(district_visits.get(district_id, 1))
	var citizens := get_citizens_in_district(district_id)
	if not citizens.is_empty() and visit % 3 == 0:
		var citizen: Dictionary = citizens[(visit / 3) % citizens.size()]
		return {"type": "citizen", "citizen": str(citizen.get("id", "")), "name": str(citizen.get("name", "")), "message": "%s wartet mit einer neuen Beobachtung." % str(citizen.get("name", "Jemand"))}
	var secret_id := _secret_for_district(district_id)
	if not secret_id.is_empty() and not completed_secrets.has(secret_id) and visit % 2 == 0:
		return {"type": "secret", "secret": secret_id, "message": "Eine verborgene Resonanz reagiert auf euren Besuch."}
	return {"type": "world", "message": "Der Bezirk verändert sich durch eure Anwesenheit.", "mastery": float(district_mastery.get(district_id, 0.0))}

func _secret_for_district(district_id: String) -> String:
	for secret_id_variant in SECRETS.keys():
		var secret_id := str(secret_id_variant)
		if str((SECRETS[secret_id] as Dictionary).get("district", "")) == district_id:
			return secret_id
	return ""

func _citizen_is_visible(citizen_id: String, data: Dictionary) -> bool:
	if _settlement_rank() < int(data.get("rank", 0)):
		return false
	if bool(data.get("native", false)):
		return true
	return (_partner_snapshot().get("citizens", []) as Array).has(citizen_id)

func _refresh_world_consequences() -> void:
	var partner := _partner_snapshot()
	var rank := int(partner.get("settlement_rank", 0))
	var generation := int(partner.get("generation", 1))
	var next_flags := {
		"sky_lanes": rank >= 2,
		"mentor_network": rank >= 2 and mentor_bonds.size() >= 3,
		"legacy_statues": generation >= 2,
		"archive_constellation": completed_secrets.size() >= 2,
		"expedition_beacons": expedition_records.size() >= 2,
		"world_mood": "AWAKENING" if rank <= 1 else "THRIVING" if rank <= 3 else "CONSTELLATION"
	}
	if next_flags != world_flags:
		world_flags = next_flags
		world_consequences_changed.emit(world_flags.duplicate(true))

func _partner_snapshot() -> Dictionary:
	var partner := get_node_or_null("/root/PartnerWorld")
	if partner != null and partner.has_method("get_snapshot"):
		return partner.call("get_snapshot") as Dictionary
	return {}

func _settlement_rank() -> int:
	return int(_partner_snapshot().get("settlement_rank", 0))

func _award_settlement_xp(amount: int) -> void:
	var partner := get_node_or_null("/root/PartnerWorld")
	if partner != null and partner.has_method("add_settlement_xp"):
		partner.call("add_settlement_xp", amount)

func _remember(event_type: String, data: Dictionary) -> void:
	history.append({"type": event_type, "data": data.duplicate(true), "at": int(Time.get_unix_time_from_system())})
	while history.size() > MAX_HISTORY:
		history.pop_front()

func _emit_changed() -> void:
	settlement_changed.emit(get_snapshot())

func _read_payload(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if not parsed is Dictionary:
		return {}
	var payload := parsed as Dictionary
	return payload if int(payload.get("version", 0)) > 0 else {}

func _copy_file(source: String, target: String) -> bool:
	var source_file := FileAccess.open(source, FileAccess.READ)
	if source_file == null:
		return false
	var bytes := source_file.get_buffer(source_file.get_length())
	source_file.close()
	var target_file := FileAccess.open(target, FileAccess.WRITE)
	if target_file == null:
		return false
	target_file.store_buffer(bytes)
	target_file.close()
	return true

func _string_array(value: Variant) -> Array[String]:
	var result: Array[String] = []
	if value is Array:
		for entry in value:
			result.append(str(entry))
	return result

func _dictionary_array(value: Variant, limit: int) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if value is Array:
		for entry in value:
			if entry is Dictionary:
				result.append((entry as Dictionary).duplicate(true))
	while result.size() > limit:
		result.pop_front()
	return result
