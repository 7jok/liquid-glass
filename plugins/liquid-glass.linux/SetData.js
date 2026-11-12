.pragma library
.import "T.js" as T

// Réglages propres à chaque thème Linux, partagés par les réglages de chaque
// thème (Set*.qml) et par la page « Bureau Linux » des Réglages du Mac.
// Une ligne : [type, clé, libellé, sous-titre, défaut, extra]
//   t interrupteur · s curseur (extra = [de, à, pas, format]) · c choix (extra = [[valeur, nom]…])
//   f police (comme c, en puces) · b bouton (extra = texte, puis la commande en 7e case)
// Les clés sont celles de linux.<clé> dans ~/.config/liquid-glass/config.json.

var names = { blanc: "Blanc", sombre: "Sombre", jouet: "Jouet", violet: "Violet", expressive: "Expressive", windows: "Windows",
              mono: "Mono", foret: "Forêt", ruban: "Rubans", espace: "Espace", cosmos: "Cosmos", ile: "Île", hud: "7JOKS",
              infini: "Infini", gouts: "Mes goûts", debian: "Debian", fedora: "Fedora", mint: "Mint", kali: "Kali", arch: "Arch" }
function name(st) { return T.t(names[st] || st) }

function position(st, def, label) {
  return [["c", st + "_position", label || T.t("Position de la barre"), "", def, [["top", T.t("En haut")], ["bottom", T.t("En bas")]]]]
}
function cards(st, l) {
  return l.map(function(c) { return ["t", st + "_card_" + c[0], T.t("Carte : ") + c[1], "", true] })
}
// Barre en îlots commune à Sombre, Violet, Expressive et Mes goûts : chacun garde ses choix.
function exBar(st, op) {
  return [["t", st + "_bar_title", T.t("Fenêtre active"), T.t("Nom de l'app et titre, à gauche de la barre"), true],
          ["t", st + "_bar_res", T.t("Jauges système"), st === "sombre" ? T.t("Quand le mur Sombre est coupé") : T.t("Processeur, mémoire, température"), true],
          ["t", st + "_bar_track", T.t("Morceau dans la barre"), "", true],
          ["t", st + "_bar_weather", T.t("Météo dans la barre"), "", true],
          ["t", st + "_bar_seconds", T.t("Secondes"), "", false],
          ["t", st + "_bar_tools", T.t("Capture et enregistrement"), T.t("Boutons à droite de la barre"), true],
          ["t", st + "_bar_claude", T.t("Bouton Claude"), "", true],
          ["s", st + "_bar_opacity", T.t("Opacité de la barre"), "", op, [0.4, 1, 0.01, "op"]],
          ["c", st + "_bar_size", T.t("Taille de la barre"), "", "normal", [["compact", T.t("Compacte")], ["normal", T.t("Normale")], ["grand", T.t("Grande")]]],
          ["c", st + "_bar_shape", T.t("Forme de la barre"), "", "float", [["float", T.t("Îlot flottant")], ["edge", T.t("Collée au bord")]]]].concat(position(st, "top"))
}
// Panneau des distributions.
function distro(st) {
  return [["t", st + "_seconds", T.t("Secondes"), "", false],
          ["t", st + "_date", T.t("Date à côté de l'heure"), "", true],
          ["t", st + "_tray", T.t("Icônes des applications"), T.t("Zone de notification, dans le panneau"), true],
          ["t", st + "_claude", T.t("Bouton Claude"), "", true],
          ["s", st + "_panel_h", T.t("Hauteur du panneau"), "", ({ debian: 30, fedora: 30, mint: 40, kali: 30, arch: 44 })[st] || 30, [22, 64, 1, "px"]]].concat(
          position(st, ({ mint: "bottom", arch: "bottom" })[st] || "top", T.t("Position du panneau")))
}

var fontChoices = [["", T.t("D'origine")], ["Inter", "Inter"], ["Google Sans Flex", "Google Sans"], ["Rubik", "Rubik"],
  ["Noto Sans", "Noto Sans"], ["Adwaita Sans", "Adwaita"], ["JetBrainsMono Nerd Font", "JetBrains Mono"], ["IBM Plex Mono", "IBM Plex Mono"],
  ["Fira Code", "Fira Code"], ["Share Tech Mono", "Share Tech"], ["Pixelify Sans", "Pixelify"], ["VT323", "VT323"]]
var displayChoices = [["", T.t("D'origine")], ["Bebas Neue", "Bebas Neue"], ["Unbounded", "Unbounded"], ["Syncopate", "Syncopate"],
  ["Michroma", "Michroma"], ["Rubik", "Rubik"], ["Google Sans Flex", "Google Sans"], ["Silkscreen", "Silkscreen"],
  ["Press Start 2P", "Press Start"], ["VT323", "VT323"], ["JetBrainsMono Nerd Font", "JetBrains Mono"]]
var cardSkins = { jouet: [3, "hard"], violet: [0, "soft"], expressive: [0, "soft"], gouts: [0, "soft"],
                  espace: [1, "soft"], foret: [1, "soft"], ruban: [2, "hard"] }

// Allure, pour tous les styles : polices, et pour ceux qui ont des cartes, bordure et ombre.
function allure(st) {
  var r = [["f", st + "_font", T.t("Police"), T.t("Barre, menus et widgets du style"), "", fontChoices],
           ["f", st + "_display", T.t("Grands chiffres"), T.t("Horloges et titres"), "", displayChoices]]
  var c = cardSkins[st]
  if (c) r = r.concat([["c", st + "_border", T.t("Bordure des cartes"), "", String(c[0]), [["0", T.t("Aucune")], ["1", T.t("Fine")], ["2", T.t("Moyenne")], ["3", T.t("Épaisse")]]],
                       ["c", st + "_shadow", T.t("Ombre des cartes"), "", c[1], [["none", T.t("Aucune")], ["soft", T.t("Douce")], ["hard", T.t("Dure")]]]])
  return r
}

function own(st) {
  switch (st) {
  case "infini": return [["t", "infini_clock", T.t("Horloge sur la toile"), T.t("Heures sur minutes, au centre de la toile"), true],
           ["t", "infini_frame", T.t("Cadre du visualiseur"), T.t("Posé sur la toile, il suit le glisser et le zoom"), true],
           ["t", "infini_viz", T.t("Visualiseur du bas"), T.t("Sur toute la largeur, sous la barre"), true],
           ["s", "infini_zoom_speed", T.t("Vitesse du zoom"), "", 1.08, [1.02, 1.25, 0.01, "pct"]],
           ["t", "infini_dblclick", T.t("Double-clic : retour au centre"), T.t("Et zoom à 100 %"), true],
           ["t", "infini_pos", T.t("Position dans la barre"), T.t("Coordonnées et zoom, clic pour revenir"), true]].concat(position("infini", "bottom"))
  case "windows": return [["c", "windows_align", T.t("Alignement de la barre des tâches"), "", "center", [["center", T.t("Centre")], ["left", T.t("Gauche")]]],
           ["t", "windows_weather", T.t("Météo dans la barre"), T.t("À gauche (pas avec l'alignement à gauche)"), true],
           ["t", "windows_search", T.t("Rechercher"), T.t("La pilule de recherche à côté de Démarrer"), true],
           ["t", "windows_taskview", T.t("Vue des tâches"), "", true],
           ["t", "windows_icons", T.t("Icônes du bureau"), T.t("Ce PC, Corbeille, Documents…"), true],
           ["c", "windows_size", T.t("Taille de la barre des tâches"), "", "normale", [["petite", T.t("Petite")], ["normale", T.t("Normale")], ["grande", T.t("Grande")]]]]
  case "hud": return [["t", "hud_globe", T.t("Globe"), T.t("Vue du monde en fil de fer, à droite"), true],
           ["t", "hud_files", T.t("Dossiers"), T.t("En bas à gauche"), true],
           ["t", "hud_keyboard", T.t("Clavier"), T.t("En bas à droite, les touches s'allument"), true]]
  case "cosmos": return [["s", "cosmos_speed", T.t("Vitesse du système solaire"), "", 1, [0.25, 3, 0.05, "x"]],
           ["t", "cosmos_drift", T.t("Caméra automatique"), T.t("Repart seule après une minute sans action"), true],
           ["t", "cosmos_notifs", T.t("Satellites de notifications"), "", true],
           ["t", "cosmos_weather", T.t("Satellites météo"), T.t("Prévision des prochaines heures autour de la Terre"), true]].concat(position("cosmos", "top"))
  case "ile": return [["t", "ile_dock", T.t("Dock"), "", true],
           ["t", "ile_dock_autohide", T.t("Masquer le dock"), T.t("Il apparaît quand la souris touche le bas"), true],
           ["t", "ile_snap", T.t("Aimanter à la grille"), T.t("En déplaçant l'horloge et la carte musique"), true],
           ["t", "ile_weather", T.t("Météo dans l'encoche"), "", true]]
  case "mono": return [["t", "mono_title", T.t("Titre de la fenêtre"), T.t("À la verticale dans la barre"), true],
           ["t", "mono_edge", T.t("Tableau de bord par le haut"), T.t("La souris posée au milieu du bord haut l'ouvre"), true],
           ["t", "mono_unlock", T.t("Cadenas au déverrouillage"), "", true],
           ["s", "mono_frame", T.t("Épaisseur du cadre"), T.t("Le bord noir autour des fenêtres"), 8, [0, 28, 1, "px"]],
           ["s", "mono_corner", T.t("Arrondi du cadre"), "", 18, [0, 48, 1, "px"]]]
  case "blanc": return [["t", "blanc_fetch", T.t("Fiche système"), "", true], ["t", "blanc_track", T.t("Morceau en cours"), "", true],
           ["t", "blanc_clock", T.t("Grande heure"), "", true],
           ["t", "blanc_bar_title", T.t("Titre de la fenêtre dans la barre"), "", true],
           ["t", "blanc_bar_track", T.t("Morceau dans la barre"), "", true],
           ["t", "blanc_bar_res", T.t("cpu / ram dans la barre"), T.t("Un clic ouvre btop"), true],
           ["t", "blanc_bar_tray", T.t("Icônes des applications"), T.t("Zone de notification, dans la barre"), true],
           ["t", "blanc_bar_seconds", T.t("Secondes"), "", false],
           ["t", "blanc_bar_upper", T.t("Barre en capitales"), T.t("COMME UN VIEUX TERMINAL"), false]].concat(position("blanc", "bottom"))
  case "sombre": return [["t", "sombre_anim", T.t("Tuiles animées"), T.t("Spectre, blobs et anneau suivent la musique (coupé : moins de processeur)"), true],
           ["t", "sombre_word", T.t("Paroles en géant"), T.t("Sinon l'heure dans la grande tuile"), true],
           ["s", "sombre_tile_alpha", T.t("Opacité des tuiles"), T.t("Le fond d'écran passe à travers"), 0.72, [0.2, 1, 0.01, "op"]],
           ["t", "sombre_glow", T.t("Liseré lumineux"), T.t("En haut de chaque tuile"), true],
           ["s", "sombre_gap", T.t("Espace entre les tuiles"), "", 10, [0, 30, 1, "px"]]].concat(exBar("sombre", 0.97))
  case "violet": return [["t", "violet_card_moon", T.t("Phase de la Lune"), T.t("Carte en bas à gauche"), true],
           ["t", "violet_card_quote", T.t("Citation"), T.t("Carte en bas à droite"), true]].concat(exBar("violet", 0.82))
  case "expressive": return [["t", "expressive_spin", T.t("Horloge cookie qui tourne"), T.t("Les festons avancent d'un cran par minute"), false],
           ["s", "expressive_lobes", T.t("Festons de l'horloge"), T.t("Du trèfle à la fleur"), 10, [4, 16, 1, "n"]]].concat(exBar("expressive", 0.94))
  case "jouet": return [["t", "jouet_magnify", T.t("Grossir au survol"), T.t("Les autocollants du dock rebondissent sous la souris"), true],
           ["t", "jouet_tilt", T.t("Autocollants penchés"), T.t("Sinon tout est bien droit"), true],
           ["t", "jouet_rainbow", T.t("Bureaux arc-en-ciel"), T.t("Sinon la couleur du thème"), true],
           ["t", "jouet_cover", T.t("Pochette dans le dock"), "", true],
           ["t", "jouet_spin", T.t("Pochette qui tourne"), T.t("Pendant la lecture, comme un disque"), true],
           ["t", "jouet_seconds", T.t("Secondes"), "", false],
           ["t", "jouet_tray", T.t("Icônes des applications"), T.t("Zone de notification, dans le dock"), true],
           ["t", "jouet_battery", T.t("Batterie"), "", true],
           ["t", "jouet_claude", T.t("Bouton Claude"), "", true],
           ["c", "jouet_size", T.t("Taille du dock"), "", "normal", [["petit", T.t("Petit")], ["normal", T.t("Normal")], ["grand", T.t("Grand")]]]].concat(
           position("jouet", "bottom", T.t("Position du dock")))
  case "gouts": return [["b", "", T.t("Thème Omarchy"), T.t("Mes goûts reprend un thème Omarchy installé"), "", T.t("Suivant  ⌃⌘T"), ["liquid-glass", "profile", "tone"]],
           ["t", "gouts_planets", T.t("Horloge à planètes"), T.t("En bas à droite du bureau"), true]].concat(exBar("gouts", 0.94))
  case "debian": return [["t", "debian_label", T.t("Mot « Activités »"), T.t("À côté du logo, comme GNOME"), true]].concat(distro("debian"))
  case "fedora": return [["t", "fedora_pills", T.t("Points des bureaux"), T.t("À côté du logo, comme GNOME récent"), true]].concat(distro("fedora"))
  case "mint": return [["t", "mint_label", T.t("Mot « Menu »"), "", true], ["t", "mint_launchers", T.t("Lanceurs du panneau"), "", true],
           ["t", "mint_tasks", T.t("Liste des fenêtres"), "", true]].concat(distro("mint"))
  case "kali": return [["t", "kali_launchers", T.t("Lanceurs du panneau"), "", true], ["t", "kali_workspaces", T.t("Bureaux dans le panneau"), T.t("Petits rectangles, comme Xfce"), true],
           ["t", "kali_tasks", T.t("Liste des fenêtres"), "", true]].concat(distro("kali"))
  case "arch": return [["t", "arch_launchers", T.t("Tâches épinglées"), "", true], ["t", "arch_tasks", T.t("Liste des fenêtres"), "", true]].concat(distro("arch"))
  case "espace": return [["t", "espace_lyrics", T.t("Paroles dans le ciel"), "", true], ["t", "espace_planets", T.t("Horloge à planètes"), "", true],
           ["t", "espace_activity", T.t("Activité du processeur"), T.t("Une case par minute, en haut à droite"), true]].concat(position("espace", "top"),
           cards("espace", [["weather", T.t("Météo")], ["moon", T.t("Phase de la Lune")], ["calendar", T.t("Calendrier")], ["gauges", T.t("Jauges système")]]))
  case "foret": return [["t", "foret_seconds", T.t("Secondes"), "", true], ["t", "foret_weather", T.t("Météo dans la barre"), "", true],
           ["t", "foret_media", T.t("Morceau dans la barre"), T.t("Pochette, temps et commandes"), true]].concat(position("foret", "top"),
           cards("foret", [["clock", T.t("Horloge")], ["weather", T.t("Météo")], ["calendar", T.t("Calendrier")], ["todo", T.t("À faire")], ["music", T.t("Lecteur")]]))
  case "ruban": return [["t", "ruban_date", T.t("Date en filigrane"), "", true], ["t", "ruban_music", T.t("Bande musique"), "", true],
           ["t", "ruban_weather", T.t("Bande météo"), "", true], ["t", "ruban_battery", T.t("Bloc batterie"), "", true]].concat(
           cards("ruban", [["calendar", T.t("Calendrier")], ["gauges", T.t("Jauges système")], ["quote", T.t("Citation")]]))
  }
  return []
}

// Ce que montre la page « Propre à <style> ».
function rows(st) { return own(st).concat(allure(st)) }

// Pages des réglages de chaque thème : [id, nom, icône Material Symbols].
function pages(st) {
  return [["home", T.t("Accueil"), "home"], ["style", name(st), "palette"], ["look", T.t("Apparence"), "wallpaper"],
          ["net", T.t("Réseau"), "wifi"], ["bt", "Bluetooth", "bluetooth"], ["sound", T.t("Son"), "volume_up"],
          ["screen", T.t("Écran"), "light_mode"], ["power", T.t("Énergie"), "battery_full"], ["system", T.t("Système"), "memory"]]
}

// Lignes de chaque page. Types en plus de ceux du haut (état du système, listes) :
//   h titre · T interrupteur système (wifi bt night dnd mute micmute) · S curseur système (vol mic bright)
//   tone teinte du style · colors couleurs · walls fonds · styles bureaux · wifi réseaux · btdev appareils
//   sinks sorties son · battery batterie · profile mode d'énergie · power éteindre… · info fiche · acts raccourcis
function pageRows(st, page) {
  switch (page) {
  case "home": return [["T", "wifi", "Wi-Fi"], ["T", "bt", "Bluetooth"], ["T", "night", T.t("Lumière de nuit")], ["T", "dnd", T.t("Ne pas déranger")],
                       ["S", "vol", T.t("Volume")], ["S", "bright", T.t("Luminosité")], ["tone", "", T.t("Teinte")], ["acts", "", T.t("Raccourcis")], ["power", "", T.t("Session")]]
  case "style": return [["h", "", T.t("Propre à ") + name(st)]].concat(own(st), [["h", "", T.t("Allure")]], allure(st))
  case "look": return [["h", "", T.t("Couleurs")], ["tone", "", T.t("Teinte")], ["colors", "", T.t("Couleurs")],
                       ["h", "", T.t("Fond d'écran")], ["walls", "", T.t("Fond d'écran")],
                       ["c", "live_wall", T.t("Fond vivant"), T.t("Anime l'image du fond, s'arrête dès qu'une fenêtre est ouverte"), "off",
                        [["off", T.t("Non")], ["respire", T.t("Respire")], ["vague", T.t("Vague")], ["tourbillon", T.t("Tourbillon")]]],
                       ["h", "", T.t("Bureau")],
                       ["t", "widgets", T.t("Widgets"), T.t("Horloge, météo, musique… sur le bureau"), true],
                       ["t", "lyrics", T.t("Paroles"), T.t("Ligne chantée du morceau en cours"), true],
                       ["t", "cava", T.t("Visualiseur"), T.t("Barres qui suivent la musique"), true],
                       ["s", "radius", T.t("Arrondi des fenêtres"), "", 12, [0, 30, 1, "px"]],
                       ["h", "", T.t("Bureaux")], ["styles", "", T.t("Bureaux")]]
  case "net": return [["T", "wifi", "Wi-Fi", T.t("Réseau sans fil")], ["wifi", "", T.t("Réseaux")],
                      ["b", "", T.t("Plus de réglages"), T.t("Mots de passe, réseaux cachés"), "", T.t("Ouvrir"), ["omarchy-launch-floating-terminal-with-presentation", "nmtui"]]]
  case "bt": return [["T", "bt", "Bluetooth", T.t("Casques, souris, claviers")], ["btdev", "", T.t("Appareils")],
                     ["b", "", T.t("Associer un appareil"), "", "", T.t("Ouvrir"), ["omarchy-launch-floating-terminal-with-presentation", "bluetoothctl"]]]
  case "sound": return [["S", "vol", T.t("Volume")], ["T", "mute", T.t("Muet")], ["S", "mic", T.t("Micro")], ["T", "micmute", T.t("Micro coupé")],
                        ["sinks", "", T.t("Sortie")]]
  case "screen": return [["S", "bright", T.t("Luminosité")], ["T", "night", T.t("Lumière de nuit"), T.t("Écran plus chaud le soir")],
                         ["b", "", T.t("Écrans"), T.t("Résolution, échelle, disposition"), "", T.t("Ouvrir"), ["sh", "-c", "omarchy-launch-editor \"$HOME/.config/hypr/monitors.conf\""]]]
  case "power": return [["battery", "", T.t("Batterie")], ["profile", "", T.t("Mode d'énergie")], ["h", "", T.t("Session")], ["power", "", T.t("Session")]]
  case "system": return [["info", "", T.t("Cet ordinateur")], ["T", "dnd", T.t("Ne pas déranger"), T.t("Notifications en silence")],
                         ["b", "", T.t("Mises à jour"), T.t("Omarchy et les paquets"), "", T.t("Lancer"), ["omarchy-launch-floating-terminal-with-presentation", "omarchy-update"]],
                         ["b", "", T.t("Raccourcis clavier"), "⌘K", "", T.t("Voir"), ["omarchy-shell", "liquid-glass.linux", "keys"]],
                         ["b", "", T.t("Fonds animés"), T.t("Minecraft et pixel art, environ 200 vidéos"), "", T.t("Télécharger"),
                          ["sh", "-c", "cd \"$(dirname \"$(readlink -f \"$(command -v liquid-glass)\")\")/..\" && setsid nohup scripts/fetch-live-wallpapers.py >\"$HOME/.cache/liquid-glass/live.log\" 2>&1 &"]]]
  }
  return []
}
