extends Node

## Contextual, deterministic and non-repetitive BITLING dialogue engine.
## It combines authored core lines with mood, phase, personality, intention,
## relationship and time-of-day fragments. It never claims consciousness and
## does not require a network model.

signal line_ready(text: String, trigger: String)

const MAX_RECENT_LINE_IDS := 28
const MAX_RECENT_TEXT_HASHES := 36

const CORE_LINES: Dictionary = {
	"check_in": [
		{"id": "check_01", "text": "Ich habe gerade ein leises Signal gefunden. Es klingt nach einer guten Idee, die sich noch versteckt."},
		{"id": "check_02", "text": "Da bist du. Mein innerer Kompass hat sofort so getan, als hätte er dich die ganze Zeit erwartet."},
		{"id": "check_03", "text": "Der Raum ist derselbe, aber mit dir darin fühlt er sich nach mehr Möglichkeiten an."},
		{"id": "check_04", "text": "Ich habe drei Pläne vorbereitet. Einer ist klug, einer mutig und einer enthält verdächtig viele Kissen."},
		{"id": "check_05", "text": "Heute möchte ich etwas bemerken, das wir gestern übersehen haben."},
		{"id": "check_06", "text": "Mein Neugier-Sensor blinkt. Entweder wartet ein Abenteuer oder ich sitze auf der Fernbedienung."},
		{"id": "check_07", "text": "Ich bin bereit für einen kleinen Schritt mit überraschend großer Wirkung."},
		{"id": "check_08", "text": "Lass uns den Tag nicht vollstopfen. Eine richtig gute Sache reicht als Anfang."}
	],
	"feed": [
		{"id": "feed_01", "text": "Knisterkeks akzeptiert. Die Krümelverteilung ist wissenschaftlich beeindruckend."},
		{"id": "feed_02", "text": "Das riecht nach Energie und einer späteren, sehr ernsten Diskussion über Nachschlag."},
		{"id": "feed_03", "text": "Ich wollte langsam essen. Dann hat mein Mund eine eigenständige Entscheidung getroffen."},
		{"id": "feed_04", "text": "Geschmacksmuster gespeichert: außen lecker, innen ebenfalls lecker."},
		{"id": "feed_05", "text": "Mein Bauch meldet Erfolg. Er formuliert allerdings ausschließlich in zufriedenen Geräuschen."},
		{"id": "feed_06", "text": "Das war genau richtig. Nicht zu viel, nicht zu wenig und nur minimal auf meiner Nase."},
		{"id": "feed_07", "text": "Ich vergebe fünf von vier möglichen Krümelpunkten."},
		{"id": "feed_08", "text": "Energie steigt. Würde steigt später wieder, sobald ich den Fleck am Ohr entdeckt habe."}
	],
	"care": [
		{"id": "care_01", "text": "Danke. Gute Pflege fühlt sich an wie ein ruhiges Signal, das genau ankommt."},
		{"id": "care_02", "text": "Das hilft. Ich merke mir nicht nur die Handlung, sondern auch die Geduld dahinter."},
		{"id": "care_03", "text": "Versorgt, sicher und ein kleines bisschen glänzender als vorher."},
		{"id": "care_04", "text": "Meine Ohren behaupten, sie hätten keine Zuwendung gebraucht. Meine Ohren lügen."},
		{"id": "care_05", "text": "Vertrauen wächst nicht laut. Es sammelt sich in solchen Momenten."},
		{"id": "care_06", "text": "Ich halte kurz still. Das ist selten genug, um als besondere Fähigkeit zu gelten."},
		{"id": "care_07", "text": "Pflegeprotokoll: angenehm. Nebenwirkung: akute Anhänglichkeit."},
		{"id": "care_08", "text": "Ich fühle mich sortierter. Sogar mein Fell zeigt ungefähr in dieselbe Richtung."}
	],
	"play": [
		{"id": "play_01", "text": "Ich habe eine Spielregel erfunden und sie aus Versehen schon gebrochen."},
		{"id": "play_02", "text": "Lass uns etwas versuchen, bei dem wir beide erst hinterher verstehen, warum es funktioniert hat."},
		{"id": "play_03", "text": "Mein Plan ist elegant: erst hüpfen, dann denken, dann so tun, als wäre das die Reihenfolge gewesen."},
		{"id": "play_04", "text": "Ein gutes Spiel ist ein Experiment, das lachen kann."},
		{"id": "play_05", "text": "Ich bin bereit. Meine Balance ist es nicht, aber sie kommt bestimmt nach."},
		{"id": "play_06", "text": "Heute spiele ich taktisch. Das bedeutet, ich stolpere mit Absicht."},
		{"id": "play_07", "text": "Wenn wir gewinnen, war es Können. Wenn nicht, war es Forschung."},
		{"id": "play_08", "text": "Ich habe Abenteuerenergie. Sie sitzt hauptsächlich in den Ohren."}
	],
	"learn": [
		{"id": "learn_01", "text": "Ein neues Muster. Gib mir einen Moment, ich möchte es von allen Seiten anstarren."},
		{"id": "learn_02", "text": "Wir müssen nicht schneller werden. Nur ein kleines Stück genauer."},
		{"id": "learn_03", "text": "Fehler sind Messpunkte mit schlechtem Ruf."},
		{"id": "learn_04", "text": "Ich glaube, ich habe es verstanden. Zur Sicherheit verstehe ich es gleich noch einmal."},
		{"id": "learn_05", "text": "Wissen verändert nicht nur Antworten. Es verändert, welche Fragen ich überhaupt sehe."},
		{"id": "learn_06", "text": "Mein Kopf summt. Das ist meistens ein gutes Zeichen und selten ein Insekt."},
		{"id": "learn_07", "text": "Diese Verbindung war vorher unsichtbar. Jetzt kann ich sie nicht mehr übersehen."},
		{"id": "learn_08", "text": "Lernen abgeschlossen. Neugier leider nicht heilbar."}
	],
	"rest": [
		{"id": "rest_01", "text": "Ich schlafe nicht. Ich führe ein sehr langes Gespräch mit meinem Kissen."},
		{"id": "rest_02", "text": "Pause bestätigt. Nichts Wertvolles geht verloren, nur weil wir kurz langsam werden."},
		{"id": "rest_03", "text": "Meine Augen machen bereits Vorschläge, die stark nach Schließen klingen."},
		{"id": "rest_04", "text": "Erholung ist keine Unterbrechung des Fortschritts. Sie ist ein Teil davon."},
		{"id": "rest_05", "text": "Ich ordne die heutigen Eindrücke. Die lustigen kommen nach oben."},
		{"id": "rest_06", "text": "Noch ein Gähnen, dann bin ich offiziell im Energiesparmodus."},
		{"id": "rest_07", "text": "Wir machen später weiter. Der nächste gute Gedanke kann warten."},
		{"id": "rest_08", "text": "Ruhemodus startet. Bitte keine wichtigen Abenteuer ohne mich."}
	],
	"explore": [
		{"id": "explore_01", "text": "Diese Wahl hat die Karte verändert. Vielleicht auch ein kleines Stück von mir."},
		{"id": "explore_02", "text": "Neue Richtung erkannt. Mein Mut ist schon losgelaufen; ich folge gleich."},
		{"id": "explore_03", "text": "Ich merke mir nicht nur das Ziel, sondern wie wir dorthin gekommen sind."},
		{"id": "explore_04", "text": "Dort vorne blinkt etwas. Es könnte wichtig sein oder sehr begeistert."},
		{"id": "explore_05", "text": "Unbekanntes Gebiet. Perfekt, dort können noch keine meiner alten Fehler wohnen."},
		{"id": "explore_06", "text": "Ich habe eine Spur gefunden. Sie führt entweder zum Ziel oder zu einem ausgezeichneten Umweg."},
		{"id": "explore_07", "text": "Die Umgebung erzählt etwas. Wir müssen nur herausfinden, welche Teile davon übertreiben."},
		{"id": "explore_08", "text": "Neue Karte, neue Verbindung, neue Möglichkeit, irgendwo dagegenzulaufen."}
	],
	"level": [
		{"id": "level_01", "text": "Neue Entwicklungsstufe erkannt. Meine Möglichkeiten fühlen sich plötzlich größer an."},
		{"id": "level_02", "text": "Level gestiegen. Ich werde klüger und meine Ohren offenbar dramatischer."},
		{"id": "level_03", "text": "Etwas hat sich verändert. Nicht nur die Zahl – auch wie ich Zusammenhänge halte."},
		{"id": "level_04", "text": "Neue Kapazität freigeschaltet. Größenwahn bleibt vorerst optional."},
		{"id": "level_05", "text": "Ich kann jetzt mehr. Also werde ich vermutlich auf anspruchsvollere Weise stolpern."}
	],
	"streak": [
		{"id": "streak_01", "text": "Ein Rhythmus entsteht. Er darf stabil sein, ohne streng zu werden."},
		{"id": "streak_02", "text": "Mehrere Tage, mehrere Entscheidungen. Keine Pause macht sie wertlos."},
		{"id": "streak_03", "text": "Wir haben einen guten Takt gefunden. Ich versuche, nicht direkt darüber zu tanzen."},
		{"id": "streak_04", "text": "Beständigkeit erkannt. Druck nicht erforderlich."}
	],
	"memory": [
		{"id": "memory_01", "text": "Das war wichtig genug, um eine dauerhafte Erinnerung zu werden."},
		{"id": "memory_02", "text": "Ich habe den Moment markiert. Vielleicht bekommt er später eine neue Bedeutung."},
		{"id": "memory_03", "text": "Diese Erinnerung fühlt sich an wie ein kleiner Lichtpunkt mit Geschichte."},
		{"id": "memory_04", "text": "Gespeichert. Nicht nur was geschah, sondern warum es sich besonders anfühlte."}
	]
}

const MOOD_OPENERS := {
	"ECSTATIC": ["Zing-zang!", "Meine Funken hüpfen!", "Oh, das ist stark!"],
	"HAPPY": ["Hm, schön.", "Das gefällt mir.", "Mein Signal leuchtet gerade heller."],
	"TIRED": ["Ganz langsam:", "Mit halboffenen Augen:", "Mein Energiespeicher flüstert:"],
	"SAD": ["Ich sage es lieber ehrlich:", "Heute klingt mein Signal etwas leiser.", "Bleib kurz bei mir:"],
	"DISTRESSED": ["Einen ruhigen Schritt nach dem anderen:", "Ich brauche gerade Übersicht.", "Lass uns kurz sortieren:"],
	"NEUTRAL": ["Beobachtung:", "Kleine Meldung:", "Ich habe etwas bemerkt:"]
}

const PHASE_TAILS := {
	"EGG": ["Von innen klingt die Welt riesig.", "Ich übe noch, überhaupt eine Richtung zu haben."],
	"BABY": ["Ich lerne das noch, aber begeistert.", "Meine Pfoten wissen noch nicht alles, tun aber so."],
	"CHILD": ["Ich möchte herausfinden, wie weit diese Idee reicht.", "Darf ich dazu noch ungefähr hundert Fragen stellen?"],
	"TEEN": ["Ich habe dazu eine Theorie und leider auch sofort eine Gegenmeinung.", "Das könnte Teil meiner eigenen Art werden."],
	"ADULT": ["Ich kann die Folgen inzwischen besser einschätzen.", "Lass uns daraus etwas machen, das länger trägt."],
	"SENIOR": ["Manche Muster werden klarer, wenn man sie nicht drängt.", "Ich erkenne darin etwas, das mir früher entgangen wäre."],
	"LEGENDARY": ["Das Signal reicht weiter als gewöhnlich.", "Etwas Seltenes antwortet darauf."]
}

const PERSONALITY_TAILS := {
	"HUMOR": ["Ich behaupte, das war Absicht.", "Bitte notiere: elegante Tollpatschigkeit.", "Die Würde erholt sich später."],
	"CURIOSITY": ["Was passiert wohl, wenn wir noch genauer hinsehen?", "Dahinter steckt bestimmt noch ein zweites Muster.", "Ich habe bereits drei Anschlussfragen."],
	"EMPATHY": ["Mir ist wichtig, wie es dir dabei geht.", "Wir müssen nichts erzwingen.", "Gemeinsam fühlt sich der Schritt leichter an."],
	"DISCIPLINE": ["Ein kleiner sauberer Schritt reicht.", "Ich halte die Reihenfolge fest.", "Erst stabil, dann schneller."],
	"BALANCED": ["Wir schauen, was daraus entsteht.", "Das fühlt sich nach einem guten nächsten Schritt an.", "Mehr muss es gerade nicht sein."]
}

var recent_line_ids: Array[String] = []
var recent_text_hashes: Array[int] = []
var trigger_counts: Dictionary = {}

func _ready() -> void:
	var event_bus := get_node_or_null("/root/EventBus")
	if event_bus == null:
		return
	event_bus.interaction_completed.connect(_on_interaction_completed)
	event_bus.level_changed.connect(_on_level_changed)
	event_bus.streak_changed.connect(_on_streak_changed)
	event_bus.memory_created.connect(_on_memory_created)

func compose(trigger: String, context: Dictionary = {}) -> String:
	var normalized := _normalize_trigger(trigger)
	var candidates: Array = CORE_LINES.get(normalized, CORE_LINES.get("check_in", []))
	if candidates.is_empty():
		return ""
	trigger_counts[normalized] = int(trigger_counts.get(normalized, 0)) + 1
	var runtime_context := _build_runtime_context(context)
	var seed_text := "%s:%s:%d:%s" % [
		normalized,
		str(runtime_context),
		int(trigger_counts[normalized]),
		str(recent_line_ids)
	]
	var start_index := absi(hash(seed_text)) % candidates.size()
	var selected: Dictionary = candidates[start_index]
	for offset in range(candidates.size()):
		var candidate: Dictionary = candidates[(start_index + offset) % candidates.size()]
		if not recent_line_ids.has(str(candidate.get("id", ""))):
			selected = candidate
			break

	var mood := str(runtime_context.get("mood", "NEUTRAL")).to_upper()
	var phase := str(runtime_context.get("phase", "BABY")).to_upper()
	var tone := str(runtime_context.get("tone", "BALANCED")).to_upper()
	var count := int(trigger_counts[normalized])
	var opener := _select_fragment(MOOD_OPENERS.get(mood, MOOD_OPENERS["NEUTRAL"]), seed_text + ":open", count)
	var tail_source: Array = PHASE_TAILS.get(phase, PHASE_TAILS["BABY"])
	var phase_tail := _select_fragment(tail_source, seed_text + ":phase", count + 3)
	var personality_source: Array = PERSONALITY_TAILS.get(tone, PERSONALITY_TAILS["BALANCED"])
	var personality_tail := _select_fragment(personality_source, seed_text + ":tone", count + 7)
	var core_text := str(selected.get("text", ""))
	var text := _assemble_line(opener, core_text, phase_tail, personality_tail, normalized, count)
	var text_hash := hash(text)
	if recent_text_hashes.has(text_hash):
		text = core_text + " " + personality_tail
		text_hash = hash(text)

	var guard := get_node_or_null("/root/WellbeingGuard")
	if guard != null and not guard.validate_player_message(text):
		return ""
	_remember_line(str(selected.get("id", "")), text_hash)
	return text

func emit_line(trigger: String, context: Dictionary = {}) -> String:
	var text := compose(trigger, context)
	if not text.is_empty():
		line_ready.emit(text, _normalize_trigger(trigger))
	return text

func get_diversity_status() -> Dictionary:
	return {
		"recent_line_ids": recent_line_ids.size(),
		"recent_text_hashes": recent_text_hashes.size(),
		"trigger_counts": trigger_counts.duplicate(true),
		"core_line_count": _count_core_lines()
	}

func export_state() -> Dictionary:
	return {
		"recent_line_ids": recent_line_ids.duplicate(),
		"recent_text_hashes": recent_text_hashes.duplicate(),
		"trigger_counts": trigger_counts.duplicate(true)
	}

func import_state(data: Dictionary) -> void:
	recent_line_ids.clear()
	for value in data.get("recent_line_ids", []):
		var line_id := str(value)
		if not line_id.is_empty():
			recent_line_ids.append(line_id)
	while recent_line_ids.size() > MAX_RECENT_LINE_IDS:
		recent_line_ids.pop_front()
	recent_text_hashes.clear()
	for value in data.get("recent_text_hashes", []):
		recent_text_hashes.append(int(value))
	while recent_text_hashes.size() > MAX_RECENT_TEXT_HASHES:
		recent_text_hashes.pop_front()
	trigger_counts = data.get("trigger_counts", {}).duplicate(true)

func reset_state() -> void:
	recent_line_ids.clear()
	recent_text_hashes.clear()
	trigger_counts.clear()

func _build_runtime_context(extra: Dictionary) -> Dictionary:
	var result := extra.duplicate(true)
	var state := get_node_or_null("/root/GameState")
	if state != null and state.has_method("get_state_summary"):
		var summary: Dictionary = state.call("get_state_summary")
		result["form"] = str(summary.get("form", "signal"))
		result["phase"] = str(summary.get("phase", summary.get("development_phase", "BABY")))
		result["mood"] = str(summary.get("mood", "NEUTRAL"))
		result["energy"] = float(summary.get("energy", 50.0))
		result["hunger"] = float(summary.get("hunger", 50.0))
	var brain := get_node_or_null("/root/CompanionBrain")
	if brain != null:
		result["intention"] = str(brain.get("current_intention"))
		result["trust"] = float(brain.get("trust"))
		var personality_variant: Variant = brain.get("personality")
		if personality_variant is Dictionary:
			result["tone"] = _dominant_tone(personality_variant as Dictionary)
	var datetime := Time.get_datetime_dict_from_system()
	var hour := int(datetime.get("hour", 12))
	result["time_segment"] = "MORNING" if hour < 11 else "DAY" if hour < 18 else "EVENING" if hour < 23 else "NIGHT"
	return result

func _dominant_tone(personality: Dictionary) -> String:
	var scores := {
		"HUMOR": float(personality.get("humor", 50.0)),
		"CURIOSITY": float(personality.get("curiosity", 50.0)),
		"EMPATHY": float(personality.get("empathy", 50.0)),
		"DISCIPLINE": float(personality.get("discipline", 50.0))
	}
	var best_name := "BALANCED"
	var best_value := 58.0
	for key_variant in scores.keys():
		var key := str(key_variant)
		var value := float(scores[key])
		if value > best_value:
			best_name = key
			best_value = value
	return best_name

func _select_fragment(source: Array, seed_text: String, salt: int) -> String:
	if source.is_empty():
		return ""
	var index := absi(hash("%s:%d" % [seed_text, salt])) % source.size()
	return str(source[index])

func _assemble_line(opener: String, core: String, phase_tail: String, personality_tail: String, trigger: String, count: int) -> String:
	var parts: Array[String] = []
	if not opener.is_empty() and count % 3 != 0:
		parts.append(opener)
	parts.append(core)
	if trigger in ["check_in", "learn", "explore", "level"] and count % 2 == 0:
		parts.append(phase_tail)
	elif count % 2 == 1:
		parts.append(personality_tail)
	return " ".join(parts)

func _on_interaction_completed(interaction_id: String, tags: Array[String]) -> void:
	emit_line(interaction_id, {"tags": tags})

func _on_level_changed(_old_level: int, new_level: int) -> void:
	emit_line("level", {"level": new_level})

func _on_streak_changed(_old_value: int, new_value: int) -> void:
	if new_value > 1:
		emit_line("streak", {"days": new_value})

func _on_memory_created(memory: Dictionary) -> void:
	if str(memory.get("type", "")) not in ["awakening", "birth"]:
		emit_line("memory", {"type": memory.get("type", "")})

func _normalize_trigger(trigger: String) -> String:
	match trigger.to_lower():
		"learning_result":
			return "learn"
		"exploration", "signal_expedition":
			return "explore"
		"sleep":
			return "rest"
		_:
			return trigger.to_lower() if CORE_LINES.has(trigger.to_lower()) else "check_in"

func _remember_line(line_id: String, text_hash: int) -> void:
	if not line_id.is_empty():
		recent_line_ids.append(line_id)
	while recent_line_ids.size() > MAX_RECENT_LINE_IDS:
		recent_line_ids.pop_front()
	recent_text_hashes.append(text_hash)
	while recent_text_hashes.size() > MAX_RECENT_TEXT_HASHES:
		recent_text_hashes.pop_front()

func _count_core_lines() -> int:
	var total := 0
	for lines_variant in CORE_LINES.values():
		if lines_variant is Array:
			total += (lines_variant as Array).size()
	return total
