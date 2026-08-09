extends SceneTree

var failures: Array[String] = []
var assertions: int = 0

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	await process_frame
	var social := root.get_node_or_null("SocialSessionService")
	_check(social != null, "Wave 6 social runtime exists")
	if social == null:
		_finish()
		return
	_check(str(social.get_script().resource_path).ends_with("social_session_service_v2.gd"), "Wave 6 runtime is authoritative")
	social.call("reset_state")
	_test_catalog(social)
	_test_consent_gate(social)
	_test_shared_activity_lifecycle(social)
	_test_payload_bounds(social)
	_test_session_cleanup(social)
	_finish()

func _test_catalog(social: Node) -> void:
	var catalog: Array = social.call("get_shared_activity_catalog") as Array
	_check(catalog.size() == 3, "shared activity catalog exposes three safe activities")
	var ids: Dictionary = {}
	for entry_variant: Variant in catalog:
		var entry := entry_variant as Dictionary
		ids[str(entry.get("id", ""))] = true
	_check(ids.has("pattern_duet"), "catalog includes pattern duet")
	_check(ids.has("signal_story"), "catalog includes signal story")
	_check(ids.has("care_mirror"), "catalog includes care mirror")

func _test_consent_gate(social: Node) -> void:
	var denied: Dictionary = social.call("propose_shared_activity", "pattern_duet", {})
	_check(not bool(denied.get("accepted", false)), "activity proposal requires an active session")
	var offer: Dictionary = social.call("create_pairing_offer")
	var accepted: Dictionary = social.call("accept_pairing_offer", offer, str(offer.get("pair_code", "")))
	_check(bool(accepted.get("accepted", false)), "pair code starts a bounded social session")
	denied = social.call("propose_shared_activity", "pattern_duet", {})
	_check(str(denied.get("reason", "")) == "data_consent_required", "activity proposal requires mutual data consent")
	social.call("set_local_consent", "data", true)
	denied = social.call("propose_shared_activity", "pattern_duet", {})
	_check(str(denied.get("reason", "")) == "data_consent_required", "one-sided consent remains insufficient")
	social.call("receive_remote_consent", "data", true)

func _test_shared_activity_lifecycle(social: Node) -> void:
	var proposal_result: Dictionary = social.call("propose_shared_activity", "pattern_duet", {
		"rounds": 3,
		"prompt": "Find the shared rhythm",
		"private_notes": "must not leave device"
	})
	_check(bool(proposal_result.get("accepted", false)), "mutual consent enables a shared activity proposal")
	var proposal := proposal_result.get("proposal", {}) as Dictionary
	_check(not (proposal.get("context", {}) as Dictionary).has("private_notes"), "private activity context is stripped")
	var started: Dictionary = social.call("accept_shared_activity", proposal)
	_check(bool(started.get("accepted", false)), "valid proposal starts the shared activity")
	var snapshot: Dictionary = social.call("get_session_snapshot")
	_check(str((snapshot.get("active_activity", {}) as Dictionary).get("activity_id", "")) == "pattern_duet", "active activity is visible in the session snapshot")
	var result: Dictionary = social.call("complete_shared_activity", 0.95, 0.75, "We alternated and checked each other.")
	_check(bool(result.get("accepted", false)), "shared activity completes")
	_check(float(result.get("combined_score", 0.0)) > 0.8, "completion records bounded combined performance")
	_check(float(result.get("cooperation", 0.0)) > 0.7, "completion records cooperation")
	snapshot = social.call("get_session_snapshot")
	_check((snapshot.get("active_activity", {}) as Dictionary).is_empty(), "completion clears active activity")
	_check((snapshot.get("completed_activities", []) as Array).size() == 1, "completion enters bounded activity history")
	_check(not (snapshot.get("peer_insights", []) as Array).is_empty(), "shared activity creates a peer-learning insight")

func _test_payload_bounds(social: Node) -> void:
	var long_text := "x".repeat(200)
	var proposal_result: Dictionary = social.call("propose_shared_activity", "signal_story", {
		"prompt": long_text,
		"url": "https://not-allowed.example",
		"safe_number": 7
	})
	_check(bool(proposal_result.get("accepted", false)), "second safe activity can be proposed")
	var proposal := proposal_result.get("proposal", {}) as Dictionary
	var context := proposal.get("context", {}) as Dictionary
	_check(str(context.get("prompt", "")).length() <= 96, "activity text is length bounded")
	_check(not context.has("url"), "external URLs are excluded from activity context")
	_check(int(context.get("safe_number", 0)) == 7, "bounded scalar context survives sanitization")
	var tampered := proposal.duplicate(true)
	tampered["session_id"] = "SOC-WRONG"
	var rejected: Dictionary = social.call("accept_shared_activity", tampered)
	_check(str(rejected.get("reason", "")) == "session_mismatch", "cross-session activity proposal is rejected")
	_check(bool(social.call("cancel_shared_activity", "test_cleanup")), "pending activity can be cancelled safely")

func _test_session_cleanup(social: Node) -> void:
	var proposal_result: Dictionary = social.call("propose_shared_activity", "care_mirror", {})
	var proposal := proposal_result.get("proposal", {}) as Dictionary
	social.call("accept_shared_activity", proposal)
	social.call("end_session", "wave6_test_complete")
	var snapshot: Dictionary = social.call("get_session_snapshot")
	_check(not bool(snapshot.get("session_active", true)), "ending a session disables the social channel")
	_check((snapshot.get("pending_activity", {}) as Dictionary).is_empty(), "ending a session clears pending activities")
	_check((snapshot.get("active_activity", {}) as Dictionary).is_empty(), "ending a session clears active activities")
	_check(not bool(social.call("cancel_shared_activity", "nothing_to_cancel")), "empty activity cancellation fails closed")

func _check(condition: bool, description: String) -> void:
	assertions += 1
	if condition:
		print("[CI-WAVE6] PASS: %s" % description)
	else:
		failures.append(description)
		push_error("[CI-WAVE6] FAIL: %s" % description)

func _finish() -> void:
	if failures.is_empty():
		print("[CI-WAVE6] PASS: %d assertions" % assertions)
		quit(0)
	else:
		print("[CI-WAVE6] BLOCKED: %d of %d assertions failed" % [failures.size(), assertions])
		quit(1)
