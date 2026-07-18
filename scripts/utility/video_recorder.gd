extends Node

# Automatisierter Frame-Recorder für BITLING OMNI v3.0
# Erstellt eine PNG-Frame-Sequenz in einem Zielordner für spätere Videokomposition (FFmpeg etc.).

signal recording_started()
signal recording_finished(frame_count: int)

@export var is_recording: bool = false
@export var target_dir: String = "user://video_frames/"
@export var frames_per_second: float = 30.0
@export var max_frames: int = 900 # Standard: 30 Sekunden bei 30 FPS

var _frame_timer: float = 0.0
var _current_frame: int = 0

func _ready() -> void:
	_ensure_directory()
	print("[VideoRecorder] Initialisiert. Zielverzeichnis:", target_dir)

func _ensure_directory() -> void:
	# Versuche, das Zielverzeichnis rekursiv anzulegen. DirAccess.make_dir_recursive ist statisch verfügbar.
	var ok = DirAccess.make_dir_recursive(target_dir)
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

func _process(delta: float) -> void:
	if not is_recording:
		return

	_frame_timer += delta
	var frame_interval = 1.0 / frames_per_second

	if _frame_timer >= frame_interval:
		_frame_timer -= frame_interval
		_capture_frame()
		_current_frame += 1

		if _current_frame >= max_frames:
			stop_recording()

func _capture_frame() -> void:
	# Erfasst den aktuellen Viewport-Inhalt
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

	# Optional: bei Bedarf auf gewünschte Auflösung skalieren (auskommentieren, falls nicht gebraucht)
	# img.resize(1920, 1080, Image.INTERPOLATE_LANCZOS)

	# Stelle sicher, dass der Zielpfad einen abschließenden Slash hat
	var save_dir := target_dir
	if not save_dir.ends_with("/"):
		save_dir += "/"

	var file_path := save_dir + "frame_%06d.png" % _current_frame
	var err := img.save_png(file_path)
	if err != OK:
		push_error("[VideoRecorder] Fehler beim Speichern von Frame %d: %d" % [_current_frame, err])

# Einfache Hilfsfunktionen zum Triggern via UI oder externen Aufrufen
func trigger_recording_sequence() -> void:
	start_recording()
	# Hier können automatisierte Sequenzen oder Spielaktionen ausgelöst werden.

func toggle_recording() -> void:
	if is_recording:
		stop_recording()
	else:
		start_recording()
