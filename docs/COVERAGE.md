# Couverture du « Third Prompt Claude Mac OS »

Audit du 2026-11-06, mis à jour à chaque phase.
✅ fait · 🟡 partiel · ❌ absent · 🚫 impossible tel quel sous Linux/Wayland (alternative indiquée)

| § | Fonctionnalité | État | Où / remarque |
|---|---|---|---|
| 1 | Verre (flou, liseré, ombres, clair/sombre, styles clear/standard/tinted) | ✅ | Hyprland + thèmes générés |
| 1 | Réfraction / lentille, reflet spéculaire mobile | ❌ | trop coûteux sur UHD 620 → à tester en option |
| 1 | Couleur d'accent au choix, icônes MacTahoe, curseurs | 🟡 | accent fixe bleu / Spotify ; pas de sélecteur d'accent |
| 2 | Barre : logo + menu Pomme complet, menus de l'app, extras, horloge | ✅ | logo (À propos, Réglages, App Store, Forcer à quitter, Suspendre…), menubar, clock |
| 2 | Menus globaux de l'app (Fichier, Édition…) | 🟡 | pas d'export de menus sous Wayland → `liquid-glass.menubar` : Fichier/Édition/Présentation/Fenêtre/Aide génériques qui envoient ⌘N, ⌘S, ⌘Z… à l'app active (`liquid-glass key`) |
| 2 | Hauteur 24 pt, extras réordonnables, Live Activities | ✅ | barre 24 pt ; Live Activities via l'île |
| 3 | Dock : verre, grossissement gaussien, points, autohide, Corbeille, réduction, pastilles, pile Téléchargements | ✅ | dock : pastilles rouges = notifications non lues par app (remises à zéro au focus) ; pile Téléchargements en éventail à gauche de la Corbeille (clic droit = ouvrir le dossier) |
| 3 | Menu contextuel Mac (fenêtres ouvertes, Options ▸ Garder / Ouvrir à la connexion / Afficher dans le Finder, Afficher toutes les fenêtres, Masquer, Quitter ; ⌥ → Forcer à quitter), clignotement du choix | ✅ | dock ; ⌥ lu via `$XDG_RUNTIME_DIR/liquid-glass-alt` (liaisons Hyprland transparentes) ; `liquid-glass login-item` (XDG autostart) |
| 3 | Aperçus en direct au survol des icônes (DockDoor) : clic = premier plan, × = fermer | ✅ | dock (screencopy, 650 ms de survol) |
| 3 | Barre de progression, apps récentes, pouf | ❌ | |
| 4 | Feux tricolores sur les fenêtres | ✅ | Plugin hyprbars chargé par `hypr/liquid-glass.lua` : barre de 28 px en verre + rouge/jaune/vert (fermer, réduire via `liquid-glass window minimize`, agrandir) sur **toutes** les fenêtres, présentes et futures (Chrome, Spotify, terminal…). Les fenêtres flottent façon Mac (`windows.floating`) car hyprbars ne dessine que sur les fenêtres flottantes ; désactivable dans Réglages → Bureau et Dock → Fenêtres |
| 4 | Mission Control, coins actifs, afficher le bureau | ✅ | mission, hotcorners, `liquid-glass show-desktop` |
| 4 | Mosaïque Sequoia (moitiés, remplir, centrer), masquer ⌘H / ⌥⌘H | ✅ | ⌃⌥ ← → ↑ ↓ F C, menu Fenêtre, `liquid-glass window` |
| 4 | App Exposé (⌘↓, 4 doigts ↓) : fenêtres de l'app sur tous les bureaux + documents récents | ✅ | mission (payload `{"app":…}`) |
| 4 | Menu du bouton vert : Plein écran, Agrandir, moitiés et quarts en mini-écrans, Remplir, Centrer, Toujours au-dessus, bureau suivant, Réduire | ✅ | `liquid-glass.tilemenu` + `liquid-glass tile-menu` ; clic (hyprbars ne gère pas le survol) ; Réglages → Bureau et Dock → Bouton vert |
| 4 | Stage Manager | ❌ | |
| 5 | Spotlight (5 modes, calcul, unités, presse-papiers, `>` commande, web) | ✅ | spotlight |
| 5 | Devises, fuseaux, dictionnaire, quick keys, aperçu Quick Look | ❌ | |
| 6 | Grille d'apps (Launchpad) | 🟡 | AppGrid du dock ; pas de dossiers ni mode jiggle |
| 7 | ⌘⇥ sélecteur, Q pour quitter | ✅ | switcher |
| 7 | Forcer à quitter (⌥⌘Échap) façon Mac | ✅ | forcequit (liste par app, confirmation) |
| 8 | Control Center en capsules (Focus, Wi-Fi, BT, son, écran, musique, boutons) | ✅ | control |
| 8 | Disposition de la vidéo : Concentration, Wi-Fi, Arrêter / Lecture en cours, Mode Jeu ; curseurs fins ; sortie en cascade | ✅ | control (pastilles au choix : Réglages → Centre de contrôle) ; `liquid-glass gamemode` |
| 8 | Mode édition Tahoe (glisser-déposer) | 🟡 | choix des pastilles et des boutons dans Réglages |
| 9 | Notifications façon Mac (bannières 344 pt, groupées, centre) | 🟡 | notifications Omarchy thémées ; largeur 380 codée en dur dans /usr/share (cloner le service casserait aux mises à jour) |
| 10 | Widgets horloge, calendrier, météo, batterie, musique | ✅ | widgets |
| 10 | Tailles S/M/L/XL, galerie, estompage derrière fenêtres, horloge mondiale… | 🟡 | Tailles S/M/L/XL (appui long → pastille S·M·L·XL, ou Réglages → Bureau et Dock) ; pas de galerie ni d'horloge mondiale |
| 11 | Verrouillage Tahoe (date, heure, musique, avatar, notifs, empreinte) | ✅ | lock |
| 11 | Secousse du mot de passe | ✅ | lock |
| 11 | Horloge : 5 styles (Verre, Classique, Serif, Liquide, Fine), graisse, luminosité, teinte, chiffres hauts, format de date ; position de « Lecture en cours » | ✅ | lock + Réglages → Écran verrouillé |
| 11 | Boutons Veille/Redémarrer/Éteindre, économiseurs | ❌ | Veille/Redémarrer/Éteindre dans le menu Pomme |
| 11 | Dernier morceau Spotify gardé sur l'écran verrouillé, ▶ le relance (Spotify démarre en arrière-plan) ; champ mot de passe façon macOS 132×22 tout en bas, avatar 40 ; clic sur la pochette = agrandie au-dessus de la carte (en dessous si l'horloge la cache), carte toujours déplaçable | ✅ | lock + `liquid-glass resume-music` ; Réglages → Écran verrouillé → Garder le dernier morceau |
| 12 | Fonds Mac, rotation | 🟡 | fonds dynamiques selon l'heure ❌ |
| 13 | Finder | 🟡 | Nautilus + sushi (Quick Look) installés, pas thémés « Mac » |
| 14 | Captures ⌘⇧3/4/5, vignette flottante | ✅ | omasnap sans --notify : vignette 7 s en bas à droite (épingler, Modifier) |
| 14 | OCR (Texte en direct) | 🟡 | `omarchy capture text` |
| 15 | Raccourcis macOS + aide-mémoire ⌘K | ✅ | cheatsheet, liquid-glass-bindings.lua |
| 15 | Appui long = accents | ❌ | |
| 16 | Gestes 4 doigts Mission Control | 🟡 | 3 doigts bureaux = Omarchy |
| 17 | Réglages Tahoe (≈ 15 pages), « À propos de ce Mac » | ✅ | settings aux mesures (715 pt, barre latérale 215), about |
| 18 | Moniteur d'activité, calculatrice, etc. | 🟡 | apps Linux existantes |
| 19 | Coins d'écran arrondis, fausse encoche | ✅ | corners (Réglages → Écrans), encoche = île au repos « Encoche » |
| 20 | Fichier de tokens, tailles exactes | ✅ | `shared/Mac.js` → `scripts/push-tokens.sh` ; Spotlight 680 × 52, menus 22, barre 24, Réglages 715 |
| 21 | Île dynamique (Alcove) | ✅ | island : musique + égaliseur, secteur, Bluetooth, Concentration, volume ; molette, balayage |
| 21 | Sons de clavier (Klack) | ❌ | demande l'accès au groupe `input` : à valider par l'utilisateur |
| 21 | Raycast, Ice, Stats, Loop, CleanShot, Paste, PopClip… | ❌ | |
| 21 | StandBy | ✅ | plugin `liquid-glass.standby` (⌘⌥B ou Spotlight) : horloge 3 styles (← →), panneaux musique / calendrier / batterie (↑ ↓, molette), rouge la nuit |

## Fait cette session
Tokens + barre 24 pt · menus de l'app · menu Pomme · À propos de ce Mac · Forcer à quitter ·
mosaïque ⌃⌥ · île dynamique · coins arrondis · vignette de capture · Réglages aux mesures Mac.

Vidéo « macshell » (2ᵉ passage) : Spotlight à bulles séparées, Centre de contrôle de la vidéo + Mode Jeu,
options d'horloge du verrouillage, horloge de la barre (24 h, date, secondes), semaine du lundi, Souris /
Trackpad, moniteurs dans Écrans, fenêtre Réglages déplaçable, widgets qui arrivent du bord après le
déverrouillage, horloge du widget nette (texte vectoriel), morceau fantôme effacé quand aucun lecteur ne joue.

## Reste
Galerie de widgets · horloge mondiale · accents par appui long (impossible sans injecter des touches,
donc sans wtype) · Visual Intelligence (⌘⇧Espace reste le sélecteur de profil).

## Ajouts récents

- **Fond d'écran pochette** : quand Spotify joue, la pochette floutée devient le fond d'écran (`spotify.wallpaper = "cover"`), le widget musique se place sous la pochette, les paroles s'affichent sur le bureau si « Paroles » est activé dans le Centre de contrôle.
- **Mode édition des widgets** : appui long (0,55 s) → les widgets tremblent avec un « − » ; clic = suppression, « Terminé » ou 12 s d'inactivité pour sortir. IPC : `omarchy-shell liquid-glass.widgets edit|done`.
- **Écran verrouillé** : notifications compactes (252 px, 4 max), champ mot de passe 186×28 coins 8, avatar en bulle de verre 46 px — proportions de la vidéo.
- **Horloge widget** : chiffres vectoriels (nets en 1,5×).
- **Dock** : pastilles rouges de notifications non lues (par app, effacées quand l'app reprend le focus) et pile Téléchargements en éventail.
- **Widgets S/M/L/XL** : en mode édition, pastille S · M · L · XL sous chaque widget ; calendrier moyen = grand jour à gauche + mois, batterie moyenne = anneau + texte côte à côte.
- **Centre de contrôle modifiable sur place** : « Modifier les commandes… » → les commandes tremblent ; clic sur une pastille = la changer (↻), « − » retire un bouton rond, glisser le réordonne, rangée « Ajouter des commandes » ; clic droit = réglages détaillés.
- **En veille (StandBy)** : ⌘⌥B ou Spotlight « En veille ».
- **Fonds d'écran animés** : `liquid-glass animated-wallpapers` (ou `./install.sh --animated`) génère des vidéos en boucle parfaite (panoramique elliptique + respiration de teinte) dans les thèmes ; choix dans Réglages → Fond d'écran (pastille « Animé ») ou double-clic sur le bureau. Les .mp4 ne sont pas versionnés.
- **Réglages propres à chaque thème** (⌘Échap, ⌘⌥Espace, boutons des barres) : plus de fenêtre façon Mac ni de centre de contrôle générique sur Linux. Un moteur commun (`SetData.js` pour le contenu, `SetCore.qml` pour l'état et les actions système, `SetRow.qml`/`SetList.qml` pour le rendu selon un « habillage ») et une mise en page par thème : Ruban (bandeau penché, onglets en rubans), Blanc (feuille de terminal, tags dwm), Sombre (mur de tuiles kanji), Jouet (boîte à bonbons, autocollants), Violet (disque, lunes en arc), Expressive (tiroir M3), Goûts (palette de commandes), Mono (panneau sorti du cadre), Forêt (cartes flottantes, feuilles), Espace (planète et lunes), Cosmos (console de bord, stations), Île (l'encoche s'ouvre), 7JOKS (terminal F1…F9), Infini (cartes sur la toile), Debian/Fedora (Paramètres GNOME, barre latérale ou sélecteur de vues), Mint (grille Cinnamon), Kali (gestionnaire Xfce, classeur), Arch (Configuration du système KDE). Pages : accueil, style, apparence, réseau, Bluetooth, son, écran, énergie, système. Windows garde ses Paramètres façon Windows 11.
- **Fonds vivants Minecraft et pixel art** : `scripts/fetch-live-wallpapers.py [minecraft|pixel|link]` (aussi lancé par `./install.sh --animated`) télécharge ~200 vidéos 1080p (MoeWalls, MotionBGs, DesktopHut ; son retiré, doublons écartés par empreinte d'image ; `PIXEL=n` pour le nombre de pixel art) dans `~/.local/share/liquid-glass/live/`, avec un lien dans `~/.config/omarchy/backgrounds/<thème>/` pour chaque thème. Choix : sélecteur d'Omarchy, carrousel ⌃⌘Espace (catégorie « Animés »), Réglages → Fond d'écran (« Dynamiques »).
- **Barre des menus épurée façon macOS** : batterie dessinée (pile horizontale, % en option), Wi-Fi, loupe Spotlight, icône Centre de contrôle dessinée (deux interrupteurs), horloge. Retirés par défaut : bureaux 1 2 3, agents, Bluetooth, son, morceau en cours — réactivables dans Réglages → Barre des menus → Éléments de la barre, ou `liquid-glass bar <élément> on|off`.
- **Paroles dans l'île dynamique** : l'île s'élargit et la ligne chantée y défile (plus de paroles dans la barre, rien ne déborde sur les fenêtres). Réglages → Barre des menus → Paroles.
- **Widget musique** : déplaçable aussi quand la pochette est le fond d'écran (place à part : music_cover_x/y, par défaut sous la pochette ou à côté en grand format) ; pochette et coins découpés sans masque (nets, plus de pochette étirée en L) ; la bulle met les paroles sur le fond d'écran (clic droit : sur la carte) ; « Pas de paroles pour ce titre » quand il n'y en a pas.
- **Widget musique taille unique (moyen)** : plus de pastille S/M/L ; clic sur la pochette → elle s'agrandit au-dessus de la carte avec un ressort (en dessous s'il n'y a pas la place), re-clic → elle retourne dans la carte. IPC : `omarchy-shell liquid-glass.widgets musicArt`.
- **Raccourcis d'apps dans la barre** (plugin `liquid-glass.shortcuts`, remplace l'ancien module `claude`) : Claude Code par défaut + n'importe quelle app. Réglages → Raccourcis d'apps : ajouter (recherche dans les apps installées), monter / descendre, retirer. Clic = ouvrir ou passer sur la fenêtre déjà ouverte ; clic droit = la page de réglages. Config : `shortcuts.apps`.
- **Spotlight, bulles de la vidéo** : icônes vectorielles au trait (`ModeIcon.qml`) — A, dossier, calques, presse-papiers, émoji. Le 5ᵉ mode est maintenant **Émojis** (grille 10 colonnes, Entrée insère dans l'app active, Ctrl+Entrée copie) ; les commandes musique restent dans Actions.
- **~200 fonds d'écran** : `liquid-glass wallpapers fetch` (wallhaven, SFW uniquement : anime, ASCII, minimal, abstrait, fruits), `liquid-glass wallpapers generate` (24 générés : vagues de papier et dégradés fluides, 12 palettes), `liquid-glass wallpapers list` (liens dans les deux thèmes + vignettes). Réglages → Fond d'écran : filtre par catégorie (Mac, Dynamiques, Anime, ASCII, Minimal, Abstrait, Fruits, Générés). Les fichiers vivent dans `~/.local/share/liquid-glass/wallpapers` (non versionnés).
- **Notifications** : seules les vraies notifications s'affichent ; s'il n'y en a pas, rien en haut à droite.

- **Pochette agrandie (bureau et écran verrouillé)** : elle sort de la carte vers le haut ; si elle y serait cachée (haut de l'écran, horloge du verrouillage, colonne de widgets, grande pochette du fond), elle passe en dessous.
- **Dock façon Tahoe** : fine plaque de verre très claire (plus de gros verre teinté), icônes serrées (marge 4), coins très arrondis ; séparateurs apps gardées | apps ouvertes non gardées | Téléchargements + Corbeille.
- **Barre des menus transparente** (Tahoe) : `liquid-glass bar background none|glassy|opaque` ou Réglages → Barre des menus → Fond de la barre ; texte sombre ou blanc selon la luminance du haut du fond affiché (`liquid-glass bar-contrast`, suivi par liquid-glass.appearance, pochette Spotify comprise).
- **Correctif** : `liquid-glass set` écrit config.toml sous verrou et de façon atomique (deux écritures simultanées avaient écrasé l'en-tête et cassé la config, donc les paroles).

- **Bureau « Linux » (⌘⇧Espace)** : un second bureau sans rien de macOS, d'après github.com/Teiguuu/dotfiles (rice lain). `liquid-glass profile mac|linux|toggle|status` ou Réglages → Bureau Linux. Chaque profil garde son `shell.json` (`~/.config/liquid-glass/profiles/`), son thème (`lain` : sombre, sarcelle, fonds Teiguuu récupérés au premier passage, non versionnés) et son réglage Hyprland (`hypr/liquid-glass-linux.lua` : tiling dwindle, espaces 5/8, bordure 2 px en dégradé, coins carrés, animations back_out, raccourcis Omarchy d'origine). Plugin `liquid-glass.linux` : barre façon waybar (luminosité, heure | date, réseau ; bureaux dans une pastille ; clavier, CPU, mémoire, température, batterie, notifications, alimentation), horloge pixel façon tty-clock, bande cava en bas (seulement pendant la lecture), carte de paroles sarcelle (dernier morceau + ▶ Reprendre quand Spotify est fermé). Le service Spotify n'y met ni pochette en fond ni couleurs dynamiques. Verrouillage et OSD restent ceux de Liquid Glass (échanger le plugin de verrouillage à chaud laisse deux gestionnaires IPC « lock » en concurrence).

## macOS 27 « Golden Gate »

- **Finder** (`apps/finder`, `liquid-glass finder [dossier]`, ⌘⌥Espace) : un seul processus Quickshell pour toutes les fenêtres, qui se ferme avec la dernière. Barre latérale bord à bord (Favoris, Emplacements avec éjection, Tags), barre d'outils uniforme, présentations Icônes / Liste / Colonnes / Galerie (⌘1-4), recherche, Coup d'œil (Espace), Lire les informations (⌘I), Aller au dossier (⌘⇧G), Corbeille (gio), alias, compresser, dupliquer, tags (`finder-tags.json`), barre du chemin et barre d'état. Menu « Aller » dans la barre des menus : `liquid-glass finder --go <dossier|recents|apps|goto>`.
- **Icônes et curseurs macOS** : MacTahoe (vinceliuice, GPL-3) copié par `scripts/install-mac-icons.sh` dans `~/.local/share/icons` (sans sudo).
- **Fonds officiels** : `scripts/fetch-mac-wallpapers.py`, de Cheetah à Golden Gate (6K réduits à 3840 px, non versionnés), catégorie « macOS » dans Réglages → Fond d'écran. **Bureau dynamique** : `liquid-glass dynamic-wallpaper tick|list`, selon l'heure (Golden Gate, plage de Tahoe, Big Sur, Mojave, Catalina) ou le mode clair / sombre.
- **Réglages** : curseur Liquid Glass (transparent → teinté), Accessibilité (zoom ⌥⌘8, taille du pointeur, réduire la transparence / les animations), Claude (à la place de Siri), Touch ID et mot de passe (fprintd), Langue et région (sources de saisie, ⌃Espace), Imprimantes et scanners (CUPS), Alcove (île dynamique) et Klack (sons du clavier, sans groupe `input`).
- **Spotlight « Rechercher ou demander »** : une question → réponse de Claude en direct dans une bulle, questions de suite (Entrée), ⇥ pour demander.
- **Île** : la source de saisie s'affiche quand elle change.
- **Raccourcis Mac** : ⌘Z/⇧⌘Z, ⌘N, ⌘R, ⌘B, ⌘U, ⌘D envoyés en Ctrl aux apps (rien dans les terminaux), ⌃Espace (clavier suivant), ⌃⌘Espace (émojis), ⌥⌘D (masquer le Dock), zoom ⌥⌘8 et ⌥⌘ + molette. Le menu Omarchy passe sur ⌃⌥⌘Espace.
- **Fenêtres** : ombre plus marquée sur la fenêtre active, comme macOS 27.
