extends "res://scripts/ui/legendary_activity_overlay.gd"

const ActivityBackdrop := preload("res://scripts/ui/legendary_activity_backdrop.gd")

var _visual_backdrop: Control

func _build_overlay() -> void:
	super._build_overlay()
	_visual_backdrop = ActivityBackdrop.new()
	_visual_backdrop.name = "LegendaryActivityVisualBackdrop"
	layer.add_child(_visual_backdrop)
	layer.move_child(_visual_backdrop, 1)
	_visual_backdrop.call("set_activity", _activity_id)
	var state := get_node_or_null("/root/GameState")
	if state != null:
		_visual_backdrop.set("reduced_motion", bool(state.settings.get("reduce_motion", false)))
	_apply_presentation_polish()

func _round_complete(success: bool, score: float, feedback: String) -> void:
	if _visual_backdrop != null and _visual_backdrop.has_method("pulse"):
		_visual_backdrop.call("pulse", success, score)
	super._round_complete(success, score, feedback)

func _finish_current_activity() -> void:
	if _visual_backdrop != null and _visual_backdrop.has_method("pulse"):
		_visual_backdrop.call("pulse", _successes >= 2, clampf(_score_total / float(maxi(_round_target, 1)), 0.0, 1.0))
	super._finish_current_activity()

func _apply_responsive_size() -> void:
	super._apply_responsive_size()
	if panel == null:
		return
	var viewport_size := get_viewport().get_visible_rect().size
	if viewport_size.x < 760.0:
		panel.custom_minimum_size = Vector2(maxf(330.0, viewport_size.x - 30.0), minf(620.0, viewport_size.y - 52.0))
		prompt_label.add_theme_font_size_override("font_size", 25)
		instruction_label.add_theme_font_size_override("font_size", 14)
		feedback_label.add_theme_font_size_override("font_size", 14)
	else:
		panel.custom_minimum_size = Vector2(minf(760.0, viewport_size.x * 0.62), 540.0)
		prompt_label.add_theme_font_size_override("font_size", 34)
		instruction_label.add_theme_font_size_override("font_size", 17)
		feedback_label.add_theme_font_size_override("font_size", 16)

func get_presentation_snapshot() -> Dictionary:
	var backdrop_snapshot: Dictionary = {}
	if _visual_backdrop != null and _visual_backdrop.has_method("get_visual_snapshot"):
		backdrop_snapshot = _visual_backdrop.call("get_visual_snapshot")
	return {
		"activity": _activity_id,
		"overlay_open": layer != null,
		"panel_minimum": panel.custom_minimum_size if panel != null else Vector2.ZERO,
		"visual_backdrop": backdrop_snapshot
	}

func _apply_presentation_polish() -> void:
	if panel == null:
		return
	panel.modulate.a = 0.0
	panel.scale = Vector2(0.96, 0.96)
	panel.pivot_offset = panel.size * 0.5
	var tween := create_tween().set_parallel(true).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(panel, "modulate:a", 1.0, 0.24)
	tween.tween_property(panel, "scale", Vector2.ONE, 0.32)
