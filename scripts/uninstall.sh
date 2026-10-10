#!/usr/bin/env bash
set -e

echo "==> Stopping ProxyGuard..."
pkill -f "ProxyGuard.app/Contents/MacOS/ProxyGuard" 2>/dev/null || true

echo "==> Removing Login Item (if enabled)..."
rm -f "$HOME/Library/LaunchAgents/com.yjy.proxyguard.plist" 2>/dev/null || true

echo "==> Removing /Applications/ProxyGuard.app..."
rm -rf "/Applications/ProxyGuard.app"

echo "==> Successfully uninstalled ProxyGuard."
