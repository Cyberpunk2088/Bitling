extends Node

## World-first Living Home interface. Controls stay on the edges so the Bitling
## and its evolving 3D room remain the visual focus on phone, tablet and desktop.

signal home_opened
signal home_closed

const PANEL := Color("091126")
const PANEL_SOFT := Color("111936")
const BORDER := Color("31416e")
const CYAN := Color("42e8ff")
const VIOLET := Color("a855f7")
const MAGENTA := Color("f044d4")
const GREEN := Color("64e6a2")
const GOLD := Color("ffc85a")
const TEXT := Color("f4f7ff")
const MUTED := Color("8d9abd")

const OBJECT_ORDER: Array[String] = [
	"sleep_pod", "signal_kitchen", "learning_desk", "holo_projector",
	"memory_archive", "garden_wall", "cleaning_drone", "weather_window"
]
const OBJECT_DATA: Dictionary = {
	"sleep_pod": {"title": "Schlafkapsel", "action": "AUSRUHEN", "glyph": "☾", "description": "Erholung, Traumerinnerungen und sichere Ruhephasen."},
	"signal_kitchen": {"title": "Signalküche", "action": "ZUBEREITEN", "glyph": "◉", "description": "Nahrung wird zu einer gemeinsamen Tätigkeit mit sichtbaren Spuren."},
	"learning_desk": {"title": "Lerntisch", "action": "FORSCHEN", "glyph": "▤", "description": "Experimente und Techniktraining erhöhen Neugier und Inspiration."},
	"holo_projector": {"title": "Holoprojektor", "action": "ERLEBEN", "glyph": "◇", "description": "Geschichten, Musikvisualisierungen und Spielszenen heben die Stimmung."},
	"memory_archive": {"title": "Erinnerungsarchiv", "action": "ERINNERN", "glyph": "◎", "description": "Entscheidungen, Generationen und Entdeckungen werden räumlich sichtbar."},
	"garden_wall": {"title": "Gartenwand", "action": "PFLEGEN", "glyph": "✦", "description": "Pflanzen reagieren auf Pflege, Tageszeit und längere Pausen."},
	"cleaning_drone": {"title": "Reinigungsdrohne", "action": "ORDNEN", "glyph": "◌", "description": "Hilft beim Ordnen, ersetzt aber nicht die gemeinsame Pflege."},
	"weather_window": {"title": "Wetterfenster", "action": "BEOBACHTEN", "glyph": "⌁", "description": "Himmel, Wetter und Lichtdramaturgie verändern die Atmosphäre."}
}
const DECORATIONS: Array[String] = [
	"moon_lantern", "prism_mobile", "memory_ribbon", "moss_cushion", "star_map",
	"tiny_planet", "friend_totem", "signal_chimes", "aurora_rug", "archive_orb"
]
const DECORATION_TITLES: Dictionary = {
	"moon_lantern": "Mondlaterne", "prism_mobile": "Prismen-Mobile",
	"memory_ribbon": "Erinnerungsband", "moss_cushion": "Mooskissen",
	"star_map": "Sternenkarte", "tiny_planet": "Kleiner Planet",
	"friend_totem": "Freundschaftstotem", "signal_chimes": "Signalglocken",
	"aurora_rug": "Aurora-Teppich", "archive_orb": "Archivkugel"
}

var _layer: CanvasLayer
var _root: Control
var _header: PanelContainer
var _status: PanelContainer
var _objects: PanelContainer
var _detail: PanelContainer
var _decorations: PanelContainer
var _title: Label
var _level: Label
var _mood: Label
var _detail_title: Label
var _detail_text: Label
var _recommendation: Label
var _theme_button: Button
var _time_button: Button
var _weather_button: Button
var _upgrade_button: Button
var _stat_widgets: Dictionary = {}
var _object_widgets: Dictionary = {}
var _decoration_buttons: Dictionary = {}
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
		"object_button_count": _object_widgets.size(),
		"decoration_button_count": _decoration_buttons.size(),
		"status_row_count": _stat_widgets.size(),
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

	var edge_tint := ColorRect.new()
	edge_tint.color = Color(0.005, 0.008, 0.025, 0.13)
	edge_tint.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	edge_tint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(edge_tint)

	_header = _panel("LivingHomeHeader", CYAN, 0.96)
	_root.add_child(_header)
	var header_row := HBoxContainer.new()
	header_row.add_theme_constant_override("separation", 8)
	_header.add_child(header_row)
	var heading := VBoxContainer.new()
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_row.add_child(heading)
	_title = _label("LIVING HOME", 22, TEXT)
	heading.add_child(_title)
	_level = _label("", 12, CYAN)
	heading.add_child(_level)
	_theme_button = _small_button("THEME", VIOLET)
	_theme_button.pressed.connect(_cycle_theme)
	header_row.add_child(_theme_button)
	_time_button = _small_button("ZEIT", CYAN)
	_time_button.pressed.connect(_cycle_time)
	header_row.add_child(_time_button)
	_weather_button = _small_button("WETTER", GREEN)
	_weather_button.pressed.connect(_cycle_weather)
	header_row.add_child(_weather_button)
	var close := _small_button("×", MAGENTA)
	close.custom_minimum_size = Vector2(50.0, 46.0)
	close.add_theme_font_size_override("font_size", 23)
	close.pressed.connect(close_home)
	header_row.add_child(close)

	_status = _panel("LivingHomeStatus", GREEN, 0.92)
	_root.add_child(_status)
	var status_box := VBoxContainer.new()
	status_box.add_theme_constant_override("separation", 7)
	_status.add_child(status_box)
	_mood = _label("ATMOSPHÄRE", 15, GREEN)
	status_box.add_child(_mood)
	for row in [
		["cleanliness", "ORDNUNG", CYAN], ["effective_comfort", "KOMFORT", MAGENTA],
		["effective_inspiration", "INSPIRATION", VIOLET], ["plant_health", "GARTEN", GREEN],
		["power_stability", "ENERGIE", GOLD]
	]:
		_add_stat(status_box, str(row[0]), str(row[1]), row[2] as Color)
	var clean := _action_button("GEMEINSAM ORDNEN", GREEN)
	clean.pressed.connect(_clean_room)
	status_box.add_child(clean)

	_objects = _panel("LivingHomeObjects", VIOLET, 0.91)
	_root.add_child(_objects)
	var object_box := VBoxContainer.new()
	object_box.add_theme_constant_override("separation", 7)
	_objects.add_child(object_box)
	object_box.add_child(_label("INTERAKTIVER RAUM", 15, TEXT))
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	object_box.add_child(scroll)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 7)
	grid.add_theme_constant_override("v_separation", 7)
	scroll.add_child(grid)
	for object_id in OBJECT_ORDER:
		var button := Button.new()
		button.name = "HomeObject%s" % object_id.to_pascal_case()
		button.custom_minimum_size = Vector2(126.0, 70.0)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.add_theme_stylebox_override("normal", _button_style(PANEL_SOFT, BORDER, 13))
		button.add_theme_stylebox_override("hover", _button_style(Color(VIOLET, 0.15), Color(VIOLET, 0.64), 13))
		button.add_theme_stylebox_override("pressed", _button_style(Color(CYAN, 0.20), CYAN, 13))
		button.pressed.connect(_select_and_use.bind(object_id))
		grid.add_child(button)
		var caption := _label("", 11, TEXT)
		caption.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.add_child(caption)
		_object_widgets[object_id] = {"button": button, "caption": caption}

	_detail = _panel("LivingHomeDetail", CYAN, 0.92)
	_root.add_child(_detail)
	var detail_box := VBoxContainer.new()
	detail_box.add_theme_constant_override("separation", 6)
	_detail.add_child(detail_box)
	_detail_title = _label("", 16, CYAN)
	detail_box.add_child(_detail_title)
	_detail_text = _label("", 12, MUTED)
	_detail_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	detail_box.add_child(_detail_text)
	_upgrade_button = _action_button("OBJEKT VERBESSERN", GOLD)
	_upgrade_button.pressed.connect(_upgrade_selected)
	detail_box.add_child(_upgrade_button)
	_recommendation = _label("", 11, GREEN)
	_recommendation.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail_box.add_child(_recommendation)

	_decorations = _panel("LivingHomeDecorations", MAGENTA, 0.92)
	_root.add_child(_decorations)
	var decor_box := VBoxContainer.new()
	decor_box.add_theme_constant_override("separation", 5)
	_decorations.add_child(decor_box)
	decor_box.add_child(_label("DEKORATIONEN", 14, TEXT))
	var decor_scroll := ScrollContainer.new()
	decor_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	decor_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	decor_box.add_child(decor_scroll)
	var decor_row := HBoxContainer.new()
	decor_row.add_theme_constant_override("separation", 6)
	decor_scroll.add_child(decor_row)
	for decoration_id in DECORATIONS:
		var button := _small_button(str(DECORATION_TITLES[decoration_id]), MAGENTA)
		button.custom_minimum_size = Vector2(130.0, 40.0)
		button.pressed.connect(_toggle_decoration.bind(decoration_id))
		decor_row.add_child(button)
		_decoration_buttons[decoration_id] = button

func _add_stat(parent: VBoxContainer, id: String, title: String, color: Color) -> void:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	parent.add_child(box)
	var row := HBoxContainer.new()
	box.add_child(row)
	var name_label := _label(title, 10, MUTED)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(name_label)
	var value_label := _label("0%", 10, color)
	row.add_child(value_label)
	var bar := ProgressBar.new()
	bar.show_percentage = false
	bar.max_value = 100.0
	bar.custom_minimum_size = Vector2(0.0, 7.0)
	bar.add_theme_stylebox_override("background", _flat(Color("050817"), 4))
	bar.add_theme_stylebox_override("fill", _flat(color, 4))
	box.add_child(bar)
	_stat_widgets[id] = {"bar": bar, "value": value_label}

func _connect_service() -> void:
	var service := get_node_or_null("/root/LivingHome")
	if service == null or not service.has_signal("home_changed"):
		return
	var callback := Callable(self, "_on_home_changed")
	if not service.is_connected("home_changed", callback):
		service.connect("home_changed", callback)

func _on_home_changed(snapshot: Dictionary) -> void:
	_snapshot = snapshot.duplicate(true)
	_refresh_widgets()

func _refresh() -> void:
	var service := get_node_or_null("/root/LivingHome")
	if service != null and service.has_method("get_snapshot"):
		_snapshot = service.call("get_snapshot") as Dictionary
	_refresh_widgets()

func _refresh_widgets() -> void:
	if _snapshot.is_empty() or _title == null:
		return
	var theme: Dictionary = _snapshot.get("theme", {})
	_title.text = "LIVING HOME · %s" % str(theme.get("title", "Neon-Nest"))
	_level.text = "RAUMLEVEL %d · %d / %d XP" % [int(_snapshot.get("room_level", 1)), int(_snapshot.get("room_xp", 0)), int(_snapshot.get("next_level_xp", 100))]
	_mood.text = "ATMOSPHÄRE: %s" % str(_snapshot.get("room_mood", "BALANCED")).replace("_", " ")
	_theme_button.text = "THEME\n%s" % str(theme.get("title", "Neon-Nest"))
	_time_button.text = "ZEIT\n%s" % str(_snapshot.get("time_segment", "DAY"))
	_weather_button.text = "WETTER\n%s" % str(_snapshot.get("weather", "CLEAR"))
	for stat_variant in _stat_widgets.keys():
		var stat_id := str(stat_variant)
		var widget: Dictionary = _stat_widgets[stat_id]
		var value := float(_snapshot.get(stat_id, 0.0))
		(widget["bar"] as ProgressBar).value = value
		(widget["value"] as Label).text = "%d%%" % int(round(value))
	var levels: Dictionary = _snapshot.get("object_levels", {})
	for object_id in OBJECT_ORDER:
		var widget: Dictionary = _object_widgets[object_id]
		var info: Dictionary = OBJECT_DATA[object_id]
		var level := int(levels.get(object_id, 1))
		(widget["caption"] as Label).text = "%s  %s\n%s · STUFE %d" % [info["glyph"], info["title"], info["action"], level]
		var selected: bool = object_id == _selected_object
		(widget["button"] as Button).add_theme_stylebox_override("normal", _button_style(Color(CYAN, 0.12) if selected else PANEL_SOFT, Color(CYAN, 0.72) if selected else BORDER, 13))
	var active: Array = _snapshot.get("decorations", [])
	for decoration_id in DECORATIONS:
		var button := _decoration_buttons[decoration_id] as Button
		var placed: bool = active.has(decoration_id)
		button.text = ("✓ " if placed else "+ ") + str(DECORATION_TITLES[decoration_id])
		button.add_theme_color_override("font_color", GREEN if placed else MUTED)
	_update_detail()

func _select_and_use(object_id: String) -> void:
	_selected_object = object_id
	var service := get_node_or_null("/root/LivingHome")
	if service != null and service.has_method("interact_object"):
		var result: Dictionary = service.call("interact_object", object_id)
		_feedback(object_id, bool(result.get("accepted", false)))
	_refresh()

func _clean_room() -> void:
	var service := get_node_or_null("/root/LivingHome")
	if service != null and service.has_method("clean_room"):
		service.call("clean_room")
	_feedback("care", true)

func _upgrade_selected() -> void:
	var service := get_node_or_null("/root/LivingHome")
	if service != null and service.has_method("upgrade_object"):
		var result: Dictionary = service.call("upgrade_object", _selected_object)
		_feedback("level", bool(result.get("accepted", false)))

func _toggle_decoration(id: String) -> void:
	var service := get_node_or_null("/root/LivingHome")
	if service == null:
		return
	var active: Array = _snapshot.get("decorations", [])
	if active.has(id):
		service.call("remove_decoration", id)
	else:
		service.call("place_decoration", id)
	_feedback("care", true)

func _cycle_theme() -> void:
	_cycle_service_value("set_theme", ["neon_nest", "botanical_lab", "star_archive", "soft_signal"], str(_snapshot.get("theme_id", "neon_nest")))

func _cycle_time() -> void:
	_cycle_service_value("set_time_mode", ["AUTO", "MORNING", "DAY", "EVENING", "NIGHT"], str(_snapshot.get("time_mode", "AUTO")))

func _cycle_weather() -> void:
	_cycle_service_value("set_weather", ["CLEAR", "RAIN", "STORM", "AURORA", "SNOW"], str(_snapshot.get("weather", "CLEAR")))

func _cycle_service_value(method: String, values: Array, current: String) -> void:
	var service := get_node_or_null("/root/LivingHome")
	if service == null or not service.has_method(method):
		return
	var index := values.find(current)
	service.call(method, values[(index + 1) % values.size()])
	_feedback("navigation", true)

func _update_detail() -> void:
	var info: Dictionary = OBJECT_DATA[_selected_object]
	var levels: Dictionary = _snapshot.get("object_levels", {})
	var level := int(levels.get(_selected_object, 1))
	_detail_title.text = "%s · STUFE %d" % [info["title"], level]
	_detail_text.text = str(info["description"])
	var recommended := str(_snapshot.get("recommended_action", "learning_desk"))
	_recommendation.text = "EMPFEHLUNG: %s" % str((OBJECT_DATA.get(recommended, {}) as Dictionary).get("title", recommended))
	_upgrade_button.disabled = level >= 5

func _feedback(action: String, accepted: bool) -> void:
	var audio := get_node_or_null("/root/OmniAudio")
	if audio != null and audio.has_method("play_action"):
		audio.call("play_action", action if accepted else "navigation", 0.82)
	var performance := get_node_or_null("/root/CharacterPerformance")
	if performance != null and performance.has_method("request_action"):
		var mapped := "care"
		if action in ["learning_desk", "memory_archive"]:
			mapped = "learn"
		elif action == "holo_projector":
			mapped = "play"
		elif action == "sleep_pod":
			mapped = "rest"
		elif action == "signal_kitchen":
			mapped = "feed"
		performance.call("request_action", mapped, 0.8)

func _apply_layout() -> void:
	if _root == null:
		return
	var width := get_viewport().get_visible_rect().size.x
	var compact := width < 760.0
	_header.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_header.offset_left = 12.0
	_header.offset_right = -12.0
	_header.offset_top = 12.0
	_header.offset_bottom = 98.0
	var side_width := 206.0 if compact else 280.0
	var right_width := 236.0 if compact else 350.0
	_status.set_anchors_and_offsets_preset(Control.PRESET_LEFT_WIDE)
	_status.offset_left = 12.0
	_status.offset_right = side_width
	_status.offset_top = 108.0
	_status.offset_bottom = -162.0
	_objects.set_anchors_and_offsets_preset(Control.PRESET_RIGHT_WIDE)
	_objects.offset_left = -right_width
	_objects.offset_right = -12.0
	_objects.offset_top = 108.0
	_objects.offset_bottom = -162.0
	_detail.anchor_left = 0.5
	_detail.anchor_right = 0.5
	_detail.anchor_top = 1.0
	_detail.anchor_bottom = 1.0
	_detail.offset_left = -150.0 if compact else -230.0
	_detail.offset_right = 150.0 if compact else 230.0
	_detail.offset_top = -300.0
	_detail.offset_bottom = -162.0
	_decorations.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_decorations.offset_left = 12.0
	_decorations.offset_right = -12.0
	_decorations.offset_top = -150.0
	_decorations.offset_bottom = -12.0

func _panel(name_value: String, accent: Color, alpha: float) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.name = name_value
	panel.add_theme_stylebox_override("panel", _panel_style(Color(PANEL, alpha), Color(accent, 0.44)))
	return panel

func _label(value: String, size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = value
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	return label

func _small_button(value: String, accent: Color) -> Button:
	var button := Button.new()
	button.text = value
	button.custom_minimum_size = Vector2(88.0, 46.0)
	button.add_theme_font_size_override("font_size", 10)
	button.add_theme_color_override("font_color", accent)
	button.add_theme_stylebox_override("normal", _button_style(Color(accent, 0.07), Color(accent, 0.34), 12))
	button.add_theme_stylebox_override("pressed", _button_style(Color(accent, 0.20), accent, 12))
	return button

func _action_button(value: String, accent: Color) -> Button:
	var button := _small_button(value, accent)
	button.custom_minimum_size.y = 42.0
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return button

func _panel_style(background: Color, border: Color) -> StyleBoxFlat:
	var style := _button_style(background, border, 17)
	style.content_margin_left = 10.0
	style.content_margin_right = 10.0
	style.content_margin_top = 9.0
	style.content_margin_bottom = 9.0
	return style

func _button_style(background: Color, border: Color, radius: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(radius)
	return style

func _flat(color: Color, radius: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(radius)
	return style
