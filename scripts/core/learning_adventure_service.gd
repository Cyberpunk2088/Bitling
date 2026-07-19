extends Node

## Wave 5 authoritative learning-adventure runtime.
## Twelve original adventures share one adaptive mastery model while producing
## transfer effects for expeditions, dialogue, techniques and evolution.

signal catalog_changed(snapshot: Dictionary)
signal session_started(session: Dictionary)
signal challenge_changed(challenge: Dictionary)
signal round_resolved(result: Dictionary)
signal session_completed(result: Dictionary)
signal mastery_changed(adventure_id: String, old_mastery: float, new_mastery: float)

const SAVE_VERSION := 1
const SAVE_PATH := "user://learning_adventures.json"
const TEMP_PATH := "user://learning_adventures.tmp"
const BACKUP_PATH := "user://learning_adventures.backup.json"
const MAX_HISTORY := 120
const ROUNDS_PER_SESSION := 3

const ADVENTURES: Dictionary = {
	"pattern_observatory": {
		"title": "Musterobservatorium",
		"domain": "logic",
		"icon": "pattern",
		"description": "Entdecke Regeln in Zahlen, Symbolen und Bewegungen.",
		"technique": "pattern_focus",
		"expedition": "aurora_foundry",
		"evolution_affinity": "LIGHT_SCHOLAR",
		"accent": "42e8ff"
	},
	"signal_translation": {
		"title": "Signalübersetzung",
		"domain": "language",
		"icon": "language",
		"description": "Leite Bedeutung aus Kontext, Tonfall und Wortbausteinen ab.",
		"technique": "mentor_chorus",
		"expedition": "quiet_orbit",
		"evolution_affinity": "CHORUS_MENTOR",
		"accent": "a855f7"
	},
	"resonance_rhythm": {
		"title": "Resonanzrhythmus",
		"domain": "rhythm",
		"icon": "rhythm",
		"description": "Erkenne Takt, Wiederholung und musikalische Struktur.",
		"technique": "signal_dash",
		"expedition": "prismatic_rooftops",
		"evolution_affinity": "MOSAIC_TRICKSTER",
		"accent": "f044d4"
	},
	"emotion_compass": {
		"title": "Emotionskompass",
		"domain": "empathy",
		"icon": "heart",
		"description": "Lies Bedürfnisse, Perspektiven und hilfreiche Reaktionen.",
		"technique": "care_pulse",
		"expedition": "echo_marsh",
		"evolution_affinity": "HEART_BASTION",
		"accent": "ff7aa8"
	},
	"number_foundry": {
		"title": "Zahlenwerkstatt",
		"domain": "math",
		"icon": "number",
		"description": "Nutze Schätzen, Zerlegen und Rechnen für echte Probleme.",
		"technique": "pattern_focus",
		"expedition": "aurora_foundry",
		"evolution_affinity": "LIGHT_SCHOLAR",
		"accent": "ffc85a"
	},
	"media_lens": {
		"title": "Medienlinse",
		"domain": "media",
		"icon": "lens",
		"description": "Prüfe Quellen, Absichten und fehlende Informationen.",
		"technique": "echo_shield",
		"expedition": "quiet_orbit",
		"evolution_affinity": "SIGNAL_WANDERER",
		"accent": "6fa8ff"
	},
	"science_garden": {
		"title": "Forschungsgarten",
		"domain": "science",
		"icon": "leaf",
		"description": "Bilde Hypothesen und unterscheide Beobachtung von Erklärung.",
		"technique": "care_pulse",
		"expedition": "echo_marsh",
		"evolution_affinity": "LIGHT_SCHOLAR",
		"accent": "64e6a2"
	},
	"spatial_bridge": {
		"title": "Raumbrücken",
		"domain": "spatial",
		"icon": "bridge",
		"description": "Drehe Formen im Kopf und plane sichere Wege.",
		"technique": "echo_shield",
		"expedition": "prismatic_rooftops",
		"evolution_affinity": "SIGNAL_WANDERER",
		"accent": "42e8ff"
	},
	"memory_archive": {
		"title": "Erinnerungsarchiv",
		"domain": "memory",
		"icon": "memory",
		"description": "Ordne Hinweise, Geschichten und Reihenfolgen sinnvoll.",
		"technique": "mentor_chorus",
		"expedition": "quiet_orbit",
		"evolution_affinity": "ANCIENT_ORACLE",
		"accent": "b783ff"
	},
	"creative_forge": {
		"title": "Kreativschmiede",
		"domain": "creativity",
		"icon": "spark",
		"description": "Finde mehrere brauchbare Ideen und verbessere sie gezielt.",
		"technique": "comic_trip",
		"expedition": "aurora_foundry",
		"evolution_affinity": "MOSAIC_TRICKSTER",
		"accent": "f044d4"
	},
	"debate_circle": {
		"title": "Perspektivenkreis",
		"domain": "reasoning",
		"icon": "dialogue",
		"description": "Unterscheide Behauptung, Beleg und faire Gegenposition.",
		"technique": "mentor_chorus",
		"expedition": "echo_marsh",
		"evolution_affinity": "CHORUS_MENTOR",
		"accent": "ffc85a"
	},
	"systems_lab": {
		"title": "Systemlabor",
		"domain": "systems",
		"icon": "network",
		"description": "Verstehe Ursache, Rückkopplung und langfristige Folgen.",
		"technique": "pattern_focus",
		"expedition": "quiet_orbit",
		"evolution_affinity": "ANCIENT_ORACLE",
		"accent": "64e6a2"
	}
}

const APPROACHES: Dictionary = {
	"observe": {"label": "BEOBACHTEN", "hint_cost": 0, "mastery_factor": 1.00},
	"compare": {"label": "VERGLEICHEN", "hint_cost": 0, "mastery_factor": 1.05},
	"experiment": {"label": "AUSPROBIEREN", "hint_cost": 1, "mastery_factor": 0.92},
	"explain": {"label": "ERKLÄREN", "hint_cost": 0, "mastery_factor": 1.12}
}

var profiles: Dictionary = {}
var active_session: Dictionary = {}
var history: Array[Dictionary] = []
var total_sessions: int = 0
var transfer_tokens: Dictionary = {}
var affinity_points: Dictionary = {}

func _ready() -> void:
	load_state()

func get_catalog() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for adventure_id_variant: Variant in ADVENTURES.keys():
		var adventure_id: String = str(adventure_id_variant)
		var data: Dictionary = (ADVENTURES[adventure_id] as Dictionary).duplicate(true)
		var profile: Dictionary = _ensure_profile(adventure_id)
		data["id"] = adventure_id
		data["mastery"] = float(profile.get("mastery", 20.0))
		data["level"] = _mastery_level(float(profile.get("mastery", 20.0)))
		data["attempts"] = int(profile.get("attempts", 0))
		data["best_score"] = float(profile.get("best_score", 0.0))
		data["unlocked"] = _is_unlocked(adventure_id)
		result.append(data)
	return result

func get_snapshot() -> Dictionary:
	return {
		"catalog": get_catalog(),
		"active_session": active_session.duplicate(true),
		"total_sessions": total_sessions,
		"average_mastery": get_average_mastery(),
		"transfer_tokens": transfer_tokens.duplicate(true),
		"affinity_points": affinity_points.duplicate(true),
		"mastered_count": get_mastered_count(),
		"history_count": history.size()
	}

func start_session(adventure_id: String, seed_value: int = -1) -> Dictionary:
	if not ADVENTURES.has(adventure_id):
		return {"accepted": false, "reason": "unknown_adventure"}
	if not active_session.is_empty():
		return {"accepted": false, "reason": "session_active"}
	if not _is_unlocked(adventure_id):
		return {"accepted": false, "reason": "adventure_locked"}
	var profile: Dictionary = _ensure_profile(adventure_id)
	var difficulty: int = _recommend_difficulty(profile)
	var resolved_seed: int = seed_value
	if resolved_seed < 0:
		resolved_seed = hash("%s:%d:%d" % [adventure_id, total_sessions, int(Time.get_unix_time_from_system())])
	active_session = {
		"adventure_id": adventure_id,
		"title": str((ADVENTURES[adventure_id] as Dictionary).get("title", adventure_id)),
		"round": 0,
		"rounds": ROUNDS_PER_SESSION,
		"difficulty": difficulty,
		"score_total": 0.0,
		"successes": 0,
		"approaches": [],
		"seed": resolved_seed,
		"started_at": int(Time.get_unix_time_from_system()),
		"challenge": {}
	}
	active_session["challenge"] = _build_challenge(adventure_id, difficulty, resolved_seed, 0)
	session_started.emit(active_session.duplicate(true))
	challenge_changed.emit((active_session["challenge"] as Dictionary).duplicate(true))
	return {"accepted": true, "session": active_session.duplicate(true)}

func submit_solution(answer_index: int, approach_id: String = "observe") -> Dictionary:
	if active_session.is_empty():
		return {"accepted": false, "reason": "no_active_session"}
	var challenge: Dictionary = active_session.get("challenge", {}) as Dictionary
	var answers: Array = challenge.get("answers", []) as Array
	if answer_index < 0 or answer_index >= answers.size():
		return {"accepted": false, "reason": "invalid_answer"}
	var normalized_approach: String = approach_id.strip_edges().to_lower()
	if not APPROACHES.has(normalized_approach):
		normalized_approach = "observe"
	var correct_indices: Array = challenge.get("correct_indices", []) as Array
	var success: bool = correct_indices.has(answer_index)
	var approach: Dictionary = APPROACHES[normalized_approach]
	var base_score: float = 1.0 if success else 0.25
	var reasoning_bonus: float = float(challenge.get("approach_bonus", {}).get(normalized_approach, 0.0))
	var round_score: float = clampf((base_score + reasoning_bonus) * float(approach.get("mastery_factor", 1.0)), 0.0, 1.25)
	active_session["score_total"] = float(active_session.get("score_total", 0.0)) + round_score
	active_session["successes"] = int(active_session.get("successes", 0)) + (1 if success else 0)
	var used_approaches: Array = active_session.get("approaches", []) as Array
	used_approaches.append(normalized_approach)
	active_session["approaches"] = used_approaches
	var result: Dictionary = {
		"accepted": true,
		"success": success,
		"selected_answer": answers[answer_index],
		"correct_answers": _correct_answer_values(answers, correct_indices),
		"approach": normalized_approach,
		"round_score": round_score,
		"explanation": str(challenge.get("explanation", "")),
		"transfer_tip": str(challenge.get("transfer_tip", "")),
		"round": int(active_session.get("round", 0)) + 1,
		"rounds": int(active_session.get("rounds", ROUNDS_PER_SESSION)),
		"completed": false
	}
	active_session["round"] = int(active_session.get("round", 0)) + 1
	round_resolved.emit(result.duplicate(true))
	if int(active_session.get("round", 0)) >= int(active_session.get("rounds", ROUNDS_PER_SESSION)):
		return _complete_session(result)
	var adventure_id: String = str(active_session.get("adventure_id", "pattern_observatory"))
	var difficulty: int = int(active_session.get("difficulty", 1))
	var seed_value: int = int(active_session.get("seed", 0))
	active_session["challenge"] = _build_challenge(adventure_id, difficulty, seed_value, int(active_session.get("round", 0)))
	challenge_changed.emit((active_session["challenge"] as Dictionary).duplicate(true))
	result["next_challenge"] = (active_session["challenge"] as Dictionary).duplicate(true)
	return result

func abandon_session() -> void:
	if active_session.is_empty():
		return
	_remember("abandoned", {"adventure_id": active_session.get("adventure_id", ""), "round": active_session.get("round", 0)})
	active_session.clear()
	save_state()

func get_expedition_bonus(region_id: String) -> float:
	var tokens: float = float(transfer_tokens.get(region_id, 0.0))
	return clampf(tokens * 0.02, 0.0, 0.35)

func consume_expedition_bonus(region_id: String, fraction: float = 0.25) -> float:
	var bonus: float = get_expedition_bonus(region_id)
	var current: float = float(transfer_tokens.get(region_id, 0.0))
	transfer_tokens[region_id] = maxf(current - maxf(current * fraction, 1.0), 0.0)
	save_state()
	return bonus

func get_affinity_bonus(affinity_id: String) -> float:
	return clampf(float(affinity_points.get(affinity_id, 0.0)) / 100.0, 0.0, 0.30)

func get_average_mastery() -> float:
	if profiles.is_empty():
		return 20.0
	var total: float = 0.0
	for profile_variant: Variant in profiles.values():
		var profile: Dictionary = profile_variant as Dictionary
		total += float(profile.get("mastery", 20.0))
	return total / float(profiles.size())

func get_mastered_count() -> int:
	var count: int = 0
	for profile_variant: Variant in profiles.values():
		var profile: Dictionary = profile_variant as Dictionary
		if float(profile.get("mastery", 0.0)) >= 75.0:
			count += 1
	return count

func export_state() -> Dictionary:
	return {
		"version": SAVE_VERSION,
		"profiles": profiles.duplicate(true),
		"total_sessions": total_sessions,
		"transfer_tokens": transfer_tokens.duplicate(true),
		"affinity_points": affinity_points.duplicate(true),
		"history": history.duplicate(true)
	}

func import_state(data: Dictionary) -> void:
	profiles = (data.get("profiles", {}) as Dictionary).duplicate(true)
	total_sessions = maxi(int(data.get("total_sessions", 0)), 0)
	transfer_tokens = (data.get("transfer_tokens", {}) as Dictionary).duplicate(true)
	affinity_points = (data.get("affinity_points", {}) as Dictionary).duplicate(true)
	history = _dictionary_array(data.get("history", []), MAX_HISTORY)
	active_session.clear()
	catalog_changed.emit(get_snapshot())

func reset_state() -> void:
	profiles.clear()
	active_session.clear()
	history.clear()
	transfer_tokens.clear()
	affinity_points.clear()
	total_sessions = 0
	for path: String in [SAVE_PATH, TEMP_PATH, BACKUP_PATH]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)
	catalog_changed.emit(get_snapshot())

func save_state() -> bool:
	var payload: Dictionary = export_state()
	payload["saved_at"] = int(Time.get_unix_time_from_system())
	var file: FileAccess = FileAccess.open(TEMP_PATH, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(payload))
	file.close()
	if FileAccess.file_exists(SAVE_PATH) and not _read_payload(SAVE_PATH).is_empty():
		_copy_file(SAVE_PATH, BACKUP_PATH)
	if FileAccess.file_exists(SAVE_PATH):
		var remove_error: Error = DirAccess.remove_absolute(SAVE_PATH)
		if remove_error != OK:
			return false
	var rename_error: Error = DirAccess.rename_absolute(TEMP_PATH, SAVE_PATH)
	if rename_error != OK:
		if FileAccess.file_exists(BACKUP_PATH):
			_copy_file(BACKUP_PATH, SAVE_PATH)
		return false
	return true

func load_state() -> bool:
	for path: String in [SAVE_PATH, BACKUP_PATH]:
		var payload: Dictionary = _read_payload(path)
		if payload.is_empty():
			continue
		import_state(payload)
		return true
	return false

func _complete_session(last_round: Dictionary) -> Dictionary:
	var adventure_id: String = str(active_session.get("adventure_id", "pattern_observatory"))
	var adventure: Dictionary = ADVENTURES[adventure_id]
	var profile: Dictionary = _ensure_profile(adventure_id)
	var old_mastery: float = float(profile.get("mastery", 20.0))
	var average_score: float = float(active_session.get("score_total", 0.0)) / maxf(float(active_session.get("rounds", ROUNDS_PER_SESSION)), 1.0)
	var difficulty: int = int(active_session.get("difficulty", 1))
	var target: float = float(difficulty) * 10.0
	var expected: float = 1.0 / (1.0 + pow(10.0, (target - old_mastery) / 40.0))
	var mastery_delta: float = 13.0 * (average_score - expected)
	var new_mastery: float = clampf(old_mastery + mastery_delta, 0.0, 100.0)
	profile["mastery"] = new_mastery
	profile["attempts"] = int(profile.get("attempts", 0)) + 1
	profile["successes"] = int(profile.get("successes", 0)) + (1 if average_score >= 0.70 else 0)
	profile["best_score"] = maxf(float(profile.get("best_score", 0.0)), average_score)
	profile["last_score"] = average_score
	profile["last_played_at"] = int(Time.get_unix_time_from_system())
	profile["best_streak"] = maxi(int(profile.get("best_streak", 0)), int(active_session.get("successes", 0)))
	profiles[adventure_id] = profile
	if not is_equal_approx(old_mastery, new_mastery):
		mastery_changed.emit(adventure_id, old_mastery, new_mastery)
	var expedition_id: String = str(adventure.get("expedition", ""))
	var affinity_id: String = str(adventure.get("evolution_affinity", ""))
	var token_reward: float = 2.0 + average_score * float(difficulty)
	transfer_tokens[expedition_id] = float(transfer_tokens.get(expedition_id, 0.0)) + token_reward
	affinity_points[affinity_id] = float(affinity_points.get(affinity_id, 0.0)) + token_reward * 0.8
	total_sessions += 1
	var result: Dictionary = last_round.duplicate(true)
	result["completed"] = true
	result["adventure_id"] = adventure_id
	result["title"] = str(adventure.get("title", adventure_id))
	result["average_score"] = average_score
	result["mastery_before"] = old_mastery
	result["mastery"] = new_mastery
	result["mastery_level"] = _mastery_level(new_mastery)
	result["xp_reward"] = int(round(18.0 + average_score * 22.0 + float(difficulty) * 4.0))
	result["technique"] = str(adventure.get("technique", ""))
	result["expedition"] = expedition_id
	result["expedition_bonus"] = get_expedition_bonus(expedition_id)
	result["evolution_affinity"] = affinity_id
	_apply_world_transfer(result)
	_remember("completed", result)
	active_session.clear()
	save_state()
	session_completed.emit(result.duplicate(true))
	catalog_changed.emit(get_snapshot())
	return result

func _apply_world_transfer(result: Dictionary) -> void:
	var state: Node = get_node_or_null("/root/GameState")
	if state != null and state.has_method("perform_interaction"):
		var success: bool = float(result.get("average_score", 0.0)) >= 0.65
		var effects: Dictionary = {
			"energy": -5.0,
			"happiness": 6.0 if success else 3.0,
			"curiosity": 14.0 if success else 7.0,
			"quest_event": "discovery_completed"
		}
		state.call("perform_interaction", "learning_adventure", effects, int(result.get("xp_reward", 0)), ["learn", "mastery", str(result.get("adventure_id", ""))])
		if state.has_method("save_game_state"):
			state.call("save_game_state")
	var adaptive: Node = get_node_or_null("/root/AdaptiveLearning")
	if adaptive != null and adaptive.has_method("record_result"):
		adaptive.call("record_result", str((ADVENTURES[str(result.get("adventure_id", ""))] as Dictionary).get("domain", "logic")), clampi(int(round(float(result.get("mastery", 20.0)) / 10.0)), 1, 10), float(result.get("average_score", 0.0)) >= 0.65, 12.0, 0)
	var partner: Node = get_node_or_null("/root/PartnerWorld")
	if partner != null and partner.has_method("observe_technique"):
		partner.call("observe_technique", str(result.get("technique", "pattern_focus")), 0.72 + float(result.get("average_score", 0.0)) * 0.8)
	var brain: Node = get_node_or_null("/root/CompanionBrain")
	if brain != null and brain.has_method("observe_interaction"):
		brain.call("observe_interaction", "learn", 0.85 + float(result.get("average_score", 0.0)) * 0.25, {"adventure": result.get("adventure_id", ""), "mastery": result.get("mastery", 0.0)})
	var performance: Node = get_node_or_null("/root/CharacterPerformance")
	if performance != null and performance.has_method("request_action"):
		performance.call("request_action", "learn", clampf(float(result.get("average_score", 0.0)), 0.5, 1.0))
	var evolution: Node = get_node_or_null("/root/EvolutionService")
	if evolution != null and evolution.has_method("evaluate_runtime"):
		evolution.call("evaluate_runtime")

func _build_challenge(adventure_id: String, difficulty: int, seed_value: int, round_index: int) -> Dictionary:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_value + round_index * 7919 + difficulty * 101
	var domain: String = str((ADVENTURES[adventure_id] as Dictionary).get("domain", "logic"))
	match domain:
		"logic", "math", "systems":
			return _build_numeric_challenge(adventure_id, domain, difficulty, rng, round_index)
		"language", "media", "reasoning":
			return _build_context_challenge(adventure_id, domain, difficulty, rng, round_index)
		"empathy", "science", "creativity":
			return _build_scenario_challenge(adventure_id, domain, difficulty, rng, round_index)
		_:
			return _build_sequence_challenge(adventure_id, domain, difficulty, rng, round_index)

func _build_numeric_challenge(adventure_id: String, domain: String, difficulty: int, rng: RandomNumberGenerator, round_index: int) -> Dictionary:
	var start: int = rng.randi_range(2, 7 + difficulty)
	var step: int = rng.randi_range(2, 3 + difficulty)
	var correct: int = start + step * 4
	var answers: Array = [correct, correct + step, maxi(correct - step, 0)]
	_shuffle(answers, rng)
	var prompt: String = "Welche Zahl vervollständigt das System?\n%d · %d · %d · %d · ?" % [start, start + step, start + step * 2, start + step * 3]
	if domain == "systems":
		prompt = "Ein Leuchtknoten gewinnt pro Runde %d Energie. Er startet bei %d. Wie viel besitzt er nach vier Verstärkungen?" % [step, start]
	elif domain == "math":
		prompt = "Ein Expeditionsteam sammelt viermal je %d Signale und startet mit %d. Welche Gesamtsumme entsteht?" % [step, start]
	return _challenge(adventure_id, round_index, prompt, answers, [answers.find(correct)], "Jeder Schritt verändert den Wert um %d." % step, "Diese Regel kann später bei Ressourcen und Wegen helfen.", {"compare": 0.08, "explain": 0.12})

func _build_context_challenge(adventure_id: String, domain: String, difficulty: int, _rng: RandomNumberGenerator, round_index: int) -> Dictionary:
	var prompts: Dictionary = {
		"language": [
			["Zumi sagt: ‘Luma’ und zeigt auf ein warmes Licht. Später sagt Zumi ‘Luma’ zur aufgehenden Sonne. Was bedeutet es wahrscheinlich?", ["hell oder warm leuchtend", "laut und gefährlich", "klein und versteckt"], 0],
			["Das Wort ‘Nari’ erscheint immer, wenn jemand wartet und genau zuhört. Welche Bedeutung passt?", ["aufmerksam sein", "schnell weglaufen", "etwas zerbrechen"], 0]
		],
		"media": [
			["Eine Nachricht behauptet: ‘Alle Gartensignale sind gefährlich’, nennt aber keine Quelle. Was ist der beste nächste Schritt?", ["Quelle und Gegenbelege prüfen", "sofort weiterleiten", "nur die Überschrift glauben"], 0],
			["Ein Bild zeigt einen dunklen Bezirk, aber nicht den hellen Bereich daneben. Welche Frage hilft am meisten?", ["Was wurde außerhalb des Bildes weggelassen?", "Welche Farbe ist am schönsten?", "Wie oft wurde es geteilt?"], 0]
		],
		"reasoning": [
			["Kai sagt: ‘Die Brücke ist sicher, weil drei Tests bestanden wurden.’ Was ist der Beleg?", ["die drei bestandenen Tests", "Kais Lautstärke", "die Farbe der Brücke"], 0],
			["Zwei Bewohner wollen denselben Raum nutzen. Welche Lösung berücksichtigt beide Perspektiven?", ["Zeiten aufteilen und Bedürfnisse prüfen", "der Lautere entscheidet", "beide ignorieren"], 0]
		]
	}
	var pool: Array = prompts.get(domain, []) as Array
	var entry: Array = pool[round_index % pool.size()] as Array
	var answers: Array = (entry[1] as Array).duplicate()
	var correct_index: int = int(entry[2])
	return _challenge(adventure_id, round_index, str(entry[0]), answers, [correct_index], "Die beste Lösung nutzt Kontext oder überprüfbare Belege.", "Wende diese Prüfung auf Dialoge und Expeditionshinweise an.", {"observe": 0.06, "explain": 0.10})

func _build_scenario_challenge(adventure_id: String, domain: String, _difficulty: int, _rng: RandomNumberGenerator, round_index: int) -> Dictionary:
	var prompts: Dictionary = {
		"empathy": [
			["Ein Bitling zieht sich nach einem Fehler zurück. Welche Reaktion hilft wahrscheinlich am meisten?", ["ruhig nachfragen und Wahlmöglichkeiten geben", "sofort erneut prüfen", "den Fehler verspotten"], [0]],
			["Eine Bewohnerin wirkt überfordert und spricht sehr kurz. Was ist ein guter erster Schritt?", ["Tempo senken und Unterstützung anbieten", "mehr Aufgaben geben", "ihre Reaktion ignorieren"], [0]]
		],
		"science": [
			["Eine Pflanze leuchtet nach dem Gießen stärker. Was ist die beste überprüfbare Hypothese?", ["Wasser beeinflusst die Leuchtstärke", "die Pflanze mag Musik", "alle Pflanzen leuchten immer"], [0]],
			["Zwei Kristalle reagieren unterschiedlich. Welche Untersuchung ist am fairsten?", ["nur eine Bedingung gleichzeitig verändern", "beide gleichzeitig erhitzen und bewegen", "nur den schönsten wählen"], [0]]
		],
		"creativity": [
			["Eine Brücke ist zu schwer. Welche Ideen sind brauchbare neue Ansätze?", ["leichteres Material testen", "Stützpunkte neu verteilen", "das Problem ignorieren"], [0, 1]],
			["Ein Lernraum wirkt unruhig. Welche Änderungen könnten helfen?", ["Licht und Geräusche anpassen", "klare Zonen schaffen", "alle Hinweise entfernen"], [0, 1]]
		]
	}
	var pool: Array = prompts.get(domain, []) as Array
	var entry: Array = pool[round_index % pool.size()] as Array
	return _challenge(adventure_id, round_index, str(entry[0]), (entry[1] as Array).duplicate(), (entry[2] as Array).duplicate(), "Mehrere Lösungen können richtig sein, wenn sie das Ziel nachvollziehbar verbessern.", "Nutze dieselbe Denkweise beim Bauen, Pflegen und Erkunden.", {"experiment": 0.08, "explain": 0.10})

func _build_sequence_challenge(adventure_id: String, domain: String, difficulty: int, rng: RandomNumberGenerator, round_index: int) -> Dictionary:
	var patterns: Array = [
		["● ○ ● ○ ?", ["●", "○", "▲"], 0, "Die Formen wechseln sich ab."],
		["▲ ▲ ■ ▲ ▲ ■ ?", ["▲", "■", "●"], 0, "Nach zwei Dreiecken folgt ein Quadrat."],
		["links · oben · rechts · unten · ?", ["links", "oben", "rechts"], 0, "Die Richtung dreht sich im Kreis."]
	]
	var entry: Array = patterns[(round_index + rng.randi_range(0, patterns.size() - 1)) % patterns.size()] as Array
	return _challenge(adventure_id, round_index, "Setze die Folge fort:\n%s" % str(entry[0]), (entry[1] as Array).duplicate(), [int(entry[2])], str(entry[3]), "Muster helfen bei Rhythmus, Gedächtnis und sicheren Wegen.", {"observe": 0.08, "compare": 0.08})

func _challenge(adventure_id: String, round_index: int, prompt: String, answers: Array, correct_indices: Array, explanation: String, transfer_tip: String, approach_bonus: Dictionary) -> Dictionary:
	return {
		"id": "%s_%d" % [adventure_id, round_index],
		"adventure_id": adventure_id,
		"round": round_index + 1,
		"prompt": prompt,
		"answers": answers,
		"correct_indices": correct_indices,
		"explanation": explanation,
		"transfer_tip": transfer_tip,
		"approaches": APPROACHES.duplicate(true),
		"approach_bonus": approach_bonus.duplicate(true)
	}

func _ensure_profile(adventure_id: String) -> Dictionary:
	if not profiles.has(adventure_id):
		profiles[adventure_id] = {"mastery": 20.0, "attempts": 0, "successes": 0, "best_score": 0.0, "last_score": 0.0, "best_streak": 0, "last_played_at": 0}
	return profiles[adventure_id] as Dictionary

func _recommend_difficulty(profile: Dictionary) -> int:
	var mastery: float = float(profile.get("mastery", 20.0))
	var attempts: int = int(profile.get("attempts", 0))
	return clampi(int(round(mastery / 10.0)) + (0 if attempts < 2 else 1), 1, 10)

func _is_unlocked(adventure_id: String) -> bool:
	var index: int = ADVENTURES.keys().find(adventure_id)
	if index < 6:
		return true
	return total_sessions >= (index - 5) * 2 or get_average_mastery() >= 35.0 + float(index - 6) * 4.0

func _mastery_level(value: float) -> String:
	if value >= 90.0:
		return "LEGENDÄR"
	if value >= 75.0:
		return "GEMEISTERT"
	if value >= 55.0:
		return "SICHER"
	if value >= 35.0:
		return "WACHSEND"
	return "ENTDECKEND"

func _correct_answer_values(answers: Array, indices: Array) -> Array:
	var result: Array = []
	for index_variant: Variant in indices:
		var index: int = int(index_variant)
		if index >= 0 and index < answers.size():
			result.append(answers[index])
	return result

func _shuffle(values: Array, rng: RandomNumberGenerator) -> void:
	for index: int in range(values.size() - 1, 0, -1):
		var swap_index: int = rng.randi_range(0, index)
		var temporary: Variant = values[index]
		values[index] = values[swap_index]
		values[swap_index] = temporary

func _remember(event_type: String, data: Dictionary) -> void:
	history.append({"type": event_type, "data": data.duplicate(true), "at": int(Time.get_unix_time_from_system())})
	while history.size() > MAX_HISTORY:
		history.pop_front()

func _read_payload(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if not parsed is Dictionary:
		return {}
	var payload: Dictionary = parsed as Dictionary
	return payload if int(payload.get("version", 0)) > 0 else {}

func _copy_file(source: String, target: String) -> bool:
	var source_file: FileAccess = FileAccess.open(source, FileAccess.READ)
	if source_file == null:
		return false
	var bytes: PackedByteArray = source_file.get_buffer(source_file.get_length())
	source_file.close()
	var target_file: FileAccess = FileAccess.open(target, FileAccess.WRITE)
	if target_file == null:
		return false
	target_file.store_buffer(bytes)
	target_file.close()
	return true

func _dictionary_array(value: Variant, limit: int) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if value is Array:
		for entry: Variant in value:
			if entry is Dictionary:
				result.append((entry as Dictionary).duplicate(true))
	while result.size() > limit:
		result.pop_front()
	return result
