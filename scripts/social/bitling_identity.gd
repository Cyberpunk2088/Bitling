extends Node

## Persistent fictional identity and passport for one Bitling.
## Precise device location, owner identity and camera images are never collected automatically.

signal identity_created(bitling_id: String)
signal identity_updated(snapshot: Dictionary)

const PASSPORT_VERSION := 2
const DEFAULT_NAME := "Bitling"

var passport: Dictionary = {}

func _ready() -> void:
	_ensure_identity_exists()

func ensure_identity() -> Dictionary:
	_ensure_identity_exists()
	return _public_projection()

func set_display_name(value: String) -> bool:
	var cleaned := value.strip_edges().left(24)
	if cleaned.is_empty():
		return false
	_ensure_identity_exists()
	passport["display_name"] = cleaned
	_emit_update()
	return true

func set_optional_birth_label(value: String) -> void:
	## User-entered coarse label only, for example "Berlin" or "Signalhafen".
	## Never populate this field from GPS without a separate explicit consent flow.
	_ensure_identity_exists()
	passport["birth_label"] = value.strip_edges().left(40)
	_emit_update()

func set_portrait_reference(local_path: String) -> bool:
	## Stores only a local resource reference. It is excluded from public cards.
	if not local_path.is_empty() and not local_path.begins_with("user://") and not local_path.begins_with("res://"):
		return false
	_ensure_identity_exists()
	passport["portrait_reference"] = local_path
	_emit_update()
	return true

func set_intelligence_quotient(value: int) -> void:
	## Individual in-world IQ of this Bitling. It is not a score for the human player.
	_ensure_identity_exists()
	passport["intelligence_quotient"] = clampi(value, 40, 220)
	passport.erase("cognitive_index")
	passport["last_updated_at"] = int(Time.get_unix_time_from_system())
	_emit_update()

func refresh_development_metrics(
	level: int,
	phase_name: String,
	form_id: String,
	_learning_rating: float,
	_curiosity: float
) -> Dictionary:
	_ensure_identity_exists()
	var phase_scale := {
		"EGG": Vector2(4.0, 45.0),
		"BABY": Vector2(14.0, 320.0),
		"CHILD": Vector2(28.0, 1200.0),
		"TEEN": Vector2(42.0, 3100.0),
		"ADULT": Vector2(56.0, 5700.0),
		"SENIOR": Vector2(54.0, 5400.0),
		"LEGENDARY": Vector2(62.0, 6400.0)
	}
	var base: Vector2 = phase_scale.get(phase_name, Vector2(14.0, 320.0))
	var variation := _identity_variation()
	passport["height_cm"] = snappedf(maxf(base.x + variation.x, 1.0), 0.1)
	passport["weight_g"] = maxi(int(round(base.y + variation.y)), 1)
	passport["development_phase"] = phase_name
	passport["form_id"] = form_id
	passport["level"] = maxi(level, 1)
	if not passport.has("intelligence_quotient"):
		passport["intelligence_quotient"] = _initial_iq(str(passport.get("bitling_id", "bitling")))
	passport.erase("cognitive_index")
	passport["last_updated_at"] = int(Time.get_unix_time_from_system())
	_emit_update()
	return _public_projection()

func get_public_passport() -> Dictionary:
	_ensure_identity_exists()
	return _public_projection()

func get_private_passport() -> Dictionary:
	_ensure_identity_exists()
	return passport.duplicate(true)

func export_state() -> Dictionary:
	_ensure_identity_exists()
	return {"passport": passport.duplicate(true)}

func import_state(data: Dictionary) -> void:
	var loaded: Dictionary = data.get("passport", {})
	passport = loaded.duplicate(true) if not loaded.is_empty() else _create_identity()
	passport["passport_version"] = PASSPORT_VERSION
	if not passport.has("intelligence_quotient"):
		passport["intelligence_quotient"] = clampi(int(passport.get("cognitive_index", _initial_iq(str(passport.get("bitling_id", "bitling"))))), 40, 220)
	passport.erase("cognitive_index")
	_emit_update()

func reset_state() -> void:
	passport = _create_identity()
	identity_created.emit(str(passport.get("bitling_id", "")))

func _ensure_identity_exists() -> void:
	if passport.is_empty() or str(passport.get("bitling_id", "")).is_empty():
		passport = _create_identity()
		identity_created.emit(str(passport.get("bitling_id", "")))

func _public_projection() -> Dictionary:
	var public_card := passport.duplicate(true)
	public_card.erase("portrait_reference")
	public_card.erase("private_notes")
	return public_card

func _create_identity() -> Dictionary:
	var bitling_id := _new_identifier("BTL")
	var seed_value := hash(bitling_id)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return {
		"passport_version": PASSPORT_VERSION,
		"bitling_id": bitling_id,
		"display_name": DEFAULT_NAME,
		"born_at": int(Time.get_unix_time_from_system()),
		"birth_label": "Lokales Signalnetz",
		"generation": 1,
		"development_phase": "EGG",
		"form_id": "signal",
		"level": 1,
		"height_cm": 4.0,
		"weight_g": 45,
		"intelligence_quotient": _initial_iq(bitling_id),
		"voice_seed": rng.randi(),
		"portrait_reference": "",
		"last_updated_at": int(Time.get_unix_time_from_system())
	}

func _initial_iq(bitling_id: String) -> int:
	var rng := RandomNumberGenerator.new()
	rng.seed = abs(hash("iq:%s" % bitling_id))
	return rng.randi_range(82, 128)

func _new_identifier(prefix: String) -> String:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(Time.get_unix_time_from_system()) ^ int(Time.get_ticks_usec()) ^ int(hash(get_instance_id()))
	return "%s-%s-%s-%s" % [
		prefix,
		str(int(Time.get_unix_time_from_system())),
		str(rng.randi()),
		str(rng.randi())
	]

func _identity_variation() -> Vector2:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(str(passport.get("bitling_id", "bitling")))
	return Vector2(rng.randf_range(-2.0, 2.0), rng.randf_range(-120.0, 120.0))

func _emit_update() -> void:
	identity_updated.emit(_public_projection())
