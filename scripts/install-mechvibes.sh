#!/usr/bin/env bash
# Rend l'AppImage de Mechvibes utilisable sur Omarchy :
#  - pas de FUSE 2 sur le système → on extrait l'AppImage dans ~/.local/opt/mechvibes
#  - libxdo.so.3 absent (xdotool récent = libxdo.so.4) → on embarque l'ancienne version
#  - lanceur ~/.local/bin/mechvibes + entrée dans le lanceur d'applis
#  - importe ses packs (eg-oreo…) pour liquid-glass-keys
# Usage : scripts/install-mechvibes.sh [chemin/vers/mechvibes-*.AppImage]
set -euo pipefail
APPIMAGE="${1:-$(ls -t "$HOME"/Downloads/mechvibes*.AppImage 2>/dev/null | head -1)}"
[ -f "$APPIMAGE" ] || { echo "AppImage Mechvibes introuvable (passer le chemin en argument)"; exit 1; }
DEST="$HOME/.local/opt/mechvibes"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

chmod +x "$APPIMAGE"
(cd "$TMP" && "$APPIMAGE" --appimage-extract >/dev/null)
rm -rf "$DEST"
mkdir -p "$(dirname "$DEST")"
mv "$TMP/squashfs-root" "$DEST"

# libxdo.so.3 depuis l'archive Arch (xdotool 3.x)
if ! ldconfig -p | grep -q 'libxdo.so.3'; then
  mkdir -p "$DEST/usr/lib"
  curl -sfL "https://archive.archlinux.org/packages/x/xdotool/xdotool-3.20211022.1-2-x86_64.pkg.tar.zst" -o "$TMP/xdo.pkg.tar.zst"
  bsdtar -xf "$TMP/xdo.pkg.tar.zst" -C "$TMP" usr/lib/libxdo.so.3
  cp "$TMP/usr/lib/libxdo.so.3" "$DEST/usr/lib/"
fi
grep -q LD_LIBRARY_PATH "$DEST/AppRun" ||
  sed -i 's|^export PATH=|export LD_LIBRARY_PATH="${HERE}/usr/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"\nexport WEBKIT_DISABLE_DMABUF_RENDERER=1\nexport PATH=|' "$DEST/AppRun"

mkdir -p "$HOME/.local/bin" "$HOME/.local/share/applications" "$HOME/.local/share/icons/hicolor/512x512/apps"
printf '#!/bin/sh\nexec "$HOME/.local/opt/mechvibes/AppRun" "$@"\n' > "$HOME/.local/bin/mechvibes"
chmod +x "$HOME/.local/bin/mechvibes"
cp "$DEST/mechvibes.png" "$HOME/.local/share/icons/hicolor/512x512/apps/mechvibes.png"
sed -e "s|^Exec=.*|Exec=$HOME/.local/bin/mechvibes %u|" "$DEST/mechvibes.desktop" > "$HOME/.local/share/applications/mechvibes.desktop"
update-desktop-database "$HOME/.local/share/applications" 2>/dev/null || true

if command -v ffmpeg >/dev/null && command -v liquid-glass-keys >/dev/null; then
  liquid-glass-keys import
fi
echo "Mechvibes installé : lancer « mechvibes » (ou depuis le lanceur)."
id -nG | grep -qw input || echo "Pour entendre les touches sous Wayland : sudo usermod -aG input \$USER, puis se reconnecter."
