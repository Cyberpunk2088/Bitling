extends SceneTree

var failures: Array[String] = []
var assertions: int = 0
var state: Node

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	# macOS ignores XDG_DATA_HOME. Its fixture must be a separate named custom
	# user directory, with a runner-created marker and matching random token.
	var token := OS.get_environment("BITLING_TEST_TOKEN")
	var isolated_mac := OS.get_name() == "macOS" and OS.get_user_data_dir().get_file().begins_with("BitlingRepairTests-") and token.length() >= 32 and FileAccess.file_exists("user://.bitling-test-fixture") and FileAccess.get_file_as_string("user://.bitling-test-fixture") == token
	if OS.get_environment("BITLING_TEST_ISOLATED") != "1" or not (OS.get_user_data_dir().begins_with("/tmp/") or isolated_mac):
		push_error("Use BITLING_TEST_ISOLATED=1 with isolated /tmp data, or the marked BitlingRepairTests macOS fixture.")
		quit(2)
		return
	state = root.get_node("GameState")
	state.set_process(false)
	_test_future_and_corrupt_startup()
	_test_pending_recovery()
	_test_payload_validation_before_mutation()
	_test_good_roundtrip_and_migration()
	print("[SAVE-REGRESSION] %d assertions, %d failures; %s" % [assertions, failures.size(), OS.get_user_data_dir()])
	for failure: String in failures:
		push_error(failure)
	quit(0 if failures.is_empty() else 1)

func _test_future_and_corrupt_startup() -> void:
	for suffix: String in [".json", ".backup.json", ".tmp", ".dat"]:
		_clear_fixture()
		var path: String = "user://bitling_save" + suffix
		_write(path, JSON.stringify({"schema_version": 999, "level": 73, "future_marker": "preserve"}))
		var before: String = FileAccess.get_file_as_string(path)
		state.call("_ready")
		_expect(state.get("save_blocked") == true, "Future schema blocks startup writes: " + suffix)
		var before_progress: Array = [state.level, state.xp, state.hunger, state.story_flags.duplicate(true), state.memories.duplicate(true)]
		state.hatch()
		state.gain_xp(300, "blocked_regression")
		state.perform_interaction("care", {"hunger": 10.0}, 12)
		state.update_stats(5.0)
		state.add_memory("blocked", "Must not mutate a blocked session")
		state.apply_save_data({"level": 55, "story_flags": {"hatched": true}})
		_expect([state.level, state.xp, state.hunger, state.story_flags, state.memories] == before_progress, "Blocked session rejects automatic hatch and central mutations: " + suffix)
		_expect(not state.save_game_state(), "Future schema rejects explicit save: " + suffix)
		_expect(FileAccess.get_file_as_string(path) == before, "Future bytes survive startup/save: " + suffix)
	_clear_fixture()
	_write(state.SAVE_PATH, "{not json")
	state.call("_ready")
	_expect(state.get("save_blocked") == true and not state.save_game_state(), "Corruption without valid generation blocks writes")
	_expect(FileAccess.get_file_as_string(state.SAVE_PATH) == "{not json", "Corrupt original survives startup")
	_clear_fixture()
	_write(state.SAVE_PATH, '{"schema_version":10000000000000000,"level":73}')
	_write(state.BACKUP_SAVE_PATH, '{"schema_version":9,"level":20}')
	_expect(not state.load_game_state() and state.get("save_blocked") == true, "Very large future schema still takes precedence over an old backup")

func _test_pending_recovery() -> void:
	_clear_fixture()
	_write(state.TEMP_SAVE_PATH, JSON.stringify({"schema_version": 9, "level": 73, "story_flags": {"hatched": true}}))
	var original: String = FileAccess.get_file_as_string(state.TEMP_SAVE_PATH)
	state.call("_ready")
	_expect(state.level == 73, "Only valid pending generation restores progression")
	_expect(state.get("storage_status") == "recovered", "Pending recovery is reported")
	state.level = 74
	_expect(state.save_game_state(), "Save after pending recovery succeeds")
	_expect(FileAccess.get_file_as_string(state.BACKUP_SAVE_PATH) == original, "Only pending generation is preserved before new transaction")
	_clear_fixture()
	_write(state.SAVE_PATH, JSON.stringify({"level": 41, "story_flags": {"hatched": true}}))
	_write(state.TEMP_SAVE_PATH, JSON.stringify({"level": 72, "story_flags": {"hatched": true}}))
	_expect(state.load_game_state() and state.level == 41, "Committed main precedes possibly stale pending data")
	DirAccess.rename_absolute(state.SAVE_PATH, state.BACKUP_SAVE_PATH)
	_expect(state.load_game_state() and state.level == 41, "Committed backup precedes possibly stale pending data")

func _test_payload_validation_before_mutation() -> void:
	var mutations: Array[Dictionary] = [
		{"story_flags": []}, {"settings": []}, {"settings": {"music_volume": {}}},
		{"memories": {}}, {"level": []}, {"schema_version": true},
		{"companion": {"personality": []}}, {"companion": {"personality": {"humor": {}}}},
		{"identity": {"passport": []}}, {"identity": {"passport": {"intelligence_quotient": {}}}},
		{"development": {"skills": {"logic": "bad"}}}, {"development": {"rarity": {"visual": []}}},
		{"development": {"social_history": {"peer": []}}},
		{"learning": {"skills": {"logic": {"rating": []}}}}, {"emotion": {"emotion_weights": []}},
		{"quests": {"active_quests": [{"progress": []}]}}, {"streak": {"current_streak": []}},
		{"evolution": {"discovered_forms": {}}}, {"exploration": {"choice_history": {}}},
		{"dialogue": {"trigger_counts": []}}, {"vitality": {"last_update_unix": []}},
		{"lineage": {"eggs": [{"genome": []}]}}, {"health": NAN}
	]
	for mutation: Dictionary in mutations:
		_clear_fixture()
		state.level = 19
		state.story_flags = {"sentinel": true}
		var payload: Dictionary = {"schema_version": 9, "level": 88, "story_flags": {"hatched": true}}
		payload.merge(mutation, true)
		var accepted: Variant = state.call("apply_save_data", payload)
		_expect(accepted == false and state.level == 19 and state.story_flags == {"sentinel": true}, "Invalid payload rejected before any mutation: " + str(mutation))
	_clear_fixture()
	_write(state.SAVE_PATH, JSON.stringify({"schema_version":9, "level":88, "story_flags":[]}))
	_write(state.BACKUP_SAVE_PATH, JSON.stringify({"schema_version":9, "level":44, "story_flags":{"hatched":true}}))
	_expect(state.load_game_state() and state.level == 44, "Malformed primary falls back without partial import")
	_expect(state.save_game_state(), "Saving recovered backup succeeds")
	_expect(FileAccess.get_file_as_string(state.SAVE_PATH + ".damaged").contains('"level":88'), "Malformed original preserved after recovery")

func _test_good_roundtrip_and_migration() -> void:
	_clear_fixture()
	state.initialize_new_game()
	state.level = 23
	state.xp = 17
	_expect(state.save_game_state(), "Current complete state saves")
	state.level = 1
	_expect(state.load_game_state() and state.level == 23 and state.xp == 17, "Complete service state roundtrip succeeds")
	var committed: String = FileAccess.get_file_as_string(state.SAVE_PATH)
	_expect(DirAccess.make_dir_absolute(state.TEMP_SAVE_PATH) == OK, "Real I/O failure fixture created")
	_expect(not state.save_game_state(), "Real temporary-file I/O failure is reported")
	_expect(FileAccess.get_file_as_string(state.SAVE_PATH) == committed, "I/O failure preserves committed bytes")
	DirAccess.remove_absolute(state.TEMP_SAVE_PATH)
	_clear_fixture()
	var file: FileAccess = FileAccess.open(state.LEGACY_SAVE_PATH, FileAccess.WRITE)
	file.store_var({"level":17,"xp":33,"story_flags":{"hatched":true}}, true)
	file.close()
	_expect(state.load_game_state() and state.level == 17 and state.xp == 33, "Legacy dictionary binary migration remains supported")
	_expect(FileAccess.file_exists(state.LEGACY_SAVE_PATH), "Migration preserves legacy source")
	_expect(FileAccess.file_exists(state.SAVE_PATH), "Migration writes validated current JSON")

func _clear_fixture() -> void:
	for path: String in ["user://bitling_save.json", "user://bitling_save.backup.json", "user://bitling_save.dat", "user://bitling_save.tmp"]:
		for suffix: String in ["", ".damaged"]:
			if FileAccess.file_exists(path + suffix):
				DirAccess.remove_absolute(path + suffix)
	# Each case deliberately simulates a new process after isolating fixtures.
	if "save_blocked" in state:
		state.set("save_blocked", false)

func _write(path: String, value: String) -> void:
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	file.store_string(value)
	file.close()

func _expect(condition: bool, label: String) -> void:
	assertions += 1
	if condition:
		print("PASS: " + label)
	else:
		failures.append(label)
		print("FAIL: " + label)
