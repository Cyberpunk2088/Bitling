extends CanvasLayer

## Compact responsive control surface for the Living Home.

var _panel: PanelContainer
var _title: Label
var _summary: Label
var _routine: Label
var _button: Button
var _object_buttons: Dictionary = {}

func _ready() -> void:
	layer = 44
	_build_ui()
	_connect_service()
	_refresh()

func _build_ui() -> void:
	_button = Button.new()
	_button.name = "LivingHomeLauncher"
	_button.text = "RAUM"
	_button.tooltip_text = "Deine lebendige Heimat gestalten"
	_button.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_button.position = Vector2(18, 338)
	_button.custom_minimum_size = Vector2(104, 48)
	_button.pressed.connect(_toggle)
	add_child(_button)

	_panel = PanelContainer.new()
	_panel.name = "LivingHomePanel"
	_panel.visible = false
	_panel.set_anchors_preset(Control.PRESET_CENTER)
	_panel.offset_left = -310
	_panel.offset_top = -330
	_panel.offset_right = 310
	_panel.offset_bottom = 330
	add_child(_panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_top", 22)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_bottom", 22)
	_panel.add_child(margin)
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 14)
	margin.add_child(root)

	var header := HBoxContainer.new()
	root.add_child(header)
	_title = Label.new()
	_title.text = "LIVING HOME"
	_title.add_theme_font_size_override("font_size", 26)
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(_title)
	var close := Button.new()
	close.text = "×"
	close.custom_minimum_size = Vector2(48, 44)
	close.pressed.connect(_close)
	header.add_child(close)

	_summary = Label.new()
	_summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_summary.add_theme_font_size_override("font_size", 18)
	root.add_child(_summary)
	_routine = Label.new()
	_routine.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_routine.add_theme_font_size_override("font_size", 17)
	root.add_child(_routine)

	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	root.add_child(grid)
	for object_id in ["window", "lamp", "plant", "shelf", "cushion"]:
		var button := Button.new()
		button.custom_minimum_size = Vector2(250, 76)
		button.text = object_id.capitalize()
		button.pressed.connect(_interact.bind(object_id))
		grid.add_child(button)
		_object_buttons[object_id] = button
	var tidy := Button.new()
	tidy.text = "RAUM ORDNEN"
	tidy.custom_minimum_size = Vector2(250, 76)
	tidy.pressed.connect(_tidy)
	grid.add_child(tidy)

func _connect_service() -> void:
	var service := get_node_or_null("/root/LivingHome")
	if service == null:
		return
	if service.has_signal("home_changed"):
		var callback := Callable(self, "_on_home_changed")
		if not service.is_connected("home_changed", callback):
			service.connect("home_changed", callback)

func _toggle() -> void:
	_panel.visible = not _panel.visible
	if _panel.visible:
		_refresh()

func _close() -> void:
	_panel.visible = false

func open_living_home() -> void:
	_panel.visible = true
	_refresh()

func close_living_home() -> void:
	_close()

func is_open() -> bool:
	return _panel != null and _panel.visible

func get_layout_snapshot() -> Dictionary:
	return {
		"visible": is_open(),
		"button_count": _object_buttons.size() + 1,
		"panel_size": _panel.size if _panel != null else Vector2.ZERO,
		"launcher_visible": _button != null and _button.visible
	}

func _interact(object_id: String) -> void:
	var service := get_node_or_null("/root/LivingHome")
	if service == null or not service.has_method("interact"):
		return
	var result: Dictionary = service.call("interact", object_id)
	if bool(result.get("accepted", false)):
		_summary.text = str(result.get("message", "Der Raum reagiert."))
	var audio := get_node_or_null("/root/OmniAudio")
	if audio != null and audio.has_method("play_action"):
		audio.call("play_action", "care" if object_id in ["plant", "cushion"] else "navigation", 0.8)
	_refresh_buttons()

func _tidy() -> void:
	var service := get_node_or_null("/root/LivingHome")
	if service != null and service.has_method("tidy_room"):
		service.call("tidy_room")
		_summary.text = "Der Raum fühlt sich wieder klar und bewohnbar an."

func _on_home_changed(_snapshot: Dictionary) -> void:
	_refresh()

func _refresh() -> void:
	var service := get_node_or_null("/root/LivingHome")
	if service == null or not service.has_method("get_snapshot"):
		return
	var snapshot: Dictionary = service.call("get_snapshot")
	_summary.text = "%s · %s · Komfort %d%% · Ordnung %d%%" % [
		str(snapshot.get("time_segment", "DAY")),
		str(snapshot.get("weather_label", "klar")),
		int(snapshot.get("comfort", 0.0)),
		int(snapshot.get("cleanliness", 0.0))
	]
	_routine.text = "Aktuelle Routine: %s" % str(snapshot.get("routine_label", "Freie Zeit"))
	_refresh_buttons()
	_apply_responsive_layout()

func _refresh_buttons() -> void:
	var service := get_node_or_null("/root/LivingHome")
	if service == null or not service.has_method("get_snapshot"):
		return
	var objects: Dictionary = (service.call("get_snapshot") as Dictionary).get("objects", {})
	for object_id_variant in _object_buttons.keys():
		var object_id := str(object_id_variant)
		var data: Dictionary = objects.get(object_id, {})
		(_object_buttons[object_id] as Button).text = "%s\n%s" % [str(data.get("label", object_id.capitalize())), str(data.get("action", "Interagieren"))]

func _apply_responsive_layout() -> void:
	var viewport_size := get_viewport().get_visible_rect().size
	if viewport_size.x < 620.0:
		_panel.offset_left = -viewport_size.x * 0.46
		_panel.offset_right = viewport_size.x * 0.46
		_panel.offset_top = -viewport_size.y * 0.40
		_panel.offset_bottom = viewport_size.y * 0.40
		var grid := _panel.find_child("GridContainer", true, false) as GridContainer
		if grid != null:
			grid.columns = 1
		for button_variant in _object_buttons.values():
			(button_variant as Button).custom_minimum_size = Vector2(0, 64)
