extends Control

@export var recorder_node_path: NodePath = NodePath("../RecorderPro")
@export var zip_output_name: String = "user://bitling_frames.zip"

onready var start_btn := $StartButton
onready var stop_btn := $StopButton
onready var package_btn := $PackageButton
onready var upload_btn := $UploadButton
onready var status_label := $StatusLabel

func _ready() -> void:
	start_btn.pressed.connect(self._on_start_pressed)
	stop_btn.pressed.connect(self._on_stop_pressed)
	package_btn.pressed.connect(self._on_package_pressed)
	upload_btn.pressed.connect(self._on_upload_pressed)
	_update_status("Recorder UI ready")

func _get_recorder():
	if has_node(recorder_node_path):
		return get_node(recorder_node_path)
	_update_status("Recorder node not found at " + str(recorder_node_path))
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

func _on_package_pressed():
	var r = _get_recorder()
	if r:
		_update_status("Packaging ZIP...")
		var out = r.package_frames_to_zip(zip_output_name)
		if out != "":
			_update_status("Packaged: " + out)
		else:
			_update_status("Packaging failed")

func _on_upload_pressed():
	var r = _get_recorder()
	if r:
		var out = zip_output_name
		if FileAccess.file_exists(out):
			_update_status("Uploading...")
			r.upload_file(out)
		else:
			_update_status("ZIP not found: " + out)

func _update_status(text: String) -> void:
	status_label.text = text
