extends Node

const COLOR_PANEL := Color(0.03, 0.05, 0.12, 0.82)
const COLOR_BORDER := Color("42e8ff")
const COLOR_TEXT := Color("f4f7ff")
const COLOR_MUTED := Color("9ba8c7")
const COLOR_RARE := Color("a855f7")
const COLOR_LEGENDARY := Color("ffc85a")

var _dashboard: Node
var _stage: Control
var _name_label: Label
var _details_label: Label
var _rarity_label: Label

func _ready() -> void:
	call_deferred("_bind")

func _bind() -> void:
	_dashboard = get_parent()
	if _dashboard == null:
		return
	_stage = _dashboard.get("stage") as Control
	if _stage == null:
		return
	_build_badges()
	var identity := get_node_or_null("/root/BitlingIdentity")
	if identity != null and not identity.identity_updated.is_connected(_on_identity_updated):
		identity.identity_updated.connect(_on_identity_updated)
	var profile := get_node_or_null("/root/DevelopmentProfile")
	if profile != null and not profile.profile_changed.is_connected(_on_profile_changed):
		profile.profile_changed.connect(_on_profile_changed)
	var state := get_node_or_null("/root/GameState")
	if state != null and not state.state_changed.is_connected(_on_state_changed):
		state.state_changed.connect(_on_state_changed)
	_refresh()

func _build_badges() -> void:
	var identity_panel := PanelContainer.new()
	identity_panel.name = "StageIdentityBadge"
	identity_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	identity_panel.position = Vector2(14.0, 14.0)
	identity_panel.add_theme_stylebox_override("panel", _style(COLOR_PANEL, Color(COLOR_BORDER, 0.48), 13))
	var identity_column := VBoxContainer.new()
	identity_column.add_theme_constant_override("separation", 1)
	identity_panel.add_child(identity_column)
	_name_label = Label.new()
	_name_label.text = "BITLING"
	_name_label.add_theme_color_override("font_color", COLOR_TEXT)
	_name_label.add_theme_font_size_override("font_size", 15)
	identity_column.add_child(_name_label)
	_details_label = Label.new()
	_details_label.text = "SIGNAL • BABY"
	_details_label.add_theme_color_override("font_color", COLOR_MUTED)
	_details_label.add_theme_font_size_override("font_size", 9)
	identity_column.add_child(_details_label)
	_stage.add_child(identity_panel)

	var rarity_panel := PanelContainer.new()
	rarity_panel.name = "StageRarityBadge"
	rarity_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rarity_panel.anchor_left = 1.0
	rarity_panel.anchor_right = 1.0
	rarity_panel.offset_left = -122.0
	rarity_panel.offset_right = -14.0
	rarity_panel.offset_top = 14.0
	rarity_panel.offset_bottom = 48.0
	rarity_panel.add_theme_stylebox_override("panel", _style(COLOR_PANEL, Color(COLOR_RARE, 0.54), 13))
	_rarity_label = Label.new()
	_rarity_label.text = "COMMON"
	_rarity_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_rarity_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_rarity_label.add_theme_color_override("font_color", COLOR_RARE)
	_rarity_label.add_theme_font_size_override("font_size", 10)
	rarity_panel.add_child(_rarity_label)
	_stage.add_child(rarity_panel)

func _refresh() -> void:
	var identity := get_node_or_null("/root/BitlingIdentity")
	var profile := get_node_or_null("/root/DevelopmentProfile")
	if identity == null or profile == null:
		return
	var passport: Dictionary = identity.get_public_passport()
	var snapshot: Dictionary = profile.get_display_snapshot()
	var rarity_data: Dictionary = snapshot.get("rarity", {})
	var tier := str(rarity_data.get("tier", "COMMON")).to_upper()
	_name_label.text = str(passport.get("display_name", "BITLING")).to_upper()
	_details_label.text = "%s • %s" % [
		str(passport.get("form_id", "signal")).to_upper(),
		str(passport.get("development_phase", "BABY")).to_upper()
	]
	_rarity_label.text = ("✦ " + tier + " ✦") if tier == "LEGENDARY" else tier
	_rarity_label.add_theme_color_override("font_color", COLOR_LEGENDARY if tier == "LEGENDARY" else COLOR_RARE)
	if _stage.has_method("set_rarity"):
		_stage.call("set_rarity", tier)

func _on_identity_updated(_snapshot: Dictionary) -> void:
	_refresh()

func _on_profile_changed(_snapshot: Dictionary) -> void:
	_refresh()

func _on_state_changed(_key: String, _value: Variant) -> void:
	call_deferred("_refresh")

func _style(background: Color, border: Color, radius: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(radius)
	style.content_margin_left = 10.0
	style.content_margin_right = 10.0
	style.content_margin_top = 7.0
	style.content_margin_bottom = 7.0
	return style
