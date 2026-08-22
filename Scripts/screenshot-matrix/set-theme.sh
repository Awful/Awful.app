#!/bin/bash
# set-theme.sh <udid> <theme-raw-value> <dark:0|1>
# Sets the Awful app's global theme and relaunches the app.
#
# Note: the app's preferences live in its sandboxed data container, NOT in the
# simulator's global defaults domain — `simctl spawn <udid> defaults write` goes
# to the wrong place. We edit the container plist directly, with the app
# terminated and the simulator's cfprefsd stopped so it can't flush a stale
# cached copy over our writes.
set -euo pipefail

UDID="$1"
THEME="$2"
DARK="$3"
BUNDLE_ID="com.awfulapp.Awful.debug"

xcrun simctl terminate "$UDID" "$BUNDLE_ID" 2>/dev/null || true
sleep 1

CONTAINER=$(xcrun simctl get_app_container "$UDID" "$BUNDLE_ID" data)
PLIST="$CONTAINER/Library/Preferences/$BUNDLE_ID.plist"

xcrun simctl spawn "$UDID" launchctl stop com.apple.cfprefsd.xpc.daemon 2>/dev/null || true
sleep 1

set_key() { # set_key <key> <type> <value>
    plutil -replace "$1" "-$2" "$3" "$PLIST" 2>/dev/null \
        || plutil -insert "$1" "-$2" "$3" "$PLIST"
}

set_key auto_dark_theme bool false
if [ "$DARK" = "1" ]; then
    set_key dark_theme bool true
    set_key default_dark_theme_name string "$THEME"
else
    set_key dark_theme bool false
    set_key default_light_theme_name string "$THEME"
fi
# Forum-specific overrides would shadow the global theme in those forums.
for key in theme-25 theme-26 theme-219 theme-268; do
    plutil -remove "$key" "$PLIST" 2>/dev/null || true
done

# Scrub real titles out of the list views while the app is down and cfprefsd
# is stopped. SCRUB=0 skips (captures live data). Failure is fatal: silently
# capturing real bookmark/PM titles is worse than a failed theme.
if [ "${SCRUB:-1}" != "0" ]; then
    "$(dirname "${BASH_SOURCE[0]}")/scrub-lists.sh" "$UDID"
fi

xcrun simctl launch "$UDID" "$BUNDLE_ID" >/dev/null
sleep 4
