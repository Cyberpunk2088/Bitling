extends "res://scripts/ui/learning_adventure_overlay_v2.gd"

## Mobile readability pass for Wave 5. Keeps the existing gameplay flow while
## enforcing legible typography and touch feedback on narrow phone viewports.

func _apply_responsive_layout() -> void:
	super._apply_responsive_layout()
	if _catalog_grid == null:
		return
	var design_width: float = get_viewport().get_visible_rect().size.x
	var physical_width: float = float(get_tree().root.size.x)
	var width: float = minf(design_width, physical_width) if physical_width > 0.0 else design_width
	var phone_layout: bool = width < 520.0
	if phone_layout:
		_title.add_theme_font_size_override("font_size", 22)
		_summary.add_theme_font_size_override("font_size", 12)
		_progress.add_theme_font_size_override("font_size", 13)
		_prompt.add_theme_font_size_override("font_size", 21)
		_feedback.add_theme_font_size_override("font_size", 14)
		_mastery.custom_minimum_size = Vector2(0, 28)
		for button_variant: Variant in _approach_buttons.values():
			var approach_button: Button = button_variant as Button
			approach_button.add_theme_font_size_override("font_size", 10)
			approach_button.custom_minimum_size = Vector2(0, 50)
		for answer_button: Button in _answer_buttons:
			answer_button.add_theme_font_size_override("font_size", 17)
			answer_button.custom_minimum_size = Vector2(0, 62)
	else:
		_title.add_theme_font_size_override("font_size", 25)
		_summary.add_theme_font_size_override("font_size", 11)
		_progress.add_theme_font_size_override("font_size", 12)
		_feedback.add_theme_font_size_override("font_size", 13)
		_mastery.custom_minimum_size = Vector2(0, 24)

func _show_challenge(challenge: Dictionary, session: Dictionary = {}) -> void:
	super._show_challenge(challenge, session)
	_apply_responsive_layout()
