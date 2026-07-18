extends Node

## Local adaptive learning model.
## Difficulty follows demonstrated mastery without punitive failure states.

signal challenge_created(challenge: Dictionary)
signal challenge_resolved(result: Dictionary)
signal skill_updated(skill_id: String, old_rating: float, new_rating: float)

const MIN_RATING := 0.0
const MAX_RATING := 100.0
const MIN_DIFFICULTY := 1
const MAX_DIFFICULTY := 10

var skills: Dictionary = {}
var active_challenge: Dictionary = {}
var challenge_counter: int = 0

func create_challenge(skill_id: String = "logic", seed_value: int = -1) -> Dictionary:
	var normalized_skill := skill_id.strip_edges().to_lower()
	if normalized_skill.is_empty():
		normalized_skill = "logic"
	var profile := _ensure_skill(normalized_skill)
	var difficulty := recommend_difficulty(normalized_skill)
	var rng := RandomNumberGenerator.new()
	var resolved_seed := seed_value
	if resolved_seed < 0:
		resolved_seed = hash("%s:%s:%d" % [normalized_skill, _date_key(), challenge_counter])
	rng.seed = resolved_seed
	challenge_counter += 1
	var challenge := _build_sequence_challenge(normalized_skill, difficulty, rng)
	challenge["seed"] = resolved_seed
	challenge["started_at_msec"] = Time.get_ticks_msec()
	challenge["rating_before"] = float(profile.get("rating", 20.0))
	active_challenge = challenge
	challenge_created.emit(challenge.duplicate(true))
	return challenge.duplicate(true)

func submit_answer(answer_index: int, hints_used: int = 0) -> Dictionary:
	if active_challenge.is_empty():
		return {"accepted": false, "reason": "no_active_challenge"}
	var answers: Array = active_challenge.get("answers", [])
	if answer_index < 0 or answer_index >= answers.size():
		return {"accepted": false, "reason": "invalid_answer"}
	var correct_index := int(active_challenge.get("correct_index", -1))
	if correct_index < 0 or correct_index >= answers.size():
		active_challenge.clear()
		return {"accepted": false, "reason": "invalid_challenge"}
	var success := answer_index == correct_index
	var response_seconds := maxf(
		float(Time.get_ticks_msec() - int(active_challenge.get("started_at_msec", Time.get_ticks_msec()))) / 1000.0,
		0.0
	)
	var skill_id := str(active_challenge.get("skill_id", "logic"))
	var difficulty := int(active_challenge.get("difficulty", 1))
	var update := record_result(skill_id, difficulty, success, response_seconds, hints_used)
	var result := {
		"accepted": true,
		"success": success,
		"correct_index": correct_index,
		"correct_answer": answers[correct_index],
		"selected_answer": answers[answer_index],
		"skill_id": skill_id,
		"difficulty": difficulty,
		"response_seconds": response_seconds,
		"rating": update.get("rating", 0.0),
		"xp_reward": difficulty * (8 if success else 2),
		"explanation": str(active_challenge.get("explanation", ""))
	}
	active_challenge.clear()
	challenge_resolved.emit(result.duplicate(true))
	return result

func record_result(
	skill_id: String,
	difficulty: int,
	success: bool,
	response_seconds: float,
	hints_used: int = 0
) -> Dictionary:
	var profile := _ensure_skill(skill_id)
	var old_rating := float(profile.get("rating", 20.0))
	var target_rating := float(clampi(difficulty, MIN_DIFFICULTY, MAX_DIFFICULTY) * 10)
	var expected := 1.0 / (1.0 + pow(10.0, (target_rating - old_rating) / 40.0))
	var score := 1.0 if success else 0.0
	var hint_factor := clampf(1.0 - float(maxi(hints_used, 0)) * 0.12, 0.45, 1.0)
	var speed_factor := clampf(1.15 - maxf(response_seconds - 8.0, 0.0) * 0.015, 0.65, 1.15)
	var delta := 12.0 * (score - expected) * hint_factor * speed_factor
	var new_rating := clampf(old_rating + delta, MIN_RATING, MAX_RATING)
	profile["rating"] = new_rating
	profile["attempts"] = int(profile.get("attempts", 0)) + 1
	profile["successes"] = int(profile.get("successes", 0)) + (1 if success else 0)
	profile["current_streak"] = int(profile.get("current_streak", 0)) + 1 if success else 0
	profile["best_streak"] = maxi(int(profile.get("best_streak", 0)), int(profile.get("current_streak", 0)))
	profile["last_difficulty"] = difficulty
	profile["last_response_seconds"] = maxf(response_seconds, 0.0)
	profile["last_played_at"] = int(Time.get_unix_time_from_system())
	skills[skill_id] = profile
	if not is_equal_approx(old_rating, new_rating):
		skill_updated.emit(skill_id, old_rating, new_rating)
	return profile.duplicate(true)

func recommend_difficulty(skill_id: String) -> int:
	var profile := _ensure_skill(skill_id)
	var rating := float(profile.get("rating", 20.0))
	var attempts := int(profile.get("attempts", 0))
	var confidence_penalty := 1 if attempts < 3 else 0
	return clampi(int(round(rating / 10.0)) + 1 - confidence_penalty, MIN_DIFFICULTY, MAX_DIFFICULTY)

func get_average_rating() -> float:
	if skills.is_empty():
		return 20.0
	var total := 0.0
	for profile in skills.values():
		total += float(profile.get("rating", 20.0))
	return total / float(skills.size())

func get_skill_profile(skill_id: String) -> Dictionary:
	return _ensure_skill(skill_id).duplicate(true)

func export_state() -> Dictionary:
	return {
		"skills": skills.duplicate(true),
		"challenge_counter": challenge_counter
	}

func import_state(data: Dictionary) -> void:
	skills = data.get("skills", {}).duplicate(true)
	challenge_counter = maxi(int(data.get("challenge_counter", 0)), 0)
	active_challenge.clear()

func reset_state() -> void:
	skills.clear()
	active_challenge.clear()
	challenge_counter = 0

func _ensure_skill(skill_id: String) -> Dictionary:
	if not skills.has(skill_id):
		skills[skill_id] = {
			"rating": 20.0,
			"attempts": 0,
			"successes": 0,
			"current_streak": 0,
			"best_streak": 0,
			"last_difficulty": 1,
			"last_response_seconds": 0.0,
			"last_played_at": 0
		}
	return skills[skill_id]

func _build_sequence_challenge(skill_id: String, difficulty: int, rng: RandomNumberGenerator) -> Dictionary:
	var start := rng.randi_range(1, 4 + difficulty * 2)
	var step := rng.randi_range(1, 2 + difficulty)
	var sequence: Array[int] = []
	for index in range(4):
		sequence.append(start + step * index)
	var correct := start + step * 4
	var answers: Array[int] = [correct, correct + step, maxi(correct - step, 0)]
	_shuffle_int_array(answers, rng)
	return {
		"id": "%s_sequence_%d" % [skill_id, challenge_counter],
		"skill_id": skill_id,
		"difficulty": difficulty,
		"prompt": "Welche Zahl setzt die Folge fort?\n%s, ?" % _join_ints(sequence),
		"answers": answers,
		"correct_index": answers.find(correct),
		"explanation": "Die Folge wächst jedes Mal um %d." % step
	}

func _shuffle_int_array(values: Array[int], rng: RandomNumberGenerator) -> void:
	for index in range(values.size() - 1, 0, -1):
		var swap_index := rng.randi_range(0, index)
		var temporary := values[index]
		values[index] = values[swap_index]
		values[swap_index] = temporary

func _join_ints(values: Array[int]) -> String:
	var parts: PackedStringArray = []
	for value in values:
		parts.append(str(value))
	return ", ".join(parts)

func _date_key() -> String:
	var date := Time.get_date_dict_from_system()
	return "%04d-%02d-%02d" % [
		int(date.get("year", 1970)),
		int(date.get("month", 1)),
		int(date.get("day", 1))
	]
