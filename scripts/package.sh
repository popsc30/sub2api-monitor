#!/bin/zsh
set -eu

ROOT="${0:A:h:h}"
APP_NAME="Sub2API Monitor.app"
APP="$ROOT/build/$APP_NAME"
BINARY="$ROOT/.build/release/Sub2APIMonitor"

cd "$ROOT"
xcrun swift build -c release
xcrun swift "$ROOT/scripts/generate-icon.swift" "$ROOT/Resources/Sub2APIMonitor.icns"

mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
/usr/bin/install -m 755 "$BINARY" "$APP/Contents/MacOS/Sub2APIMonitor"
/usr/bin/install -m 644 "$ROOT/Resources/Info.plist" "$APP/Contents/Info.plist"
/usr/bin/install -m 644 "$ROOT/Resources/Sub2APIMonitor.icns" "$APP/Contents/Resources/Sub2APIMonitor.icns"
/usr/bin/codesign --force --deep --sign - "$APP"
print -r -- "$APP"
