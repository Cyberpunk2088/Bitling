extends SceneTree

var failures: Array[String] = []
var assertions := 0

const CONTEXT_ANSWERS := {
	"signal_translation": ["hell oder warm leuchtend", "aufmerksam sein", "gemeinsam etwas tragen"],
	"media_lens": ["Quelle und Gegenbelege prüfen", "Was wurde außerhalb des Bildes weggelassen?", "Datum und ursprünglichen Zusammenhang prüfen"],
	"debate_circle": ["die drei bestandenen Tests", "Zeiten aufteilen und Bedürfnisse prüfen", "prüfen, ob die Beobachtung auch anders erklärbar ist"],
	"emotion_compass": ["ruhig nachfragen und Wahlmöglichkeiten geben", "Tempo senken und Unterstützung anbieten", "fragen, ob Nähe oder etwas Ruhe gewünscht ist"],
	"science_garden": ["Wasser beeinflusst die Leuchtstärke", "nur eine Bedingung gleichzeitig verändern", "bei gleicher Lichtmenge mehrere Messungen vergleichen"],
	"creative_forge": ["leichteres Material testen", "Stützpunkte neu verteilen", "Licht und Geräusche anpassen", "klare Zonen schaffen", "Materialreste neu kombinieren", "eine faltbare Form ausprobieren"]
}

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var token := OS.get_environment("BITLING_TEST_TOKEN")
	var mac_fixture := OS.get_name() == "macOS" and OS.get_user_data_dir().get_file().begins_with("BitlingRepairTests-") and token.length() >= 32 and FileAccess.file_exists("user://.bitling-test-fixture") and FileAccess.get_file_as_string("user://.bitling-test-fixture") == token
	if OS.get_environment("BITLING_TEST_ISOLATED") != "1" or not (OS.get_user_data_dir().begins_with("/tmp/") or mac_fixture):
		printerr("This test requires an isolated test project and BITLING_TEST_ISOLATED=1.")
		quit(2)
		return
	var service := root.get_node("LearningAdventures")
	for adventure_id: String in ["signal_translation", "media_lens", "debate_circle", "emotion_compass", "science_garden", "creative_forge", "resonance_rhythm", "spatial_bridge", "memory_archive"]:
		_test_authored_challenges(service, adventure_id)
	for adventure_id: String in ["pattern_observatory", "number_foundry", "systems_lab"]:
		_test_numeric_challenges(service, adventure_id)
	print("[LEARNING-QUALITY] %d assertions, %d failures" % [assertions, failures.size()])
	quit(0 if failures.is_empty() else 1)

func _test_authored_challenges(service: Node, adventure_id: String) -> void:
	var positions: Dictionary = {}
	var always_correct_positions := {0: true, 1: true, 2: true}
	var first_prompts: Dictionary = {}
	var deterministic := true
	var no_repeated_prompts := true
	var correct_answers_preserved := true
	var valid_options := true
	var explanations_specific := true
	for seed_value: int in range(101, 125):
		for difficulty: int in [1, 5, 10]:
			var prompts: Dictionary = {}
			var explanations: Dictionary = {}
			for round_index: int in range(3):
				var challenge: Dictionary = service.call("_build_challenge", adventure_id, difficulty, seed_value, round_index)
				deterministic = deterministic and challenge == service.call("_build_challenge", adventure_id, difficulty, seed_value, round_index)
				var prompt := str(challenge.get("prompt", ""))
				prompts[prompt] = true
				if round_index == 0:
					first_prompts[prompt] = true
				explanations[str(challenge.get("explanation", ""))] = true
				var answers: Array = challenge.get("answers", [])
				var correct: Array = challenge.get("correct_indices", [])
				for position: int in always_correct_positions.keys():
					if not correct.has(position):
						always_correct_positions.erase(position)
				valid_options = valid_options and _valid_options(answers, correct)
				var expected := _expected_answers(adventure_id, prompt, answers)
				var actual: Array = []
				for index: Variant in correct:
					if int(index) >= 0 and int(index) < answers.size():
						actual.append(answers[int(index)])
						positions[int(index)] = true
				actual.sort()
				expected.sort()
				correct_answers_preserved = correct_answers_preserved and actual == expected and actual.size() == (2 if adventure_id == "creative_forge" else 1)
			no_repeated_prompts = no_repeated_prompts and prompts.size() == 3
			explanations_specific = explanations_specific and explanations.size() == 3
	_check(deterministic, adventure_id + ": the same seed reproduces the same complete challenge")
	_check(valid_options, adventure_id + ": answers stay unique and correct indices stay valid")
	_check(correct_answers_preserved, adventure_id + ": shuffled indices preserve every semantically correct answer")
	_check(positions.size() > 1 and always_correct_positions.is_empty(), adventure_id + ": a fixed answer position cannot win every seeded challenge")
	_check(no_repeated_prompts, adventure_id + ": three rounds have three different prompts")
	_check(first_prompts.size() > 1, adventure_id + ": replay seeds change the first prompt")
	_check(explanations_specific, adventure_id + ": each prompt has its own explanation")

func _test_numeric_challenges(service: Node, adventure_id: String) -> void:
	var number := RegEx.new()
	number.compile("\\d+")
	var all_correct := true
	var positions: Dictionary = {}
	for difficulty: int in [1, 5, 10]:
		for seed_value: int in range(101, 125):
			for round_index: int in range(3):
				var challenge: Dictionary = service.call("_build_challenge", adventure_id, difficulty, seed_value, round_index)
				var matches := number.search_all(str(challenge.get("prompt", "")))
				var expected: int
				if adventure_id == "pattern_observatory":
					expected = int(matches[3].get_string()) + int(matches[1].get_string()) - int(matches[0].get_string())
				else:
					expected = int(matches[0].get_string()) * 4 + int(matches[1].get_string())
				var answers: Array = challenge.get("answers", [])
				var correct: Array = challenge.get("correct_indices", [])
				all_correct = all_correct and _valid_options(answers, correct) and correct.size() == 1 and int(answers[int(correct[0])]) == expected
				positions[int(correct[0])] = true
	_check(all_correct, adventure_id + ": correct values match arithmetic independently calculated from the prompt")
	_check(positions.size() > 1, adventure_id + ": numeric correct positions vary across seeds")

func _expected_answers(adventure_id: String, prompt: String, answers: Array) -> Array:
	if CONTEXT_ANSWERS.has(adventure_id):
		var result: Array = []
		for answer: Variant in answers:
			if (CONTEXT_ANSWERS[adventure_id] as Array).has(answer):
				result.append(answer)
		return result
	if prompt.contains("● ○ ● ○"):
		return ["●"]
	if prompt.contains("▲ ▲ ■ ▲ ▲ ■"):
		return ["▲"]
	if prompt.contains("links · oben · rechts · unten"):
		return ["links"]
	return []

func _valid_options(answers: Array, correct: Array) -> bool:
	var distinct: Dictionary = {}
	for answer: Variant in answers:
		distinct[answer] = true
	if answers.size() != 3 or distinct.size() != 3 or correct.is_empty():
		return false
	var distinct_correct: Dictionary = {}
	for index: Variant in correct:
		if int(index) < 0 or int(index) >= answers.size():
			return false
		distinct_correct[int(index)] = true
	return distinct_correct.size() == correct.size()

func _check(condition: bool, message: String) -> void:
	assertions += 1
	if not condition:
		failures.append(message)
		printerr("[LEARNING-QUALITY] FAIL: ", message)
