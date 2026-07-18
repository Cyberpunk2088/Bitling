extends Node

## Consent-based fictional lineage and egg system.
## Reproduction is represented as a non-sexual resonance bond between mature Bitlings.

signal egg_created(egg: Dictionary)
signal egg_progressed(egg_id: String, progress: float)
signal egg_ready_to_hatch(egg_id: String)
signal egg_hatched(egg: Dictionary, hatchling_profile: Dictionary)

const MATURE_PHASES: Array[String] = ["ADULT", "SENIOR", "LEGENDARY"]
const MIN_RELATIONSHIP := 45.0
const MIN_TRUST := 45.0
const EGG_COOLDOWN_SECONDS := 86400

var eggs: Array[Dictionary] = []
var lineage_history: Array[Dictionary] = []
var last_egg_created_at: int = 0

func build_local_breeding_profile() -> Dictionary:
	var identity := get_node_or_null("/root/BitlingIdentity")
	var brain := get_node_or_null("/root/CompanionBrain")
	var state := get_node_or_null("/root/GameState")
	if identity == null or brain == null or state == null:
		return {}
	var passport: Dictionary = identity.get_public_passport()
	return {
		"bitling_id": passport.get("bitling_id", ""),
		"display_name": passport.get("display_name", "Bitling"),
		"generation": int(passport.get("generation", 1)),
		"phase": str(state.Phase.keys()[state.phase]),
		"form_id": str(passport.get("form_id", "signal")),
		"relationship": float(brain.relationship_score),
		"trust": float(brain.trust),
		"personality": brain.personality.duplicate(true)
	}

func validate_pairing(local_profile: Dictionary, remote_profile: Dictionary, consent_record: Dictionary) -> Dictionary:
	if not bool(consent_record.get("local", false)) or not bool(consent_record.get("remote", false)):
		return {"accepted": false, "reason": "mutual_consent_required"}
	if str(consent_record.get("session_id", "")).is_empty():
		return {"accepted": false, "reason": "verified_social_session_required"}
	var local_id := str(local_profile.get("bitling_id", ""))
	var remote_id := str(remote_profile.get("bitling_id", ""))
	if local_id.is_empty() or remote_id.is_empty() or local_id == remote_id:
		return {"accepted": false, "reason": "distinct_parent_ids_required"}
	if not MATURE_PHASES.has(str(local_profile.get("phase", ""))):
		return {"accepted": false, "reason": "local_bitling_not_mature"}
	if not MATURE_PHASES.has(str(remote_profile.get("phase", ""))):
		return {"accepted": false, "reason": "remote_bitling_not_mature"}
	if float(local_profile.get("relationship", 0.0)) < MIN_RELATIONSHIP:
		return {"accepted": false, "reason": "local_relationship_too_low"}
	if float(remote_profile.get("relationship", 0.0)) < MIN_RELATIONSHIP:
		return {"accepted": false, "reason": "remote_relationship_too_low"}
	if float(local_profile.get("trust", 0.0)) < MIN_TRUST or float(remote_profile.get("trust", 0.0)) < MIN_TRUST:
		return {"accepted": false, "reason": "mutual_trust_too_low"}
	var now := int(Time.get_unix_time_from_system())
	if last_egg_created_at > 0 and now - last_egg_created_at < EGG_COOLDOWN_SECONDS:
		return {"accepted": false, "reason": "lineage_cooldown_active"}
	return {"accepted": true}

func create_resonance_egg(remote_profile: Dictionary, consent_record: Dictionary) -> Dictionary:
	var local_profile := build_local_breeding_profile()
	var validation := validate_pairing(local_profile, remote_profile, consent_record)
	if not bool(validation.get("accepted", false)):
		return validation
	var parent_ids: Array[String] = [
		str(local_profile.get("bitling_id", "")),
		str(remote_profile.get("bitling_id", ""))
	]
	parent_ids.sort()
	var egg_seed := hash("%s:%s:%s" % [parent_ids[0], parent_ids[1], consent_record.get("session_id", "")])
	var egg := {
		"accepted": true,
		"egg_id": _new_egg_id(egg_seed),
		"created_at": int(Time.get_unix_time_from_system()),
		"generation": maxi(int(local_profile.get("generation", 1)), int(remote_profile.get("generation", 1))) + 1,
		"parent_ids": parent_ids,
		"parent_names": [local_profile.get("display_name", "Bitling"), remote_profile.get("display_name", "Bitling")],
		"genome": _blend_genome(local_profile, remote_profile, egg_seed),
		"incubation": 0.0,
		"ready": false,
		"hatched": false,
		"origin_session": str(consent_record.get("session_id", ""))
	}
	eggs.append(egg)
	last_egg_created_at = int(egg.get("created_at", 0))
	lineage_history.append({
		"event": "egg_created",
		"egg_id": egg.get("egg_id", ""),
		"timestamp": last_egg_created_at
	})
	egg_created.emit(egg.duplicate(true))
	return egg.duplicate(true)

func nurture_egg(egg_id: String, amount: float) -> Dictionary:
	var index := _find_egg_index(egg_id)
	if index < 0:
		return {"accepted": false, "reason": "egg_not_found"}
	var egg: Dictionary = eggs[index]
	if bool(egg.get("hatched", false)):
		return {"accepted": false, "reason": "egg_already_hatched"}
	var old_progress := float(egg.get("incubation", 0.0))
	var new_progress := clampf(old_progress + clampf(amount, 0.0, 25.0), 0.0, 100.0)
	egg["incubation"] = new_progress
	if new_progress >= 100.0 and not bool(egg.get("ready", false)):
		egg["ready"] = true
		egg_ready_to_hatch.emit(egg_id)
	eggs[index] = egg
	egg_progressed.emit(egg_id, new_progress)
	return {"accepted": true, "egg": egg.duplicate(true)}

func hatch_egg(egg_id: String, display_name: String = "") -> Dictionary:
	var index := _find_egg_index(egg_id)
	if index < 0:
		return {"accepted": false, "reason": "egg_not_found"}
	var egg: Dictionary = eggs[index]
	if not bool(egg.get("ready", false)):
		return {"accepted": false, "reason": "egg_not_ready"}
	if bool(egg.get("hatched", false)):
		return {"accepted": false, "reason": "egg_already_hatched"}
	var hatchling_name := display_name.strip_edges().left(24)
	if hatchling_name.is_empty():
		hatchling_name = "Nova"
	var hatchling_profile := {
		"bitling_id": _new_hatchling_id(str(egg.get("egg_id", ""))),
		"display_name": hatchling_name,
		"born_at": int(Time.get_unix_time_from_system()),
		"generation": int(egg.get("generation", 2)),
		"phase": "BABY",
		"form_id": "spark",
		"genome": egg.get("genome", {}).duplicate(true),
		"height_cm": 14.0,
		"weight_g": 320,
		"cognitive_index": 40
	}
	egg["hatched"] = true
	egg["hatched_at"] = int(hatchling_profile.get("born_at", 0))
	egg["hatchling_id"] = hatchling_profile.get("bitling_id", "")
	eggs[index] = egg
	lineage_history.append({
		"event": "egg_hatched",
		"egg_id": egg_id,
		"hatchling_id": hatchling_profile.get("bitling_id", ""),
		"timestamp": hatchling_profile.get("born_at", 0)
	})
	egg_hatched.emit(egg.duplicate(true), hatchling_profile.duplicate(true))
	return {"accepted": true, "egg": egg.duplicate(true), "hatchling": hatchling_profile}

func get_eggs() -> Array[Dictionary]:
	return eggs.duplicate(true)

func export_state() -> Dictionary:
	return {
		"eggs": eggs.duplicate(true),
		"lineage_history": lineage_history.duplicate(true),
		"last_egg_created_at": last_egg_created_at
	}

func import_state(data: Dictionary) -> void:
	eggs.clear()
	for item in data.get("eggs", []):
		if item is Dictionary:
			eggs.append(item.duplicate(true))
	lineage_history.clear()
	for item in data.get("lineage_history", []):
		if item is Dictionary:
			lineage_history.append(item.duplicate(true))
	last_egg_created_at = maxi(int(data.get("last_egg_created_at", 0)), 0)

func reset_state() -> void:
	eggs.clear()
	lineage_history.clear()
	last_egg_created_at = 0

func _blend_genome(local_profile: Dictionary, remote_profile: Dictionary, seed_value: int) -> Dictionary:
	var local_traits: Dictionary = local_profile.get("personality", {})
	var remote_traits: Dictionary = remote_profile.get("personality", {})
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var genome: Dictionary = {}
	for trait_name in ["curiosity", "empathy", "courage", "humor", "order", "creativity", "independence"]:
		var average := (float(local_traits.get(trait_name, 50.0)) + float(remote_traits.get(trait_name, 50.0))) * 0.5
		genome[trait_name] = clampf(average + rng.randf_range(-3.0, 3.0), 0.0, 100.0)
	genome["color_seed"] = rng.randi()
	genome["voice_seed"] = rng.randi()
	genome["quirk_seed"] = rng.randi()
	genome["inherited_forms"] = [local_profile.get("form_id", "signal"), remote_profile.get("form_id", "signal")]
	return genome

func _find_egg_index(egg_id: String) -> int:
	for index in range(eggs.size()):
		if str(eggs[index].get("egg_id", "")) == egg_id:
			return index
	return -1

func _new_egg_id(seed_value: int) -> String:
	return "EGG-%s-%s" % [str(int(Time.get_unix_time_from_system())), str(abs(seed_value))]

func _new_hatchling_id(egg_id: String) -> String:
	return "BTL-%s-%s" % [str(int(Time.get_unix_time_from_system())), str(abs(hash(egg_id + str(Time.get_ticks_usec()))))]
