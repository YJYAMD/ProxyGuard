#!/usr/bin/env bash
set -e

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_DIR="$DIR/build"
APP_BUNDLE="$BUILD_DIR/VPN监控.app"
MACOS_DIR="$APP_BUNDLE/Contents/MacOS"
RESOURCES_DIR="$APP_BUNDLE/Contents/Resources"

echo "==> Building VPN监控 for macOS..."
rm -rf "$BUILD_DIR"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"

# Copy Info.plist and AppIcon.icns
cp "$DIR/Info.plist" "$APP_BUNDLE/Contents/Info.plist"
if [ -f "$DIR/assets/AppIcon.icns" ]; then
    cp "$DIR/assets/AppIcon.icns" "$RESOURCES_DIR/AppIcon.icns"
fi

# Compile Swift binary (Optimized)
echo "==> Compiling Swift source..."
swiftc -O -o "$MACOS_DIR/ProxyGuard" "$DIR/Sources/main.swift"

# Package as Release Zip
echo "==> Packaging Release archive..."
cd "$BUILD_DIR"
zip -qry "VPN监控-macOS.zip" "VPN监控.app"

echo "==> Build succeeded: $APP_BUNDLE"
echo "==> Release archive: $BUILD_DIR/VPN监控-macOS.zip"
