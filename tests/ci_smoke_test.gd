extends SceneTree

var failures: Array[String] = []
var assertions: int = 0

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	_ensure_runtime_nodes()
	_test_streak_service()
	_test_quest_service()
	_test_companion_brain()
	_test_wellbeing_guard()
	_test_game_state_progression_and_interactions()
	_test_save_roundtrip()
	if failures.is_empty():
		print("[CI] PASS: %d assertions" % assertions)
		quit(0)
		return
	push_error("[CI] FAIL: %d of %d assertions failed" % [failures.size(), assertions])
	for failure in failures:
		push_error("[CI]   - %s" % failure)
	quit(1)

func _ensure_runtime_nodes() -> void:
	var definitions: Array = [
		["EventBus", "res://scripts/core/event_bus.gd"],
		["StreakService", "res://scripts/core/streak_service.gd"],
		["QuestService", "res://scripts/core/quest_service.gd"],
		["PlatformService", "res://scripts/core/platform_service.gd"],
		["CompanionBrain", "res://scripts/core/companion_brain.gd"],
		["WellbeingGuard", "res://scripts/core/wellbeing_guard.gd"],
		["GameState", "res://scripts/core/game_state.gd"]
	]
	for definition in definitions:
		var node_name: String = str(definition[0])
		if root.has_node(node_name):
			continue
		var script: Script = load(str(definition[1]))
		_assert(script != null, "Script loads: %s" % definition[1])
		if script == null:
			continue
		var instance: Node = script.new()
		instance.name = node_name
		root.add_child(instance)

func _test_streak_service() -> void:
	var streak: Node = root.get_node("StreakService")
	streak.import_state({})
	var started: Dictionary = streak.register_activity(_date(2026, 1, 1))
	_assert(started.get("status") == "started", "Streak starts on first activity")
	_assert(streak.current_streak == 1, "Initial streak equals one")
	var continued: Dictionary = streak.register_activity(_date(2026, 1, 2))
	_assert(continued.get("status") == "continued", "Consecutive day continues streak")
	_assert(streak.current_streak == 2, "Consecutive streak increments")
	var gap: Dictionary = streak.register_activity(_date(2026, 1, 4))
	_assert(gap.get("status") == "recovery_available", "Missed day offers non-punitive recovery")
	_assert(streak.pending_missed_days == 1, "Missed day count is tracked")
	_assert(streak.recover_streak(_date(2026, 1, 4)), "Available streak recovery succeeds")
	_assert(streak.current_streak == 3, "Recovered streak continues")

func _test_quest_service() -> void:
	var quests: Node = root.get_node("QuestService")
	quests.import_state({})
	var first: Array = quests.ensure_daily_quests("ci-profile", _date(2026, 2, 14))
	var first_ids: Array[String] = _quest_ids(first)
	quests.import_state({})
	var second: Array = quests.ensure_daily_quests("ci-profile", _date(2026, 2, 14))
	_assert(first.size() == int(quests.DAILY_QUEST_COUNT), "Daily quest count is stable")
	_assert(first_ids == _quest_ids(second), "Quest generation is deterministic per profile and date")
	var target_event: String = str(first[0].get("event", ""))
	var changed: Array = quests.record_event(target_event, int(first[0].get("target", 1)))
	_assert(not changed.is_empty(), "Matching gameplay event progresses a quest")
	var reward: int = int(quests.claim_reward(str(first[0].get("id", ""))))
	_assert(reward > 0, "Completed quest reward can be claimed once")
	_assert(int(quests.claim_reward(str(first[0].get("id", "")))) == 0, "Quest reward cannot be claimed twice")

func _test_companion_brain() -> void:
	var brain: Node = root.get_node("CompanionBrain")
	brain.reset_state()
	var old_relationship: float = float(brain.relationship_score)
	var old_empathy: float = float(brain.personality.get("empathy", 0.0))
	brain.observe_interaction("care", 1.0, {"source": "ci"})
	_assert(float(brain.relationship_score) > old_relationship, "Care increases relationship")
	_assert(float(brain.personality.get("empathy", 0.0)) > old_empathy, "Care shapes companion personality")
	_assert(int(brain.interaction_counts.get("care", 0)) == 1, "Interaction frequency is remembered")
	var exported: Dictionary = brain.export_state()
	brain.reset_state()
	brain.import_state(exported)
	_assert(int(brain.interaction_counts.get("care", 0)) == 1, "Companion memory survives export/import")
	_assert(not str(brain.get_greeting()).is_empty(), "Companion always produces a greeting")

func _test_wellbeing_guard() -> void:
	var guard: Node = root.get_node("WellbeingGuard")
	_assert(guard.validate_player_message("Schön, dass du da bist."), "Supportive copy is accepted")
	_assert(not guard.validate_player_message("Du hast mich im Stich gelassen."), "Guilt-inducing copy is rejected")
	var settings: Dictionary = {
		"notifications_enabled": true,
		"quiet_hours_start": 22,
		"quiet_hours_end": 8
	}
	_assert(not guard.can_send_notification(settings, 0, 23), "Quiet hours block notifications")
	_assert(guard.can_send_notification(settings, 0, 12), "Daytime notification can pass")

func _test_game_state_progression_and_interactions() -> void:
	var state: Node = root.get_node("GameState")
	state.initialize_new_game()
	state.gain_xp(250, "ci")
	_assert(int(state.level) == 3, "Large XP grants multiple level-ups")
	_assert(int(state.xp) == 50, "XP remainder is preserved")
	var old_hunger: float = float(state.hunger)
	var old_happiness: float = float(state.happiness)
	var tags: Array[String] = ["care"]
	state.perform_interaction(
		"care",
		{"hunger": 10.0, "happiness": 5.0, "quest_event": "care_action_completed"},
		15,
		tags
	)
	_assert(float(state.hunger) > old_hunger, "Care interaction updates saturation")
	_assert(float(state.happiness) > old_happiness, "Care interaction updates happiness")
	_assert(int(state.total_xp) == 265, "Interaction XP is included in total XP")
	var brain: Node = root.get_node("CompanionBrain")
	_assert(int(brain.interaction_counts.get("care", 0)) >= 1, "Game interaction reaches companion brain")

func _test_save_roundtrip() -> void:
	var state: Node = root.get_node("GameState")
	state.level = 7
	state.xp = 42
	state.story_flags["ci_roundtrip"] = true
	_assert(bool(state.save_game_state()), "Game state saves successfully")
	state.level = 1
	state.xp = 0
	state.story_flags.erase("ci_roundtrip")
	_assert(bool(state.load_game_state()), "Game state loads successfully")
	_assert(int(state.level) == 7 and int(state.xp) == 42, "Progression survives save roundtrip")
	_assert(bool(state.story_flags.get("ci_roundtrip", false)), "Story flags survive save roundtrip")

func _quest_ids(quests: Array) -> Array[String]:
	var ids: Array[String] = []
	for quest in quests:
		ids.append(str(quest.get("id", "")))
	return ids

func _date(year: int, month: int, day: int) -> Dictionary:
	return {"year": year, "month": month, "day": day}

func _assert(condition: bool, description: String) -> void:
	assertions += 1
	if not condition:
		failures.append(description)
