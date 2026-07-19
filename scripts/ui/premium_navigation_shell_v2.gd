extends "res://scripts/ui/premium_navigation_shell.gd"

## Routes the STATUS destination into the dedicated partner-world experience.

func _on_page_pressed(page_name: String) -> void:
	if page_name != "STATUS":
		super._on_page_pressed(page_name)
		return
	var audio := get_node_or_null("/root/OmniAudio")
	if audio != null and audio.has_method("play_navigation"):
		audio.call("play_navigation")
	_active_page = page_name
	_update_button_states()
	var overlay := get_node_or_null("/root/PartnerWorldOverlay")
	if overlay != null and overlay.has_method("open_partner_world"):
		overlay.call("open_partner_world")
