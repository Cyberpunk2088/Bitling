extends "res://scripts/ui/living_home_overlay.gd"

## Wave 3 art-direction pass. Living Home owns a fullscreen 3D stage while the
## interface becomes a set of compact edge HUDs rather than a dashboard overlay.

const FullscreenHomeStage := preload("res://scripts/ui/production_bitling_stage_3d_v12.gd")

var _fullscreen_stage: Control

func _ready() -> void:
	super._ready()
	_install_fullscreen_stage()
	_apply_layout()

func open_home() -> void:
	super.open_home()
	if _fullscreen_stage != null:
		_fullscreen_stage.visible = true
		_fullscreen_stage.grab_focus()

func close_home() -> void:
	if _fullscreen_stage != null:
		_fullscreen_stage.visible = false
	super.close_home()

func get_overlay_snapshot() -> Dictionary:
	var snapshot := super.get_overlay_snapshot()
	snapshot["fullscreen_stage"] = _fullscreen_stage != null
	snapshot["fullscreen_stage_visible"] = _fullscreen_stage != null and _fullscreen_stage.visible
	return snapshot

func _install_fullscreen_stage() -> void:
	if _root == null:
		return
	_fullscreen_stage = FullscreenHomeStage.new()
	_fullscreen_stage.name = "LivingHomeFullscreenStage3D"
	_fullscreen_stage.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_fullscreen_stage.mouse_filter = Control.MOUSE_FILTER_STOP
	_fullscreen_stage.focus_mode = Control.FOCUS_ALL
	_root.add_child(_fullscreen_stage)
	_root.move_child(_fullscreen_stage, 1)
	_fullscreen_stage.visible = _open

func _apply_layout() -> void:
	if _root == null or _header == null:
		return
	var size := get_viewport().get_visible_rect().size
	var compact := size.x < 760.0
	var tablet := size.x >= 760.0 and size.x < 1180.0

	_header.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_header.offset_left = 10.0
	_header.offset_right = -10.0
	_header.offset_top = 10.0
	_header.offset_bottom = 92.0

	if compact:
		_status.anchor_left = 0.0
		_status.anchor_right = 0.0
		_status.anchor_top = 0.0
		_status.anchor_bottom = 0.0
		_status.offset_left = 10.0
		_status.offset_right = 190.0
		_status.offset_top = 102.0
		_status.offset_bottom = 342.0

		_objects.anchor_left = 1.0
		_objects.anchor_right = 1.0
		_objects.anchor_top = 0.0
		_objects.anchor_bottom = 0.0
		_objects.offset_left = -226.0
		_objects.offset_right = -10.0
		_objects.offset_top = 102.0
		_objects.offset_bottom = 394.0

		_detail.anchor_left = 0.5
		_detail.anchor_right = 0.5
		_detail.anchor_top = 1.0
		_detail.anchor_bottom = 1.0
		_detail.offset_left = -156.0
		_detail.offset_right = 156.0
		_detail.offset_top = -284.0
		_detail.offset_bottom = -148.0

		_decorations.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
		_decorations.offset_left = 10.0
		_decorations.offset_right = -10.0
		_decorations.offset_top = -138.0
		_decorations.offset_bottom = -10.0
	elif tablet:
		_status.set_anchors_and_offsets_preset(Control.PRESET_LEFT_WIDE)
		_status.offset_left = 16.0
		_status.offset_right = 276.0
		_status.offset_top = 104.0
		_status.offset_bottom = -166.0

		_objects.set_anchors_and_offsets_preset(Control.PRESET_RIGHT_WIDE)
		_objects.offset_left = -330.0
		_objects.offset_right = -16.0
		_objects.offset_top = 104.0
		_objects.offset_bottom = -166.0

		_detail.anchor_left = 0.5
		_detail.anchor_right = 0.5
		_detail.anchor_top = 1.0
		_detail.anchor_bottom = 1.0
		_detail.offset_left = -220.0
		_detail.offset_right = 220.0
		_detail.offset_top = -310.0
		_detail.offset_bottom = -166.0

		_decorations.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
		_decorations.offset_left = 16.0
		_decorations.offset_right = -16.0
		_decorations.offset_top = -154.0
		_decorations.offset_bottom = -16.0
	else:
		_status.set_anchors_and_offsets_preset(Control.PRESET_LEFT_WIDE)
		_status.offset_left = 20.0
		_status.offset_right = 300.0
		_status.offset_top = 104.0
		_status.offset_bottom = -178.0

		_objects.set_anchors_and_offsets_preset(Control.PRESET_RIGHT_WIDE)
		_objects.offset_left = -370.0
		_objects.offset_right = -20.0
		_objects.offset_top = 104.0
		_objects.offset_bottom = -178.0

		_detail.anchor_left = 0.5
		_detail.anchor_right = 0.5
		_detail.anchor_top = 1.0
		_detail.anchor_bottom = 1.0
		_detail.offset_left = -250.0
		_detail.offset_right = 250.0
		_detail.offset_top = -330.0
		_detail.offset_bottom = -178.0

		_decorations.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
		_decorations.offset_left = 20.0
		_decorations.offset_right = -20.0
		_decorations.offset_top = -164.0
		_decorations.offset_bottom = -20.0
