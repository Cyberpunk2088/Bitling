extends CanvasLayer

## A failed save must never look like a successful, durable session.
## The blocking state is deliberately exit-only; recovery is not a new game.
var notice: PanelContainer
var description: Label
var blocker: ColorRect
var exit_button: Button

func _ready() -> void:
	name = "StorageStatusOverlay"
	layer = 300
	process_mode = Node.PROCESS_MODE_ALWAYS
	blocker = ColorRect.new()
	blocker.color = Color("080e20")
	blocker.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(blocker)
	notice = PanelContainer.new()
	notice.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	notice.offset_left = 20
	notice.offset_right = -20
	notice.offset_top = 20
	var style := StyleBoxFlat.new()
	style.bg_color = Color("242139")
	style.border_color = Color("ffc85a")
	style.set_border_width_all(2)
	style.set_content_margin_all(18)
	notice.add_theme_stylebox_override("panel", style)
	add_child(notice)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 20)
	notice.add_child(column)
	description = Label.new()
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description.add_theme_font_size_override("font_size", 24)
	description.add_theme_color_override("font_color", Color("f4f7ff"))
	column.add_child(description)
	exit_button = Button.new()
	exit_button.text = "Spiel schließen"
	exit_button.custom_minimum_size.y = 76
	exit_button.add_theme_font_size_override("font_size", 24)
	exit_button.pressed.connect(func() -> void: get_tree().quit())
	column.add_child(exit_button)
	EventBus.save_failed.connect(_on_save_failed)
	EventBus.save_completed.connect(_on_save_completed)
	refresh()

func refresh() -> void:
	var state := get_node("/root/GameState")
	var blocked := bool(state.get("save_blocked"))
	var status := str(state.get("storage_status"))
	blocker.visible = blocked
	exit_button.visible = blocked
	notice.visible = blocked or status in ["error", "recovered"]
	if blocked:
		description.text = "SPIELSTAND GESCHÜTZT\n\nDieser Spielstand lässt sich mit dieser Version nicht sicher öffnen. Das Spiel bleibt angehalten. Dein zentraler Spielstand wird nicht ersetzt.\n\n" + str(state.get("storage_message")) + "\n\nBitte sichere den gesamten Spielstandordner, bevor du eine Wiederherstellung oder eine andere Spielversion verwendest."
		var activities := get_node_or_null("/root/LegendaryActivities")
		if activities != null:
			activities.call("_close_overlay")
		# Autoloads such as LivingHome intentionally process during normal pauses.
		# This exit-only recovery screen must also stop their autosave timers.
		for service: Node in get_tree().root.get_children():
			if service != get_parent() and service.process_mode == Node.PROCESS_MODE_ALWAYS:
				service.process_mode = Node.PROCESS_MODE_DISABLED
		get_tree().paused = true
		exit_button.grab_focus()
	elif status == "recovered":
		description.text = "Spielstand wiederhergestellt. " + str(state.get("storage_message"))
	elif status == "error":
		description.text = "NICHT GESPEICHERT\nDein letzter Fortschritt ist noch nicht gesichert. " + str(state.get("storage_message"))

func _on_save_failed(_reason: String) -> void:
	refresh()

func _on_save_completed(_path: String) -> void:
	refresh()
