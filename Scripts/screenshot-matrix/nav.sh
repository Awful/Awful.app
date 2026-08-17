#!/bin/bash
# nav.sh <udid> <awful-url> [settle-seconds]
# Opens a deep link and dismisses SpringBoard's "Open in <app>?" confirmation,
# which simctl/idb both trigger for custom URL schemes and which would
# otherwise sit on top of every screenshot.
#
# The settle argument used to be a flat sleep, sized for the slowest case. That
# is wrong in both directions: too long for screens that render instantly, and
# too short under load — capturing four simulators at once produced a genuinely
# blank poll thread because 7s was no longer enough. It now polls the screen
# and returns once two consecutive screenshots are effectively identical,
# treating the argument as a timeout budget rather than a duration. Runs get
# both more reliable and usually faster.
#
# Set ADAPTIVE_SETTLE=0 to go back to the flat sleep.
set -euo pipefail

IDB="${IDB_BIN:?IDB_BIN must point at the idb client}"
UDID="$1"
URL="$2"
SETTLE="${3:-4}"

# A sheet left over from the previous shot (the profile modal, say) swallows the
# next deep link, so close anything modal before navigating.
DONE_COORDS=$("$IDB" ui describe-all --udid "$UDID" 2>/dev/null | python3 -c "
import sys, json
try:
    data = json.load(sys.stdin)
except Exception:
    sys.exit(0)
for d in data:
    if d.get('AXLabel') == 'Done' and d.get('type') == 'Button' and d.get('enabled'):
        f = d['frame']
        print(int(f['x'] + f['width'] / 2), int(f['y'] + f['height'] / 2))
        break
" || true)
if [ -n "$DONE_COORDS" ]; then
    # shellcheck disable=SC2086
    "$IDB" ui tap --udid "$UDID" $DONE_COORDS 2>/dev/null || true
    sleep 1
fi

xcrun simctl openurl "$UDID" "$URL"
sleep 1.5

# The confirmation is a SpringBoard alert; find the Open button and tap its centre.
COORDS=$("$IDB" ui describe-all --udid "$UDID" 2>/dev/null | python3 -c "
import sys, json
try:
    data = json.load(sys.stdin)
except Exception:
    sys.exit(0)
for d in data:
    if d.get('AXLabel') == 'Open' and d.get('type') == 'Button':
        f = d['frame']
        print(int(f['x'] + f['width'] / 2), int(f['y'] + f['height'] / 2))
        break
" || true)

if [ -n "$COORDS" ]; then
    # shellcheck disable=SC2086
    "$IDB" ui tap --udid "$UDID" $COORDS 2>/dev/null || true
fi

# Wait for the screen to stop changing, up to a budget. Two consecutive quiet
# samples rather than one: a slow screen can pause mid-render (nav bar drawn,
# post content still coming) and a single comparison would call that settled.
# The threshold is not zero because the clock, cursors and spinners never
# actually stop — it is "nothing meaningful moved".
STABLE_THRESHOLD="${STABLE_THRESHOLD:-0.0008}"
STABLE_INTERVAL="${STABLE_INTERVAL:-0.5}"
STABLE_HITS="${STABLE_HITS:-2}"

wait_until_stable() { # wait_until_stable <max-seconds>
    local max="$1" tmp a b diff hits=0 n=0 iters
    # The budget is in seconds and the interval may be fractional, so turn it
    # into an iteration count in awk — bash arithmetic is integer-only and
    # `waited + 0.5` is a syntax error, not a rounding problem.
    iters=$(awk -v m="$max" -v i="$STABLE_INTERVAL" \
            'BEGIN { printf "%d", (i > 0 ? m / i : m) }')
    [ "${iters:-0}" -lt 1 ] && iters=1

    tmp=$(mktemp -d); a="$tmp/a.png"; b="$tmp/b.png"
    xcrun simctl io "$UDID" screenshot "$a" >/dev/null 2>&1 || { rm -rf "$tmp"; return 1; }

    while [ "$n" -lt "$iters" ]; do
        sleep "$STABLE_INTERVAL"
        n=$((n + 1))
        xcrun simctl io "$UDID" screenshot "$b" >/dev/null 2>&1 || break
        # Compare downscaled: full-res diffing a 1206x2666 pair costs more than
        # the wait it is meant to shorten, and shrinking also discards the
        # sub-pixel noise we do not care about.
        diff=$(magick "$a" "$b" -resize 25% -compose difference -composite \
               -colorspace Gray -format '%[fx:mean]' info: 2>/dev/null)
        [ -z "$diff" ] && diff=1
        if awk -v d="$diff" -v t="$STABLE_THRESHOLD" 'BEGIN { exit !(d < t) }'; then
            hits=$((hits + 1))
            [ "$hits" -ge "$STABLE_HITS" ] && { rm -rf "$tmp"; return 0; }
        else
            hits=0
        fi
        mv "$b" "$a"
    done

    rm -rf "$tmp"
    return 1
}

if [ "${ADAPTIVE_SETTLE:-1}" = "0" ]; then
    sleep "$SETTLE"
else
    # Give the transition a moment to start, so we never sample two identical
    # frames of the *previous* screen and call it settled.
    sleep 1
    # Budget is generous compared with the old fixed wait: timing out here is
    # not fatal, it just means capturing whatever is on screen, as before.
    wait_until_stable "$(( SETTLE * 3 ))" || true
fi
