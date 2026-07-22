extends "res://scripts/core/habitat_behavior_runtime.gd"

## Makes relationship history alter the shared room and future situations.
## Formed habits manifest as persistent room states. Conflict creates explicit
## follow-up moments that must be lived through rather than hidden in a meter.

signal world_consequences_changed(snapshot: Dictionary)

const WORLD_VERSION := 1
const MAX_RESOLVED_WORLD_EVENTS := 24
const CONFLICT_RESET_THRESHOLD := 20.0
const CONFLICT_REPAIR_AMOUNTS := {
	"embraced": 18.0,
	"negotiated": 26.0,
	"resisted": 10.0
}
const CHOICE_MANIFESTATIONS := {
	"familiar_snack": {"hotspot": "bitling", "axis": "novelty", "direction": -1.0, "state": "comfort_ritual", "title": "Vertrautes Ritual", "accent": "green", "description": "Xogot hat aus Vertrautheit ein eigenes Essritual gemacht."},
	"new_flavor": {"hotspot": "window", "axis": "novelty", "direction": 1.0, "state": "taste_lab", "title": "Geschmackslabor", "accent": "cyan", "description": "Am Fenster sammelt Xogot Muster für neue Kombinationen."},
	"let_choose": {"hotspot": "bitling", "axis": "agency", "direction": 1.0, "state": "choice_station", "title": "Eigene Auswahl", "accent": "magenta", "description": "Xogot bereitet Entscheidungen inzwischen selbst vor."},
	"follow_rule": {"hotspot": "platform", "axis": "agency", "direction": -1.0, "state": "rule_grid", "title": "Regelgitter", "accent": "violet", "description": "Die Plattform speichert gemeinsam erkannte Regeln."},
	"invent_together": {"hotspot": "workbench", "axis": "novelty", "direction": 1.0, "state": "open_prototype", "title": "Offener Prototyp", "accent": "cyan", "description": "Ein unfertiges gemeinsames Objekt bleibt sichtbar und veränderbar."},
	"let_lead": {"hotspot": "platform", "axis": "agency", "direction": 1.0, "state": "xogot_course", "title": "Xogots Parcours", "accent": "magenta", "description": "Xogot baut eigene Spielabläufe, bevor du eintriffst."},
	"observe_first": {"hotspot": "window", "axis": "arousal", "direction": -1.0, "state": "observation_mode", "title": "Beobachtungsmodus", "accent": "yellow", "description": "Das Habitat dämpft Reize, solange Xogot Muster sammelt."},
	"explain_connection": {"hotspot": "workbench", "axis": "contact", "direction": 1.0, "state": "connection_map", "title": "Verbindungskarte", "accent": "cyan", "description": "Erklärungen werden als sichtbare Beziehungen im Raum abgelegt."},
	"ask_back": {"hotspot": "window", "axis": "agency", "direction": 1.0, "state": "question_beacon", "title": "Frage-Signal", "accent": "magenta", "description": "Xogot sendet eigene Fragen in den Raum, statt nur zu antworten."},
	"check_in": {"hotspot": "plant", "axis": "contact", "direction": 1.0, "state": "care_pulse", "title": "Fürsorgepuls", "accent": "green", "description": "Die Resonanzpflanze reagiert auf gegenseitiges Nachfragen."},
	"practical_help": {"hotspot": "workbench", "axis": "agency", "direction": -1.0, "state": "support_layout", "title": "Hilfsordnung", "accent": "yellow", "description": "Werkzeuge liegen so bereit, dass Belastung sinkt."},
	"give_space": {"hotspot": "plant", "axis": "contact", "direction": -1.0, "state": "quiet_boundary", "title": "Ruhige Grenze", "accent": "violet", "description": "Ein stiller Bereich markiert Nähe ohne Zugriff."},
	"dim_lights": {"hotspot": "sleep", "axis": "arousal", "direction": -1.0, "state": "low_light_routine", "title": "Dämmerungsroutine", "accent": "yellow", "description": "Das Ruhepod senkt Licht und Bewegung frühzeitig."},
	"quiet_story": {"hotspot": "sleep", "axis": "contact", "direction": 1.0, "state": "story_nest", "title": "Geschichtennest", "accent": "green", "description": "Fragmente gemeinsamer Geschichten bleiben am Ruhepod."},
	"dream_archive": {"hotspot": "sleep", "axis": "novelty", "direction": 1.0, "state": "dream_archive", "title": "Traumarchiv", "accent": "cyan", "description": "Neue Traummuster erscheinen als veränderliche Lichtspuren."}
}

var world_marks: Dictionary = {}
var pending_world_events: Array[Dictionary] = []
var resolved_world_events: Array[Dictionary] = []
var generated_habit_events: Dictionary = {}
var conflict_tiers: Dictionary = {}
var world_event_counter := 0

func _ready() -> void:
	super._ready()
	world_consequences_changed.emit(get_world_consequence_snapshot())

func get_current_moment() -> Dictionary:
	var event := _active_world_event()
	if not event.is_empty():
		return (event.get("moment", {}) as Dictionary).duplicate(true)
	return super.get_current_moment()

func refresh_moment(force_change: bool = false) -> Dictionary:
	var event := _active_world_event()
	if event.is_empty():
		return super.refresh_moment(force_change)
	focused_hotspot = str(event.get("hotspot", "bitling"))
	var moment := get_current_moment()
	moment_changed.emit(moment)
	hotspot_focused.emit(focused_hotspot)
	return moment

func focus_hotspot(hotspot_id: String) -> Dictionary:
	var event := _active_world_event()
	if not event.is_empty() and str(event.get("hotspot", "")) == hotspot_id:
		focused_hotspot = hotspot_id
		var moment := get_current_moment()
		hotspot_focused.emit(focused_hotspot)
		moment_changed.emit(moment)
		return moment
	return super.focus_hotspot(hotspot_id)

func get_snapshot() -> Dictionary:
	var snapshot := super.get_snapshot()
	snapshot["world_consequences"] = get_world_consequence_snapshot()
	var contract: Dictionary = snapshot.get("agency_contract", {}) as Dictionary
	contract["world_manifestations"] = true
	contract["follow_up_events"] = true
	contract["conflict_requires_play"] = true
	snapshot["agency_contract"] = contract
	return snapshot

func get_world_consequence_snapshot() -> Dictionary:
	return {
		"version": WORLD_VERSION,
		"world_marks": world_marks.duplicate(true),
		"pending_events": pending_world_events.duplicate(true),
		"resolved_events": resolved_world_events.duplicate(true),
		"active_event": _active_world_event(),
		"marked_hotspot_count": world_marks.size(),
		"pending_event_count": pending_world_events.size(),
		"event_counter": world_event_counter
	}

func export_state() -> Dictionary:
	var data := super.export_state()
	data["world_version"] = WORLD_VERSION
	data["world_marks"] = world_marks.duplicate(true)
	data["pending_world_events"] = pending_world_events.duplicate(true)
	data["resolved_world_events"] = resolved_world_events.duplicate(true)
	data["generated_habit_events"] = generated_habit_events.duplicate(true)
	data["conflict_tiers"] = conflict_tiers.duplicate(true)
	data["world_event_counter"] = world_event_counter
	return data

func import_state(data: Dictionary) -> void:
	super.import_state(data)
	world_marks = (data.get("world_marks", {}) as Dictionary).duplicate(true)
	pending_world_events.clear()
	for event_variant in data.get("pending_world_events", []):
		if event_variant is Dictionary:
			pending_world_events.append((event_variant as Dictionary).duplicate(true))
	resolved_world_events.clear()
	for event_variant in data.get("resolved_world_events", []):
		if event_variant is Dictionary:
			resolved_world_events.append((event_variant as Dictionary).duplicate(true))
	generated_habit_events = (data.get("generated_habit_events", {}) as Dictionary).duplicate(true)
	conflict_tiers = (data.get("conflict_tiers", {}) as Dictionary).duplicate(true)
	world_event_counter = maxi(int(data.get("world_event_counter", 0)), 0)
	_sanitize_world_state()

func reset_state() -> void:
	super.reset_state()
	world_marks.clear()
	pending_world_events.clear()
	resolved_world_events.clear()
	generated_habit_events.clear()
	conflict_tiers.clear()
	world_event_counter = 0
	save_state()

func _store_outcome(result: Dictionary) -> void:
	var resolving_event := _active_world_event()
	super._store_outcome(result)
	if not resolving_event.is_empty():
		_resolve_world_event(resolving_event, result)
	_generate_habit_manifestation(result)
	_generate_conflict_follow_up(result)
	result["world_consequences"] = get_world_consequence_snapshot()
	world_consequences_changed.emit(get_world_consequence_snapshot())

func _generate_habit_manifestation(result: Dictionary) -> void:
	if not bool(result.get("habit_formed", false)):
		return
	var choice_id := str(result.get("choice_id", ""))
	if choice_id.is_empty() or generated_habit_events.has(choice_id):
		return
	var manifestation: Dictionary = CHOICE_MANIFESTATIONS.get(choice_id, {}) as Dictionary
	if manifestation.is_empty():
		return
	generated_habit_events[choice_id] = true
	var hotspot := str(manifestation.get("hotspot", "bitling"))
	var mark := manifestation.duplicate(true)
	mark["choice_id"] = choice_id
	mark["level"] = 1
	mark["intensity"] = clampf(float(result.get("habit_strength", 55.0)), 0.0, 100.0)
	mark["formed_session"] = session_index
	world_marks[hotspot] = mark
	var event := _build_world_event("initiative", manifestation, choice_id)
	pending_world_events.append(event)
	result["world_event_created"] = event.get("id", "")
	result["world_mark_created"] = hotspot

func _generate_conflict_follow_up(result: Dictionary) -> void:
	for axis_variant in BEHAVIOR_AXES:
		var axis := str(axis_variant)
		if float(axis_conflicts.get(axis, 0.0)) < CONFLICT_RESET_THRESHOLD:
			conflict_tiers[axis] = 0
	var conflict: Dictionary = result.get("active_conflict", {}) as Dictionary
	if conflict.is_empty():
		return
	var axis := str(conflict.get("axis", ""))
	var strength := float(conflict.get("strength", 0.0))
	var tier := 2 if strength >= CONFLICT_RESIST_THRESHOLD else 1
	if tier <= int(conflict_tiers.get(axis, 0)):
		return
	conflict_tiers[axis] = tier
	var manifestation := _conflict_manifestation(axis, tier)
	var event := _build_world_event("conflict", manifestation, "conflict_%s_%d" % [axis, tier])
	event["axis"] = axis
	event["conflict_strength"] = strength
	event["tier"] = tier
	pending_world_events.append(event)
	result["conflict_event_created"] = event.get("id", "")

func _build_world_event(event_type: String, manifestation: Dictionary, source_id: String) -> Dictionary:
	world_event_counter += 1
	var hotspot := str(manifestation.get("hotspot", "bitling"))
	var title := str(manifestation.get("title", "Gemeinsame Folge"))
	var description := str(manifestation.get("description", "Eine frühere Entscheidung ist im Habitat sichtbar geworden."))
	var prompt := "Xogot hat diese Entwicklung selbst begonnen. Wie gehst du mit ihr weiter?" if event_type == "initiative" else "Die Reibung ist jetzt Teil des Raums. Wie lebt ihr mit ihr weiter?"
	var cues: Array[String] = []
	if event_type == "initiative":
		cues.append("verstärken")
		cues.append("verändern")
		cues.append("umleiten")
	else:
		cues.append("aushandeln")
		cues.append("Grenze halten")
		cues.append("anderen Zugang wählen")
	var event_id := "%s_%04d" % [event_type, world_event_counter]
	return {
		"id": event_id,
		"type": event_type,
		"source_id": source_id,
		"hotspot": hotspot,
		"axis": str(manifestation.get("axis", "")),
		"direction": float(manifestation.get("direction", 0.0)),
		"title": title,
		"state": str(manifestation.get("state", event_type)),
		"accent": str(manifestation.get("accent", "cyan")),
		"created_session": session_index,
		"moment": {
			"id": event_id,
			"title": title,
			"description": description,
			"prompt": prompt,
			"hotspot": hotspot,
			"cues": cues,
			"no_correct_answer": true,
			"world_event": true,
			"event_type": event_type,
			"source_id": source_id
		}
	}

func _resolve_world_event(event: Dictionary, result: Dictionary) -> void:
	if pending_world_events.is_empty() or str((pending_world_events[0] as Dictionary).get("id", "")) != str(event.get("id", "")):
		return
	pending_world_events.pop_front()
	var choice_id := str(result.get("choice_id", ""))
	var profile: Dictionary = CHOICE_PROFILES.get(choice_id, {}) as Dictionary
	var event_axis := str(event.get("axis", ""))
	var choice_axis := str(profile.get("axis", ""))
	var choice_direction := float(profile.get("direction", 0.0))
	var event_direction := float(event.get("direction", 0.0))
	var resolution := "redirected"
	if choice_axis == event_axis and is_equal_approx(choice_direction, event_direction):
		resolution = "reinforced"
	elif choice_axis == event_axis:
		resolution = "transformed"
	var hotspot := str(event.get("hotspot", "bitling"))
	var mark: Dictionary = (world_marks.get(hotspot, {}) as Dictionary).duplicate(true)
	if mark.is_empty():
		mark = {"title": str(event.get("title", "Gemeinsame Folge")), "state": str(event.get("state", "changed")), "accent": str(event.get("accent", "cyan")), "level": 0, "intensity": 30.0}
	match resolution:
		"reinforced":
			mark["level"] = mini(int(mark.get("level", 0)) + 1, 5)
			mark["intensity"] = clampf(float(mark.get("intensity", 0.0)) + 15.0, 0.0, 100.0)
		"transformed":
			mark["state"] = "%s_transformed" % str(mark.get("state", "changed"))
			mark["accent"] = "violet"
			mark["intensity"] = clampf(float(mark.get("intensity", 0.0)) + 8.0, 0.0, 100.0)
		_:
			mark["state"] = "%s_redirected" % str(mark.get("state", "changed"))
			mark["accent"] = "yellow"
			mark["intensity"] = clampf(float(mark.get("intensity", 0.0)) + 4.0, 0.0, 100.0)
	world_marks[hotspot] = mark
	if str(event.get("type", "")) == "conflict":
		var mode := str(result.get("execution_mode", "embraced"))
		var repair := float(CONFLICT_REPAIR_AMOUNTS.get(mode, 18.0))
		axis_conflicts[event_axis] = clampf(float(axis_conflicts.get(event_axis, 0.0)) - repair, 0.0, 100.0)
		result["conflict_repair"] = repair
	var resolved := event.duplicate(true)
	resolved["resolution"] = resolution
	resolved["resolved_choice"] = choice_id
	resolved["resolved_session"] = session_index
	resolved_world_events.append(resolved)
	while resolved_world_events.size() > MAX_RESOLVED_WORLD_EVENTS:
		resolved_world_events.pop_front()
	result["world_event_resolved"] = str(event.get("id", ""))
	result["world_resolution"] = resolution
	result["world_hotspot"] = hotspot
	result["consequence"] = "%s Die Folge bleibt als %s im Habitat sichtbar." % [str(result.get("consequence", "")), _resolution_label(resolution)]

func _active_world_event() -> Dictionary:
	if pending_world_events.is_empty():
		return {}
	return (pending_world_events[0] as Dictionary).duplicate(true)

func _conflict_manifestation(axis: String, tier: int) -> Dictionary:
	var data := {
		"agency": {"hotspot": "workbench", "title": "Wer entscheidet hier?", "state": "agency_friction", "accent": "magenta", "description": "Xogots Eigenständigkeit und eure gemeinsame Struktur passen gerade nicht zusammen."},
		"novelty": {"hotspot": "window", "title": "Neugier gegen Sicherheit", "state": "novelty_friction", "accent": "cyan", "description": "Das Fenster zeigt gleichzeitig neue Signale und vertraute Schutzmuster."},
		"arousal": {"hotspot": "sleep", "title": "Reiz oder Ruhe", "state": "arousal_friction", "accent": "yellow", "description": "Das Habitat kann sich nicht entscheiden, ob es aktivieren oder dämpfen soll."},
		"contact": {"hotspot": "plant", "title": "Nähe mit Grenze", "state": "contact_friction", "accent": "violet", "description": "Die Resonanzpflanze zeigt gleichzeitig Annäherung und Rückzug."}
	}.get(axis, {}) as Dictionary
	var result := data.duplicate(true)
	result["axis"] = axis
	result["direction"] = 0.0
	if tier >= 2:
		result["title"] = "GRENZE: %s" % str(result.get("title", axis))
	return result

func _resolution_label(resolution: String) -> String:
	return str({"reinforced": "verstärktes Muster", "transformed": "verändertes Muster", "redirected": "umgeleitetes Muster"}.get(resolution, resolution))

func _sanitize_world_state() -> void:
	var sanitized_marks: Dictionary = {}
	for hotspot_variant in world_marks.keys():
		var hotspot := str(hotspot_variant)
		if not HOTSPOT_MOMENTS.has(hotspot):
			continue
		var mark_variant: Variant = world_marks[hotspot_variant]
		if not mark_variant is Dictionary:
			continue
		var mark := (mark_variant as Dictionary).duplicate(true)
		mark["level"] = clampi(int(mark.get("level", 0)), 0, 5)
		mark["intensity"] = clampf(float(mark.get("intensity", 0.0)), 0.0, 100.0)
		sanitized_marks[hotspot] = mark
	world_marks = sanitized_marks
	while resolved_world_events.size() > MAX_RESOLVED_WORLD_EVENTS:
		resolved_world_events.pop_front()
