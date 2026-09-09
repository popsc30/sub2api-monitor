#!/bin/zsh
set -eu

ROOT="${0:A:h:h}"
INFO_PLIST="$ROOT/Resources/Info.plist"
VERSION="${1:-$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$INFO_PLIST")}"
APP="$ROOT/build/Sub2API Monitor.app"
BINARY="$APP/Contents/MacOS/Sub2APIMonitor"
DIST="$ROOT/dist"

if [[ "$VERSION" != <->.<->.<-> ]]; then
  print -u2 "Version must use semantic versioning, for example 1.0.0."
  exit 1
fi

"$ROOT/scripts/package.sh" >/dev/null
/usr/bin/codesign --verify --deep --strict "$APP"

architectures="$(/usr/bin/lipo -archs "$BINARY")"
case "$architectures" in
  (arm64) architecture="arm64" ;;
  (x86_64) architecture="x86_64" ;;
  (*) architecture="universal" ;;
esac

archive_name="Sub2API-Monitor-v${VERSION}-macos-${architecture}.zip"
/bin/mkdir -p "$DIST"
if [[ -e "$DIST/$archive_name" || -e "$DIST/$archive_name.sha256" ]]; then
  print -u2 "Release output already exists in $DIST."
  exit 1
fi
/usr/bin/ditto -c -k --sequesterRsrc --keepParent "$APP" "$DIST/$archive_name"
(
  cd "$DIST"
  /usr/bin/shasum -a 256 "$archive_name" > "$archive_name.sha256"
)

print -r -- "$DIST/$archive_name"
print -r -- "$DIST/$archive_name.sha256"
