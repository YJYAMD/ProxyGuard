#!/usr/bin/env bash
set -e

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

echo "==> Building VPN监控..."
bash "$DIR/scripts/build.sh"

echo "==> Stopping running instance (if any)..."
pkill -f "Contents/MacOS/ProxyGuard" 2>/dev/null || true
sleep 0.5

echo "==> Installing to /Applications/VPN监控.app..."
rm -rf "/Applications/ProxyGuard.app" "/Applications/VPN监控.app"
cp -r "$DIR/build/VPN监控.app" "/Applications/VPN监控.app"

echo "==> Launching VPN监控..."
open "/Applications/VPN监控.app"

echo "==> Successfully installed and launched VPN监控!"
