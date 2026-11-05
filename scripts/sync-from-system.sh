#!/usr/bin/env bash
# Développement : recopie les plugins Liquid Glass installés (~/.config/omarchy/plugins)
# dans le dépôt. (Omarchy refuse les liens symboliques dans un plugin, donc les
# plugins sont des copies ; install.sh fait le chemin inverse.)
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
mkdir -p "$ROOT/plugins"
for d in "$HOME"/.config/omarchy/plugins/liquid-glass.*/; do
  name="$(basename "$d")"
  rsync -a --delete --exclude '__pycache__' "$d" "$ROOT/plugins/$name/"
  echo "synchronisé : $name"
done
