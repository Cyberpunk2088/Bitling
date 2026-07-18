extends CanvasLayer

## Read-only responsive profile sheet for passport, IQ, attributes, skills,
## specializations, upbringing, preferences and rarity.

const COLOR_BACKDROP := Color(0.01, 0.02, 0.05, 0.92)
const COLOR_PANEL := Color("10182a")
const COLOR_BORDER := Color("6de7ff")
const COLOR_TEXT := Color("f4f7ff")
const COLOR_MUTED := Color("aab4cf")
const COLOR_ACCENT := Color("b783ff")

var launcher: Button
var backdrop: ColorRect
var content: RichTextLabel

func _ready() -> void:
	layer = 32
	_build_ui()
	_connect_services()
	_refresh()

func _build_ui() -> void:
	launcher = Button.new()
	launcher.text = "AUSWEIS"
	launcher.tooltip_text = "Bitling-Ausweis und Entwicklungsprofil öffnen"
	launcher.anchor_left = 1.0
	launcher.anchor_right = 1.0
	launcher.offset_left = -146.0
	launcher.offset_right = -16.0
	launcher.offset_top = 88.0
	launcher.offset_bottom = 138.0
	launcher.add_theme_font_size_override("font_size", 14)
	launcher.add_theme_stylebox_override("normal", _style(Color("151f35"), COLOR_ACCENT, 14))
	launcher.add_theme_stylebox_override("hover", _style(Color("202c49"), COLOR_BORDER, 14))
	launcher.pressed.connect(open_profile)
	add_child(launcher)

	backdrop = ColorRect.new()
	backdrop.color = COLOR_BACKDROP
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.visible = false
	add_child(backdrop)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(340, 620)
	panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	panel.add_theme_stylebox_override("panel", _style(COLOR_PANEL, COLOR_BORDER, 22))
	center.add_child(panel)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	panel.add_child(column)

	var header := HBoxContainer.new()
	column.add_child(header)
	var title := Label.new()
	title.text = "BITLING-PROFIL"
	title.add_theme_color_override("font_color", COLOR_TEXT)
	title.add_theme_font_size_override("font_size", 22)
	header.add_child(title)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(spacer)
	var close_button := Button.new()
	close_button.text = "×"
	close_button.tooltip_text = "Profil schließen"
	close_button.custom_minimum_size = Vector2(48, 48)
	close_button.pressed.connect(close_profile)
	header.add_child(close_button)

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(300, 520)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(scroll)

	content = RichTextLabel.new()
	content.bbcode_enabled = true
	content.fit_content = true
	content.custom_minimum_size = Vector2(300, 0)
	content.add_theme_color_override("default_color", COLOR_TEXT)
	content.add_theme_font_size_override("normal_font_size", 15)
	scroll.add_child(content)

func _connect_services() -> void:
	var profile := get_node_or_null("/root/DevelopmentProfile")
	if profile != null and not profile.profile_changed.is_connected(_on_profile_changed):
		profile.profile_changed.connect(_on_profile_changed)
	var identity := get_node_or_null("/root/BitlingIdentity")
	if identity != null and not identity.identity_updated.is_connected(_on_identity_updated):
		identity.identity_updated.connect(_on_identity_updated)

func open_profile() -> void:
	_refresh()
	backdrop.visible = true
	launcher.visible = false

func close_profile() -> void:
	backdrop.visible = false
	launcher.visible = true

func _unhandled_input(event: InputEvent) -> void:
	if backdrop.visible and event.is_action_pressed("ui_cancel"):
		close_profile()
		get_viewport().set_input_as_handled()

func _refresh() -> void:
	if content == null:
		return
	var identity := get_node_or_null("/root/BitlingIdentity")
	var profile := get_node_or_null("/root/DevelopmentProfile")
	if identity == null or profile == null:
		content.text = "Profil wird geladen …"
		return
	var passport: Dictionary = identity.get_public_passport()
	var snapshot: Dictionary = profile.get_display_snapshot()
	var rarity: Dictionary = snapshot.get("rarity", {})
	var tier := str(rarity.get("tier", "COMMON"))
	var sparkle := " ✦ SCHIMMERND ✦" if tier == "LEGENDARY" else ""
	var lines: Array[String] = []
	lines.append("[center][font_size=28]◉   ◉[/font_size]\n[b]%s[/b][/center]" % str(passport.get("display_name", "Bitling")))
	lines.append("[color=#aab4cf]ID[/color]  %s" % str(passport.get("bitling_id", "—")))
	lines.append("[color=#aab4cf]Geboren[/color]  %s" % str(passport.get("birth_label", "—")))
	lines.append("[color=#aab4cf]Generation[/color]  %d" % int(passport.get("generation", 1)))
	lines.append("[color=#aab4cf]Phase / Form[/color]  %s / %s" % [str(passport.get("development_phase", "EGG")), str(passport.get("form_id", "signal"))])
	lines.append("[color=#aab4cf]Größe / Gewicht[/color]  %.1f cm / %d g" % [float(passport.get("height_cm", 0.0)), int(passport.get("weight_g", 0))])
	lines.append("[font_size=22][color=#6de7ff][b]IQ %d[/b][/color][/font_size]" % int(snapshot.get("intelligence_quotient", passport.get("intelligence_quotient", 100))))
	lines.append("[color=#aab4cf]Seltenheit[/color]  [b]%s%s[/b]" % [tier, sparkle])
	lines.append("\n[color=#b783ff][b]ATTRIBUTE[/b][/color]")
	lines.append(_format_attributes(snapshot.get("attributes", {})))
	lines.append("\n[color=#b783ff][b]FERTIGKEITEN[/b][/color]")
	lines.append(_format_skills(snapshot.get("skills", {})))
	lines.append("\n[color=#b783ff][b]SPEZIALISIERUNGEN[/b][/color]")
	lines.append(_format_specializations(snapshot.get("specializations", {}), profile))
	lines.append("\n[color=#b783ff][b]FÄHIGKEITEN[/b][/color]")
	lines.append(_format_abilities(snapshot.get("abilities", {})))
	lines.append("\n[color=#b783ff][b]ERZIEHUNG & AUTONOMIE[/b][/color]")
	lines.append(_format_upbringing(snapshot))
	lines.append("\n[color=#b783ff][b]VORLIEBEN[/b][/color]")
	lines.append(_format_preferences(snapshot))
	lines.append("\n[color=#aab4cf]Altersanpassung[/color]  %s" % str(snapshot.get("player_age_band", "adult")).to_upper())
	if tier == "LEGENDARY":
		lines.append("\n[color=#ffdf7e][b]LEGENDÄRE GABE[/b][/color]\nKann Bitling-Sprache übersetzen und in freigegebenen Menschensprachen sprechen.")
	content.text = "\n".join(lines)

func _format_attributes(values: Dictionary) -> String:
	if values.is_empty():
		return "Noch keine Werte."
	var labels := {
		"intelligence": "Intelligenz", "empathy": "Empathie", "humor": "Humor",
		"coordination": "Koordination", "discipline": "Disziplin", "creativity": "Kreativität",
		"charisma": "Charisma", "resilience": "Widerstandskraft", "curiosity": "Neugier"
	}
	var result: Array[String] = []
	for key in labels.keys():
		result.append("%s  [color=#6de7ff]%d[/color]" % [labels[key], int(round(float(values.get(key, 0.0))))])
	return "\n".join(result)

func _format_skills(values: Dictionary) -> String:
	if values.is_empty():
		return "Noch keine Fertigkeiten."
	var labels := {
		"logic": "Logik", "language": "Sprachen", "teaching": "Unterrichten",
		"debate": "Debattieren", "humor": "Komik", "cooking": "Kochen",
		"exploration": "Erkunden", "music": "Musik", "social": "Soziales",
		"self_care": "Selbstfürsorge"
	}
	var result: Array[String] = []
	for key in labels.keys():
		var entry: Dictionary = values.get(key, {})
		result.append("%s  Lv.%d · %d%%" % [labels[key], int(entry.get("level", 1)), int(round(float(entry.get("rating", 0.0))))])
	return "\n".join(result)

func _format_specializations(values: Dictionary, profile: Node) -> String:
	if values.is_empty():
		return "Noch keine Spezialisierung. Die erste beginnt auf BRONZE."
	var result: Array[String] = []
	var keys := values.keys()
	keys.sort()
	for key in keys:
		var entry: Dictionary = values[key]
		result.append("%s  [b]%s[/b] · %d XP" % [str(key).capitalize(), profile.get_rank_name(int(entry.get("rank", 0))), int(round(float(entry.get("xp", 0.0))))])
	return "\n".join(result)

func _format_abilities(values: Dictionary) -> String:
	var active: Array[String] = []
	for key in values.keys():
		if bool(values[key]):
			active.append("✓ %s" % str(key).replace("_", " ").capitalize())
	return "\n".join(active) if not active.is_empty() else "Noch keine besondere Fähigkeit freigeschaltet."

func _format_upbringing(snapshot: Dictionary) -> String:
	var values: Dictionary = snapshot.get("upbringing", {})
	var lines: Array[String] = [
		"Disziplin  %d%%" % int(round(float(values.get("discipline", 0.0)))),
		"Routine  %d%%" % int(round(float(values.get("routine", 0.0)))),
		"Selbstständigkeit  %d%%" % int(round(float(values.get("independence", 0.0)))),
		"Soziale Sicherheit  %d%%" % int(round(float(values.get("social_confidence", 0.0)))),
		"Autonomie  [color=#6de7ff]%d%%[/color]" % int(round(float(snapshot.get("autonomy_score", 0.0)))),
		"Effizienz  %d%%" % int(round(float(snapshot.get("autonomy_efficiency", 0.35)) * 100.0))
	]
	return "\n".join(lines)

func _format_preferences(snapshot: Dictionary) -> String:
	var values: Dictionary = snapshot.get("preferences", {})
	var hobbies: Array = values.get("hobbies", [])
	var favorite := str(snapshot.get("favorite_bitling_id", ""))
	return "Hobbys  %s\nLieblingsessen  %s\nLieblingsthema  %s\nLieblings-Bitling  %s" % [
		", ".join(hobbies),
		str(values.get("favorite_food", "—")),
		str(values.get("favorite_topic", "—")),
		favorite if not favorite.is_empty() else "noch niemand"
	]

func _style(background: Color, border: Color, radius: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(radius)
	style.content_margin_left = 16.0
	style.content_margin_right = 16.0
	style.content_margin_top = 14.0
	style.content_margin_bottom = 14.0
	return style

func _on_profile_changed(_snapshot: Dictionary) -> void:
	if backdrop.visible:
		_refresh()

func _on_identity_updated(_snapshot: Dictionary) -> void:
	if backdrop.visible:
		_refresh()
