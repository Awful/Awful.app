#!/bin/bash
# posts-scroll-perf.sh [-o dir] [device]
#
# Runs the posts scrolling workout (App/UITests/PostsScrollPerformanceTests.swift)
# on a simulator while recording the performance probe's output and every app
# and WebKit process's CPU and memory, then writes a per-phase report.
#
#   ./Scripts/posts-scroll-perf.sh                  # the booted simulator
#   ./Scripts/posts-scroll-perf.sh <udid>           # a specific simulator
#   ./Scripts/posts-scroll-perf.sh -o /tmp/scroll   # elsewhere
#
# Two workouts run back to back. Each opens page 1 of the GIF thread with
# endless scroll on, flicks quickly down four pages, then scrolls up two pages
# and down two again: unhurried ("slow") and twice as fast ("medium").
# Endless scroll and the probe are switched on through launch arguments for
# the run only; the simulator's own settings are left alone. It needs a
# logged-in, booted simulator (the tests skip otherwise).
#
# Output, in PostsScrollPerf/<timestamp>/ unless -o is given:
#   report.md       the per-phase report
#   probe.log       the probe's log lines and the test's phase markers
#   processes.csv   CPU % and memory per process, once a second
#   test.log        full xcodebuild output
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
OUT_DIR=""
DEVICE=""

# The whole header comment, however long it grows.
usage() { awk 'NR > 1 && !/^#/ { exit } NR > 1 { sub(/^# ?/, ""); print }' "$0"; }

while [ $# -gt 0 ]; do
    case "$1" in
        -o|--out)  OUT_DIR="${2:?--out needs a directory}"; shift 2 ;;
        -h|--help) usage; exit 0 ;;
        -*)        echo "unknown option: $1" >&2; usage >&2; exit 1 ;;
        *)         DEVICE="$1"; shift ;;
    esac
done

if [ -z "$DEVICE" ]; then
    DEVICE=$(xcrun simctl list devices booted | grep -oE '[0-9A-F-]{36}' | head -1)
    [ -n "$DEVICE" ] || { echo "no booted simulator — boot one or pass a UDID" >&2; exit 1; }
    if [ "$(xcrun simctl list devices booted | grep -cE '[0-9A-F-]{36}')" -gt 1 ]; then
        echo "more than one simulator booted; using $DEVICE (pass a UDID to choose)"
    fi
fi
xcrun simctl list devices | grep -q "$DEVICE.*Booted" || { echo "$DEVICE isn't booted" >&2; exit 1; }

OUT_DIR="${OUT_DIR:-$REPO_ROOT/PostsScrollPerf/$(date +%Y-%m-%d-%H%M%S)}"
mkdir -p "$OUT_DIR"

# The simulator's launchd, whose children are the app and its WebKit processes.
LAUNCHD=$(ps -axo pid,command | grep "launchd_sim .*$DEVICE" | grep -v grep | awk '{print $1}' | head -1)
[ -n "$LAUNCHD" ] || { echo "couldn't find the simulator's launchd_sim" >&2; exit 1; }

# Once a second: CPU % and memory for the app and each WebKit process. top needs
# two samples to report CPU, so each line comes from the second.
sample_processes() {
    echo "time,pid,process,cpu,mem"
    while true; do
        local pids="" args="" names=""
        while read -r pid; do
            [ -n "$pid" ] || continue
            pids="$pids $pid"
            args="$args -pid $pid"
        done < <(ps -axo pid,ppid,command | awk -v l="$LAUNCHD" '$2 == l && ($0 ~ /AwfulDebug|com\.apple\.WebKit\./) { print $1 }')
        if [ -z "$pids" ]; then sleep 1; continue; fi
        # Full names (top truncates them), e.g. com.apple.WebKit.WebContent.
        names=$(for p in $pids; do printf '%s=%s ' "$p" "$(ps -o comm= -p "$p" 2>/dev/null | sed 's#.*/##')"; done)
        local now; now=$(date +%H:%M:%S)
        top -l 2 -s 1 -stats pid,cpu,mem $args 2>/dev/null | awk -v t="$now" -v names="$names" '
            BEGIN { n = split(names, pairs, " "); for (i = 1; i <= n; i++) { split(pairs[i], kv, "="); name[kv[1]] = kv[2] } }
            /^PID/ { sample++; next }
            sample == 2 && NF >= 3 { printf "%s,%s,%s,%s,%s\n", t, $1, name[$1], $2, $3 }'
    done
}

cleanup() {
    [ -n "${LOG_PID:-}" ] && kill "$LOG_PID" 2>/dev/null
    [ -n "${SAMPLER_PID:-}" ] && pkill -P "$SAMPLER_PID" 2>/dev/null && kill "$SAMPLER_PID" 2>/dev/null
}
trap cleanup EXIT

echo "recording to $OUT_DIR"
xcrun simctl spawn "$DEVICE" log stream --level info --style compact \
    --predicate 'category == "PostsPerformance"' > "$OUT_DIR/probe.log" 2>&1 &
LOG_PID=$!
sample_processes > "$OUT_DIR/processes.csv" &
SAMPLER_PID=$!

echo "running the workout (a few minutes)…"
# Parallel testing would run the test on a fresh clone of the simulator, which isn't logged in.
xcodebuild test \
    -project "$REPO_ROOT/Awful.xcodeproj" -scheme Awful -testPlan UITests \
    -destination "platform=iOS Simulator,id=$DEVICE" \
    -parallel-testing-enabled NO \
    -only-testing:AwfulUITests/PostsScrollPerformanceTests \
    > "$OUT_DIR/test.log" 2>&1
rc=$?
sleep 2
cleanup
trap - EXIT

grep -E "Test Case .*(passed|failed|skipped)|error:|Skipped" "$OUT_DIR/test.log" | head -5
python3 "$SCRIPT_DIR/posts-scroll-perf-report.py" "$OUT_DIR" > "$OUT_DIR/report.md"
cat "$OUT_DIR/report.md"
echo
echo "report: $OUT_DIR/report.md"
exit $rc
