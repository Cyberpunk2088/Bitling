extends Node

## Consent-first social session state and validated semantic packet exchange.
## Network, voice and video transports are adapters; this service owns the safe protocol.

signal session_started(session_id: String, peer_card: Dictionary)
signal session_ended(reason: String)
signal consent_changed(channel: String, local_value: bool, remote_value: bool)
signal social_packet_received(decoded: Dictionary)
signal social_learning_applied(insight: Dictionary)

const SESSION_PROTOCOL := 1
const MAX_SESSION_EVENTS := 64
const CONSENT_CHANNELS: Array[String] = ["data", "voice", "video", "egg"]

var session_id: String = ""
var pair_code: String = ""
var peer_card: Dictionary = {}
var local_consent: Dictionary = {}
var remote_consent: Dictionary = {}
var session_events: Array[Dictionary] = []
var peer_insights: Array[Dictionary] = []
var session_active: bool = false

func _ready() -> void:
	_reset_consent()

func create_pairing_offer() -> Dictionary:
	if session_active:
		return {}
	pair_code = _create_pair_code()
	var identity := get_node_or_null("/root/BitlingIdentity")
	var media := get_node_or_null("/root/MediaCapabilityService")
	return {
		"protocol": SESSION_PROTOCOL,
		"pair_code": pair_code,
		"identity": identity.get_public_passport() if identity != null else {},
		"capabilities": media.get_snapshot() if media != null else {},
		"expires_at": int(Time.get_unix_time_from_system()) + 300
	}

func accept_pairing_offer(offer: Dictionary, entered_code: String) -> Dictionary:
	if int(offer.get("protocol", -1)) != SESSION_PROTOCOL:
		return {"accepted": false, "reason": "protocol_mismatch"}
	if str(offer.get("pair_code", "")) != entered_code.strip_edges().to_upper():
		return {"accepted": false, "reason": "pair_code_mismatch"}
	if int(offer.get("expires_at", 0)) < int(Time.get_unix_time_from_system()):
		return {"accepted": false, "reason": "pairing_expired"}
	var candidate: Dictionary = offer.get("identity", {})
	if not _validate_peer_card(candidate):
		return {"accepted": false, "reason": "invalid_peer_identity"}
	peer_card = candidate.duplicate(true)
	session_id = _new_session_id(str(peer_card.get("bitling_id", "peer")))
	session_active = true
	_reset_consent()
	_record_session_event("session_started", {"peer_id": peer_card.get("bitling_id", "")})
	session_started.emit(session_id, peer_card.duplicate(true))
	return {"accepted": true, "session_id": session_id, "peer_card": peer_card.duplicate(true)}

func set_local_consent(channel: String, value: bool) -> bool:
	if not CONSENT_CHANNELS.has(channel):
		return false
	local_consent[channel] = value
	consent_changed.emit(channel, value, bool(remote_consent.get(channel, false)))
	return true

func receive_remote_consent(channel: String, value: bool) -> bool:
	if not CONSENT_CHANNELS.has(channel):
		return false
	remote_consent[channel] = value
	consent_changed.emit(channel, bool(local_consent.get(channel, false)), value)
	return true

func has_mutual_consent(channel: String) -> bool:
	return session_active and bool(local_consent.get(channel, false)) and bool(remote_consent.get(channel, false))

func create_social_packet(intent: String, payload: Dictionary = {}) -> Dictionary:
	if not has_mutual_consent("data"):
		return {}
	var language := get_node_or_null("/root/BitlingLanguage")
	var emotions := get_node_or_null("/root/EmotionModel")
	if language == null:
		return {}
	var emotion_snapshot: Dictionary = emotions.get_snapshot() if emotions != null else {}
	var packet: Dictionary = language.create_packet(intent, payload, emotion_snapshot)
	if packet.is_empty():
		return {}
	packet["session_id"] = session_id
	_record_session_event("packet_sent", {"intent": intent})
	return packet

func receive_social_packet(packet: Dictionary) -> Dictionary:
	if not has_mutual_consent("data"):
		return {"accepted": false, "reason": "data_consent_required"}
	if str(packet.get("session_id", "")) != session_id:
		return {"accepted": false, "reason": "session_mismatch"}
	var language := get_node_or_null("/root/BitlingLanguage")
	if language == null:
		return {"accepted": false, "reason": "language_unavailable"}
	var decoded: Dictionary = language.decode_packet(packet)
	if not bool(decoded.get("accepted", false)):
		return decoded
	if str(decoded.get("speaker_id", "")) != str(peer_card.get("bitling_id", "")):
		return {"accepted": false, "reason": "speaker_mismatch"}
	_apply_social_effects(decoded)
	_record_session_event("packet_received", {"intent": decoded.get("intent", "")})
	social_packet_received.emit(decoded.duplicate(true))
	return decoded

func can_start_voice() -> bool:
	var media := get_node_or_null("/root/MediaCapabilityService")
	return media != null and media.can_start_voice(
		bool(local_consent.get("voice", false)),
		bool(remote_consent.get("voice", false))
	)

func can_start_video() -> bool:
	var media := get_node_or_null("/root/MediaCapabilityService")
	return media != null and media.can_start_video(
		bool(local_consent.get("video", false)),
		bool(remote_consent.get("video", false))
	)

func end_session(reason: String = "completed") -> void:
	if not session_active:
		return
	_record_session_event("session_ended", {"reason": reason})
	session_active = false
	peer_card.clear()
	pair_code = ""
	var old_session := session_id
	session_id = ""
	_reset_consent()
	session_ended.emit(reason if not reason.is_empty() else old_session)

func get_session_snapshot() -> Dictionary:
	return {
		"session_id": session_id,
		"session_active": session_active,
		"peer_card": peer_card.duplicate(true),
		"local_consent": local_consent.duplicate(true),
		"remote_consent": remote_consent.duplicate(true),
		"peer_insights": peer_insights.duplicate(true)
	}

func reset_state() -> void:
	session_id = ""
	pair_code = ""
	peer_card.clear()
	session_events.clear()
	peer_insights.clear()
	session_active = false
	_reset_consent()

func _apply_social_effects(decoded: Dictionary) -> void:
	var intent := str(decoded.get("intent", ""))
	var emotion_snapshot: Dictionary = decoded.get("emotion", {})
	var emotion_model := get_node_or_null("/root/EmotionModel")
	if emotion_model != null:
		emotion_model.perceive_peer_emotion(emotion_snapshot, 0.45)
		emotion_model.apply_event("social_greeting" if intent == "greet" else "peer_insight", 0.6)
	var brain := get_node_or_null("/root/CompanionBrain")
	if brain != null:
		brain.observe_interaction("social_%s" % intent, 0.45, {"peer_id": peer_card.get("bitling_id", "")})
	var payload: Dictionary = decoded.get("payload", {})
	if intent in ["teach_pattern", "share_discovery"]:
		var insight := {
			"source_peer": str(peer_card.get("bitling_id", "")),
			"topic": str(payload.get("topic", "general")).left(40),
			"summary": str(payload.get("summary", "")).left(160),
			"received_at": int(Time.get_unix_time_from_system())
		}
		peer_insights.append(insight)
		while peer_insights.size() > 20:
			peer_insights.pop_front()
		if brain != null:
			brain.nudge_trait("curiosity", 0.25)
		social_learning_applied.emit(insight.duplicate(true))

func _validate_peer_card(card: Dictionary) -> bool:
	if str(card.get("bitling_id", "")).is_empty():
		return false
	if str(card.get("display_name", "")).length() > 24:
		return false
	if card.has("portrait_reference") or card.has("private_notes"):
		return false
	return true

func _reset_consent() -> void:
	local_consent.clear()
	remote_consent.clear()
	for channel in CONSENT_CHANNELS:
		local_consent[channel] = false
		remote_consent[channel] = false

func _record_session_event(event_id: String, payload: Dictionary) -> void:
	session_events.append({
		"event_id": event_id,
		"payload": payload.duplicate(true),
		"timestamp": int(Time.get_unix_time_from_system())
	})
	while session_events.size() > MAX_SESSION_EVENTS:
		session_events.pop_front()

func _create_pair_code() -> String:
	var alphabet := "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
	var rng := RandomNumberGenerator.new()
	rng.seed = int(Time.get_ticks_usec() ^ get_instance_id())
	var result := ""
	for _index in range(6):
		result += alphabet[rng.randi_range(0, alphabet.length() - 1)]
	return result

func _new_session_id(peer_id: String) -> String:
	return "SOC-%s-%s" % [str(int(Time.get_unix_time_from_system())), str(abs(hash(peer_id + str(Time.get_ticks_usec()))))]
