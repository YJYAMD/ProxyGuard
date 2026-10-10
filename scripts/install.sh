#!/usr/bin/env bash
set -e

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

echo "==> Building ProxyGuard..."
bash "$DIR/scripts/build.sh"

echo "==> Stopping running instance (if any)..."
pkill -f "ProxyGuard.app/Contents/MacOS/ProxyGuard" 2>/dev/null || true
sleep 0.5

echo "==> Installing to /Applications/ProxyGuard.app..."
rm -rf "/Applications/ProxyGuard.app"
cp -r "$DIR/build/ProxyGuard.app" "/Applications/ProxyGuard.app"

echo "==> Launching ProxyGuard..."
open "/Applications/ProxyGuard.app"

echo "==> Successfully installed and launched ProxyGuard!"
