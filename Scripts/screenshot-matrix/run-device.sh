#!/bin/bash
# run-device.sh <udid> <ios-slug> <device-slug> <device-label> [themes: all|key]
# Walks a device's themes, capturing the deep-linkable views for each.
#
# The fifth argument picks the theme list only. Views used to be narrowed here
# too — "keyonly" meant fewer themes AND fewer screens — but those are separate
# questions: an iPad can afford every theme while still being unable to run the
# phone-calibrated compose flow. devices.txt now carries a column for each.
set -uo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

: "${IDB_BIN:?set IDB_BIN}"
UDID="$1"; IOS="$2"; DEV="$3"; DEVLABEL="$4"

if [ "${5:-all}" = key ]; then
    THEME_LIST="$SCRIPT_DIR/themes-key.txt"
else
    THEME_LIST="$SCRIPT_DIR/themes.txt"
fi

while IFS='|' read -r raw slug dark; do
    case "$raw" in \#*|"") continue ;; esac
    # THEME_FILTER comes from run-all.sh --themes, for re-capturing one theme.
    if [ -n "${THEME_FILTER:-}" ]; then
        case ",${THEME_FILTER}," in *",$slug,"*) ;; *) continue ;; esac
    fi
    echo "=== $slug ($raw) on $DEV"
    "$SCRIPT_DIR/capture-theme.sh" "$UDID" "$IOS" "$DEV" "$raw" "$slug" "$dark" "$DEVLABEL" \
        || echo "!! failed: $slug on $DEV"
done < "$THEME_LIST"

echo "ALL DONE $IOS/$DEV"
