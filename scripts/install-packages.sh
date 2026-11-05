#!/usr/bin/env bash
# Liquid Glass — installation des paquets (idempotent : --needed ne réinstalle rien).
# À lancer dans un terminal, sudo/yay demanderont ton mot de passe.
set -euo pipefail

# Dépôts officiels
REPO_PKGS=(
  spotify-launcher   # client Spotify officiel (installe/maintient le binaire Spotify)
  playerctl          # contrôle MPRIS en ligne de commande (raccourcis média)
  cava               # visualiseur audio (optionnel, désactivé par défaut)
  matugen            # extraction de palette depuis la pochette
  inter-font         # police d'interface proche de SF Pro
  sassc              # requis par MacTahoe : sinon son script lance un « pacman -Syyu »
                     # que le garde-fou d'Omarchy bloque (mises à jour via omarchy update)
  # Qt : pas de Kvantum/qt6ct. Omarchy exporte QT_QPA_PLATFORMTHEME=gtk3, donc les
  # apps Qt suivent le thème GTK (MacTahoe), ses icônes et sa police.
)

# AUR (thèmes libres façon macOS Tahoe, par vinceliuice)
AUR_PKGS=(
  mactahoe-gtk-theme          # thème GTK3/GTK4
  mactahoe-icon-theme-git     # icônes
  mactahoe-cursor-theme-git   # curseurs
)

echo "==> Paquets des dépôts officiels"
sudo pacman -S --needed --noconfirm "${REPO_PKGS[@]}"

# Options Wayland pour Spotify (n'écrase pas un fichier existant).
conf="$HOME/.config/spotify-launcher.conf"
here="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
[[ -e $conf ]] || cp "$here/config/spotify-launcher.conf" "$conf"

# Premier lancement : spotify-launcher télécharge le client officiel (signé par
# Spotify) puis l'ouvre pour que tu puisses te connecter.
if [[ ${1-} != --no-launch ]] && ! pgrep -x spotify >/dev/null; then
  echo "Ouverture de Spotify pour la connexion…"
  setsid uwsm-app -- spotify-launcher >/dev/null 2>&1 &
fi

echo "==> Paquets AUR"
missing=()
for p in "${AUR_PKGS[@]}"; do pacman -Q "$p" &>/dev/null || missing+=("$p"); done
if ((${#missing[@]})); then
  yay -S --needed --noconfirm --answerdiff None --answerclean None "${missing[@]}"
else
  echo "Déjà installés."
fi

# Applique icônes, curseur et thème GTK maintenant qu'ils sont là.
command -v liquid-glass >/dev/null && liquid-glass system || true

echo "==> Terminé."
