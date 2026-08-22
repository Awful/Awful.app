#!/bin/bash
# label.sh <image.png> <label text>
# Splices a label strip onto the bottom of the image (app pixels untouched,
# so regression comparisons can crop the strip off). Idempotent-unsafe:
# run once per image; the capture pipeline only labels fresh captures.
set -euo pipefail

IMG="$1"
LABEL="$2"

WIDTH=$(magick identify -format '%w' "$IMG")
# Strip height scales with image width; ~3.5% looks right on phones and iPads.
STRIP_H=$(( WIDTH * 7 / 200 ))
[ "$STRIP_H" -lt 44 ] && STRIP_H=44
POINTSIZE=$(( STRIP_H * 55 / 100 ))

magick "$IMG" \
    -background '#1c1c1e' -fill '#f2f2f7' \
    -gravity south \
    -font '/System/Library/Fonts/Supplemental/Arial Bold.ttf' -pointsize "$POINTSIZE" \
    -splice "0x${STRIP_H}" \
    -annotate "+0+$(( STRIP_H * 22 / 100 ))" "$LABEL" \
    "$IMG"
