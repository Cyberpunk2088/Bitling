# Xogot Recording Notes for BITLING OMNI v3.0

Dieses Dokument fasst empfohlene Einstellungen und Schritte zum Aufnehmen von Gameplay‑Sequenzen auf iOS (Xogot) zusammen.

Wichtigste Punkte:
- Standard-Format: JPEG (schneller, kleiner) mit Qualitätswert 85 für gute Balance aus Größe/Qualität.
- Standard-FPS für Xogot: 15 FPS (reduziert, um Encoding-Overhead zu minimieren).
- Standard-Dauer: max_frames = 450 (≈30 Sekunden bei 15 FPS). Passe bei Bedarf an.
- Speicherort: user://video_frames/ innerhalb der iOS‑Sandbox. Zugriff erfolgt über die Files App oder beim Debugging per ADB/idevice tools.

Empfohlener Workflow:
1. Erstelle eine Export-Build für iOS (Godot 4). Verwende gleichen Fenstermodus/Größe wie Zielgerät für deterministische Ergebnisse.
2. Füge in deiner Hauptszene einen Node "Recorder" hinzu und hänge scripts/utility/video_recorder.gd an.
3. Starte die Aufnahme per Code: get_node("Recorder").start_recording()
4. Nach Beendigung kopiere die erzeugten JPEGs vom Zielgerät auf deinen Rechner.
5. Kombiniere die Frames mit FFmpeg:
   ffmpeg -framerate 15 -i frame_%06d.jpg -c:v libx264 -pix_fmt yuv420p -crf 18 bitling_omni_trailer.mp4

Performance-Hinweise:
- PNG-Encoding ist auf iOS deutlich teurer; nutze JPEG für mobile Aufnahmen.
- Vermeide hohe Auflösungen beim direkten Gerätetraining; für 1080p/4K hochwertige Trailer empfiehlt sich Aufnahme auf Desktop/Export-Target mit mehr Leistung.
- Überwache freien Speicher (get_free_space_bytes) bevor du start_recording() aufrufst.

