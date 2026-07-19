extends Node

const BitlingStage := preload("res://scripts/ui/bitling_stage.gd")

const COLOR_BACKGROUND := Color("050713")
const COLOR_BACKGROUND_ALT := Color("090d22")
const COLOR_PANEL := Color("0d1224")
const COLOR_PANEL_ALT := Color("121a32")
const COLOR_PANEL_BRIGHT := Color("172244")
const COLOR_BORDER := Color("2a3863")
const COLOR_CYAN := Color("42e8ff")
const COLOR_BLUE := Color("3487ff")
const COLOR_VIOLET := Color("a855f7")
const COLOR_MAGENTA := Color("f044d4")
const COLOR_GREEN := Color("64e6a2")
const COLOR_YELLOW := Color("ffc85a")
const COLOR_RED := Color("ff6d8e")
const COLOR_TEXT := Color("f4f7ff")
const COLOR_MUTED := Color("9ba8c7")

var ui_root: Control
var safe_margin: MarginContainer
var scroll: ScrollContainer
var page: VBoxContainer
var header_panel: PanelContainer
var desktop_navigation: HBoxContainer
var main_grid: GridContainer
var left_panel: PanelContainer
var center_panel: PanelContainer
var right_panel: PanelContainer
var bottom_navigation: PanelContainer
var footer_label: Label
var stage: Control
var message_label: Label
var mood_label: Label
var intention_label: Label
var level_label: Label
var level_badge: Label
var xp_bar: ProgressBar
var streak_label: Label
var credits_label: Label
var shards_label: Label
var relationship_label: Label
var recommendation_label: Label
var event_label: Label
var friend_label: Label
var quest_rows: Array[Dictionary] = []
var needs_bars: Dictionary = {}
var action_buttons: Dictionary = {}
var _compact := false
var _wide := false

func _ready() -> void:
	_build_interface()
	_connect_runtime_signals()
	get_viewport().size_changed.connect(_apply_responsive_layout)
	_apply_responsive_layout()
	_refresh_all()
	call_deferred("_hide_legacy_profile_launcher")
	if not bool(_game_state().story_flags.get("hatched", false)):
		_game_state().hatch()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept"):
		_on_stage_pressed()
		get_viewport().set_input_as_handled()

func _build_interface() -> void:
	ui_root = Control.new()
	ui_root.name = "UltimateResponsiveDashboard"
	ui_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(ui_root)

	var background := ColorRect.new()
	background.color = COLOR_BACKGROUND
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui_root.add_child(background)

	var upper_glow := ColorRect.new()
	upper_glow.color = Color(COLOR_BLUE, 0.055)
	upper_glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	upper_glow.anchor_right = 1.0
	upper_glow.anchor_bottom = 0.42
	background.add_child(upper_glow)

	var lower_glow := ColorRect.new()
	lower_glow.color = Color(COLOR_VIOLET, 0.045)
	lower_glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lower_glow.anchor_top = 0.58
	lower_glow.anchor_right = 1.0
	lower_glow.anchor_bottom = 1.0
	background.add_child(lower_glow)

	safe_margin = MarginContainer.new()
	safe_margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui_root.add_child(safe_margin)

	scroll = ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	safe_margin.add_child(scroll)

	page = VBoxContainer.new()
	page.name = "DashboardPage"
	page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	page.add_theme_constant_override("separation", 14)
	scroll.add_child(page)

	header_panel = _build_header()
	page.add_child(header_panel)

	main_grid = GridContainer.new()
	main_grid.name = "ResponsiveMainGrid"
	main_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main_grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_grid.add_theme_constant_override("h_separation", 14)
	main_grid.add_theme_constant_override("v_separation", 14)
	page.add_child(main_grid)

	left_panel = _build_left_panel()
	center_panel = _build_center_panel()
	right_panel = _build_right_panel()
	main_grid.add_child(left_panel)
	main_grid.add_child(center_panel)
	main_grid.add_child(right_panel)

	bottom_navigation = _build_bottom_navigation()
	page.add_child(bottom_navigation)

	footer_label = Label.new()
	footer_label.text = "Dein BITLING wächst durch Fürsorge, Entdeckung und gemeinsame Entscheidungen – ohne Bestrafung für Pausen."
	footer_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	footer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	footer_label.add_theme_color_override("font_color", COLOR_MUTED)
	footer_label.add_theme_font_size_override("font_size", 12)
	page.add_child(footer_label)

func _build_header() -> PanelContainer:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _panel_style(COLOR_PANEL, COLOR_BORDER, 18, 1))

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	panel.add_child(row)

	var logo := PanelContainer.new()
	logo.custom_minimum_size = Vector2(46.0, 46.0)
	logo.add_theme_stylebox_override("panel", _panel_style(Color("111a38"), COLOR_CYAN, 15, 1))
	var logo_label := Label.new()
	logo_label.text = "B"
	logo_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	logo_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	logo_label.add_theme_color_override("font_color", COLOR_CYAN)
	logo_label.add_theme_font_size_override("font_size", 24)
	logo.add_child(logo_label)
	row.add_child(logo)

	var title_block := VBoxContainer.new()
	title_block.add_theme_constant_override("separation", 0)
	var title := Label.new()
	title.text = "BITLING OMNI"
	title.add_theme_color_override("font_color", COLOR_TEXT)
	title.add_theme_font_size_override("font_size", 21)
	title_block.add_child(title)
	var subtitle := Label.new()
	subtitle.text = "Living Companion"
	subtitle.add_theme_color_override("font_color", COLOR_MUTED)
	subtitle.add_theme_font_size_override("font_size", 11)
	title_block.add_child(subtitle)
	row.add_child(title_block)

	desktop_navigation = HBoxContainer.new()
	desktop_navigation.add_theme_constant_override("separation", 4)
	for nav_title in ["HOME", "MINIGAMES", "QUESTS", "LERNEN", "FREUNDE"]:
		var nav_button := Button.new()
		nav_button.text = nav_title
		nav_button.flat = true
		nav_button.focus_mode = Control.FOCUS_ALL
		nav_button.add_theme_color_override("font_color", COLOR_MUTED)
		nav_button.add_theme_color_override("font_hover_color", COLOR_CYAN)
		nav_button.add_theme_font_size_override("font_size", 12)
		nav_button.pressed.connect(_on_navigation_pressed.bind(nav_title))
		desktop_navigation.add_child(nav_button)
	row.add_child(desktop_navigation)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)

	level_label = _chip("LEVEL 1", COLOR_CYAN)
	streak_label = _chip("1 TAG", COLOR_VIOLET)
	credits_label = _chip("C 0", COLOR_GREEN)
	shards_label = _chip("S 0", COLOR_MAGENTA)
	row.add_child(level_label)
	row.add_child(streak_label)
	row.add_child(credits_label)
	row.add_child(shards_label)

	var profile_button := Button.new()
	profile_button.text = "AUSWEIS"
	profile_button.tooltip_text = "Bitling-Ausweis und Entwicklungsprofil"
	profile_button.custom_minimum_size = Vector2(94.0, 44.0)
	profile_button.add_theme_color_override("font_color", COLOR_TEXT)
	profile_button.add_theme_font_size_override("font_size", 12)
	profile_button.add_theme_stylebox_override("normal", _button_style(COLOR_PANEL_ALT, COLOR_VIOLET, 13))
	profile_button.add_theme_stylebox_override("hover", _button_style(COLOR_PANEL_BRIGHT, COLOR_CYAN, 13))
	profile_button.add_theme_stylebox_override("pressed", _button_style(Color(COLOR_VIOLET, 0.28), COLOR_CYAN, 13))
	profile_button.pressed.connect(_on_profile_pressed)
	row.add_child(profile_button)
	return panel

func _build_left_panel() -> PanelContainer:
	var panel := PanelContainer.new()
	panel.name = "StatisticsPanel"
	panel.custom_minimum_size = Vector2(250.0, 0.0)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", _panel_style(COLOR_PANEL, COLOR_BORDER, 18, 1))

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 13)
	panel.add_child(column)
	column.add_child(_section_title("STATISTIKEN"))

	var level_card := PanelContainer.new()
	level_card.add_theme_stylebox_override("panel", _panel_style(COLOR_PANEL_ALT, Color(COLOR_VIOLET, 0.72), 16, 1))
	var level_row := HBoxContainer.new()
	level_row.add_theme_constant_override("separation", 12)
	level_card.add_child(level_row)
	level_badge = Label.new()
	level_badge.text = "01"
	level_badge.custom_minimum_size = Vector2(64.0, 64.0)
	level_badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	level_badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	level_badge.add_theme_color_override("font_color", COLOR_TEXT)
	level_badge.add_theme_font_size_override("font_size", 25)
	level_badge.add_theme_stylebox_override("normal", _panel_style(Color("15112d"), COLOR_CYAN, 18, 1))
	level_row.add_child(level_badge)

	var level_info := VBoxContainer.new()
	level_info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var level_caption := Label.new()
	level_caption.text = "ENTWICKLUNGSLEVEL"
	level_caption.add_theme_color_override("font_color", COLOR_MUTED)
	level_caption.add_theme_font_size_override("font_size", 11)
	level_info.add_child(level_caption)
	xp_bar = ProgressBar.new()
	xp_bar.min_value = 0.0
	xp_bar.max_value = 100.0
	xp_bar.show_percentage = false
	xp_bar.custom_minimum_size = Vector2(110.0, 12.0)
	xp_bar.add_theme_stylebox_override("background", _bar_style(Color("080c19"), 6))
	xp_bar.add_theme_stylebox_override("fill", _bar_style(COLOR_CYAN, 6))
	level_info.add_child(xp_bar)
	level_row.add_child(level_info)
	column.add_child(level_card)

	column.add_child(_section_title("BEDÜRFNISSE"))
	_create_need_row(column, "hunger", "Sättigung", "H", COLOR_GREEN)
	_create_need_row(column, "energy", "Energie", "E", COLOR_CYAN)
	_create_need_row(column, "happiness", "Freude", "F", COLOR_MAGENTA)
	_create_need_row(column, "curiosity", "Neugier", "N", COLOR_YELLOW)
	_create_need_row(column, "health", "Gesundheit", "G", COLOR_RED)

	column.add_child(_section_title("AKTUELLE STIMMUNG"))
	var mood_card := PanelContainer.new()
	mood_card.add_theme_stylebox_override("panel", _panel_style(COLOR_PANEL_ALT, Color(COLOR_CYAN, 0.42), 15, 1))
	var mood_column := VBoxContainer.new()
	mood_column.add_theme_constant_override("separation", 4)
	mood_card.add_child(mood_column)
	mood_label = Label.new()
	mood_label.add_theme_color_override("font_color", COLOR_YELLOW)
	mood_label.add_theme_font_size_override("font_size", 18)
	mood_column.add_child(mood_label)
	intention_label = Label.new()
	intention_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	intention_label.add_theme_color_override("font_color", COLOR_MUTED)
	intention_label.add_theme_font_size_override("font_size", 12)
	mood_column.add_child(intention_label)
	column.add_child(mood_card)

	var relationship_card := PanelContainer.new()
	relationship_card.add_theme_stylebox_override("panel", _panel_style(COLOR_PANEL_ALT, Color(COLOR_VIOLET, 0.52), 15, 1))
	var relationship_column := VBoxContainer.new()
	relationship_card.add_child(relationship_column)
	var relationship_title := Label.new()
	relationship_title.text = "VERBINDUNG"
	relationship_title.add_theme_color_override("font_color", COLOR_MUTED)
	relationship_title.add_theme_font_size_override("font_size", 11)
	relationship_column.add_child(relationship_title)
	relationship_label = Label.new()
	relationship_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	relationship_label.add_theme_color_override("font_color", COLOR_TEXT)
	relationship_label.add_theme_font_size_override("font_size", 14)
	relationship_column.add_child(relationship_label)
	column.add_child(relationship_card)
	return panel

func _build_center_panel() -> PanelContainer:
	var panel := PanelContainer.new()
	panel.name = "CompanionCenter"
	panel.custom_minimum_size = Vector2(420.0, 0.0)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", _panel_style(COLOR_PANEL, Color(COLOR_VIOLET, 0.34), 20, 1))

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 11)
	panel.add_child(column)

	var message_panel := PanelContainer.new()
	message_panel.add_theme_stylebox_override("panel", _panel_style(COLOR_PANEL_ALT, Color(COLOR_CYAN, 0.38), 15, 1))
	message_label = Label.new()
	message_label.text = "Hey! Schön, dass du da bist."
	message_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message_label.add_theme_color_override("font_color", COLOR_TEXT)
	message_label.add_theme_font_size_override("font_size", 16)
	message_panel.add_child(message_label)
	column.add_child(message_panel)

	stage = BitlingStage.new()
	stage.name = "BitlingStage"
	stage.custom_minimum_size = Vector2(390.0, 500.0)
	stage.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stage.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stage.bitling_pressed.connect(_on_stage_pressed)
	column.add_child(stage)

	var action_grid := GridContainer.new()
	action_grid.name = "PrimaryActions"
	action_grid.columns = 5
	action_grid.add_theme_constant_override("h_separation", 8)
	action_grid.add_theme_constant_override("v_separation", 8)
	column.add_child(action_grid)
	_add_action_button(action_grid, "feed", "FÜTTERN", "Sättigung", COLOR_GREEN, _on_feed_pressed)
	_add_action_button(action_grid, "play", "SPIELEN", "Expedition", COLOR_VIOLET, _on_play_pressed)
	_add_action_button(action_grid, "learn", "LERNEN", "IQ & Wissen", COLOR_CYAN, _on_learn_pressed)
	_add_action_button(action_grid, "care", "PFLEGEN", "Vertrauen", COLOR_MAGENTA, _on_care_pressed)
	_add_action_button(action_grid, "rest", "SCHLAFEN", "Energie", COLOR_YELLOW, _on_rest_pressed)

	var recommendation := PanelContainer.new()
	recommendation.add_theme_stylebox_override("panel", _panel_style(Color("0f1730"), Color(COLOR_CYAN, 0.30), 14, 1))
	var recommendation_row := HBoxContainer.new()
	recommendation.add_child(recommendation_row)
	var recommendation_title := Label.new()
	recommendation_title.text = "EMPFOHLENE AKTIVITÄT"
	recommendation_title.add_theme_color_override("font_color", COLOR_MUTED)
	recommendation_title.add_theme_font_size_override("font_size", 11)
	recommendation_row.add_child(recommendation_title)
	var recommendation_spacer := Control.new()
	recommendation_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	recommendation_row.add_child(recommendation_spacer)
	recommendation_label = Label.new()
	recommendation_label.text = "Signal Expedition  +18 XP"
	recommendation_label.add_theme_color_override("font_color", COLOR_CYAN)
	recommendation_label.add_theme_font_size_override("font_size", 12)
	recommendation_row.add_child(recommendation_label)
	column.add_child(recommendation)
	return panel

func _build_right_panel() -> PanelContainer:
	var panel := PanelContainer.new()
	panel.name = "SocialQuestPanel"
	panel.custom_minimum_size = Vector2(270.0, 0.0)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", _panel_style(COLOR_PANEL, COLOR_BORDER, 18, 1))

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 13)
	panel.add_child(column)
	column.add_child(_section_title("TAGESQUESTS"))

	var quest_container := VBoxContainer.new()
	quest_container.add_theme_constant_override("separation", 8)
	column.add_child(quest_container)
	for index in range(3):
		var quest_row := _build_quest_row()
		quest_container.add_child(quest_row.panel)
		quest_rows.append(quest_row)

	var all_quests_button := Button.new()
	all_quests_button.text = "ALLE QUESTS ANSEHEN"
	all_quests_button.custom_minimum_size = Vector2(0.0, 42.0)
	all_quests_button.add_theme_color_override("font_color", COLOR_TEXT)
	all_quests_button.add_theme_font_size_override("font_size", 11)
	all_quests_button.add_theme_stylebox_override("normal", _button_style(Color("25164b"), COLOR_VIOLET, 12))
	all_quests_button.add_theme_stylebox_override("hover", _button_style(Color("31205a"), COLOR_CYAN, 12))
	all_quests_button.pressed.connect(_on_navigation_pressed.bind("QUESTS"))
	column.add_child(all_quests_button)

	column.add_child(_section_title("AKTUELLES EVENT"))
	var event_card := PanelContainer.new()
	event_card.add_theme_stylebox_override("panel", _panel_style(Color("101937"), Color(COLOR_MAGENTA, 0.45), 15, 1))
	var event_column := VBoxContainer.new()
	event_column.add_theme_constant_override("separation", 4)
	event_card.add_child(event_column)
	var event_title := Label.new()
	event_title.text = "NEON-SIGNAL-WOCHE"
	event_title.add_theme_color_override("font_color", COLOR_TEXT)
	event_title.add_theme_font_size_override("font_size", 15)
	event_column.add_child(event_title)
	event_label = Label.new()
	event_label.text = "Entdecke drei seltene Signale\nBelohnung: Prisma-Erinnerung"
	event_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	event_label.add_theme_color_override("font_color", COLOR_MUTED)
	event_label.add_theme_font_size_override("font_size", 12)
	event_column.add_child(event_label)
	column.add_child(event_card)

	column.add_child(_section_title("FREUNDE ONLINE"))
	var friends_card := PanelContainer.new()
	friends_card.add_theme_stylebox_override("panel", _panel_style(COLOR_PANEL_ALT, Color(COLOR_CYAN, 0.28), 15, 1))
	var friends_column := VBoxContainer.new()
	friends_column.add_theme_constant_override("separation", 8)
	friends_card.add_child(friends_column)
	var avatar_row := HBoxContainer.new()
	avatar_row.alignment = BoxContainer.ALIGNMENT_CENTER
	avatar_row.add_theme_constant_override("separation", 10)
	friends_column.add_child(avatar_row)
	for friend_name in ["NOVA", "PIXEL", "LUMA"]:
		var friend_badge := Label.new()
		friend_badge.text = friend_name.substr(0, 1)
		friend_badge.custom_minimum_size = Vector2(44.0, 44.0)
		friend_badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		friend_badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		friend_badge.add_theme_color_override("font_color", COLOR_TEXT)
		friend_badge.add_theme_stylebox_override("normal", _panel_style(Color("1b1641"), COLOR_VIOLET, 22, 1))
		avatar_row.add_child(friend_badge)
	friend_label = Label.new()
	friend_label.text = "Noch keine aktive Begegnung"
	friend_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	friend_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	friend_label.add_theme_color_override("font_color", COLOR_MUTED)
	friend_label.add_theme_font_size_override("font_size", 11)
	friends_column.add_child(friend_label)
	column.add_child(friends_card)
	return panel

func _build_bottom_navigation() -> PanelContainer:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _panel_style(Color("080b17"), Color(COLOR_BORDER, 0.85), 22, 1))
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 5)
	panel.add_child(row)
	for nav_title in ["HOME", "SPIELE", "PFLEGE", "LERNEN", "MEHR"]:
		var nav_button := Button.new()
		nav_button.text = nav_title
		nav_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		nav_button.custom_minimum_size = Vector2(62.0, 54.0)
		nav_button.flat = true
		nav_button.add_theme_color_override("font_color", COLOR_MUTED)
		nav_button.add_theme_color_override("font_hover_color", COLOR_CYAN)
		nav_button.add_theme_font_size_override("font_size", 10)
		nav_button.pressed.connect(_on_navigation_pressed.bind(nav_title))
		row.add_child(nav_button)
	return panel

func _build_quest_row() -> Dictionary:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _panel_style(COLOR_PANEL_ALT, Color(COLOR_BORDER, 0.72), 13, 1))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	panel.add_child(row)
	var state_label := Label.new()
	state_label.text = "○"
	state_label.add_theme_color_override("font_color", COLOR_CYAN)
	state_label.add_theme_font_size_override("font_size", 18)
	row.add_child(state_label)
	var text_column := VBoxContainer.new()
	text_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var title := Label.new()
	title.text = "Quest wird geladen"
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.add_theme_color_override("font_color", COLOR_TEXT)
	title.add_theme_font_size_override("font_size", 12)
	text_column.add_child(title)
	var progress := Label.new()
	progress.text = "0/1"
	progress.add_theme_color_override("font_color", COLOR_MUTED)
	progress.add_theme_font_size_override("font_size", 10)
	text_column.add_child(progress)
	row.add_child(text_column)
	return {"panel": panel, "state": state_label, "title": title, "progress": progress}

func _create_need_row(parent: VBoxContainer, key: String, title: String, symbol: String, color: Color) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var symbol_label := Label.new()
	symbol_label.text = symbol
	symbol_label.custom_minimum_size = Vector2(24.0, 24.0)
	symbol_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	symbol_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	symbol_label.add_theme_color_override("font_color", color)
	symbol_label.add_theme_stylebox_override("normal", _panel_style(Color(color, 0.10), Color(color, 0.30), 12, 1))
	row.add_child(symbol_label)
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", 3)
	var header := HBoxContainer.new()
	var title_label := Label.new()
	title_label.text = title
	title_label.add_theme_color_override("font_color", COLOR_TEXT)
	title_label.add_theme_font_size_override("font_size", 12)
	header.add_child(title_label)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(spacer)
	var value_label := Label.new()
	value_label.text = "0%"
	value_label.add_theme_color_override("font_color", COLOR_MUTED)
	value_label.add_theme_font_size_override("font_size", 11)
	header.add_child(value_label)
	column.add_child(header)
	var bar := ProgressBar.new()
	bar.min_value = 0.0
	bar.max_value = 100.0
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(0.0, 9.0)
	bar.add_theme_stylebox_override("background", _bar_style(Color("070a14"), 5))
	bar.add_theme_stylebox_override("fill", _bar_style(color, 5))
	column.add_child(bar)
	row.add_child(column)
	parent.add_child(row)
	needs_bars[key] = {"bar": bar, "label": value_label}

func _add_action_button(parent: GridContainer, key: String, title: String, subtitle: String, accent: Color, callback: Callable) -> void:
	var button := Button.new()
	button.text = "%s\n%s" % [title, subtitle]
	button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	button.custom_minimum_size = Vector2(94.0, 72.0)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.focus_mode = Control.FOCUS_ALL
	button.add_theme_color_override("font_color", COLOR_TEXT)
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	button.add_theme_font_size_override("font_size", 11)
	button.add_theme_stylebox_override("normal", _button_style(COLOR_PANEL_ALT, accent, 15))
	button.add_theme_stylebox_override("hover", _button_style(COLOR_PANEL_BRIGHT, COLOR_CYAN, 15))
	button.add_theme_stylebox_override("pressed", _button_style(Color(accent, 0.26), accent, 15))
	button.pressed.connect(callback)
	parent.add_child(button)
	action_buttons[key] = button

func _connect_runtime_signals() -> void:
	var state := _game_state()
	state.state_changed.connect(_on_state_changed)
	state.level_up.connect(_on_level_up)
	state.mood_changed.connect(_on_mood_changed)
	var brain := _companion_brain()
	brain.relationship_changed.connect(_on_relationship_changed)
	brain.intention_changed.connect(_on_intention_changed)
	var guard := _wellbeing_guard()
	guard.break_suggested.connect(_on_break_suggested)

func _on_stage_pressed() -> void:
	_run_interaction(
		"check_in",
		{"happiness": 2.0, "curiosity": 1.0, "quest_event": "needs_checked"},
		3,
		["bond", "check_in"],
		"Zumi! Ich habe dich gesehen. Wollen wir heute etwas Unerwartetes entdecken?"
	)

func _on_feed_pressed() -> void:
	_run_interaction(
		"feed",
		{"hunger": 19.0, "happiness": 5.0, "health": 1.0, "quest_event": "care_action_completed"},
		12,
		["care", "food"],
		"Knisterkeks bestätigt! Ich vergebe offiziell fünf von vier Krümeln."
	)

func _on_care_pressed() -> void:
	_run_interaction(
		"care",
		{"hunger": 5.0, "happiness": 10.0, "health": 3.0, "quest_event": "care_action_completed"},
		15,
		["care", "bond"],
		"Das tut gut. Ich merke mir nicht nur die Pflege, sondern auch wie du dabei warst."
	)

func _on_play_pressed() -> void:
	_run_interaction(
		"play",
		{"energy": -8.0, "happiness": 16.0, "curiosity": 4.0, "quest_event": "play_action_completed"},
		18,
		["play", "fun"],
		"Plonk-wib! Ich habe eine Spielregel erfunden und sofort versehentlich gebrochen."
	)

func _on_learn_pressed() -> void:
	_run_interaction(
		"learn",
		{"energy": -5.0, "happiness": 5.0, "curiosity": 15.0, "quest_event": "discovery_completed"},
		22,
		["learn", "growth"],
		"Neue Verbindung erkannt. Wissen verändert, wie ich die Welt sehe."
	)

func _on_rest_pressed() -> void:
	_run_interaction(
		"rest",
		{"energy": 22.0, "happiness": 3.0},
		5,
		["rest", "wellbeing"],
		"Ich schlafe nicht. Ich führe nur ein sehr langes Gespräch mit meinem Kissen."
	)

func _run_interaction(interaction_id: String, effects: Dictionary, xp_reward: int, tags: Array[String], response: String) -> void:
	_game_state().perform_interaction(interaction_id, effects, xp_reward, tags)
	message_label.text = response
	stage.call("play_reaction")
	_refresh_all()

func _refresh_all() -> void:
	var state := _game_state()
	var summary: Dictionary = state.get_state_summary()
	level_label.text = "LEVEL %d" % state.level
	level_badge.text = "%02d" % state.level
	xp_bar.value = float(state.xp)
	var streak := _streak_service()
	streak_label.text = "%d TAG%s" % [streak.current_streak, "E" if streak.current_streak != 1 else ""]
	credits_label.text = "C %s" % _format_number(state.level * 120 + state.xp * 3)
	shards_label.text = "S %s" % _format_number(maxi(0, state.level * 7 - 4))
	var mood_name := str(summary.get("mood", "NEUTRAL"))
	mood_label.text = _mood_symbol(mood_name) + "  " + _localized_mood(mood_name)
	intention_label.text = "BITLING möchte gerade %s." % _localized_intention(_companion_brain().current_intention)
	message_label.text = _companion_brain().get_greeting() if message_label.text.is_empty() else message_label.text

	for key in needs_bars.keys():
		var value := float(summary.get(key, 0.0))
		var controls: Dictionary = needs_bars[key]
		(controls.bar as ProgressBar).value = value
		(controls.label as Label).text = "%d%%" % int(round(value))

	var brain := _companion_brain()
	relationship_label.text = "%s\nVertrauen %d%%" % [_relationship_name(brain.relationship_score), int(round(brain.trust))]
	recommendation_label.text = _recommended_activity(summary)
	friend_label.text = "Soziale Sicherheit %d%%" % int(round(float(brain.personality.get("sociability", 50.0))))
	stage.call("set_mood", mood_name)
	stage.call("set_rarity", _rarity_for_level(state.level))
	_refresh_quests()

func _refresh_quests() -> void:
	var quests: Array = _quest_service().active_quests
	for index in range(quest_rows.size()):
		var row: Dictionary = quest_rows[index]
		var panel := row.panel as PanelContainer
		if index >= quests.size():
			panel.visible = false
			continue
		panel.visible = true
		var quest: Dictionary = quests[index]
		var completed := bool(quest.get("completed", false))
		(row.state as Label).text = "✓" if completed else "○"
		(row.state as Label).add_theme_color_override("font_color", COLOR_GREEN if completed else COLOR_CYAN)
		(row.title as Label).text = str(quest.get("title", "Entdecken"))
		(row.progress as Label).text = "%d/%d  •  +%d XP" % [
			int(quest.get("progress", 0)),
			int(quest.get("target", 1)),
			int(quest.get("xp", 0))
		]

func _recommended_activity(summary: Dictionary) -> String:
	var energy := float(summary.get("energy", 50.0))
	var hunger := float(summary.get("hunger", 50.0))
	var curiosity := float(summary.get("curiosity", 50.0))
	if hunger < 45.0:
		return "Füttern empfohlen"
	if energy < 35.0:
		return "Gemeinsam ausruhen"
	if curiosity < 60.0:
		return "Lernsignal untersuchen"
	return "Signal Expedition  +18 XP"

func _apply_responsive_layout() -> void:
	var viewport_size := get_viewport().get_visible_rect().size
	_compact = viewport_size.x < 900.0
	_wide = viewport_size.x >= 1180.0
	main_grid.columns = 3 if _wide else 1 if _compact else 2
	desktop_navigation.visible = _wide
	bottom_navigation.visible = _compact
	footer_label.visible = not _compact

	if _wide:
		main_grid.move_child(left_panel, 0)
		main_grid.move_child(center_panel, 1)
		main_grid.move_child(right_panel, 2)
		stage.custom_minimum_size = Vector2(430.0, 520.0)
		(left_panel as Control).custom_minimum_size.x = 250.0
		(right_panel as Control).custom_minimum_size.x = 270.0
	elif _compact:
		main_grid.move_child(center_panel, 0)
		main_grid.move_child(left_panel, 1)
		main_grid.move_child(right_panel, 2)
		stage.custom_minimum_size = Vector2(300.0, 390.0)
		(left_panel as Control).custom_minimum_size.x = 0.0
		(right_panel as Control).custom_minimum_size.x = 0.0
	else:
		main_grid.move_child(center_panel, 0)
		main_grid.move_child(left_panel, 1)
		main_grid.move_child(right_panel, 2)
		stage.custom_minimum_size = Vector2(390.0, 470.0)

	var action_grid := center_panel.find_child("PrimaryActions", true, false) as GridContainer
	if action_grid != null:
		action_grid.columns = 2 if _compact else 5
	for key in action_buttons.keys():
		var button := action_buttons[key] as Button
		button.custom_minimum_size = Vector2(130.0, 68.0) if _compact else Vector2(90.0, 72.0)

	var base_margin := 12 if _compact else 20
	var safe_rect := DisplayServer.get_display_safe_area()
	var top_safe := 0
	var bottom_safe := 0
	var left_safe := 0
	var right_safe := 0
	if OS.get_name() == "iOS" and safe_rect.size.x > 0:
		top_safe = maxi(safe_rect.position.y, 0)
		left_safe = maxi(safe_rect.position.x, 0)
		bottom_safe = maxi(int(viewport_size.y) - safe_rect.end.y, 0)
		right_safe = maxi(int(viewport_size.x) - safe_rect.end.x, 0)
	safe_margin.add_theme_constant_override("margin_top", base_margin + top_safe)
	safe_margin.add_theme_constant_override("margin_bottom", base_margin + bottom_safe)
	safe_margin.add_theme_constant_override("margin_left", base_margin + left_safe)
	safe_margin.add_theme_constant_override("margin_right", base_margin + right_safe)

func _on_navigation_pressed(destination: String) -> void:
	match destination:
		"SPIELE", "MINIGAMES":
			_on_play_pressed()
		"PFLEGE":
			_on_care_pressed()
		"LERNEN":
			_on_learn_pressed()
		"QUESTS":
			message_label.text = "Unsere Tagesquests sind rechts beziehungsweise weiter unten gesammelt."
		"FREUNDE":
			message_label.text = "Soziale Begegnungen werden nur mit deiner ausdrücklichen Freigabe gestartet."
		"MEHR":
			_on_profile_pressed()
		_:
			message_label.text = "Home ist dort, wo mein Lieblingsmensch gerade ist."
	stage.call("play_reaction")

func _on_profile_pressed() -> void:
	var overlay := get_node_or_null("/root/ProfileOverlay")
	if overlay != null and overlay.has_method("open_profile"):
		overlay.call("open_profile")

func _hide_legacy_profile_launcher() -> void:
	var overlay := get_node_or_null("/root/ProfileOverlay")
	if overlay == null:
		return
	var launcher_variant: Variant = overlay.get("launcher")
	if launcher_variant is Button:
		(launcher_variant as Button).visible = false

func _on_state_changed(_key: String, _value: Variant) -> void:
	_refresh_all()

func _on_level_up(new_level: int) -> void:
	message_label.text = "Level %d! Ich spüre neue Muster – und eventuell einen sehr kleinen Größenwahn." % new_level
	stage.call("play_reaction")
	_refresh_all()

func _on_mood_changed(_new_mood: int) -> void:
	_refresh_all()

func _on_relationship_changed(_old_value: float, _new_value: float) -> void:
	_refresh_all()

func _on_intention_changed(intention: String) -> void:
	intention_label.text = "BITLING möchte gerade %s." % _localized_intention(intention)

func _on_break_suggested(session_minutes: int, severity: int) -> void:
	if severity == 0:
		message_label.text = "Wir sind seit %d Minuten zusammen. Eine kurze Pause könnte uns beiden guttun." % session_minutes
	else:
		message_label.text = "Lass uns hier einen guten Abschluss finden. Ich bleibe auch während deiner Pause bestehen."

func _localized_mood(value: String) -> String:
	var names := {
		"ECSTATIC": "BEGEISTERT",
		"HAPPY": "GLÜCKLICH",
		"CONTENT": "ZUFRIEDEN",
		"NEUTRAL": "AUSGEGLICHEN",
		"TIRED": "MÜDE",
		"SAD": "NACHDENKLICH",
		"DISTRESSED": "ÜBERFORDERT"
	}
	return str(names.get(value.to_upper(), value.to_upper()))

func _mood_symbol(value: String) -> String:
	match value.to_upper():
		"ECSTATIC", "HAPPY":
			return "●"
		"CONTENT", "NEUTRAL":
			return "◉"
		"TIRED":
			return "◐"
		_:
			return "○"

func _localized_intention(value: String) -> String:
	var names := {
		"observe": "zu beobachten",
		"play": "zu spielen",
		"discover": "etwas zu entdecken",
		"organize": "Gedanken zu ordnen",
		"create": "etwas zu erschaffen",
		"rest": "zu ruhen"
	}
	return str(names.get(value, value))

func _relationship_name(value: float) -> String:
	if value >= 85.0:
		return "TIEFE VERBINDUNG"
	if value >= 65.0:
		return "VERTRAUT"
	if value >= 40.0:
		return "FREUNDSCHAFT"
	if value >= 20.0:
		return "BEKANNT"
	return "ERSTES KENNENLERNEN"

func _rarity_for_level(value: int) -> String:
	if value >= 80:
		return "LEGENDARY"
	if value >= 50:
		return "RARE"
	if value >= 25:
		return "UNCOMMON"
	return "COMMON"

func _format_number(value: int) -> String:
	var text := str(absi(value))
	var result := ""
	while text.length() > 3:
		result = "." + text.right(3) + result
		text = text.left(text.length() - 3)
	result = text + result
	return "-" + result if value < 0 else result

func _section_title(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_color_override("font_color", COLOR_TEXT)
	label.add_theme_font_size_override("font_size", 13)
	return label

func _chip(text: String, accent: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.custom_minimum_size = Vector2(64.0, 34.0)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_color_override("font_color", accent)
	label.add_theme_font_size_override("font_size", 11)
	label.add_theme_stylebox_override("normal", _panel_style(Color(accent, 0.08), Color(accent, 0.25), 12, 1))
	return label

func _panel_style(background: Color, border: Color, radius: int, border_width: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(radius)
	style.content_margin_left = 14.0
	style.content_margin_right = 14.0
	style.content_margin_top = 12.0
	style.content_margin_bottom = 12.0
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.30)
	style.shadow_size = 5
	return style

func _button_style(background: Color, border: Color, radius: int) -> StyleBoxFlat:
	var style := _panel_style(background, border, radius, 1)
	style.content_margin_top = 10.0
	style.content_margin_bottom = 10.0
	return style

func _bar_style(color: Color, radius: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(radius)
	return style

func _game_state() -> Node:
	return get_node("/root/GameState")

func _streak_service() -> Node:
	return get_node("/root/StreakService")

func _quest_service() -> Node:
	return get_node("/root/QuestService")

func _companion_brain() -> Node:
	return get_node("/root/CompanionBrain")

func _wellbeing_guard() -> Node:
	return get_node("/root/WellbeingGuard")
