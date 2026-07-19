extends "res://scripts/ui/partner_world_overlay.gd"

## Runtime guard and physical-window responsive refinement.
## Godot keeps a 720px design viewport on phones, so the real root width is also
## considered to prevent dense two-column cards on 390px-class devices.

func _on_forecast_updated(forecast: Array[Dictionary]) -> void:
	if not backdrop.visible:
		return
	_rebuild_evolution_cards(forecast)
	_apply_responsive_layout()

func _apply_responsive_layout() -> void:
	if summary_grid == null:
		return
	var design_width := get_viewport().get_visible_rect().size.x
	var physical_width := float(get_tree().root.size.x)
	var width := minf(design_width, physical_width) if physical_width > 0.0 else design_width
	var compact := width < 600.0
	var medium := width < 1120.0

	summary_grid.columns = 1 if compact else 2 if medium else 4
	evolution_grid.columns = 1 if compact else 2 if medium else 3
	technique_grid.columns = 1 if compact else 2 if medium else 3
	settlement_grid.columns = 1 if compact else 2 if medium else 3

	var font_factor := 1.28 if compact else 1.08 if medium else 1.10
	_scale_typography(font_factor)
	_scale_cards(compact, medium)
	shell.pivot_offset = shell.size * 0.5

func _scale_typography(factor: float) -> void:
	for candidate in shell.find_children("*", "Label", true, false):
		if not candidate is Label:
			continue
		var label := candidate as Label
		if not label.has_meta("partner_base_font_size"):
			label.set_meta("partner_base_font_size", label.get_theme_font_size("font_size"))
		var base_size := int(label.get_meta("partner_base_font_size"))
		label.add_theme_font_size_override("font_size", maxi(10, int(round(float(base_size) * factor))))
	for candidate in shell.find_children("*", "Button", true, false):
		if not candidate is Button:
			continue
		var button := candidate as Button
		if not button.has_meta("partner_base_font_size"):
			button.set_meta("partner_base_font_size", button.get_theme_font_size("font_size"))
		var base_size := int(button.get_meta("partner_base_font_size"))
		button.add_theme_font_size_override("font_size", maxi(11, int(round(float(base_size) * factor))))

func _scale_cards(compact: bool, medium: bool) -> void:
	for candidate in evolution_grid.get_children():
		if candidate is Control:
			(candidate as Control).custom_minimum_size.y = 250.0 if compact else 220.0 if medium else 214.0
	for candidate in technique_grid.get_children():
		if candidate is Control:
			(candidate as Control).custom_minimum_size.y = 112.0 if compact else 98.0
	for candidate in settlement_grid.get_children():
		if candidate is Control:
			(candidate as Control).custom_minimum_size.y = 102.0 if compact else 86.0
