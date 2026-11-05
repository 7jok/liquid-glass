#!/usr/bin/env bash
# Liquid Glass — restauration d'une sauvegarde faite par backup.sh.
#
# Usage : restore.sh [dossier-de-sauvegarde]
#   Lancé depuis le dossier de sauvegarde lui-même, il se restaure sans argument.
#
# Ce que fait la restauration :
#   1. remet chaque fichier/dossier sauvegardé à l'identique (les fichiers ajoutés
#      depuis dans ces dossiers sont supprimés) ;
#   2. supprime les chemins qui n'existaient pas au moment de la sauvegarde ;
#   3. recharge gsettings, le thème et la police Omarchy, puis Hyprland et le shell.
# Les paquets installés ne sont PAS désinstallés : packages-before.txt permet de
# comparer (comm -13 packages-before.txt <(pacman -Qqe)).
set -euo pipefail

SRC="${1:-$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)}"

if [[ ! -d $SRC/files || ! -f $SRC/absent.txt ]]; then
  echo "$SRC ne ressemble pas à une sauvegarde Liquid Glass." >&2
  exit 1
fi

read -r -p "Restaurer la sauvegarde $SRC ? [o/N] " answer
[[ $answer =~ ^[oOyY]$ ]] || exit 0

# Arrête les services Liquid Glass éventuels avant de toucher aux fichiers.
systemctl --user disable --now liquid-glass-spotify.service 2>/dev/null || true

# 1. Fichiers sauvegardés (liste exacte dans saved.txt)
while IFS= read -r rel; do
  [[ -z $rel || ! -e $SRC/files/$rel && ! -L $SRC/files/$rel ]] && continue
  dst="$HOME/$rel"
  rm -rf -- "$dst"
  mkdir -p "$(dirname "$dst")"
  cp -a "$SRC/files/$rel" "$dst"
  echo "restauré   ~/$rel"
done <"$SRC/saved.txt"

# 2. Chemins créés depuis la sauvegarde
while IFS= read -r rel; do
  [[ -z $rel ]] && continue
  if [[ -e $HOME/$rel || -L $HOME/$rel ]]; then
    rm -rf -- "${HOME:?}/$rel"
    echo "supprimé   ~/$rel"
  fi
done <"$SRC/absent.txt"

# Commandes et cache propres à Liquid Glass (hors du périmètre sauvegardé).
# Seuls les liens symboliques sont retirés : un vrai fichier homonyme est laissé.
for f in "$HOME/.local/bin/liquid-glass" "$HOME/.local/bin/liquid-glass-spotify"; do
  if [[ -L $f ]]; then rm -f -- "$f"; echo "supprimé   ${f/#$HOME/\~}"; fi
done
[[ -d $HOME/.cache/liquid-glass ]] && rm -rf -- "${HOME:?}/.cache/liquid-glass" && echo "supprimé   ~/.cache/liquid-glass"

systemctl --user daemon-reload 2>/dev/null || true

# 3. Réglages système
[[ -s $SRC/gsettings-interface.ini ]] && dconf load /org/gnome/desktop/interface/ <"$SRC/gsettings-interface.ini" || true
theme="$(cat "$SRC/omarchy-theme.txt" 2>/dev/null || true)"
font="$(cat "$SRC/omarchy-font.txt" 2>/dev/null || true)"
[[ -n $font ]] && omarchy font set "$font" >/dev/null 2>&1 || true
[[ -n $theme ]] && omarchy theme set "$theme" || true

hyprctl reload >/dev/null 2>&1 || true
omarchy restart shell >/dev/null 2>&1 || true
omarchy restart terminal >/dev/null 2>&1 || true

echo "Restauration terminée."
