#!/bin/bash
# Icônes et curseurs façon macOS (MacTahoe de vinceliuice, GPL-3) dans ~/.local/share/icons,
# sans sudo et sans lancer le script du projet : on copie seulement les fichiers d'icônes.
#   scripts/install-mac-icons.sh [dossier-du-depot-MacTahoe]
set -e
SRC=${1:-$HOME/.cache/liquid-glass/MacTahoe-icon-theme}
if [ ! -d "$SRC/src" ]; then
  git clone -q --depth 1 https://github.com/vinceliuice/MacTahoe-icon-theme.git "$SRC"
fi
DEST=$HOME/.local/share/icons
T=$DEST/MacTahoe
rm -rf "$T"; mkdir -p "$T/status"
cp -r "$SRC"/{COPYING,AUTHORS} "$SRC/src/index.theme" "$T"
cp -r "$SRC"/src/{actions,animations,apps,categories,devices,emotes,emblems,mimes,places,preferences} "$T"
cp -r "$SRC"/src/status/{16,22,24,32,symbolic} "$T/status"
rm -f "$T"/places/scalable/user-trash{,-full}-dark.svg
cp -r "$SRC"/links/{actions,apps,categories,devices,emotes,emblems,mimes,places,status,preferences} "$T"
# Curseurs (déjà construits dans cursors/dist)
if [ -d "$SRC/cursors/dist" ]; then
  rm -rf "$DEST/MacTahoe-cursors"; cp -r "$SRC/cursors/dist" "$DEST/MacTahoe-cursors"
fi
command -v gtk-update-icon-cache >/dev/null && gtk-update-icon-cache -q "$T" 2>/dev/null || true
echo "MacTahoe installé dans $T"
