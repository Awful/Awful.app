#!/bin/bash
# run-all.sh — capture a screenshot matrix across simulators, themes and views.
# See README.md for what the passes contain and how the scrub works.
set -uo pipefail

# SCRIPT_DIR before common.sh, because the options parsed below (--out,
# --bundle-id) are the very things common.sh reads out of the environment.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCREENS_FILE="$SCRIPT_DIR/screens.txt"

usage() {
    cat <<'EOF'
usage: run-all.sh [options] [device-filter ...]

Captures every device in a runlist, then verifies and regenerates INDEX.md.
Bare arguments are device filters, same as repeating --device.

Options:
  -l, --list NAME     runlist to walk: devices-NAME.txt, or `full` for
                      devices.txt (default: $RUNLIST, else full)
  -d, --device SPEC   only devices whose slug contains SPEC, or whose udid
                      equals it exactly; repeatable
  -s, --screens LIST  comma-separated screen ids or fragments, e.g.
                      bookmarks,settings (default: every screen)
  -T, --themes LIST   comma-separated theme slugs (default: whatever the pass
                      calls for). Useful for re-capturing one bad image.
  -p, --pass A|B      shorthand overriding both runlist columns: A = every
                      theme and the tap-driven views, B = key themes and
                      deep-linkable views only
  -j, --jobs N        capture up to N devices at once (default 1)
  -o, --out DIR       where images land (default: $OUT_ROOT, else
                      <repo>/ScreenshotMatrix)
      --bundle-id ID  app to capture (default: com.awfulapp.Awful.debug)
      --no-scrub      leave list views showing real account data
      --no-verify     skip the blank-frame check
      --no-index      skip regenerating INDEX.md
  -n, --dry-run       print the plan and exit; boots nothing
      --list-screens  print the screen id vocabulary and exit
  -h, --help          this text

Examples:
  run-all.sh                                  # full matrix, ~2h
  run-all.sh -l quick                          # one phone + one iPad, key themes
  run-all.sh -l quick -s bookmarks             # one screen, two devices
  run-all.sh -p B                              # every device, key themes only
  run-all.sh -d ipad -o /tmp/ipads             # iPads only, scratch directory
  run-all.sh -j 2                              # full matrix, two devices at once
  run-all.sh -l quick -n                       # what would this do?

Devices carry two independent columns. `themes` is all (15) or key (2), and is
nearly all of a run's cost. `views` is all (deep links plus the tap-driven
compose/preview) or key (deep links only); only the two 402x874pt phones can
take views=all, since capture-interactive.sh taps coordinates calibrated for
that screen.

Parallelism: -j overlaps whole devices, iPads included. Rotation still happens
one device at a time — orient.sh holds a lock across fronting the window and
pressing the shortcut — but that costs seconds, not the whole capture.
EOF
}

screens_rows() { grep -vE '^[[:space:]]*(#|$)' "$SCREENS_FILE"; }

list_screens() {
    printf '%-18s %-12s %-12s %s\n' ID WHEN SCRIPT DESCRIPTION
    local id when script desc
    while IFS='|' read -r id when script desc; do
        printf '%-18s %-12s %-12s %s\n' "$id" "$when" "$script" "$desc"
    done < <(screens_rows)
}

LIST="${RUNLIST:-full}"
JOBS="${JOBS:-1}"
SCREENS_ARG=""
PASS_OVERRIDE=""
DRY_RUN=""
DO_VERIFY=1
DO_INDEX=1
FILTERS=()

while [ $# -gt 0 ]; do
    case "$1" in
        -l|--list)      LIST="${2:?--list needs a runlist name}"; shift 2 ;;
        -d|--device)    FILTERS+=("${2:?--device needs a slug or udid}"); shift 2 ;;
        -s|--screens)   SCREENS_ARG="${2:?--screens needs a list of ids}"; shift 2 ;;
        -T|--themes)    export THEME_FILTER="${2:?--themes needs theme slugs}"; shift 2 ;;
        -p|--pass)      PASS_OVERRIDE="$(echo "${2:?--pass needs A or B}" | tr '[:lower:]' '[:upper:]')"; shift 2 ;;
        -j|--jobs)      JOBS="${2:?--jobs needs a number}"; shift 2 ;;
        -o|--out)       export OUT_ROOT="${2:?--out needs a directory}"; shift 2 ;;
        --bundle-id)    export BUNDLE_ID="${2:?--bundle-id needs an id}"; shift 2 ;;
        --no-scrub)     export SCRUB=0; shift ;;
        --no-verify)    DO_VERIFY=0; shift ;;
        --no-index)     DO_INDEX=0; shift ;;
        -n|--dry-run)   DRY_RUN=1; shift ;;
        --list-screens) list_screens; exit 0 ;;
        -h|--help)      usage; exit 0 ;;
        --)             shift; break ;;
        -*)             echo "unknown option: $1" >&2; usage >&2; exit 1 ;;
        *)              FILTERS+=("$1"); shift ;;
    esac
done
[ $# -gt 0 ] && FILTERS+=("$@")

case "$PASS_OVERRIDE" in
    ""|A|B) ;;
    *) echo "--pass takes A or B, not $PASS_OVERRIDE" >&2; exit 1 ;;
esac

source "$SCRIPT_DIR/common.sh"

case "$LIST" in
    full)  DEVICES="$SCRIPT_DIR/devices.txt" ;;
    */*)   DEVICES="$LIST" ;;
    *)     DEVICES="$SCRIPT_DIR/devices-$LIST.txt" ;;
esac
if [ ! -f "$DEVICES" ]; then
    echo "no such runlist: $LIST (looked for $DEVICES)" >&2
    echo "available:" >&2
    for f in "$SCRIPT_DIR"/devices.txt "$SCRIPT_DIR"/devices-*.txt; do
        [ -f "$f" ] || continue
        n=$(basename "$f" .txt); [ "$n" = devices ] && n=full || n=${n#devices-}
        printf '  %-8s %s device(s)\n' "$n" "$(grep -cvE '^[[:space:]]*(#|$)' "$f")" >&2
    done
    exit 1
fi

# Resolve --screens fragments to canonical ids up front, so a typo fails here
# rather than quietly capturing nothing an hour into a run. Empty means all.
SEL=""
if [ -n "$SCREENS_ARG" ]; then
    IFS=',' read -ra tokens <<< "$SCREENS_ARG"
    for t in "${tokens[@]}"; do
        t="$(echo "$t" | tr -d '[:space:]')"
        [ -z "$t" ] && continue
        found=""
        while IFS='|' read -r id when script desc; do
            case "$id" in
                *"$t"*)
                    case ",$SEL," in *",$id,"*) ;; *) SEL="${SEL:+$SEL,}$id" ;; esac
                    found=1 ;;
            esac
        done < <(screens_rows)
        if [ -z "$found" ]; then
            echo "unknown screen: $t" >&2
            list_screens >&2
            exit 1
        fi
    done
fi
export SCREENS="$SEL"

# count_screens [key] — selected screens; `key` counts only those a device
# with views=key captures, i.e. everything that is not tap-driven.
count_screens() {
    local only_key="${1:-}" n=0 id when script desc
    while IFS='|' read -r id when script desc; do
        if [ -n "$SEL" ]; then
            case ",$SEL," in *",$id,"*) ;; *) continue ;; esac
        fi
        if [ "$only_key" = key ] && [ "$when" != always ]; then continue; fi
        n=$((n + 1))
    done < <(screens_rows)
    echo "$n"
}

# need_script theme|interactive — is any selected screen captured by it?
need_script() {
    local kind="$1" id when script desc
    while IFS='|' read -r id when script desc; do
        if [ -n "$SEL" ]; then
            case ",$SEL," in *",$id,"*) ;; *) continue ;; esac
        fi
        case "$script" in "$kind"|both) return 0 ;; esac
    done < <(screens_rows)
    return 1
}

SEL_ALL=$(count_screens)
SEL_KEY=$(count_screens key)
if need_script theme; then NEED_THEME=1; else NEED_THEME=0; fi
if need_script interactive; then NEED_INTERACTIVE=1; else NEED_INTERACTIVE=0; fi

# Only a real run needs the tooling; --dry-run stays usable without idb.
if [ -z "$DRY_RUN" ]; then
    : "${IDB_BIN:?set IDB_BIN to the idb client (see README.md)}"
    command -v magick >/dev/null || { echo "ImageMagick 'magick' not found" >&2; exit 1; }
fi

# No filters means every device; otherwise slug-substring or exact udid.
match_device() {
    [ ${#FILTERS[@]} -eq 0 ] && return 0
    local f
    for f in "${FILTERS[@]}"; do
        case "$1" in *"$f"*) return 0 ;; esac
        [ "$2" = "$f" ] && return 0
    done
    return 1
}

# -p is a shorthand for setting both columns at once; it reads `themes` and
# `views` out of scope on purpose, as the loops below use those names.
apply_pass_override() {
    case "$PASS_OVERRIDE" in
        A) themes=all; views=all ;;
        B) themes=key; views=key ;;
    esac
}

themes_full=$(grep -cvE '^[[:space:]]*(#|$)' "$SCRIPT_DIR/themes.txt")
themes_key=$(grep -cvE '^[[:space:]]*(#|$)' "$SCRIPT_DIR/themes-key.txt")

echo "runlist: $LIST ($DEVICES)"
echo "out:     $OUT_ROOT"
echo "scrub:   $([ "${SCRUB:-1}" = 0 ] && echo off || echo on)"
echo "screens: $([ -n "$SEL" ] && echo "$SEL" || echo "all ($SEL_ALL)")"
[ -n "$PASS_OVERRIDE" ] && echo "pass:    forced to $PASS_OVERRIDE"
[ ${#FILTERS[@]} -gt 0 ] && echo "devices: ${FILTERS[*]}"

if [ -n "$DRY_RUN" ]; then
    total=0; count=0
    while IFS='|' read -r udid ios dev label themes views rotate; do
        case "$udid" in \#*|"") continue ;; esac
        match_device "$dev" "$udid" || continue
        apply_pass_override
        if [ "$themes" = key ]; then t=$themes_key; else t=$themes_full; fi
        if [ "$views" = key ]; then v=$SEL_KEY; else v=$SEL_ALL; fi
        note=""
        [ "$v" -eq 0 ] && note="  (nothing selected for these views)"
        printf '  %-9s %-18s themes=%-4s views=%-4s %2d x %2d = %4d%s\n' \
            "$ios" "$dev" "$themes" "$views" "$t" "$v" "$((t * v))" "$note"
        total=$((total + t * v)); count=$((count + 1))
    done < "$DEVICES"
    echo "plan: $count device(s), ~$total images (estimate)"
    exit 0
fi

# Failures are recorded as files, not a shell array: with -j the device bodies
# run in subshells, and an array assignment there would vanish with them.
STATUS=$(mktemp -d)
trap 'rm -rf "$STATUS"' EXIT
fail() { echo "$1" >> "$STATUS/failures"; }

capture_device() {
    local udid="$1" ios="$2" dev="$3" label="$4" themes="$5" views="$6" rotate="$7"
    local installed container

    echo "### $ios/$dev (themes=$themes views=$views rotate=$rotate)"

    xcrun simctl boot "$udid" 2>/dev/null
    # Booting is asynchronous; wait for the runtime to actually come up.
    for _ in $(seq 1 30); do
        xcrun simctl list devices | grep -q "$udid.*Booted" && break
        sleep 2
    done

    # A device reports Booted before its app registry answers queries, so an
    # early miss here means "still coming up" as often as "not installed" —
    # retry before believing it, or a slow device silently drops out of the
    # matrix. Matched with `case` rather than a pipe to `grep -q`: grep exits
    # at the first match, and the SIGPIPE that can leave on listapps would
    # fail the pipeline under `pipefail` even though the app is present.
    installed=""
    for _ in $(seq 1 15); do
        case "$(xcrun simctl listapps "$udid" 2>/dev/null)" in
            *"$BUNDLE_ID"*) installed=1; break ;;
        esac
        sleep 2
    done
    if [ -z "$installed" ]; then
        echo "!! $dev: app not installed — skipping"
        fail "$dev (not installed)"; return 0
    fi

    # Same story: this errors with "Unable to lookup in current state" until
    # the container is mounted.
    container=""
    for _ in $(seq 1 10); do
        container=$(xcrun simctl get_app_container "$udid" "$BUNDLE_ID" data 2>/dev/null)
        [ -n "$container" ] && break
        sleep 2
    done
    if ! plutil -p "$container/Library/Preferences/$BUNDLE_ID.plist" 2>/dev/null | grep -q username; then
        echo "!! $dev: NOT LOGGED IN — log in manually, then re-run. Skipping."
        fail "$dev (not logged in)"; return 0
    fi

    # The `rotate` column says how the capture is turned upright, which only
    # holds if the device is actually in the orientation it assumes. A headless
    # boot is always portrait, so put it back first — otherwise every iPad
    # image comes out sideways with its sidebar collapsed. Non-fatal: a device
    # that will not rotate still captures, just wrongly, and says so.
    if [ "$rotate" = "0" ]; then
        # A portrait device that will not rotate is still captured correctly,
        # since rotate=0 applies no rotation — warn and carry on.
        "$SCRIPT_DIR/orient.sh" "$udid" portrait || fail "$dev orientation"
    else
        # A device with rotate!=0 that is stuck in the wrong orientation will
        # produce nothing but sideways images. Skip it rather than spend half
        # an hour filling the matrix with them.
        if ! "$SCRIPT_DIR/orient.sh" "$udid" landscape; then
            echo "!! $dev: could not rotate to landscape — skipping, every capture would be sideways"
            fail "$dev orientation (skipped)"
            xcrun simctl shutdown "$udid" 2>/dev/null
            return 0
        fi
    fi

    export ROTATE="$rotate"
    if [ "$NEED_THEME" = 1 ]; then
        "$SCRIPT_DIR/run-device.sh" "$udid" "$ios" "$dev" "$label" "$themes" || fail "$dev themes"
    fi
    # The tap-driven views are calibrated for one phone size; devices.txt says
    # which devices may run them.
    if [ "$views" = all ] && [ "$NEED_INTERACTIVE" = 1 ]; then
        "$SCRIPT_DIR/run-interactive.sh" "$udid" "$ios" "$dev" "$label" || fail "$dev interactive"
    fi
    unset ROTATE

    # Drop the scrub's "just refreshed" stamps so the next manual launch
    # re-fetches real data promptly instead of showing fakes for ~10 minutes.
    if [ "${SCRUB:-1}" != "0" ]; then
        "$SCRIPT_DIR/scrub-lists.sh" "$udid" release || true
    fi

    xcrun simctl shutdown "$udid" 2>/dev/null
}

# Resolve the runlist to the devices actually being captured, so the scheduler
# below can split them without re-reading the file.
ROWS=()
while IFS='|' read -r udid ios dev label themes views rotate; do
    case "$udid" in \#*|"") continue ;; esac
    match_device "$dev" "$udid" || continue
    apply_pass_override

    # A views=key device never captures the tap-driven screens, so a selection
    # made entirely of those would boot it for nothing.
    if [ "$views" = key ] && [ "$SEL_KEY" -eq 0 ]; then
        echo "!! $dev: only tap-driven screens selected, which this device does not capture — skipping"
        continue
    fi
    ROWS+=("$udid|$ios|$dev|$label|$themes|$views|$rotate")
done < "$DEVICES"

run_row() {
    local udid ios dev label themes views rotate
    IFS='|' read -r udid ios dev label themes views rotate <<< "$1"
    capture_device "$udid" "$ios" "$dev" "$label" "$themes" "$views" "$rotate"
}

if [ ${#ROWS[@]} -eq 0 ]; then
    echo "no devices selected"
elif [ "$JOBS" -le 1 ]; then
    for row in "${ROWS[@]}"; do run_row "$row"; done
else
    echo "--- ${#ROWS[@]} device(s) at up to $JOBS at a time"
    for row in "${ROWS[@]}"; do
        # bash 3.2 has no `wait -n`, so poll the running job count.
        while [ "$(jobs -rp | wc -l)" -ge "$JOBS" ]; do sleep 2; done
        # Key the log by udid, not slug: the matrix holds two devices called
        # ipad-pro-11, two ipad-pro-13 and two ipad-mini, and keying by slug
        # meant each pair truncated the other's output.
        udid=$(echo "$row" | cut -d'|' -f1)
        ( run_row "$row" ) > "$STATUS/log.$udid" 2>&1 &
    done
    wait
    for l in "$STATUS"/log.*; do [ -f "$l" ] && cat "$l"; done
fi

rc=0
if [ "$DO_VERIFY" = 1 ]; then
    # A blank or sideways capture is a failed run, not a footnote.
    "$SCRIPT_DIR/verify.sh" || rc=1
fi
[ "$DO_INDEX" = 1 ] && "$SCRIPT_DIR/make-index.sh"

if [ -f "$STATUS/failures" ]; then
    echo "FAILURES: $(tr '\n' ' ' < "$STATUS/failures")"
    rc=1
fi
[ "$rc" -eq 0 ] && echo "run-all complete — images in $OUT_ROOT"
exit "$rc"
