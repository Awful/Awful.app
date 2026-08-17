#!/bin/bash
# verify.sh — fails if any capture is a blank frame, or if a device was
# captured in the wrong orientation.
#
# BLANK: a dead simulator framebuffer produces zero pixel variance. The app is
# running, it just never drew. Per image.
#
# Measured over the app pixels — everything above label.sh's caption strip —
# and NOT over a centre crop. A centre crop was the obvious choice, since the
# caption strip always contains text and would keep whole-image variance above
# zero forever. But it also throws away the status bar, nav bar and toolbar,
# which are exactly the parts that prove the app drew something: a short thread
# under a solid-colour theme (Gas Chamber, say) leaves the middle of the screen
# uniform, and the centre crop called those perfectly good captures blank.
#
# SIDEWAYS: the device sat in a different orientation than devices.txt's
# `rotate` column assumes, so upright captures got rotated 90 degrees. This is
# what a headless boot does to every iPad (trap 5), and checking the file's
# aspect ratio does NOT catch it — rotating a portrait capture by 90 produces a
# landscape-shaped file that looks entirely plausible.
#
# The test instead uses the structure of the UI: interfaces are stacks of
# horizontal bands (status bar, nav bar, separators, lines of text), so row
# brightness varies more than column brightness, and rotating flips that. The
# score is row_stddev / col_stddev — above 1 upright, below 1 sideways.
#
# It is judged PER DEVICE, not per image, and that matters. A few screens are
# genuinely close to neutral: a dark-theme thread list is a column of thread
# tags, scoring about 0.76 upright and about 1.3 sideways, so no per-image
# threshold classifies it correctly in both directions. Whole devices, though,
# are never half-rotated — if the boot came up wrong, every screen on it is
# wrong. Taking the median over a device separates cleanly: measured here,
# upright devices sit around 2.5-6 and sideways ones around 0.3.
set -uo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

# Structure of the app pixels only — label.sh's caption strip is horizontal
# text and would bias every image toward "upright".
strip_height() {
    local s=$(( $1 * 7 / 200 ))
    [ "$s" -lt 44 ] && s=44
    echo "$s"
}

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

total=0; blank=0
for f in "$OUT_ROOT"/ios*/*/*.png; do
    [ -f "$f" ] || continue
    total=$((total + 1))

    w=$(magick identify -format '%w' "$f" 2>/dev/null) || continue
    h=$(magick identify -format '%h' "$f" 2>/dev/null) || continue
    content=$(( h - $(strip_height "$w") ))
    [ "$content" -gt 0 ] || continue

    sd=$(magick "$f" -gravity north -crop "x${content}+0+0" +repage \
         -colorspace Gray -format '%[fx:standard_deviation]' info: 2>/dev/null)
    if [ "$sd" = "0" ]; then
        blank=$((blank + 1))
        echo "BLANK: ${f#$OUT_ROOT/}"
        continue
    fi

    rowsd=$(magick "$f" -gravity north -crop "x${content}+0+0" +repage \
            -colorspace Gray -resize '1x256!' -format '%[fx:standard_deviation]' info: 2>/dev/null)
    colsd=$(magick "$f" -gravity north -crop "x${content}+0+0" +repage \
            -colorspace Gray -resize '256x1!' -format '%[fx:standard_deviation]' info: 2>/dev/null)
    [ -n "$rowsd" ] && [ -n "$colsd" ] || continue

    # One file of scores per device directory, for the median below.
    devdir=$(basename "$(dirname "$(dirname "$f")")")
    awk -v r="$rowsd" -v c="$colsd" \
        'BEGIN { printf "%.6f\n", (c <= 0 ? 99 : r / c) }' >> "$TMP/$devdir"
done

sideways=0
for scores in "$TMP"/*; do
    [ -f "$scores" ] || continue
    read -r median count < <(sort -n "$scores" | awk '{ v[NR] = $1 } END { print (NR % 2 ? v[(NR+1)/2] : (v[NR/2] + v[NR/2+1]) / 2), NR }')
    if awk -v m="$median" 'BEGIN { exit !(m < 1) }'; then
        sideways=$((sideways + 1))
        printf 'SIDEWAYS: %s — %d images, median row/col %.2f (expected >1)\n' \
            "$(basename "$scores")" "$count" "$median"
    fi
done

echo "verify: $total images, $blank blank, $sideways device(s) sideways"
[ "$blank" -eq 0 ] && [ "$sideways" -eq 0 ]
