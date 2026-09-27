extends Control

## Licenses from the running engine, available offline in every exported build.
## This attributes dependencies; it does not set a license for BITLING itself.

var _panel: PanelContainer
var _text: RichTextLabel
var _close_button: Button
var _previous_focus: WeakRef

func _ready() -> void:
	name = "OpenSourceLicenseDialog"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var shade := ColorRect.new()
	shade.color = Color(0.01, 0.02, 0.05, 0.97)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	_panel = PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color("10182a")
	style.border_color = Color("6de7ff")
	style.set_border_width_all(1)
	style.set_corner_radius_all(18)
	style.set_content_margin_all(16)
	_panel.add_theme_stylebox_override("panel", style)
	center.add_child(_panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	_panel.add_child(column)
	var header := HBoxContainer.new()
	column.add_child(header)
	var title := Label.new()
	title.text = "OPEN-SOURCE-LIZENZEN"
	title.add_theme_font_size_override("font_size", 16)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	_close_button = Button.new()
	_close_button.name = "LicenseClose"
	_close_button.text = "×"
	_close_button.tooltip_text = "Lizenzen schließen"
	_close_button.custom_minimum_size = Vector2(48, 48)
	_close_button.pressed.connect(close_licenses)
	header.add_child(_close_button)
	_text = RichTextLabel.new()
	_text.name = "LicenseText"
	_text.bbcode_enabled = false
	_text.selection_enabled = true
	_text.focus_mode = Control.FOCUS_ALL
	_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_text.add_theme_color_override("default_color", Color("f4f7ff"))
	_text.add_theme_font_size_override("normal_font_size", 16)
	_text.text = _license_document()
	column.add_child(_text)
	get_viewport().size_changed.connect(_apply_layout)
	get_viewport().gui_focus_changed.connect(_on_focus_changed)
	_apply_layout()
	hide()

func open_licenses() -> void:
	if visible:
		return
	var focused := get_viewport().gui_get_focus_owner()
	_previous_focus = weakref(focused) if focused != null else null
	show()
	_apply_layout()
	_close_button.grab_focus()

func close_licenses() -> void:
	if not visible:
		return
	hide()
	var previous := _previous_focus.get_ref() as Control if _previous_focus != null else null
	_previous_focus = null
	if previous != null and previous.is_visible_in_tree() and previous.focus_mode != Control.FOCUS_NONE:
		previous.grab_focus()

func _input(event: InputEvent) -> void:
	if not is_visible_in_tree() or not (event is InputEventKey or event is InputEventAction):
		return
	get_viewport().set_input_as_handled()
	if event.is_action_pressed("ui_cancel"):
		close_licenses()
	elif event.is_action_pressed("ui_focus_next") or event.is_action_pressed("ui_focus_prev"):
		if get_viewport().gui_get_focus_owner() == _close_button:
			_text.grab_focus()
		else:
			_close_button.grab_focus()
	elif event.is_action_pressed("ui_accept"):
		if get_viewport().gui_get_focus_owner() == _close_button:
			close_licenses()
	elif event.is_action_pressed("ui_down"):
		_text.get_v_scroll_bar().value += 48
	elif event.is_action_pressed("ui_up"):
		_text.get_v_scroll_bar().value -= 48
	elif event.is_action_pressed("ui_page_down"):
		_text.get_v_scroll_bar().value += _text.size.y * 0.8
	elif event.is_action_pressed("ui_page_up"):
		_text.get_v_scroll_bar().value -= _text.size.y * 0.8

func _on_focus_changed(control: Control) -> void:
	if is_visible_in_tree() and control != null and not is_ancestor_of(control):
		call_deferred("_restore_modal_focus")

func _restore_modal_focus() -> void:
	if is_visible_in_tree():
		_close_button.grab_focus()

func _apply_layout() -> void:
	var viewport_size := get_viewport().get_visible_rect().size
	_panel.custom_minimum_size = Vector2(minf(700.0, maxf(280.0, viewport_size.x - 24.0)), minf(800.0, maxf(180.0, viewport_size.y - 24.0)))

func _license_document() -> String:
	var lines: Array[String] = [
		"BITLING nutzt Godot Engine. Die folgenden Hinweise stammen direkt aus der verwendeten Engine und ihren eingebundenen Komponenten.",
		"GODOT ENGINE · " + str(Engine.get_version_info().get("string", "")),
		Engine.get_license_text(),
		"DRITTANBIETER · URHEBERRECHTE"
	]
	for component in Engine.get_copyright_info():
		lines.append("\n" + str(component.get("name", "")))
		for part in component.get("parts", []):
			for owner in part.get("copyright", []):
				lines.append(str(owner))
			lines.append("Lizenz: " + str(part.get("license", "")))
			for file in part.get("files", []):
				lines.append("  " + str(file))
	lines.append("\nDRITTANBIETER · LIZENZTEXTE")
	var licenses := Engine.get_license_info()
	var names := licenses.keys()
	names.sort()
	for license_name in names:
		lines.append("\n" + str(license_name))
		lines.append(str(licenses[license_name]))
	return "\n\n".join(lines)
