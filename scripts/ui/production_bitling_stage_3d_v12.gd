extends "res://scripts/ui/production_bitling_stage_3d_v11.gd"

## Fullscreen Living Home composition used by the dedicated room destination.
## It reveals substantially more environment without shrinking the companion.

func _ready() -> void:
	super._ready()
	if _camera != null:
		_camera.fov = 54.0
		_camera.position = Vector3(0.0, 1.62, 10.25)
		_camera.look_at(Vector3(0.0, 1.18, -0.20), Vector3.UP)
	if _home_root != null:
		_home_root.scale = Vector3(0.86, 0.86, 0.86)
		_home_root.position = Vector3(0.0, -0.02, -0.18)
