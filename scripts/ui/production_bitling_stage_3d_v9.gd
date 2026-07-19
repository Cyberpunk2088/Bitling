extends "res://scripts/ui/production_bitling_stage_3d_v8.gd"

## Manual art-direction polish for positive facial readability.

func _ready() -> void:
	super._ready()
	_refine_speech_pulses()

func get_character_life_snapshot() -> Dictionary:
	var snapshot := super.get_character_life_snapshot()
	snapshot["art_direction_pass"] = "wave2_v9"
	return snapshot

func _apply_brows(value: float, gesture: String, t: float) -> void:
	if _left_brow == null or _right_brow == null:
		return
	var asymmetry := 0.0
	if gesture in ["focus_tilt", "scout"]:
		asymmetry = 0.10
	elif gesture == "ear_twitch_left":
		asymmetry = 0.16 * sin(t * 12.0)
	elif gesture == "ear_twitch_right":
		asymmetry = -0.16 * sin(t * 12.0)
	var lifted := clampf(value, -0.30, 0.32)
	_left_brow.position.y = 0.44 + lifted * 0.30 + asymmetry * 0.14
	_right_brow.position.y = 0.44 + lifted * 0.30 - asymmetry * 0.14
	_left_brow.rotation.z = deg_to_rad(90.0) + lifted * 0.85 + asymmetry
	_right_brow.rotation.z = deg_to_rad(90.0) - lifted * 0.85 + asymmetry

func _refine_speech_pulses() -> void:
	if _speech_root != null:
		_speech_root.position = Vector3(0.0, -0.53, 1.13)
	for index in range(_speech_rings.size()):
		var ring := _speech_rings[index] as MeshInstance3D
		if ring == null:
			continue
		var torus := ring.mesh as TorusMesh
		if torus != null:
			torus.inner_radius = 0.085 + float(index) * 0.060
			torus.outer_radius = 0.105 + float(index) * 0.060
		var material := ring.material_override as StandardMaterial3D
		if material != null:
			material.emission_energy_multiplier = 1.30 - float(index) * 0.14
		ring.transparency = 0.22 + float(index) * 0.12
