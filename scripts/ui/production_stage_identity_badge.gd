extends Node

const NeonGlyph := preload("res://scripts/ui/neon_glyph.gd")

const CYAN := Color("35e9ff")
const VIOLET := Color("9e4dff")
const MAGENTA := Color("ff3ed1")
const GOLD := Color("ffc85a")
const TEXT := Color("f4f8ff")
const MUTED := Color("9ba8c7")
const PANEL := Color(0.018, 0.028, 0.075, 0.92)

var _dashboard: Node
var _stage: Control
var _identity_plate: PanelContainer
var _passport_card: PanelContainer
var _name_label: Label
var _form_label: Label
var _rarity_label: Label
var _id_label: Label
var _phase_label: Label
var _iq_label: Label
var _body_label: Label

func _ready() -> void:
	call_deferred("_bind")

func _bind() -> void:
	_dashboard = get_parent()
	if _dashboard == null:
		return
	var stage_variant: Variant = _dashboard.get("stage")
	if not stage_variant is Control:
		return
	_stage = stage_variant as Control
	_build_identity_plate()
	_build_passport_card()
	_stage.resized.connect(_apply_responsive_layout)
	var identity := get_node_or_null("/root/BitlingIdentity")
	if identity != null and not identity.identity_updated.is_connected(_on_identity_updated):
		identity.identity_updated.connect(_on_identity_updated)
	var profile := get_node_or_null("/root/DevelopmentProfile")
	if profile != null and not profile.profile_changed.is_connected(_on_profile_changed):
		profile.profile_changed.connect(_on_profile_changed)
	var state := get_node_or_null("/root/GameState")
	if state != null and not state.state_changed.is_connected(_on_state_changed):
		state.state_changed.connect(_on_state_changed)
	_apply_responsive_layout()
	_refresh()

func _build_identity_plate() -> void:
	_identity_plate = PanelContainer.new()
	_identity_plate.name = "ProductionIdentityPlate"
	_identity_plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_identity_plate.position = Vector2(14.0, 14.0)
	_identity_plate.add_theme_stylebox_override("panel", _style(PANEL, Color(CYAN, 0.60), 15, 1, CYAN))
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 8)
	_identity_plate.add_child(row)
	var glyph := NeonGlyph.new()
	glyph.configure("bitling", CYAN)
	glyph.custom_minimum_size = Vector2(38.0, 38.0)
	row.add_child(glyph)
	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_theme_constant_override("separation", 0)
	row.add_child(column)
	_name_label = Label.new()
	_name_label.text = "BITLING"
	_name_label.add_theme_color_override("font_color", TEXT)
	_name_label.add_theme_font_size_override("font_size", 15)
	column.add_child(_name_label)
	_form_label = Label.new()
	_form_label.text = "SIGNAL · BABY"
	_form_label.add_theme_color_override("font_color", MUTED)
	_form_label.add_theme_font_size_override("font_size", 9)
	column.add_child(_form_label)
	_stage.add_child(_identity_plate)

func _build_passport_card() -> void:
	_passport_card = PanelContainer.new()
	_passport_card.name = "ProductionPassportCard"
	_passport_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_passport_card.anchor_left = 1.0
	_passport_card.anchor_right = 1.0
	_passport_card.offset_left = -224.0
	_passport_card.offset_right = -14.0
	_passport_card.offset_top = 14.0
	_passport_card.offset_bottom = 132.0
	_passport_card.add_theme_stylebox_override("panel", _style(PANEL, Color(VIOLET, 0.72), 16, 1, VIOLET))
	var root_column := VBoxContainer.new()
	root_column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root_column.add_theme_constant_override("separation", 4)
	_passport_card.add_child(root_column)
	var header := HBoxContainer.new()
	header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root_column.add_child(header)
	var title := Label.new()
	title.text = "AUSWEIS"
	title.add_theme_color_override("font_color", TEXT)
	title.add_theme_font_size_override("font_size", 12)
	header.add_child(title)
	var spacer := Control.new()
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(spacer)
	_rarity_label = Label.new()
	_rarity_label.text = "COMMON"
	_rarity_label.add_theme_color_override("font_color", VIOLET)
	_rarity_label.add_theme_font_size_override("font_size", 9)
	header.add_child(_rarity_label)

	var divider := HSeparator.new()
	divider.mouse_filter = Control.MOUSE_FILTER_IGNORE
	divider.add_theme_color_override("separator", Color(CYAN, 0.20))
	root_column.add_child(divider)

	var details := GridContainer.new()
	details.mouse_filter = Control.MOUSE_FILTER_IGNORE
	details.columns = 2
	details.add_theme_constant_override("h_separation", 8)
	details.add_theme_constant_override("v_separation", 2)
	root_column.add_child(details)
	_id_label = _detail_row(details, "ID", "BTL-000000")
	_phase_label = _detail_row(details, "PHASE", "BABY")
	_iq_label = _detail_row(details, "IQ", "100")
	_body_label = _detail_row(details, "KÖRPER", "14 cm · 320 g")
	_stage.add_child(_passport_card)

func _detail_row(parent: GridContainer, caption: String, initial: String) -> Label:
	var caption_label := Label.new()
	caption_label.text = caption
	caption_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	caption_label.add_theme_color_override("font_color", MUTED)
	caption_label.add_theme_font_size_override("font_size", 8)
	parent.add_child(caption_label)
	var value_label := Label.new()
	value_label.text = initial
	value_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value_label.add_theme_color_override("font_color", TEXT)
	value_label.add_theme_font_size_override("font_size", 9)
	parent.add_child(value_label)
	return value_label

func _refresh() -> void:
	var identity := get_node_or_null("/root/BitlingIdentity")
	var profile := get_node_or_null("/root/DevelopmentProfile")
	if identity == null or profile == null:
		return
	var passport: Dictionary = identity.get_public_passport()
	var snapshot: Dictionary = profile.get_display_snapshot()
	var rarity_data: Dictionary = snapshot.get("rarity", {})
	var tier := str(rarity_data.get("tier", "COMMON")).to_upper()
	var bitling_id := str(passport.get("bitling_id", "BTL-000000"))
	var compact_id := bitling_id.right(10).to_upper()
	_name_label.text = str(passport.get("display_name", "BITLING")).to_upper()
	_form_label.text = "%s · %s" % [
		str(passport.get("form_id", "signal")).to_upper(),
		str(passport.get("development_phase", "BABY")).to_upper()
	]
	_rarity_label.text = ("✦ %s ✦" % tier) if tier == "LEGENDARY" else tier
	_rarity_label.add_theme_color_override("font_color", GOLD if tier == "LEGENDARY" else MAGENTA if tier == "RARE" else VIOLET)
	_id_label.text = compact_id
	_phase_label.text = str(passport.get("development_phase", "BABY")).to_upper()
	_iq_label.text = str(int(passport.get("intelligence_quotient", 100)))
	_body_label.text = "%.1f cm · %d g" % [
		float(passport.get("height_cm", 14.0)),
		int(passport.get("weight_g", 320))
	]
	if _stage.has_method("set_rarity"):
		_stage.call("set_rarity", tier)

func _apply_responsive_layout() -> void:
	if _stage == null or _passport_card == null:
		return
	var compact := _stage.size.x < 430.0
	_passport_card.offset_left = -174.0 if compact else -224.0
	_passport_card.offset_bottom = 118.0 if compact else 132.0
	_identity_plate.scale = Vector2(0.88, 0.88) if compact else Vector2.ONE
	_passport_card.scale = Vector2(0.88, 0.88) if compact else Vector2.ONE
	_passport_card.pivot_offset = Vector2(_passport_card.size.x, 0.0)

func _on_identity_updated(_snapshot: Dictionary) -> void:
	_refresh()

func _on_profile_changed(_snapshot: Dictionary) -> void:
	_refresh()

func _on_state_changed(_key: String, _value: Variant) -> void:
	call_deferred("_refresh")

func _style(background: Color, border: Color, radius: int, border_width: int, glow_color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(radius)
	style.content_margin_left = 10.0
	style.content_margin_right = 10.0
	style.content_margin_top = 8.0
	style.content_margin_bottom = 8.0
	style.shadow_color = Color(glow_color, 0.14)
	style.shadow_size = 7
	style.shadow_offset = Vector2.ZERO
	return style
