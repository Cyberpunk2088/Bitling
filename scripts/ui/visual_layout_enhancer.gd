extends Node

var _dashboard: Node
var _page: VBoxContainer
var _scroll: ScrollContainer
var _stage: Control
var _left_panel: Control
var _center_panel: Control
var _right_panel: Control

func _ready() -> void:
	call_deferred("_bind_dashboard")

func _bind_dashboard() -> void:
	_dashboard = get_parent()
	if _dashboard == null:
		return
	_page = _dashboard.get("page") as VBoxContainer
	_scroll = _dashboard.get("scroll") as ScrollContainer
	_stage = _dashboard.get("stage") as Control
	_left_panel = _dashboard.get("left_panel") as Control
	_center_panel = _dashboard.get("center_panel") as Control
	_right_panel = _dashboard.get("right_panel") as Control
	if not get_viewport().size_changed.is_connected(_apply):
		get_viewport().size_changed.connect(_apply)
	_apply()

func _apply() -> void:
	var viewport_size := get_viewport().get_visible_rect().size
	if _page != null:
		_page.custom_minimum_size.y = maxf(0.0, viewport_size.y - 36.0)
	if _scroll != null:
		var scrollbar := _scroll.get_v_scroll_bar()
		if scrollbar != null:
			scrollbar.modulate = Color(1.0, 1.0, 1.0, 0.08)
			scrollbar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if _stage == null:
		return
	if viewport_size.x >= 1180.0:
		_stage.custom_minimum_size.y = maxf(620.0, viewport_size.y - 290.0)
		_set_panel_minimum_height(maxf(620.0, viewport_size.y - 210.0))
	elif viewport_size.x >= 900.0:
		_stage.custom_minimum_size.y = 500.0
		_set_panel_minimum_height(0.0)
	else:
		_stage.custom_minimum_size.y = 390.0
		_set_panel_minimum_height(0.0)

func _set_panel_minimum_height(value: float) -> void:
	for panel in [_left_panel, _center_panel, _right_panel]:
		if panel != null:
			panel.custom_minimum_size.y = value
