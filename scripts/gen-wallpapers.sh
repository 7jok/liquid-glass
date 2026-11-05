#!/usr/bin/env bash
# Liquid Glass — génère des fonds d'écran abstraits originaux (dégradés « aurora »
# doux) pour les thèmes clair et sombre. Aucun visuel Apple n'est utilisé.
#
# Principe : quelques grandes ellipses colorées sur une base, très floutées à
# basse résolution (rapide), agrandies en 2560x1440, puis un grain léger pour
# éviter le banding.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
W=640 H=360 OUT_W=2560 OUT_H=1440

# gen <fichier> <couleur-base> <grain> "<couleur> <cx> <cy> <rx> <ry>"...
gen() {
  local out="$1" base="$2" grain="$3"
  shift 3
  local draw=()
  for blob in "$@"; do
    read -r color cx cy rx ry <<<"$blob"
    draw+=(-fill "$color" -draw "ellipse $cx,$cy $rx,$ry 0,360")
  done
  magick -size "${W}x${H}" "xc:$base" "${draw[@]}" -blur 0x70 \
    -resize "${OUT_W}x${OUT_H}!" \
    \( -size "${OUT_W}x${OUT_H}" xc:gray50 +noise Gaussian -colorspace gray -evaluate multiply "$grain" \) \
    -compose overlay -composite -quality 92 "$out"
  echo "généré $out"
}

L="$ROOT/themes/liquid-glass/backgrounds"
D="$ROOT/themes/liquid-glass-dark/backgrounds"
mkdir -p "$L" "$D"

# Clair : ciel pâle, bleu glacier, lilas, pêche.
gen "$L/1-aurora-day.jpg" "#eef2f8" 0.5 \
  "#8fc3ff 120 300 260 170" "#c9b6ff 520 60 240 160" "#ffd3e6 600 340 220 140" "#a9eee0 300 20 200 120"
gen "$L/2-lagoon.jpg" "#eaf4f6" 0.5 \
  "#7fd3e6 80 80 260 180" "#9fb8ff 560 280 280 180" "#e9f6c9 320 380 240 120"
gen "$L/3-dune.jpg" "#f6f1ea" 0.5 \
  "#ffc9a1 100 320 300 160" "#f6a6c1 560 80 240 170" "#c8d3ff 360 160 200 120"

# Sombre : nuit profonde, bleu système, violet, framboise.
gen "$D/1-aurora-night.jpg" "#0a0f1e" 0.6 \
  "#1f4fd1 140 300 260 170" "#6a3fd6 520 60 240 160" "#b8326f 600 360 220 140" "#0a84ff 300 10 180 110"
gen "$D/2-abyss.jpg" "#06121a" 0.6 \
  "#0e6e8c 80 80 260 180" "#2d3fb8 560 280 280 180" "#1b8a6b 320 400 240 120"
gen "$D/3-ember.jpg" "#140b10" 0.6 \
  "#a8432e 100 320 300 160" "#7b2d8c 560 80 240 170" "#2a3f9e 360 160 200 120"
