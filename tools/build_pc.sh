#!/bin/bash
# Build the Windows game: one .exe with the game data inside.
#   bash tools/build_pc.sh      (run from the project folder)
# Needs Godot's 4.7.2 export templates (Editor > Manage Export Templates, or
# the official .tpz unpacked into %APPDATA%/Godot/export_templates/4.7.2.stable).
set -e
cd "$(dirname "$0")/.."
GODOT="${GODOT:-D:/Godot/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe}"
TPL="$APPDATA/Godot/export_templates/4.7.2.stable"
if [ ! -f "$TPL/windows_release_x86_64.exe" ]; then
  echo "Missing Windows export templates in $TPL (see the comment at the top of this script)." >&2
  exit 1
fi
mkdir -p build/pc
"$GODOT" --headless --path . --import > /dev/null 2>&1 || true
"$GODOT" --headless --path . --export-release "Windows Desktop" build/pc/LavaWarlocks.exe
ls -l build/pc/LavaWarlocks.exe
echo "Built build/pc/LavaWarlocks.exe"
