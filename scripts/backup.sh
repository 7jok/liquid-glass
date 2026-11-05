#!/usr/bin/env bash
# Liquid Glass — sauvegarde des configs touchées par le projet.
#
# Usage : scripts/backup.sh [dossier]
#   Par défaut : ~/.config-backup-<AAAA-MM-JJ_HHMM>
#
# La sauvegarde contient :
#   files/<chemin relatif à $HOME>   copie des fichiers/dossiers existants
#   absent.txt                       chemins qui n'existaient PAS (restore les supprimera)
#   gsettings-interface.ini          dump dconf de org.gnome.desktop.interface
#   omarchy-theme.txt / omarchy-font.txt   thème et police Omarchy actifs
#   packages-before.txt              paquets explicitement installés à ce moment
#   restore.sh                       copie du script de restauration
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEST="${1:-$HOME/.config-backup-$(date +%Y-%m-%d_%H%M)}"

# Chemins (relatifs à $HOME) que Liquid Glass peut créer ou modifier.
PATHS=(
  .config/hypr
  .config/omarchy
  .config/foot
  .config/alacritty
  .config/ghostty
  .config/kitty
  .config/starship.toml
  .config/btop
  .config/fastfetch
  .config/cava
  .config/gtk-3.0
  .config/gtk-4.0
  .config/qt5ct
  .config/qt6ct
  .config/Kvantum
  .config/fontconfig
  .config/environment.d
  .config/xdg-terminals.list
  .config/chromium-flags.conf
  .config/mimeapps.list
  .config/matugen
  .config/spotify-player
  .config/liquid-glass
  .config/systemd/user
  .face
)

if [[ -e $DEST ]]; then
  echo "Le dossier $DEST existe déjà, abandon." >&2
  exit 1
fi

mkdir -p "$DEST/files"
: >"$DEST/absent.txt"
: >"$DEST/saved.txt"

for rel in "${PATHS[@]}"; do
  src="$HOME/$rel"
  if [[ -e $src || -L $src ]]; then
    mkdir -p "$DEST/files/$(dirname "$rel")"
    # -a garde droits/dates/liens symboliques tels quels
    cp -a "$src" "$DEST/files/$rel"
    echo "$rel" >>"$DEST/saved.txt"
  else
    echo "$rel" >>"$DEST/absent.txt"
  fi
done

dconf dump /org/gnome/desktop/interface/ >"$DEST/gsettings-interface.ini" 2>/dev/null || true
omarchy theme current >"$DEST/omarchy-theme.txt" 2>/dev/null || true
omarchy font current >"$DEST/omarchy-font.txt" 2>/dev/null || true
pacman -Qqe >"$DEST/packages-before.txt" 2>/dev/null || true

cp "$HERE/restore.sh" "$DEST/restore.sh"
chmod +x "$DEST/restore.sh"

echo "Sauvegarde terminée : $DEST"
echo "Restauration : $DEST/restore.sh"
