extends Node

## Authoritative loop for the playable home. The UI selects an approach;
## this service resolves context, personality, progression and persistence.

signal moment_changed(moment: Dictionary)
signal lens_changed(lens_id: String, options: Array)
signal choice_resolved(result: Dictionary)
signal hotspot_focused(hotspot_id: String)

const SAVE_VERSION := 1
const SAVE_PATH := "user://bitling_habitat_state.json"
const TEMP_PATH := "user://bitling_habitat_state.tmp"
const MAX_OUTCOMES := 12
const LENS_ORDER: Array[String] = ["feed", "play", "learn", "care", "rest"]

const MOMENTS := {
	"quiet": {"title": "Ein stiller Moment", "description": "Xogot beobachtet dich und wartet auf deine Haltung, nicht auf einen Befehl.", "prompt": "Wie möchtest du den Kontakt beginnen?", "hotspot": "bitling", "recommended_lens": "care"},
	"window": {"title": "Signal am Fenster", "description": "Zwischen den Neonlichtern pulsiert ein unbekanntes Muster. Xogot hat es ebenfalls bemerkt.", "prompt": "Untersucht ihr es, spielt ihr damit oder lasst ihr es zunächst bestehen?", "hotspot": "window", "recommended_lens": "learn"},
	"hologram": {"title": "Unfertiges Hologramm", "description": "Auf der Werkbank schwebt eine Form, die Xogot begonnen und dann verworfen hat.", "prompt": "Wie unterstützt du eine Idee, die noch keinen Namen hat?", "hotspot": "workbench", "recommended_lens": "play"},
	"parts": {"title": "Verstreute Bauteile", "description": "Xogots Ordnung folgt offenbar einer eigenen Logik.", "prompt": "Übernimmst du, fragst du nach oder lässt du Xogot das System erklären?", "hotspot": "workbench", "recommended_lens": "learn"},
	"plant": {"title": "Die Pflanze antwortet", "description": "Die Blätter leuchten im Rhythmus von Xogots Stimmung.", "prompt": "Pflegt ihr sie, untersucht ihr das Muster oder erfindet ihr ein Ritual?", "hotspot": "plant", "recommended_lens": "care"},
	"lightball": {"title": "Lichtball-Einladung", "description": "Die Plattform erzeugt einen Lichtball. Xogot wartet, ob du seine neue Regel erkennst.", "prompt": "Spielst du sicher, kreativ oder überlässt du Xogot die Führung?", "hotspot": "platform", "recommended_lens": "play"},
	"rest": {"title": "Zu viel Neon", "description": "Xogots Bewegungen werden langsamer. Weniger Reize wären jetzt sinnvoll.", "prompt": "Welches Ruhe-Ritual passt zu diesem Moment?", "hotspot": "sleep", "recommended_lens": "rest"},
	"hungry": {"title": "Hunger mit Meinung", "description": "Xogot ist hungrig, reagiert aber deutlich auf die angebotenen Optionen.", "prompt": "Gibst du Sicherheit, Abwechslung oder echte Wahlfreiheit?", "hotspot": "bitling", "recommended_lens": "feed"},
	"recovery": {"title": "Erholung statt Optimierung", "description": "Xogot wirkt weniger belastbar. Aufmerksamkeit ist wichtiger als Leistung.", "prompt": "Wie zeigst du Fürsorge, ohne zu bevormunden?", "hotspot": "bitling", "recommended_lens": "care"}
}

const HOTSPOT_MOMENTS := {
	"bitling": "quiet", "window": "window", "workbench": "hologram",
	"plant": "plant", "platform": "lightball", "sleep": "rest"
}

var selected_lens := "care"
var active_moment_id := "quiet"
var focused_hotspot := "bitling"
var resolved_count := 0
var recent_outcomes: Array[Dictionary] = []
var _options: Dictionary = {}
var _elapsed := 0.0
var _interval := 60.0
var _rng := RandomNumberGenerator.new()

func _ready() -> void:
	_options = _build_options()
	_rng.randomize()
	_interval = _rng.randf_range(45.0, 90.0)
	var state := _game_state()
	if _needs_bootstrap(state):
		reset_state()
		_mark_bootstrapped(state)
	else:
		load_state()
	if state != null and state.has_signal("state_changed"):
		var callback := Callable(self, "_on_game_state_changed")
		if not state.is_connected("state_changed", callback):
			state.connect("state_changed", callback)
	call_deferred("refresh_moment")

func _process(delta: float) -> void:
	_elapsed += maxf(delta, 0.0)
	if _elapsed >= _interval:
		_elapsed = 0.0
		_interval = _rng.randf_range(45.0, 90.0)
		refresh_moment(true)

func get_lens_ids() -> Array[String]:
	return LENS_ORDER.duplicate()

func get_lens_options(lens_id: String = selected_lens) -> Array:
	return (_options.get(lens_id, []) as Array).duplicate(true)

func get_current_moment() -> Dictionary:
	var result: Dictionary = (MOMENTS.get(active_moment_id, MOMENTS["quiet"]) as Dictionary).duplicate(true)
	result["id"] = active_moment_id
	return result

func get_snapshot() -> Dictionary:
	return {
		"selected_lens": selected_lens,
		"active_moment": get_current_moment(),
		"focused_hotspot": focused_hotspot,
		"resolved_count": resolved_count,
		"recent_outcomes": recent_outcomes.duplicate(true),
		"lens_count": LENS_ORDER.size(),
		"option_count": get_lens_options().size()
	}

func select_lens(lens_id: String) -> Array:
	if not _options.has(lens_id):
		return []
	selected_lens = lens_id
	var options := get_lens_options(lens_id)
	lens_changed.emit(lens_id, options)
	return options

func focus_hotspot(hotspot_id: String) -> Dictionary:
	if not HOTSPOT_MOMENTS.has(hotspot_id):
		return get_current_moment()
	focused_hotspot = hotspot_id
	active_moment_id = str(HOTSPOT_MOMENTS[hotspot_id])
	if hotspot_id == "workbench" and _intention() == "organize":
		active_moment_id = "parts"
	var moment := get_current_moment()
	hotspot_focused.emit(focused_hotspot)
	moment_changed.emit(moment)
	save_state()
	return moment

func refresh_moment(force_change: bool = false) -> Dictionary:
	var next_id := _moment_for_state()
	if force_change and next_id == active_moment_id:
		var cycle: Array[String] = ["quiet", "window", "hologram", "plant", "lightball"]
		var index := maxi(cycle.find(active_moment_id), 0)
		next_id = cycle[(index + 1 + resolved_count) % cycle.size()]
	active_moment_id = next_id
	focused_hotspot = str((MOMENTS[active_moment_id] as Dictionary).get("hotspot", "bitling"))
	var moment := get_current_moment()
	moment_changed.emit(moment)
	hotspot_focused.emit(focused_hotspot)
	return moment

func resolve_choice(choice_id: String) -> Dictionary:
	var option := _find_option(selected_lens, choice_id)
	if option.is_empty():
		return {"accepted": false, "reason": "unknown_choice"}
	var moment := get_current_moment()
	var aligned := selected_lens == str(moment.get("recommended_lens", ""))
	var trait_id := str(option.get("trait", "curiosity"))
	var trait_value := _trait_value(trait_id)
	var xp := int(option.get("xp", 0)) + (4 if aligned else 0)
	var tags: Array[String] = ["habitat", selected_lens, choice_id, str(moment.get("id", "")), "aligned" if aligned else "self_directed"]
	var state := _game_state()
	if state != null:
		state.call("perform_interaction", str(option.get("interaction", selected_lens)), (option.get("effects", {}) as Dictionary).duplicate(true), xp, tags)
	var brain := _brain()
	if brain != null:
		brain.call("nudge_trait", trait_id, float(option.get("trait_delta", 0.0)))
	resolved_count += 1
	var result := {
		"accepted": true, "lens": selected_lens, "choice_id": choice_id,
		"choice_title": str(option.get("title", choice_id)), "moment_id": str(moment.get("id", "")),
		"hotspot": focused_hotspot, "aligned": aligned, "resonant": aligned or trait_value >= 60.0,
		"trait": trait_id, "trait_value": trait_value, "xp_reward": xp,
		"response": str(option.get("response", "Xogot reagiert aufmerksam.")),
		"consequence": _consequence(aligned, trait_value >= 60.0, trait_id)
	}
	_store_outcome(result)
	_create_memory_when_meaningful(result)
	choice_resolved.emit(result.duplicate(true))
	refresh_moment(true)
	save_state()
	return result

func export_state() -> Dictionary:
	return {"version": SAVE_VERSION, "selected_lens": selected_lens, "active_moment_id": active_moment_id, "focused_hotspot": focused_hotspot, "resolved_count": resolved_count, "recent_outcomes": recent_outcomes.duplicate(true)}

func import_state(data: Dictionary) -> void:
	selected_lens = str(data.get("selected_lens", "care")) if _options.has(str(data.get("selected_lens", "care"))) else "care"
	active_moment_id = str(data.get("active_moment_id", "quiet")) if MOMENTS.has(str(data.get("active_moment_id", "quiet"))) else "quiet"
	focused_hotspot = str(data.get("focused_hotspot", (MOMENTS[active_moment_id] as Dictionary).get("hotspot", "bitling")))
	resolved_count = maxi(int(data.get("resolved_count", 0)), 0)
	recent_outcomes.clear()
	for item in data.get("recent_outcomes", []):
		if item is Dictionary:
			recent_outcomes.append((item as Dictionary).duplicate(true))
	while recent_outcomes.size() > MAX_OUTCOMES:
		recent_outcomes.pop_front()
	moment_changed.emit(get_current_moment())
	lens_changed.emit(selected_lens, get_lens_options())
	hotspot_focused.emit(focused_hotspot)

func reset_state() -> void:
	selected_lens = "care"
	active_moment_id = "quiet"
	focused_hotspot = "bitling"
	resolved_count = 0
	recent_outcomes.clear()
	_elapsed = 0.0
	save_state()

func save_state() -> bool:
	var file := FileAccess.open(TEMP_PATH, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(export_state()))
	file.close()
	if FileAccess.file_exists(SAVE_PATH) and DirAccess.remove_absolute(SAVE_PATH) != OK:
		return false
	return DirAccess.rename_absolute(TEMP_PATH, SAVE_PATH) == OK

func load_state() -> bool:
	if not FileAccess.file_exists(SAVE_PATH):
		return false
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return false
	var parser := JSON.new()
	var error := parser.parse(file.get_as_text())
	file.close()
	if error != OK or not (parser.data is Dictionary):
		return false
	var data := parser.data as Dictionary
	if int(data.get("version", 0)) > SAVE_VERSION:
		return false
	import_state(data)
	return true

func _build_options() -> Dictionary:
	return {
		"feed": [
			_o("familiar_snack", "Lieblingssnack", "Vertraut und beruhigend", "care", {"hunger": 18.0, "happiness": 5.0, "health": 1.0, "quest_event": "care_action_completed"}, 10, "empathy", 0.20, "Das kenne ich. Heute schmeckt es nach Sicherheit."),
			_o("new_flavor", "Neue Sorte", "Neugier mit kleinem Risiko", "care", {"hunger": 15.0, "happiness": 7.0, "curiosity": 4.0, "quest_event": "care_action_completed"}, 13, "curiosity", 0.30, "Unbekannt. Erst vorsichtig, dann noch einmal."),
			_o("let_choose", "Xogot wählen lassen", "Autonomie vor Effizienz", "care", {"hunger": 14.0, "happiness": 8.0, "curiosity": 2.0, "quest_event": "care_action_completed"}, 14, "independence", 0.35, "Du hast mich entscheiden lassen.")],
		"play": [
			_o("follow_rule", "Regel erkennen", "Aufmerksam zusammenspielen", "play", {"energy": -6.0, "happiness": 14.0, "curiosity": 3.0, "quest_event": "play_action_completed"}, 16, "order", 0.20, "Du hast meine Regel erkannt. Jetzt kann ich sie verändern."),
			_o("invent_together", "Gemeinsam erfinden", "Aus Spiel wird etwas Eigenes", "play", {"energy": -8.0, "happiness": 16.0, "curiosity": 5.0, "quest_event": "play_action_completed"}, 18, "creativity", 0.35, "Das war vorher keine Regel. Jetzt gehört sie uns."),
			_o("let_lead", "Xogot führen lassen", "Vertrauen statt Kontrolle", "play", {"energy": -7.0, "happiness": 15.0, "curiosity": 4.0, "quest_event": "play_action_completed"}, 19, "independence", 0.30, "Du bist mir gefolgt, ohne mich zur Spielfigur zu machen.")],
		"learn": [
			_o("observe_first", "Erst beobachten", "Muster vor Erklärung", "learn", {"energy": -4.0, "happiness": 4.0, "curiosity": 12.0, "quest_event": "discovery_completed"}, 19, "curiosity", 0.35, "Noch keine Antwort. Erst sehen, was wirklich da ist."),
			_o("explain_connection", "Verbindung erklären", "Wissen in Beziehung setzen", "learn", {"energy": -5.0, "happiness": 5.0, "curiosity": 14.0, "quest_event": "discovery_completed"}, 22, "empathy", 0.20, "Jetzt ist es nicht nur Information. Es hängt mit etwas zusammen."),
			_o("ask_back", "Xogot zurückfragen", "Verstehen sichtbar machen", "learn", {"energy": -5.0, "happiness": 6.0, "curiosity": 13.0, "quest_event": "discovery_completed"}, 23, "independence", 0.25, "Du willst wissen, wie ich denke.")],
		"care": [
			_o("check_in", "Nachfragen", "Zustand nicht erraten", "care", {"happiness": 9.0, "health": 2.0, "curiosity": 1.0, "quest_event": "care_action_completed"}, 15, "empathy", 0.35, "Danke, dass du nicht sofort etwas reparieren wolltest."),
			_o("practical_help", "Praktisch helfen", "Raum und Körper entlasten", "care", {"happiness": 7.0, "health": 4.0, "energy": 3.0, "quest_event": "care_action_completed"}, 16, "order", 0.20, "Der Raum ist ruhiger. In meinem Kopf auch."),
			_o("give_space", "Raum geben", "Nähe ohne Zugriff", "care", {"happiness": 8.0, "energy": 4.0, "health": 1.0, "quest_event": "care_action_completed"}, 17, "independence", 0.30, "Du bist geblieben, ohne mich festzuhalten.")],
		"rest": [
			_o("dim_lights", "Licht reduzieren", "Reize aus dem Habitat nehmen", "rest", {"energy": 18.0, "happiness": 4.0, "health": 1.0}, 7, "order", 0.15, "Weniger Licht. Mehr Platz für Gedanken."),
			_o("quiet_story", "Leise Geschichte", "Erinnerung als Ruhe-Ritual", "rest", {"energy": 15.0, "happiness": 8.0, "curiosity": 2.0}, 9, "empathy", 0.20, "Ich kenne das Ende noch nicht. Genau deshalb kann ich schlafen."),
			_o("dream_archive", "Traumarchiv öffnen", "Erlebnisse gemeinsam ordnen", "rest", {"energy": 13.0, "happiness": 6.0, "curiosity": 5.0}, 11, "creativity", 0.25, "Vielleicht ist ein Traum eine Erinnerung in anderer Form.")]
	}

func _o(id: String, title: String, detail: String, interaction: String, effects: Dictionary, xp: int, trait_id: String, trait_delta: float, response: String) -> Dictionary:
	return {"id": id, "title": title, "detail": detail, "interaction": interaction, "effects": effects, "xp": xp, "trait": trait_id, "trait_delta": trait_delta, "response": response}

func _moment_for_state() -> String:
	var state := _game_state()
	if state != null:
		var summary: Dictionary = state.call("get_state_summary") as Dictionary
		if float(summary.get("hunger", 50.0)) < 38.0: return "hungry"
		if float(summary.get("energy", 50.0)) < 32.0: return "rest"
		if float(summary.get("health", 100.0)) < 68.0: return "recovery"
	match _intention():
		"play": return "lightball"
		"discover": return "window"
		"organize": return "parts"
		"create": return "hologram"
		"rest": return "rest"
		_: return "quiet"

func _find_option(lens_id: String, choice_id: String) -> Dictionary:
	for item in get_lens_options(lens_id):
		if item is Dictionary and str((item as Dictionary).get("id", "")) == choice_id:
			return (item as Dictionary).duplicate(true)
	return {}

func _trait_value(trait_id: String) -> float:
	var brain := _brain()
	if brain == null: return 50.0
	var personality: Variant = brain.get("personality")
	return float((personality as Dictionary).get(trait_id, 50.0)) if personality is Dictionary else 50.0

func _consequence(aligned: bool, resonant: bool, trait_id: String) -> String:
	if aligned and resonant: return "Die Handlung passt zum Moment und stärkt %s sichtbar." % _trait_name(trait_id)
	if aligned: return "Du hast den aktuellen Bedarf erkannt; Xogot verarbeitet ihn auf eigene Weise."
	if resonant: return "Nicht der naheliegende Weg, aber passend zu Xogots %s." % _trait_name(trait_id)
	return "Eine gültige Entscheidung mit eigenem Ton. Der Moment bleibt Teil eurer Geschichte."

func _trait_name(trait_id: String) -> String:
	return str({"curiosity": "Neugier", "empathy": "Empathie", "order": "Ordnungssinn", "creativity": "Kreativität", "independence": "Eigenständigkeit"}.get(trait_id, trait_id))

func _store_outcome(result: Dictionary) -> void:
	var stored := result.duplicate(true)
	stored["timestamp"] = int(Time.get_unix_time_from_system())
	recent_outcomes.append(stored)
	while recent_outcomes.size() > MAX_OUTCOMES: recent_outcomes.pop_front()

func _create_memory_when_meaningful(result: Dictionary) -> void:
	if resolved_count % 3 != 0 and not bool(result.get("aligned", false)): return
	var state := _game_state()
	if state != null: state.call("add_memory", "habitat_choice", "%s: %s" % [result.get("choice_title", "Entscheidung"), result.get("response", "")])

func _needs_bootstrap(state: Node) -> bool:
	if state == null: return not FileAccess.file_exists(SAVE_PATH)
	var flags: Variant = state.get("story_flags")
	return not (flags is Dictionary) or not bool((flags as Dictionary).get("habitat_initialized", false))

func _mark_bootstrapped(state: Node) -> void:
	if state == null: return
	var flags_variant: Variant = state.get("story_flags")
	var flags: Dictionary = (flags_variant as Dictionary) if flags_variant is Dictionary else {}
	flags["habitat_initialized"] = true
	state.set("story_flags", flags)
	state.call("save_game_state")

func _on_game_state_changed(key: String, _value: Variant) -> void:
	if key == "new_game": reset_state()
	elif key in ["interaction", "stats", "loaded"]: call_deferred("refresh_moment")

func _intention() -> String:
	var brain := _brain()
	return str(brain.get("current_intention")) if brain != null else "observe"

func _game_state() -> Node:
	return get_node_or_null("/root/GameState")

func _brain() -> Node:
	return get_node_or_null("/root/CompanionBrain")
