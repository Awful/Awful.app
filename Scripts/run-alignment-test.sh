#!/bin/bash
# run-alignment-test.sh [options] [device ...]
#
# Runs the sidebar alignment XCUITest suite (test plan "UITests",
# App/UITests/SidebarAlignmentTests.swift) on one or more iPad simulators,
# then exports each run's annotated screenshots and measurement report for
# review, so nobody has to dig through xcresult bundles by hand.
#
#   ./Scripts/run-alignment-test.sh                # every booted simulator
#   ./Scripts/run-alignment-test.sh <udid> [...]   # specific simulators
#   ./Scripts/run-alignment-test.sh -o /tmp/align  # elsewhere
#   ./Scripts/run-alignment-test.sh -c             # rebuild collages only
#
# Output, per device:
#   ScreenshotMatrix/alignment/<device-slug>/
#     <Screen>-<orientation>.png   annotated screenshots (measurement lines
#                                  drawn on by the test itself)
#     report.txt                   the measurement table for both orientations
#     test.log                     full xcodebuild output
#     result.xcresult              kept only with --keep-results
#
# Afterwards the header strips (status bar + nav bar + measurement labels)
# of every device folder present — this run's and earlier ones' — are
# stacked into per-screen comparison sheets:
#   ScreenshotMatrix/alignment/collages/<Screen>-<orientation>.png
# Needs ImageMagick (`magick`); skipped with a note if it's missing.
#
# Devices are run one at a time (the test rotates the simulator). Each
# device's output directory is wiped at the start of its run so a folder
# always holds exactly one coherent set. A device that isn't logged in
# produces a skipped run — the test says so loudly in report.txt.
#
# The app and test runner are built once and installed by xcodebuild on each
# device, so target simulators only need to exist and be logged in.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
OUT_ROOT="${OUT_ROOT:-$REPO_ROOT/ScreenshotMatrix/alignment}"
KEEP_RESULTS=0
COLLAGE_ONLY=0
DEVICES=()

# The whole header comment, however long it grows.
usage() { awk 'NR > 1 && !/^#/ { exit } NR > 1 { sub(/^# ?/, ""); print }' "$0"; }

while [ $# -gt 0 ]; do
    case "$1" in
        -o|--out)          OUT_ROOT="${2:?--out needs a directory}"; shift 2 ;;
        -k|--keep-results) KEEP_RESULTS=1; shift ;;
        -c|--collage-only) COLLAGE_ONLY=1; shift ;;
        -h|--help)         usage; exit 0 ;;
        -*)                echo "unknown option: $1" >&2; usage >&2; exit 1 ;;
        *)                 DEVICES+=("$1"); shift ;;
    esac
done

# slug_for <udid> — "ios26.5-ipad-pro-11-inch-m5", for stable folder names.
slug_for() {
    xcrun simctl list devices -j | UDID="$1" python3 -c "
import sys, json, os, re
udid = os.environ['UDID']
for runtime, devices in json.load(sys.stdin)['devices'].items():
    for d in devices:
        if d.get('udid') == udid:
            ver = runtime.rsplit('.', 1)[-1].replace('iOS-', '').replace('-', '.')
            name = re.sub(r'[^a-z0-9]+', '-', d['name'].lower()).strip('-')
            print(f'ios{ver}-{name}')
            raise SystemExit
"
}

# Per-screen comparison sheets: the header strip of each device's capture,
# stacked with the device slug as a caption, so one image shows every
# device's bar for a given screen. Rebuilt from every device folder present,
# so earlier runs' devices stay in the sheets.
build_collages() {
    command -v magick >/dev/null || { echo "ImageMagick 'magick' not found — skipping collages"; return; }
    local cdir="$OUT_ROOT/collages"
    # 160pt of screen keeps the status bar, the nav bar, and the measurement
    # labels the test draws just beneath it; captures are 2x.
    local strip_px=320
    local tmp; tmp=$(mktemp -d)

    local basenames
    basenames=$(find "$OUT_ROOT" -mindepth 2 -maxdepth 2 -name '*.png' ! -path "*/collages/*" \
        -exec basename {} \; | sort -u)
    [ -z "$basenames" ] && { rm -rf "$tmp"; return; }

    rm -rf "$cdir"
    mkdir -p "$cdir"
    local base dir slug n=0
    for base in $basenames; do
        local args=()
        for dir in "$OUT_ROOT"/*/; do
            slug=$(basename "$dir")
            [ "$slug" = collages ] && continue
            [ -f "$dir$base" ] || continue
            magick "$dir$base" -crop "x${strip_px}+0+0" +repage "$tmp/$slug-$base" 2>/dev/null || continue
            args+=(-label "$slug" "$tmp/$slug-$base")
        done
        if [ ${#args[@]} -gt 0 ]; then
            # Explicit font path — ImageMagick on this machine has no default
            # font configured (same reason label.sh names one).
            magick montage "${args[@]}" -tile 1x -geometry +0+8 -gravity West \
                -font '/System/Library/Fonts/Supplemental/Arial Bold.ttf' \
                -background white -fill black -pointsize 28 "$cdir/$base" \
                && n=$((n + 1))
        fi
    done
    rm -rf "$tmp"
    echo "collages: $n sheet(s) in $cdir"
}

if [ "$COLLAGE_ONLY" = 1 ]; then
    build_collages
    exit 0
fi

# No devices given: every currently booted simulator.
if [ ${#DEVICES[@]} -eq 0 ]; then
    while IFS= read -r udid; do
        DEVICES+=("$udid")
    done < <(xcrun simctl list devices booted | grep -oE '[0-9A-F-]{36}')
    if [ ${#DEVICES[@]} -eq 0 ]; then
        echo "no booted simulators and no devices given — boot one or pass UDIDs" >&2
        exit 1
    fi
fi

mkdir -p "$OUT_ROOT"

echo "building for testing (once)…"
if ! xcodebuild build-for-testing \
        -project "$REPO_ROOT/Awful.xcodeproj" -scheme Awful -testPlan UITests \
        -destination "platform=iOS Simulator,id=${DEVICES[0]}" \
        > "$OUT_ROOT/build.log" 2>&1; then
    echo "build failed — see $OUT_ROOT/build.log" >&2
    exit 1
fi

overall=0
SUMMARY=()

for udid in "${DEVICES[@]}"; do
    slug=$(slug_for "$udid")
    if [ -z "$slug" ]; then
        echo "!! unknown simulator: $udid — skipping"
        SUMMARY+=("$udid: not found")
        overall=1
        continue
    fi
    outdir="$OUT_ROOT/$slug"
    rm -rf "$outdir"
    mkdir -p "$outdir"
    echo "### $slug ($udid)"

    # Boot if needed; remember whether it was ours to shut down.
    booted_by_us=0
    if ! xcrun simctl list devices | grep -q "$udid.*Booted"; then
        xcrun simctl boot "$udid" 2>/dev/null && booted_by_us=1
        for _ in $(seq 1 30); do
            xcrun simctl list devices | grep -q "$udid.*Booted" && break
            sleep 2
        done
    fi

    xcresult="$outdir/result.xcresult"
    xcodebuild test-without-building \
        -project "$REPO_ROOT/Awful.xcodeproj" -scheme Awful -testPlan UITests \
        -destination "platform=iOS Simulator,id=$udid" \
        -resultBundlePath "$xcresult" \
        > "$outdir/test.log" 2>&1
    rc=$?

    # The measurement tables (one per orientation) from the test log.
    awk '/=== Alignment report ===/,/^========================$/' "$outdir/test.log" > "$outdir/report.txt"
    grep -E "Test Case.*(passed|failed|skipped)|Executed" "$outdir/test.log" >> "$outdir/report.txt"

    # Annotated screenshots, renamed from the manifest's readable names.
    # Only the test's own attachments ("<Screen> (landscape)" etc.) — the
    # automatic UI snapshots and debug descriptions stay in the xcresult.
    if [ -d "$xcresult" ]; then
        tmp=$(mktemp -d)
        if xcrun xcresulttool export attachments --path "$xcresult" --output-path "$tmp" >/dev/null 2>&1; then
            OUTDIR="$outdir" TMP="$tmp" python3 - <<'PY'
import json, os, re, shutil
tmp, outdir = os.environ['TMP'], os.environ['OUTDIR']
count = 0
for test in json.load(open(os.path.join(tmp, 'manifest.json'))):
    for a in test.get('attachments', []):
        name = a.get('suggestedHumanReadableName', a.get('configuredName', ''))
        base = name.split('_0_')[0]
        m = re.match(r'^(.+) \((landscape|portrait)\)$', base)
        if m:
            dest = f"{m.group(1).replace(' ', '-')}-{m.group(2)}.png"
        elif base in ('login-screen', 'no-tab-bar'):
            dest = base + '.png'
        else:
            continue
        shutil.copy(os.path.join(tmp, a['exportedFileName']), os.path.join(outdir, dest))
        count += 1
print(f"  {count} screenshot(s) exported")
PY
        else
            echo "  !! could not export attachments from $xcresult"
        fi
        rm -rf "$tmp"
    else
        echo "  !! no result bundle — see test.log"
    fi

    [ "$KEEP_RESULTS" = 1 ] || rm -rf "$xcresult"
    [ "$booted_by_us" = 1 ] && xcrun simctl shutdown "$udid" 2>/dev/null

    if [ $rc -eq 0 ]; then
        SUMMARY+=("$slug: PASS — $outdir")
    else
        # Failed assertions still export screenshots; skips (not logged in)
        # land here too. report.txt has the details either way.
        SUMMARY+=("$slug: FAIL/SKIP (see report.txt) — $outdir")
        overall=1
    fi
done

build_collages

echo
echo "=== alignment run summary ==="
printf '%s\n' "${SUMMARY[@]}"
exit $overall
