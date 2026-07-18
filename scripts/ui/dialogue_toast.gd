extends CanvasLayer

## Non-modal contextual speech bubble for authored companion reactions.

const COLOR_PANEL := Color("10182a")
const COLOR_BORDER := Color("6de7ff")
const COLOR_TEXT := Color("f4f7ff")

var margin: MarginContainer
var panel: PanelContainer
var text_label: Label
var _display_generation: int = 0

func _ready() -> void:
	layer = 12
	_build_ui()
	margin.visible = false
	var director := get_node_or_null("/root/DialogueDirector")
	if director != null:
		director.line_ready.connect(_on_line_ready)

func _build_ui() -> void:
	margin = MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	margin.add_theme_constant_override("margin_left", 18)
	margin.add_theme_constant_override("margin_right", 18)
	margin.add_theme_constant_override("margin_top", 80)
	add_child(margin)
	var center := CenterContainer.new()
	margin.add_child(center)
	panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(280, 76)
	panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	panel.add_theme_stylebox_override("panel", _panel_style())
	center.add_child(panel)
	text_label = Label.new()
	text_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	text_label.add_theme_color_override("font_color", COLOR_TEXT)
	text_label.add_theme_font_size_override("font_size", 16)
	panel.add_child(text_label)

func _on_line_ready(text: String, _trigger: String) -> void:
	if text.is_empty():
		return
	_display_generation += 1
	var generation := _display_generation
	text_label.text = text
	margin.visible = true
	if not _reduce_motion():
		panel.modulate.a = 0.0
		var tween := create_tween()
		tween.tween_property(panel, "modulate:a", 1.0, 0.18)
	await get_tree().create_timer(3.8).timeout
	if generation != _display_generation:
		return
	if _reduce_motion():
		margin.visible = false
	else:
		var tween := create_tween()
		tween.tween_property(panel, "modulate:a", 0.0, 0.22)
		await tween.finished
		if generation == _display_generation:
			margin.visible = false

func _reduce_motion() -> bool:
	var state := get_node_or_null("/root/GameState")
	return state != null and bool(state.settings.get("reduce_motion", false))

func _panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = COLOR_PANEL
	style.border_color = COLOR_BORDER
	style.set_border_width_all(1)
	style.set_corner_radius_all(18)
	style.content_margin_left = 18.0
	style.content_margin_right = 18.0
	style.content_margin_top = 14.0
	style.content_margin_bottom = 14.0
	return style
