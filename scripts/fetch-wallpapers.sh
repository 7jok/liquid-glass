#!/usr/bin/env bash
# Liquid Glass — télécharge les fonds d'écran « façon Mac » (libres) dans les thèmes.
#
# Sources (voir assets/wallpapers/CREDITS.md) :
#   - WhiteSur-wallpapers (vinceliuice, licence MIT) : Big Sur / Monterey dessinés ;
#   - MacTahoe-gtk-theme (vinceliuice, GPL-3.0) : Tahoe jour / nuit ;
#   - Unsplash (licence Unsplash, usage libre) : photos du lac Tahoe et de Yosemite.
# Les photos sont recadrées en 16:9 (2560x1440). Les fichiers déjà présents sont gardés.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
L="$ROOT/themes/liquid-glass/backgrounds"
D="$ROOT/themes/liquid-glass-dark/backgrounds"
WS=https://raw.githubusercontent.com/vinceliuice/WhiteSur-wallpapers/main/2k
MT=https://raw.githubusercontent.com/vinceliuice/MacTahoe-gtk-theme/main/wallpaper
US=https://unsplash.com/photos
mkdir -p "$L" "$D"
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT

# get <destination> <url>
get() {
  local out="$1" url="$2"
  [[ -s $out ]] && return 0
  curl -fsSL --proto '=https' --max-filesize 25000000 -o "$tmp/dl" "$url"
  magick "$tmp/dl" -resize '2560x1440^' -gravity center -extent 2560x1440 -quality 90 "$out"
  echo "ajouté ${out#"$ROOT"/}"
}

get "$L/01-tahoe-day.jpg"          "$MT/MacTahoe-day.jpeg"
get "$L/02-big-sur-light.jpg"      "$WS/WhiteSur-light.jpg"
get "$L/03-monterey-light.jpg"     "$WS/Monterey-light.jpg"
get "$L/04-emerald-bay.jpg"        "$US/v1I-OTndct8/download?force=true&w=2560"
get "$L/05-yosemite-valley.jpg"    "$US/YIgNXfXwYFU/download?force=true&w=2560"
get "$L/06-tahoe-dock.jpg"         "$US/QG42tXVTyag/download?force=true&w=2560"
get "$L/07-big-sur.jpg"            "$WS/WhiteSur.jpg"
get "$L/08-monterey-morning.jpg"   "$WS/Monterey-morning.jpg"

get "$D/01-tahoe-night.jpg"        "$MT/MacTahoe-night.jpeg"
get "$D/02-big-sur-dark.jpg"       "$WS/WhiteSur-dark.jpg"
get "$D/03-monterey-dark.jpg"      "$WS/Monterey-dark.jpg"
get "$D/04-monterey.jpg"           "$WS/Monterey.jpg"
get "$D/05-el-capitan-dusk.jpg"    "$US/1sQMDxS-cfw/download?force=true&w=2560"
get "$D/06-big-sur-morning.jpg"    "$WS/WhiteSur-morning.jpg"
