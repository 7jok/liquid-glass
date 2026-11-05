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
  kvantum            # moteur de thème Qt
  qt5ct qt6ct        # réglages Qt5/Qt6 (police, icônes, style)
  python-pillow      # analyse d'image légère pour les couleurs/fonds
)

# AUR (thèmes libres façon macOS Tahoe, par vinceliuice)
AUR_PKGS=(
  mactahoe-gtk-theme          # thème GTK3/GTK4
  mactahoe-icon-theme-git     # icônes
  mactahoe-cursor-theme-git   # curseurs
)

echo "==> Paquets des dépôts officiels"
sudo pacman -S --needed --noconfirm "${REPO_PKGS[@]}"

echo "==> Paquets AUR"
missing=()
for p in "${AUR_PKGS[@]}"; do pacman -Q "$p" &>/dev/null || missing+=("$p"); done
if ((${#missing[@]})); then
  yay -S --needed --noconfirm --answerdiff None --answerclean None "${missing[@]}"
else
  echo "Déjà installés."
fi

echo "==> Terminé."
