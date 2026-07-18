extends Node

## Optional GDScript-only utility for automated showcase recordings.

@export var target_dir: String = "user://video_frames"
@export_range(1.0, 60.0, 1.0) var frames_per_second: float = 15.0
@export var max_frames: int = 450
@export var use_jpg: bool = true
@export_range(1, 100, 1) var jpg_quality: int = 85
@export var resize_before_save: bool = false
@export var resize_width: int = 1280
@export var resize_height: int = 720
@export var flip_y_on_save: bool = true
@export var choreography_steps: Array[Dictionary] = []
@export var upload_url: String = ""

var _is_recording: bool = false
var _frame_timer: float = 0.0
var _current_frame: int = 0

func _ready() -> void:
	_ensure_directory()

func start_recording() -> void:
	if _is_recording:
		return
	_ensure_directory()
	_is_recording = true
	_current_frame = 0
	_frame_timer = 0.0

func stop_recording() -> void:
	_is_recording = false

func _process(delta: float) -> void:
	if not _is_recording:
		return
	_frame_timer += delta
	var interval: float = 1.0 / maxf(frames_per_second, 1.0)
	while _frame_timer >= interval and _is_recording:
		_frame_timer -= interval
		_capture_frame()
		_current_frame += 1
		if _current_frame >= max_frames:
			stop_recording()

func _capture_frame() -> void:
	var viewport := get_viewport()
	if viewport == null or viewport.get_texture() == null:
		return
	var image := viewport.get_texture().get_image()
	if image == null or image.is_empty():
		return
	if flip_y_on_save:
		image.flip_y()
	if resize_before_save and resize_width > 0 and resize_height > 0:
		image.resize(resize_width, resize_height, Image.INTERPOLATE_LANCZOS)
	var extension := ".jpg" if use_jpg else ".png"
	var path := target_dir.path_join("frame_%06d%s" % [_current_frame, extension])
	var error := image.save_jpg(path, clampf(float(jpg_quality) / 100.0, 0.01, 1.0)) if use_jpg else image.save_png(path)
	if error != OK:
		push_error("[RecorderPro] Could not save frame %d: %s" % [_current_frame, error])

func run_choreography() -> void:
	if choreography_steps.is_empty():
		return
	var steps: Array[Dictionary] = choreography_steps.duplicate(true)
	steps.sort_custom(_sort_by_time)
	var previous_time := 0.0
	for step in steps:
		var target_time := maxf(float(step.get("time", 0.0)), previous_time)
		var wait_time := target_time - previous_time
		if wait_time > 0.0:
			await get_tree().create_timer(wait_time).timeout
		_perform_action(step)
		previous_time = target_time

func _sort_by_time(a: Dictionary, b: Dictionary) -> bool:
	return float(a.get("time", 0.0)) < float(b.get("time", 0.0))

func _perform_action(step: Dictionary) -> void:
	var action := str(step.get("action", ""))
	var parameters: Dictionary = step.get("params", {})
	match action:
		"touch":
			var position: Vector2 = parameters.get("pos", Vector2.ZERO)
			var press := InputEventScreenTouch.new()
			press.index = 0
			press.position = position
			press.pressed = true
			Input.parse_input_event(press)
			var release := press.duplicate() as InputEventScreenTouch
			release.pressed = false
			Input.parse_input_event(release)
		"start_record":
			start_recording()
		"stop_record":
			stop_recording()
		"wait":
			pass
		_:
			push_warning("[RecorderPro] Unknown choreography action: %s" % action)

func gather_frame_files() -> Array[String]:
	var files: Array[String] = []
	var access := DirAccess.open(target_dir)
	if access == null:
		return files
	access.list_dir_begin()
	var entry := access.get_next()
	while not entry.is_empty():
		if not access.current_is_dir() and entry.begins_with("frame_"):
			files.append(target_dir.path_join(entry))
		entry = access.get_next()
	access.list_dir_end()
	files.sort()
	return files

func package_frames_to_tar(out_path: String) -> String:
	var frames := gather_frame_files()
	if frames.is_empty():
		return ""
	var archive := FileAccess.open(out_path, FileAccess.WRITE)
	if archive == null:
		return ""
	for frame_path in frames:
		var source := FileAccess.open(frame_path, FileAccess.READ)
		if source == null:
			continue
		var data := source.get_buffer(source.get_length())
		source.close()
		_write_tar_entry(archive, frame_path.get_file(), data)
	var trailer := PackedByteArray()
	trailer.resize(1024)
	trailer.fill(0)
	archive.store_buffer(trailer)
	archive.close()
	return out_path

func _write_tar_entry(archive: FileAccess, file_name: String, data: PackedByteArray) -> void:
	var header := PackedByteArray()
	header.resize(512)
	header.fill(0)
	_write_field(header, 0, 100, file_name)
	_write_field(header, 100, 8, "0000644")
	_write_field(header, 108, 8, "0000000")
	_write_field(header, 116, 8, "0000000")
	_write_field(header, 124, 12, _octal_field(data.size(), 12))
	_write_field(header, 136, 12, _octal_field(int(Time.get_unix_time_from_system()), 12))
	_write_field(header, 148, 8, "        ")
	_write_field(header, 156, 1, "0")
	_write_field(header, 257, 6, "ustar")
	_write_field(header, 263, 2, "00")
	var checksum := 0
	for byte in header:
		checksum += int(byte)
	_write_field(header, 148, 6, String.num_int64(checksum, 8).pad_zeros(6))
	header[154] = 0
	header[155] = 32
	archive.store_buffer(header)
	archive.store_buffer(data)
	var remainder := data.size() % 512
	if remainder != 0:
		var padding := PackedByteArray()
		padding.resize(512 - remainder)
		padding.fill(0)
		archive.store_buffer(padding)

func _write_field(buffer: PackedByteArray, offset: int, length: int, value: String) -> void:
	var bytes := value.to_utf8_buffer()
	var count := mini(bytes.size(), length)
	for index in range(count):
		buffer[offset + index] = bytes[index]

func _octal_field(value: int, width: int) -> String:
	return String.num_int64(value, 8).pad_zeros(width - 1)

func upload_file(file_path: String) -> void:
	if upload_url.is_empty() or not FileAccess.file_exists(file_path):
		return
	var file := FileAccess.open(file_path, FileAccess.READ)
	if file == null:
		return
	var data := file.get_buffer(file.get_length())
	file.close()
	var request := HTTPRequest.new()
	add_child(request)
	request.request_completed.connect(_on_upload_completed.bind(request))
	var headers := PackedStringArray(["Content-Type: application/x-tar"])
	var error := request.request_raw(upload_url, headers, HTTPClient.METHOD_POST, data)
	if error != OK:
		request.queue_free()
		push_warning("[RecorderPro] Upload request failed to start: %s" % error)

func _on_upload_completed(_result: int, response_code: int, _headers: PackedStringArray, _body: PackedByteArray, request: HTTPRequest) -> void:
	print("[RecorderPro] Upload response: %d" % response_code)
	request.queue_free()

func get_target_directory() -> String:
	return target_dir

func _ensure_directory() -> void:
	var error := DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(target_dir))
	if error != OK and error != ERR_ALREADY_EXISTS:
		push_error("[RecorderPro] Could not create directory: %s" % target_dir)
