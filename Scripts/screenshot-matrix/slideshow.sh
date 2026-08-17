#!/bin/bash
# slideshow.sh [options]
# Turns the collage sheets into videos, one frame per sheet, for scrubbing
# through a whole set instead of opening 108 PNGs.
#
#   --by theme   one video per theme per family, frames = views
#                -> slideshows/by-theme/<theme>-<family>.mp4
#   --by device  one video per device, frames = views
#                -> slideshows/by-device/<ios>-<device>.mp4
#   --by family  one video per family, frames = views, each frame the full
#                device-by-theme grid — the one to scrub when hunting a fault
#                that only shows at one size or in one theme
#                -> slideshows/by-family/<family>.mp4
#
#   slideshow.sh                    # both directions, 1s per frame
#   slideshow.sh -b device -D 2     # devices only, 2s per frame
#   slideshow.sh -d 17-pro -w 3840  # one device, full width
#
# Options:
#   -b, --by theme|device|family|all  which sets to render (default: all)
#   -t, --theme LIST            limit to these themes
#   -d, --device LIST           limit to these devices
#   -D, --duration SEC          seconds per frame (default: 1)
#   -w, --width PX              max output width (default: 2560)
#   -o, --out DIR               output root (default: $OUT_ROOT/slideshows)
#   -C, --collages DIR          where the sheets are (default: $OUT_ROOT/collages)
#
# Sheets within one set are not all the same size — a view captured on 4 phones
# is wider than one captured on 2 — and the image2 demuxer will not accept
# frame dimensions changing mid-stream. So every frame is first padded onto a
# common canvas with ImageMagick, then encoded. That is also why the canvas is
# derived from the largest sheet in the set rather than a fixed 1080p box:
# these are 3000-4000px wide and downscaling them to fit a video convention
# would throw away the detail the sheets exist to show.
set -uo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

command -v ffmpeg >/dev/null || { echo "ffmpeg not found (brew install ffmpeg)" >&2; exit 1; }
command -v magick >/dev/null || { echo "ImageMagick 'magick' not found" >&2; exit 1; }

MODE=all
THEMES=""
DEVICES_ARG=""
DURATION=1
MAXW=2560
SRC=""
DEST=""

while [ $# -gt 0 ]; do
    case "$1" in
        -b|--by)       MODE="${2:?--by needs theme, device or both}"; shift 2 ;;
        -t|--theme)    THEMES="${2:?--theme needs a slug}"; shift 2 ;;
        -d|--device)   DEVICES_ARG="${2:?--device needs a slug}"; shift 2 ;;
        -D|--duration) DURATION="${2:?--duration needs seconds}"; shift 2 ;;
        -w|--width)    MAXW="${2:?--width needs pixels}"; shift 2 ;;
        -o|--out)      DEST="${2:?--out needs a directory}"; shift 2 ;;
        -C|--collages) SRC="${2:?--collages needs a directory}"; shift 2 ;;
        -h|--help)     sed -n '2,28p' "$0" | cut -c3-; exit 0 ;;
        *)             echo "unknown option: $1" >&2; exit 1 ;;
    esac
done

# `both` predates the family mode and still means theme+device.
case "$MODE" in theme|device|family|both|all) ;;
    *) echo "--by takes theme, device, family or all" >&2; exit 1 ;;
esac
SRC="${SRC:-$OUT_ROOT/collages}"
DEST="${DEST:-$OUT_ROOT/slideshows}"
[ -d "$SRC" ] || { echo "no collages at $SRC — run collage.sh first" >&2; exit 1; }

matches_filter() { # matches_filter <name> <comma-list>
    [ -z "$2" ] && return 0
    local w
    IFS=',' read -ra want <<< "$2"
    for w in "${want[@]}"; do
        w="$(echo "$w" | tr -d '[:space:]')"
        [ -z "$w" ] && continue
        case "$1" in *"$w"*) return 0 ;; esac
    done
    return 1
}

# render <out.mp4> <frame files...>
render() {
    local out="$1"; shift
    [ $# -eq 0 ] && return 1

    # Canvas = the largest sheet in the set, capped by --width, and even on
    # both axes because libx264 with yuv420p needs even dimensions.
    local maxw=0 maxh=0 f w h
    for f in "$@"; do
        w=$(magick identify -format '%w' "$f" 2>/dev/null) || continue
        h=$(magick identify -format '%h' "$f" 2>/dev/null) || continue
        [ "$w" -gt "$maxw" ] && maxw=$w
        [ "$h" -gt "$maxh" ] && maxh=$h
    done
    [ "$maxw" -eq 0 ] && return 1
    if [ "$maxw" -gt "$MAXW" ]; then
        maxh=$(( maxh * MAXW / maxw ))
        maxw=$MAXW
    fi
    maxw=$(( maxw / 2 * 2 )); maxh=$(( maxh / 2 * 2 ))

    local tmp; tmp=$(mktemp -d)
    local n=0
    for f in "$@"; do
        n=$((n + 1))
        magick "$f" -resize "${maxw}x${maxh}" -background '#1c1c1e' \
            -gravity center -extent "${maxw}x${maxh}" \
            "$tmp/$(printf '%04d' "$n").png" 2>/dev/null
    done

    mkdir -p "$(dirname "$out")"
    if ffmpeg -y -loglevel error \
        -framerate "1/$DURATION" -i "$tmp/%04d.png" \
        -c:v libx264 -pix_fmt yuv420p -r 30 -movflags +faststart \
        "$out" 2>/dev/null; then
        printf '  %-44s %2d frames  %dx%d  %s\n' "${out#$DEST/}" "$n" "$maxw" "$maxh" \
            "$(du -h "$out" | cut -f1 | tr -d ' ')"
        rm -rf "$tmp"
        return 0
    fi
    echo "  !! failed: $out" >&2
    rm -rf "$tmp"
    return 1
}

made=0

if [ "$MODE" = theme ] || [ "$MODE" = both ] || [ "$MODE" = all ]; then
    for d in "$SRC"/by-theme/*; do
        [ -d "$d" ] || continue
        theme=$(basename "$d")
        matches_filter "$theme" "$THEMES" || continue

        # Split by family: a phone sheet and an iPad sheet have very different
        # aspect ratios, and mixing them would letterbox most of the video.
        for family in iphones ipads; do
            frames=()
            for f in "$d"/*-"$family".png; do
                [ -f "$f" ] || continue
                frames+=("$f")
            done
            [ ${#frames[@]} -eq 0 ] && continue
            render "$DEST/by-theme/${theme}-${family}.mp4" "${frames[@]}" && made=$((made + 1))
        done
    done
fi

if [ "$MODE" = device ] || [ "$MODE" = both ] || [ "$MODE" = all ]; then
    for d in "$SRC"/by-device/*; do
        [ -d "$d" ] || continue
        devdir=$(basename "$d")
        matches_filter "$devdir" "$DEVICES_ARG" || continue

        frames=()
        for f in "$d"/*.png; do
            [ -f "$f" ] || continue
            frames+=("$f")
        done
        [ ${#frames[@]} -eq 0 ] && continue
        render "$DEST/by-device/${devdir}.mp4" "${frames[@]}" && made=$((made + 1))
    done
fi

if [ "$MODE" = family ] || [ "$MODE" = all ]; then
    for d in "$SRC"/by-family/*; do
        [ -d "$d" ] || continue
        family=$(basename "$d")

        frames=()
        for f in "$d"/*.png; do
            [ -f "$f" ] || continue
            frames+=("$f")
        done
        [ ${#frames[@]} -eq 0 ] && continue
        render "$DEST/by-family/${family}.mp4" "${frames[@]}" && made=$((made + 1))
    done
fi

echo "slideshow: $made video(s) in $DEST"
[ "$made" -gt 0 ]
