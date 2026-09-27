#!/bin/bash
set -euo pipefail
project_dir="$(cd "$(dirname "$0")" && pwd)"
for godot_path in "$HOME/Applications/Godot.app/Contents/MacOS/Godot" "/Applications/Godot.app/Contents/MacOS/Godot"; do
  if [[ -x "$godot_path" ]]; then
    exec "$godot_path" --path "$project_dir" --resolution 1100x760
  fi
done
printf '%s\n' 'Godot 4.6.3 wurde nicht gefunden. Öffne project.godot in Godot und starte die Hauptszene mit F5.'
exit 1
