Advanced Xogot Recording - Extended Notes

This document explains the extended pipeline and tools added to the repository.

Added features:
- RecorderPro: scripts/utility/video_recorder_pro.gd
  - Frame capture with same options as basic recorder
  - Choreography runner: timed actions to simulate touches, start/stop recording etc.
  - Packaging into an uncompressed TAR archive for easy download and upload
  - HTTP upload helper (if upload_url is set in inspector)

- Recorder UI (optional): A small UI script can be attached to your scene to create Start/Stop/Package/Upload buttons. The UI is intentionally lightweight and creation is left to the scene designer; RecorderPro exposes the necessary API: start_recording(), stop_recording(), package_frames_to_tar(path), upload_file(path)

Packaging format choice:
- TAR (ustar) uncompressed chosen for simplicity and predictability across platforms. TAR archives can be unpacked with `tar -xf archive.tar` on desktop systems. iOS Files app may require third-party apps to extract; alternatively download the TAR to a development machine.

Upload:
- RecorderPro can POST the TAR bytes to an HTTP endpoint if upload_url is provided. The server must accept a raw POST body with Content-Type: application/x-tar. Authentication and server-side handling are out of scope; provide an upload endpoint if you want automated upload.

Next steps / Suggestions:
- Implement an in-game zip (with compression) if ZIP compatibility with Files app is required. This needs a more complex encoder or native plugin.
- Implement a small UI panel scene (RecorderPanel.tscn) in the project for easier testing.

