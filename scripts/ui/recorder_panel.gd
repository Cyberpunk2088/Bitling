extends Control

@export var recorder_node_path: NodePath = NodePath("../RecorderPro")
@export var hq_recorder_node_path: NodePath = NodePath("../HQRecorder")
@export var zip_output_name: String = "user://bitling_frames.zip"

var status_label: Label

func _ready() -> void:
	status_label = get_node_or_null("StatusLabel") as Label
	_connect_button("StartButton", _on_start_pressed)
	_connect_button("StopButton", _on_stop_pressed)
	_connect_button("HQButton", _on_hq_pressed)
	_connect_button("PackageButton", _on_package_pressed)
	_connect_button("UploadButton", _on_upload_pressed)
	_update_status("Recorder UI ready")

func _connect_button(path: NodePath, callback: Callable) -> void:
	var button := get_node_or_null(path) as Button
	if button != null:
		button.pressed.connect(callback)

func _get_recorder() -> Node:
	var recorder := get_node_or_null(recorder_node_path)
	if recorder == null:
		_update_status("Recorder node not found: %s" % recorder_node_path)
	return recorder

func _get_hq_recorder() -> Node:
	var recorder := get_node_or_null(hq_recorder_node_path)
	if recorder == null:
		_update_status("HQ recorder node not found: %s" % hq_recorder_node_path)
	return recorder

func _on_start_pressed() -> void:
	var recorder := _get_recorder()
	if recorder != null and recorder.has_method("start_recording"):
		recorder.call("start_recording")
		_update_status("Recording started")

func _on_stop_pressed() -> void:
	var recorder := _get_recorder()
	if recorder != null and recorder.has_method("stop_recording"):
		recorder.call("stop_recording")
		_update_status("Recording stopped")

func _on_hq_pressed() -> void:
	var recorder := _get_hq_recorder()
	if recorder != null and recorder.has_method("start_recording"):
		recorder.call("start_recording")
		_update_status("HQ recording started")

func _on_package_pressed() -> void:
	var recorder := _get_hq_recorder()
	if recorder == null:
		recorder = _get_recorder()
	if recorder == null:
		return
	var files: Array = []
	if recorder.has_method("gather_frame_files"):
		files = recorder.call("gather_frame_files")
	elif recorder.has_method("get_target_directory"):
		files = _gather_files(str(recorder.call("get_target_directory")))
	if files.is_empty():
		_update_status("No frames available")
		return
	var packer := ZipPacker.new()
	if packer.create_zip(zip_output_name, files):
		_update_status("Packaged: %s" % zip_output_name)
	else:
		_update_status("Packaging failed")

func _on_upload_pressed() -> void:
	var recorder := _get_hq_recorder()
	if recorder == null:
		recorder = _get_recorder()
	if recorder == null or not FileAccess.file_exists(zip_output_name):
		_update_status("ZIP not found: %s" % zip_output_name)
		return
	if recorder.has_method("upload_file"):
		recorder.call("upload_file", zip_output_name)
		_update_status("Upload requested")
	else:
		_update_status("Recorder has no upload capability")

func _gather_files(directory: String) -> Array:
	var files: Array = []
	var access := DirAccess.open(directory)
	if access == null:
		return files
	access.list_dir_begin()
	var entry := access.get_next()
	while not entry.is_empty():
		if not access.current_is_dir() and entry.begins_with("frame_"):
			files.append(directory.path_join(entry))
		entry = access.get_next()
	access.list_dir_end()
	files.sort()
	return files

func _update_status(text: String) -> void:
	if status_label != null:
		status_label.text = text
	print("[RecorderPanel] %s" % text)
