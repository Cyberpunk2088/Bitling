extends Node

# Advanced Recorder for Xogot - pro features
# - Frame capture (inherits behavior from basic recorder)
# - Choreography support (sequence of timed actions)
# - Packaging frames into a TAR archive for easy download
# - HTTP upload of resulting TAR (optional: set upload_url)
# - Lightweight UI integration hooks

@export var base_recorder_path: String = "res://scripts/utility/video_recorder.gd"
@export var target_dir: String = "user://video_frames/"
@export var frames_per_second: float = 15.0
@export var max_frames: int = 450
@export var use_jpg: bool = true
@export var jpg_quality: int = 85
@export var resize_before_save: bool = false
@export var resize_width: int = 1280
@export var resize_height: int = 720
@export var flip_y_on_save: bool = true

# Choreography: array of dictionaries: {time: float, action: String, params: Dictionary}
# Example: [{"time":0.0, "action":"wait", "params":{}}, {"time":0.5, "action":"touch", "params":{"pos":Vector2(200,300)}}]
@export var choreography_steps: Array = []

# Optional upload endpoint (if empty, upload is disabled)
@export var upload_url: String = ""

var _is_recording: bool = false
var _frame_timer: float = 0.0
var _current_frame: int = 0

func _ready():
	# Ensure directory
	DirAccess.make_dir_recursive(target_dir)
	print("[RecorderPro] Ready. Target:", target_dir)

func start_recording():
	if _is_recording:
		return
	_is_recording = true
	_current_frame = 0
	_frame_timer = 0.0
	print("[RecorderPro] recording started")

func stop_recording():
	if not _is_recording:
		return
	_is_recording = false
	print("[RecorderPro] recording stopped. frames:", _current_frame)

func _process(delta: float) -> void:
	if not _is_recording:
		return
	_frame_timer += delta
	var interval = 1.0 / max(0.0001, frames_per_second)
	if _frame_timer >= interval:
		_frame_timer -= interval
		_capture_frame()
		_current_frame += 1
		if _current_frame >= max_frames:
			stop_recording()

func _capture_frame():
	var viewport := get_viewport()
	if viewport == null:
		return
	var tex := viewport.get_texture()
	if tex == null:
		return
	var img := tex.get_image()
	if img == null:
		return
	if flip_y_on_save:
		img.flip_y()
	if resize_before_save and resize_width>0 and resize_height>0:
		img.resize(resize_width, resize_height, Image.INTERPOLATE_LANCZOS)
	var save_dir := target_dir
	if not save_dir.ends_with("/"):
		save_dir += "/"
	var filename := "frame_%06d" % _current_frame
	var file_path := save_dir + filename
	var err := OK
	if use_jpg:
		file_path += ".jpg"
		err = img.save_jpg(file_path, jpg_quality)
	else:
		file_path += ".png"
		err = img.save_png(file_path)
	if err != OK:
		push_error("[RecorderPro] save error %d" % err)

# Choreography runner
func run_choreography():
	if choreography_steps.empty():
		print("[RecorderPro] no choreography steps")
		return
	# Sort by time
	choreography_steps.sort_custom(self, "_sort_by_time")
	var start_time = OS.get_ticks_msec() / 1000.0
	for step in choreography_steps:
		var target_time = start_time + float(step.get("time", 0.0))
		while OS.get_ticks_msec() / 1000.0 < target_time:
			OS.delay_usec(10000) # 10ms wait
			# yield(get_tree().create_timer(0.01), "timeout")
		_perform_action(step)

func _sort_by_time(a, b):
	return int(sign(float(a.get("time",0)) - float(b.get("time",0))))

func _perform_action(step: Dictionary) -> void:
	var action = step.get("action", "")
	var params = step.get("params", {})
	match action:
		"touch":
			var pos = params.get("pos", Vector2(0,0))
			# simulate touch event
			var ev = InputEventScreenTouch.new()
			ev.pressed = true
			ev.index = 0
			ev.position = pos
			get_tree().input_event(ev)
			# release
			ev.pressed = false
			get_tree().input_event(ev)
		"wait":
			# do nothing (timing already handled)
			pass
		"start_record":
			start_recording()
		"stop_record":
			stop_recording()
		_:
			print("[RecorderPro] unknown action:", action)

# Pack frames into a TAR archive (uncompressed). Returns path or empty string on error.
func package_frames_to_tar(out_path: String) -> String:
	var frames = _gather_frame_files()
	if frames.empty():
		push_warning("[RecorderPro] no frames to package")
		return ""
	var file = FileAccess.open(out_path, FileAccess.WRITE)
	if not file:
		push_error("[RecorderPro] cannot open tar for writing: " + out_path)
		return ""
	# write each file with ustar header
	for f in frames:
		var fh = FileAccess.open(f, FileAccess.READ)
		if not fh:
			push_warning("[RecorderPro] cannot open frame: " + f)
			continue
		var data = fh.get_buffer(fh.get_length())
		fh.close()
		_write_tar_entry(file, f.get_file(), data)
	# two 512-byte zero blocks to mark end of archive
	file.store_8_array(PackedByteArray(512))
	file.store_8_array(PackedByteArray(512))
	file.close()
	print("[RecorderPro] tar written to:", out_path)
	return out_path

func _gather_frame_files() -> Array:
	var da = DirAccess.open(target_dir)
	var list := []
	if not da:
		return list
	da.list_dir_begin()
	var name = da.get_next()
	while name != "":
		if not da.current_is_dir():
			if name.begins_with("frame_"):
				list.append(target_dir.rstrip("/") + "/" + name)
		name = da.get_next()
	da.list_dir_end()
	list.sort() # ensure ordered
	return list

func _write_tar_entry(file: FileAccess, name: String, data: PackedByteArray) -> void:
	# build 512-byte header
	var header = PoolByteArray()
	header.resize(512)
	var buf = header
	# helper to write at offset
	func _set_bytes(offset:int, src: PoolByteArray) -> void:
		for i in range(src.size()):
			buf[offset + i] = src[i]
	# name (100)
	var name_bytes = name.to_utf8()
	if name_bytes.size() > 100:
		name_bytes = name_bytes.subarray(0,100)
	_set_bytes(0, name_bytes)
	# mode (8)
	_set_bytes(100, "0000777\0".to_utf8())
	# uid (8)
	_set_bytes(108, "0000000\0".to_utf8())
	# gid (8)
	_set_bytes(116, "0000000\0".to_utf8())
	# size (12) octal
	var size_oct = "%011o" % data.size()
	_set_bytes(124, (size_oct + "\0").to_utf8())
	# mtime (12)
	var mtime_oct = "%011o" % OS.get_unix_time()
	_set_bytes(136, (mtime_oct + "\0").to_utf8())
	# chksum (8) - fill with spaces for checksum calc
	_set_bytes(148, "        ".to_utf8())
	# typeflag (1)
	_set_bytes(156, "0".to_utf8())
	# linkname (100) skipped
	# magic (6) + version (2)
	_set_bytes(257, "ustar\0".to_utf8())
	_set_bytes(263, "00".to_utf8())
	# uname (32)
	_set_bytes(265, "godot\0".to_utf8())
	# gname (32)
	_set_bytes(297, "godot\0".to_utf8())
	# prefix skipped
	# compute checksum: sum of all bytes of header
	var chksum = 0
	for i in range(512):
		chksum += int(buf[i])
	# write checksum in header as octal with trailing NULL and space
	var chksum_str = "%06o" % chksum + "\0 "
	_set_bytes(148, chksum_str.to_utf8())
	# write header
	file.store_8_array(buf)
	# write data
	file.store_buffer(data)
	# pad to 512-byte block
	var rem = data.size() % 512
	if rem != 0:
		var pad = 512 - rem
		file.store_8_array(PackedByteArray(pad))

# Upload TAR via HTTPRequest (synchronous-ish using signals)
func upload_file(file_path: String) -> void:
	if upload_url == "":
		push_warning("[RecorderPro] no upload_url set")
		return
	var http = HTTPRequest.new()
	add_child(http)
	http.connect("request_completed", Callable(self, "_on_upload_completed"))
	var f = FileAccess.open(file_path, FileAccess.READ)
	if not f:
		push_error("[RecorderPro] cannot open file for upload")
		return
	var data = f.get_buffer(f.get_length())
	f.close()
	var headers = ["Content-Type: application/x-tar"]
	http.request(upload_url, headers, false, HTTPClient.METHOD_POST, data)

func _on_upload_completed(result, response_code, headers, body):
	print("[RecorderPro] upload result:", result, response_code)

