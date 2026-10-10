#!/usr/bin/env bash
set -e

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_DIR="$DIR/build"
APP_BUNDLE="$BUILD_DIR/ProxyGuard.app"
MACOS_DIR="$APP_BUNDLE/Contents/MacOS"

echo "==> Building ProxyGuard for macOS..."
rm -rf "$BUILD_DIR"
mkdir -p "$MACOS_DIR"

# Copy Info.plist
cp "$DIR/Info.plist" "$APP_BUNDLE/Contents/Info.plist"

# Compile Swift binary (Optimized)
echo "==> Compiling Swift source..."
swiftc -O -o "$MACOS_DIR/ProxyGuard" "$DIR/Sources/main.swift"

# Package as Release Zip
echo "==> Packaging Release archive..."
cd "$BUILD_DIR"
zip -qry "ProxyGuard-macOS.zip" "ProxyGuard.app"

echo "==> Build succeeded: $APP_BUNDLE"
echo "==> Release archive: $BUILD_DIR/ProxyGuard-macOS.zip"
