extends Node

# High-Quality Recorder for Desktop (HQ) and Mobile (Dual-Mode)
# - Desktop HQ: lossless PNG sequence, 4K/60 default, optional supersampling
# - Mobile fallback: optimized settings (JPEG, 15fps)
# - Per-frame JSON metadata
# - Optional background encoding via ffmpeg (desktop only)

signal recording_started()
signal recording_stopped(frame_count: int)

@export var auto_detect_platform: bool = true
@export var target_dir: String = "user://hq_frames/"
@export var use_png: bool = true
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

func _ready() -> void:
	_apply_defaults()
	DirAccess.make_dir_recursive(target_dir)
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
	# For supersampling, we rely on viewport scaling if possible; otherwise resize after capture
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
		# If engine supports rendering at a larger viewport, that is preferable.
		# As fallback, resize the captured image (may degrade quality).
		var target_w = resolution_width * supersample_scale
		var target_h = resolution_height * supersample_scale
		if img.get_width() != target_w or img.get_height() != target_h:
			# attempt to upscale first then downscale
			img.resize(target_w, target_h, Image.INTERPOLATE_LANCZOS)
		# downscale to desired resolution
		img.resize(resolution_width, resolution_height, Image.INTERPOLATE_LANCZOS)
	elif resize_before_save:
		img.resize(resize_width, resize_height, Image.INTERPOLATE_LANCZOS)

	# Build filename and save
	var save_dir = target_dir
	if not save_dir.ends_with("/"):
		save_dir += "/"
	var fname = "frame_%06d" % _current_frame
	var fullpath = save_dir + fname
	var err = OK
	if use_png:
		fullpath += ".png"
		err = img.save_png(fullpath)
	else:
		fullpath += ".jpg"
		err = img.save_jpg(fullpath, 95)
	if err != OK:
		push_error("[HQRecorder] Error saving frame %d : %d" % [_current_frame, err])
	else:
		# Save per-frame metadata
		var meta = {
			"frame": _current_frame,
			"timestamp": OS.get_unix_time(),
			"resolution": [img.get_width(), img.get_height()],
			"fps_target": frames_per_second
		}
		var meta_path = save_dir + fname + ".json"
		var fh = FileAccess.open(meta_path, FileAccess.WRITE)
		if fh:
			fh.store_string(JSON.stringify(meta))
			fh.close()

func _start_background_encode() -> void:
	# Launch ffmpeg to encode frames into a master file. This works on desktop builds.
	var cmd = []
	if ffmpeg_command.strip_edges() == "":
		# default: lossless x264 (very large) and then user can re-encode
		# Recommend ProRes 4444 or ProRes 422 HQ for masters if available
		# Example: encode PNG sequence to ProRes (requires libx264 or prores_ks)
		var seq = target_dir.rstrip("/") + "/frame_%06d.png"
		var out = target_dir.rstrip("/") + "/encoded_master.mov"
		cmd = ["ffmpeg", "-y", "-framerate", str(frames_per_second), "-i", seq, "-c:v", "prores_ks", "-profile:v", "3", out]
	else:
		# User-specified command string; split on spaces (simple)
		cmd = ffmpeg_command.split(" ")
	print("[HQRecorder] Spawning background encoder:", cmd)
	# Note: OS.execute blocks if last param true; using false is non-blocking
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
	if Engine.has_singleton("ZipPacker"):
		# not typical; prefer loading the script class
		zp = ZipPacker.new()
	else:
		var packer = preload("res://scripts/utility/zip_packer.gd")
		zp = packer.new()
	var ok = zp.create_zip(out_path, files)
	if ok:
		return out_path
	return ""
