extends SceneTree

var failures: Array[String] = []
var assertions: int = 0
var _learning_backup: Dictionary = {}
var _adaptive_backup: Dictionary = {}
var _development_backup: Dictionary = {}
var _partner_backup: Dictionary = {}
var _game_backup: Dictionary = {}

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	await process_frame
	await process_frame
	var learning: Node = root.get_node_or_null("LearningAdventures")
	var adaptive: Node = root.get_node_or_null("AdaptiveLearning")
	var development: Node = root.get_node_or_null("DevelopmentProfile")
	var partner: Node = root.get_node_or_null("PartnerWorld")
	var state: Node = root.get_node_or_null("GameState")
	_assert(learning != null, "LearningAdventures autoload exists")
	_assert(adaptive != null, "AdaptiveLearning remains available")
	_assert(development != null, "DevelopmentProfile remains available")
	_assert(partner != null, "PartnerWorld remains available")
	_assert(state != null, "GameState remains available")
	if learning == null or adaptive == null or development == null or partner == null or state == null:
		_finish()
		return

	_learning_backup = learning.call("export_state") as Dictionary
	_adaptive_backup = adaptive.call("export_state") as Dictionary
	_development_backup = development.call("export_state") as Dictionary
	_partner_backup = partner.call("export_state") as Dictionary
	_game_backup = state.call("get_save_data") as Dictionary
	learning.call("reset_state")
	adaptive.call("reset_state")
	development.call("reset_state")
	partner.call("reset_state")
	state.call("hatch")
	await process_frame

	_test_catalog_contract(learning)
	_test_age_profiles(learning, development)
	_test_all_adventures(learning)
	_test_recoverable_failure(learning)
	_test_adaptive_growth(learning)
	_test_persistence(learning)
	await _test_audio_and_ui(learning)

	learning.call("import_state", _learning_backup)
	adaptive.call("import_state", _adaptive_backup)
	development.call("import_state", _development_backup)
	partner.call("import_state", _partner_backup)
	state.call("apply_save_data", _game_backup)
	learning.call("save_state")
	_finish()

func _test_catalog_contract(learning: Node) -> void:
	var snapshot: Dictionary = learning.call("get_snapshot") as Dictionary
	var catalog: Array = snapshot.get("catalog", []) as Array
	_assert(catalog.size() == 12, "catalog exposes twelve core Learning Adventures")
	_assert(int(snapshot.get("variant_count", 0)) >= 60, "catalog exposes at least sixty authored variants")
	var ids: Array[String] = []
	var domains: Array[String] = []
	for entry_variant: Variant in catalog:
		if not entry_variant is Dictionary:
			continue
		var entry: Dictionary = entry_variant as Dictionary
		ids.append(str(entry.get("id", "")))
		domains.append(str(entry.get("domain", "")))
		_assert(int(entry.get("variant_count", 0)) >= 5, "%s owns at least five variants" % str(entry.get("id", "adventure")))
		_assert(not str(entry.get("learning_goal", "")).is_empty(), "%s documents a learning goal" % str(entry.get("id", "adventure")))
		_assert(not str(entry.get("transfer_prompt", "")).is_empty(), "%s documents a transfer task" % str(entry.get("id", "adventure")))
	for required: String in ["pattern_relay", "signal_language", "resonance_rhythm", "circuit_garden", "number_constellation", "evidence_beacon", "emotion_mirror", "eco_balance", "story_forge", "debate_bridge", "navigation_lab", "mentor_workshop"]:
		_assert(ids.has(required), "catalog contains %s" % required)
	_assert(domains.has("math") and domains.has("media") and domains.has("emotion") and domains.has("science"), "catalog spans academic, media and emotional learning")

func _test_age_profiles(learning: Node, development: Node) -> void:
	development.call("set_player_age_band", "child")
	var child_start: Dictionary = learning.call("start_adventure", "pattern_relay", 101) as Dictionary
	_assert(bool(child_start.get("accepted", false)), "child profile starts an adventure")
	var child_session: Dictionary = child_start.get("session", {}) as Dictionary
	_assert(str(child_session.get("age_band", "")) == "child", "child age profile propagates into session")
	_assert(int(child_session.get("total_rounds", 0)) == 4, "child profile uses three core rounds plus transfer")
	learning.call("abandon_session")

	development.call("set_player_age_band", "teen")
	var teen_start: Dictionary = learning.call("start_adventure", "pattern_relay", 102) as Dictionary
	_assert(bool(teen_start.get("accepted", false)), "teen profile starts an adventure")
	var teen_session: Dictionary = teen_start.get("session", {}) as Dictionary
	_assert(int(teen_session.get("total_rounds", 0)) == 5, "teen profile uses four core rounds plus transfer")
	learning.call("abandon_session")
	development.call("set_player_age_band", "adult")

func _test_all_adventures(learning: Node) -> void:
	var catalog: Array = learning.call("get_catalog") as Array
	for entry_variant: Variant in catalog:
		var entry: Dictionary = entry_variant as Dictionary
		var adventure_id: String = str(entry.get("id", ""))
		var completion: Dictionary = _play_best_session(learning, adventure_id, 700 + assertions)
		_assert(bool(completion.get("accepted", false)), "%s completes end to end" % adventure_id)
		_assert(float(completion.get("score", 0.0)) >= 0.75, "%s records a strong session score" % adventure_id)
		_assert(bool(completion.get("transfer_mastered", false)), "%s masters its transfer task" % adventure_id)
		_assert(int(completion.get("xp_reward", 0)) > 0, "%s grants a positive gameplay reward" % adventure_id)
		var impact: Dictionary = completion.get("impact", {}) as Dictionary
		_assert(impact.has("technique"), "%s affects partner technique learning" % adventure_id)
		_assert(int(impact.get("settlement_xp", 0)) > 0, "%s affects settlement progress" % adventure_id)
		var profile: Dictionary = learning.call("get_mastery_profile", adventure_id) as Dictionary
		_assert(int(profile.get("sessions", 0)) >= 1, "%s persists a mastery session" % adventure_id)
	var snapshot: Dictionary = learning.call("get_snapshot") as Dictionary
	_assert(int(snapshot.get("total_completed_sessions", 0)) >= 12, "all twelve completed sessions are counted")
	_assert(int(snapshot.get("total_transfer_masteries", 0)) >= 12, "all twelve transfer masteries are counted")

func _test_recoverable_failure(learning: Node) -> void:
	var before: Dictionary = learning.call("get_mastery_profile", "pattern_relay") as Dictionary
	var old_rating: float = float(before.get("rating", 20.0))
	var started: Dictionary = learning.call("start_adventure", "pattern_relay", 404) as Dictionary
	_assert(bool(started.get("accepted", false)), "failure-path session starts")
	var completion: Dictionary = {}
	while not (learning.call("get_active_session") as Dictionary).is_empty():
		var session: Dictionary = learning.call("get_active_session") as Dictionary
		var round_data: Dictionary = session.get("current_round", {}) as Dictionary
		var result: Dictionary = {}
		if str(round_data.get("mechanic", "choice")) == "timing":
			result = learning.call("submit_timing", 0.0) as Dictionary
		else:
			var worst_index: int = _worst_index(round_data.get("scores", []) as Array)
			result = learning.call("submit_choice", worst_index) as Dictionary
		if bool(result.get("session_complete", false)):
			completion = result.get("completion", {}) as Dictionary
	_assert(not bool(completion.get("success", true)), "weak answers produce a non-success result")
	var new_rating: float = float(completion.get("rating", old_rating))
	_assert(new_rating >= old_rating - 3.5, "failure cannot collapse mastery by more than the recovery limit")
	var retry: Dictionary = learning.call("start_adventure", "pattern_relay", 405) as Dictionary
	_assert(bool(retry.get("accepted", false)), "a failed adventure remains immediately retryable")
	learning.call("abandon_session")

func _test_adaptive_growth(learning: Node) -> void:
	var before: Dictionary = learning.call("get_mastery_profile", "number_constellation") as Dictionary
	var rating_before: float = float(before.get("rating", 20.0))
	var first_start: Dictionary = learning.call("start_adventure", "number_constellation", 501) as Dictionary
	var difficulty_before: int = int((first_start.get("session", {}) as Dictionary).get("difficulty", 1))
	learning.call("abandon_session")
	for index: int in range(3):
		_play_best_session(learning, "number_constellation", 510 + index)
	var after: Dictionary = learning.call("get_mastery_profile", "number_constellation") as Dictionary
	_assert(float(after.get("rating", 0.0)) > rating_before, "repeated strong play increases mastery rating")
	var next_start: Dictionary = learning.call("start_adventure", "number_constellation", 520) as Dictionary
	var difficulty_after: int = int((next_start.get("session", {}) as Dictionary).get("difficulty", 1))
	_assert(difficulty_after >= difficulty_before, "adaptive difficulty does not fall after repeated mastery")
	learning.call("abandon_session")

func _test_persistence(learning: Node) -> void:
	var exported: Dictionary = learning.call("export_state") as Dictionary
	var completed_before: int = int(exported.get("total_completed_sessions", 0))
	learning.call("reset_state")
	_assert(int((learning.call("get_snapshot") as Dictionary).get("total_completed_sessions", -1)) == 0, "reset clears Learning Adventure progress")
	learning.call("import_state", exported)
	var restored: Dictionary = learning.call("get_snapshot") as Dictionary
	_assert(int(restored.get("total_completed_sessions", 0)) == completed_before, "export/import restores completed sessions")
	_assert(int(restored.get("catalog", []).size()) == 12, "export/import preserves the complete catalog")
	_assert(bool(learning.call("save_state")), "Learning Adventures save atomically")

func _test_audio_and_ui(learning: Node) -> void:
	var audio: Node = root.get_node_or_null("OmniAudio")
	_assert(audio != null, "OmniAudio remains available")
	if audio != null:
		audio.call("set_environment", "LEARNING_ADVENTURE")
		var status: Dictionary = audio.call("get_audio_status") as Dictionary
		_assert(str(status.get("environment", "")) == "LEARNING_ADVENTURE", "learning hub has a dedicated ambience")
		_assert((status.get("learning_cue_types", []) as Array).size() >= 7, "audio exposes at least seven semantic learning cues")
		var before: int = int(status.get("learning_cues", 0))
		audio.call("play_learning_cue", "transfer", 0.9)
		var after: Dictionary = audio.call("get_audio_status") as Dictionary
		_assert(int(after.get("learning_cues", 0)) == before + 1, "transfer schedules a dedicated learning cue")
		_assert(int(after.get("transfer_cues", 0)) >= 1, "transfer cue is counted separately")
		audio.call("stop_all")

	root.size = Vector2i(390, 844)
	var packed: PackedScene = load("res://main.tscn") as PackedScene
	_assert(packed != null, "premium main scene loads with Wave 5")
	if packed == null:
		return
	var main: Node = packed.instantiate()
	root.add_child(main)
	await _settle(8)
	var overlay: Node = root.get_node_or_null("LearningAdventureOverlay")
	_assert(overlay != null, "Learning Adventure overlay autoload exists")
	if overlay != null:
		overlay.call("open_catalog")
		await _settle(5)
		var hub_layout: Dictionary = overlay.call("get_layout_snapshot") as Dictionary
		_assert(bool(hub_layout.get("visible", false)), "learning hub opens fullscreen")
		_assert(bool(hub_layout.get("compact", false)), "390-pixel viewport selects compact layout")
		_assert(int(hub_layout.get("hub_columns", 0)) == 1, "phone hub uses one readable card column")
		_assert(int(hub_layout.get("catalog_cards", 0)) == 12, "phone hub renders all twelve adventure cards")
		overlay.call("open_adventure", "resonance_rhythm")
		await _settle(4)
		var session_layout: Dictionary = overlay.call("get_layout_snapshot") as Dictionary
		_assert(bool(session_layout.get("session_visible", false)), "adventure session replaces hub without a second modal")
		_assert(bool(session_layout.get("timing_active", false)), "rhythm adventure activates the timing mechanic")
		_assert(str(session_layout.get("current_adventure", "")) == "resonance_rhythm", "session reports the active adventure")
		overlay.call("close_overlay")
	var learning_overlay: Node = root.get_node_or_null("LearningOverlay")
	_assert(learning_overlay != null and learning_overlay.get_script().resource_path.ends_with("learning_overlay_v2.gd"), "existing Learn action routes through the Wave 5 bridge")
	main.queue_free()
	await process_frame
	learning.call("abandon_session")

func _play_best_session(learning: Node, adventure_id: String, seed_value: int) -> Dictionary:
	var started: Dictionary = learning.call("start_adventure", adventure_id, seed_value) as Dictionary
	if not bool(started.get("accepted", false)):
		return {}
	var completion: Dictionary = {}
	while not (learning.call("get_active_session") as Dictionary).is_empty():
		var session: Dictionary = learning.call("get_active_session") as Dictionary
		var round_data: Dictionary = session.get("current_round", {}) as Dictionary
		var result: Dictionary = {}
		if str(round_data.get("mechanic", "choice")) == "timing":
			result = learning.call("submit_timing", float(round_data.get("target", 0.5))) as Dictionary
		else:
			var best_index: int = _best_index(round_data.get("scores", []) as Array)
			result = learning.call("submit_choice", best_index) as Dictionary
		if bool(result.get("session_complete", false)):
			completion = result.get("completion", {}) as Dictionary
	return completion

func _best_index(scores: Array) -> int:
	var best_index: int = 0
	var best_score: float = -1.0
	for index: int in range(scores.size()):
		if float(scores[index]) > best_score:
			best_score = float(scores[index])
			best_index = index
	return best_index

func _worst_index(scores: Array) -> int:
	var worst_index: int = 0
	var worst_score: float = 2.0
	for index: int in range(scores.size()):
		if float(scores[index]) < worst_score:
			worst_score = float(scores[index])
			worst_index = index
	return worst_index

func _settle(count: int) -> void:
	for _index: int in range(count):
		await process_frame

func _assert(condition: bool, description: String) -> void:
	assertions += 1
	if condition:
		print("[CI-WAVE5] PASS: %s" % description)
	else:
		failures.append(description)
		push_error("[CI-WAVE5] FAIL: %s" % description)

func _finish() -> void:
	if failures.is_empty():
		print("[CI-WAVE5] PASS: %d assertions" % assertions)
		quit(0)
	else:
		print("[CI-WAVE5] BLOCKED: %d of %d assertions failed" % [failures.size(), assertions])
		quit(1)
