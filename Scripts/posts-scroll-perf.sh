#!/bin/bash
# posts-scroll-perf.sh [-o dir] [-w slow|medium|previous] [--gifs on|off] [--no-frames] [device]
#
# Runs the posts scrolling workout (App/UITests/PostsScrollPerformanceTests.swift)
# on a simulator while recording the performance probe's output and every app
# and WebKit process's CPU and memory, then writes a per-phase report.
#
#   ./Scripts/posts-scroll-perf.sh                  # the booted simulator
#   ./Scripts/posts-scroll-perf.sh <udid>           # a specific simulator
#   ./Scripts/posts-scroll-perf.sh -o /tmp/scroll   # elsewhere
#   ./Scripts/posts-scroll-perf.sh -w medium        # just one workout (about half the time)
#   ./Scripts/posts-scroll-perf.sh -w previous      # just the Previous posts workout
#   ./Scripts/posts-scroll-perf.sh --gifs off       # GIF autoplay forced off (or on) for the run
#   ./Scripts/posts-scroll-perf.sh --no-frames      # no frame sampling in the page, whose
#                                                   # rAF loop itself costs web content CPU
#
# Three workouts run back to back. Two open page 1 of the GIF thread with
# endless scroll on, flick quickly down four pages, then scroll up two pages
# and down two again: unhurried ("slow") and twice as fast ("medium"). The
# third ("previous") marks a thread read partway down a page, opens that page,
# taps Previous posts and scrolls up through the revealed posts, failing if any
# is drawn for the first time above the viewport on the way. Set
# TEST_RUNNER_AWFUL_PERF_SET_SEEN=<threadID>:<index> to pick the thread and post.
# Endless scroll and the probe are switched on through launch arguments for
# the run only, as is GIF autoplay with --gifs; the simulator's own settings are
# left alone. It needs a
# logged-in, booted simulator (the tests skip otherwise).
#
# Output, in PostsScrollPerf/<timestamp>/ unless -o is given:
#   report.md       the per-phase report
#   run.txt         what was run, for the report's heading
#   probe.log       the probe's log lines and the test's phase markers
#   processes.csv   CPU % and memory per process, once a second
#   test.log        full xcodebuild output
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
OUT_DIR=""
DEVICE=""
WORKOUT=""
GIFS=""
FRAMES=YES

# The whole header comment, however long it grows.
usage() { awk 'NR > 1 && !/^#/ { exit } NR > 1 { sub(/^# ?/, ""); print }' "$0"; }

while [ $# -gt 0 ]; do
    case "$1" in
        -o|--out)  OUT_DIR="${2:?--out needs a directory}"; shift 2 ;;
        -w|--workout)
            case "${2:-}" in
                slow)   WORKOUT=testSlowScrolling ;;
                medium) WORKOUT=testMediumScrolling ;;
                previous) WORKOUT=testScrollUpAfterPreviousPosts ;;
                *)      echo "--workout is slow, medium or previous" >&2; exit 1 ;;
            esac
            shift 2 ;;
        --gifs)
            case "${2:-}" in
                on)  GIFS=YES ;;
                off) GIFS=NO ;;
                *)   echo "--gifs is on or off" >&2; exit 1 ;;
            esac
            shift 2 ;;
        --no-frames) FRAMES=NO; shift ;;
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
    # Separately: pkill fails when the sampler has no child at that instant, which mustn't spare the sampler.
    if [ -n "${SAMPLER_PID:-}" ]; then
        kill "$SAMPLER_PID" 2>/dev/null
        pkill -P "$SAMPLER_PID" 2>/dev/null
    fi
}
trap cleanup EXIT

echo "recording to $OUT_DIR"
xcrun simctl spawn "$DEVICE" log stream --level info --style compact \
    --predicate 'category == "PostsPerformance"' > "$OUT_DIR/probe.log" 2>&1 &
LOG_PID=$!
# Its stderr is dropped so that killing it mid-sample doesn't report top being "Terminated".
sample_processes > "$OUT_DIR/processes.csv" 2>/dev/null &
SAMPLER_PID=$!
# Nor this shell reporting either job as "Terminated" when cleanup kills them.
disown "$LOG_PID" "$SAMPLER_PID"

TEST_ID="AwfulUITests/PostsScrollPerformanceTests${WORKOUT:+/$WORKOUT}"
echo "running $TEST_ID${GIFS:+ with GIF autoplay $GIFS} (several minutes)…"
[ -n "$GIFS" ] && export TEST_RUNNER_AWFUL_PERF_AUTOPLAY_GIFS="$GIFS"
export TEST_RUNNER_AWFUL_PERF_PROBE_FRAMES="$FRAMES"
{
    echo "Workouts: ${WORKOUT:-all}; GIF autoplay: ${GIFS:-simulator setting}; page frame sampling: $FRAMES"
    echo "Commit: $(git -C "$REPO_ROOT" rev-parse --short HEAD)$(git -C "$REPO_ROOT" diff --quiet HEAD || echo ' plus uncommitted changes')"
} > "$OUT_DIR/run.txt"
# Parallel testing would run the test on a fresh clone of the simulator, which isn't logged in.
xcodebuild test \
    -project "$REPO_ROOT/Awful.xcodeproj" -scheme Awful -testPlan UITests \
    -destination "platform=iOS Simulator,id=$DEVICE" \
    -parallel-testing-enabled NO \
    -only-testing:"$TEST_ID" \
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
