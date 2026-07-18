extends Control

@export var recorder_node_path: NodePath = NodePath("../RecorderPro")
@export var hq_recorder_node_path: NodePath = NodePath("../HQRecorder")
@export var zip_output_name: String = "user://bitling_frames.zip"

onready var start_btn := $StartButton
onready var stop_btn := $StopButton
onready var hq_btn := $HQButton
onready var package_btn := $PackageButton
onready var upload_btn := $UploadButton
onready var status_label := $StatusLabel

func _ready() -> void:
	start_btn.pressed.connect(self._on_start_pressed)
	stop_btn.pressed.connect(self._on_stop_pressed)
	hq_btn.pressed.connect(self._on_hq_pressed)
	package_btn.pressed.connect(self._on_package_pressed)
	upload_btn.pressed.connect(self._on_upload_pressed)
	_update_status("Recorder UI ready")

func _get_recorder():
	if has_node(recorder_node_path):
		return get_node(recorder_node_path)
	_update_status("Recorder node not found at " + str(recorder_node_path))
	return null

func _get_hq_recorder():
	if has_node(hq_recorder_node_path):
		return get_node(hq_recorder_node_path)
	_update_status("HQ Recorder node not found at " + str(hq_recorder_node_path))
	return null

func _on_start_pressed():
	var r = _get_recorder()
	if r:
		r.start_recording()
		_update_status("Recording started")

func _on_stop_pressed():
	var r = _get_recorder()
	if r:
		r.stop_recording()
		_update_status("Recording stopped")

func _on_hq_pressed():
	var hq = _get_hq_recorder()
	if hq:
		hq.start_recording()
		_update_status("HQ Recording started")

func _on_package_pressed():
	# Use HQ recorder if available, else normal
	var r = _get_hq_recorder()
	if r == null:
		r = _get_recorder()
	if r:
		_update_status("Packaging ZIP...")
		# Gather files from recorder
		var files = []
		if r.has_method("gather_frame_files"):
			files = r.gather_frame_files()
		else:
			# fallback: try common directory
			var da = DirAccess.open(r.target_dir)
			if da:
				files = []
				da.list_dir_begin()
				var name = da.get_next()
				while name != "":
					if not da.current_is_dir() and name.begins_with("frame_"):
						files.append(r.target_dir.rstrip("/") + "/" + name)
					name = da.get_next()
				da.list_dir_end()
		# Use ZipPacker
		var zp = preload("res://scripts/utility/zip_packer.gd").new()
		var ok = zp.create_zip(zip_output_name, files)
		if ok:
			_update_status("Packaged: " + zip_output_name)
		else:
			_update_status("Packaging failed")

func _on_upload_pressed():
	var r = _get_hq_recorder()
	if r == null:
		r = _get_recorder()
	if r:
		var out = zip_output_name
		if FileAccess.file_exists(out):
			_update_status("Uploading...")
			if r.has_method("upload_file"):
				r.upload_file(out)
			else:
				_update_status("Recorder has no upload capability")
		else:
			_update_status("ZIP not found: " + out)

func _update_status(text: String) -> void:
	status_label.text = text
