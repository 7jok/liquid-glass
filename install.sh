#!/usr/bin/env bash
# ============================================================================
# Liquid Glass — installation (idempotente : relançable sans risque).
#
#   ./install.sh               installe / met à jour
#   ./install.sh --packages    installe aussi les paquets (sudo + yay, interactif)
#   ./install.sh --no-backup   ne crée pas de sauvegarde (déconseillé au 1er lancement)
#
# Ce que fait le script (rien dans /usr/share/omarchy n'est touché) :
#   1. sauvegarde ~/.config-backup-<date> (+ restore.sh) au premier lancement
#   2. liens : thèmes, commandes, config Hyprland, Starship/fastfetch/cava
#   3. copie des plugins du shell (Omarchy refuse les liens symboliques)
#   4. hook theme-set, config centrale, ajouts à shell.json (jq, écriture atomique)
#   5. liquid-glass apply + system, rechargement de Hyprland et du shell
# ============================================================================
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CFG="${XDG_CONFIG_HOME:-$HOME/.config}"
STATE="$CFG/liquid-glass"
MARKER="$STATE/.installed"

DO_PACKAGES=0
DO_BACKUP=1
for arg in "$@"; do
  case "$arg" in
    --packages) DO_PACKAGES=1 ;;
    --no-backup) DO_BACKUP=0 ;;
    -h|--help) sed -n '2,16p' "$0"; exit 0 ;;
    *) echo "Option inconnue : $arg" >&2; exit 2 ;;
  esac
done

say()  { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
ok()   { printf '    \033[32m✓\033[0m %s\n' "$*"; }
warn() { printf '    \033[33m!\033[0m %s\n' "$*"; }

# Lien symbolique idempotent ; un fichier réel déjà présent est mis de côté (.bak.<date>).
link() {
  local src="$1" dst="$2"
  mkdir -p "$(dirname "$dst")"
  if [ -L "$dst" ] && [ "$(readlink -f "$dst")" = "$(readlink -f "$src")" ]; then return; fi
  if [ -e "$dst" ] && [ ! -L "$dst" ]; then mv "$dst" "$dst.bak.$(date +%s)"; warn "$dst existant mis de côté (.bak)"; fi
  ln -sfn "$src" "$dst"
}

# ---------------------------------------------------------------- 0. prérequis
say "Vérification des prérequis"
missing=()
for cmd in omarchy omarchy-shell hyprctl jq python3 magick fd; do
  command -v "$cmd" >/dev/null || missing+=("$cmd")
done
if ((${#missing[@]})); then
  echo "Commandes manquantes : ${missing[*]}" >&2
  echo "Ce projet vise Omarchy (Arch + Hyprland + omarchy-shell)." >&2
  exit 1
fi
python3 -c 'import tomllib' 2>/dev/null || { echo "Python ≥ 3.11 requis (tomllib)." >&2; exit 1; }
ok "Omarchy $(omarchy version 2>/dev/null | head -1)"

# ---------------------------------------------------------------- 1. sauvegarde
if ((DO_BACKUP)) && [ ! -f "$MARKER" ]; then
  say "Sauvegarde de la configuration actuelle"
  "$REPO/scripts/backup.sh"
fi

# ---------------------------------------------------------------- 2. paquets
if ((DO_PACKAGES)); then
  say "Paquets (sudo / yay)"
  "$REPO/scripts/install-packages.sh"
else
  for p in spotify-launcher playerctl cava inter-font mactahoe-gtk-theme; do
    pacman -Q "$p" &>/dev/null || { warn "paquet $p absent — lancer ./install.sh --packages (ou scripts/install-packages.sh)"; break; }
  done
fi

# ---------------------------------------------------------------- 3. fonds et thèmes
say "Thèmes Liquid Glass (clair + sombre)"
for t in liquid-glass liquid-glass-dark; do
  if ! compgen -G "$REPO/themes/$t/backgrounds/*.jpg" >/dev/null; then "$REPO/scripts/gen-wallpapers.sh"; break; fi
done
[[ -e $REPO/themes/liquid-glass/backgrounds/01-tahoe-day.jpg ]] || "$REPO/scripts/fetch-wallpapers.sh" || warn "fonds Mac non téléchargés (hors ligne ?)"
link "$REPO/themes/liquid-glass" "$CFG/omarchy/themes/liquid-glass"
link "$REPO/themes/liquid-glass-dark" "$CFG/omarchy/themes/liquid-glass-dark"
ok "thèmes liés dans ~/.config/omarchy/themes"

# ---------------------------------------------------------------- 4. commandes
say "Commandes"
for b in liquid-glass liquid-glass-spotify; do link "$REPO/bin/$b" "$HOME/.local/bin/$b"; done
ok "liquid-glass, liquid-glass-spotify → ~/.local/bin"

# ---------------------------------------------------------------- 5. config centrale
say "Configuration centrale"
mkdir -p "$STATE"
if [ ! -f "$STATE/config.toml" ]; then
  cp "$REPO/config/config.toml" "$STATE/config.toml"; ok "config.toml créée"
else
  # Ajoute les sections apparues dans les versions suivantes, sans toucher aux valeurs.
  python3 - "$REPO/config/config.toml" "$STATE/config.toml" <<'PY'
import sys, tomllib, re
default_txt = open(sys.argv[1]).read()
user_path = sys.argv[2]
user = tomllib.load(open(user_path, "rb"))
blocks = re.split(r"(?m)^(?=\[)", default_txt)
added = [b for b in blocks if b.startswith("[") and b[1:b.index("]")] not in user]
if added:
    with open(user_path, "a") as f:
        f.write("\n" + "\n".join(b.rstrip() + "\n" for b in added))
    print("    + sections ajoutées : " + ", ".join(b[1:b.index("]")] for b in added))
PY
  ok "config.toml conservée"
fi

# ---------------------------------------------------------------- 6. Hyprland
say "Hyprland"
link "$REPO/hypr/liquid-glass.lua" "$CFG/hypr/liquid-glass.lua"
link "$REPO/hypr/liquid-glass-bindings.lua" "$CFG/hypr/liquid-glass-bindings.lua"
if ! grep -q 'require("hypr.liquid-glass")' "$CFG/hypr/hyprland.lua"; then
  cp "$CFG/hypr/hyprland.lua" "$CFG/hypr/hyprland.lua.bak.$(date +%s)"
  printf '\n-- Liquid Glass (doit rester en dernier : passe devant le mode glassy)\nrequire("hypr.liquid-glass")\n' >> "$CFG/hypr/hyprland.lua"
  ok "require ajouté à la fin de hyprland.lua"
else
  ok "hyprland.lua déjà configuré"
fi

# ---------------------------------------------------------------- 7. terminal
say "Terminal (Starship, fastfetch, cava, btop)"
link "$REPO/terminal/starship.toml" "$CFG/starship.toml"
for f in config.jsonc logo.png logo.txt; do
  [ -e "$REPO/terminal/fastfetch/$f" ] && link "$REPO/terminal/fastfetch/$f" "$CFG/fastfetch/$f"
done
link "$REPO/terminal/cava/config" "$CFG/cava/config"
if [ -f "$CFG/btop/btop.conf" ]; then
  sed -i 's/^theme_background = .*/theme_background = false/' "$CFG/btop/btop.conf"
fi
ok "liens en place (fichiers existants mis de côté en .bak)"

# ---------------------------------------------------------------- 8. hook de thème
say "Hook theme-set"
mkdir -p "$CFG/omarchy/hooks/theme-set.d"
install -m 755 "$REPO/hooks/theme-set-liquid-glass" "$CFG/omarchy/hooks/theme-set.d/20-liquid-glass"
ok "20-liquid-glass installé"

# ---------------------------------------------------------------- 9. plugins du shell
say "Plugins du shell"
for dir in "$REPO"/plugins/liquid-glass.*; do
  name="$(basename "$dir")"
  rm -rf "$CFG/omarchy/plugins/$name.tmp"
  cp -r "$dir" "$CFG/omarchy/plugins/$name.tmp"
  rm -rf "$CFG/omarchy/plugins/$name"
  mv "$CFG/omarchy/plugins/$name.tmp" "$CFG/omarchy/plugins/$name"
  omarchy plugin validate "$CFG/omarchy/plugins/$name" >/dev/null 2>&1 || warn "validation de $name : à vérifier (omarchy plugin validate)"
done
ok "$(ls -d "$REPO"/plugins/liquid-glass.* | wc -l) plugins copiés"

# ---------------------------------------------------------------- 10. shell.json
say "shell.json (barre, dock, plugins)"
SJ="$CFG/omarchy/shell.json"
[ -f "$SJ" ] || cp "${OMARCHY_PATH:-/usr/share/omarchy}/config/omarchy/shell.json" "$SJ"
cp "$SJ" "$SJ.bak.$(date +%s)"
tmp="$(mktemp)"
jq --argjson dock "$(python3 -c '
import tomllib, json, os
d = tomllib.load(open(os.path.expanduser("~/.config/liquid-glass/config.toml"), "rb")).get("dock", {})
print(json.dumps({"iconSize": d.get("icon_size", 42), "magnification": d.get("magnification", 1.6),
                  "autohide": d.get("autohide", False), "alwaysVisible": d.get("always_visible", True)}))')" '
  def addids($ids): (. // []) as $cur | $cur + [ $ids[] | select(. as $i | ($cur | map(if type=="object" then .id else . end) | index($i)) | not) | {id: .} ];
  def addstr($xs): (. // []) as $cur | $cur + [ $xs[] | select(. as $x | $cur | index($x) | not) ];
  def ids: map(.id);
  .plugins |= addids(["liquid-glass.dock","liquid-glass.spotify","liquid-glass.spotlight","liquid-glass.mission",
                      "liquid-glass.switcher","liquid-glass.cheatsheet","liquid-glass.settings","liquid-glass.appearance",
                      "liquid-glass.lock","liquid-glass.osd","liquid-glass.widgets","liquid-glass.hotcorners"])
  | .disabledPlugins |= addstr(["omarchy.dock","omarchy.lock","omarchy.osd"])
  | .cloneSourceRestores |= addstr(["liquid-glass.dock","liquid-glass.lock","liquid-glass.osd"])
  | .dock = ((.dock // {}) + {position: "bottom"} + $dock)
  # Barre : logo + nom de l app à gauche ; mini-lecteur, centre de contrôle et horloge à droite.
  | .bar.layout.left = ([{id:"liquid-glass.logo"},{id:"liquid-glass.appname"}]
                        + [(.bar.layout.left // [])[] | select(.id != "liquid-glass.logo" and .id != "liquid-glass.appname")])
  | .bar.layout.right = ([{id:"liquid-glass.spotify"}]
                        + [(.bar.layout.right // [])[] | select(.id != "liquid-glass.spotify" and .id != "liquid-glass.control"
                                                                 and .id != "liquid-glass.clock" and .id != "omarchy.clock")]
                        + [{id:"liquid-glass.control"},{id:"liquid-glass.clock"}])
' "$SJ" > "$tmp"
jq empty "$tmp" && mv "$tmp" "$SJ"
ok "plugins activés, omarchy.dock/lock/osd remplacés par leurs clones, barre réorganisée"

omarchy bar background glassy >/dev/null 2>&1 || true
omarchy hyprland window transparency glassy >/dev/null 2>&1 || true

# ---------------------------------------------------------------- 11. application
say "Application"
"$HOME/.local/bin/liquid-glass" apply
"$HOME/.local/bin/liquid-glass" system || warn "réglages GTK : installer les paquets puis relancer « liquid-glass system »"
hyprctl reload >/dev/null
errors="$(hyprctl configerrors)"
[ -z "$errors" ] && ok "Hyprland : aucune erreur" || { warn "Hyprland signale :"; echo "$errors"; }
timeout 25 omarchy restart shell >/dev/null 2>&1 || warn "redémarrage du shell : relancer « omarchy restart shell »"

date -Iseconds > "$MARKER"
say "Terminé. ⌘K pour l'aide-mémoire, menu  → Réglages Liquid Glass pour tout ajuster."
