#!/usr/bin/env bash
set -euo pipefail

# One-command runner for simulator builds.
# Usage:
#   ./run-ios.sh
#   DEVICE_ID=<UDID> ./run-ios.sh
#   DEVICE_NAME="iPhone 17 Pro" ./run-ios.sh

PROJECT_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
XCODE_DIR="$(cd "$(dirname "$0")" && pwd)"
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

if [ ! -d "$XCODE_DIR/AudiobookApp.xcodeproj" ]; then
    echo "error: missing Xcode project at $XCODE_DIR/AudiobookApp.xcodeproj"
    echo "hint: run 'cd $XCODE_DIR && xcodegen generate' first."
    exit 1
fi

if [ -z "$DEVICE_ID" ]; then
    DEVICE_ID="$(xcrun simctl list devices available \
        | awk -v name="$DEVICE_NAME" '$0 ~ name" " && ($0 ~ /\(Shutdown\)/ || $0 ~ /\(Booted\)/) { print; exit }' \
        | sed -E 's/.*\(([0-9A-F-]{36})\).*/\1/')"
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

SCHEME="AudiobookApp"
BUILD_LOG="$(mktemp -t audiobookapp-build.XXXXXX.log)"
DERIVED_DATA="${DERIVED_DATA:-/tmp/AudiobookAppDerivedData}"

echo "Building scheme: $SCHEME"
if ! xcodebuild \
    -project "$XCODE_DIR/AudiobookApp.xcodeproj" \
    -scheme "$SCHEME" \
    -destination "id=$DEVICE_ID" \
    -configuration Debug \
    -derivedDataPath "$DERIVED_DATA" \
    build >"$BUILD_LOG" 2>&1; then
    echo "error: build failed."
    echo "--- build tail ---"
    tail -n 60 "$BUILD_LOG"
    exit 1
fi

APP_PATH="$DERIVED_DATA/Build/Products/Debug-iphonesimulator/AudiobookApp.app"
if [ ! -d "$APP_PATH" ]; then
    APP_PATH="$(find "$DERIVED_DATA/Build/Products/Debug-iphonesimulator" -maxdepth 1 -type d -name "*.app" | head -n 1 || true)"
fi
if [ -z "$APP_PATH" ] || [ ! -d "$APP_PATH" ]; then
    echo "error: no .app bundle found under $DERIVED_DATA/Build/Products/Debug-iphonesimulator"
    echo "hint: check build output above and confirm scheme '$SCHEME' is an app-runnable scheme."
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
