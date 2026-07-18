extends SceneTree

var failures: Array[String] = []
var assertions: int = 0

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	_test_contextual_dialogue()
	_test_haptic_patterns()
	_test_controlled_trait_nudge()
	_test_exploration_choice_personality()
	_test_runtime_overlays()
	_test_bitling_identity()
	_test_emotion_model()
	_test_bitling_language_and_voice()
	_test_social_consent_and_exchange()
	_test_lineage_and_eggs()
	_test_dialogue_save_roundtrip()
	_test_social_save_roundtrip()
	if failures.is_empty():
		print("[CI-XP] PASS: %d assertions" % assertions)
		quit(0)
		return
	push_error("[CI-XP] FAIL: %d of %d assertions failed" % [failures.size(), assertions])
	for failure in failures:
		push_error("[CI-XP]   - %s" % failure)
	quit(1)

func _test_contextual_dialogue() -> void:
	var director := root.get_node_or_null("DialogueDirector")
	_assert(director != null, "DialogueDirector autoload exists")
	if director == null:
		return
	director.reset_state()
	var first := str(director.compose("care", {"test": 1}))
	var second := str(director.compose("care", {"test": 2}))
	_assert(not first.is_empty(), "DialogueDirector produces a care reaction")
	_assert(first != second, "Immediate contextual dialogue does not repeat")
	var guard := root.get_node_or_null("WellbeingGuard")
	_assert(guard != null and guard.validate_player_message(first), "Generated dialogue passes wellbeing guard")
	var exported: Dictionary = director.export_state()
	director.reset_state()
	director.import_state(exported)
	_assert(not director.recent_line_ids.is_empty(), "Dialogue history survives export/import")

func _test_haptic_patterns() -> void:
	var haptics := root.get_node_or_null("HapticService")
	_assert(haptics != null, "HapticService autoload exists")
	if haptics == null:
		return
	var success_pattern: Dictionary = haptics.get_pattern("success")
	_assert(int(success_pattern.get("duration", 0)) > 0, "Success haptic has a positive duration")
	_assert(float(success_pattern.get("amplitude", 0.0)) > 0.0, "Success haptic has a positive amplitude")
	_assert(haptics.get_pattern("unknown").is_empty(), "Unknown haptic pattern fails closed")

func _test_controlled_trait_nudge() -> void:
	var brain := root.get_node_or_null("CompanionBrain")
	_assert(brain != null, "CompanionBrain autoload exists")
	if brain == null:
		return
	brain.reset_state()
	var old_value := float(brain.personality.get("curiosity", 0.0))
	_assert(brain.nudge_trait("curiosity", 1.0), "Known trait can be nudged")
	_assert(float(brain.personality.get("curiosity", 0.0)) > old_value, "Trait nudge changes personality")
	_assert(not brain.nudge_trait("missing_trait", 1.0), "Unknown trait is rejected")

func _test_exploration_choice_personality() -> void:
	var exploration := root.get_node_or_null("ExplorationService")
	var brain := root.get_node_or_null("CompanionBrain")
	_assert(exploration != null and brain != null, "Exploration and companion services exist")
	if exploration == null or brain == null:
		return
	brain.reset_state()
	exploration.reset_state()
	var stage: Dictionary = exploration.start_expedition(31337)
	var choices: Array = stage.get("choices", [])
	_assert(not choices.is_empty(), "Expedition stage exposes choices")
	if choices.is_empty():
		return
	var trait_name := str(choices[0].get("trait", ""))
	var old_value := float(brain.personality.get(trait_name, 0.0))
	var result: Dictionary = exploration.choose(0)
	_assert(bool(result.get("accepted", false)), "Expedition choice is accepted")
	_assert(float(brain.personality.get(trait_name, 0.0)) > old_value, "Expedition choice shapes its declared trait")

func _test_runtime_overlays() -> void:
	for node_name in ["DialogueToast", "LearningOverlay", "ExplorationOverlay", "EvolutionOverlay"]:
		_assert(root.has_node(node_name), "%s autoload exists" % node_name)

func _test_bitling_identity() -> void:
	var identity := root.get_node_or_null("BitlingIdentity")
	_assert(identity != null, "BitlingIdentity autoload exists")
	if identity == null:
		return
	identity.reset_state()
	var public_card: Dictionary = identity.get_public_passport()
	_assert(not str(public_card.get("bitling_id", "")).is_empty(), "Passport has a stable Bitling ID")
	_assert(not public_card.has("portrait_reference"), "Public passport excludes local portrait path")
	_assert(identity.set_display_name("Nova"), "Passport display name can be updated")
	identity.set_portrait_reference("user://portraits/nova.png")
	_assert(not identity.get_public_passport().has("portrait_reference"), "Portrait remains private after assignment")
	var refreshed: Dictionary = identity.refresh_development_metrics(25, "CHILD", "prism", 55.0, 70.0)
	_assert(float(refreshed.get("height_cm", 0.0)) > 0.0, "Passport tracks height")
	_assert(int(refreshed.get("weight_g", 0)) > 0, "Passport tracks weight")
	_assert(int(refreshed.get("cognitive_index", 0)) >= 40, "Passport exposes fictional cognitive index")

func _test_emotion_model() -> void:
	var emotions := root.get_node_or_null("EmotionModel")
	_assert(emotions != null, "EmotionModel autoload exists")
	if emotions == null:
		return
	emotions.reset_state()
	var before: Dictionary = emotions.get_snapshot()
	var after: Dictionary = emotions.apply_event("play", 1.0)
	_assert(float(after.get("arousal", 0.0)) > float(before.get("arousal", 0.0)), "Play raises simulated arousal")
	var perceived: Dictionary = emotions.perceive_peer_emotion({
		"dominant_emotion": "joy",
		"valence": 0.8,
		"arousal": 0.7
	}, 0.8)
	_assert(not str(perceived.get("dominant_emotion", "")).is_empty(), "Peer emotion produces a bounded local response")
	var exported: Dictionary = emotions.export_state()
	emotions.reset_state()
	emotions.import_state(exported)
	_assert(not emotions.recent_events.is_empty(), "Emotion history survives export/import")

func _test_bitling_language_and_voice() -> void:
	var language := root.get_node_or_null("BitlingLanguage")
	var emotions := root.get_node_or_null("EmotionModel")
	_assert(language != null, "BitlingLanguage autoload exists")
	if language == null:
		return
	var emotion_snapshot: Dictionary = emotions.get_snapshot() if emotions != null else {}
	var packet: Dictionary = language.create_packet("tell_joke", {"topic": "bananas"}, emotion_snapshot)
	_assert(language.validate_packet(packet), "Generated Bitling language packet validates")
	_assert(not str(language.render_utterance(packet)).is_empty(), "Bitling packet renders as audible gibberish")
	var voice: Dictionary = language.get_voice_profile(emotion_snapshot)
	_assert(str(voice.get("style", "")) == "original_playful_gibberish", "Voice profile is explicitly original")
	_assert(float(voice.get("pitch_scale", 0.0)) > 0.0, "Voice profile contains mood-adjusted pitch")
	var tampered := packet.duplicate(true)
	tampered["intent"] = "unsupported"
	_assert(not language.validate_packet(tampered), "Tampered language packet is rejected")

func _test_social_consent_and_exchange() -> void:
	var social := root.get_node_or_null("SocialSessionService")
	_assert(social != null, "SocialSessionService autoload exists")
	if social == null:
		return
	social.reset_state()
	var offer: Dictionary = social.create_pairing_offer()
	_assert(not offer.is_empty(), "Social service creates expiring pairing offer")
	var accepted: Dictionary = social.accept_pairing_offer(offer, str(offer.get("pair_code", "")))
	_assert(bool(accepted.get("accepted", false)), "Matching pair code starts social session")
	_assert(social.create_social_packet("greet").is_empty(), "Data packets are blocked before mutual consent")
	social.set_local_consent("data", true)
	social.receive_remote_consent("data", true)
	var packet: Dictionary = social.create_social_packet("share_discovery", {
		"topic": "patterns",
		"summary": "Alternating signals repeat every two steps."
	})
	_assert(not packet.is_empty(), "Mutual data consent enables social packet")
	var decoded: Dictionary = social.receive_social_packet(packet)
	_assert(bool(decoded.get("accepted", false)), "Validated social packet is received")
	_assert(not social.peer_insights.is_empty(), "Social discovery creates bounded peer insight")
	_assert(not social.can_start_video(), "Video remains blocked without supported transport and consent")
	social.end_session("test_complete")
	_assert(not social.session_active, "Social session can be terminated cleanly")

func _test_lineage_and_eggs() -> void:
	var lineage := root.get_node_or_null("LineageService")
	var state := root.get_node_or_null("GameState")
	var brain := root.get_node_or_null("CompanionBrain")
	var identity := root.get_node_or_null("BitlingIdentity")
	_assert(lineage != null and state != null and brain != null and identity != null, "Lineage dependencies exist")
	if lineage == null or state == null or brain == null or identity == null:
		return
	lineage.reset_state()
	state.phase = state.Phase.ADULT
	state.level = 60
	brain.relationship_score = 80.0
	brain.trust = 80.0
	identity.refresh_development_metrics(60, "ADULT", "weaver", 65.0, 70.0)
	var remote_profile := {
		"bitling_id": "BTL-REMOTE-001",
		"display_name": "Lumo",
		"generation": 2,
		"phase": "ADULT",
		"form_id": "guardian",
		"relationship": 80.0,
		"trust": 80.0,
		"personality": {
			"curiosity": 65.0, "empathy": 70.0, "courage": 60.0,
			"humor": 75.0, "order": 45.0, "creativity": 68.0, "independence": 52.0
		}
	}
	var denied: Dictionary = lineage.create_resonance_egg(remote_profile, {"local": true, "remote": false, "session_id": "SOC-1"})
	_assert(not bool(denied.get("accepted", false)), "Egg creation requires mutual consent")
	var egg: Dictionary = lineage.create_resonance_egg(remote_profile, {"local": true, "remote": true, "session_id": "SOC-1"})
	_assert(bool(egg.get("accepted", false)), "Mature mutually consenting Bitlings can create an egg")
	_assert(not str(egg.get("egg_id", "")).is_empty(), "Egg receives a unique ID")
	var egg_id := str(egg.get("egg_id", ""))
	for _step in range(4):
		lineage.nurture_egg(egg_id, 25.0)
	var hatched: Dictionary = lineage.hatch_egg(egg_id, "Piko")
	_assert(bool(hatched.get("accepted", false)), "Fully nurtured egg can hatch")
	_assert(int(hatched.get("hatchling", {}).get("generation", 0)) == 3, "Hatchling generation follows parent lineage")

func _test_dialogue_save_roundtrip() -> void:
	var state := root.get_node_or_null("GameState")
	var director := root.get_node_or_null("DialogueDirector")
	_assert(state != null and director != null, "Save and dialogue services exist")
	if state == null or director == null:
		return
	director.reset_state()
	director.compose("rest", {"roundtrip": true})
	_assert(state.save_game_state(), "Dialogue fixture saves")
	director.reset_state()
	_assert(state.load_game_state(), "Dialogue fixture loads")
	_assert(not director.recent_line_ids.is_empty(), "Dialogue anti-repeat history survives game save")

func _test_social_save_roundtrip() -> void:
	var state := root.get_node_or_null("GameState")
	var identity := root.get_node_or_null("BitlingIdentity")
	var emotions := root.get_node_or_null("EmotionModel")
	var lineage := root.get_node_or_null("LineageService")
	var social := root.get_node_or_null("SocialSessionService")
	_assert(state != null and identity != null and emotions != null and lineage != null and social != null, "Social persistence dependencies exist")
	if state == null or identity == null or emotions == null or lineage == null or social == null:
		return
	identity.set_display_name("Persisto")
	emotions.apply_event("care", 1.0)
	var saved_id := str(identity.get_public_passport().get("bitling_id", ""))
	var saved_egg_count: int = lineage.eggs.size()
	_assert(state.save_game_state(), "Social identity and lineage fixture saves")
	identity.reset_state()
	emotions.reset_state()
	lineage.reset_state()
	social.create_pairing_offer()
	_assert(state.load_game_state(), "Social identity and lineage fixture loads")
	_assert(str(identity.get_public_passport().get("bitling_id", "")) == saved_id, "Bitling identity survives game save")
	_assert(lineage.eggs.size() == saved_egg_count, "Egg lineage survives game save")
	_assert(not emotions.recent_events.is_empty(), "Emotion state survives game save")
	_assert(not social.session_active, "Social consent and sessions do not survive restart")

func _assert(condition: bool, description: String) -> void:
	assertions += 1
	if not condition:
		failures.append(description)
