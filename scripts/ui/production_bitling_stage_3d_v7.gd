extends "res://scripts/ui/production_bitling_stage_3d_v6.gd"

## Final Wave 1 stage hardening.
## A stretched SubViewportContainer owns its SubViewport dimensions; manually
## assigning them causes repeated Godot warnings. Camera composition is still
## adjusted responsively without touching the managed viewport size.

func _sync_viewport_size() -> void:
	if _viewport == null:
		return
	if not stretch:
		_viewport.size = Vector2i(maxi(480, int(size.x)), maxi(540, int(size.y)))
	if _camera == null or size.y <= 1.0:
		return
	var aspect: float = size.x / size.y
	var distance: float = 9.6 if aspect < 0.78 else 9.15 if aspect < 1.15 else 8.75
	_camera.position = Vector3(0.0, 1.48, distance)
	_camera.look_at(Vector3(0.0, 1.22, 0.0), Vector3.UP)
