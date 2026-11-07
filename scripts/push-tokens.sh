#!/usr/bin/env bash
# Recopie shared/Mac.js (mesures macOS) dans chaque plugin Liquid Glass,
# du dépôt et du système. Omarchy refuse les liens symboliques et les imports
# hors du dossier d'un plugin : chaque plugin garde donc sa copie.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SRC="$ROOT/shared/Mac.js"
for base in "$ROOT/plugins" "$HOME/.config/omarchy/plugins"; do
  for d in "$base"/liquid-glass.*/; do
    [ -d "$d" ] || continue
    cp "$SRC" "$d/Mac.js"
  done
done
echo "Mac.js recopié dans $(ls -d "$ROOT"/plugins/liquid-glass.*/ | wc -l) plugins"
