#!/bin/sh
set -eu
DESKTOP_ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
CHECK_ROOT=$(mktemp -d /tmp/mnemo-menu-check.XXXXXX)
trap 'rm -rf "$CHECK_ROOT"' EXIT
# Reuse the production delegate, replacing only the app's event-loop bootstrap.
python3 - "$DESKTOP_ROOT" "$CHECK_ROOT/main.swift" <<'PY'
from pathlib import Path
import sys
root=Path(sys.argv[1])
source=(root/'Sources/main.swift').read_text().split('\nlet app=NSApplication.shared\n')[0]
Path(sys.argv[2]).write_text(source+'\n'+(root/'tests/menu-check.swift').read_text())
PY
swiftc -swift-version 5 -module-cache-path /tmp/mnemo-swift-cache \
  -framework ScreenCaptureKit -framework Cocoa -framework WebKit -framework UserNotifications -framework ServiceManagement \
  "$DESKTOP_ROOT/Sources/SpotifyLibrary.swift" "$DESKTOP_ROOT/Sources/SpotifyPlayback.swift" "$DESKTOP_ROOT/Sources/SettingsWindow.swift" "$DESKTOP_ROOT/Sources/AppLifecycle.swift" "$DESKTOP_ROOT/Sources/ReminderStore.swift" "$DESKTOP_ROOT/Sources/MenuIcon.swift" \
  "$DESKTOP_ROOT/Sources/BackgroundColour.swift" "$CHECK_ROOT/main.swift" -o "$CHECK_ROOT/check"
"$CHECK_ROOT/check"
