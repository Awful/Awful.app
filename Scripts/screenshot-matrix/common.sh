#!/bin/bash
# common.sh — sourced by the capture scripts.
# Resolves where the scripts live and where images go. Images land outside
# this directory (and outside git) because they are large binary output;
# override with OUT_ROOT to capture somewhere else.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
OUT_ROOT="${OUT_ROOT:-$REPO_ROOT/ScreenshotMatrix}"

BUNDLE_ID="${BUNDLE_ID:-com.spankykong.awful.debug}"

# Content shared by every capture: the safe test forum and the account's own
# user. Composing anywhere else risks posting to a public forum.
FORUM_ID="${FORUM_ID:-261}"          # Apps In Developmental States
THREAD_ID="${THREAD_ID:-3532200}"    # [TEST] The Post Test Thread
POLL_THREAD_ID="${POLL_THREAD_ID:-4115578}"
OWN_USER_ID="${OWN_USER_ID:-224355}" # commie kong

mkdir -p "$OUT_ROOT"

# want <screen-id> — is this screen in the requested set?
# SCREENS is a comma-separated list of ids from `run-all.sh --screens`, already
# canonicalised there against screens.txt. Unset or empty means capture
# everything, which is what a plain run does.
want() {
    [ -z "${SCREENS:-}" ] && return 0
    case ",${SCREENS}," in *",$1,"*) return 0 ;; esac
    return 1
}
