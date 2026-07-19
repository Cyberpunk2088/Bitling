extends "res://scripts/ui/learning_adventure_overlay.gd"

func _connect_service() -> void:
	super._connect_service()
	var service: Node = get_node_or_null("/root/LearningAdventures")
	if service == null or not service.has_signal("session_started"):
		return
	var callback: Callable = Callable(self, "_on_session_started")
	if not service.is_connected("session_started", callback):
		service.connect("session_started", callback)

func _on_session_started(session: Dictionary) -> void:
	if not is_open():
		return
	_catalog_scroll.visible = false
	_session_panel.visible = true
	_approach_row.visible = true
	_title.text = str(session.get("title", "Lernabenteuer"))
	_selected_approach = "observe"
	_update_approach_buttons()
	_show_challenge(session.get("challenge", {}) as Dictionary, session)
