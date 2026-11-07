#!/usr/bin/env bash
# Fonds du style Île : les dessins sur papier blanc passent en prune, le papier devient
# le fond du bureau et l'encre reste presque noire. Les images sombres sont écartées.
set -euo pipefail
REPO="$(cd "$(dirname "$0")/.." && pwd)"
OUT="$REPO/themes/ile/backgrounds"
mkdir -p "$OUT"
n=1
for f in "$OUT"/wh-* "$REPO"/themes/mono/backgrounds/*; do
  [ -f "$f" ] || continue
  case "$f" in *.jpg|*.jpeg|*.png|*.webp) ;; *) continue ;; esac
  mean=$(magick "$f[0]" -resize 64x64! -colorspace Gray -format '%[fx:mean]' info:)
  awk "BEGIN { exit !($mean > 0.42) }" || continue
  dest="$OUT/$(printf '%02d' "$n")-ile.jpg"
  magick "$f[0]" -resize 1920x1080^ -gravity center -extent 1920x1080 -colorspace Gray \
    -level 8%,92% +level-colors '#0d0b10,#322e39' -quality 88 "$dest"
  n=$((n + 1))
done
rm -f "$OUT"/wh-*
echo "$((n - 1)) fonds"
