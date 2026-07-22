extends "res://scripts/ui/production_bitling_stage_3d_v11.gd"

## Production 3D stage with room-level agency. The stage owns all in-world
## hit-testing and Xogot root motion; overlays render state without intercepting
## input. Dashboard buttons are compatibility affordances, not the primary loop.

signal hotspot_pressed(hotspot_id: String)
signal live_action_choice_pressed(choice_id: String)

const HabitatHotspotOverlay := preload("res://scripts/ui/habitat_hotspot_overlay.gd")
const HabitatWorldConsequenceOverlay := preload("res://scripts/ui/habitat_world_consequence_overlay.gd")
const HabitatLiveActionOverlay := preload("res://scripts/ui/habitat_live_action_overlay.gd")
const LIVE_ACTION_WORLD_TARGETS := {
	"bitling": Vector3(0.0, -0.12, 0.20),
	"window": Vector3(0.0, -0.12, -1.55),
	"workbench": Vector3(2.45, -0.12, -0.30),
	"plant": Vector3(-2.85, -0.12, 0.10),
	"platform": Vector3(2.10, -0.12, 1.15),
	"sleep": Vector3(-2.35, -0.12, 0.78)
}
const LIVE_ACTION_YAWS := {
	"bitling": 0.0,
	"window": 0.0,
	"workbench": -0.38,
	"plant": 0.42,
	"platform": -0.28,
	"sleep": 0.32
}

var focused_hotspot := "bitling"
var activity_lens := "care"
var moment_title := ""
var world_consequence_snapshot: Dictionary = {}
var live_action_snapshot: Dictionary = {}
var _habitat_overlay: Control
var _world_consequence_overlay: Control
var _live_action_overlay: Control
var _live_position := Vector3(0.0, -0.12, 0.20)
var _live_target := Vector3(0.0, -0.12, 0.20)
var _live_yaw := 0.0
var _last_live_phase := "idle"

func _ready() -> void:
	super._ready()
	if _bitling != null:
		_live_position = _bitling.position
		_live_target = _live_position
	_habitat_overlay = HabitatHotspotOverlay.new()
	_habitat_overlay.name = "HabitatHotspotOverlay"
	add_child(_habitat_overlay)
	_world_consequence_overlay = HabitatWorldConsequenceOverlay.new()
	_world_consequence_overlay.name = "HabitatWorldConsequenceOverlay"
	add_child(_world_consequence_overlay)
	_live_action_overlay = HabitatLiveActionOverlay.new()
	_live_action_overlay.name = "HabitatLiveActionOverlay"
	add_child(_live_action_overlay)
	move_child(_habitat_overlay, get_child_count() - 1)
	move_child(_world_consequence_overlay, get_child_count() - 1)
	move_child(_live_action_overlay, get_child_count() - 1)
	_sync_habitat_overlay()
	_sync_world_consequences()
	_sync_live_action()

func _process(delta: float) -> void:
	super._process(delta)
	_apply_live_action_motion(maxf(delta, 0.0))

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

func set_live_action_snapshot(value: Dictionary) -> void:
	live_action_snapshot = value.duplicate(true)
	var phase := str(live_action_snapshot.get("phase", "idle"))
	if phase != _last_live_phase:
		_on_live_phase_entered(phase)
		_last_live_phase = phase
	_sync_live_action()

func activate_live_action_choice(index: int) -> bool:
	var choices: Array = live_action_snapshot.get("choices", []) as Array
	if str(live_action_snapshot.get("phase", "")) != "awaiting_choice" or index < 0 or index >= choices.size():
		return false
	var choice := choices[index] as Dictionary
	var choice_id := str(choice.get("id", ""))
	if choice_id.is_empty():
		return false
	live_action_choice_pressed.emit(choice_id)
	return true

func get_live_action_choice_regions() -> Array[Rect2]:
	if _live_action_overlay == null or not _live_action_overlay.has_method("get_choice_regions"):
		return []
	return _live_action_overlay.call("get_choice_regions") as Array[Rect2]

func get_habitat_interaction_snapshot() -> Dictionary:
	var world_visual: Dictionary = {}
	if _world_consequence_overlay != null and _world_consequence_overlay.has_method("get_visual_snapshot"):
		world_visual = _world_consequence_overlay.call("get_visual_snapshot") as Dictionary
	var live_visual: Dictionary = {}
	if _live_action_overlay != null and _live_action_overlay.has_method("get_visual_snapshot"):
		live_visual = _live_action_overlay.call("get_visual_snapshot") as Dictionary
	return {
		"habitat_capable": true,
		"focused_hotspot": focused_hotspot,
		"activity_lens": activity_lens,
		"moment_title": moment_title,
		"hotspot_count": 6,
		"overlay_ready": _habitat_overlay != null,
		"world_consequence_overlay_ready": _world_consequence_overlay != null,
		"world_consequence_visual": world_visual,
		"live_action_overlay_ready": _live_action_overlay != null,
		"live_action_visual": live_visual,
		"bitling_world_position": _live_position,
		"bitling_world_target": _live_target,
		"live_action_phase": str(live_action_snapshot.get("phase", "idle"))
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
		var choice_index := _live_action_choice_at(position)
		if choice_index >= 0 and activate_live_action_choice(choice_index):
			_request_touch_performance(position)
			accept_event()
			return
		var hotspot := _habitat_hotspot_at(position)
		if not hotspot.is_empty() and hotspot != "bitling":
			focused_hotspot = hotspot
			_sync_habitat_overlay()
			_request_touch_performance(position)
			hotspot_pressed.emit(hotspot)
			accept_event()
			return
	super._gui_input(event)

func _live_action_choice_at(position: Vector2) -> int:
	var regions := get_live_action_choice_regions()
	for index in range(regions.size()):
		if regions[index].has_point(position):
			return index
	return -1

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

func _apply_live_action_motion(delta: float) -> void:
	if _bitling == null:
		return
	var active := bool(live_action_snapshot.get("active", false))
	var phase := str(live_action_snapshot.get("phase", "idle"))
	var hotspot := str(live_action_snapshot.get("hotspot", "bitling"))
	_live_target = LIVE_ACTION_WORLD_TARGETS.get(hotspot, LIVE_ACTION_WORLD_TARGETS["bitling"]) as Vector3 if active and phase != "aftermath" else LIVE_ACTION_WORLD_TARGETS["bitling"] as Vector3
	var speed := 8.5 if _reduce_motion_enabled() else 3.4 if phase == "approach" else 5.2 if phase == "aftermath" else 4.1
	var blend := 1.0 - exp(-speed * delta)
	_live_position = _live_position.lerp(_live_target, clampf(blend, 0.0, 1.0))
	var phase_bob := 0.0
	if not _reduce_motion_enabled() and phase in ["observe", "awaiting_choice", "perform"]:
		phase_bob = sin(_elapsed * (3.1 if phase == "perform" else 1.8)) * (0.045 if phase == "perform" else 0.022)
	_bitling.position = Vector3(_live_position.x, _live_position.y + phase_bob, _live_position.z)
	var target_yaw := float(LIVE_ACTION_YAWS.get(hotspot, 0.0)) if active and phase != "aftermath" else 0.0
	_live_yaw = lerp_angle(_live_yaw, target_yaw, clampf(delta * 4.2, 0.0, 1.0))
	_bitling.rotation.y = _live_yaw

func _on_live_phase_entered(phase: String) -> void:
	match phase:
		"approach":
			play_reaction()
		"observe":
			play_action_animation("learn")
		"perform":
			play_action_animation(str(live_action_snapshot.get("selected_lens", activity_lens)))
		"aftermath":
			play_reaction()
		_:
			pass

func _sync_habitat_overlay() -> void:
	if _habitat_overlay != null:
		_habitat_overlay.call("set_context", focused_hotspot, activity_lens, moment_title)

func _sync_world_consequences() -> void:
	if _world_consequence_overlay != null:
		_world_consequence_overlay.call("set_snapshot", world_consequence_snapshot)

func _sync_live_action() -> void:
	if _live_action_overlay != null:
		_live_action_overlay.call("set_snapshot", live_action_snapshot)
