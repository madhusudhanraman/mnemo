#!/bin/sh
# Install the verified build at the stable per-user Applications location.
set -eu
DESKTOP_ROOT=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
SOURCE_APP="$DESKTOP_ROOT/build/Mnemo.app"
APP_ROOT="$HOME/Applications"
DESTINATION="$APP_ROOT/Mnemo.app"
if pgrep -u "$(id -u)" -f '/Mnemo.app/Contents/MacOS/Mnemo( |$)' >/dev/null; then
  printf '%s\n' 'Quit Mnemo before installing.' >&2
  exit 1
fi
[ ! -L "$DESTINATION" ] || { printf '%s\n' 'The installed app must not be a symbolic link.' >&2; exit 1; }
[ "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$SOURCE_APP/Contents/Info.plist")" = 'local.mnemo.companion' ]
codesign --verify --strict "$SOURCE_APP"
mkdir -p "$APP_ROOT"
STAGING=$(mktemp -d "$APP_ROOT/.mnemo-install.XXXXXX")
cleanup() {
  result=$?
  trap - EXIT
  if [ "$result" -ne 0 ] && [ -d "$STAGING/previous.app" ]; then
    rm -rf "$DESTINATION"
    mv "$STAGING/previous.app" "$DESTINATION"
  fi
  rm -rf "$STAGING"
  exit "$result"
}
trap cleanup EXIT
trap 'exit 1' HUP INT TERM
ditto "$SOURCE_APP" "$STAGING/Mnemo.app"
codesign --verify --strict "$STAGING/Mnemo.app"
if [ -e "$DESTINATION" ]; then mv "$DESTINATION" "$STAGING/previous.app"; fi
mv "$STAGING/Mnemo.app" "$DESTINATION"
codesign --verify --strict "$DESTINATION"
printf 'Installed %s\n' "$DESTINATION"
