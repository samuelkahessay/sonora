#!/usr/bin/env bash
set -euo pipefail

# Usage: build_run_sim.sh <projectPath.xcodeproj> <scheme> <simulatorName>
if [[ $# -lt 3 ]]; then
  echo "Usage: $0 <projectPath.xcodeproj> <scheme> <simulatorName>" >&2
  exit 1
fi

PROJ="$1"; SCHEME="$2"; SIM="$3"
DEST="platform=iOS Simulator,name=${SIM}"

# Build first
echo "[info] Building \"$SCHEME\" for \"$SIM\""
set -x
xcodebuild -project "$PROJ" -scheme "$SCHEME" -destination "$DEST" -configuration Debug build | xcbeautify || true
set +x

# Extract TARGET_BUILD_DIR and WRAPPER_NAME
echo "[info] Resolving build products path..."
BUILD_SETTINGS=$(xcodebuild -project "$PROJ" -scheme "$SCHEME" -destination "$DEST" -showBuildSettings)
TARGET_BUILD_DIR=$(echo "$BUILD_SETTINGS" | awk -F= '/ TARGET_BUILD_DIR /{gsub(/^ +| +$/,"",$2); print $2; exit}')
WRAPPER_NAME=$(echo "$BUILD_SETTINGS" | awk -F= '/ WRAPPER_NAME /{gsub(/^ +| +$/,"",$2); print $2; exit}')

APP_PATH="${TARGET_BUILD_DIR}/${WRAPPER_NAME}"
if [[ ! -d "$APP_PATH" ]]; then
  echo "[warn] Could not find app via build settings; falling back to search" >&2
  APP_PATH=$(find "$HOME/Library/Developer/Xcode/DerivedData" -type d -name "${SCHEME}.app" -print -quit 2>/dev/null || true)
fi

if [[ -z "$APP_PATH" || ! -d "$APP_PATH" ]]; then
  echo "[error] .app not found after build" >&2
  exit 2
fi

echo "[info] Built app: $APP_PATH"

# Boot simulator and get UUID
SIM_UUID=$(xcrun simctl list devices --json | python3 -c "import sys,json; d=json.load(sys.stdin); print(next((dev['udid'] for runt in d['devices'].values() for dev in runt if dev['name']=='${SIM}' and dev['isAvailable']), '' )) )")
if [[ -z "$SIM_UUID" ]]; then
  echo "[error] Simulator \"$SIM\" not found" >&2
  exit 3
fi

echo "[info] Booting simulator $SIM ($SIM_UUID)"
xcrun simctl boot "$SIM_UUID" || true
open -a Simulator.app || true

# Install and launch
echo "[info] Installing app..."
xcrun simctl install "$SIM_UUID" "$APP_PATH" || true

# Resolve bundle id
INFO_PLIST="$APP_PATH/Info.plist"
BUNDLE_ID=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$INFO_PLIST")
if [[ -z "$BUNDLE_ID" ]]; then
  echo "[error] Failed to read CFBundleIdentifier from $INFO_PLIST" >&2
  exit 4
fi

echo "[info] Launching $BUNDLE_ID"
xcrun simctl launch "$SIM_UUID" "$BUNDLE_ID" || true

printf '{"status":"ok","simulatorUuid":"%s","appPath":"%s","bundleId":"%s"}\n' "$SIM_UUID" "$APP_PATH" "$BUNDLE_ID"

