#!/bin/bash
# capture-theme.sh <udid> <ios-slug> <device-slug> <theme-raw> <theme-slug> <dark:0|1> <device-label>
# Sets the theme, then captures + labels every deep-linkable view for it.
# These are all plain deep links, so every device gets the same ten; what
# varies per device is how many THEMES it runs (devices.txt) and whether it
# also runs the tap-driven views (capture-interactive.sh).
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

UDID="$1"; IOS="$2"; DEV="$3"; THEME_RAW="$4"; THEME="$5"; DARK="$6"; DEVLABEL="$7"

OUT="$OUT_ROOT/${IOS}-${DEV}/${THEME}"
mkdir -p "$OUT"

"$SCRIPT_DIR/set-theme.sh" "$UDID" "$THEME_RAW" "$DARK"

# Views that pull remote content pass "content" as $4, so nav.sh keeps waiting
# when the screen has settled on a spinner rather than on the page. Screens
# that are legitimately sparse — an empty rap sheet, a bare settings form —
# must NOT ask for it, or they wait out the whole budget every time.
shot() { # shot <NN-slug> <url> <settle> [content]
    local name="$1" url="$2" settle="${3:-4}" expect="${4:-}"
    # Skipping here rather than at the call sites keeps the shot list readable
    # and its per-view settle times in one place.
    want "$name" || return 0
    local f="$OUT/${IOS}_${DEV}_${THEME}_${name}.png"
    "$SCRIPT_DIR/nav.sh" "$UDID" "$url" "$settle" "$expect"
    xcrun simctl io "$UDID" screenshot "$f" >/dev/null 2>&1
    # simctl grabs the portrait-native framebuffer, so a landscape iPad comes
    # out sideways. ROTATE turns it upright before the label goes on.
    [ -n "${ROTATE:-}" ] && [ "${ROTATE}" != "0" ] && magick "$f" -rotate "$ROTATE" "$f"
    "$SCRIPT_DIR/label.sh" "$f" "$DEVLABEL · ${THEME_RAW} · ${name#*-}"
    echo "  $name"
}

shot 01-forums-list   "awful://forums"                          4
shot 02-thread-list   "awful://forums/$FORUM_ID"                5   content
shot 03-posts-view    "awful://threads/$THREAD_ID/pages/last"   7   content
shot 04-bookmarks     "awful://bookmarks"                       5   content
shot 05-pm-list       "awful://messages"                        4   content
shot 07-settings      "awful://settings"                        4

shot 09-lepers-colony "awful://banlist"                     6
shot 10-profile       "awful://users/$OWN_USER_ID"          5
shot 11-rap-sheet     "awful://banlist/$OWN_USER_ID"        5
shot 19-poll-thread   "awful://threads/$POLL_THREAD_ID"     7   content

echo "done: $THEME on $IOS/$DEV"
