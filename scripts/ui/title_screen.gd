extends Control

# =====================================================================
# TITLE SCREEN: First Launch Detection & Instant Hatch Flow
# =====================================================================
# Handles the first-launch experience and smooth transition to main game
# =====================================================================

@export var auto_start_delay: float = 1.5
@export var dialog_display_time: float = 1.2  # Seconds per dialog line
@export var main_game_scene: String = "res://main.tscn"

# UI References
@onready var title_label: Label = Label.new()
@onready var dialog_display: Label = Label.new()
@onready var background: ColorRect = ColorRect.new()

var is_first_launch: bool = false

func _ready() -> void:
	_setup_ui()
	
	# Check if this is a fresh start
	is_first_launch = not GameState.has_save_file()
	
	if is_first_launch:
		print("[TitleScreen] First launch detected → Initiating Instant Hatch")
		await get_tree().create_timer(auto_start_delay).timeout
		_start_instant_game()
	else:
		print("[TitleScreen] Existing save found → Showing Title Screen")
		_show_title_screen()

func _setup_ui() -> void:
	"""Creates the UI elements dynamically."""
	# Background
	background.color = Color(0.08, 0.08, 0.12, 1.0)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)
	
	# Title Label
	title_label.text = "BITLING"
	title_label.add_theme_font_size_override("font_size", 48)
	title_label.alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.anchor_top = 0.2
	title_label.anchor_bottom = 0.2
	title_label.anchor_left = 0.5
	title_label.anchor_right = 0.5
	title_label.offset_left = -150
	title_label.offset_right = 150
	add_child(title_label)
	
	# Dialog Display
	dialog_display.text = ""
	dialog_display.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	dialog_display.add_theme_font_size_override("font_size", 16)
	dialog_display.custom_minimum_size = Vector2(500, 200)
	dialog_display.anchor_top = 0.5
	dialog_display.anchor_bottom = 0.8
	dialog_display.anchor_left = 0.5
	dialog_display.anchor_right = 0.5
	dialog_display.offset_left = -250
	dialog_display.offset_right = 250
	add_child(dialog_display)

func _start_instant_game() -> void:
	"""Executes the instant hatch flow."""
	print("[TitleScreen] >>> Starting Instant Hatch Sequence <<<")
	
	# 1. Initialize GameState with BABY spawn
	GameState.initialize_new_game()
	
	# 2. Start the welcome dialog sequence
	if DialogSystem:
		DialogSystem.start_sequence("instant_welcome")
		
		# 3. Display dialogs with timing
		while DialogSystem.has_active_sequence():
			var speaker = "SYSTEM"
			var text = DialogSystem.get_current_dialog()
			
			if text:
				dialog_display.text = "[%s]\n%s" % [speaker, text]
				print("[TitleScreen] Displaying: %s" % text)
			
			await get_tree().create_timer(dialog_display_time).timeout
			DialogSystem.next_dialog()
		
		# 4. Transition to main game
		print("[TitleScreen] Instant Hatch complete → Loading main game")
		await get_tree().create_timer(1.0).timeout
		get_tree().change_scene_to_file(main_game_scene)
	else:
		push_error("[TitleScreen] DialogSystem not available!")
		get_tree().change_scene_to_file(main_game_scene)

func _show_title_screen() -> void:
	"""Shows the title screen for existing players."""
	title_label.text = "BITLING\n(Existing Save)"
	dialog_display.text = "Click anywhere or press ENTER to continue"
	
	# Add input handling for existing players
	await get_tree().create_timer(2.0).timeout
	print("[TitleScreen] Loaded Title Screen. Waiting for input...")

func _input(event: InputEvent) -> void:
	"""Handles input for continuing from title screen."""
	if not is_first_launch and (event is InputEventKey or event is InputEventScreenTouch):
		if event.pressed:
			print("[TitleScreen] Input detected → Loading main game")
			get_tree().change_scene_to_file(main_game_scene)
			get_tree().root.set_input_as_handled()
