extends SceneTree

var failures: Array[String] = []
var assertions: int = 0

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	_test_safe_defaults()
	_test_state_invariants_under_load()
	_test_memory_bound()
	_test_authoritative_profile_roundtrip()
	_test_backup_recovery()
	_test_binary_legacy_migration()
	_test_social_packet_fuzzing()
	_test_autonomy_stability()
	_test_localization_contract()
	_test_public_summary_contract()
	if failures.is_empty():
		print("[CI-RELEASE] PASS: %d assertions" % assertions)
		quit(0)
		return
	push_error("[CI-RELEASE] FAIL: %d of %d assertions failed" % [failures.size(), assertions])
	for failure in failures:
		push_error("[CI-RELEASE]   - %s" % failure)
	quit(1)

func _test_safe_defaults() -> void:
	var state := root.get_node("GameState")
	_assert(not bool(state.settings.get("notifications_enabled", true)), "Notifications default to opt-in")
	_assert(not bool(state.settings.get("social_discovery_enabled", true)), "Social discovery defaults to disabled")
	_assert(not bool(state.settings.get("voice_chat_enabled", true)), "Voice chat defaults to disabled")
	_assert(not bool(state.settings.get("video_chat_enabled", true)), "Video chat defaults to disabled")
	_assert(not bool(state.settings.get("share_public_passport", true)), "Passport sharing defaults to disabled")

func _test_state_invariants_under_load() -> void:
	var state := root.get_node("GameState")
	state.initialize_new_game()
	var rng := RandomNumberGenerator.new()
	rng.seed = 9042026
	var started := Time.get_ticks_msec()
	for index in range(1500):
		state.update_stats(
			rng.randf_range(-8.0, 8.0),
			rng.randf_range(-8.0, 8.0),
			rng.randf_range(-8.0, 8.0),
			rng.randf_range(-8.0, 8.0),
			rng.randf_range(-4.0, 4.0)
		)
		if index % 5 == 0:
			state.gain_xp(rng.randi_range(1, 35), "release_stress")
	var elapsed := Time.get_ticks_msec() - started
	for value in [state.hunger, state.energy, state.happiness, state.curiosity, state.health]:
		var number := float(value)
		_assert(number >= 0.0 and number <= 100.0, "Needs remain clamped after randomized load")
		_assert(not is_nan(number) and not is_inf(number), "Needs never become NaN or infinite")
	_assert(int(state.level) >= 1 and int(state.level) <= int(state.MAX_LEVEL), "Level remains in supported range")
	_assert(elapsed < 8000, "Core randomized simulation completes within a generous CI budget")

func _test_memory_bound() -> void:
	var state := root.get_node("GameState")
	state.memories.clear()
	for index in range(120):
		state.add_memory("stress_%d" % index, "Unique memory %d" % index)
	_assert(state.memories.size() == 50, "Long-term memory remains bounded to 50 entries")
	_assert(str(state.memories.front().get("type", "")) == "stress_70", "Memory eviction removes oldest entries first")

func _test_authoritative_profile_roundtrip() -> void:
	var state := root.get_node("GameState")
	var profile := root.get_node("DevelopmentProfile")
	state.initialize_new_game()
	var tags: Array[String] = ["social", "discipline"]
	for _index in range(12):
		profile.record_interaction("teach_peer", tags, 3.0)
	var expected_iq := int(profile.get_intelligence_quotient())
	var expected_teaching: Dictionary = profile.skills.get("teaching", {}).duplicate(true)
	_assert(state.save_game_state(), "Authoritative game save succeeds with development profile")
	profile.intelligence_quotient = 40
	profile.skills["teaching"] = {"level": 1, "xp": 0.0, "rating": 0.0}
	_assert(state.load_game_state(), "Authoritative game save reloads")
	_assert(int(profile.get_intelligence_quotient()) == expected_iq, "Individual IQ survives the main save roundtrip")
	_assert(int(profile.skills.get("teaching", {}).get("level", 0)) == int(expected_teaching.get("level", -1)), "Development skills survive the main save roundtrip")

func _test_backup_recovery() -> void:
	var state := root.get_node("GameState")
	_remove_if_present(state.SAVE_PATH)
	_remove_if_present(state.BACKUP_SAVE_PATH)
	_remove_if_present(state.LEGACY_SAVE_PATH)
	state.initialize_new_game()
	state.level = 21
	_assert(state.save_game_state(), "First recovery fixture saves")
	state.level = 22
	_assert(state.save_game_state(), "Second recovery fixture creates backup")
	var damaged := FileAccess.open(state.SAVE_PATH, FileAccess.WRITE)
	_assert(damaged != null, "Primary save can be replaced by corruption fixture")
	if damaged != null:
		damaged.store_string("{not-valid-json")
		damaged.close()
	state.level = 1
	_assert(state.load_game_state(), "Corrupt primary save falls back to backup")
	_assert(int(state.level) == 21, "Backup recovery restores the last known-good state")

func _test_binary_legacy_migration() -> void:
	var state := root.get_node("GameState")
	_remove_if_present(state.SAVE_PATH)
	_remove_if_present(state.BACKUP_SAVE_PATH)
	_remove_if_present(state.LEGACY_SAVE_PATH)
	var legacy := FileAccess.open(state.LEGACY_SAVE_PATH, FileAccess.WRITE)
	_assert(legacy != null, "Legacy binary fixture opens")
	if legacy == null:
		return
	legacy.store_var({
		"level": 17,
		"xp": 33,
		"total_xp": 1233,
		"phase": int(state.Phase.CHILD),
		"era": int(state.Era.PIXEL),
		"mood": int(state.Mood.CONTENT),
		"story_flags": {"hatched": true}
	}, true)
	legacy.close()
	state.level = 1
	_assert(state.load_game_state(), "Binary .dat save migrates successfully")
	_assert(int(state.level) == 17 and int(state.xp) == 33, "Legacy migration preserves progression")
	_assert(state.save_game_state(), "Migrated legacy data is rewritten as current JSON")

func _test_social_packet_fuzzing() -> void:
	var language := root.get_node("BitlingLanguage")
	var valid: Dictionary = language.create_packet("greet", {"topic": "signals"}, {"dominant_emotion": "joy"})
	_assert(language.validate_packet(valid), "Baseline social language packet validates")
	var mutations: Array[Dictionary] = []
	var bad_protocol := valid.duplicate(true)
	bad_protocol["protocol"] = -1
	mutations.append(bad_protocol)
	var bad_intent := valid.duplicate(true)
	bad_intent["intent"] = "execute_code"
	mutations.append(bad_intent)
	var empty_speaker := valid.duplicate(true)
	empty_speaker["speaker_id"] = ""
	mutations.append(empty_speaker)
	var bad_integrity := valid.duplicate(true)
	bad_integrity["integrity"] = int(valid.get("integrity", 0)) + 1
	mutations.append(bad_integrity)
	var oversized := valid.duplicate(true)
	oversized["payload"] = {"blob": "x".repeat(int(language.MAX_PAYLOAD_BYTES) + 100)}
	mutations.append(oversized)
	for packet in mutations:
		_assert(not language.validate_packet(packet), "Malformed social packet fails closed")

func _test_autonomy_stability() -> void:
	var profile := root.get_node("DevelopmentProfile")
	profile.reset_state()
	for key in ["discipline", "routine", "independence", "self_control"]:
		profile.train_upbringing(str(key), 80.0)
	var allowed := ["practice_hobby", "self_care", "invent_game", "study", "teach_peer", "wait_for_guidance"]
	for _index in range(200):
		var action: Dictionary = profile.choose_autonomous_action(true)
		_assert(allowed.has(str(action.get("id", ""))), "Autonomy only selects allowlisted actions")
		var efficiency := float(action.get("efficiency", 0.0))
		_assert(efficiency >= 0.0 and efficiency <= 1.0, "Autonomous efficiency remains bounded")

func _test_localization_contract() -> void:
	var bridge := root.get_node("LanguageBridge")
	for locale in ["de", "en", "es", "fr", "it", "pt", "pl", "tr", "ru", "ja", "ko", "zh", "ar", "hi"]:
		var greeting := str(bridge.translate_intent("greet", locale))
		_assert(not greeting.is_empty() and greeting != "intent.greet", "Every advertised locale resolves the greeting intent")
	var fallback := str(bridge.translate_intent("greet", "zz-unknown"))
	_assert(fallback.contains("Hello"), "Unknown locales retain meaning through English fallback")

func _test_public_summary_contract() -> void:
	var state := root.get_node("GameState")
	var profile := root.get_node("DevelopmentProfile")
	var summary: Dictionary = state.get_state_summary()
	_assert(summary.has("intelligence_quotient"), "Public state summary exposes the individual Bitling IQ")
	_assert(not summary.has("cognitive_index"), "Deprecated cognitive-index label is absent from public state")
	_assert(int(summary.get("intelligence_quotient", -1)) == int(profile.get_intelligence_quotient()), "Summary and development profile agree on IQ")

func _remove_if_present(path: String) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)

func _assert(condition: bool, description: String) -> void:
	assertions += 1
	if not condition:
		failures.append(description)
