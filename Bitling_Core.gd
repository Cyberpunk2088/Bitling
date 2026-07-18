extends Node

## Responsive, asset-independent vertical slice for BITLING OMNI.
## It is intentionally built from standard Godot Controls so it opens in Xogot
## without native plugins and supports touch, mouse, keyboard and controller input.

const COLOR_BACKGROUND := Color("070b17")
const COLOR_PANEL := Color("10182a")
const COLOR_PANEL_ALT := Color("151f35")
const COLOR_BORDER := Color("33456f")
const COLOR_ACCENT := Color("6de7ff")
const COLOR_ACCENT_SECONDARY := Color("b783ff")
const COLOR_TEXT := Color("f4f7ff")
const COLOR_MUTED := Color("aab4cf")
const COLOR_SUCCESS := Color("70e3a0")
const COLOR_WARNING := Color("ffcc6e")

var ui_root: Control
var safe_margin: MarginContainer
var main_grid: GridContainer
var status_grid: GridContainer
var avatar_button: Button
var message_label: Label
var mood_label: Label
var level_label: Label
var streak_label: Label
var relationship_label: Label
var quest_label: Label
var intention_label: Label
var needs_bars: Dictionary = {}
var action_buttons: Dictionary = {}
var _idle_tween: Tween

func _ready() -> void:
	_build_interface()
	_connect_runtime_signals()
	get_viewport().size_changed.connect(_apply_responsive_layout)
	_apply_responsive_layout()
	_refresh_all()
	_start_idle_animation()
	if not bool(_game_state().story_flags.get("hatched", false)):
		_game_state().hatch()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept"):
		_on_avatar_pressed()
		get_viewport().set_input_as_handled()

func _build_interface() -> void:
	ui_root = Control.new()
	ui_root.name = "ResponsiveUI"
	ui_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(ui_root)

	var background := ColorRect.new()
	background.color = COLOR_BACKGROUND
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui_root.add_child(background)

	var ambient := ColorRect.new()
	ambient.color = Color(COLOR_ACCENT_SECONDARY, 0.055)
	ambient.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ambient.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.add_child(ambient)

	safe_margin = MarginContainer.new()
	safe_margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui_root.add_child(safe_margin)

	var page := VBoxContainer.new()
	page.add_theme_constant_override("separation", 16)
	safe_margin.add_child(page)

	page.add_child(_build_top_bar())

	main_grid = GridContainer.new()
	main_grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_grid.add_theme_constant_override("h_separation", 16)
	main_grid.add_theme_constant_override("v_separation", 16)
	page.add_child(main_grid)

	main_grid.add_child(_build_companion_panel())
	main_grid.add_child(_build_status_panel())

	var footer := Label.new()
	footer.text = "BITLING entwickelt sich durch Fürsorge, Neugier und gemeinsame Entscheidungen – ohne Bestrafung für Pausen."
	footer.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	footer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	footer.add_theme_color_override("font_color", COLOR_MUTED)
	footer.add_theme_font_size_override("font_size", 14)
	page.add_child(footer)

func _build_top_bar() -> Control:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _panel_style(COLOR_PANEL, COLOR_BORDER, 18))

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	panel.add_child(row)

	var title_block := VBoxContainer.new()
	var title := Label.new()
	title.text = "BITLING OMNI"
	title.add_theme_color_override("font_color", COLOR_TEXT)
	title.add_theme_font_size_override("font_size", 24)
	title_block.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "Living Companion • Xogot / Godot 4.4"
	subtitle.add_theme_color_override("font_color", COLOR_MUTED)
	subtitle.add_theme_font_size_override("font_size", 13)
	title_block.add_child(subtitle)
	row.add_child(title_block)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)

	level_label = _chip_label("Level 1")
	streak_label = _chip_label("1 Tag")
	row.add_child(level_label)
	row.add_child(streak_label)
	return panel

func _build_companion_panel() -> Control:
	var panel := PanelContainer.new()
	panel.name = "CompanionPanel"
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", _panel_style(COLOR_PANEL, COLOR_BORDER, 22))

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 14)
	panel.add_child(column)

	message_label = Label.new()
	message_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message_label.add_theme_color_override("font_color", COLOR_TEXT)
	message_label.add_theme_font_size_override("font_size", 19)
	column.add_child(message_label)

	avatar_button = Button.new()
	avatar_button.name = "BitlingAvatar"
	avatar_button.text = "◉   ◉\n  ᴗ\nBITLING"
	avatar_button.tooltip_text = "Mit Bitling interagieren"
	avatar_button.custom_minimum_size = Vector2(280, 250)
	avatar_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	avatar_button.size_flags_vertical = Control.SIZE_EXPAND_FILL
	avatar_button.add_theme_font_size_override("font_size", 36)
	avatar_button.add_theme_color_override("font_color", COLOR_TEXT)
	avatar_button.add_theme_color_override("font_hover_color", COLOR_TEXT)
	avatar_button.add_theme_stylebox_override("normal", _avatar_style(COLOR_PANEL_ALT, COLOR_ACCENT))
	avatar_button.add_theme_stylebox_override("hover", _avatar_style(Color("1a2942"), COLOR_ACCENT))
	avatar_button.add_theme_stylebox_override("pressed", _avatar_style(Color("202f4d"), COLOR_ACCENT_SECONDARY))
	avatar_button.pressed.connect(_on_avatar_pressed)
	column.add_child(avatar_button)
	avatar_button.resized.connect(_center_avatar_pivot)

	mood_label = Label.new()
	mood_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mood_label.add_theme_color_override("font_color", COLOR_ACCENT)
	mood_label.add_theme_font_size_override("font_size", 17)
	column.add_child(mood_label)

	intention_label = Label.new()
	intention_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	intention_label.add_theme_color_override("font_color", COLOR_MUTED)
	intention_label.add_theme_font_size_override("font_size", 14)
	column.add_child(intention_label)

	var actions := HFlowContainer.new()
	actions.alignment = FlowContainer.ALIGNMENT_CENTER
	actions.add_theme_constant_override("h_separation", 10)
	actions.add_theme_constant_override("v_separation", 10)
	column.add_child(actions)

	_add_action_button(actions, "care", "PFLEGEN", COLOR_SUCCESS, _on_care_pressed)
	_add_action_button(actions, "play", "SPIELEN", COLOR_ACCENT_SECONDARY, _on_play_pressed)
	_add_action_button(actions, "learn", "LERNEN", COLOR_ACCENT, _on_learn_pressed)
	_add_action_button(actions, "rest", "RUHEN", COLOR_WARNING, _on_rest_pressed)
	return panel

func _build_status_panel() -> Control:
	var panel := PanelContainer.new()
	panel.name = "StatusPanel"
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", _panel_style(COLOR_PANEL, COLOR_BORDER, 22))

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 14)
	panel.add_child(column)

	var heading := Label.new()
	heading.text = "ZUSTAND & ENTWICKLUNG"
	heading.add_theme_color_override("font_color", COLOR_TEXT)
	heading.add_theme_font_size_override("font_size", 18)
	column.add_child(heading)

	status_grid = GridContainer.new()
	status_grid.columns = 1
	status_grid.add_theme_constant_override("h_separation", 10)
	status_grid.add_theme_constant_override("v_separation", 10)
	column.add_child(status_grid)

	_create_need_row("hunger", "Sättigung", COLOR_SUCCESS)
	_create_need_row("energy", "Energie", COLOR_ACCENT)
	_create_need_row("happiness", "Freude", COLOR_ACCENT_SECONDARY)
	_create_need_row("curiosity", "Neugier", COLOR_WARNING)
	_create_need_row("health", "Gesundheit", Color("ff7895"))

	var relation_panel := PanelContainer.new()
	relation_panel.add_theme_stylebox_override("panel", _panel_style(COLOR_PANEL_ALT, COLOR_BORDER, 14))
	var relation_column := VBoxContainer.new()
	relation_panel.add_child(relation_column)
	var relation_title := Label.new()
	relation_title.text = "BEZIEHUNG"
	relation_title.add_theme_color_override("font_color", COLOR_MUTED)
	relation_title.add_theme_font_size_override("font_size", 13)
	relation_column.add_child(relation_title)
	relationship_label = Label.new()
	relationship_label.add_theme_color_override("font_color", COLOR_TEXT)
	relationship_label.add_theme_font_size_override("font_size", 18)
	relation_column.add_child(relationship_label)
	column.add_child(relation_panel)

	var quest_panel := PanelContainer.new()
	quest_panel.add_theme_stylebox_override("panel", _panel_style(COLOR_PANEL_ALT, COLOR_ACCENT_SECONDARY, 14))
	var quest_column := VBoxContainer.new()
	quest_panel.add_child(quest_column)
	var quest_title := Label.new()
	quest_title.text = "TAGESIMPULS"
	quest_title.add_theme_color_override("font_color", COLOR_MUTED)
	quest_title.add_theme_font_size_override("font_size", 13)
	quest_column.add_child(quest_title)
	quest_label = Label.new()
	quest_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	quest_label.add_theme_color_override("font_color", COLOR_TEXT)
	quest_label.add_theme_font_size_override("font_size", 16)
	quest_column.add_child(quest_label)
	column.add_child(quest_panel)
	return panel

func _create_need_row(key: String, title: String, color: Color) -> void:
	var container := VBoxContainer.new()
	container.add_theme_constant_override("separation", 4)
	var header := HBoxContainer.new()
	var name_label := Label.new()
	name_label.text = title
	name_label.add_theme_color_override("font_color", COLOR_TEXT)
	header.add_child(name_label)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(spacer)
	var value_label := Label.new()
	value_label.name = "Value"
	value_label.add_theme_color_override("font_color", COLOR_MUTED)
	header.add_child(value_label)
	container.add_child(header)

	var bar := ProgressBar.new()
	bar.min_value = 0.0
	bar.max_value = 100.0
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(0, 14)
	bar.add_theme_stylebox_override("background", _bar_style(Color("09101e"), 7))
	bar.add_theme_stylebox_override("fill", _bar_style(color, 7))
	container.add_child(bar)
	needs_bars[key] = {"bar": bar, "label": value_label}
	status_grid.add_child(container)

func _add_action_button(parent: Control, key: String, text: String, accent: Color, callback: Callable) -> void:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(126, 54)
	button.add_theme_font_size_override("font_size", 15)
	button.add_theme_color_override("font_color", COLOR_TEXT)
	button.add_theme_stylebox_override("normal", _panel_style(COLOR_PANEL_ALT, accent, 14))
	button.add_theme_stylebox_override("hover", _panel_style(Color("1e2a44"), accent, 14))
	button.add_theme_stylebox_override("pressed", _panel_style(Color(accent, 0.28), accent, 14))
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

func _on_avatar_pressed() -> void:
	_run_interaction(
		"check_in",
		{"happiness": 2.0, "curiosity": 1.0, "quest_event": "needs_checked"},
		3,
		["bond", "check_in"],
		"Ich bin da. Was möchtest du heute gemeinsam tun?"
	)

func _on_care_pressed() -> void:
	_run_interaction(
		"care",
		{"hunger": 14.0, "happiness": 8.0, "health": 2.0, "quest_event": "care_action_completed"},
		15,
		["care", "bond"],
		"Das tut gut. Ich merke mir, wie aufmerksam du bist."
	)

func _on_play_pressed() -> void:
	_run_interaction(
		"play",
		{"energy": -8.0, "happiness": 16.0, "curiosity": 4.0, "quest_event": "play_action_completed"},
		18,
		["play", "fun"],
		"Zim-zim! Beim nächsten Mal erfinde ich eine neue Regel."
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
		{"energy": 20.0, "happiness": 3.0},
		5,
		["rest", "wellbeing"],
		"Eine Pause ist kein Stillstand. Ich sortiere gerade unsere Erinnerungen."
	)

func _run_interaction(
	interaction_id: String,
	effects: Dictionary,
	xp_reward: int,
	tags: Array[String],
	response: String
) -> void:
	_game_state().perform_interaction(interaction_id, effects, xp_reward, tags)
	message_label.text = response
	_play_avatar_reaction()
	_refresh_all()

func _refresh_all() -> void:
	var state := _game_state()
	var summary: Dictionary = state.get_state_summary()
	level_label.text = "LEVEL %d • %d/%d XP" % [state.level, state.xp, state.XP_PER_LEVEL]
	var streak := _streak_service()
	streak_label.text = "%d TAG%s" % [streak.current_streak, "E" if streak.current_streak != 1 else ""]
	mood_label.text = "STIMMUNG: %s" % _localized_mood(str(summary.get("mood", "NEUTRAL")))
	intention_label.text = "Aktueller Impuls: %s" % _localized_intention(_companion_brain().current_intention)
	message_label.text = _companion_brain().get_greeting() if message_label.text.is_empty() else message_label.text

	for key in needs_bars.keys():
		var value := float(summary.get(key, 0.0))
		var controls: Dictionary = needs_bars[key]
		(controls.bar as ProgressBar).value = value
		(controls.label as Label).text = "%d%%" % int(round(value))

	var brain := _companion_brain()
	relationship_label.text = "%s • Vertrauen %d%%" % [
		_relationship_name(brain.relationship_score),
		int(round(brain.trust))
	]
	quest_label.text = _quest_summary()

func _quest_summary() -> String:
	var quests: Array = _quest_service().active_quests
	if quests.is_empty():
		return "Heute gibt es keinen Pflichttermin. Entdecke frei, was dir guttut."
	for quest in quests:
		if not bool(quest.get("completed", false)):
			return "%s  •  %d/%d  •  +%d XP" % [
			str(quest.get("title", "Entdecken")),
			int(quest.get("progress", 0)),
			int(quest.get("target", 1)),
			int(quest.get("xp", 0))
			]
	return "Alle Tagesimpulse erfüllt. Alles Weitere ist heute freiwillig."

func _apply_responsive_layout() -> void:
	var size := get_viewport().get_visible_rect().size
	var compact := size.x < 780.0
	main_grid.columns = 1 if compact else 2
	status_grid.columns = 1 if size.x < 1050.0 else 2
	var base_margin := 16 if compact else 24
	var top_safe := 0
	var bottom_safe := 0
	var left_safe := 0
	var right_safe := 0
	if OS.get_name() == "iOS":
		var safe_rect := DisplayServer.get_display_safe_area()
		top_safe = maxi(safe_rect.position.y, 0)
		left_safe = maxi(safe_rect.position.x, 0)
		bottom_safe = maxi(int(size.y) - safe_rect.end.y, 0)
		right_safe = maxi(int(size.x) - safe_rect.end.x, 0)
	safe_margin.add_theme_constant_override("margin_top", base_margin + top_safe)
	safe_margin.add_theme_constant_override("margin_bottom", base_margin + bottom_safe)
	safe_margin.add_theme_constant_override("margin_left", base_margin + left_safe)
	safe_margin.add_theme_constant_override("margin_right", base_margin + right_safe)
	avatar_button.custom_minimum_size.y = 230.0 if compact else 360.0
	call_deferred("_center_avatar_pivot")

func _start_idle_animation() -> void:
	if bool(_game_state().settings.get("reduce_motion", false)):
		return
	if _idle_tween and _idle_tween.is_valid():
		_idle_tween.kill()
	_idle_tween = create_tween().set_loops()
	_idle_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_idle_tween.tween_property(avatar_button, "scale", Vector2(1.018, 1.018), 1.8)
	_idle_tween.tween_property(avatar_button, "scale", Vector2(0.99, 0.99), 1.8)

func _play_avatar_reaction() -> void:
	if bool(_game_state().settings.get("reduce_motion", false)):
		return
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(avatar_button, "scale", Vector2(1.08, 0.94), 0.10)
	tween.tween_property(avatar_button, "scale", Vector2.ONE, 0.28)

func _center_avatar_pivot() -> void:
	if avatar_button:
		avatar_button.pivot_offset = avatar_button.size * 0.5

func _on_state_changed(_key: String, _value: Variant) -> void:
	_refresh_all()

func _on_level_up(new_level: int) -> void:
	message_label.text = "Level %d. Ich kann spüren, dass neue Möglichkeiten entstehen." % new_level
	_play_avatar_reaction()

func _on_mood_changed(_new_mood: int) -> void:
	_refresh_all()

func _on_relationship_changed(_old_value: float, _new_value: float) -> void:
	_refresh_all()

func _on_intention_changed(intention: String) -> void:
	intention_label.text = "Aktueller Impuls: %s" % _localized_intention(intention)

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
	return str(names.get(value, value))

func _localized_intention(value: String) -> String:
	var names := {
		"observe": "beobachten",
		"play": "spielen",
		"discover": "etwas entdecken",
		"organize": "Gedanken ordnen",
		"create": "etwas erschaffen",
		"rest": "ruhen"
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

func _chip_label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_color_override("font_color", COLOR_ACCENT)
	label.add_theme_font_size_override("font_size", 14)
	return label

func _panel_style(background: Color, border: Color, radius: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(radius)
	style.content_margin_left = 16.0
	style.content_margin_right = 16.0
	style.content_margin_top = 14.0
	style.content_margin_bottom = 14.0
	return style

func _avatar_style(background: Color, border: Color) -> StyleBoxFlat:
	var style := _panel_style(background, border, 36)
	style.set_border_width_all(2)
	style.content_margin_top = 24.0
	style.content_margin_bottom = 24.0
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
