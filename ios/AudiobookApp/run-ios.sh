#!/usr/bin/env bash
set -euo pipefail

# One-command runner for simulator builds.
# Usage:
#   ./run-ios.sh
#   DEVICE_ID=<UDID> ./run-ios.sh
#   DEVICE_NAME="iPhone 17 Pro" ./run-ios.sh

PROJECT_ROOT="$(cd "$(dirname "$0")" && pwd)"
cd "$PROJECT_ROOT"

DEFAULT_DEVICE_NAME="iPhone 17 Pro"
DEVICE_NAME="${DEVICE_NAME:-$DEFAULT_DEVICE_NAME}"
DEVICE_ID="${DEVICE_ID:-}"

if ! command -v xcrun >/dev/null 2>&1; then
    echo "error: xcrun not found. Install Xcode command line tools first."
    exit 1
fi

if ! command -v xcodebuild >/dev/null 2>&1; then
    echo "error: xcodebuild not found. Install full Xcode first."
    exit 1
fi

if [ -z "$DEVICE_ID" ]; then
    DEVICE_ID="$(xcrun simctl list devices available | awk -v name="$DEVICE_NAME" '
        $0 ~ name" " && $0 ~ /\(Shutdown\)|\(Booted\)/ {
            match($0, /\(([0-9A-F-]+)\)/, m)
            if (m[1] != "") {
                print m[1]
                exit
            }
        }
    ')"
fi

if [ -z "$DEVICE_ID" ]; then
    echo "error: could not resolve simulator device."
    echo "hint: set DEVICE_ID explicitly, for example:"
    echo "  DEVICE_ID=FD1D4F72-038A-4963-A062-C435FA1ED3C6 ./run-ios.sh"
    exit 1
fi

echo "Using simulator: $DEVICE_ID"
open -a Simulator || true
xcrun simctl boot "$DEVICE_ID" >/dev/null 2>&1 || true

# Package.swift project usually exposes this scheme in Xcode.
SCHEME="AudiobookApp"

BUILD_LOG="$(mktemp -t audiobookapp-build.XXXXXX.log)"

echo "Building scheme: $SCHEME"
if ! xcodebuild \
    -scheme "$SCHEME" \
    -destination "id=$DEVICE_ID" \
    -configuration Debug \
    build >"$BUILD_LOG" 2>&1; then
    echo "error: build failed."
    echo "--- build tail ---"
    tail -n 60 "$BUILD_LOG"
    exit 1
fi

APP_PATH="$(find "$PROJECT_ROOT"/build/Build/Products/Debug-iphonesimulator -maxdepth 1 -type d -name "*.app" | head -n 1)"
if [ -z "$APP_PATH" ]; then
    echo "error: no .app bundle found under build/Build/Products/Debug-iphonesimulator"
    echo "hint: open Package.swift in Xcode and run once, then retry this script."
    exit 1
fi

BUNDLE_ID="$(/usr/libexec/PlistBuddy -c "Print :CFBundleIdentifier" "$APP_PATH/Info.plist" 2>/dev/null || true)"
if [ -z "$BUNDLE_ID" ]; then
    echo "error: failed to resolve CFBundleIdentifier from $APP_PATH/Info.plist"
    exit 1
fi

echo "Installing: $APP_PATH"
xcrun simctl install "$DEVICE_ID" "$APP_PATH"

echo "Launching: $BUNDLE_ID"
xcrun simctl launch "$DEVICE_ID" "$BUNDLE_ID"

echo "Done."
