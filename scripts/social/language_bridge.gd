extends Node

## Semantic translation layer between human languages and Bitling speech.
## Any BCP-47 locale can be requested. Missing translations fall back to English
## while preserving the semantic intent, so no gameplay meaning is lost.

signal locale_changed(locale: String)
signal translation_registered(locale: String, key: String)

const FALLBACK_LOCALE := "en"
const INTENT_KEYS := {
	"greet": "intent.greet", "invite_play": "intent.invite_play",
	"share_discovery": "intent.share_discovery", "comfort": "intent.comfort",
	"celebrate": "intent.celebrate", "ask_question": "intent.ask_question",
	"explain_pattern": "intent.explain_pattern", "tell_joke": "intent.tell_joke",
	"debate": "intent.debate", "monologue": "intent.monologue",
	"teach": "intent.teach", "goodbye": "intent.goodbye"
}
const PROTOCOL_INTENTS := {
	"greet": "greet", "invite_play": "play_invite", "share_discovery": "share_discovery",
	"comfort": "comfort", "celebrate": "celebrate", "ask_question": "ask_question",
	"explain_pattern": "teach_pattern", "tell_joke": "tell_joke",
	"debate": "ask_question", "monologue": "share_discovery",
	"teach": "teach_pattern", "goodbye": "say_goodbye"
}

var current_locale: String = "de"
var translations: Dictionary = {}

func _ready() -> void:
	_load_builtin_translations()
	var state: Node = get_node_or_null("/root/GameState")
	if state != null:
		current_locale = normalize_locale(str(state.settings.get("language", "de")))

func set_locale(locale: String) -> void:
	current_locale = normalize_locale(locale)
	locale_changed.emit(current_locale)

func normalize_locale(locale: String) -> String:
	var cleaned: String = locale.strip_edges().replace("_", "-").to_lower()
	return FALLBACK_LOCALE if cleaned.is_empty() else cleaned

func register_translation(locale: String, key: String, text: String) -> bool:
	var normalized: String = normalize_locale(locale)
	if key.is_empty() or text.strip_edges().is_empty():
		return false
	if not translations.has(normalized):
		translations[normalized] = {}
	translations[normalized][key] = text.strip_edges()
	translation_registered.emit(normalized, key)
	return true

func translate(key: String, locale: String = "", values: Dictionary = {}) -> String:
	var requested: String = normalize_locale(locale if not locale.is_empty() else current_locale)
	var text: String = _lookup(requested, key)
	if text.is_empty() and requested.contains("-"):
		text = _lookup(requested.get_slice("-", 0), key)
	if text.is_empty():
		text = _lookup(FALLBACK_LOCALE, key)
	if text.is_empty():
		text = key
	for value_key in values.keys():
		text = text.replace("{%s}" % str(value_key), str(values[value_key]))
	return text

func translate_intent(intent: String, locale: String = "", payload: Dictionary = {}) -> String:
	var key: String = str(INTENT_KEYS.get(intent, "intent.unknown"))
	return translate(key, locale, payload)

func render_bitling_speech(intent: String, payload: Dictionary = {}, locale: String = "") -> Dictionary:
	var target_locale: String = normalize_locale(locale if not locale.is_empty() else current_locale)
	var emotion_name: String = str(payload.get("emotion", "calm"))
	var utterance: String = "Bii-luma!"
	var language: Node = get_node_or_null("/root/BitlingLanguage")
	if language != null and language.has_method("create_packet"):
		var protocol_intent: String = str(PROTOCOL_INTENTS.get(intent, "greet"))
		var emotion: Dictionary = {"dominant_emotion": emotion_name, "primary": emotion_name}
		var packet: Dictionary = language.create_packet(protocol_intent, payload, emotion)
		if not packet.is_empty() and language.has_method("render_utterance"):
			utterance = str(language.render_utterance(packet))
	var subtitle: String = translate_intent(intent, target_locale, payload)
	var profile: Node = get_node_or_null("/root/DevelopmentProfile")
	var human_speech: String = ""
	var can_speak_human: bool = profile != null and bool(profile.has_legendary_language())
	if can_speak_human:
		human_speech = subtitle
	return {
		"intent": intent, "bitling_utterance": utterance, "subtitle": subtitle,
		"human_speech": human_speech, "locale": target_locale,
		"legendary_translation": can_speak_human
	}

func decode_peer_packet(packet: Dictionary, locale: String = "") -> Dictionary:
	var protocol_intent: String = str(packet.get("intent", "unknown"))
	var intent: String = _display_intent_for_protocol(protocol_intent)
	var payload: Dictionary = packet.get("payload", {})
	return {
		"speaker_id": str(packet.get("speaker_id", "")), "intent": intent,
		"translation": translate_intent(intent, locale, payload),
		"original_utterance": str(packet.get("utterance", "")),
		"emotion": packet.get("emotion", {}).duplicate(true)
	}

func create_bitling_language_lesson(difficulty: int = 1, locale: String = "") -> Dictionary:
	var lessons: Array[Dictionary] = [
		{"token": "bii", "meaning_key": "lesson.bii", "example": "Bii-luma!"},
		{"token": "luma", "meaning_key": "lesson.luma", "example": "Mii-luma."},
		{"token": "zumi", "meaning_key": "lesson.zumi", "example": "Zumi-biki!"},
		{"token": "nobi", "meaning_key": "lesson.nobi", "example": "Nobi?"},
		{"token": "plonk", "meaning_key": "lesson.plonk", "example": "Plonk-wib-boppa!"}
	]
	var index: int = clampi(difficulty - 1, 0, lessons.size() - 1)
	var lesson: Dictionary = lessons[index].duplicate(true)
	lesson["meaning"] = translate(str(lesson.get("meaning_key", "")), locale)
	lesson.erase("meaning_key")
	return lesson

func get_language_capabilities() -> Dictionary:
	var profile: Node = get_node_or_null("/root/DevelopmentProfile")
	var legendary: bool = profile != null and bool(profile.has_legendary_language())
	return {
		"semantic_understanding": true, "requested_locale": current_locale,
		"fallback_locale": FALLBACK_LOCALE, "available_translation_locales": translations.keys(),
		"bitling_language_teaching": true, "human_speech": legendary,
		"peer_translation": legendary
	}

func _display_intent_for_protocol(protocol_intent: String) -> String:
	for display_intent in PROTOCOL_INTENTS.keys():
		if str(PROTOCOL_INTENTS[display_intent]) == protocol_intent:
			return str(display_intent)
	return "unknown"

func _lookup(locale: String, key: String) -> String:
	if not translations.has(locale):
		return ""
	return str(translations[locale].get(key, ""))

func _load_builtin_translations() -> void:
	translations = {
		"de": {
			"intent.greet": "Hallo! Ich freue mich, dich zu sehen.",
			"intent.invite_play": "Wollen wir etwas zusammen spielen?",
			"intent.share_discovery": "Ich habe etwas Spannendes entdeckt: {topic}",
			"intent.comfort": "Ich bleibe bei dir. Wir schaffen das gemeinsam.",
			"intent.celebrate": "Das war großartig! Lass uns das feiern.",
			"intent.ask_question": "Darf ich dir eine Frage stellen?",
			"intent.explain_pattern": "Ich glaube, ich habe das Muster verstanden.",
			"intent.tell_joke": "Achtung, mein bester schlechter Witz kommt.",
			"intent.debate": "Ich sehe das anders. Tauschen wir Argumente aus?",
			"intent.monologue": "Ich muss dir unbedingt erzählen, was mir durch den Kopf geht.",
			"intent.teach": "Ich kann dir zeigen, wie ich das gelernt habe.",
			"intent.goodbye": "Bis bald. Ich merke mir unser Gespräch.",
			"intent.unknown": "Der Bitling versucht etwas Neues auszudrücken.",
			"lesson.bii": "freundliche Aufmerksamkeit",
			"lesson.luma": "Licht, Freude oder ein warmer Gruß",
			"lesson.zumi": "Aufregung und Neugier",
			"lesson.nobi": "eine Frage oder Bitte",
			"lesson.plonk": "tollpatschiger Überraschungsmoment"
		},
		"en": {
			"intent.greet": "Hello! I am happy to see you.",
			"intent.invite_play": "Would you like to play something together?",
			"intent.share_discovery": "I discovered something exciting: {topic}",
			"intent.comfort": "I will stay with you. We can handle this together.",
			"intent.celebrate": "That was excellent! Let us celebrate.",
			"intent.ask_question": "May I ask you a question?",
			"intent.explain_pattern": "I think I understand the pattern.",
			"intent.tell_joke": "Warning: my best bad joke is coming.",
			"intent.debate": "I see it differently. Shall we exchange arguments?",
			"intent.monologue": "I need to tell you what is going through my mind.",
			"intent.teach": "I can show you how I learned this.",
			"intent.goodbye": "See you soon. I will remember our conversation.",
			"intent.unknown": "The Bitling is trying to express something new.",
			"lesson.bii": "friendly attention", "lesson.luma": "light, joy, or a warm greeting",
			"lesson.zumi": "excitement and curiosity", "lesson.nobi": "a question or request",
			"lesson.plonk": "a clumsy surprise"
		},
		"es": {"intent.greet": "¡Hola! Me alegra verte.", "intent.invite_play": "¿Jugamos juntos?", "intent.goodbye": "Hasta pronto. Recordaré nuestra conversación."},
		"fr": {"intent.greet": "Bonjour ! Je suis heureux de te voir.", "intent.invite_play": "Veux-tu jouer avec moi ?", "intent.goodbye": "À bientôt. Je me souviendrai de notre conversation."},
		"it": {"intent.greet": "Ciao! Sono felice di vederti.", "intent.invite_play": "Giochiamo insieme?", "intent.goodbye": "A presto. Ricorderò la nostra conversazione."},
		"pt": {"intent.greet": "Olá! Fico feliz em ver você.", "intent.invite_play": "Vamos brincar juntos?", "intent.goodbye": "Até logo. Vou lembrar da nossa conversa."},
		"pl": {"intent.greet": "Cześć! Miło cię widzieć.", "intent.invite_play": "Pobawimy się razem?", "intent.goodbye": "Do zobaczenia. Zapamiętam naszą rozmowę."},
		"tr": {"intent.greet": "Merhaba! Seni gördüğüme sevindim.", "intent.invite_play": "Birlikte oynayalım mı?", "intent.goodbye": "Yakında görüşürüz. Konuşmamızı hatırlayacağım."},
		"ru": {"intent.greet": "Привет! Я рад тебя видеть.", "intent.invite_play": "Давай поиграем вместе?", "intent.goodbye": "До скорого. Я запомню наш разговор."},
		"ja": {"intent.greet": "こんにちは。会えてうれしいです。", "intent.invite_play": "いっしょに遊びませんか？", "intent.goodbye": "またね。この会話を覚えておくよ。"},
		"ko": {"intent.greet": "안녕! 만나서 반가워.", "intent.invite_play": "같이 놀래?", "intent.goodbye": "다음에 봐. 우리 대화를 기억할게."},
		"zh": {"intent.greet": "你好！很高兴见到你。", "intent.invite_play": "我们一起玩好吗？", "intent.goodbye": "再见。我会记住我们的谈话。"},
		"ar": {"intent.greet": "مرحبًا! سعيد برؤيتك.", "intent.invite_play": "هل نلعب معًا؟", "intent.goodbye": "إلى اللقاء. سأتذكر حديثنا."},
		"hi": {"intent.greet": "नमस्ते! तुम्हें देखकर खुशी हुई।", "intent.invite_play": "क्या हम साथ खेलें?", "intent.goodbye": "फिर मिलेंगे। मैं हमारी बातचीत याद रखूँगा।"}
	}
