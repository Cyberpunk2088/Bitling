extends "res://scripts/ui/premium_navigation_shell_v3.gd"

## Wave 4 navigation replaces the passive missions destination with a direct,
## playable Partner World entry while preserving Home, Status, Social and Profile.

func _build_navigation() -> PanelContainer:
	var panel := PanelContainer.new()
	panel.name = "PremiumMobileNavigation"
	panel.add_theme_stylebox_override("panel", _panel_style(COLOR_PANEL, Color(COLOR_CYAN, 0.34), 22, 1))
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 4)
	panel.add_child(row)
	_add_nav_button(row, "HOME", "bitling", COLOR_CYAN)
	_add_nav_button(row, "STATUS", "care", COLOR_GREEN)
	_add_nav_button(row, "WELT", "spark", COLOR_VIOLET)
	_add_nav_button(row, "SOZIAL", "play", COLOR_MAGENTA)
	_add_nav_button(row, "MEHR", "learn", Color("ffc85a"))
	return panel

func _on_page_pressed(page_name: String) -> void:
	if page_name != "WELT":
		super._on_page_pressed(page_name)
		return
	var audio := get_node_or_null("/root/OmniAudio")
	if audio != null and audio.has_method("play_navigation"):
		audio.call("play_navigation")
	_active_page = "WELT"
	_apply_compact_page()
	_update_button_states()
	var overlay := get_node_or_null("/root/SignalSettlementOverlay")
	if overlay != null and overlay.has_method("open_world"):
		overlay.call("open_world")
