extends Node

# High-Quality Recorder for Desktop (HQ) and Mobile (Dual-Mode)
# Background save worker to avoid main-thread I/O blocking during frame capture.

signal recording_started()
signal recording_stopped(frame_count: int)

@export var auto_detect_platform: bool = true
@export var target_dir: String = "user://hq_frames/"
@export var use_png: bool = true
@export var jpg_quality: int = 90
@export var frames_per_second: int = 60
@export var max_frames: int = 3600 # default 60s @60fps
@export var resolution_width: int = 3840 # 4K width
@export var resolution_height: int = 2160 # 4K height
@export var supersample_scale: int = 1 # 1=no supersample, 2=render at 2x and downscale
@export var resize_before_save: bool = false
@export var resize_width: int = 3840
@export var resize_height: int = 2160
@export var flip_y_on_save: bool = false
@export var background_encode: bool = false # Spawn ffmpeg on desktop after recording
@export var ffmpeg_command: String = "" # if empty, use recommended default for platform

var _frame_timer: float = 0.0
var _current_frame: int = 0
var _is_recording: bool = false

# Save queue + threading
var _save_queue: Array = []
var _save_mutex := Mutex.new()
var _save_thread: Thread = Thread.new()
var _save_thread_running: bool = false

func _ready() -> void:
	_apply_defaults()
	DirAccess.make_dir_recursive(target_dir)
	_start_save_worker()
	print("[HQRecorder] Ready. Target:", target_dir)

func _apply_defaults() -> void:
	if auto_detect_platform:
		var osn = OS.get_name()
		if osn == "iOS":
			# Mobile constraints
			use_png = false
			frames_per_second = 15
			max_frames = 450
			flip_y_on_save = true
			resolution_width = 1280
			resolution_height = 720
			supersample_scale = 1
			print("[HQRecorder] iOS detected: applied mobile defaults")
		else:
			# Desktop HS defaults remain as configured (4K/60/PNG)
			print("[HQRecorder] Desktop detected: HQ defaults active")

func start_recording() -> void:
	if _is_recording:
		return
	_is_recording = true
	_current_frame = 0
	_frame_timer = 0.0
	recording_started.emit()
	print("[HQRecorder] Recording started")

func stop_recording() -> void:
	if not _is_recording:
		return
	_is_recording = false
	recording_stopped.emit(_current_frame)
	print("[HQRecorder] Recording stopped. Frames:", _current_frame)
	# wait for save queue drained before optionally starting encoder
	_wait_for_queue_empty()
	# Optionally trigger background encode on desktop
	if background_encode and (OS.get_name() in ["Windows", "Linux", "OSX"]):
		_start_background_encode()

func _process(delta: float) -> void:
	if not _is_recording:
		return
	_frame_timer += delta
	var interval = 1.0 / max(1, frames_per_second)
	if _frame_timer >= interval:
		_frame_timer -= interval
		_capture_frame()
		_current_frame += 1
		if _current_frame >= max_frames:
			stop_recording()

func _capture_frame() -> void:
	var viewport = get_viewport()
	if viewport == null:
		push_warning("[HQRecorder] No viewport")
		return
	var tex = viewport.get_texture()
	if tex == null:
		push_warning("[HQRecorder] Viewport has no texture")
		return
	var img = tex.get_image()
	if img == null:
		push_warning("[HQRecorder] Could not get Image from viewport")
		return
	# Optional flip for certain platforms
	if flip_y_on_save:
		img.flip_y()
	# Resize / supersample handling
	if supersample_scale > 1:
		var target_w = resolution_width * supersample_scale
		var target_h = resolution_height * supersample_scale
		if img.get_width() != target_w or img.get_height() != target_h:
			img.resize(target_w, target_h, Image.INTERPOLATE_LANCZOS)
		# downscale to desired resolution
		img.resize(resolution_width, resolution_height, Image.INTERPOLATE_LANCZOS)
	elif resize_before_save:
		img.resize(resize_width, resize_height, Image.INTERPOLATE_LANCZOS)

	# Build filename
	var save_dir = target_dir
	if not save_dir.ends_with("/"):
		save_dir += "/"
	var fname = "frame_%06d" % _current_frame
	var fullpath = save_dir + fname

	# Instead of synchronous save, enqueue the image for background writing
	var entry = {
		"path": fullpath,
		"is_png": use_png,
		"jpg_quality": jpg_quality,
		"image": img.duplicate()
	}
	_enqueue_save(entry)

func _enqueue_save(entry: Dictionary) -> void:
	_save_mutex.lock()
	_save_queue.append(entry)
	_save_mutex.unlock()

func _start_save_worker() -> void:
	if _save_thread_running:
		return
	_save_thread_running = true
	# start the thread; the worker will run _save_worker
	var err = _save_thread.start(self, "_save_worker", null)
	if err != OK:
		push_warning("[HQRecorder] Failed to start save thread; falling back to sync saves")
		_save_thread_running = false

func _stop_save_worker() -> void:
	if not _save_thread_running:
		return
	_save_mutex.lock()
	_save_thread_running = false
	_save_mutex.unlock()
	_save_thread.wait_to_finish()

func _wait_for_queue_empty() -> void:
	var tries = 0
	while true:
		_save_mutex.lock()
		var qsize = _save_queue.size()
		_save_mutex.unlock()
		if qsize == 0:
			break
		OS.delay_msec(50)
		tries += 1
		if tries > 600: # 30s timeout safety
			push_warning("[HQRecorder] save queue not drained after 30s; proceeding.")
			break

func _save_worker(_unused) -> void:
	# Worker loop: drains save queue and performs file writes off the main thread
	while true:
		_save_mutex.lock()
		var running = _save_thread_running
		var has_item = _save_queue.size() > 0
		if not running and not has_item:
			_save_mutex.unlock()
			break
		if not has_item:
			_save_mutex.unlock()
			OS.delay_msec(10)
			continue
		var entry = _save_queue.pop_front()
		_save_mutex.unlock()

		# Perform actual save on worker thread
		var path = entry.path
		var im = entry.image
		var ok = OK
		if entry.is_png:
			ok = im.save_png(path)
		else:
			ok = im.save_jpg(path, entry.jpg_quality)
		if ok != OK:
			push_error("[HQRecorder] background save failed for %s (err=%d)" % [path, ok])

func _start_background_encode() -> void:
	# Launch ffmpeg to encode frames into a master file. This works on desktop builds.
	var cmd = []
	if ffmpeg_command.strip_edges() == "":
		var seq = target_dir.rstrip("/") + "/frame_%06d.png"
		var out = target_dir.rstrip("/") + "/encoded_master.mov"
		cmd = ["ffmpeg", "-y", "-framerate", str(frames_per_second), "-i", seq, "-c:v", "prores_ks", "-profile:v", "3", out]
	else:
		cmd = ffmpeg_command.split(" ")
	print("[HQRecorder] Spawning background encoder:", cmd)
	var err = OS.execute(cmd[0], cmd.slice(1, cmd.size()), false)
	if err != OK:
		push_warning("[HQRecorder] Failed to start ffmpeg: " + str(err))

# Helper: gather frame files in order
func gather_frame_files() -> Array:
	var da = DirAccess.open(target_dir)
	var list := []
	if not da:
		return list
	da.list_dir_begin()
	var name = da.get_next()
	while name != "":
		if not da.current_is_dir() and name.begins_with("frame_"):
			list.append(target_dir.rstrip("/") + "/" + name)
		name = da.get_next()
	da.list_dir_end()
	list.sort()
	return list

# Convenient packaging via ZipPacker (if available)
func package_frames_to_zip(out_path: String) -> String:
	var files = gather_frame_files()
	if files.empty():
		push_warning("[HQRecorder] no frames to package")
		return ""
	var zp = null
	var packer = preload("res://scripts/utility/zip_packer.gd")
	zp = packer.new()
	var ok = zp.create_zip(out_path, files)
	if ok:
		return out_path
	return ""

func _exit_tree() -> void:
	# Ensure worker stops cleanly
	_stop_save_worker()
