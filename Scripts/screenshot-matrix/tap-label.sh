#!/bin/bash
# tap-label.sh <udid> <ax-label> [match-mode: exact|contains] [settle]
# Taps the centre of the first element whose accessibility label matches.
# Exits non-zero (without tapping) when nothing matches, so callers can skip
# a screen rather than tapping blindly at a stale coordinate.
set -euo pipefail

IDB="${IDB_BIN:?IDB_BIN must point at the idb client}"
UDID="$1"
LABEL="$2"
MODE="${3:-exact}"
SETTLE="${4:-3}"

COORDS=$("$IDB" ui describe-all --udid "$UDID" 2>/dev/null | LABEL="$LABEL" MODE="$MODE" python3 -c "
import sys, json, os
label, mode = os.environ['LABEL'], os.environ['MODE']
try:
    data = json.load(sys.stdin)
except Exception:
    sys.exit(1)
for d in data:
    ax = d.get('AXLabel') or ''
    hit = (ax == label) if mode == 'exact' else (label.lower() in ax.lower())
    if hit and d.get('enabled'):
        f = d['frame']
        print(int(f['x'] + f['width'] / 2), int(f['y'] + f['height'] / 2))
        sys.exit(0)
sys.exit(1)
")

# shellcheck disable=SC2086
"$IDB" ui tap --udid "$UDID" $COORDS 2>/dev/null
sleep "$SETTLE"
