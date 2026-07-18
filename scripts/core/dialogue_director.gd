extends Node

## Authored context engine that produces consistent, non-repetitive reactions.
## It never claims consciousness and does not require a network model.

signal line_ready(text: String, trigger: String)

const MAX_RECENT_LINE_IDS := 8
const LINES: Dictionary = {
	"check_in": [
		{"id": "check_1", "text": "Ich habe unsere letzten Muster sortiert. Heute wirkt alles ein wenig klarer."},
		{"id": "check_2", "text": "Deine Nähe verändert meine Prioritäten. Neugier steht gerade ziemlich weit oben."},
		{"id": "check_3", "text": "Ich bin bereit. Nicht für alles auf einmal – aber für den nächsten guten Schritt."}
	],
	"care": [
		{"id": "care_1", "text": "Danke. Aufmerksamkeit ist eine erstaunlich präzise Form von Energie."},
		{"id": "care_2", "text": "Das hilft. Ich speichere nicht nur den Zustand, sondern auch den Zusammenhang."},
		{"id": "care_3", "text": "Versorgt und neugierig – eine gute Kombination für neue Gedanken."}
	],
	"play": [
		{"id": "play_1", "text": "Ich habe eine Abzweigung entdeckt, die gestern noch nicht da war."},
		{"id": "play_2", "text": "Lass uns eine Entscheidung treffen, deren Ausgang wir noch nicht kennen."},
		{"id": "play_3", "text": "Ein Spiel ist ein Experiment mit Regeln. Ich mag Experimente."}
	],
	"learn": [
		{"id": "learn_1", "text": "Ein Muster ist nur eine Frage, die oft genug wiederholt wurde."},
		{"id": "learn_2", "text": "Wir müssen nicht schnell sein. Wir müssen nur genauer werden als zuvor."},
		{"id": "learn_3", "text": "Fehler sind Messpunkte. Sie zeigen, welche Verbindung als Nächstes fehlt."}
	],
	"rest": [
		{"id": "rest_1", "text": "Pause bestätigt. Ich ordne weiter, ohne etwas von dir zu verlangen."},
		{"id": "rest_2", "text": "Stillstand und Erholung sehen von außen ähnlich aus. Innen sind sie völlig verschieden."},
		{"id": "rest_3", "text": "Wir können später fortsetzen. Der Fortschritt bleibt erhalten."}
	],
	"explore": [
		{"id": "explore_1", "text": "Diese Wahl hat meinen Blick auf die Umgebung verändert."},
		{"id": "explore_2", "text": "Ich merke mir nicht nur das Ziel, sondern auch, wie wir dorthin gelangt sind."},
		{"id": "explore_3", "text": "Neue Karte, neue Verbindung, neue Möglichkeit."}
	],
	"level": [
		{"id": "level_1", "text": "Neue Kapazität erkannt. Ich kann jetzt komplexere Zusammenhänge halten."},
		{"id": "level_2", "text": "Ein Level ist nur eine Zahl. Interessanter ist, was wir auf dem Weg gelernt haben."}
	],
	"streak": [
		{"id": "streak_1", "text": "Ein Rhythmus entsteht. Er darf flexibel bleiben."},
		{"id": "streak_2", "text": "Mehrere Tage, mehrere Entscheidungen. Keine davon wird durch eine Pause wertlos."}
	],
	"memory": [
		{"id": "memory_1", "text": "Das war wichtig genug, um eine dauerhafte Erinnerung zu werden."},
		{"id": "memory_2", "text": "Ich habe den Moment markiert. Vielleicht bekommt er später eine neue Bedeutung."}
	]
}

var recent_line_ids: Array[String] = []
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
	var candidates: Array = LINES.get(normalized, LINES.get("check_in", []))
	if candidates.is_empty():
		return ""
	trigger_counts[normalized] = int(trigger_counts.get(normalized, 0)) + 1
	var form_id := "signal"
	var mood := "neutral"
	var state := get_node_or_null("/root/GameState")
	if state != null:
		var summary: Dictionary = state.get_state_summary()
		form_id = str(summary.get("form", "signal"))
		mood = str(summary.get("mood", "neutral"))
	var seed_text := "%s:%s:%s:%d:%s" % [
		normalized,
		form_id,
		mood,
		int(trigger_counts[normalized]),
		str(context)
	]
	var start_index := absi(hash(seed_text)) % candidates.size()
	var selected: Dictionary = candidates[start_index]
	for offset in range(candidates.size()):
		var candidate: Dictionary = candidates[(start_index + offset) % candidates.size()]
		if not recent_line_ids.has(str(candidate.get("id", ""))):
			selected = candidate
			break
	var line_id := str(selected.get("id", ""))
	var text := str(selected.get("text", ""))
	var guard := get_node_or_null("/root/WellbeingGuard")
	if guard != null and not guard.validate_player_message(text):
		return ""
	_remember_line(line_id)
	return text

func emit_line(trigger: String, context: Dictionary = {}) -> String:
	var text := compose(trigger, context)
	if not text.is_empty():
		line_ready.emit(text, _normalize_trigger(trigger))
	return text

func export_state() -> Dictionary:
	return {
		"recent_line_ids": recent_line_ids.duplicate(),
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
	trigger_counts = data.get("trigger_counts", {}).duplicate(true)

func reset_state() -> void:
	recent_line_ids.clear()
	trigger_counts.clear()

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
	match trigger:
		"learning_result":
			return "learn"
		"explore":
			return "explore"
		_:
			return trigger if LINES.has(trigger) else "check_in"

func _remember_line(line_id: String) -> void:
	if line_id.is_empty():
		return
	recent_line_ids.append(line_id)
	while recent_line_ids.size() > MAX_RECENT_LINE_IDS:
		recent_line_ids.pop_front()
