extends Node

## World-first Living Home interface. The 3D room remains visible while compact
## responsive panels expose room condition, object interactions and decoration.

signal home_opened
signal home_closed

const COLOR_BG := Color("070b1a")
const COLOR_PANEL := Color("0b1228")
const COLOR_PANEL_SOFT := Color("111936")
const COLOR_BORDER := Color("31416e")
const COLOR_CYAN := Color("42e8ff")
const COLOR_VIOLET := Color("a855f7")
const COLOR_MAGENTA := Color("f044d4")
const COLOR_GREEN := Color("64e6a2")
const COLOR_GOLD := Color("ffc85a")
const COLOR_TEXT := Color("f4f7ff")
const COLOR_MUTED := Color("8d9abd")

const OBJECT_ORDER := [
	"sleep_pod",
	"signal_kitchen",
	"learning_desk",
	"holo_projector",
	"memory_archive",
	"garden_wall",
	"cleaning_drone",
	"weather_window"
]

const OBJECT_ACTIONS: Dictionary = {
	"sleep_pod": "AUSRUHEN",
	"signal_kitchen": "ZUBEREITEN",
	"learning_desk": "FORSCHEN",
	"holo_projector": "ERLEBEN",
	"memory_archive": "ERINNERN",
	"garden_wall": "PFLEGEN",
	"cleaning_drone": "ORDNEN",
	"weather_window": "BEOBACHTEN"
}

const OBJECT_GLYPHS: Dictionary = {
	"sleep_pod": "☾",
	"signal_kitchen": "◉",
	"learning_desk": "▤",
	"holo_projector": "◇",
	"memory_archive": "◎",
	"garden_wall": "✦",
	"cleaning_drone": "◌",
	"weather_window": "⌁"
}

var _layer: CanvasLayer
var _root: Control
var _scrim: ColorRect
var _header: PanelContainer
var _status_panel: PanelContainer
var _objects_panel: PanelContainer
var _decoration_panel: PanelContainer
var _detail_panel: PanelContainer
var _title_label: Label
var _level_label: Label
var _mood_label: Label
var _recommendation_label: Label
var _detail_title: Label
var _detail_body: Label
var _object_buttons: Dictionary = {}
var _stat_rows: Dictionary = {}
var _decoration_buttons: Dictionary = {}
var _theme_button: Button
var _time_button: Button
var _weather_button: Button
var _upgrade_button: Button
var _selected_object := "learning_desk"
var _snapshot: Dictionary = {}
var _open := false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()
	_connect_service()
	get_viewport().size_changed.connect(_apply_layout)
	_apply_layout()
	_refresh()

func open_home() -> void:
	_open = true
	_root.visible = true
	_refresh()
	_apply_layout()
	var audio := get_node_or_null("/root/OmniAudio")
	if audio != null and audio.has_method("set_environment"):
		audio.call("set_environment", "HOME")
	home_opened.emit()

func close_home() -> void:
	_open = false
	_root.visible = false
	home_closed.emit()

func is_open() -> bool:
	return _open

func get_overlay_snapshot() -> Dictionary:
	return {
		"open": _open,
		"selected_object": _selected_object,
		"object_button_count": _object_buttons.size(),
		"decoration_button_count": _decoration_buttons.size(),
		"status_row_count": _stat_rows.size(),
		"room": _snapshot.duplicate(true),
		"viewport": get_viewport().get_visible_rect().size
	}

func _build_ui() -> void:
	_layer = CanvasLayer.new()
	_layer.name = "LivingHomeLayer"
	_layer.layer = 48
	add_child(_layer)
	_root = Control.new()
	_root.name = "LivingHomeRoot"
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_PASS
	_root.visible = false
	_layer.add_child(_root)

	_scrim = ColorRect.new()
	_scrim.color = Color(0.005, 0.008, 0.025, 0.34)
	_scrim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_scrim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_scrim)

	_header = PanelContainer.new()
	_header.name = "LivingHomeHeader"
	_header.add_theme_stylebox_override("panel", _panel_style(Color(COLOR_PANEL, 0.96), Color(COLOR_CYAN, 0.55), 22, 1))
	_root.add_child(_header)
	var header_row := HBoxContainer.new()
	header_row.add_theme_constant_override("separation", 10)
	_header.add_child(header_row)
	var heading_box := VBoxContainer.new()
	heading_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_row.add_child(heading_box)
	_title_label = Label.new()
	_title_label.text = "LIVING HOME"
	_title_label.add_theme_color_override("font_color", COLOR_TEXT)
	_title_label.add_theme_font_size_override("font_size", 24)
	heading_box.add_child(_title_label)
	_level_label = Label.new()
	_level_label.add_theme_color_override("font_color", COLOR_CYAN)
	_level_label.add_theme_font_size_override("font_size", 13)
	heading_box.add_child(_level_label)
	_theme_button = _header_button("THEME", COLOR_VIOLET)
	_theme_button.pressed.connect(_cycle_theme)
	header_row.add_child(_theme_button)
	_time_button = _header_button("ZEIT", COLOR_CYAN)
	_time_button.pressed.connect(_cycle_time)
	header_row.add_child(_time_button)
	_weather_button = _header_button("WETTER", COLOR_GREEN)
	_weather_button.pressed.connect(_cycle_weather)
	header_row.add_child(_weather_button)
	var close_button := _header_button("×", COLOR_MAGENTA)
	close_button.custom_minimum_size = Vector2(56.0, 48.0)
	close_button.add_theme_font_size_override("font_size", 24)
	close_button.pressed.connect(close_home)
	header_row.add_child(close_button)

	_status_panel = PanelContainer.new()
	_status_panel.name = "LivingHomeStatus"
	_status_panel.add_theme_stylebox_override("panel", _panel_style(Color(COLOR_PANEL, 0.94), Color(COLOR_GREEN, 0.36), 18, 1))
	_root.add_child(_status_panel)
	var status_box := VBoxContainer.new()
	status_box.add_theme_constant_override("separation", 8)
	_status_panel.add_child(status_box)
	_mood_label = Label.new()
	_mood_label.add_theme_color_override("font_color", COLOR_GREEN)
	_mood_label.add_theme_font_size_override("font_size", 16)
	status_box.add_child(_mood_label)
	for data in [
		{"id": "cleanliness", "title": "ORDNUNG", "color": COLOR_CYAN},
		{"id": "effective_comfort", "title": "KOMFORT", "color": COLOR_MAGENTA},
		{"id": "effective_inspiration", "title": "INSPIRATION", "color": COLOR_VIOLET},
		{"id": "plant_health", "title": "GARTEN", "color": COLOR_GREEN},
		{"id": "power_stability", "title": "ENERGIE", "color": COLOR_GOLD}
	]:
		_add_stat_row(status_box, str(data["id"]), str(data["title"]), data["color"] as Color)
	var clean_button := Button.new()
	clean_button.text = "GEMEINSAM ORDNEN"
	clean_button.custom_minimum_size = Vector2(0.0, 44.0)
	clean_button.add_theme_color_override("font_color", COLOR_GREEN)
	clean_button.add_theme_stylebox_override("normal", _button_style(Color(COLOR_GREEN, 0.08), Color(COLOR_GREEN, 0.45), 12))
	clean_button.add_theme_stylebox_override("pressed", _button_style(Color(COLOR_GREEN, 0.20), COLOR_GREEN, 12))
	clean_button.pressed.connect(_clean_room)
	status_box.add_child(clean_button)

	_objects_panel = PanelContainer.new()
	_objects_panel.name = "LivingHomeObjects"
	_objects_panel.add_theme_stylebox_override("panel", _panel_style(Color(COLOR_PANEL, 0.93), Color(COLOR_VIOLET, 0.36), 18, 1))
	_root.add_child(_objects_panel)
	var objects_box := VBoxContainer.new()
	objects_box.add_theme_constant_override("separation", 8)
	_objects_panel.add_child(objects_box)
	var objects_heading := Label.new()
	objects_heading.text = "INTERAKTIVER RAUM"
	objects_heading.add_theme_color_override("font_color", COLOR_TEXT)
	objects_heading.add_theme_font_size_override("font_size", 16)
	objects_box.add_child(objects_heading)
	var object_scroll := ScrollContainer.new()
	object_scroll.name = "ObjectScroll"
	object_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	objects_box.add_child(object_scroll)
	var object_grid := GridContainer.new()
	object_grid.name = "ObjectGrid"
	object_grid.columns = 2
	object_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	object_grid.add_theme_constant_override("h_separation", 8)
	object_grid.add_theme_constant_override("v_separation", 8)
	object_scroll.add_child(object_grid)
	for object_id in OBJECT_ORDER:
		var button := Button.new()
		button.name = "HomeObject%s" % object_id.to_pascal_case()
		button.text = ""
		button.custom_minimum_size = Vector2(150.0, 76.0)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.add_theme_stylebox_override("normal", _button_style(Color(COLOR_PANEL_SOFT, 0.92), Color(COLOR_BORDER, 0.78), 14))
		button.add_theme_stylebox_override("hover", _button_style(Color(COLOR_VIOLET, 0.12), Color(COLOR_VIOLET, 0.56), 14))
		button.add_theme_stylebox_override("pressed", _button_style(Color(COLOR_CYAN, 0.18), COLOR_CYAN, 14))
		button.pressed.connect(_select_and_use_object.bind(object_id))
		object_grid.add_child(button)
		var label := Label.new()
		label.name = "Caption"
		label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE)
		label.offset_left = 10.0
		label.offset_right = -10.0
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.add_theme_color_override("font_color", COLOR_TEXT)
		label.add_theme_font_size_override("font_size", 13)
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.add_child(label)
		_object_buttons[object_id] = {"button": button, "label": label}

	_detail_panel = PanelContainer.new()
	_detail_panel.name = "LivingHomeDetail"
	_detail_panel.add_theme_stylebox_override("panel", _panel_style(Color(COLOR_PANEL, 0.96), Color(COLOR_CYAN, 0.34), 18, 1))
	_root.add_child(_detail_panel)
	var detail_box := VBoxContainer.new()
	detail_box.add_theme_constant_override("separation", 8)
	_detail_panel.add_child(detail_box)
	_detail_title = Label.new()
	_detail_title.add_theme_color_override("font_color", COLOR_CYAN)
	_detail_title.add_theme_font_size_override("font_size", 17)
	detail_box.add_child(_detail_title)
	_detail_body = Label.new()
	_detail_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail_body.add_theme_color_override("font_color", COLOR_MUTED)
	_detail_body.add_theme_font_size_override("font_size", 13)
	_detail_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	detail_box.add_child(_detail_body)
	_upgrade_button = Button.new()
	_upgrade_button.text = "OBJEKT VERBESSERN"
	_upgrade_button.custom_minimum_size = Vector2(0.0, 44.0)
	_upgrade_button.add_theme_color_override("font_color", COLOR_GOLD)
	_upgrade_button.add_theme_stylebox_override("normal", _button_style(Color(COLOR_GOLD, 0.08), Color(COLOR_GOLD, 0.40), 12))
	_upgrade_button.add_theme_stylebox_override("pressed", _button_style(Color(COLOR_GOLD, 0.20), COLOR_GOLD, 12))
	_upgrade_button.pressed.connect(_upgrade_selected)
	detail_box.add_child(_upgrade_button)
	_recommendation_label = Label.new()
	_recommendation_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_recommendation_label.add_theme_color_override("font_color", COLOR_GREEN)
	_recommendation_label.add_theme_font_size_override("font_size", 12)
	detail_box.add_child(_recommendation_label)

	_decoration_panel = PanelContainer.new()
	_decoration_panel.name = "LivingHomeDecorations"
	_decoration_panel.add_theme_stylebox_override("panel", _panel_style(Color(COLOR_PANEL, 0.95), Color(COLOR_MAGENTA, 0.34), 18, 1))
	_root.add_child(_decoration_panel)
	var decoration_box := VBoxContainer.new()
	decoration_box.add_theme_constant_override("separation", 6)
	_decoration_panel.add_child(decoration_box)
	var decoration_title := Label.new()
	decoration_title.text = "DEKORATIONEN"
	decoration_title.add_theme_color_override("font_color", COLOR_TEXT)
	decoration_title.add_theme_font_size_override("font_size", 15)
	decoration_box.add_child(decoration_title)
	var decoration_scroll := ScrollContainer.new()
	decoration_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	decoration_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	decoration_box.add_child(decoration_scroll)
	var decoration_row := HBoxContainer.new()
	decoration_row.add_theme_constant_override("separation", 7)
	decoration_scroll.add_child(decoration_row)
	var service_script := load("res://scripts/core/living_home_service.gd")
	var catalog: Dictionary = service_script.DECORATION_CATALOG if service_script != null else {}
	for key_variant in catalog.keys():
		var decoration_id := str(key_variant)
		var definition: Dictionary = catalog[decoration_id]
		var button := Button.new()
		button.text = str(definition.get("title", decoration_id))
		button.custom_minimum_size = Vector2(142.0, 42.0)
		button.add_theme_font_size_override("font_size", 11)
		button.add_theme_stylebox_override("normal", _button_style(Color(COLOR_MAGENTA, 0.06), Color(COLOR_MAGENTA, 0.30), 11))
		button.add_theme_stylebox_override("pressed", _button_style(Color(COLOR_MAGENTA, 0.18), COLOR_MAGENTA, 11))
		button.pressed.connect(_toggle_decoration.bind(decoration_id))
		decoration_row.add_child(button)
		_decoration_buttons[decoration_id] = button

func _add_stat_row(parent: VBoxContainer, stat_id: String, title: String, color: Color) -> void:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	parent.add_child(box)
	var row := HBoxContainer.new()
	box.add_child(row)
	var label := Label.new()
	label.text = title
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.add_theme_color_override("font_color", COLOR_MUTED)
	label.add_theme_font_size_override("font_size", 11)
	row.add_child(label)
	var value_label := Label.new()
	value_label.add_theme_color_override("font_color", color)
	value_label.add_theme_font_size_override("font_size", 11)
	row.add_child(value_label)
	var bar := ProgressBar.new()
	bar.show_percentage = false
	bar.max_value = 100.0
	bar.custom_minimum_size = Vector2(0.0, 8.0)
	bar.add_theme_stylebox_override("background", _bar_style(Color("050817"), 4))
	bar.add_theme_stylebox_override("fill", _bar_style(color, 4))
	box.add_child(bar)
	_stat_rows[stat_id] = {"bar": bar, "value": value_label}

func _connect_service() -> void:
	var service := get_node_or_null("/root/LivingHome")
	if service == null or not service.has_signal("home_changed"):
		return
	var callback := Callable(self, "_on_home_changed")
	if not service.is_connected("home_changed", callback):
		service.connect("home_changed", callback)

func _on_home_changed(snapshot: Dictionary) -> void:
	_snapshot = snapshot.duplicate(true)
	_refresh_from_snapshot()

func _refresh() -> void:
	var service := get_node_or_null("/root/LivingHome")
	if service != null and service.has_method("get_snapshot"):
		_snapshot = service.call("get_snapshot") as Dictionary
	_refresh_from_snapshot()

func _refresh_from_snapshot() -> void:
	if _snapshot.is_empty() or _title_label == null:
		return
	var theme: Dictionary = _snapshot.get("theme", {})
	_title_label.text = "LIVING HOME · %s" % str(theme.get("title", "Neon-Nest"))
	_level_label.text = "RAUMLEVEL %d  ·  %d / %d XP" % [int(_snapshot.get("room_level", 1)), int(_snapshot.get("room_xp", 0)), int(_snapshot.get("next_level_xp", 100))]
	_mood_label.text = "ATMOSPHÄRE: %s" % str(_snapshot.get("room_mood", "BALANCED")).replace("_", " ")
	_theme_button.text = "THEME\n%s" % str(theme.get("title", "Neon-Nest"))
	_time_button.text = "ZEIT\n%s" % str(_snapshot.get("time_segment", "DAY"))
	_weather_button.text = "WETTER\n%s" % str(_snapshot.get("weather", "CLEAR"))
	for stat_variant in _stat_rows.keys():
		var stat_id := str(stat_variant)
		var data: Dictionary = _stat_rows[stat_id]
		var value := float(_snapshot.get(stat_id, 0.0))
		(data.get("bar") as ProgressBar).value = value
		(data.get("value") as Label).text = "%d%%" % int(round(value))
	var levels: Dictionary = _snapshot.get("object_levels", {})
	var catalog := _object_catalog()
	for object_id in OBJECT_ORDER:
		var data: Dictionary = _object_buttons.get(object_id, {})
		var label := data.get("label") as Label
		var button := data.get("button") as Button
		var definition: Dictionary = catalog.get(object_id, {})
		var level := int(levels.get(object_id, 1))
		if label != null:
			label.text = "%s  %s\n%s · STUFE %d" % [str(OBJECT_GLYPHS.get(object_id, "◇")), str(definition.get("title", object_id)), str(OBJECT_ACTIONS.get(object_id, "NUTZEN")), level]
		if button != null:
			var selected := object_id == _selected_object
			button.add_theme_stylebox_override("normal", _button_style(Color(COLOR_CYAN, 0.12) if selected else Color(COLOR_PANEL_SOFT, 0.92), Color(COLOR_CYAN, 0.70) if selected else Color(COLOR_BORDER, 0.78), 14))
	var active_decorations: Array = _snapshot.get("decorations", [])
	for key_variant in _decoration_buttons.keys():
		var decoration_id := str(key_variant)
		var button := _decoration_buttons[decoration_id] as Button
		if button != null:
			var active := active_decorations.has(decoration_id)
			button.add_theme_color_override("font_color", COLOR_GREEN if active else COLOR_MUTED)
			button.text = ("✓ " if active else "+ ") + button.text.trim_prefix("✓ ").trim_prefix("+ ")
	_update_detail()

func _select_and_use_object(object_id: String) -> void:
	_selected_object = object_id
	var service := get_node_or_null("/root/LivingHome")
	if service != null and service.has_method("interact_object"):
		var result: Dictionary = service.call("interact_object", object_id)
		_play_feedback(object_id, bool(result.get("accepted", false)))
	_refresh()

func _clean_room() -> void:
	var service := get_node_or_null("/root/LivingHome")
	if service != null and service.has_method("clean_room"):
		service.call("clean_room")
	_play_feedback("care", true)
	_refresh()

func _upgrade_selected() -> void:
	var service := get_node_or_null("/root/LivingHome")
	if service == null or not service.has_method("upgrade_object"):
		return
	var result: Dictionary = service.call("upgrade_object", _selected_object)
	_play_feedback("level" if bool(result.get("accepted", false)) else "navigation", bool(result.get("accepted", false)))
	_refresh()

func _toggle_decoration(decoration_id: String) -> void:
	var service := get_node_or_null("/root/LivingHome")
	if service == null:
		return
	var active: Array = _snapshot.get("decorations", [])
	if active.has(decoration_id) and service.has_method("remove_decoration"):
		service.call("remove_decoration", decoration_id)
	elif service.has_method("place_decoration"):
		service.call("place_decoration", decoration_id)
	_play_feedback("care", true)
	_refresh()

func _cycle_theme() -> void:
	var service := get_node_or_null("/root/LivingHome")
	if service == null or not service.has_method("set_theme"):
		return
	var ids := ["neon_nest", "botanical_lab", "star_archive", "soft_signal"]
	var current := ids.find(str(_snapshot.get("theme_id", "neon_nest")))
	service.call("set_theme", ids[(current + 1) % ids.size()])
	_play_feedback("navigation", true)

func _cycle_time() -> void:
	var service := get_node_or_null("/root/LivingHome")
	if service == null or not service.has_method("set_time_mode"):
		return
	var ids := ["AUTO", "MORNING", "DAY", "EVENING", "NIGHT"]
	var current := ids.find(str(_snapshot.get("time_mode", "AUTO")))
	service.call("set_time_mode", ids[(current + 1) % ids.size()])
	_play_feedback("navigation", true)

func _cycle_weather() -> void:
	var service := get_node_or_null("/root/LivingHome")
	if service == null or not service.has_method("set_weather"):
		return
	var ids := ["CLEAR", "RAIN", "STORM", "AURORA", "SNOW"]
	var current := ids.find(str(_snapshot.get("weather", "CLEAR")))
	service.call("set_weather", ids[(current + 1) % ids.size()])
	_play_feedback("navigation", true)

func _update_detail() -> void:
	var catalog := _object_catalog()
	var definition: Dictionary = catalog.get(_selected_object, {})
	var levels: Dictionary = _snapshot.get("object_levels", {})
	var level := int(levels.get(_selected_object, 1))
	_detail_title.text = "%s · STUFE %d" % [str(definition.get("title", _selected_object)), level]
	var descriptions := {
		"sleep_pod": "Erholung, Traumerinnerungen und sichere Ruhephasen. Höhere Stufen regenerieren mehr Energie.",
		"signal_kitchen": "Nahrung wird zur gemeinsamen Tätigkeit. Nutzung stärkt Sättigung, hinterlässt aber sichtbare Spuren.",
		"learning_desk": "Adaptive Lernaufgaben, Experimente und Techniktraining erhöhen Neugier und Inspiration.",
		"holo_projector": "Geschichten, Musikvisualisierungen und gemeinsame Spielszenen heben Stimmung und Komfort.",
		"memory_archive": "Wichtige Entscheidungen, Generationen und Entdeckungen werden räumlich sichtbar gespeichert.",
		"garden_wall": "Die Pflanzen reagieren auf Pflege, Tageszeit und Pausen. Ein gesunder Garten beruhigt den Raum.",
		"cleaning_drone": "Hilft beim Ordnen, ersetzt aber nicht die gemeinsame Pflege. Höhere Stufen arbeiten effizienter.",
		"weather_window": "Verändert Himmel, Wetter und Lichtdramaturgie. Beobachtung kann neue Dialoge auslösen."
	}
	_detail_body.text = str(descriptions.get(_selected_object, "Interaktives Raumobjekt."))
	var recommendation := str(_snapshot.get("recommended_action", "holo_projector"))
	_recommendation_label.text = "EMPFEHLUNG: %s" % str(catalog.get(recommendation, {}).get("title", recommendation))
	_upgrade_button.disabled = level >= int(definition.get("max_level", 5))

func _play_feedback(action_id: String, accepted: bool) -> void:
	var audio := get_node_or_null("/root/OmniAudio")
	if audio != null and audio.has_method("play_action"):
		audio.call("play_action", action_id if accepted else "navigation", 0.85 if accepted else 0.55)
	var performance := get_node_or_null("/root/CharacterPerformance")
	if performance != null and performance.has_method("request_action"):
		var mapped := "care"
		if action_id in ["learning_desk", "memory_archive"]:
			mapped = "learn"
		elif action_id in ["holo_projector", "play"]:
			mapped = "play"
		elif action_id in ["sleep_pod", "rest"]:
			mapped = "rest"
		elif action_id in ["signal_kitchen", "feed"]:
			mapped = "feed"
		performance.call("request_action", mapped, 0.8)

func _apply_layout() -> void:
	if _root == null:
		return
	var size := get_viewport().get_visible_rect().size
	var compact := size.x < 760.0
	var tablet := size.x >= 760.0 and size.x < 1180.0
	_header.anchor_left = 0.0
	_header.anchor_right = 1.0
	_header.offset_left = 12.0
	_header.offset_right = -12.0
	_header.offset_top = 12.0
	_header.offset_bottom = 104.0 if compact else 92.0
	if compact:
		_status_panel.anchor_left = 0.0
		_status_panel.anchor_right = 0.46
		_status_panel.anchor_top = 0.0
		_status_panel.anchor_bottom = 1.0
		_status_panel.offset_left = 12.0
		_status_panel.offset_right = -4.0
		_status_panel.offset_top = 116.0
		_status_panel.offset_bottom = -164.0
		_detail_panel.anchor_left = 0.46
		_detail_panel.anchor_right = 1.0
		_detail_panel.anchor_top = 0.0
		_detail_panel.anchor_bottom = 0.54
		_detail_panel.offset_left = 4.0
		_detail_panel.offset_right = -12.0
		_detail_panel.offset_top = 116.0
		_detail_panel.offset_bottom = -4.0
		_objects_panel.anchor_left = 0.46
		_objects_panel.anchor_right = 1.0
		_objects_panel.anchor_top = 0.54
		_objects_panel.anchor_bottom = 1.0
		_objects_panel.offset_left = 4.0
		_objects_panel.offset_right = -12.0
		_objects_panel.offset_top = 4.0
		_objects_panel.offset_bottom = -164.0
		_decoration_panel.anchor_left = 0.0
		_decoration_panel.anchor_right = 1.0
		_decoration_panel.anchor_top = 1.0
		_decoration_panel.anchor_bottom = 1.0
		_decoration_panel.offset_left = 12.0
		_decoration_panel.offset_right = -12.0
		_decoration_panel.offset_top = -152.0
		_decoration_panel.offset_bottom = -12.0
	elif tablet:
		_status_panel.set_anchors_and_offsets_preset(Control.PRESET_LEFT_WIDE)
		_status_panel.offset_left = 18.0
		_status_panel.offset_right = 310.0
		_status_panel.offset_top = 112.0
		_status_panel.offset_bottom = -174.0
		_objects_panel.set_anchors_and_offsets_preset(Control.PRESET_RIGHT_WIDE)
		_objects_panel.offset_left = -370.0
		_objects_panel.offset_right = -18.0
		_objects_panel.offset_top = 112.0
		_objects_panel.offset_bottom = -174.0
		_detail_panel.anchor_left = 0.32
		_detail_panel.anchor_right = 0.68
		_detail_panel.anchor_top = 0.62
		_detail_panel.anchor_bottom = 1.0
		_detail_panel.offset_left = 8.0
		_detail_panel.offset_right = -8.0
		_detail_panel.offset_top = 0.0
		_detail_panel.offset_bottom = -174.0
		_decoration_panel.anchor_left = 0.0
		_decoration_panel.anchor_right = 1.0
		_decoration_panel.anchor_top = 1.0
		_decoration_panel.anchor_bottom = 1.0
		_decoration_panel.offset_left = 18.0
		_decoration_panel.offset_right = -18.0
		_decoration_panel.offset_top = -160.0
		_decoration_panel.offset_bottom = -18.0
	else:
		_status_panel.set_anchors_and_offsets_preset(Control.PRESET_LEFT_WIDE)
		_status_panel.offset_left = 24.0
		_status_panel.offset_right = 324.0
		_status_panel.offset_top = 112.0
		_status_panel.offset_bottom = -190.0
		_objects_panel.set_anchors_and_offsets_preset(Control.PRESET_RIGHT_WIDE)
		_objects_panel.offset_left = -410.0
		_objects_panel.offset_right = -24.0
		_objects_panel.offset_top = 112.0
		_objects_panel.offset_bottom = -190.0
		_detail_panel.anchor_left = 0.50
		_detail_panel.anchor_right = 0.50
		_detail_panel.anchor_top = 1.0
		_detail_panel.anchor_bottom = 1.0
		_detail_panel.offset_left = -245.0
		_detail_panel.offset_right = 245.0
		_detail_panel.offset_top = -330.0
		_detail_panel.offset_bottom = -190.0
		_decoration_panel.anchor_left = 0.0
		_decoration_panel.anchor_right = 1.0
		_decoration_panel.anchor_top = 1.0
		_decoration_panel.anchor_bottom = 1.0
		_decoration_panel.offset_left = 24.0
		_decoration_panel.offset_right = -24.0
		_decoration_panel.offset_top = -174.0
		_decoration_panel.offset_bottom = -24.0

func _object_catalog() -> Dictionary:
	var script := load("res://scripts/core/living_home_service.gd")
	return script.OBJECT_CATALOG if script != null else {}

func _header_button(text: String, accent: Color) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(96.0, 48.0)
	button.add_theme_color_override("font_color", accent)
	button.add_theme_font_size_override("font_size", 11)
	button.add_theme_stylebox_override("normal", _button_style(Color(accent, 0.06), Color(accent, 0.30), 13))
	button.add_theme_stylebox_override("hover", _button_style(Color(accent, 0.13), Color(accent, 0.56), 13))
	button.add_theme_stylebox_override("pressed", _button_style(Color(accent, 0.22), accent, 13))
	return button

func _panel_style(background: Color, border: Color, radius: int, border_width: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(radius)
	style.content_margin_left = 12.0
	style.content_margin_right = 12.0
	style.content_margin_top = 10.0
	style.content_margin_bottom = 10.0
	return style

func _button_style(background: Color, border: Color, radius: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(radius)
	return style

func _bar_style(color: Color, radius: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(radius)
	return style
