extends "res://scripts/social/social_session_service.gd"

## Wave 6 shared-activity protocol layered on the consent-first social session.
## Activities exchange only bounded semantic state; no open chat, media, or arbitrary payload execution.

signal shared_activity_proposed(proposal: Dictionary)
signal shared_activity_started(activity: Dictionary)
signal shared_activity_completed(result: Dictionary)
signal shared_activity_cancelled(reason: String)

const SHARED_ACTIVITY_PROTOCOL := 1
const ACTIVITY_OFFER_TTL_SECONDS := 120
const SHARED_ACTIVITIES: Dictionary = {
	"pattern_duet": {
		"title": "Muster-Duett",
		"domain": "logic",
		"trait": "curiosity",
		"learning_topic": "patterns"
	},
	"signal_story": {
		"title": "Signalgeschichte",
		"domain": "language",
		"trait": "creativity",
		"learning_topic": "storytelling"
	},
	"care_mirror": {
		"title": "Fürsorge-Spiegel",
		"domain": "empathy",
		"trait": "empathy",
		"learning_topic": "perspective"
	}
}

var pending_activity: Dictionary = {}
var active_activity: Dictionary = {}
var completed_activities: Array[Dictionary] = []

func get_shared_activity_catalog() -> Array[Dictionary]:
	var catalog: Array[Dictionary] = []
	for activity_id_variant: Variant in SHARED_ACTIVITIES.keys():
		var activity_id := str(activity_id_variant)
		var entry := (SHARED_ACTIVITIES[activity_id] as Dictionary).duplicate(true)
		entry["id"] = activity_id
		catalog.append(entry)
	return catalog

func propose_shared_activity(activity_id: String, context: Dictionary = {}) -> Dictionary:
	if not session_active:
		return {"accepted": false, "reason": "session_required"}
	if not has_mutual_consent("data"):
		return {"accepted": false, "reason": "data_consent_required"}
	if not SHARED_ACTIVITIES.has(activity_id):
		return {"accepted": false, "reason": "unknown_activity"}
	if not active_activity.is_empty():
		return {"accepted": false, "reason": "activity_active"}
	var now := int(Time.get_unix_time_from_system())
	pending_activity = {
		"protocol": SHARED_ACTIVITY_PROTOCOL,
		"proposal_id": "ACT-%s-%s" % [session_id, str(abs(hash(activity_id + str(Time.get_ticks_usec()))))],
		"session_id": session_id,
		"activity_id": activity_id,
		"context": _sanitize_activity_context(context),
		"created_at": now,
		"expires_at": now + ACTIVITY_OFFER_TTL_SECONDS
	}
	_record_session_event("activity_proposed", {"activity_id": activity_id})
	shared_activity_proposed.emit(pending_activity.duplicate(true))
	return {"accepted": true, "proposal": pending_activity.duplicate(true)}

func accept_shared_activity(proposal: Dictionary) -> Dictionary:
	if not session_active:
		return {"accepted": false, "reason": "session_required"}
	if not has_mutual_consent("data"):
		return {"accepted": false, "reason": "data_consent_required"}
	if int(proposal.get("protocol", -1)) != SHARED_ACTIVITY_PROTOCOL:
		return {"accepted": false, "reason": "protocol_mismatch"}
	if str(proposal.get("session_id", "")) != session_id:
		return {"accepted": false, "reason": "session_mismatch"}
	if int(proposal.get("expires_at", 0)) < int(Time.get_unix_time_from_system()):
		return {"accepted": false, "reason": "activity_expired"}
	var activity_id := str(proposal.get("activity_id", ""))
	if not SHARED_ACTIVITIES.has(activity_id):
		return {"accepted": false, "reason": "unknown_activity"}
	if not active_activity.is_empty():
		return {"accepted": false, "reason": "activity_active"}
	var definition := SHARED_ACTIVITIES[activity_id] as Dictionary
	active_activity = {
		"proposal_id": str(proposal.get("proposal_id", "")),
		"session_id": session_id,
		"activity_id": activity_id,
		"title": str(definition.get("title", activity_id)),
		"domain": str(definition.get("domain", "social")),
		"context": _sanitize_activity_context(proposal.get("context", {}) as Dictionary),
		"started_at": int(Time.get_unix_time_from_system())
	}
	pending_activity.clear()
	_record_session_event("activity_started", {"activity_id": activity_id})
	shared_activity_started.emit(active_activity.duplicate(true))
	return {"accepted": true, "activity": active_activity.duplicate(true)}

func complete_shared_activity(local_score: float, remote_score: float, reflection: String = "") -> Dictionary:
	if active_activity.is_empty():
		return {"accepted": false, "reason": "no_active_activity"}
	if not has_mutual_consent("data"):
		return {"accepted": false, "reason": "data_consent_required"}
	var activity_id := str(active_activity.get("activity_id", ""))
	var definition := SHARED_ACTIVITIES.get(activity_id, {}) as Dictionary
	var local_bounded := clampf(local_score, 0.0, 1.0)
	var remote_bounded := clampf(remote_score, 0.0, 1.0)
	var cooperation := clampf(1.0 - absf(local_bounded - remote_bounded), 0.0, 1.0)
	var combined := clampf((local_bounded + remote_bounded) * 0.5, 0.0, 1.0)
	var result := {
		"accepted": true,
		"activity_id": activity_id,
		"domain": str(definition.get("domain", "social")),
		"combined_score": combined,
		"cooperation": cooperation,
		"reflection": reflection.strip_edges().left(160),
		"peer_id": str(peer_card.get("bitling_id", "")),
		"completed_at": int(Time.get_unix_time_from_system())
	}
	completed_activities.append(result.duplicate(true))
	while completed_activities.size() > 20:
		completed_activities.pop_front()
	_apply_shared_activity_effects(definition, result)
	_record_session_event("activity_completed", {
		"activity_id": activity_id,
		"combined_score": combined,
		"cooperation": cooperation
	})
	active_activity.clear()
	shared_activity_completed.emit(result.duplicate(true))
	return result

func cancel_shared_activity(reason: String = "cancelled") -> bool:
	if pending_activity.is_empty() and active_activity.is_empty():
		return false
	var resolved_reason := reason.strip_edges().left(40)
	if resolved_reason.is_empty():
		resolved_reason = "cancelled"
	pending_activity.clear()
	active_activity.clear()
	_record_session_event("activity_cancelled", {"reason": resolved_reason})
	shared_activity_cancelled.emit(resolved_reason)
	return true

func get_session_snapshot() -> Dictionary:
	var snapshot := super.get_session_snapshot()
	snapshot["shared_activity_catalog"] = get_shared_activity_catalog()
	snapshot["pending_activity"] = pending_activity.duplicate(true)
	snapshot["active_activity"] = active_activity.duplicate(true)
	snapshot["completed_activities"] = completed_activities.duplicate(true)
	return snapshot

func end_session(reason: String = "completed") -> void:
	pending_activity.clear()
	active_activity.clear()
	super.end_session(reason)

func reset_state() -> void:
	pending_activity.clear()
	active_activity.clear()
	completed_activities.clear()
	super.reset_state()

func _sanitize_activity_context(context: Dictionary) -> Dictionary:
	var sanitized: Dictionary = {}
	for key_variant: Variant in context.keys():
		if sanitized.size() >= 6:
			break
		var key := str(key_variant).strip_edges().left(32)
		if key.is_empty() or key in ["portrait_reference", "private_notes", "path", "url"]:
			continue
		var value: Variant = context[key_variant]
		if value is String:
			sanitized[key] = str(value).strip_edges().left(96)
		elif value is int or value is float or value is bool:
			sanitized[key] = value
	return sanitized

func _apply_shared_activity_effects(definition: Dictionary, result: Dictionary) -> void:
	var brain := get_node_or_null("/root/CompanionBrain")
	if brain != null:
		brain.observe_interaction("social_shared_activity", 0.55 + float(result.get("cooperation", 0.0)) * 0.35, {
			"peer_id": peer_card.get("bitling_id", ""),
			"activity_id": result.get("activity_id", "")
		})
		brain.nudge_trait(str(definition.get("trait", "curiosity")), 0.15 + float(result.get("combined_score", 0.0)) * 0.20)
	var adaptive := get_node_or_null("/root/AdaptiveLearning")
	if adaptive != null and adaptive.has_method("record_result"):
		adaptive.call("record_result", str(definition.get("domain", "social")), 5, float(result.get("combined_score", 0.0)) >= 0.55, 8.0, 0)
	var insight := {
		"source_peer": str(peer_card.get("bitling_id", "")),
		"topic": str(definition.get("learning_topic", "cooperation")),
		"summary": "Gemeinsame Aktivität: %s" % str(definition.get("title", "Aktivität")),
		"received_at": int(Time.get_unix_time_from_system())
	}
	peer_insights.append(insight)
	while peer_insights.size() > 20:
		peer_insights.pop_front()
	social_learning_applied.emit(insight.duplicate(true))
