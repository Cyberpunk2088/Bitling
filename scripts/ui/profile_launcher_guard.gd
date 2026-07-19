extends Node

var _overlay: Node
var _launcher: Button
var _backdrop: ColorRect

func _ready() -> void:
	call_deferred("_bind_overlay")

func _bind_overlay() -> void:
	_overlay = get_node_or_null("/root/ProfileOverlay")
	if _overlay == null:
		return
	var launcher_variant: Variant = _overlay.get("launcher")
	var backdrop_variant: Variant = _overlay.get("backdrop")
	if launcher_variant is Button:
		_launcher = launcher_variant as Button
	if backdrop_variant is ColorRect:
		_backdrop = backdrop_variant as ColorRect
		if not _backdrop.visibility_changed.is_connected(_on_backdrop_visibility_changed):
			_backdrop.visibility_changed.connect(_on_backdrop_visibility_changed)
	_hide_launcher()

func _on_backdrop_visibility_changed() -> void:
	call_deferred("_hide_launcher")

func _hide_launcher() -> void:
	if _launcher == null:
		return
	_launcher.visible = false
	_launcher.disabled = true
	_launcher.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_launcher.position = Vector2(-10000.0, -10000.0)
