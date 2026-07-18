extends Node

signal recording_started()
signal recording_stopped(frame_count: int)

@export var auto_detect_platform: bool = true
@export var target_dir: String = "user://hq_frames"
@export var use_png: bool = true
@export_range(1, 60, 1) var frames_per_second: int = 60
@export var max_frames: int = 3600
@export var resize_before_save: bool = true
@export var resize_width: int = 1920
@export var resize_height: int = 1080
@export var flip_y_on_save: bool = false
@export var background_encode: bool = false
@export var ffmpeg_path: String = "ffmpeg"

var _frame_timer: float = 0.0
var _current_frame: int = 0
var _is_recording: bool = false

func _ready() -> void:
	if auto_detect_platform and OS.get_name() == "iOS":
		use_png = false
		frames_per_second = mini(frames_per_second, 15)
		max_frames = mini(max_frames, 450)
		resize_width = mini(resize_width, 1280)
		resize_height = mini(resize_height, 720)
		flip_y_on_save = true
	_ensure_directory()

func start_recording() -> void:
	if _is_recording:
		return
	_ensure_directory()
	_is_recording = true
	_current_frame = 0
	_frame_timer = 0.0
	recording_started.emit()

func stop_recording() -> void:
	if not _is_recording:
		return
	_is_recording = false
	recording_stopped.emit(_current_frame)
	if background_encode and OS.get_name() in ["Windows", "Linux", "macOS"]:
		_start_background_encode()

func _process(delta: float) -> void:
	if not _is_recording:
		return
	_frame_timer += delta
	var interval: float = 1.0 / float(maxi(frames_per_second, 1))
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
	var extension := ".png" if use_png else ".jpg"
	var base_name := "frame_%06d" % _current_frame
	var frame_path := target_dir.path_join(base_name + extension)
	var error := image.save_png(frame_path) if use_png else image.save_jpg(frame_path, 0.95)
	if error != OK:
		push_error("[HQRecorder] Could not save frame %d: %s" % [_current_frame, error])
		return
	var metadata := {
		"frame": _current_frame,
		"timestamp": int(Time.get_unix_time_from_system()),
		"resolution": [image.get_width(), image.get_height()],
		"fps_target": frames_per_second
	}
	var file := FileAccess.open(target_dir.path_join(base_name + ".json"), FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(metadata))
		file.close()

func _start_background_encode() -> void:
	var extension := "png" if use_png else "jpg"
	var sequence := ProjectSettings.globalize_path(target_dir.path_join("frame_%06d." + extension))
	var output := ProjectSettings.globalize_path(target_dir.path_join("encoded_master.mov"))
	var arguments := PackedStringArray([
		"-y", "-framerate", str(frames_per_second), "-i", sequence,
		"-c:v", "prores_ks", "-profile:v", "3", output
	])
	var process_id := OS.create_process(ffmpeg_path, arguments)
	if process_id <= 0:
		push_warning("[HQRecorder] Could not start ffmpeg process")

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

func package_frames_to_zip(out_path: String) -> String:
	var files := gather_frame_files()
	if files.is_empty():
		return ""
	var packer := ZipPacker.new()
	return out_path if packer.create_zip(out_path, files) else ""

func get_target_directory() -> String:
	return target_dir

func _ensure_directory() -> void:
	var error := DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(target_dir))
	if error != OK and error != ERR_ALREADY_EXISTS:
		push_error("[HQRecorder] Could not create directory: %s" % target_dir)
