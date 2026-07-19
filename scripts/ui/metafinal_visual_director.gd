extends Node

## Replaces the previous canvas placeholder with the production 3D presentation and
## upgrades the existing data-driven dashboard without duplicating game state.

const ProductionStage3D := preload("res://scripts/ui/production_bitling_stage_3d.gd")
const NeonGlyph := preload("res://scripts/ui/neon_glyph.gd")

const CYAN := Color("35e9ff")
const BLUE := Color("337cff")
const VIOLET := Color("9e4dff")
const MAGENTA := Color("ff3ed1")
const GREEN := Color("53f0a6")
const GOLD := Color("ffc85a")
const TEXT := Color("f4f8ff")
const MUTED := Color("9ba8c7")
const PANEL := Color("090d1f")
const PANEL_LIFT := Color("101832")

var _dashboard: Node
var _stage: Control
var _installed := false

func _ready() -> void:
	call_deferred("_install")

func _install() -> void:
	if _installed:
		return
	_dashboard = get_parent()
	if _dashboard == null:
		return
	_install_production_stage()
	_upgrade_primary_actions()
	_upgrade_header()
	_upgrade_navigation()
	_add_cinematic_overlay()
	_installed = true

func _install_production_stage() -> void:
	var previous_variant: Variant = _dashboard.get("stage")
	if not previous_variant is Control:
		return
	var previous := previous_variant as Control
	var parent := previous.get_parent()
	if parent == null:
		return
	var child_index := previous.get_index()
	_stage = ProductionStage3D.new()
	_stage.name = "ProductionBitlingStage3D"
	_stage.custom_minimum_size = previous.custom_minimum_size
	_stage.size_flags_horizontal = previous.size_flags_horizontal
	_stage.size_flags_vertical = previous.size_flags_vertical
	parent.add_child(_stage)
	parent.move_child(_stage, child_index)
	if _stage.has_signal("bitling_pressed") and _dashboard.has_method("_on_stage_pressed"):
		_stage.connect("bitling_pressed", Callable(_dashboard, "_on_stage_pressed"))
	_dashboard.set("stage", _stage)
	previous.queue_free()

func _upgrade_primary_actions() -> void:
	var buttons_variant: Variant = _dashboard.get("action_buttons")
	if not buttons_variant is Dictionary:
		return
	var buttons := buttons_variant as Dictionary
	var accents := {
		"feed": GREEN,
		"play": VIOLET,
		"learn": CYAN,
		"care": MAGENTA,
		"rest": GOLD
	}
	var titles := {
		"feed": ["FÜTTERN", "Sättigung"],
		"play": ["SPIELEN", "Abenteuer"],
		"learn": ["LERNEN", "IQ & Wissen"],
		"care": ["PFLEGEN", "Vertrauen"],
		"rest": ["SCHLAFEN", "Energie"]
	}
	for key_variant in buttons.keys():
		var key := str(key_variant)
		var button_variant: Variant = buttons[key]
		if not button_variant is Button:
			continue
		var button := button_variant as Button
		for child in button.get_children():
			child.queue_free()
		button.text = ""
		button.clip_contents = false
		button.custom_minimum_size = Vector2(104.0, 94.0)
		button.add_theme_stylebox_override("normal", _button_style(Color(PANEL_LIFT, 0.96), accents.get(key, CYAN), 18, 1.0))
		button.add_theme_stylebox_override("hover", _button_style(Color("172449"), CYAN, 18, 1.8))
		button.add_theme_stylebox_override("pressed", _button_style(Color(accents.get(key, CYAN), 0.24), accents.get(key, CYAN), 18, 2.2))
		button.add_theme_stylebox_override("focus", _button_style(Color(PANEL_LIFT, 0.98), Color.WHITE, 18, 2.0))
		var content := VBoxContainer.new()
		content.name = "ProductionButtonContent"
		content.mouse_filter = Control.MOUSE_FILTER_IGNORE
		content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 8)
		content.alignment = BoxContainer.ALIGNMENT_CENTER
		content.add_theme_constant_override("separation", 1)
		button.add_child(content)
		var glyph := NeonGlyph.new()
		glyph.name = "Glyph"
		glyph.configure(key, accents.get(key, CYAN))
		glyph.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		content.add_child(glyph)
		var title := Label.new()
		title.text = str((titles.get(key, [key.to_upper(), ""]) as Array)[0])
		title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		title.mouse_filter = Control.MOUSE_FILTER_IGNORE
		title.add_theme_color_override("font_color", accents.get(key, CYAN))
		title.add_theme_font_size_override("font_size", 12)
		content.add_child(title)
		var subtitle := Label.new()
		subtitle.text = str((titles.get(key, [key.to_upper(), ""]) as Array)[1])
		subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		subtitle.mouse_filter = Control.MOUSE_FILTER_IGNORE
		subtitle.add_theme_color_override("font_color", MUTED)
		subtitle.add_theme_font_size_override("font_size", 9)
		content.add_child(subtitle)
		button.mouse_entered.connect(_animate_button.bind(button, true))
		button.mouse_exited.connect(_animate_button.bind(button, false))

func _upgrade_header() -> void:
	var header_variant: Variant = _dashboard.get("header_panel")
	if not header_variant is PanelContainer:
		return
	var header := header_variant as PanelContainer
	header.add_theme_stylebox_override("panel", _panel_style(Color("070b1a"), Color(CYAN, 0.38), 20, 1, 0.9))
	header.custom_minimum_size.y = 72.0

	var title := _find_label_with_text(header, "BITLING OMNI")
	if title != null:
		title.add_theme_color_override("font_color", TEXT)
		title.add_theme_font_size_override("font_size", 24)
		title.tooltip_text = "METAFINAL ALPHA · Xogot 4.6"

	var logo_label := _find_label_with_text(header, "B")
	if logo_label != null and logo_label.get_parent() is PanelContainer:
		var logo_panel := logo_label.get_parent() as PanelContainer
		logo_label.visible = false
		var glyph := NeonGlyph.new()
		glyph.configure("bitling", CYAN)
		glyph.mouse_filter = Control.MOUSE_FILTER_IGNORE
		logo_panel.add_child(glyph)

func _upgrade_navigation() -> void:
	var bottom_variant: Variant = _dashboard.get("bottom_navigation")
	if bottom_variant is PanelContainer:
		var bottom := bottom_variant as PanelContainer
		bottom.add_theme_stylebox_override("panel", _panel_style(Color("060917"), Color(VIOLET, 0.55), 24, 1, 0.88))
		for child in bottom.find_children("*", "Button", true, false):
			var button := child as Button
			button.add_theme_color_override("font_color", MUTED)
			button.add_theme_color_override("font_hover_color", CYAN)
			button.add_theme_color_override("font_pressed_color", Color.WHITE)

func _add_cinematic_overlay() -> void:
	var ui_variant: Variant = _dashboard.get("ui_root")
	if not ui_variant is Control:
		return
	var ui := ui_variant as Control
	var overlay := Control.new()
	overlay.name = "CinematicEdgeTreatment"
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.set_script(preload("res://scripts/ui/cinematic_edge_treatment.gd"))
	ui.add_child(overlay)
	ui.move_child(overlay, ui.get_child_count() - 1)

func _animate_button(button: Button, hovered: bool) -> void:
	if button == null or not is_instance_valid(button):
		return
	var target := Vector2(1.035, 1.035) if hovered else Vector2.ONE
	var tween := create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(button, "scale", target, 0.12)
	button.pivot_offset = button.size * 0.5

func _find_label_with_text(root: Node, text_value: String) -> Label:
	for child in root.find_children("*", "Label", true, false):
		var label := child as Label
		if label.text == text_value:
			return label
	return null

func _button_style(background: Color, accent: Color, radius: int, glow: float) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = Color(accent, 0.72)
	style.set_border_width_all(1)
	style.set_corner_radius_all(radius)
	style.content_margin_left = 8.0
	style.content_margin_right = 8.0
	style.content_margin_top = 7.0
	style.content_margin_bottom = 7.0
	style.shadow_color = Color(accent, 0.15 * glow)
	style.shadow_size = maxi(4, int(7.0 * glow))
	style.shadow_offset = Vector2.ZERO
	return style

func _panel_style(background: Color, accent: Color, radius: int, border_width: int, glow: float) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = accent
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(radius)
	style.content_margin_left = 14.0
	style.content_margin_right = 14.0
	style.content_margin_top = 12.0
	style.content_margin_bottom = 12.0
	style.shadow_color = Color(accent, 0.10 * glow)
	style.shadow_size = maxi(4, int(9.0 * glow))
	style.shadow_offset = Vector2.ZERO
	return style
