#!/bin/bash
# Relaunch the built app and sample CPU, energy impact and wakeups for Mnemo and its WebKit helpers.
# Usage: sh desktop/tools/measure-energy.sh <output.txt> [seconds=150]
# Leave the ghost untouched while it runs; hovering or dragging switches him to 30 fps.
set -eu
TOOLS=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
APP="$(dirname "$TOOLS")/build/Mnemo.app"
OUT=$1; SECONDS_TO_SAMPLE=${2:-150}
pkill -f Mnemo.app/Contents/MacOS/Mnemo || true; sleep 3
BEFORE=$(mktemp); AFTER=$(mktemp)
pgrep -f com.apple.WebKit | sort > "$BEFORE"; open "$APP"; sleep 8; pgrep -f com.apple.WebKit | sort > "$AFTER"
PIDS=($(pgrep -f Mnemo.app/Contents/MacOS/Mnemo) $(comm -13 "$BEFORE" "$AFTER")); rm -f "$BEFORE" "$AFTER"
ARGS=(); for p in "${PIDS[@]}"; do ARGS+=(-pid "$p"); done
top -l $((SECONDS_TO_SAMPLE/2+1)) -s 2 "${ARGS[@]}" -stats pid,command,cpu,mem,power,idlew > "$OUT" 2>&1
echo "${PIDS[@]}" > "$OUT.pids"
python3 -I "$TOOLS/summarise-top.py" "$OUT" ${PIDS[@]}
