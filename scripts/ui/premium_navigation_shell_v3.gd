extends "res://scripts/ui/premium_navigation_shell_v2.gd"

## Wave 3 navigation: HOME becomes a world destination that opens the Living
## Home interaction layer while preserving all existing compact page behavior.

func _on_page_pressed(page_name: String) -> void:
	if page_name != "HOME":
		super._on_page_pressed(page_name)
		return
	var audio := get_node_or_null("/root/OmniAudio")
	if audio != null and audio.has_method("play_navigation"):
		audio.call("play_navigation")
	_active_page = "HOME"
	_apply_compact_page()
	_update_button_states()
	var overlay := get_node_or_null("/root/LivingHomeOverlay")
	if overlay != null and overlay.has_method("open_home"):
		overlay.call("open_home")
