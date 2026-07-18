Desktop Build & HQ Workflow (README)

This guide contains steps to create a high-quality desktop export and encode frames into a master video.

Prerequisites
- Godot 4 (Editor + Export Templates)
- ffmpeg installed and in PATH
- Sufficient disk space (fast NVMe recommended)

Export Steps
1. In Project Settings:
   - Disable VSync
   - Set a fixed window size that matches your target resolution (e.g., 3840x2160 for 4K)
   - Ensure physics and fixed process are deterministic if you rely on fixed timestep
2. Create an Export Preset for your target platform (Windows/macOS/Linux) and export a build.
3. Run the exported build on the target machine.

Recording HQ Frames
- Use HQ Recorder (scripts/utility/video_recorder_hq.gd) attached to a node.
- Configure resolution, FPS (e.g., 60), and max_frames.
- Start recording: call start_recording() at runtime or via UI.

Encoding Master
- Use the provided ffmpeg_worker.sh or the ffmpeg_hq.md recommended commands.
- Example (ProRes 422 HQ):
  ./scripts/tools/ffmpeg_worker.sh /absolute/path/to/frames_dir /absolute/path/to/out_master.mov 60

Automation
- Use the RecorderPro choreography + package/upload to automate capture.

