#!/usr/bin/env bash
# Polices des bureaux Linux : Material Symbols Rounded (icônes par ligature),
# Google Sans Flex, Rubik, Silkscreen, Pixelify Sans, Syncopate, Unbounded, toutes sous licence libre
# (Apache 2.0 / OFL), dans ~/.local/share/fonts/liquid-glass (sans sudo).
set -euo pipefail
DEST="$HOME/.local/share/fonts/liquid-glass"
mkdir -p "$DEST"
fetch() {
  local name="$1" url="$2"
  [ -s "$DEST/$name" ] && return 0
  if curl -fsSL --max-time 120 -o "$DEST/$name.part" "$url"; then
    mv "$DEST/$name.part" "$DEST/$name"; echo "    ✓ $name"
  else
    rm -f "$DEST/$name.part"; echo "    ! $name non téléchargée (hors ligne ?)" >&2
  fi
}
fetch MaterialSymbolsRounded.ttf "https://github.com/google/material-design-icons/raw/master/variablefont/MaterialSymbolsRounded%5BFILL,GRAD,opsz,wght%5D.ttf"
fetch GoogleSansFlex.ttf "https://raw.githubusercontent.com/google/fonts/main/ofl/googlesansflex/GoogleSansFlex%5BROND%2Copsz%2Cslnt%2Cwdth%2Cwght%5D.ttf"
fetch Rubik.ttf "https://github.com/google/fonts/raw/main/ofl/rubik/Rubik%5Bwght%5D.ttf"
# Pixel (paroles géantes, horloges, style Jouet) et display large (jour de la semaine)
fetch Silkscreen-Regular.ttf "https://raw.githubusercontent.com/google/fonts/main/ofl/silkscreen/Silkscreen-Regular.ttf"
fetch Silkscreen-Bold.ttf "https://raw.githubusercontent.com/google/fonts/main/ofl/silkscreen/Silkscreen-Bold.ttf"
fetch PixelifySans.ttf "https://raw.githubusercontent.com/google/fonts/main/ofl/pixelifysans/PixelifySans%5Bwght%5D.ttf"
fetch Syncopate-Bold.ttf "https://raw.githubusercontent.com/google/fonts/main/apache/syncopate/Syncopate-Bold.ttf"
fetch Syncopate-Regular.ttf "https://raw.githubusercontent.com/google/fonts/main/apache/syncopate/Syncopate-Regular.ttf"
fetch Unbounded.ttf "https://raw.githubusercontent.com/google/fonts/main/ofl/unbounded/Unbounded%5Bwght%5D.ttf"
# Polices à chasse fixe des terminaux animés (une par style, voir liquid-glass rice).
G="https://raw.githubusercontent.com/google/fonts/main/ofl"
fetch VT323-Regular.ttf "$G/vt323/VT323-Regular.ttf"
fetch SpaceMono-Regular.ttf "$G/spacemono/SpaceMono-Regular.ttf"
fetch SpaceMono-Bold.ttf "$G/spacemono/SpaceMono-Bold.ttf"
fetch IBMPlexMono-Regular.ttf "$G/ibmplexmono/IBMPlexMono-Regular.ttf"
fetch ShareTechMono-Regular.ttf "$G/sharetechmono/ShareTechMono-Regular.ttf"
fetch PressStart2P-Regular.ttf "$G/pressstart2p/PressStart2P-Regular.ttf"
fetch FiraCode.ttf "$G/firacode/FiraCode%5Bwght%5D.ttf"
fetch DMMono-Regular.ttf "$G/dmmono/DMMono-Regular.ttf"
fetch CourierPrime-Regular.ttf "$G/courierprime/CourierPrime-Regular.ttf"
fetch SyneMono-Regular.ttf "$G/synemono/SyneMono-Regular.ttf"
fetch MartianMono.ttf "$G/martianmono/MartianMono%5Bwdth,wght%5D.ttf"
fc-cache -f "$DEST" >/dev/null 2>&1 || true
