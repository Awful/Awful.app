#!/bin/bash
# collage.sh [options]
# Builds comparison sheets from a captured matrix, in one of two directions:
#
#   --by theme   (default) one sheet per view per theme, tiles = devices.
#                Phones and iPads are separate images, because a landscape iPad
#                beside a portrait phone wastes most of the canvas.
#                -> collages/by-theme/<theme>/<view>-{iphones,ipads}.png
#
#   --by device  one sheet per view per device, tiles = themes, in themes.txt
#                order rather than alphabetical so light and dark group up.
#                -> collages/by-device/<ios>-<device>/<view>-themes.png
#
#   --by family  one sheet per view per family, a grid of devices (columns)
#                against themes (rows). The other two modes each hold one of
#                those axes still, so neither shows a fault that depends on
#                both — a layout that only breaks on the small iPad in a dark
#                theme. Missing combinations are padded so the grid stays
#                square and a column really is one device.
#                -> collages/by-family/<family>/<view>-grid.png
#
#   collage.sh                             # devices compared, default theme
#   collage.sh -b device                   # themes compared, every device
#   collage.sh -b device -d iphone-17-pro  # ...just one device
#   collage.sh -t default,classic-dark     # two theme sheets
#   collage.sh -s bookmarks -S 75          # one view, larger tiles
#
# Options:
#   -b, --by theme|device  which comparison to build (default: theme)
#   -t, --theme LIST       theme slugs, comma-separated. --by theme defaults to
#                          `default`; --by device defaults to every theme.
#   -d, --device LIST      device slug fragments (--by device only)
#   -s, --screens LIST     screen ids or fragments (default: every screen)
#   -S, --scale PCT        tile size as a percentage of the capture (default: 50)
#   -c, --cols N           tiles per row (default: phones one row, iPads 3,
#                          themes 5)
#   -o, --out DIR          output root (default: $OUT_ROOT/collages)
#
# Every tile keeps the caption strip label.sh spliced on, so a sheet says which
# device and theme each panel is without further annotation. Tiles are
# bottom-aligned so those captions line up despite differing device heights.
set -uo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

command -v magick >/dev/null || { echo "ImageMagick 'magick' not found" >&2; exit 1; }

MODE=theme
THEMES=""
DEVICES_ARG=""
SCREENS_ARG=""
SCALE=50
SCALE_SET=""
COLS=""
# Widest a generated sheet should get. Generous, because --by family puts six
# landscape iPads in a row and squeezing that under 4400 shrank tiles to 26%.
MAX_SHEET_W="${MAX_SHEET_W:-6400}"
DEST="$OUT_ROOT/collages"

while [ $# -gt 0 ]; do
    case "$1" in
        -b|--by)      MODE="${2:?--by needs theme or device}"; shift 2 ;;
        -t|--theme)   THEMES="${2:?--theme needs a theme slug}"; shift 2 ;;
        -d|--device)  DEVICES_ARG="${2:?--device needs a slug}"; shift 2 ;;
        -s|--screens) SCREENS_ARG="${2:?--screens needs a list}"; shift 2 ;;
        -S|--scale)   SCALE="${2:?--scale needs a percentage}"; SCALE_SET=1; shift 2 ;;
        -c|--cols)    COLS="${2:?--cols needs a number}"; shift 2 ;;
        -o|--out)     DEST="${2:?--out needs a directory}"; shift 2 ;;
        -h|--help)    sed -n '2,34p' "$0" | cut -c3-; exit 0 ;;
        *)            echo "unknown option: $1" >&2; exit 1 ;;
    esac
done

case "$MODE" in
    theme|device|family) ;;
    *) echo "--by takes theme, device or family, not $MODE" >&2; exit 1 ;;
esac

screens_rows() { grep -vE '^[[:space:]]*(#|$)' "$SCRIPT_DIR/screens.txt"; }
themes_rows()  { grep -vE '^[[:space:]]*(#|$)' "$SCRIPT_DIR/themes.txt"; }

# --by family defaults to every theme: each device captures all 15, so the grid
# is full rather than ragged, and one sheet showing every device against every
# theme is the point of that mode. Narrow with -t for a shorter sheet.
[ "$MODE" = family ] && [ -z "$THEMES" ] && THEMES=all

# -t all means every theme in themes.txt, which is only useful now that every
# device captures all of them.
if [ "$THEMES" = all ]; then
    THEMES=""
    while IFS='|' read -r raw slug dark; do
        THEMES="${THEMES:+$THEMES,}$slug"
    done < <(themes_rows)
fi

# Same fragment matching as run-all.sh --screens, so "bookmarks" works here too.
SEL=""
if [ -n "$SCREENS_ARG" ]; then
    IFS=',' read -ra tokens <<< "$SCREENS_ARG"
    for t in "${tokens[@]}"; do
        t="$(echo "$t" | tr -d '[:space:]')"
        [ -z "$t" ] && continue
        while IFS='|' read -r id pass script desc; do
            case "$id" in
                *"$t"*) case ",$SEL," in *",$id,"*) ;; *) SEL="${SEL:+$SEL,}$id" ;; esac ;;
            esac
        done < <(screens_rows)
    done
    [ -z "$SEL" ] && { echo "no screens matched: $SCREENS_ARG" >&2; exit 1; }
fi

want_screen() {
    [ -z "$SEL" ] && return 0
    case ",$SEL," in *",$1,"*) return 0 ;; esac
    return 1
}

# montage args shared by both modes. -gravity south bottom-aligns each tile in
# its cell: devices and themes render at different heights, montage centres by
# default, and that leaves every caption strip on a different line.
FONT='/System/Library/Fonts/Supplemental/Arial Bold.ttf'

# A 6-wide by 15-tall grid is 6420x13059 — correct, but a column you scroll for
# five screens is not a comparison. Folding takes the bottom half of the rows
# and sets it beside the top half: same tiles, same scale, half the height,
# twice the width. Repeat while the sheet is still taller than wide.
#
# Sets FOLD_FILES and FOLD_COLS. Ragged folds are padded so columns stay
# aligned to whatever they were aligned to before.
fold_grid() { # fold_grid <cols> <pad-file> <files...>
    local cols="$1" pad="$2"; shift 2
    local all=("$@") rows half r i
    rows=$(( (${#all[@]} + cols - 1) / cols ))
    half=$(( (rows + 1) / 2 ))

    FOLD_FILES=()
    for (( r = 0; r < half; r++ )); do
        for (( i = 0; i < cols; i++ )); do
            local top=$(( r * cols + i ))
            FOLD_FILES+=("${all[$top]:-$pad}")
        done
        for (( i = 0; i < cols; i++ )); do
            local bot=$(( (r + half) * cols + i ))
            FOLD_FILES+=("${all[$bot]:-$pad}")
        done
    done
    FOLD_COLS=$(( cols * 2 ))
}

# Fold until the sheet stops being taller than wide, or twice at most: beyond
# that the rows are so interleaved that reading across one stops being useful.
autofold() { # autofold <cols> <tile-w> <tile-h> <pad> <files...>
    local cols="$1" tw="$2" th="$3" pad="$4"; shift 4
    FOLD_FILES=("$@"); FOLD_COLS="$cols"
    [ "${tw:-0}" -eq 0 ] || [ "${th:-0}" -eq 0 ] && return 0
    local n
    for n in 1 2; do
        local rows=$(( (${#FOLD_FILES[@]} + FOLD_COLS - 1) / FOLD_COLS ))
        [ "$rows" -lt 4 ] && break
        awk -v c="$FOLD_COLS" -v r="$rows" -v tw="$tw" -v th="$th" \
            'BEGIN { exit !((c * tw) / (r * th) < 1) }' || break
        fold_grid "$FOLD_COLS" "$pad" "${FOLD_FILES[@]}"
    done
}

build_sheet() { # build_sheet <out> <title> <cols> <files...>
    local out="$1" title="$2" tile="$3"; shift 3
    mkdir -p "$(dirname "$out")"

    # montage's own -title draws at a fixed pointsize and silently CROPS when
    # the text is wider than the sheet, which bites the narrow two-tile sheets.
    # So montage the tiles bare, then build a title bar sized to the finished
    # width: `-size WxH label:` picks a point size that fits the box, so the
    # text scales to the sheet instead of overflowing it.
    # -font is still needed here even with no title: montage errors out with
    # "unable to read font ''" otherwise.
    if ! magick montage "$@" \
        -background '#1c1c1e' -font "$FONT" \
        -gravity south \
        -geometry "${SCALE}%x${SCALE}%+12+12" -tile "${tile}x" \
        "$out" 2>/dev/null; then
        echo "  !! failed: $out" >&2
        return 1
    fi

    local w th
    w=$(magick identify -format '%w' "$out" 2>/dev/null) || return 1
    th=$(( w * 4 / 100 ))
    [ "$th" -lt 44 ] && th=44

    if ! magick \
        \( -background '#1c1c1e' -fill '#f2f2f7' -font "$FONT" \
           -size "$(( w - w / 12 ))x${th}" -gravity center label:"$title" \
           -background '#1c1c1e' -extent "${w}x$(( th + th / 2 ))" \) \
        "$out" -append "$out" 2>/dev/null; then
        echo "  !! failed to title: $out" >&2
        return 1
    fi

    printf '  %-46s %2d tiles  %s\n' "${out#$DEST/}" "$#" \
        "$(magick identify -format '%wx%h' "$out")"
    return 0
}

made=0

if [ "$MODE" = theme ]; then
    [ -z "$THEMES" ] && THEMES="default"
    IFS=',' read -ra theme_list <<< "$THEMES"
    for theme in "${theme_list[@]}"; do
        theme="$(echo "$theme" | tr -d '[:space:]')"
        [ -z "$theme" ] && continue

        while IFS='|' read -r id pass script desc; do
            want_screen "$id" || continue

            for family in iphone ipad; do
                # Iterate device directories, not a glob of files: sorting
                # whole paths compares "…-16-pro-max/" against "…-16-pro/",
                # and "-" sorts before "/", which lands Pro Max ahead of Pro.
                # As directory names "…-16-pro" is simply a prefix, so it
                # sorts first — the order you actually want.
                files=()
                for d in "$OUT_ROOT"/ios*-"$family"*; do
                    [ -d "$d" ] || continue
                    for f in "$d/$theme"/*_"$id".png; do
                        [ -f "$f" ] || continue
                        files+=("$f")
                    done
                done
                [ ${#files[@]} -eq 0 ] && continue

                tile="$COLS"
                if [ -z "$tile" ]; then
                    # Phones are narrow enough to sit in one row; iPads are not.
                    if [ "$family" = iphone ]; then tile=${#files[@]}; else tile=3; fi
                fi

                build_sheet "$DEST/by-theme/$theme/${id}-${family}s.png" \
                    "${id#*-}  ·  $theme" "$tile" "${files[@]}" && made=$((made + 1))
            done
        done < <(screens_rows)
    done
elif [ "$MODE" = family ]; then
    # Every device now captures all 15 themes, so the grid is full rather than
    # ragged and there is no reason to withhold rows. This makes tall sheets —
    # six iPads by fifteen themes is 6420x13059 — but that IS the comparison:
    # one image showing every device against every theme for a view. Narrow it
    # with -t when a shorter sheet is more useful than a complete one.
    :

    # One placeholder for absent device/theme combinations. A 1x1 tile costs
    # nothing and montage pads it out to the cell size, which is what keeps
    # every column aligned to one device.
    # 100x100, not 1x1: montage scales every tile by --scale, and a 1px pad
    # rounds to zero below 50%, which fails the whole sheet with "negative or
    # zero image size". Its actual size does not matter — montage pads each
    # cell out to the largest tile regardless.
    PAD=$(mktemp -d)/pad.png
    magick -size 100x100 xc:'#1c1c1e' "$PAD" 2>/dev/null
    FAMILY_SCALE_DEFAULT="$SCALE"

    for family in iphone ipad; do
        devs=()
        for d in "$OUT_ROOT"/ios*-"$family"*; do
            [ -d "$d" ] || continue
            devs+=("$d")
        done
        [ ${#devs[@]} -eq 0 ] && continue

        # Devices always go across, themes down. Transposing the landscape iPad
        # grid to keep tiles at 50% produced a 2800x6792 sheet, and a video of
        # those is a tall column — useless for scrubbing. Wide wins: the sheet
        # keeps a video-friendly aspect and detail comes from MAX_SHEET_W being
        # generous, or from opening the PNG.
        widest=0; tallest=0
        for d in "${devs[@]}"; do
            for f in "$d"/*/*.png; do
                [ -f "$f" ] || continue
                fw=$(magick identify -format '%w' "$f" 2>/dev/null) || break
                fh=$(magick identify -format '%h' "$f" 2>/dev/null) || break
                [ "${fw:-0}" -gt "$widest" ] && widest=$fw
                [ "${fh:-0}" -gt "$tallest" ] && tallest=$fh
                break
            done
        done

        DEVICES_ACROSS=1

        # Count the themes actually being laid out, for the width estimate.
        theme_count=0
        while IFS='|' read -r raw slug dark; do
            case ",$THEMES," in *",$slug,"*) theme_count=$((theme_count + 1)) ;; esac
        done < <(themes_rows)
        [ "$theme_count" -eq 0 ] && theme_count=1

        if [ "$DEVICES_ACROSS" = 1 ]; then cols=${#devs[@]}; else cols=$theme_count; fi

        SCALE="$FAMILY_SCALE_DEFAULT"
        if [ -z "$SCALE_SET" ] && [ "$widest" -gt 0 ]; then
            SCALE=$(( MAX_SHEET_W * 100 / (cols * widest) ))
            [ "$SCALE" -gt 50 ] && SCALE=50
            [ "$SCALE" -lt 12 ] && SCALE=12
        fi

        while IFS='|' read -r id pass script desc; do
            want_screen "$id" || continue

            # tile_for <device-dir> <theme-slug> — the capture, or the pad that
            # holds a gap open so columns stay aligned to one thing.
            tile_for() {
                local f
                for f in "$1/$2"/*_"$id".png; do
                    [ -f "$f" ] && { printf '%s' "$f"; return 0; }
                done
                printf '%s' "$PAD"
                return 1
            }

            files=(); found=0
            if [ "$DEVICES_ACROSS" = 1 ]; then
                while IFS='|' read -r raw slug dark; do
                    case ",$THEMES," in *",$slug,"*) ;; *) continue ;; esac
                    row=(); rowfound=0
                    for d in "${devs[@]}"; do
                        t=$(tile_for "$d" "$slug") && rowfound=1
                        row+=("$t")
                    done
                    # Skip a theme none of these devices captured, rather than
                    # emitting a row of nothing but placeholders.
                    [ "$rowfound" = 1 ] && { files+=("${row[@]}"); found=$((found + 1)); }
                done < <(themes_rows)
                layout="devices across, themes down"
            else
                for d in "${devs[@]}"; do
                    row=(); rowfound=0
                    while IFS='|' read -r raw slug dark; do
                        case ",$THEMES," in *",$slug,"*) ;; *) continue ;; esac
                        t=$(tile_for "$d" "$slug") && rowfound=1
                        row+=("$t")
                    done < <(themes_rows)
                    [ "$rowfound" = 1 ] && { files+=("${row[@]}"); found=$((found + 1)); }
                done
                layout="themes across, devices down"
            fi
            [ "$found" -eq 0 ] && continue

            autofold "$cols" "$widest" "$tallest" "$PAD" "${files[@]}"
            [ "$FOLD_COLS" -gt "$cols" ] && layout="$layout, folded"
            build_sheet "$DEST/by-family/${family}s/${id}-grid.png" \
                "${id#*-}  ·  ${family}s  ·  $layout" \
                "$FOLD_COLS" "${FOLD_FILES[@]}" && made=$((made + 1))
        done < <(screens_rows)
    done
else
    for d in "$OUT_ROOT"/ios*-*; do
        [ -d "$d" ] || continue
        devdir=$(basename "$d")

        if [ -n "$DEVICES_ARG" ]; then
            keep=""
            IFS=',' read -ra want <<< "$DEVICES_ARG"
            for w in "${want[@]}"; do
                w="$(echo "$w" | tr -d '[:space:]')"
                [ -z "$w" ] && continue
                case "$devdir" in *"$w"*) keep=1 ;; esac
            done
            [ -z "$keep" ] && continue
        fi

        while IFS='|' read -r id pass script desc; do
            want_screen "$id" || continue

            # themes.txt order, not directory order: it runs light themes then
            # dark, which is how you want them laid out for comparison.
            files=()
            while IFS='|' read -r raw slug dark; do
                if [ -n "$THEMES" ]; then
                    case ",$THEMES," in *",$slug,"*) ;; *) continue ;; esac
                fi
                for f in "$d/$slug"/*_"$id".png; do
                    [ -f "$f" ] || continue
                    files+=("$f")
                done
            done < <(themes_rows)
            [ ${#files[@]} -eq 0 ] && continue

            # Pick the column count whose finished sheet is closest to 16:9.
            # A fixed 5 wide put 15 portrait themes into a 3135x4258 column,
            # which reads badly and makes a tall, unscrubdable video; 8 wide
            # lands the same tiles at roughly 1.8:1.
            if [ -n "$COLS" ]; then
                tile="$COLS"
            else
                tw=$(magick identify -format '%w' "${files[0]}" 2>/dev/null || echo 0)
                th=$(magick identify -format '%h' "${files[0]}" 2>/dev/null || echo 0)
                if [ "${tw:-0}" -gt 0 ] && [ "${th:-0}" -gt 0 ]; then
                    # Closest-to-16:9 alone gets this wrong: for two landscape
                    # tiles, stacked scores 0.72 and side-by-side 2.89, so the
                    # nearer number is the stacked one — which is the worse
                    # sheet. These are for comparing, so wide beats tall: only
                    # consider layouts at 1.3:1 or wider, and fall back to the
                    # widest available when nothing reaches that.
                    tile=$(awk -v n="${#files[@]}" -v tw="$tw" -v th="$th" 'BEGIN {
                        best = 0; bestd = 1e9; widest = 1; widesta = 0
                        for (c = 1; c <= n; c++) {
                            rows = int((n + c - 1) / c)
                            a = (c * tw) / (rows * th)
                            if (a > widesta) { widesta = a; widest = c }
                            if (a < 1.3) continue
                            d = a - 1.78; if (d < 0) d = -d
                            if (d < bestd) { bestd = d; best = c }
                        }
                        print (best ? best : widest)
                    }')
                else
                    tile=5
                fi
            fi
            [ ${#files[@]} -lt "$tile" ] && tile=${#files[@]}
            [ "${tile:-0}" -lt 1 ] && tile=1

            DEV_PAD="${DEV_PAD:-$(mktemp -d)/pad.png}"
            [ -f "$DEV_PAD" ] || magick -size 100x100 xc:'#1c1c1e' "$DEV_PAD" 2>/dev/null
            autofold "$tile" "$tw" "$th" "$DEV_PAD" "${files[@]}"
            build_sheet "$DEST/by-device/$devdir/${id}-themes.png" \
                "${id#*-}  ·  $devdir" "$FOLD_COLS" "${FOLD_FILES[@]}" && made=$((made + 1))
        done < <(screens_rows)
    done
fi

echo "collage: $made sheet(s) in $DEST"
[ "$made" -gt 0 ]
