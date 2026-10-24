#!/bin/sh
set -eu
DESKTOP_ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
CHECK_ROOT=$(mktemp -d /tmp/mnemo-spotify-check.XXXXXX)
trap 'rm -rf "$CHECK_ROOT"' EXIT
swiftc -swift-version 5 -module-cache-path /tmp/mnemo-swift-cache -framework Cocoa "$DESKTOP_ROOT/Sources/SpotifyLibrary.swift" "$DESKTOP_ROOT/tests/spotify/main.swift" -o "$CHECK_ROOT/check"
"$CHECK_ROOT/check"
