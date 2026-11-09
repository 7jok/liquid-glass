#!/bin/sh
# Récents du Finder : « mtime<TAB>taille<TAB>chemin », du plus récent au plus ancien.
# Documents ouverts récemment (recently-used.xbel, tenu par GTK/Qt/KDE) + fichiers modifiés
# ces 30 derniers jours dans les dossiers personnels (pas les dépôts de code, pas les cachés).
{
  x="$HOME/.local/share/recently-used.xbel"
  if [ -f "$x" ]; then
    python3 -I - "$x" <<'PY'
import os, sys, urllib.parse, re
for m in re.finditer(r'href="file://([^"]+)"', open(sys.argv[1], encoding="utf-8", errors="replace").read()):
    p = urllib.parse.unquote(m.group(1))
    try:
        st = os.stat(p)
    except OSError:
        continue
    if os.path.isfile(p):
        print(f"{st.st_mtime}\t{st.st_size}\t{p}")
PY
  fi
  for d in Desktop Documents Downloads Pictures Music Videos; do
    [ -d "$HOME/$d" ] && find "$HOME/$d" -maxdepth 4 -type f -mtime -30 -not -path '*/.*' -printf '%T@\t%s\t%p\n'
  done
} 2>/dev/null | awk -F'\t' '!seen[$3]++' | sort -rn | head -150
