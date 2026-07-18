extends Node

## Small platform abstraction used by UI and optional services.

signal safe_area_changed(safe_area: Rect2i)

var _last_safe_area := Rect2i()

func _ready() -> void:
	_last_safe_area = get_safe_area()
	get_tree().root.size_changed.connect(_on_viewport_size_changed)

func is_mobile() -> bool:
	return OS.has_feature("mobile") or OS.has_feature("android") or OS.has_feature("ios")

func is_web() -> bool:
	return OS.has_feature("web")

func is_desktop() -> bool:
	return not is_mobile() and not is_web()

func supports_touch() -> bool:
	return DisplayServer.is_touchscreen_available()

func platform_name() -> String:
	return OS.get_name()

func get_safe_area() -> Rect2i:
	if is_mobile():
		return DisplayServer.get_display_safe_area()
	return Rect2i(Vector2i.ZERO, get_tree().root.size)

func get_layout_class() -> StringName:
	var viewport_size := get_tree().root.size
	var shortest_side := mini(viewport_size.x, viewport_size.y)
	if shortest_side < 600:
		return &"compact"
	if shortest_side < 960:
		return &"medium"
	return &"expanded"

func _on_viewport_size_changed() -> void:
	var safe_area := get_safe_area()
	if safe_area != _last_safe_area:
		_last_safe_area = safe_area
		safe_area_changed.emit(safe_area)
