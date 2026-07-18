#!/usr/bin/env bash
# pull_ios_container.sh
# Requires Xcode installed and the device connected. Downloads the app container and extracts the user data.
# Usage: ./pull_ios_container.sh "BundleID" "output_dir"

BUNDLE_ID="$1"
OUT_DIR="$2"

if [ -z "$BUNDLE_ID" ] || [ -z "$OUT_DIR" ]; then
  echo "Usage: $0 <App Bundle ID> <output_dir>"
  exit 1
fi

mkdir -p "$OUT_DIR"

echo "Downloading container for $BUNDLE_ID..."
# This uses xcrun simctl for simulator or ideviceinstaller/ios-deploy for device; here we show Xcode command for device using xcrun
# For physical device, you may need to use Xcode's Devices and Simulators window or libimobiledevice tools.

xcrun simctl get_app_container booted "$BUNDLE_ID" data > /dev/null 2>&1
if [ $? -eq 0 ]; then
  echo "Simulator detected: copying container..."
  xcrun simctl get_app_container booted "$BUNDLE_ID" data "$OUT_DIR"
  echo "Container copied to $OUT_DIR"
else
  echo "No simulator container found. Please use Xcode -> Devices and Simulators -> Download Container, or use libimobiledevice tools for a physical device."
fi
