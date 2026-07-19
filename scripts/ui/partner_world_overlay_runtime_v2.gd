extends "res://scripts/ui/partner_world_overlay_runtime.gd"

## Wave 4 bridge: the existing development dashboard remains available, but its
## settlement section now leads directly into the playable world destination.

var _world_entry: PanelContainer

func _ready() -> void:
	super._ready()
	call_deferred("_add_world_entry")

func _add_world_entry() -> void:
	if content == null or _world_entry != null:
		return
	_world_entry = PanelContainer.new()
	_world_entry.name = "PlayableSettlementEntry"
	_world_entry.add_theme_stylebox_override("panel", _panel_style(Color("101535"), Color(COLOR_VIOLET, 0.62), 18, 1))
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_top", 14)
	margin.add_theme_constant_override("margin_bottom", 14)
	_world_entry.add_child(margin)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	margin.add_child(row)
	var text_column := VBoxContainer.new()
	text_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(text_column)
	var title := Label.new()
	title.text = "SIGNALSIEDLUNG BETRETEN"
	title.add_theme_color_override("font_color", COLOR_VIOLET)
	title.add_theme_font_size_override("font_size", 18)
	text_column.add_child(title)
	var description := Label.new()
	description.text = "Bewege dich durch Bezirke, trainiere mit Mentoren, entschlüssele Geheimnisse und starte Expeditionen."
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description.add_theme_color_override("font_color", COLOR_MUTED)
	description.add_theme_font_size_override("font_size", 11)
	text_column.add_child(description)
	var button := Button.new()
	button.text = "WELT ÖFFNEN"
	button.custom_minimum_size = Vector2(138, 54)
	button.add_theme_stylebox_override("normal", _button_style(Color(COLOR_VIOLET, 0.12), Color(COLOR_VIOLET, 0.58), 14))
	button.add_theme_stylebox_override("pressed", _button_style(Color(COLOR_VIOLET, 0.28), COLOR_VIOLET, 14))
	button.pressed.connect(_open_signal_settlement)
	row.add_child(button)
	content.add_child(_world_entry)
	content.move_child(_world_entry, 0)
	_apply_responsive_layout()

func _open_signal_settlement() -> void:
	close_partner_world()
	var overlay := get_node_or_null("/root/SignalSettlementOverlay")
	if overlay != null and overlay.has_method("open_world"):
		overlay.call("open_world")
