extends Node

signal recording_started()
signal recording_finished(frame_count: int)

@export var is_recording: bool = false
@export var target_dir: String = "user://video_frames"
@export var use_jpg: bool = true
@export_range(1, 100, 1) var jpg_quality: int = 85
@export_range(1.0, 60.0, 1.0) var frames_per_second: float = 15.0
@export var max_frames: int = 450
@export var flip_y_on_save: bool = true
@export var resize_before_save: bool = false
@export var resize_width: int = 1280
@export var resize_height: int = 720

var _frame_timer: float = 0.0
var _current_frame: int = 0

func _ready() -> void:
	if OS.get_name() == "iOS":
		use_jpg = true
		frames_per_second = minf(frames_per_second, 15.0)
		max_frames = mini(max_frames, 450)
	_ensure_directory()

func start_recording() -> void:
	if is_recording:
		return
	_ensure_directory()
	is_recording = true
	_current_frame = 0
	_frame_timer = 0.0
	recording_started.emit()

func stop_recording() -> void:
	if not is_recording:
		return
	is_recording = false
	recording_finished.emit(_current_frame)

func toggle_recording() -> void:
	if is_recording:
		stop_recording()
	else:
		start_recording()

func _process(delta: float) -> void:
	if not is_recording:
		return
	_frame_timer += delta
	var frame_interval: float = 1.0 / maxf(frames_per_second, 1.0)
	while _frame_timer >= frame_interval and is_recording:
		_frame_timer -= frame_interval
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
	var error := OK
	if use_jpg:
		error = image.save_jpg(path, clampf(float(jpg_quality) / 100.0, 0.01, 1.0))
	else:
		error = image.save_png(path)
	if error != OK:
		push_error("[VideoRecorder] Could not save frame %d: %s" % [_current_frame, error])

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

func get_target_directory() -> String:
	return target_dir

func get_free_space_bytes(path: String = "user://") -> int:
	var access := DirAccess.open(path)
	return access.get_space_left() if access != null else -1

func _ensure_directory() -> void:
	var absolute := ProjectSettings.globalize_path(target_dir)
	var error := DirAccess.make_dir_recursive_absolute(absolute)
	if error != OK and error != ERR_ALREADY_EXISTS:
		push_error("[VideoRecorder] Could not create directory: %s" % target_dir)
