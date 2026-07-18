extends SceneTree

var failures: Array[String] = []
var assertions: int = 0

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	_test_individual_iq_and_passport()
	_test_specialization_ranks()
	_test_upbringing_and_autonomy()
	_test_preferences_and_affinity()
	_test_age_adaptation()
	_test_language_bridge()
	_test_rarity_and_profile_ui()
	if failures.is_empty():
		print("[CI-DEV] PASS: %d assertions" % assertions)
		quit(0)
		return
	push_error("[CI-DEV] FAIL: %d of %d assertions failed" % [failures.size(), assertions])
	for failure in failures:
		push_error("[CI-DEV]   - %s" % failure)
	quit(1)

func _test_individual_iq_and_passport() -> void:
	var profile := root.get_node_or_null("DevelopmentProfile")
	var identity := root.get_node_or_null("BitlingIdentity")
	_assert(profile != null and identity != null, "Development profile and identity autoloads exist")
	if profile == null or identity == null:
		return
	profile.reset_state()
	var iq := int(profile.get_intelligence_quotient())
	var passport: Dictionary = identity.get_public_passport()
	_assert(iq >= 40 and iq <= 220, "Individual Bitling IQ stays in the supported range")
	_assert(int(passport.get("intelligence_quotient", -1)) == iq, "Passport shows the Bitling's own IQ")
	_assert(not passport.has("portrait_reference"), "Public passport still excludes local portrait data")

func _test_specialization_ranks() -> void:
	var profile := root.get_node("DevelopmentProfile")
	profile.reset_state()
	var bronze: Dictionary = profile.progress_specialization("mentor", 10.0)
	_assert(int(bronze.get("rank", -1)) == profile.RANK_BRONZE, "New specialization starts at Bronze")
	var silver: Dictionary = profile.progress_specialization("mentor", 200.0)
	_assert(int(silver.get("rank", -1)) == profile.RANK_SILVER, "Specialization advances to Silver")
	var platinum: Dictionary = profile.progress_specialization("mentor", 1400.0)
	_assert(int(platinum.get("rank", -1)) == profile.RANK_PLATINUM, "Specialization can reach Platinum")
	_assert(profile.get_rank_name(profile.RANK_PLATINUM) == "PLATIN", "Platinum rank has the expected display name")

func _test_upbringing_and_autonomy() -> void:
	var profile := root.get_node("DevelopmentProfile")
	profile.reset_state()
	var initial := float(profile.get_autonomy_score())
	profile.train_upbringing("discipline", 70.0)
	profile.train_upbringing("routine", 70.0)
	profile.train_upbringing("independence", 70.0)
	profile.train_upbringing("self_control", 70.0)
	var trained := float(profile.get_autonomy_score())
	_assert(trained > initial, "Discipline and routine improve autonomy")
	_assert(profile.can_self_entertain(), "Well-raised Bitling can entertain itself")
	for index in range(12):
		profile.record_interaction("teach_peer", ["social"], 5.0)
	_assert(profile.can_teach_peer(), "Highly trained Bitling can teach another Bitling")
	var action: Dictionary = profile.choose_autonomous_action(true)
	_assert(not str(action.get("id", "")).is_empty(), "Autonomous Bitling chooses a valid action")
	_assert(float(action.get("efficiency", 0.0)) > 0.35, "Training improves autonomous efficiency")

func _test_preferences_and_affinity() -> void:
	var profile := root.get_node("DevelopmentProfile")
	profile.reset_state()
	var own: Dictionary = profile.get_display_snapshot()
	var same: Dictionary = profile.calculate_affinity(own)
	_assert(float(same.get("score", 0.0)) >= 95.0, "Very similar Bitlings strongly like each other")
	var different := {
		"preferences": {"hobbies": ["Ganz anderes Hobby"], "favorite_food": "Anderes Essen", "conversation_style": "anders"},
		"attributes": {"intelligence": 0.0, "empathy": 0.0, "humor": 0.0},
		"skills": {"logic": {"rating": 100.0}}
	}
	var low: Dictionary = profile.calculate_affinity(different)
	_assert(float(low.get("score", 100.0)) < float(same.get("score", 0.0)), "Different preferences reduce affinity")
	var encounter: Dictionary = profile.register_social_encounter("BTL-PEER-1", own)
	_assert(bool(encounter.get("accepted", false)), "Social encounter is accepted for another Bitling")
	_assert(str(profile.favorite_bitling_id) == "BTL-PEER-1", "High-affinity peer can become favorite Bitling")

func _test_age_adaptation() -> void:
	var profile := root.get_node("DevelopmentProfile")
	_assert(profile.set_player_age_band("child"), "Child age band can be selected")
	var child_style: Dictionary = profile.get_age_adjusted_style()
	_assert(float(child_style.get("complexity", 1.0)) < 0.5, "Child dialogue uses lower complexity")
	_assert(not bool(child_style.get("sensitive_topics", true)), "Child mode disables sensitive topics")
	_assert(not profile.set_player_age_band("invalid"), "Unknown age band is rejected")
	_assert(profile.set_player_age_band("senior"), "Senior age band can be selected")

func _test_language_bridge() -> void:
	var bridge := root.get_node_or_null("LanguageBridge")
	_assert(bridge != null, "LanguageBridge autoload exists")
	if bridge == null:
		return
	_assert(bridge.translate_intent("greet", "de").contains("Hallo"), "German intent translation is available")
	var fallback := str(bridge.translate_intent("greet", "xx-unknown"))
	_assert(fallback.contains("Hello"), "Unknown locale falls back without losing meaning")
	var speech: Dictionary = bridge.render_bitling_speech("invite_play", {"emotion": "joy"}, "de")
	_assert(not str(speech.get("bitling_utterance", "")).is_empty(), "Bitling speech contains a fictional utterance")
	_assert(not str(speech.get("subtitle", "")).is_empty(), "Bitling speech remains translatable")
	var lesson: Dictionary = bridge.create_bitling_language_lesson(1, "de")
	_assert(not str(lesson.get("meaning", "")).is_empty(), "Bitling language can be taught to the player")

func _test_rarity_and_profile_ui() -> void:
	var profile := root.get_node("DevelopmentProfile")
	var rarity: Dictionary = profile.get_display_snapshot().get("rarity", {})
	_assert(["COMMON", "UNCOMMON", "RARE", "LEGENDARY"].has(str(rarity.get("tier", ""))), "Rarity tier is valid")
	var visual: Dictionary = profile.get_rarity_visual_profile()
	_assert(visual.has("shimmer") and visual.has("glow") and visual.has("sparkles"), "Rarity provides a visual shimmer profile")
	_assert(root.has_node("ProfileOverlay"), "Responsive passport and development overlay exists")

func _assert(condition: bool, description: String) -> void:
	assertions += 1
	if not condition:
		failures.append(description)
