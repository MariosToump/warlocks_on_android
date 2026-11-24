#!/bin/bash
# Build the debug APK and install + launch it on the USB-connected phone.
#   bash tools/deploy_android.sh      (run from the project folder)
set -e
GODOT="/d/Godot/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64.exe"
ADB="$LOCALAPPDATA/Android/Sdk/platform-tools/adb.exe"
mkdir -p build
"$GODOT" --headless --path . --import > /dev/null 2>&1 || true
"$GODOT" --headless --path . --export-debug "Android" build/warlocks_on_android.apk
"$ADB" start-server >/dev/null 2>&1; "$ADB" wait-for-device
"$ADB" install -r build/warlocks_on_android.apk || "$ADB" install -r build/warlocks_on_android.apk
"$ADB" shell monkey -p com.lavawarlocks.game -c android.intent.category.LAUNCHER 1 > /dev/null
echo "Installed and launched on the phone."
