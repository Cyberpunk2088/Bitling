extends Node

## Transport-neutral semantic language used between Bitlings.
## The audible utterance is original procedural gibberish, never an imitation of a named character voice.

signal utterance_created(packet: Dictionary, audible_text: String)

const PROTOCOL_VERSION := 1
const MAX_PAYLOAD_BYTES := 1024
const ALLOWED_INTENTS: Array[String] = [
	"greet", "play_invite", "share_discovery", "comfort", "celebrate",
	"ask_question", "teach_pattern", "tell_joke", "say_goodbye", "egg_proposal"
]

const SYLLABLES_SOFT: Array[String] = ["mii", "luma", "nobi", "pala", "wuu", "lili", "momo", "sana"]
const SYLLABLES_BRIGHT: Array[String] = ["biki", "tala", "zumi", "kiko", "pipi", "daba", "riri", "toki"]
const SYLLABLES_ODD: Array[String] = ["plonk", "wib", "boppa", "grum", "naka", "toing", "blim", "quba"]

func create_packet(intent: String, payload: Dictionary = {}, emotion: Dictionary = {}) -> Dictionary:
	if not ALLOWED_INTENTS.has(intent):
		return {}
	var sanitized_payload := _sanitize_payload(payload)
	var identity := get_node_or_null("/root/BitlingIdentity")
	var speaker_id := "unknown"
	if identity != null:
		speaker_id = str(identity.get_public_passport().get("bitling_id", "unknown"))
	var packet := {
		"protocol": PROTOCOL_VERSION,
		"speaker_id": speaker_id,
		"intent": intent,
		"emotion": _sanitize_emotion(emotion),
		"payload": sanitized_payload,
		"created_at": int(Time.get_unix_time_from_system()),
		"nonce": _nonce()
	}
	packet["integrity"] = _integrity_token(packet)
	var audible_text := render_utterance(packet)
	utterance_created.emit(packet.duplicate(true), audible_text)
	return packet

func validate_packet(packet: Dictionary) -> bool:
	if int(packet.get("protocol", -1)) != PROTOCOL_VERSION:
		return false
	if not ALLOWED_INTENTS.has(str(packet.get("intent", ""))):
		return false
	if str(packet.get("speaker_id", "")).is_empty():
		return false
	var payload: Dictionary = packet.get("payload", {})
	if JSON.stringify(payload).to_utf8_buffer().size() > MAX_PAYLOAD_BYTES:
		return false
	return int(packet.get("integrity", 0)) == _integrity_token(packet)

func decode_packet(packet: Dictionary) -> Dictionary:
	if not validate_packet(packet):
		return {"accepted": false, "reason": "invalid_packet"}
	return {
		"accepted": true,
		"speaker_id": str(packet.get("speaker_id", "")),
		"intent": str(packet.get("intent", "")),
		"emotion": packet.get("emotion", {}).duplicate(true),
		"payload": packet.get("payload", {}).duplicate(true)
	}

func render_utterance(packet: Dictionary) -> String:
	if packet.is_empty():
		return ""
	var intent := str(packet.get("intent", "greet"))
	var emotion: Dictionary = packet.get("emotion", {})
	var dominant := str(emotion.get("dominant_emotion", "curiosity"))
	var seed_value := hash("%s:%s:%s" % [packet.get("speaker_id", ""), packet.get("nonce", 0), intent])
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var syllables := _syllable_set_for_emotion(dominant)
	var word_count := rng.randi_range(2, 5)
	var words: Array[String] = []
	for _index in range(word_count):
		var parts := rng.randi_range(1, 3)
		var word := ""
		for _part in range(parts):
			word += syllables[rng.randi_range(0, syllables.size() - 1)]
		words.append(word.capitalize())
	var ending := "."
	if intent in ["ask_question", "play_invite", "egg_proposal"]:
		ending = "?"
	elif dominant in ["joy", "surprise", "pride"]:
		ending = "!"
	return " ".join(words) + ending

func get_voice_profile(emotion: Dictionary = {}) -> Dictionary:
	var identity := get_node_or_null("/root/BitlingIdentity")
	var seed_value := 1
	if identity != null:
		seed_value = int(identity.get_private_passport().get("voice_seed", 1))
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var dominant := str(emotion.get("dominant_emotion", "calm"))
	var arousal := clampf(float(emotion.get("arousal", 0.35)), 0.0, 1.0)
	var valence := clampf(float(emotion.get("valence", 0.2)), -1.0, 1.0)
	var pitch := rng.randf_range(1.08, 1.34)
	var rate := rng.randf_range(0.92, 1.12)
	pitch += valence * 0.10 + arousal * 0.12
	rate += arousal * 0.22
	if dominant in ["sadness", "worry"]:
		pitch -= 0.12
		rate -= 0.10
	elif dominant == "surprise":
		pitch += 0.18
		rate += 0.12
	return {
		"style": "original_playful_gibberish",
		"pitch_scale": clampf(pitch, 0.75, 1.75),
		"rate_scale": clampf(rate, 0.65, 1.55),
		"brightness": clampf(0.55 + valence * 0.20, 0.2, 0.9),
		"wobble": rng.randf_range(0.04, 0.14) + arousal * 0.08,
		"breathiness": clampf(0.15 + (1.0 - arousal) * 0.18, 0.05, 0.4)
	}

func _sanitize_payload(payload: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for key in payload.keys():
		var name := str(key).left(40)
		var value: Variant = payload[key]
		if value is String:
			result[name] = str(value).left(160)
		elif value is int or value is float or value is bool:
			result[name] = value
		elif value is Array:
			var safe_values: Array = []
			for item in value:
				if item is String or item is int or item is float or item is bool:
					safe_values.append(item)
				if safe_values.size() >= 12:
					break
			result[name] = safe_values
		if JSON.stringify(result).to_utf8_buffer().size() > MAX_PAYLOAD_BYTES:
			result.erase(name)
			break
	return result

func _sanitize_emotion(emotion: Dictionary) -> Dictionary:
	return {
		"dominant_emotion": str(emotion.get("dominant_emotion", "calm")).left(24),
		"valence": clampf(float(emotion.get("valence", 0.0)), -1.0, 1.0),
		"arousal": clampf(float(emotion.get("arousal", 0.3)), 0.0, 1.0)
	}

func _syllable_set_for_emotion(emotion_name: String) -> Array[String]:
	if emotion_name in ["joy", "surprise", "pride"]:
		return SYLLABLES_BRIGHT
	if emotion_name in ["confusion", "embarrassment", "frustration"]:
		return SYLLABLES_ODD
	return SYLLABLES_SOFT

func _integrity_token(packet: Dictionary) -> int:
	return hash("%s|%s|%s|%s|%s|%s" % [
		packet.get("protocol", 0),
		packet.get("speaker_id", ""),
		packet.get("intent", ""),
		JSON.stringify(packet.get("emotion", {})),
		JSON.stringify(packet.get("payload", {})),
		packet.get("nonce", 0)
	])

func _nonce() -> int:
	return int(Time.get_ticks_usec() ^ Time.get_unix_time_from_system() ^ get_instance_id())
