#!/bin/sh
set -eu
DESKTOP_ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
CHECK_ROOT=$(mktemp -d /tmp/mnemo-startup-check.XXXXXX)
trap 'rm -rf "$CHECK_ROOT"' EXIT
swiftc -swift-version 5 -module-cache-path /tmp/mnemo-swift-cache -framework Cocoa -framework ServiceManagement \
  "$DESKTOP_ROOT/Sources/AppLifecycle.swift" "$DESKTOP_ROOT/tests/startup/main.swift" -o "$CHECK_ROOT/check"
"$CHECK_ROOT/check"
