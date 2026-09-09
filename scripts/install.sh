#!/bin/zsh
set -eu

ROOT="${0:A:h:h}"
SOURCE_APP="$ROOT/build/Sub2API Monitor.app"
TARGET_APP="/Applications/Sub2API Monitor.app"
TARGET_BINARY="$TARGET_APP/Contents/MacOS/Sub2APIMonitor"
NATIVE_KEYCHAIN_SERVICE="co.agenticai.sub2api-monitor"
LEGACY_KEYCHAIN_SERVICE="co.agenticai.sub2api-menubar"

if [[ ! -d "$SOURCE_APP" ]]; then
  "$ROOT/scripts/package.sh" >/dev/null
fi

/usr/bin/pkill -x Sub2APIMonitor 2>/dev/null || true
/usr/bin/ditto "$SOURCE_APP" "$TARGET_APP"

/usr/bin/codesign --verify --deep --strict "$TARGET_APP"

if ! /usr/bin/security find-generic-password \
  -a admin \
  -s "$NATIVE_KEYCHAIN_SERVICE" >/dev/null 2>&1; then
  legacy_key=$(/usr/bin/security find-generic-password \
    -a "$USER" \
    -s "$LEGACY_KEYCHAIN_SERVICE" \
    -w 2>/dev/null || true)
  if [[ -n "$legacy_key" ]]; then
    print -r -- "$legacy_key"$'\n'"$legacy_key" | /usr/bin/security add-generic-password \
      -U \
      -a admin \
      -s "$NATIVE_KEYCHAIN_SERVICE" \
      -l "Sub2API Monitor Admin Key" \
      -T "$TARGET_BINARY" \
      -w >/dev/null
    legacy_key=""
    print "Migrated the existing Admin API Key to the native app."
  fi
fi

/usr/bin/open -a "$TARGET_APP"
print "Installed and opened $TARGET_APP"
