extends Node

## Original BITLING evolution paths.
## Forms are unlocked by a combination of progression, personality, relationship
## and demonstrated learning rather than level alone.

signal form_available(form_id: String)
signal evolved(old_form: String, new_form: String)

const FORMS: Dictionary = {
	"signal": {
		"name": "Signal",
		"description": "The first stable shape of a new digital life.",
		"level": 1
	},
	"spark": {
		"name": "Spark",
		"description": "A bright, playful form driven by connection.",
		"level": 10,
		"relationship": 15.0
	},
	"prism": {
		"name": "Prism",
		"description": "A curious form that refracts every discovery into new ideas.",
		"level": 25,
		"relationship": 30.0,
		"learning": 35.0,
		"traits": {"curiosity": 58.0}
	},
	"guardian": {
		"name": "Guardian",
		"description": "A protective form shaped by empathy and trust.",
		"level": 25,
		"relationship": 40.0,
		"trust": 45.0,
		"traits": {"empathy": 58.0}
	},
	"weaver": {
		"name": "Weaver",
		"description": "A creative form that builds systems from memories and patterns.",
		"level": 40,
		"relationship": 50.0,
		"learning": 50.0,
		"traits": {"creativity": 62.0, "curiosity": 60.0}
	},
	"sentinel": {
		"name": "Sentinel",
		"description": "A courageous form specialized in strategic protection.",
		"level": 40,
		"relationship": 50.0,
		"trust": 60.0,
		"traits": {"courage": 60.0, "order": 55.0}
	},
	"sage": {
		"name": "Sage",
		"description": "A reflective form that turns experience into transferable wisdom.",
		"level": 60,
		"relationship": 65.0,
		"learning": 68.0,
		"traits": {"order": 62.0, "empathy": 58.0}
	},
	"aurora": {
		"name": "Aurora",
		"description": "A rare synthesis of trust, mastery, curiosity and self-direction.",
		"level": 80,
		"relationship": 82.0,
		"trust": 78.0,
		"learning": 76.0,
		"traits": {"curiosity": 68.0, "creativity": 68.0, "independence": 60.0}
	}
}

var current_form: String = "signal"
var discovered_forms: Array[String] = ["signal"]
var evolution_history: Array[Dictionary] = []
var last_available_forms: Array[String] = []

func evaluate_context(context: Dictionary) -> Array[String]:
	var available: Array[String] = []
	for form_id in FORMS.keys():
		if form_id == current_form:
			continue
		var requirements: Dictionary = FORMS[form_id]
		if _meets_requirements(requirements, context):
			available.append(form_id)
			if not discovered_forms.has(form_id):
				discovered_forms.append(form_id)
				form_available.emit(form_id)
	available.sort_custom(_sort_forms_by_level)
	last_available_forms = available.duplicate()
	return available

func evaluate_runtime() -> Array[String]:
	var state := get_node_or_null("/root/GameState")
	var brain := get_node_or_null("/root/CompanionBrain")
	var learning := get_node_or_null("/root/AdaptiveLearning")
	if state == null or brain == null or learning == null:
		return []
	return evaluate_context({
		"level": int(state.level),
		"relationship": float(brain.relationship_score),
		"trust": float(brain.trust),
		"learning": float(learning.get_average_rating()),
		"personality": brain.personality.duplicate(true)
	})

func select_evolution(form_id: String) -> bool:
	if not FORMS.has(form_id) or not last_available_forms.has(form_id):
		return false
	var old_form := current_form
	current_form = form_id
	evolution_history.append({
		"from": old_form,
		"to": current_form,
		"timestamp": int(Time.get_unix_time_from_system())
	})
	evolved.emit(old_form, current_form)
	return true

func get_current_form() -> Dictionary:
	var data: Dictionary = FORMS.get(current_form, FORMS.signal).duplicate(true)
	data["id"] = current_form
	return data

func get_form(form_id: String) -> Dictionary:
	if not FORMS.has(form_id):
		return {}
	var data: Dictionary = FORMS[form_id].duplicate(true)
	data["id"] = form_id
	return data

func export_state() -> Dictionary:
	return {
		"current_form": current_form,
		"discovered_forms": discovered_forms.duplicate(),
		"evolution_history": evolution_history.duplicate(true)
	}

func import_state(data: Dictionary) -> void:
	var loaded_form := str(data.get("current_form", "signal"))
	current_form = loaded_form if FORMS.has(loaded_form) else "signal"
	discovered_forms.clear()
	for value in data.get("discovered_forms", ["signal"]):
		var form_id := str(value)
		if FORMS.has(form_id) and not discovered_forms.has(form_id):
			discovered_forms.append(form_id)
	if not discovered_forms.has("signal"):
		discovered_forms.push_front("signal")
	evolution_history.clear()
	for item in data.get("evolution_history", []):
		if item is Dictionary:
			evolution_history.append(item.duplicate(true))
	last_available_forms.clear()

func reset_state() -> void:
	current_form = "signal"
	discovered_forms = ["signal"]
	evolution_history.clear()
	last_available_forms.clear()

func _meets_requirements(requirements: Dictionary, context: Dictionary) -> bool:
	if int(context.get("level", 1)) < int(requirements.get("level", 1)):
		return false
	if float(context.get("relationship", 0.0)) < float(requirements.get("relationship", 0.0)):
		return false
	if float(context.get("trust", 0.0)) < float(requirements.get("trust", 0.0)):
		return false
	if float(context.get("learning", 0.0)) < float(requirements.get("learning", 0.0)):
		return false
	var personality: Dictionary = context.get("personality", {})
	var required_traits: Dictionary = requirements.get("traits", {})
	for trait_name in required_traits.keys():
		if float(personality.get(trait_name, 0.0)) < float(required_traits[trait_name]):
			return false
	return true

func _sort_forms_by_level(a: String, b: String) -> bool:
	return int(FORMS[a].get("level", 1)) < int(FORMS[b].get("level", 1))
