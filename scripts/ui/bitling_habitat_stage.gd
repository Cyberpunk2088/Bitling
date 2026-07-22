extends "res://scripts/ui/production_bitling_stage_3d_v11.gd"

## Production 3D stage with room-level agency. Clicks outside the companion are
## resolved as habitat context; clicks on Xogot retain the full character rig.

signal hotspot_pressed(hotspot_id: String)

const HabitatHotspotOverlay := preload("res://scripts/ui/habitat_hotspot_overlay.gd")
const HabitatWorldConsequenceOverlay := preload("res://scripts/ui/habitat_world_consequence_overlay.gd")

var focused_hotspot := "bitling"
var activity_lens := "care"
var moment_title := ""
var world_consequence_snapshot: Dictionary = {}
var _habitat_overlay: Control
var _world_consequence_overlay: Control

func _ready() -> void:
	super._ready()
	_habitat_overlay = HabitatHotspotOverlay.new()
	_habitat_overlay.name = "HabitatHotspotOverlay"
	add_child(_habitat_overlay)
	_world_consequence_overlay = HabitatWorldConsequenceOverlay.new()
	_world_consequence_overlay.name = "HabitatWorldConsequenceOverlay"
	add_child(_world_consequence_overlay)
	move_child(_habitat_overlay, get_child_count() - 1)
	move_child(_world_consequence_overlay, get_child_count() - 1)
	_sync_habitat_overlay()
	_sync_world_consequences()

func set_focused_hotspot(hotspot_id: String) -> void:
	focused_hotspot = hotspot_id
	if _habitat_overlay != null:
		_habitat_overlay.call("set_hotspot", hotspot_id)

func set_activity_lens(lens_id: String) -> void:
	activity_lens = lens_id
	if _habitat_overlay != null:
		_habitat_overlay.call("set_lens", lens_id)

func set_moment_title(value: String) -> void:
	moment_title = value
	if _habitat_overlay != null:
		_habitat_overlay.call("set_title", value)

func set_world_consequence_snapshot(value: Dictionary) -> void:
	world_consequence_snapshot = value.duplicate(true)
	_sync_world_consequences()

func get_habitat_interaction_snapshot() -> Dictionary:
	var world_visual: Dictionary = {}
	if _world_consequence_overlay != null and _world_consequence_overlay.has_method("get_visual_snapshot"):
		world_visual = _world_consequence_overlay.call("get_visual_snapshot") as Dictionary
	return {
		"habitat_capable": true,
		"focused_hotspot": focused_hotspot,
		"activity_lens": activity_lens,
		"moment_title": moment_title,
		"hotspot_count": 6,
		"overlay_ready": _habitat_overlay != null,
		"world_consequence_overlay_ready": _world_consequence_overlay != null,
		"world_consequence_visual": world_visual
	}

func _gui_input(event: InputEvent) -> void:
	var pressed := false
	var position := Vector2.ZERO
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		pressed = mouse_event.pressed and mouse_event.button_index == MOUSE_BUTTON_LEFT
		position = mouse_event.position
	elif event is InputEventScreenTouch:
		var touch_event := event as InputEventScreenTouch
		pressed = touch_event.pressed
		position = touch_event.position
	if pressed:
		var hotspot := _habitat_hotspot_at(position)
		if not hotspot.is_empty() and hotspot != "bitling":
			focused_hotspot = hotspot
			_sync_habitat_overlay()
			_request_touch_performance(position)
			hotspot_pressed.emit(hotspot)
			accept_event()
			return
	super._gui_input(event)

func _habitat_hotspot_at(position: Vector2) -> String:
	if size.x <= 1.0 or size.y <= 1.0:
		return ""
	var zones := {
		"bitling": Rect2(size.x * 0.29, size.y * 0.22, size.x * 0.42, size.y * 0.64),
		"window": Rect2(size.x * 0.24, size.y * 0.03, size.x * 0.52, size.y * 0.19),
		"workbench": Rect2(size.x * 0.70, size.y * 0.25, size.x * 0.29, size.y * 0.39),
		"plant": Rect2(size.x * 0.01, size.y * 0.24, size.x * 0.25, size.y * 0.45),
		"platform": Rect2(size.x * 0.64, size.y * 0.64, size.x * 0.35, size.y * 0.35),
		"sleep": Rect2(size.x * 0.01, size.y * 0.67, size.x * 0.34, size.y * 0.32)
	}
	for hotspot_variant in ["bitling", "window", "workbench", "plant", "platform", "sleep"]:
		var hotspot := str(hotspot_variant)
		if (zones[hotspot] as Rect2).has_point(position):
			return hotspot
	return ""

func _sync_habitat_overlay() -> void:
	if _habitat_overlay != null:
		_habitat_overlay.call("set_context", focused_hotspot, activity_lens, moment_title)

func _sync_world_consequences() -> void:
	if _world_consequence_overlay != null:
		_world_consequence_overlay.call("set_snapshot", world_consequence_snapshot)
