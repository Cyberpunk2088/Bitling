extends Node

# Xogot-optimierter Frame-Recorder für BITLING OMNI v3.0
# Ziel: Zuverlässige Frame-Erfassung auf iOS (Xogot) mit Performance- und Speicher‑Optimierungen.
# Verwendung: Node hinzufügen (z. B. Recorder) und das Script anhängen. Start/Stop per start_recording()/stop_recording().

signal recording_started()
signal recording_finished(frame_count: int)

# Konfigurierbare Eigenschaften
@export var is_recording: bool = false
@export var target_dir: String = "user://video_frames/" # user:// ist iOS-kompatibel
@export var use_jpg: bool = true # Auf iOS empfohlen: schneller und kleiner als PNG
@export var jpg_quality: int = 85 # JPEG-Qualität (0-100)
@export var frames_per_second: float = 15.0 # Default reduziert für mobile Performance (Xogot)
@export var max_frames: int = 450 # Standard: 30s @ 15 FPS
@export var flip_y_on_save: bool = true # Korrigiert mögliche vertikale Spiegelung auf mobilen Viewports
@export var resize_before_save: bool = false
@export var resize_width: int = 1280
@export var resize_height: int = 720

# Intern
var _frame_timer: float = 0.0
var _current_frame: int = 0
var _platform_defaults_applied: bool = false

func _ready() -> void:
	_apply_platform_defaults()
	_ensure_directory()
	print("[VideoRecorder] Initialisiert. Zielverzeichnis:", target_dir)

func _apply_platform_defaults() -> void:
	# Setzt sinnvolle Defaults für iOS / Xogot
	if _platform_defaults_applied:
		return
	_platform_defaults_applied = true
	var os_name := OS.get_name()
	if os_name == "iOS":
		# Optimierte Einstellungen für iPhone / Xogot
		use_jpg = true
		jpg_quality = 85
		frames_per_second = 15.0
		max_frames = 450
		flip_y_on_save = true
		print("[VideoRecorder] Plattform iOS erkannt — Xogot-optimierte Defaults angewendet.")

func _ensure_directory() -> void:
	# Versuche, das Zielverzeichnis rekursiv anzulegen
	var ok := DirAccess.make_dir_recursive(target_dir)
	if not ok:
		push_error("[VideoRecorder] Konnte Zielverzeichnis nicht erstellen: " + target_dir)

func start_recording() -> void:
	if is_recording:
		return
	is_recording = true
	_current_frame = 0
	_frame_timer = 0.0
	recording_started.emit()
	print("[VideoRecorder] Aufnahme gestartet. Ziel: ", target_dir)

func stop_recording() -> void:
	if not is_recording:
		return
	is_recording = false
	recording_finished.emit(_current_frame)
	print("[VideoRecorder] Aufnahme beendet. Gesamtframes: ", _current_frame)

func toggle_recording() -> void:
	if is_recording:
		stop_recording()
	else:
		start_recording()

func _process(delta: float) -> void:
	if not is_recording:
		return

	_frame_timer += delta
	var frame_interval := 1.0 / max(0.0001, frames_per_second)

	if _frame_timer >= frame_interval:
		_frame_timer -= frame_interval
		_capture_frame()
		_current_frame += 1

		if _current_frame >= max_frames:
			stop_recording()

func _capture_frame() -> void:
	# Holt den Viewport und sichert die Image-Daten
	var viewport := get_viewport()
	if viewport == null:
		push_warning("[VideoRecorder] Kein Viewport gefunden.")
		return

	var tex := viewport.get_texture()
	if tex == null:
		push_warning("[VideoRecorder] Viewport hat keine Textur.")
		return

	var img := tex.get_image()
	if img == null:
		push_warning("[VideoRecorder] Konnte Image aus Viewport-Textur nicht abrufen.")
		return

	# Korrigiere mögliche Spiegelung auf mobilen Plattformen
	if flip_y_on_save:
		# Einige Viewport-Implementierungen benötigen Flip
		img.flip_y()

	# Optional: Resize zur Reduktion von Encoding-Kosten
	if resize_before_save:
		if resize_width > 0 and resize_height > 0:
			img.resize(resize_width, resize_height, Image.INTERPOLATE_LANCZOS)

	# Zielpfad korrekt zusammenbauen
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
		push_error("[VideoRecorder] Fehler beim Speichern von Frame %d: %d" % [_current_frame, err])

# Optional: Hilfsmethode für externe Automation
func trigger_recording_sequence() -> void:
	start_recording()
	# Platz für automatisierte Sequenzen / Trigger

# Debug/Utility: Prüft wie viele Bytes frei sind (nicht garantiert auf allen Plattformen)
func get_free_space_bytes(path: String = "user://") -> int:
	var da := DirAccess.open(path)
	if da:
		return da.get_space_left()
	return -1
