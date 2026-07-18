extends Control

@export var auto_start_delay: float = 0.8
@export var main_game_scene: String = "res://main.tscn"

var title_label: Label
var dialog_display: Label
var continue_button: Button
var is_first_launch: bool = false

func _ready() -> void:
	_build_ui()
	var state := get_node_or_null("/root/GameState")
	is_first_launch = state == null or not bool(state.story_flags.get("hatched", false))
	if is_first_launch:
		dialog_display.text = "Ein schwaches Signal antwortet auf deine Berührung."
		await get_tree().create_timer(auto_start_delay).timeout
		_start_game()
	else:
		dialog_display.text = _existing_player_message()
		continue_button.visible = true

func _build_ui() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var background := ColorRect.new()
	background.color = Color("070b17")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_top", 40)
	margin.add_theme_constant_override("margin_bottom", 40)
	add_child(margin)

	var column := VBoxContainer.new()
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", 24)
	margin.add_child(column)

	title_label = Label.new()
	title_label.text = "BITLING OMNI"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 48)
	title_label.add_theme_color_override("font_color", Color("f4f7ff"))
	column.add_child(title_label)

	dialog_display = Label.new()
	dialog_display.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	dialog_display.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	dialog_display.custom_minimum_size = Vector2(280, 100)
	dialog_display.add_theme_font_size_override("font_size", 18)
	dialog_display.add_theme_color_override("font_color", Color("aab4cf"))
	column.add_child(dialog_display)

	continue_button = Button.new()
	continue_button.text = "WEITER"
	continue_button.custom_minimum_size = Vector2(220, 54)
	continue_button.visible = false
	continue_button.pressed.connect(_start_game)
	column.add_child(continue_button)

func _existing_player_message() -> String:
	var brain := get_node_or_null("/root/CompanionBrain")
	if brain != null and brain.has_method("get_greeting"):
		return str(brain.call("get_greeting"))
	return "Schön, dass du wieder da bist."

func _start_game() -> void:
	var state := get_node_or_null("/root/GameState")
	if state != null and not bool(state.story_flags.get("hatched", false)):
		state.call("hatch")
	if get_tree().current_scene != null and get_tree().current_scene.scene_file_path == main_game_scene:
		return
	get_tree().change_scene_to_file(main_game_scene)

func _unhandled_input(event: InputEvent) -> void:
	if not is_first_launch and event.is_action_pressed("ui_accept"):
		_start_game()
		get_viewport().set_input_as_handled()
