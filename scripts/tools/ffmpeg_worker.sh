#!/usr/bin/env bash
# ffmpeg_worker.sh - Simple wrapper to encode a sequence of PNGs into a ProRes master
# Usage: ./ffmpeg_worker.sh /path/to/frames_dir /path/to/output.mov [fps]

FRAMES_DIR="$1"
OUT_FILE="$2"
FPS=${3:-60}

if [ -z "$FRAMES_DIR" ] || [ -z "$OUT_FILE" ]; then
  echo "Usage: $0 /path/to/frames_dir /path/to/output.mov [fps]"
  exit 1
fi

FRAME_PATTERN="$FRAMES_DIR/frame_%06d.png"

ffmpeg -y -framerate $FPS -i "$FRAME_PATTERN" -c:v prores_ks -profile:v 3 "$OUT_FILE"
