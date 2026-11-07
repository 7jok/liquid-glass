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
| **Centre de contrôle** | Capsules de verre flottantes qui arrivent en cascade : Concentration (Ne pas déranger, Travail, Personnel, Sommeil), Wi-Fi, Bluetooth, Mode avion, lecture en cours, boutons ronds au choix (`[control] buttons`), Son avec sortie, Écran, indicateur micro / enregistrement |
| **Spotlight** (⌘Espace) | Barre pilule + 5 boutons (Ctrl 1–5) : Applications, Fichiers, Actions, Presse-papiers (avec images), Musique ; calculatrice, `> commande`, recherche web |
| **Mission Control** (⌘↑, 4 doigts ↑) | Aperçus en direct qui glissent depuis leur place réelle, bandeau des bureaux, glisser une fenêtre sur un bureau pour l'y déplacer |
| **Sélecteur ⌘Tab** | Apps triées par usage récent ; relâcher ⌘ valide ; Q quitte l'app sélectionnée |
| **Verrouillage** | Fond net, date et horloge en verre, notifications en haut à droite, widget musique au-dessus de l'avatar ; sa bulle l'agrandit (grande pochette, fond de pochette flouté, paroles synchronisées à côté) ; on le déplace avec inertie |
| **OSD** | Pilule de verre volume / luminosité au-dessus du dock |
| **Réglages** | Fenêtre façon Tahoe : recherche, compte, Wi-Fi, Bluetooth, Réseau, Batterie, Apparence (verre, police), Centre de contrôle, Bureau et Dock, Écrans, Fond d'écran (grille), Notifications, Son, Concentration, Musique, Écran verrouillé (styles d'horloge, aperçu), Utilisateurs (photo)… |
| **Widgets** | Horloge numérique en verre, calendrier, météo large heure par heure, batterie ; widget musique libre (petit / moyen / grand) qui glisse comme sur une patinoire, bulle des paroles, aléatoire / répétition |
| **Terminal** | foot en verre clair ou sombre, Starship sur deux lignes, fastfetch avec logo goutte en pixel art (`scripts/gen-fastfetch-logo.py`), btop transparent, cava |

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

## Bureau Linux (⌘⇧ Espace)

Un second bureau, sans rien de macOS, partagé seulement par les apps.
**⌘⇧ Espace** ouvre le **sélecteur de bureaux** : des cartes d'aperçu (fond du
thème + maquette du style) pour le Mac, l'**Omarchy d'origine** et chaque style
Linux (←/→/↑/↓ ou 1–0, Entrée). Les styles qui ne diffèrent que par la couleur
sont réunis : leurs **teintes** sont des pastilles sous la carte (touche **T**),
et **⌃⌘T** passe à la teinte suivante. En ligne de commande :
`liquid-glass profile <style>[:<teinte>]`, `liquid-glass profile tone [nom]`,
`liquid-glass profile omarchy`.

| Style | Allure | Teintes |
|---|---|---|
| **blanc** (défaut) | Barre de texte en bas façon dwm, bords durs, ombres décalées, fiche système, grande heure | pur, crème |
| **sombre** | Mur de tuiles : pochette, paroles, système, labyrinthe, signal, blobs, anneau, spectre, mot chanté géant | encre, ambre, glace, sang, indigo |
| **jouet** | Pas de barre en haut : gros dock en bas, bureaux en blocs de couleur, autocollants penchés, ombres dures | bonbon, menthe, pêche |
| **violet** | Montagnes dans la brume, grosse horloge « bonbon » empilée, anneau de batterie ondulé | nuit, aube, rose |
| **expressive** | Material 3 Expressive façon [end4-pC](https://github.com/pctrade/end4-pC) / [Serpantinum](https://github.com/ilyamiro/serpantinum), couleurs **Material You** tirées du fond (matugen) | 5 palettes matugen |
| **windows** | Clone de Windows 11 : barre des tâches centrée, menu Démarrer (épinglés, toutes les applis, recommandés), paramètres rapides, calendrier, widgets, vue des tâches, fenêtre **Paramètres** complète (Informations, Personnalisation…) | clair, sombre |
| **mono** | Façon caelestia : cadre noir arrondi autour de l'écran, barre latérale, tableau de bord (météo, calendrier, média, performances), session au bord droit, fonds en trame | noir, papier, sakura |
| **foret** | Rice « c01 » : puces flottantes, horloge à secondes, météo heure par heure en orbite, spectre musical à curseurs, volets batterie et réseau | mousse, cendre |
| **ruban** | Bandes en biais, date géante, batterie qui ondule, lanceur oblique qui glisse | bleu, rouge, or |
| **espace** | Barre fine, paroles qui défilent au centre, horloge à planètes, grille d'activité, tableau de bord central | bleu, mars, nébuleuse |
| **gouts** | « Mes goûts » : horloge empilée, planètes, vinyle, mot chanté géant, aux couleurs du thème Omarchy choisi | tous les thèmes installés |
| **debian**, **fedora** | Bureau GNOME : barre noire, Activités, vue d'ensemble, grille d'applications, dash | — |
| **mint** | Bureau Cinnamon : panneau en bas, menu avec favoris et catégories | — |
| **kali** | Bureau Xfce : panneau en haut, menu des outils par catégorie (installation en un clic, `sudo` demandé dans le terminal) | — |
| **arch** | Bureau Plasma : panneau flottant, Kickoff | — |

Aucune interface d'Omarchy sur le bureau Linux : chaque style a son **lanceur**
(⌘Espace ; menu Démarrer en Windows), ses **réglages** (⌘⌥Espace ; Paramètres en
Windows) et son **alimentation** (⌘Échap). Le profil **Omarchy** remet au contraire
Omarchy exactement comme livré (sa barre, son thème, ses menus) ; seul ⌘⇧Espace y
ouvre le sélecteur pour revenir.

Chaque style a son thème Omarchy (terminaux, bordures, menus, fonds générés :
`scripts/gen-linux-themes.py`, `scripts/gen-linux-wallpapers.py`), sa peau (polices,
arrondis, bordures, ombres) et son jeu de widgets ; les widgets se déplacent à la
souris (élan + grille) et chaque style garde ses places.

**La musique partout** (Réglages → Bureau Linux → Musique, ou `[linux]`) :
- visualiseur cava en bas de l'écran : barres, vague, miroir, blocs pixel, ligne
  d'oscilloscope ou anneau radial ; hauteur, sensibilité, opacité, couleur (thème,
  pochette, arc-en-ciel, encre) ;
- paroles synchronisées : le **mot chanté en géant** au centre, la ligne entière,
  dans la carte du lecteur, ou rien ; position et taille ;
- halo qui respire sur les basses, horloges et lecteur qui **rebondissent** sur le beat ;
- lecteur vinyle : disque qui tourne, anneau cava autour, égaliseur ;
- petit égaliseur dans la barre.

**Écran de verrouillage Linux** : horloge « bonbon » empilée, date en pastille,
champ en carrés qui apparaissent à chaque touche, utilisateur et session, morceau
en cours, bascule clair/sombre (la nouvelle ambiance s'ouvre en cercle depuis le
bouton) et menu d'alimentation. Couleurs du style actif ; même flux PAM que l'écran
Mac. `[lock] linux_style = auto | on | off`.

**Terminal** : `liquid-glass-tty [eye|heart|donut|rain|clock|cava|cover]` — animations
ASCII qui suivent la musique (œil qui regarde et dont la pupille bat, cœur en relief,
tore, pluie, horloge pixel, visualiseur, pochette en demi-blocs couleur). Espace pour
la scène suivante. **⌃⌘ M** : menu des rices. Une page = un bureau de 1 à 13 terminaux (grille avec grande
case centrale à 13), une scène par terminal parmi 33 (trou noir, aquarium, lampe à lave,
feuilles, sakura, serpent, jeu de la vie, tuyaux, radar, minuteur…), temps entre deux
scènes, durée du minuteur, police et opacité. Chaque style a ses scènes et sa police ;
**⌃⌘⇧ M** lance la page suivante. Réglages : `~/.config/liquid-glass/rice.json`.

**Son des touches** : `liquid-glass keys on` — clavier mécanique « creamy » sur tout le
système (sons synthétisés : creamy, thocky, clicky ; ou un pack Mechvibes avec
`liquid-glass keys import <dossier>`). Une seule fois : `sudo usermod -aG input $USER`.

**⌃⌘ Espace** : carrousel de fonds en cartes inclinées (←/→, molette, Tab pour les
catégories, Entrée pour appliquer).

Polices (téléchargées par `install.sh` dans `~/.local/share/fonts`) : Material
Symbols Rounded, Google Sans Flex, Rubik, Silkscreen, Pixelify Sans, Syncopate, Unbounded.

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
