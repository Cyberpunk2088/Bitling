extends "res://scripts/ui/learning_adventure_overlay_v2.gd"

## Mobile readability pass for Wave 5. Keeps the existing gameplay flow while
## enforcing legible typography and touch feedback on narrow phone viewports.

var _mobile_approach_grid: GridContainer

func get_mobile_readability_snapshot() -> Dictionary:
	var width: float = _responsive_width()
	var phone_layout: bool = width < 520.0
	var approach_columns: int = _mobile_approach_grid.columns if _mobile_approach_grid != null and _mobile_approach_grid.get_parent() != null else maxi(_approach_buttons.size(), 1)
	var approach_min_width: float = INF
	var approach_min_height: float = INF
	var approach_min_font: int = 999
	for button_variant: Variant in _approach_buttons.values():
		var approach_button: Button = button_variant as Button
		approach_min_width = minf(approach_min_width, maxf(approach_button.size.x, _estimated_approach_width(width, approach_columns)))
		approach_min_height = minf(approach_min_height, maxf(approach_button.size.y, approach_button.custom_minimum_size.y))
		approach_min_font = mini(approach_min_font, approach_button.get_theme_font_size("font_size"))
	var answer_min_height: float = INF
	var answer_min_font: int = 999
	for answer_button: Button in _answer_buttons:
		if not is_instance_valid(answer_button):
			continue
		answer_min_height = minf(answer_min_height, maxf(answer_button.size.y, answer_button.custom_minimum_size.y))
		answer_min_font = mini(answer_min_font, answer_button.get_theme_font_size("font_size"))
	var completion_button: Button = null
	if _answer_box != null and _answer_box.get_child_count() == 1:
		completion_button = _answer_box.get_child(0) as Button
	return {
		"phone_layout": phone_layout,
		"catalog_columns": _catalog_grid.columns if _catalog_grid != null else 0,
		"approach_columns": approach_columns,
		"approach_grid_children": _mobile_approach_grid.get_child_count() if _mobile_approach_grid != null and _mobile_approach_grid.get_parent() != null else 0,
		"approach_row_children": _approach_row.get_child_count() if _approach_row != null else 0,
		"approach_min_width": 0.0 if is_inf(approach_min_width) else approach_min_width,
		"approach_min_height": 0.0 if is_inf(approach_min_height) else approach_min_height,
		"approach_min_font": 0 if approach_min_font == 999 else approach_min_font,
		"answer_min_height": 0.0 if is_inf(answer_min_height) else answer_min_height,
		"answer_min_font": 0 if answer_min_font == 999 else answer_min_font,
		"title_font": _title.get_theme_font_size("font_size"),
		"summary_font": _summary.get_theme_font_size("font_size"),
		"progress_font": _progress.get_theme_font_size("font_size"),
		"prompt_font": _prompt.get_theme_font_size("font_size"),
		"feedback_font": _feedback.get_theme_font_size("font_size"),
		"mastery_height": maxf(_mastery.size.y, _mastery.custom_minimum_size.y),
		"close_button_height": maxf(_close_button.size.y, _close_button.custom_minimum_size.y),
		"completion_visible": completion_button != null and completion_button.text.find("WEITERE") >= 0,
		"continue_button_height": maxf(completion_button.size.y, completion_button.custom_minimum_size.y) if completion_button != null else 0.0,
		"reduced_motion": _reduce_motion_enabled()
	}

func _apply_responsive_layout() -> void:
	super._apply_responsive_layout()
	if _catalog_grid == null:
		return
	var width: float = _responsive_width()
	var phone_layout: bool = width < 520.0
	_set_mobile_approach_layout(phone_layout)
	if phone_layout:
		_title.add_theme_font_size_override("font_size", 22)
		_summary.add_theme_font_size_override("font_size", 13)
		_progress.add_theme_font_size_override("font_size", 13)
		_prompt.add_theme_font_size_override("font_size", 21)
		_feedback.add_theme_font_size_override("font_size", 14)
		_mastery.custom_minimum_size = Vector2(0, 28)
		for approach_id_variant: Variant in _approach_buttons.keys():
			var approach_id: String = str(approach_id_variant)
			var approach_button: Button = _approach_buttons[approach_id]
			approach_button.text = _approach_label(approach_id, true)
			approach_button.add_theme_font_size_override("font_size", 12)
			approach_button.custom_minimum_size = Vector2(0, 50)
		for answer_button: Button in _answer_buttons:
			answer_button.add_theme_font_size_override("font_size", 17)
			answer_button.custom_minimum_size = Vector2(0, 62)
	else:
		_title.add_theme_font_size_override("font_size", 25)
		_summary.add_theme_font_size_override("font_size", 12)
		_progress.add_theme_font_size_override("font_size", 12)
		_prompt.add_theme_font_size_override("font_size", 23)
		_feedback.add_theme_font_size_override("font_size", 13)
		_mastery.custom_minimum_size = Vector2(0, 24)
		for approach_id_variant: Variant in _approach_buttons.keys():
			var approach_id: String = str(approach_id_variant)
			var approach_button: Button = _approach_buttons[approach_id]
			approach_button.text = _approach_label(approach_id, false)
			approach_button.add_theme_font_size_override("font_size", 13)
			approach_button.custom_minimum_size = Vector2(0, 48)

func _show_challenge(challenge: Dictionary, session: Dictionary = {}) -> void:
	super._show_challenge(challenge, session)
	_apply_responsive_layout()

func _show_completion(result: Dictionary) -> void:
	super._show_completion(result)
	_answer_buttons.clear()
	_apply_responsive_layout()
	if _answer_box != null and _answer_box.get_child_count() == 1:
		var continue_button: Button = _answer_box.get_child(0) as Button
		if continue_button != null:
			continue_button.add_theme_font_size_override("font_size", 17)
			continue_button.custom_minimum_size = Vector2(0, 62)

func _on_session_completed(result: Dictionary) -> void:
	if is_open() and _session_panel != null and _session_panel.visible:
		if _has_internal_answer_submission():
			return
		_show_completion(result)
	elif _approach_row != null:
		_approach_row.visible = true

func _set_mobile_approach_layout(enabled: bool) -> void:
	if _approach_row == null:
		return
	if enabled:
		if _mobile_approach_grid == null:
			_mobile_approach_grid = GridContainer.new()
			_mobile_approach_grid.name = "LearningAdventureApproachGrid"
			_mobile_approach_grid.columns = 2
			_mobile_approach_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			_mobile_approach_grid.add_theme_constant_override("h_separation", 8)
			_mobile_approach_grid.add_theme_constant_override("v_separation", 8)
		if _mobile_approach_grid.get_parent() == null:
			_approach_row.add_child(_mobile_approach_grid)
		_mobile_approach_grid.columns = 2
		for approach_id: String in ["observe", "compare", "experiment", "explain"]:
			var button: Button = _approach_buttons.get(approach_id, null) as Button
			if button != null and button.get_parent() != _mobile_approach_grid:
				button.reparent(_mobile_approach_grid)
	else:
		for approach_id: String in ["observe", "compare", "experiment", "explain"]:
			var button: Button = _approach_buttons.get(approach_id, null) as Button
			if button != null and button.get_parent() != _approach_row:
				button.reparent(_approach_row)
		if _mobile_approach_grid != null and _mobile_approach_grid.get_parent() == _approach_row:
			_approach_row.remove_child(_mobile_approach_grid)

func _responsive_width() -> float:
	var design_width: float = get_viewport().get_visible_rect().size.x
	var physical_width: float = float(get_tree().root.size.x)
	return minf(design_width, physical_width) if physical_width > 0.0 else design_width

func _estimated_approach_width(width: float, columns: int) -> float:
	var resolved_columns: int = maxi(columns, 1)
	var available: float = maxf(width - 70.0, 0.0)
	return available / float(resolved_columns)

func _has_internal_answer_submission() -> bool:
	for answer_button: Button in _answer_buttons:
		if is_instance_valid(answer_button) and answer_button.disabled:
			return true
	return false

func _approach_label(approach_id: String, compact: bool) -> String:
	if compact:
		return {
			"observe": "SEHEN",
			"compare": "VERGLEICH",
			"experiment": "TESTEN",
			"explain": "ERKLÄREN"
		}.get(approach_id, approach_id.to_upper())
	return {
		"observe": "BEOBACHTEN",
		"compare": "VERGLEICHEN",
		"experiment": "AUSPROBIEREN",
		"explain": "ERKLÄREN"
	}.get(approach_id, approach_id.to_upper())
