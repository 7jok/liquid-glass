#!/usr/bin/env bash
# Développement : copie les plugins du dépôt vers ~/.config/omarchy/plugins
# (le chemin inverse de sync-from-system.sh). Usage : deploy-plugins.sh [nom…]
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DEST="$HOME/.config/omarchy/plugins"
names=("$@")
[ ${#names[@]} -eq 0 ] && names=($(cd "$ROOT/plugins" && ls -d liquid-glass.*))
for n in "${names[@]}"; do
  n="${n#liquid-glass.}"; n="liquid-glass.$n"
  rsync -a --delete --exclude '__pycache__' "$ROOT/plugins/$n/" "$DEST/$n/"
  omarchy plugin validate "$DEST/$n" >/dev/null 2>&1 || echo "validation de $n : à vérifier" >&2
  echo "déployé : $n"
done
