extends "res://scripts/ui/production_bitling_stage_3d_v10.gd"

## Wave 3 boot hardening. The inherited world builder invokes _build_lighting()
## before Living Home exists, while Stage V10 invokes it again after the room is
## constructed. This override deliberately handles both lifecycle phases.

func _build_lighting() -> void:
	if _home_root == null:
		var key := DirectionalLight3D.new()
		key.name = "MoonKey"
		key.light_color = Color("b6d7ff")
		key.light_energy = 0.72
		key.rotation_degrees = Vector3(-42.0, -28.0, 0.0)
		key.shadow_enabled = true
		_world.add_child(key)
		_add_omni("CyanRim", Vector3(-3.2, 2.4, 1.2), COLOR_CYAN, 5.8, 3.2)
		_add_omni("MagentaRim", Vector3(3.4, 2.0, 0.6), COLOR_MAGENTA, 5.4, 3.0)
		_add_omni("VioletFill", Vector3(0.0, 4.4, -1.8), COLOR_VIOLET, 7.2, 2.4)
		_add_omni("FaceFill", Vector3(0.0, 1.5, 3.0), Color("7edfff"), 4.5, 1.5)
		return
	for data in [
		[Vector3(-3.8, 2.25, 0.5), Color("42e8ff"), 2.2],
		[Vector3(3.8, 2.10, 0.2), Color("a855f7"), 2.4],
		[Vector3(0.0, 3.10, -1.8), Color("f044d4"), 1.5]
	]:
		var light := OmniLight3D.new()
		light.position = data[0] as Vector3
		light.light_color = data[1] as Color
		light.light_energy = float(data[2])
		light.omni_range = 7.0
		_home_root.add_child(light)
		_lights.append(light)
