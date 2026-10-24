#!/bin/sh
set -eu
DESKTOP_ROOT=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
WORKSPACE_ROOT=$(dirname "$DESKTOP_ROOT")
APP_DIR="$DESKTOP_ROOT/build/Mnemo.app"
# A local identity file pins development builds; signing errors stop the build.
MNEMO_SIGNING_IDENTITY=${MNEMO_SIGNING_IDENTITY:-}
if [ -z "$MNEMO_SIGNING_IDENTITY" ] && [ -f "$DESKTOP_ROOT/signing-identity.local" ]; then
  MNEMO_SIGNING_IDENTITY=$(cat "$DESKTOP_ROOT/signing-identity.local")
fi
if [ -z "$MNEMO_SIGNING_IDENTITY" ]; then
  MNEMO_SIGNING_IDENTITY=$(security find-identity -v -p codesigning 2>/dev/null | awk '/"Mnemo Local Development"|"Marginstone Local Development"/ {print $2; exit}')
fi
MNEMO_SIGNING_IDENTITY=${MNEMO_SIGNING_IDENTITY:--}
mkdir -p "$APP_DIR/Contents/MacOS" "$APP_DIR/Contents/Resources" /tmp/mnemo-swift-cache
cp "$WORKSPACE_ROOT/prototype/ghost.html" "$APP_DIR/Contents/Resources/ghost.html"
cp "$WORKSPACE_ROOT/prototype/editor.html" "$APP_DIR/Contents/Resources/editor.html"
cp "$WORKSPACE_ROOT/prototype/sizes.html" "$APP_DIR/Contents/Resources/sizes.html"
cp "$DESKTOP_ROOT/Assets/Mnemo.icns" "$APP_DIR/Contents/Resources/Mnemo.icns"
cp "$DESKTOP_ROOT/Info.plist" "$APP_DIR/Contents/Info.plist"
swiftc -swift-version 5 -O -module-cache-path /tmp/mnemo-swift-cache \
  -framework ScreenCaptureKit -framework Cocoa -framework WebKit -framework UserNotifications -framework ServiceManagement \
  "$DESKTOP_ROOT/Sources/SpotifyLibrary.swift" "$DESKTOP_ROOT/Sources/SpotifyPlayback.swift" "$DESKTOP_ROOT/Sources/SettingsWindow.swift" "$DESKTOP_ROOT/Sources/AppLifecycle.swift" "$DESKTOP_ROOT/Sources/ReminderStore.swift" "$DESKTOP_ROOT/Sources/MenuIcon.swift" "$DESKTOP_ROOT/Sources/BackgroundColour.swift" "$DESKTOP_ROOT/Sources/main.swift" \
  -o "$APP_DIR/Contents/MacOS/Mnemo"
if [ "$MNEMO_SIGNING_IDENTITY" = "-" ]; then
  printf '%s\n' 'Warning: ad-hoc signing. Screen Recording permission may need granting again after rebuilding.' >&2
fi
codesign --force --sign "$MNEMO_SIGNING_IDENTITY" "$APP_DIR"
codesign --verify --strict "$APP_DIR"
printf 'Built %s\n' "$APP_DIR"
