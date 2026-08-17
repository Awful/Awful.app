#!/bin/bash
# capture-interactive.sh <udid> <ios-slug> <device-slug> <theme-slug> <device-label>
# Captures the views with no deep link: rap sheet, post compose, post preview.
# Calibrated for a 402x874pt iPhone Pro screen (16 Pro / 17 Pro) — the app's
# accessibility tree exposes only a handful of elements in its web-backed
# views, so in-app controls are tapped by coordinate. Other screen sizes need
# their own constants.
#
# SAFETY (hard rules, never relax):
#   * Composing happens only inside FORUM_ID, "Apps In Developmental States".
#   * Any PM compose is addressed only to "Commie kong".
#   * Post / Send is NEVER tapped. Every compose flow exits via
#     Cancel -> Delete Draft, both matched by accessibility label so a shifted
#     layout cannot turn into a stray tap on Post.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

IDB="${IDB_BIN:?IDB_BIN must point at the idb client}"
UDID="$1"; IOS="$2"; DEV="$3"; THEME="$4"; DEVLABEL="$5"

OUT="$OUT_ROOT/${IOS}-${DEV}/${THEME}"
mkdir -p "$OUT"

# Nav-bar hit points for a 402x874pt screen.
COMPOSE_BTN="363 83"   # pencil, top-right of the posts view
PREVIEW_BTN="339 100"  # top-right of the compose sheet
BACK_BTN="37 100"      # top-left of the preview screen
CANCEL_BTN="58 100"    # top-left of the compose sheet

grab() {
    local name="$1"
    local f="$OUT/${IOS}_${DEV}_${THEME}_${name}.png"
    xcrun simctl io "$UDID" screenshot "$f" >/dev/null 2>&1
    [ -n "${ROTATE:-}" ] && [ "${ROTATE}" != "0" ] && magick "$f" -rotate "$ROTATE" "$f"
    "$SCRIPT_DIR/label.sh" "$f" "$DEVLABEL · ${THEME} · ${name#*-}"
    echo "  $name"
}

# shellcheck disable=SC2086
tapxy() { "$IDB" ui tap --udid "$UDID" $1 2>/dev/null || true; sleep "${2:-3}"; }

# Each block is guarded by `want` so --screens can skip the whole flow, not
# just its screenshot — the compose sequence is most of this script's runtime.
# Written as `if`, never `want X && ...`, because a false `&&` at the top level
# would take `set -e` down with it.

# --- 11. Rap sheet (nav.sh closes the leftover profile sheet first) ---------
if want 11-rap-sheet; then
    "$SCRIPT_DIR/nav.sh" "$UDID" "awful://banlist/$OWN_USER_ID" 6
    grab 11-rap-sheet
fi

# --- 13/15. Post compose + preview (test forum only) -----------------------
if want 13-post-compose || want 15-post-preview; then
    "$SCRIPT_DIR/nav.sh" "$UDID" "awful://threads/$THREAD_ID/pages/last" 7
    tapxy "$COMPOSE_BTN" 4
    "$IDB" ui text --udid "$UDID" \
        "Sample reply for the screenshot matrix. [b]Bold[/b] and [i]italic[/i] BBcode. This draft is never submitted." \
        2>/dev/null || true
    sleep 2
    if want 13-post-compose; then grab 13-post-compose; fi

    if want 15-post-preview; then
        tapxy "$PREVIEW_BTN" 6
        grab 15-post-preview
        tapxy "$BACK_BTN" 3
    fi

    # Exit without posting: Cancel, then Delete Draft by label. This runs
    # whenever the compose sheet was opened at all — never gate it on a screen
    # selection, or a skipped preview would leave a live draft on screen.
    tapxy "$CANCEL_BTN" 3
    "$SCRIPT_DIR/tap-label.sh" "$UDID" "Delete Draft" exact 3 2>/dev/null \
        || echo "  !! no Delete Draft prompt (draft may remain)"
fi

echo "interactive done: $THEME on $IOS/$DEV"
