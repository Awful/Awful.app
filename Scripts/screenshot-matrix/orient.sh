#!/bin/bash
# orient.sh <udid> <landscape|portrait>
# Puts a booted simulator into the requested orientation and verifies it.
#
# WHY THIS EXISTS: a headless `simctl boot` always comes up portrait. The
# stored SimulatorWindowOrientation in com.apple.iphonesimulator.plist is only
# applied when Simulator.app opens a window, so an iPad that looks landscape
# when you watch it captures as portrait when you don't. That silently rotates
# every iPad image by 90 degrees (devices.txt's `rotate` column then turns an
# upright capture sideways) AND collapses the split-view sidebar, because
# iPadOS only shows it alongside in landscape.
#
# There is no orientation command in simctl or idb, so this drives Simulator's
# own Rotate Right menu shortcut. That needs Accessibility permission for
# whichever app runs this script (System Settings > Privacy & Security >
# Accessibility) — without it osascript fails with "not allowed to send
# keystrokes" and this script says so rather than capturing a sideways matrix.
#
# The shortcut goes to the FRONTMOST simulator window, so this fronts the
# target's window first, via Simulator's own Window menu. Those entries read
# "<device name> – iOS <version>", which stays unique even though the matrix
# holds two devices both called "iPad Pro 11-inch". Without that step a stray
# booted simulator silently eats the keystroke: the target stays portrait and
# some innocent device rotates instead.
#
# Caveat: activating Simulator steals keyboard focus for a moment.
set -uo pipefail

IDB="${IDB_BIN:?IDB_BIN must point at the idb client}"
UDID="$1"
WANT="${2:-landscape}"

# SpringBoard reports the screen as a single element whose frame is the window
# in points; wider than tall means landscape. It reads 0x0 while the device is
# still coming up, which is "unknown", never "portrait" — guessing there would
# rotate an already-correct device.
probe() {
    "$IDB" ui describe-all --udid "$UDID" 2>/dev/null | python3 -c "
import sys, json
try:
    d = json.load(sys.stdin)
except Exception:
    print('unknown'); raise SystemExit
frames = [e['frame'] for e in d if e.get('frame')]
if not frames:
    print('unknown'); raise SystemExit
w = max(f['x'] + f['width'] for f in frames)
h = max(f['y'] + f['height'] for f in frames)
print('unknown' if w == 0 or h == 0 else ('landscape' if w > h else 'portrait'))
"
}

# Wait for the runtime to answer at all before touching orientation. "unknown"
# means describe-all returned nothing usable, which happens while the device is
# still coming up and also when the machine is loaded enough to starve the idb
# companion — so this waits rather than guessing, and gives up loudly rather
# than rotating a device whose orientation it never established.
current=unknown
for _ in $(seq 1 20); do
    current=$(probe)
    [ "$current" != unknown ] && break
    sleep 2
done
if [ "$current" = unknown ]; then
    echo "  !! orient: $UDID never reported a screen size; leaving it alone"
    exit 1
fi

[ "$current" = "$WANT" ] && exit 0

pgrep -x Simulator >/dev/null || { open -a Simulator; sleep 5; }

# Fronting a window and pressing the shortcut are two steps, so two rotations
# running at once can interleave and turn the wrong device. A lock around just
# this section lets devices capture concurrently while rotations queue — which
# is what allows run-all.sh -j to include iPads at all. mkdir is the atomic
# primitive here; macOS has no flock(1).
LOCK="${TMPDIR:-/tmp}/awful-screenshot-orient.lock"
locked=""
for _ in $(seq 1 120); do
    if mkdir "$LOCK" 2>/dev/null; then locked=1; break; fi
    sleep 1
done
if [ -z "$locked" ]; then
    # Assume a crashed holder rather than wedging the run: 2 minutes is far
    # longer than a rotation takes.
    echo "  !! orient: stale rotation lock at $LOCK — taking it"
    rmdir "$LOCK" 2>/dev/null; mkdir "$LOCK" 2>/dev/null
fi
trap 'rmdir "$LOCK" 2>/dev/null' EXIT

# Window menu entries are "<name> – iOS <version>"; match on both, since the
# name alone is ambiguous across runtimes.
NAME=$(xcrun simctl list devices -j 2>/dev/null | UDID="$UDID" python3 -c "
import sys, json, os
udid = os.environ['UDID']
for runtime, devices in json.load(sys.stdin)['devices'].items():
    for d in devices:
        if d.get('udid') == udid:
            ver = runtime.rsplit('.', 1)[-1].replace('iOS-', '').replace('-', '.')
            print('%s\t%s' % (d.get('name', ''), ver))
            raise SystemExit
")
DEV_NAME="${NAME%%$'\t'*}"
DEV_VER="${NAME##*$'\t'}"

# A simulator booted with `simctl boot` has NO Simulator window — the app can
# be running, list the device under its Window menu, and still have zero
# windows. Rotate Right then reports success and does nothing, which is how a
# whole run of iPads came out sideways with no error. A window only appears if
# Simulator is LAUNCHED for that device, and -CurrentDeviceUDID is read at
# launch only, so an already-running Simulator ignores it and has to be
# restarted. Quitting is safe: simctl-booted devices stay booted, and captures
# go through simctl/idb, which never needed the GUI.
has_window() {
    case "$(osascript -e 'tell application "System Events" to tell process "Simulator" to get name of windows' 2>/dev/null)" in
        *"$DEV_NAME"*) return 0 ;;
    esac
    return 1
}

open_window() {
    osascript -e 'tell application "Simulator" to quit' >/dev/null 2>&1
    sleep 3
    pkill -x Simulator 2>/dev/null
    sleep 2
    open -a Simulator --args -CurrentDeviceUDID "$UDID" >/dev/null 2>&1
    for _ in $(seq 1 20); do
        sleep 1
        has_window && return 0
    done
    return 1
}

front_window() {
    [ -n "$DEV_NAME" ] || return 1
    osascript <<EOF 2>&1
tell application "System Events" to tell process "Simulator"
    repeat with mi in menu items of menu 1 of menu bar item "Window" of menu bar 1
        set n to name of mi
        if n is not missing value then
            if n contains "$DEV_NAME" and n contains "iOS $DEV_VER" then
                click mi
                return "ok"
            end if
        end if
    end repeat
end tell
return "notfound"
EOF
}

if ! has_window; then
    open_window || echo "  !! orient: could not open a Simulator window for $DEV_NAME"
fi

for _ in $(seq 1 3); do
    osascript -e 'tell application "Simulator" to activate' >/dev/null 2>&1
    sleep 1
    case "$(front_window)" in
        *"not allowed to send keystrokes"*|*"osascript is not allowed"*)
            echo "  !! orient: no Accessibility permission — grant it to this app in"
            echo "     System Settings > Privacy & Security > Accessibility, or iPads"
            echo "     will capture sideways with the sidebar collapsed."
            exit 1 ;;
        notfound)
            echo "  !! orient: no Simulator window for $DEV_NAME (iOS $DEV_VER)"
            open_window || true ;;
    esac
    sleep 1
    err=$(osascript \
        -e 'tell application "System Events" to tell process "Simulator" to click menu item "Rotate Right" of menu 1 of menu bar item "Device" of menu bar 1' 2>&1)
    case "$err" in
        *"not allowed to send keystrokes"*)
            echo "  !! orient: no Accessibility permission — grant it to this app in"
            echo "     System Settings > Privacy & Security > Accessibility, or iPads"
            echo "     will capture sideways with the sidebar collapsed."
            exit 1 ;;
    esac
    # Poll rather than check once: SpringBoard keeps reporting the old size for
    # a few seconds after the rotation animation, and a single impatient check
    # reports a device "stuck" that in fact turned. Waiting here also stops the
    # next attempt from sending a second rotation on top of a good one.
    for _ in $(seq 1 8); do
        sleep 2
        current=$(probe)
        [ "$current" = "$WANT" ] && exit 0
    done
done

echo "  !! orient: $UDID stuck in $current, wanted $WANT"
exit 1
