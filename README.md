# Liquid Glass pour Omarchy

Une interface façon macOS « Liquid Glass » pour [Omarchy](https://omarchy.org)
(Arch + Hyprland), qui garde l'identité Linux et vit au rythme de Spotify :
la pochette devient le fond d'écran, ses couleurs teintent le bureau et les
paroles défilent derrière tes fenêtres.

Tout passe par les mécanismes prévus par Omarchy : thèmes utilisateur, plugins
du shell (Quickshell), hooks et fichiers de `~/.config`. Rien dans
`/usr/share/omarchy` n'est modifié.

---

## Installation

```bash
cd ~/Work/liquid-glass
./install.sh --packages     # 1re fois : sauvegarde + paquets (sudo/yay) + installation
./install.sh                # ensuite : mise à jour, relançable sans risque
```

Paquets installés par `--packages` (voir `scripts/install-packages.sh`) :
`spotify-launcher`, `playerctl`, `cava`, `matugen`, `inter-font` (dépôts) et
`mactahoe-gtk-theme`, `mactahoe-icon-theme-git`, `mactahoe-cursor-theme-git` (AUR).

Après l'installation des paquets : `liquid-glass system` applique GTK, icônes,
curseur et police.

### Tout annuler

Le premier `install.sh` sauvegarde l'état d'origine dans `~/.config-backup-<date>/` :

```bash
~/.config-backup-<date>/restore.sh
```

Cela restaure les fichiers sauvegardés, supprime ceux que Liquid Glass a créés,
recharge le thème et la police d'avant, puis relance Hyprland et le shell.
Les paquets installés ne sont pas désinstallés : la liste d'avant se trouve dans
`packages-before.txt`.

---

## Ce qu'on obtient

| Élément | Détail |
|---|---|
| **Verre** | Flou fort (7×3) avec vibrance, transparences partout, arrondi 16, liseré blanc 1 px à 15–25 %, ombres douces |
| **Animations** | Ressorts : zoom et fondu des fenêtres, glissement des bureaux, popin des calques |
| **Thèmes** | `liquid-glass` (clair, par défaut) et `liquid-glass-dark`, accent bleu Apple, fonds aurora originaux ; bascule ⌘⇧L ou mode Auto |
| **Barre** | Logo goutte de verre et menu système, nom de l'app active, bureaux, mini-lecteur, icônes d'état, centre de contrôle, horloge « jeu. 5 nov. 21:15 » |
| **Dock** | Capsule de verre, grossissement en vague (gaussienne), point sous les apps ouvertes, masquage auto en option |
| **Centre de contrôle** | Wi-Fi, Bluetooth, Concentration, Mode sombre, Night Shift, luminosité, volume, lecture en cours |
| **Spotlight** (⌘Espace) | Applications, calculatrice (`12*(3+4)` puis Entrée pour copier), commandes, fichiers (fd), `> commande`, recherche web |
| **Mission Control** (⌘↑, 4 doigts ↑) | Aperçus en direct qui glissent depuis leur place réelle, bandeau des bureaux, glisser une fenêtre sur un bureau pour l'y déplacer |
| **Sélecteur ⌘Tab** | Apps triées par usage récent ; relâcher ⌘ valide ; Q quitte l'app sélectionnée |
| **Verrouillage** | Date et grande horloge, avatar (`~/.face` ou initiale), champ pilule en verre qui secoue en cas d'erreur, pochette floutée et mini-lecteur pendant la lecture |
| **OSD** | Pilule de verre volume / luminosité au-dessus du dock |
| **Réglages** | Fenêtre « Réglages Système » qui modifie la config en direct |
| **Terminal** | foot en verre clair ou sombre, Starship sur deux lignes, fastfetch avec logo, btop transparent, cava |

### Spotify

- **Fond d'écran** : `cover` (pochette nette sur fond flou), `blur` ou `gradient`,
  avec le fondu natif d'Omarchy. Le lien du fond du thème n'est jamais modifié :
  après `restore_after_minutes` de pause, ou dès que le lecteur se ferme, le fond
  et les couleurs du thème reviennent.
- **Couleurs dynamiques** : l'accent de la pochette est appliqué en direct à la
  barre, aux panneaux, au dock, aux bordures Hyprland (dégradé) et aux terminaux
  ouverts (OSC 4/12). Désactivable.
- **Paroles synchronisées** (LRCLIB, gratuit et sans compte), en quatre modes
  combinables :
  - sur le bureau, derrière les fenêtres : ligne en cours nette, les autres
    floutées selon leur distance ;
  - widget flottant déplaçable (double-clic : karaoké) ;
  - dans la barre, à la place du titre ;
  - karaoké plein écran (⌘⌥M).
- **Mini-lecteur** dans la barre :
  - clic : popup avec pochette, progression déplaçable, contrôles, volume et raccourcis ;
  - clic milieu : lecture/pause ;
  - molette : piste suivante/précédente ;
  - clic droit : karaoké.
- **Visualiseur** cava aux couleurs de la pochette (désactivé par défaut).
- **Lecteurs pris en charge** : tout lecteur MPRIS (client officiel,
  spotify-player, spotifyd…), Spotify en priorité. « J'aime » n'apparaît que si
  `spotify_player` est installé, car MPRIS n'expose pas cette action.
- **Fonctionnement par événements** : un seul appel réseau par morceau, mis en
  cache. La position est extrapolée localement et rafraîchie 4×/s seulement quand
  des paroles synchronisées sont affichées. cava ne tourne que pendant la lecture
  et s'il est activé.

---

## Raccourcis

⌘ = touche Super. Liste complète à l'écran : **⌘K**. Liste Omarchy : **⌘⇧K**.

| Raccourci | Action | Remplace (et où l'action d'origine est partie) |
|---|---|---|
| ⌘ Espace | Spotlight | menu Omarchy → **⌘⌥ Espace** |
| ⌘⌥ Espace | Menu Omarchy | grille d'apps → bouton du dock et Spotlight |
| ⌘ Q | Quitter l'application (toutes ses fenêtres) | fermer la fenêtre (toujours sur ⌘W) |
| ⌘ W | Fermer la fenêtre | — |
| ⌘ Tab / ⌘⇧ Tab | Sélecteur d'apps | bureau suivant/précédent → ⌘← / ⌘→ |
| ⌘ ↑ | Mission Control | focus vers le haut → **⌘⌃↑** (⌘⌃↓ pour le bas) |
| ⌘ ← / → | Bureau précédent / suivant | focus gauche/droite (mosaïque : ⌘⇧ flèches pour échanger) |
| ⌘⇧ 3 / 4 / 5 | Capture plein écran / zone / menu de capture | déplacer la fenêtre au bureau 3/4/5 → **⌘⌃⇧ chiffre** (tous les bureaux) |
| ⌘ C / V / X / A | Copier / coller / couper / tout sélectionner | — (déjà dans Omarchy) |
| ⌘ K | Aide-mémoire Liquid Glass | raccourcis Omarchy → **⌘⇧K** |
| ⌘⇧ L | Clair / sombre | — |
| ⌃⌘ Q | Verrouiller | — (⌘⌃L verrouille aussi) |
| ⌘⌥ M | Paroles en karaoké | — |
| 4 doigts ↑ / ↓ | Ouvrir / fermer Mission Control | — |

Ctrl+flèches ne change **pas** de bureau, pour garder le saut de mot dans les apps.
Pour revenir aux raccourcis Omarchy d'origine : `[keys] macos_shortcuts = false`
(ou Réglages → Clavier).

---

## Personnaliser

Tout se règle dans **`~/.config/liquid-glass/config.toml`** (fichier commenté), ou
depuis **Réglages** (menu  → Réglages Liquid Glass, Spotlight « réglages », ou la
tuile du centre de contrôle).

```bash
liquid-glass set glass.blur_size 9        # une valeur, appliquée tout de suite
liquid-glass set spotify.wallpaper blur
liquid-glass mode dark|light|toggle|auto
liquid-glass apply                        # tout réappliquer
liquid-glass status
```

| Section | Clés |
|---|---|
| `appearance` | `mode` (light/dark/auto), `auto_light_at`, `auto_dark_at`, `font_ui`, `font_mono` |
| `glass` | `blur_size`, `blur_passes`, `opacity`, `window_opacity_active/inactive`, `rounding`, `gaps_in`, `gaps_out`, `animations` |
| `terminal` | `opacity_light`, `opacity_dark` |
| `dock` | `icon_size`, `magnification`, `autohide`, `always_visible` |
| `spotify` | `wallpaper` (off/cover/blur/gradient), `restore_after_minutes`, `dynamic_colors` |
| `lyrics` | `desktop`, `widget`, `bar` |
| `visualizer` | `enabled`, `bars` |
| `keys` | `macos_shortcuts` |

Ce qui s'applique à chaud :
- `spotify`, `lyrics`, `visualizer` : relus par le shell ;
- `dock` : recopié dans `shell.json` ;
- `glass` : rechargement de Hyprland ;
- `opacity`, `terminal` et police : régénération du thème (environ 1 s).

---

## Architecture

```
liquid-glass/
├── install.sh                 installation idempotente
├── bin/
│   ├── liquid-glass           CLI : config, thèmes, mode, GTK/icônes/curseur
│   └── liquid-glass-spotify   pochette HD, fond, palette, paroles, couleurs live
├── config/config.toml         config centrale par défaut
├── themes/liquid-glass{,-dark}/   thèmes Omarchy (colors.toml + fonds)
├── scripts/
│   ├── render-theme.py        génère shell.toml / hyprland.lua / foot.ini des thèmes
│   ├── backup.sh, restore.sh  sauvegarde et restauration complètes
│   ├── install-packages.sh    paquets (pacman + AUR)
│   ├── gen-wallpapers.sh      fonds aurora originaux (ImageMagick)
│   └── sync-from-system.sh    recopie les plugins installés vers le dépôt
├── hypr/
│   ├── liquid-glass.lua       flou, ombres, arrondis, ressorts, règles de calque
│   └── liquid-glass-bindings.lua  raccourcis façon macOS
├── hooks/theme-set-liquid-glass   GTK/icônes/curseur à chaque changement de thème
├── terminal/                  starship.toml, fastfetch/, cava/
└── plugins/                   plugins du shell Omarchy (copiés dans ~/.config/omarchy/plugins)
    ├── liquid-glass.logo        logo + menu système          (bar-widget)
    ├── liquid-glass.appname     nom de l'app active          (bar-widget)
    ├── liquid-glass.clock       horloge macOS                (bar-widget)
    ├── liquid-glass.control     centre de contrôle           (bar-widget)
    ├── liquid-glass.spotify     service MPRIS + mini-lecteur + paroles + visualiseur
    ├── liquid-glass.spotlight   Spotlight                    (overlay)
    ├── liquid-glass.mission     Mission Control              (overlay)
    ├── liquid-glass.switcher    ⌘Tab                         (overlay)
    ├── liquid-glass.cheatsheet  aide-mémoire                 (overlay)
    ├── liquid-glass.settings    Réglages                     (overlay)
    ├── liquid-glass.appearance  mode clair/sombre auto       (service)
    ├── liquid-glass.dock        clone de omarchy.dock (capsule + vague)
    ├── liquid-glass.lock        clone visuel de omarchy.lock (PAM inchangé)
    └── liquid-glass.osd         clone de omarchy.osd (pilule de verre)
```

**Circulation des données.** `config.toml` est lu par `liquid-glass`, qui en tire :
- `config.json`, lu à chaud par les plugins QML ;
- `hypr-vars.lua`, lu par `liquid-glass.lua` ;
- les fichiers des deux thèmes ;
- le sous-arbre `dock` de `shell.json`.

Côté Spotify, MPRIS alimente `liquid-glass.spotify`, qui appelle `liquid-glass-spotify track` :
- pochette et fond d'écran, appliqués via `omarchy-shell background transition` ;
- palette, appliquée via `liquid-glass-spotify colors` (applyTheme du shell,
  bordure Hyprland, OSC des terminaux) ;
- paroles LRCLIB.

**Sécurité.**
- Les téléchargements se font uniquement en HTTPS, vers une liste blanche
  (`*.scdn.co`, `*.spotifycdn.com`, lrclib.net), avec taille et délai bornés.
- Les images sont ré-encodées par ImageMagick avant usage.
- Aucune donnée externe ne passe par un shell : les commandes sont lancées en
  argv, et le texte est affiché en `Text.PlainText` dans QML.
- Les clones de `omarchy.lock` ne modifient que la vue ; l'authentification
  (PAM) reste celle d'Omarchy.

**Mise à jour d'Omarchy.**
- Les trois plugins clonés (dock, lock, osd) ne suivent pas les évolutions de leur
  original.
- `omarchy plugin` et `cloneSourceRestores` permettent de revenir aux versions
  d'Omarchy.
- Pour re-cloner, suivre la même méthode (voir l'historique git).

---

## Limites connues

- **Inter et MacTahoe** ne s'appliquent qu'après `./install.sh --packages`.
  D'ici là, la police de repli et le thème GTK d'origine sont utilisés.
- **Raccourcis** : ils sont vérifiés avec `hyprctl binds` et chaque commande a été
  testée. En revanche, l'appui physique (notamment le relâchement de ⌘ pour ⌘Tab)
  n'a pas pu être simulé.
  - En secours : `omarchy-shell liquid-glass.switcher commit`.
- **Mode Auto** : il est vérifié chaque minute par le shell, pas par un timer systemd.
- **fastfetch** lancé à la création même d'une fenêtre foot peut dessiner son
  logo sixel décalé, car la taille des cellules n'est pas encore connue. Lancé
  dans un terminal ouvert, il s'affiche correctement.
- **Paroles** : elles dépendent de LRCLIB. Certains titres n'ont que des paroles
  non synchronisées (affichées dans le karaoké) ou aucune.
- **Calendrier** : retirer l'horloge Omarchy de la barre désactive aussi son
  raccourci calendrier (⌘⌃⌥D).
- **Écrans** : un seul écran a été testé (eDP-1, échelle 1.5). Mission Control
  et les paroles gèrent plusieurs écrans, sans test.
