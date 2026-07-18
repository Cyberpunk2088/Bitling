HQ Encoding and Post-Processing (FFmpeg) - Best Practices

This document provides high-quality encoding pipelines for pro-level trailers and masters.

Capture recommendations
- Capture lossless PNG sequences at target resolution (recommended: 4K for modern trailers).
- Use a fixed timestep and disable VSync in export builds to get deterministic frame timing.
- Consider supersampling (render at 2x and downscale) to reduce aliasing. Supersampling is heavy; prefer on powerful desktops.

Recommended FFmpeg commands
1) ProRes HQ master (visually lossless, edit-friendly):
   ffmpeg -y -framerate 60 -i frame_%06d.png -c:v prores_ks -profile:v 3 master_prores.mov
   - profile:v 3 = ProRes 422 HQ. For alpha or maximum fidelity use profile 4/4444 (if supported).

2) Lossless H.264 (huge files, but single-file master):
   ffmpeg -y -framerate 60 -i frame_%06d.png -c:v libx264 -preset veryslow -crf 0 -pix_fmt yuv420p master_lossless.mp4

3) High-quality H.264 for distribution (balance quality & size):
   ffmpeg -y -framerate 60 -i frame_%06d.png -c:v libx264 -preset slow -crf 18 -pix_fmt yuv420p release_1080p.mp4

4) HEVC/H.265 (better compression for same quality, may not be universally supported):
   ffmpeg -y -framerate 60 -i frame_%06d.png -c:v libx265 -preset slower -crf 18 -pix_fmt yuv420p release_hevc.mp4

Audio sync
- If rendering audio separately or adding music, ensure durations match. Use ffmpeg to mux audio:
   ffmpeg -i video.mp4 -i music.wav -c:v copy -c:a aac -b:a 320k -shortest output_with_audio.mp4

Color space and LUTs
- Ensure your rendering color space matches your target. For cinematic trailers, use linear/lightspace and convert to sRGB for display.
- Apply LUTs or color grading in a proper NLE (DaVinci Resolve) after creating a high-quality master (ProRes recommended).

Automation hints
- Use the server-side example in docs/server to upload and run ffmpeg server-side where resources are abundant.
- For batch processing, a watch script can invoke ffmpeg once all frames are available.

Hardware
- For 4K@60, a strong CPU and fast NVMe storage are recommended. GPU-accelerated encoders (e.g., h264_nvenc) can speed up compilation but may affect cross-platform compatibility.

