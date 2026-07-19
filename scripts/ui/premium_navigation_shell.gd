extends Node

const NeonGlyph := preload("res://scripts/ui/neon_glyph.gd")

const COLOR_PANEL := Color("080c1d")
const COLOR_PANEL_ACTIVE := Color("16163b")
const COLOR_BORDER := Color("2a3863")
const COLOR_CYAN := Color("42e8ff")
const COLOR_VIOLET := Color("a855f7")
const COLOR_MAGENTA := Color("f044d4")
const COLOR_GREEN := Color("64e6a2")
const COLOR_TEXT := Color("f4f7ff")
const COLOR_MUTED := Color("8693b6")

var _dashboard: Node
var _navigation: PanelContainer
var _buttons: Dictionary = {}
var _active_page := "HOME"
var _center_panel: Control
var _left_panel: Control
var _right_panel: Control
var _scroll: ScrollContainer

func _ready() -> void:
	call_deferred("_bind")

func _bind() -> void:
	_dashboard = get_parent()
	if _dashboard == null:
		return
	_center_panel = _dashboard.get("center_panel") as Control
	_left_panel = _dashboard.get("left_panel") as Control
	_right_panel = _dashboard.get("right_panel") as Control
	_scroll = _dashboard.get("scroll") as ScrollContainer
	var old_navigation := _dashboard.get("bottom_navigation") as PanelContainer
	if old_navigation == null or old_navigation.get_parent() == null:
		return
	var parent := old_navigation.get_parent()
	var index := old_navigation.get_index()
	_navigation = _build_navigation()
	parent.add_child(_navigation)
	parent.move_child(_navigation, index)
	_dashboard.set("bottom_navigation", _navigation)
	old_navigation.queue_free()
	get_viewport().size_changed.connect(_apply_layout)
	_apply_layout()

func _build_navigation() -> PanelContainer:
	var panel := PanelContainer.new()
	panel.name = "PremiumMobileNavigation"
	panel.add_theme_stylebox_override("panel", _panel_style(COLOR_PANEL, Color(COLOR_CYAN, 0.34), 22, 1))
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 4)
	panel.add_child(row)
	_add_nav_button(row, "HOME", "bitling", COLOR_CYAN)
	_add_nav_button(row, "STATUS", "care", COLOR_GREEN)
	_add_nav_button(row, "MISSIONEN", "learn", COLOR_VIOLET)
	_add_nav_button(row, "SOZIAL", "play", COLOR_MAGENTA)
	_add_nav_button(row, "MEHR", "spark", Color("ffc85a"))
	return panel

func _add_nav_button(parent: HBoxContainer, page_name: String, glyph_kind: String, accent: Color) -> void:
	var button := Button.new()
	button.name = "Nav%s" % page_name.capitalize()
	button.text = ""
	button.custom_minimum_size = Vector2(64.0, 62.0)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.focus_mode = Control.FOCUS_ALL
	button.tooltip_text = page_name.capitalize()
	button.add_theme_stylebox_override("normal", _button_style(Color.TRANSPARENT, Color.TRANSPARENT, 16))
	button.add_theme_stylebox_override("hover", _button_style(Color(accent, 0.10), Color(accent, 0.34), 16))
	button.add_theme_stylebox_override("pressed", _button_style(Color(accent, 0.18), accent, 16))
	button.pressed.connect(_on_page_pressed.bind(page_name))
	parent.add_child(button)

	var glyph := NeonGlyph.new()
	glyph.name = "Glyph"
	glyph.configure(glyph_kind, accent)
	glyph.anchor_left = 0.5
	glyph.anchor_right = 0.5
	glyph.offset_left = -19.0
	glyph.offset_right = 19.0
	glyph.offset_top = 3.0
	glyph.offset_bottom = 37.0
	glyph.custom_minimum_size = Vector2(38.0, 34.0)
	button.add_child(glyph)

	var label := Label.new()
	label.name = "Caption"
	label.text = page_name
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.anchor_left = 0.0
	label.anchor_top = 1.0
	label.anchor_right = 1.0
	label.anchor_bottom = 1.0
	label.offset_top = -24.0
	label.offset_bottom = -5.0
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_color_override("font_color", COLOR_MUTED)
	label.add_theme_font_size_override("font_size", 8 if page_name == "MISSIONEN" else 9)
	button.add_child(label)
	_buttons[page_name] = {"button": button, "label": label, "accent": accent}

func _on_page_pressed(page_name: String) -> void:
	var audio := get_node_or_null("/root/OmniAudio")
	if audio != null and audio.has_method("play_navigation"):
		audio.call("play_navigation")
	if page_name == "MEHR":
		var overlay := get_node_or_null("/root/ProfileOverlay")
		if overlay != null and overlay.has_method("open_profile"):
			overlay.call("open_profile")
		return
	_active_page = page_name
	_apply_compact_page()
	_update_button_states()
	if _scroll != null:
		_scroll.scroll_vertical = 0

func _apply_layout() -> void:
	if _navigation == null:
		return
	var compact := get_viewport().get_visible_rect().size.x < 900.0
	_navigation.visible = compact
	var credits := _dashboard.get("credits_label") as Control
	var shards := _dashboard.get("shards_label") as Control
	if credits != null:
		credits.visible = not compact
	if shards != null:
		shards.visible = not compact
	if compact:
		_apply_compact_page()
	else:
		_set_panel_visibility(true, true, true)
	_update_button_states()

func _apply_compact_page() -> void:
	match _active_page:
		"STATUS":
			_set_panel_visibility(false, true, false)
		"MISSIONEN", "SOZIAL":
			_set_panel_visibility(false, false, true)
		_:
			_set_panel_visibility(true, false, false)

func _set_panel_visibility(center_visible: bool, left_visible: bool, right_visible: bool) -> void:
	if _center_panel != null:
		_center_panel.visible = center_visible
	if _left_panel != null:
		_left_panel.visible = left_visible
	if _right_panel != null:
		_right_panel.visible = right_visible

func _update_button_states() -> void:
	for page_variant in _buttons.keys():
		var page_name := str(page_variant)
		var data: Dictionary = _buttons[page_name]
		var button := data.get("button") as Button
		var label := data.get("label") as Label
		var accent := data.get("accent", COLOR_CYAN) as Color
		if button == null or label == null:
			continue
		var active := page_name == _active_page
		button.add_theme_stylebox_override(
			"normal",
			_button_style(Color(accent, 0.14) if active else Color.TRANSPARENT, Color(accent, 0.78) if active else Color.TRANSPARENT, 16)
		)
		label.add_theme_color_override("font_color", accent if active else COLOR_MUTED)

func _panel_style(background: Color, border: Color, radius: int, border_width: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(radius)
	style.content_margin_left = 5.0
	style.content_margin_right = 5.0
	style.content_margin_top = 5.0
	style.content_margin_bottom = 5.0
	return style

func _button_style(background: Color, border: Color, radius: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(1 if border.a > 0.01 else 0)
	style.set_corner_radius_all(radius)
	return style
