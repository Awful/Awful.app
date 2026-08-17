#!/bin/bash
# run-interactive.sh <udid> <ios-slug> <device-slug> <device-label>
# Walks every theme capturing the tap-driven views. Phone-sized screens only —
# see the coordinate note in capture-interactive.sh.
set -uo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

: "${IDB_BIN:?set IDB_BIN}"
UDID="$1"; IOS="$2"; DEV="$3"; DEVLABEL="$4"

while IFS='|' read -r raw slug dark; do
    case "$raw" in \#*|"") continue ;; esac
    if [ -n "${THEME_FILTER:-}" ]; then
        case ",${THEME_FILTER}," in *",$slug,"*) ;; *) continue ;; esac
    fi
    echo "=== $slug ($raw) on $DEV"
    "$SCRIPT_DIR/set-theme.sh" "$UDID" "$raw" "$dark" || { echo "!! theme failed: $slug"; continue; }
    "$SCRIPT_DIR/capture-interactive.sh" "$UDID" "$IOS" "$DEV" "$slug" "$DEVLABEL" \
        || echo "!! interactive failed: $slug on $DEV"
done < "$SCRIPT_DIR/themes.txt"

echo "ALL DONE interactive $IOS/$DEV"
