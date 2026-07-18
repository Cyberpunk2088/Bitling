extends Node

# Demo controller for RecorderPro
# This demo will run a small choreography and trigger packaging/upload if configured.

func _ready() -> void:
	var pro = get_node("RecorderPro")
	if pro == null:
		print("[Demo] RecorderPro not found")
		return
	# Example choreography: start, touch, wait, touch, stop
	pro.choreography_steps = [
		{"time":0.0, "action":"start_record", "params":{}},
		{"time":0.3, "action":"touch", "params":{"pos":Vector2(200,300)}},
		{"time":1.2, "action":"touch", "params":{"pos":Vector2(400,200)}},
		{"time":3.5, "action":"stop_record", "params":{}},
	]
	# Run choreography in background (blocks minimally)
	pro.run_choreography()
	# After choreography, package frames to ZIP and optionally upload
	var zip_path = "user://bitling_demo_frames.zip"
	var out = pro.package_frames_to_zip(zip_path)
	if out != "":
		print("[Demo] Packaged demo frames to: ", out)
		# Optionally upload
		if pro.upload_url != "":
			pro.upload_file(out)
		else:
			print("[Demo] No upload_url configured; ZIP stored at ", out)
