import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Services.Mpris
import Quickshell.Services.UPower
import "T.js" as T

// Liquid Glass — profil « Linux » (⌘⇧Espace, `liquid-glass profile linux`).
//
// Un bureau tiling sans rien de macOS, en deux styles (config [linux] style) :
//  • « expressive » (défaut) : Material 3 Expressive d'après end4-pC
//    (github.com/pctrade/end4-pC, fork d'illogical-impulse) et Serpantinum
//    (github.com/ilyamiro/serpantinum) : couleurs Material You tirées du fond
//    par matugen, barre flottante en îlots, horloge « cookie », tuiles système,
//    météo, carte utilisateur, semaine, à faire, musique + paroles, cava, et un
//    carrousel de fonds en cartes inclinées (⌃⌘Espace).
//  • « lain » : le rice Teiguuu d'origine (barre waybar, horloge pixel, cava,
//    carte de paroles).
// Ce plugin n'est chargé que dans le shell.json du profil Linux.
Item {
  id: svc
  property var shell: null
  property var manifest: null

  readonly property string home: Quickshell.env("HOME")
  readonly property string user: Quickshell.env("USER") || "moi"
  property var cfg: ({})
  FileView {
    path: svc.home + "/.config/liquid-glass/config.json"
    watchChanges: true
    onFileChanged: reload()
    onLoaded: { try { svc.cfg = JSON.parse(text()) } catch (e) {} }
  }
  readonly property var lcfg: Object.assign({}, cfg.linux || {}, JSON.parse(Quickshell.env("LG_TEST") || "{}"))
  // Réglage : d'abord la valeur propre au thème actif (linux.<style>__<clé>, écrite par
  // Réglages → page du thème), puis la valeur commune (linux.<clé>), puis le défaut.
  function opt(k, d) {
    var sk = style + "__" + k
    if (lcfg.hasOwnProperty(sk)) return lcfg[sk]
    return lcfg.hasOwnProperty(k) ? lcfg[k] : d
  }
  // Styles : blanc (défaut), sombre, jouet, violet (nuit/aube/rose), expressive (Material You), lain.
  // Tous sauf lain partagent les mêmes composants (Ex*), habillés par une « peau »
  // (palette, polices, arrondis, bordures, ombres) et un jeu de widgets.
  readonly property var styles: ["blanc", "sombre", "jouet", "violet", "expressive", "windows", "mono", "foret",
                                 "ruban", "espace", "cosmos", "ile", "hud", "infini", "gouts", "debian", "fedora", "mint", "kali", "arch"]
  readonly property string style: styles.indexOf(String(lcfg.style || "blanc")) >= 0 ? String(lcfg.style || "blanc") : "blanc"
  readonly property bool ex: true
  // Familles de bureau : « ex » = barre en îlots + widgets (blanc… expressive),
  // puis trois bureaux complets avec leurs propres barres, menus et réglages.
  readonly property bool win11: style === "windows"
  readonly property bool isMono: style === "mono"
  readonly property bool isForet: style === "foret"
  // Bureaux qui reprennent l'environnement d'une distribution (DistroPanel, DistroMenu).
  readonly property var distroDefs: ({
    debian: { layout: "gnome", glyph: "\uf306", menuLabel: T.t("Activités"), barH: 30, bottom: false, pins: 0 },
    fedora: { layout: "gnome", glyph: "\uf30a", menuLabel: "", barH: 30, bottom: false, pins: 0, pills: true },
    mint: { layout: "cinnamon", glyph: "\uf30e", menuLabel: "Menu", barH: 40, bottom: true, pins: 3 },
    kali: { layout: "xfce", glyph: "\uf327", menuLabel: "", barH: 30, bottom: false, pins: 3 },
    arch: { layout: "plasma", glyph: "\uf303", menuLabel: "", barH: 44, bottom: true, pins: 3 }
  })
  readonly property var distro: distroDefs[style] || null
  readonly property bool isDistro: !!distro
  readonly property bool isRuban: style === "ruban"
  readonly property bool isCosmos: style === "cosmos"
  readonly property bool isEspace: style === "espace" || isCosmos
  readonly property bool isIle: style === "ile"
  // 7JOKS : bureau de terminal de science-fiction (HudDesk), démarrage animé (HudBoot).
  readonly property bool isHud: style === "hud"
  // Infini : toile sans bord qu'on fait glisser (InfiniDesk), cerisiers, visualiseur rose.
  readonly property bool isInfini: style === "infini"
  property var infiniDesk: null   // InfiniDesk de l'écran principal (zoom de la toile)
  // Zoom : la toile sur Infini, la loupe d'Hyprland ailleurs. dir = in | out | reset
  function zoom(dir) {
    if (isInfini && infiniDesk) { infiniDesk.zoomStep(dir); return }
    Quickshell.execDetached(["hyprctl", "eval",
      dir === "reset" ? "hl.config({ cursor = { zoom_factor = 1 } })"
      : "local z = hl.get_config('cursor.zoom_factor') or 1; hl.config({ cursor = { zoom_factor = math.max(1, z " + (dir === "in" ? "+ 1" : "- 1") + ") } })"])
  }
  // ⌘ + molette / deux doigts : zoom de la toile sur Infini, bureaux voisins ailleurs.
  function wheel(dir) {
    if (isInfini && infiniDesk) { infiniDesk.zoomStep(dir === "up" ? "wheel-in" : "wheel-out"); return }
    Quickshell.execDetached(["hyprctl", "dispatch", "hl.dsp.focus({ workspace = \"m" + (dir === "up" ? "-1" : "+1") + "\" })"])
  }
  readonly property bool classic: !win11 && !isMono && !isForet && !isDistro && !isRuban && !isEspace && !isIle && !isHud && !isInfini
  // Sombre : mur de tuiles à la place de la scène musicale et des widgets.
  readonly property bool wall: style === "sombre" && opt("sombre_wall", true) !== false
  // Blanc : barre de texte en bas (dwm) ; Jouet : gros dock, pas de barre en haut.
  readonly property bool textBar: style === "blanc"
  readonly property bool toyDock: style === "jouet"
  // Couleurs, réglées par style (⌘⌥Espace → Couleurs, ou liquid-glass set linux.<style>_colors) :
  //   theme : palette du style et de sa teinte · fond : Material You tiré du fond d'écran (matugen)
  //   perso : palette du style, accent remplacé par <style>_accent (#rrggbb)
  readonly property string colorMode: {
    var m = String(opt(style + "_colors", style === "expressive" ? "fond" : "theme"))
    return ["theme", "fond", "perso"].indexOf(m) >= 0 ? m : "theme"
  }
  readonly property string accentHex: { var a = String(opt(style + "_accent", "")); return /^#[0-9a-fA-F]{6}$/.test(a) ? a : "" }
  readonly property bool dyn: colorMode === "fond"
  // Teintes de chaque style : [clé de config, [valeur, nom, couleur d'aperçu]…] (menus, sélecteur).
  readonly property var toneDefs: ({
    gouts: ["gouts_theme", omarchyThemes],
    violet: ["violet_tone", [["nuit", T.t("Nuit"), "#4a3687"], ["aube", T.t("Aube"), "#d9c8f5"], ["rose", "Rose", "#f6cfdc"], ["minuit", T.t("Minuit"), "#2a3480"], ["crepuscule", T.t("Crépuscule"), "#46304f"], ["lavande", T.t("Lavande"), "#dcd4f0"], ["prune", T.t("Prune"), "#4a1f3e"], ["ete", T.t("Été"), "#ffb0a0"], ["automne", T.t("Automne"), "#c0603a"], ["hiver", T.t("Hiver"), "#cdd8ee"], ["printemps", T.t("Printemps"), "#f6d0de"]]],
    blanc: ["blanc_tone", [["pur", T.t("Pur"), "#f7f7f7"], ["creme", T.t("Crème"), "#efe3c8"]]],
    sombre: ["sombre_tone", [["encre", T.t("Encre"), "#f2f2f2"], ["ambre", T.t("Ambre"), "#ffb454"], ["glace", T.t("Glace"), "#9fd8ff"],
                            ["sang", T.t("Sang"), "#ff5a6e"], ["indigo", "Indigo", "#a6b1ff"]]],
    jouet: ["jouet_tone", [["bonbon", T.t("Bonbon"), "#ff5fa2"], ["menthe", T.t("Menthe"), "#18b98f"], ["peche", T.t("Pêche"), "#ff7a45"]]],
    mono: ["mono_tone", [["noir", T.t("Noir"), "#000000"], ["papier", T.t("Papier"), "#ffffff"], ["sakura", "Sakura", "#f7a8c4"]]],
    infini: ["infini_tone", [["sakura", "Sakura", "#e8a3b4"], ["lilas", T.t("Lilas"), "#c9b3f0"], ["menthe", T.t("Menthe"), "#9fdcc4"], ["peche", T.t("Pêche"), "#f5b896"]]],
    hud: ["hud_tone", [["blanc", T.t("Blanc"), "#e6e6e6"], ["cyan", "Cyan", "#aacfd1"], ["ambre", T.t("Ambre"), "#ffb43c"],
                       ["vert", T.t("Vert"), "#5cff8a"], ["rouge", T.t("Rouge"), "#ff5a5a"]]],
    windows: ["windows_tone", [["clair", T.t("Clair"), "#f3f3f3"], ["sombre", T.t("Sombre"), "#202020"]]],
    cosmos: ["cosmos_tone", [["orbite", T.t("Orbite"), "#9fdcf5"], ["mousse", T.t("Mousse"), "#a8e0a4"], ["corail", T.t("Corail"), "#ffb09c"]]],
    espace: ["espace_tone", [["bleu", T.t("Bleu"), "#8fc7ff"], ["mars", "Mars", "#ff8a6b"], ["nebuleuse", T.t("Nébuleuse"), "#c58bff"]]],
    ruban: ["ruban_tone", [["bleu", T.t("Bleu"), "#19d3ff"], ["rouge", T.t("Rouge"), "#ff3b3b"], ["or", T.t("Or"), "#ffc800"]]],
    foret: ["foret_tone", [["mousse", T.t("Mousse"), "#cfe89a"], ["cendre", T.t("Cendre"), "#f3b6c8"]]],
    expressive: ["scheme", [["tonal-spot", "Tonal", "#adc6ff"], ["expressive", T.t("Expressif"), "#debcdf"], ["vibrant", T.t("Vif"), "#ffb4ab"],
                            ["fruit-salad", T.t("Fruité"), "#ffb59c"], ["monochrome", "Mono", "#c4c6d0"]]]
  })
  // Accents proposés (mode perso) : nuancier façon Windows / GNOME.
  readonly property var accentSwatches: ["#e8475f", "#ff7a45", "#ffb454", "#f4d03f", "#8bc34a", "#18b98f", "#26c6da",
                                         "#4c9aff", "#005fb8", "#7c6cff", "#b06bd6", "#ff5fa2", "#a1887f", "#90a4ae"]
  readonly property bool showClock: opt("clock", true) !== false
  readonly property bool showCava: opt("cava", true) !== false
  readonly property bool showLyrics: opt("lyrics", true) !== false
  readonly property bool showWidgets: opt("widgets", true) !== false
  readonly property int cavaBars: Math.max(24, Math.min(160, Number(opt("cava_bars", ex ? 96 : 72)) || 72))
  readonly property int wsCount: Math.max(4, Math.min(10, Number(opt("workspaces", 7)) || 7))

  // Palette lain (fixe : ce style ne suit pas la pochette).
  readonly property color bg: "#0b0f13"
  readonly property color bar: "#111111"
  readonly property color fg: "#b9d7dc"
  readonly property color dim: "#5d7a82"
  readonly property color teal: "#2f9e9e"
  readonly property color tealDeep: "#1f6f73"
  readonly property color blue: "#2c63a8"
  readonly property color red: "#e74c3c"
  readonly property string mono: "JetBrainsMono Nerd Font"
  function glyph(cp) { return String.fromCodePoint(cp) }

  // ------------------------------------------------------------ Material You
  // matugen lit le fond courant (lien ~/.local/state/omarchy/current/background,
  // donc aussi la pochette quand Spotify la met en fond) ; le JSON est gardé en
  // cache par fichier. Toutes les couleurs glissent en 700 ms au changement.
  // ------------------------------------------------------------ peaux
  readonly property var skins: ({
    blanc:      { sans: "JetBrainsMono Nerd Font", num: "JetBrainsMono Nerd Font", pixel: "Silkscreen", display: "Syncopate",
                  radius: 0, border: 2, shadow: "hard", bar: "text", dark: false },
    sombre:     { sans: "JetBrainsMono Nerd Font", num: "JetBrainsMono Nerd Font", pixel: "Silkscreen", display: "Syncopate",
                  radius: 8, border: 1, shadow: "none", bar: "line", dark: true },
    jouet:      { sans: "Pixelify Sans", num: "Pixelify Sans", pixel: "Silkscreen", display: "Unbounded",
                  radius: 20, border: 3, shadow: "hard", bar: "dock", dark: false },
    violet:     { sans: "Google Sans Flex", num: "Google Sans Flex", pixel: "Silkscreen", display: "Google Sans Flex",
                  radius: 20, border: 0, shadow: "soft", bar: "float", dark: true },
    expressive: { sans: "Google Sans Flex", num: "Rubik", pixel: "Silkscreen", display: "Unbounded",
                  radius: 24, border: 0, shadow: "soft", bar: "float", dark: true },
    windows:    { sans: "Noto Sans", num: "Noto Sans", pixel: "Silkscreen", display: "Noto Sans",
                  radius: 8, border: 1, shadow: "soft", bar: "taskbar", dark: false },
    mono:       { sans: "Rubik", num: "Rubik", pixel: "Silkscreen", display: "Rubik",
                  radius: 18, border: 0, shadow: "soft", bar: "side", dark: true },
    gouts:      { sans: "Google Sans Flex", num: "Google Sans Flex", pixel: "Silkscreen", display: "Google Sans Flex",
                  radius: 20, border: 0, shadow: "soft", bar: "float", dark: true },
    ile:        { sans: "Inter", num: "Michroma", pixel: "Silkscreen", display: "Michroma",
                  radius: 14, border: 0, shadow: "soft", bar: "ile", dark: true },
    infini:     { sans: "Inter", num: "Bebas Neue", pixel: "Silkscreen", display: "Bebas Neue",
                  radius: 14, border: 1, shadow: "soft", bar: "infini", dark: true },
    hud:        { sans: "Share Tech Mono", num: "Share Tech Mono", pixel: "Silkscreen", display: "Michroma",
                  radius: 4, border: 1, shadow: "none", bar: "hud", dark: true },
    cosmos:     { sans: "JetBrainsMono Nerd Font", num: "JetBrainsMono Nerd Font", pixel: "Silkscreen", display: "JetBrainsMono Nerd Font",
                  radius: 10, border: 1, shadow: "soft", bar: "espace", dark: true },
    espace:     { sans: "Inter", num: "Inter", pixel: "Silkscreen", display: "Inter",
                  radius: 14, border: 1, shadow: "soft", bar: "espace", dark: true },
    ruban:      { sans: "Rubik", num: "Rubik", pixel: "Silkscreen", display: "Rubik",
                  radius: 0, border: 2, shadow: "hard", bar: "ruban", dark: true },
    debian:     { sans: "Adwaita Sans", num: "Adwaita Sans", pixel: "Silkscreen", display: "Adwaita Sans",
                  radius: 12, border: 0, shadow: "soft", bar: "gnome", dark: true },
    fedora:     { sans: "Adwaita Sans", num: "Adwaita Sans", pixel: "Silkscreen", display: "Adwaita Sans",
                  radius: 12, border: 0, shadow: "soft", bar: "gnome", dark: true },
    mint:       { sans: "Noto Sans", num: "Noto Sans", pixel: "Silkscreen", display: "Noto Sans",
                  radius: 6, border: 1, shadow: "soft", bar: "cinnamon", dark: true },
    kali:       { sans: "Noto Sans", num: "Noto Sans", pixel: "Silkscreen", display: "Noto Sans",
                  radius: 4, border: 1, shadow: "soft", bar: "xfce", dark: true },
    arch:       { sans: "Noto Sans", num: "Noto Sans", pixel: "Silkscreen", display: "Noto Sans",
                  radius: 8, border: 1, shadow: "soft", bar: "plasma", dark: true },
    foret:      { sans: "JetBrainsMono Nerd Font", num: "JetBrainsMono Nerd Font", pixel: "Silkscreen", display: "JetBrainsMono Nerd Font",
                  radius: 16, border: 1, shadow: "soft", bar: "chips", dark: true }
  })
  // Police « bonbon » des grosses horloges empilées (Google Sans Flex, axes
  // graisse 1000 + arrondi 100) : à utiliser avec font.variableAxes: svc.roundAxes.
  readonly property string roundFont: "Google Sans Flex"
  readonly property var roundAxes: ({ "wght": 1000, "ROND": 100, "opsz": 144 })
  readonly property var skin: skins[style] || skins.blanc
  readonly property string sansFont: skin.sans
  readonly property string numFont: skin.num
  readonly property string pixelFont: skin.pixel
  readonly property string displayFont: skin.display
  readonly property string iconFont: "Material Symbols Rounded"
  readonly property int radius: Number(opt("radius", skin.radius))
  readonly property int borderW: skin.border
  readonly property string shadowMode: skin.shadow
  readonly property bool darkSkin: style === "violet" ? ["nuit", "minuit", "crepuscule", "prune", "automne"].indexOf(vtone) >= 0 : (style === "windows" ? wtone === "sombre" : (style === "mono" ? mtone === "noir" : (style === "gouts" ? themeMode !== "light" : skin.dark)))
  // Windows : mode clair (défaut, comme une installation neuve) ou sombre.
  readonly property string wtone: String(opt("windows_tone", "clair")) === "sombre" ? "sombre" : "clair"
  // Forêt : « mousse » (olive, accents pêche) ou « cendre » (nuit rosée).
  readonly property string ftone: String(opt("foret_tone", "mousse")) === "cendre" ? "cendre" : "mousse"
  // Tonalité du blanc : « pur » (gris neutres) ou « creme » (papier chaud, comme la capture 1).
  readonly property string tone: String(opt("blanc_tone", "pur")) === "creme" ? "creme" : "pur"
  // Tonalité du violet : nuit (montagnes violettes la nuit), aube (lilas clair), rose (pastel).
  readonly property string stone: ["encre", "ambre", "glace", "sang", "indigo"].indexOf(String(opt("sombre_tone", "encre"))) >= 0 ? String(opt("sombre_tone", "encre")) : "encre"
  readonly property string ctone: ["orbite", "mousse", "corail"].indexOf(String(opt("cosmos_tone", "orbite"))) >= 0 ? String(opt("cosmos_tone", "orbite")) : "orbite"
  readonly property string etone: ["bleu", "mars", "nebuleuse", "aurore", "soleil"].indexOf(String(opt("espace_tone", "bleu"))) >= 0 ? String(opt("espace_tone", "bleu")) : "bleu"
  readonly property string rtone: ["bleu", "rouge", "or", "vert", "violet"].indexOf(String(opt("ruban_tone", "bleu"))) >= 0 ? String(opt("ruban_tone", "bleu")) : "bleu"
  readonly property string jtone: ["bonbon", "menthe", "peche", "lagon", "lilas"].indexOf(String(opt("jouet_tone", "bonbon"))) >= 0 ? String(opt("jouet_tone", "bonbon")) : "bonbon"
  readonly property string mtone: ["noir", "papier", "sakura"].indexOf(String(opt("mono_tone", "noir"))) >= 0 ? String(opt("mono_tone", "noir")) : "noir"
  // Cadre et barre latérale de Mono (noir pur, blanc pur ou prune) ; suit le fond en mode « fond ».
  readonly property color monoFrame: mc("frame", darkSkin ? "#000000" : "#ffffff")
  readonly property string vtone: ["nuit", "aube", "rose", "minuit", "crepuscule", "lavande", "prune", "ete", "automne", "hiver", "printemps"].indexOf(String(opt("violet_tone", "nuit"))) >= 0 ? String(opt("violet_tone", "nuit")) : "nuit"

  // « Mes goûts » : la palette vient du thème Omarchy choisi (colors.toml).
  readonly property string goutsTheme: String(opt("gouts_theme", ""))
  property var themeColors: ({})
  readonly property string themeMode: String(themeColors.mode || "dark")
  // [identifiant, nom, couleur d'accent] de chaque thème installé (menu Teinte du bureau).
  property var omarchyThemes: []
  Process {
    id: themeList
    running: svc.style === "gouts"
    command: ["sh", "-c",
      "for d in \"$HOME\"/.config/omarchy/themes/*/ /usr/share/omarchy/themes/*/; do n=$(basename \"$d\"); " +
      "case \"$n\" in liquid-glass*|lain|blanc|sombre|jouet|violet*|rose|windows*|mono*|foret|ruban|espace|debian|fedora|mint|kali|arch) continue;; esac; " +
      "a=$(sed -n 's/^accent *= *\"\\(#[0-9a-fA-F]*\\)\".*/\\1/p' \"$d/colors.toml\" 2>/dev/null | head -1); " +
      "[ -n \"$a\" ] || a=$(sed -n 's/^color4 *= *\"\\(#[0-9a-fA-F]*\\)\".*/\\1/p' \"$d/colors.toml\" 2>/dev/null | head -1); " +
      "[ -n \"$a\" ] && echo \"$n $a\"; done | sort -u -k1,1"]
    stdout: StdioCollector {
      onStreamFinished: {
        var l = text.trim().split("\n"), out = []
        for (var i = 0; i < l.length; i++) {
          var f = l[i].split(" ")
          if (f.length === 2) out.push([f[0], f[0].replace(/-/g, " ").replace(/^./, function(c) { return c.toUpperCase() }), f[1]])
        }
        svc.omarchyThemes = out
      }
    }
  }
  // Thème en cours, ou celui demandé (tests) : le fichier est relu à chaque changement.
  Process {
    id: themeRead
    command: ["sh", "-c", "t=\"$1\"; for f in \"$HOME/.config/omarchy/themes/$t/colors.toml\" \"/usr/share/omarchy/themes/$t/colors.toml\" " +
      "\"$HOME/.local/state/omarchy/current/theme/colors.toml\"; do [ -f \"$f\" ] && { cat \"$f\"; exit; }; done", "sh", svc.goutsTheme]
    stdout: StdioCollector {
      onStreamFinished: {
        var o = {}, l = text.split("\n")
        for (var i = 0; i < l.length; i++) {
          var m = l[i].match(/^\s*(\w+)\s*=\s*"([^"]+)"/)
          if (m) o[m[1]] = m[2]
        }
        svc.themeColors = o
      }
    }
  }
  function readTheme() { if (style === "gouts") { themeRead.running = false; themeRead.running = true } }
  onGoutsThemeChanged: readTheme()
  // Palette tirée d'un colors.toml : surfaces du thème, texte lisible sur l'accent.
  function tpal(c) {
    var acc = c.accent || c.color4 || "#7aa2f7", bg = c.background || "#1a1b26", fg = c.foreground || "#c0caf5"
    var a = Qt.color(acc), b = Qt.color(bg), f = Qt.color(fg), light = c.mode === "light"
    var lum = 0.2126 * a.r + 0.7152 * a.g + 0.0722 * a.b
    function up(k) { return Qt.tint(b, Qt.rgba(f.r, f.g, f.b, k)) }
    return { primary: acc, on_primary: lum > 0.5 ? "#141414" : "#ffffff",
             primary_container: Qt.tint(b, Qt.rgba(a.r, a.g, a.b, 0.35)), on_primary_container: fg,
             secondary: c.color6 || acc, secondary_container: up(0.1), on_secondary_container: fg,
             tertiary: c.color5 || acc, tertiary_container: up(0.14), on_tertiary_container: fg,
             surface: bg, surface_container_low: c.dark_background || up(0.03), surface_container: up(0.06), surface_container_high: up(0.1),
             surface_container_highest: up(0.15), on_surface: fg, on_surface_variant: Qt.tint(b, Qt.rgba(f.r, f.g, f.b, 0.68)),
             outline: c.muted || up(0.4), outline_variant: up(0.2), error: c.color1 || "#f7768e" }
  }

  // Palette d'un bureau de distribution : son accent sur son gris.
  function dpal(p, bg) {
    var c = Qt.color(p), b = Qt.color(bg)
    return { primary: p, on_primary: "#ffffff", primary_container: Qt.tint(b, Qt.rgba(c.r, c.g, c.b, 0.45)), on_primary_container: "#ffffff",
             secondary: Qt.lighter(p, 1.3), secondary_container: Qt.lighter(b, 1.5), on_secondary_container: "#ffffff",
             tertiary: Qt.lighter(p, 1.5), tertiary_container: Qt.tint(b, Qt.rgba(c.r, c.g, c.b, 0.25)), on_tertiary_container: "#ffffff",
             surface: bg, surface_container_low: Qt.lighter(b, 1.1), surface_container: Qt.lighter(b, 1.2), surface_container_high: Qt.lighter(b, 1.45),
             surface_container_highest: Qt.lighter(b, 1.7), on_surface: "#f2f2f2", on_surface_variant: "#b8b8b8",
             outline: "#7c7c7c", outline_variant: Qt.lighter(b, 1.9), error: "#ff7b63" }
  }

  // Palettes fixes (mêmes clés que matugen) ; « expressive » prend celle de matugen.
  readonly property var fixed: ({
    // Île : prune désaturée, noir pur pour l'encoche.
    ile: {
      primary: "#c9c2cc", on_primary: "#17151b", primary_container: "#3a3640", on_primary_container: "#e6e0e8",
      secondary: "#8a8490", secondary_container: "#26232b", on_secondary_container: "#d8d2da",
      tertiary: "#7c74c8", tertiary_container: "#2e2a4a", on_tertiary_container: "#dcd8f4",
      surface: "#17151b", surface_container_low: "#1b191f", surface_container: "#211f25", surface_container_high: "#26232b",
      surface_container_highest: "#322e37", on_surface: "#e0dae2", on_surface_variant: "#8a8490",
      outline: "#5e5864", outline_variant: "#35313b", error: "#e8857c" },
    // Infini : verre fumé brun-rose, accent de la teinte (sakura par défaut).
    infini: (function() {
      var a = ({ sakura: "#e8a3b4", lilas: "#c9b3f0", menthe: "#9fdcc4", peche: "#f5b896" })[String(opt("infini_tone", "sakura"))] || "#e8a3b4"
      return { primary: a, on_primary: "#2a1218", primary_container: "#4a3439", on_primary_container: "#ffe0e7",
        secondary: "#c4a9af", secondary_container: "#3a2e31", on_secondary_container: "#f0dfe3",
        tertiary: "#d8b4a0", tertiary_container: "#45352c", on_tertiary_container: "#f6e2d6",
        surface: "#1c1718", surface_container_low: "#211b1c", surface_container: "#2a2324", surface_container_high: "#332b2d",
        surface_container_highest: "#3d3436", on_surface: "#ece2e4", on_surface_variant: "#a8999c",
        outline: "#6e5f62", outline_variant: "#4a3f42", error: "#ff8a8f" }
    })(),
    // 7JOKS : noir pur, traits de la teinte choisie.
    hud: (function() {
      var a = ({ blanc: "#e6e6e6", cyan: "#aacfd1", ambre: "#ffb43c", vert: "#5cff8a", rouge: "#ff5a5a" })[String(opt("hud_tone", "blanc"))] || "#e6e6e6"
      return { primary: a, on_primary: "#000000", primary_container: "#1a1a1a", on_primary_container: a,
        secondary: a, secondary_container: "#141414", on_secondary_container: a,
        tertiary: a, tertiary_container: "#141414", on_tertiary_container: a,
        surface: "#000000", surface_container_low: "#050505", surface_container: "#0a0a0a", surface_container_high: "#111111",
        surface_container_highest: "#181818", on_surface: a, on_surface_variant: "#8a8a8a",
        outline: "#5a5a5a", outline_variant: "#2a2a2a", error: "#ff5a5a" }
    })(),
    // Cosmos : verre sombre sarcelle, accent choisi.
    cosmos: Object.assign({
      primary: "#9fdcf5", on_primary: "#06222e", primary_container: "#16404f", on_primary_container: "#d5f2ff",
      secondary: "#a5c3cf", secondary_container: "#17272e", on_secondary_container: "#d5e6ee",
      tertiary: "#cdbdff", tertiary_container: "#2b2548", on_tertiary_container: "#e6deff",
      surface: "#0b1216", surface_container_low: "#10191e", surface_container: "#152127", surface_container_high: "#1c2a31",
      surface_container_highest: "#25353d", on_surface: "#e4eef2", on_surface_variant: "#92a6af",
      outline: "#5b6f78", outline_variant: "#2a3a42", error: "#ff8a8a" }, ctone === "mousse" ? {
      primary: "#a8e0a4", on_primary: "#0d2b10", primary_container: "#1f4624", on_primary_container: "#d4f3d0",
      surface: "#10140f", surface_container_low: "#151b14", surface_container: "#1b2319", surface_container_high: "#232d21", surface_container_highest: "#2d3a2b" } : ctone === "corail" ? {
      primary: "#ffb09c", on_primary: "#361006", primary_container: "#5e2a1c", on_primary_container: "#ffe0d6",
      surface: "#150f0d", surface_container_low: "#1b1412", surface_container: "#231a17", surface_container_high: "#2e221e", surface_container_highest: "#3a2c27" } : {}),
    // Espace : ciel presque noir, accent qui suit l'astre du fond.
    espace: Object.assign({
      primary: "#8fc7ff", on_primary: "#06162b", primary_container: "#1c3a5e", on_primary_container: "#d6ebff",
      secondary: "#9fb4cc", secondary_container: "#16233a", on_secondary_container: "#d6e3f2",
      tertiary: "#ffd27a", tertiary_container: "#4a3812", on_tertiary_container: "#ffefcc",
      surface: "#070b14", surface_container_low: "#0c121f", surface_container: "#111929", surface_container_high: "#182235",
      surface_container_highest: "#212d44", on_surface: "#eef3fa", on_surface_variant: "#9aa9bd",
      outline: "#5a6a80", outline_variant: "#25324a", error: "#ff7b86" }, etone === "mars" ? {
      primary: "#ff8a6b", on_primary: "#2b0c04", primary_container: "#5c2616", on_primary_container: "#ffdccf",
      secondary: "#d1a896", secondary_container: "#33201a", tertiary: "#ffc27a",
      surface: "#120a08", surface_container_low: "#1a100c", surface_container: "#221511", surface_container_high: "#2e1d17",
      surface_container_highest: "#3b261e", on_surface: "#f7ece7", on_surface_variant: "#bda69c", outline: "#80645a", outline_variant: "#46302a" } : etone === "aurore" ? {
      primary: "#6ff0b4", on_primary: "#03241a", primary_container: "#145a43", on_primary_container: "#d2fbe8",
      secondary: "#9fd8c6", secondary_container: "#10302a", tertiary: "#b58bff",
      surface: "#04100e", surface_container_low: "#081815", surface_container: "#0c201c", surface_container_high: "#122c27",
      surface_container_highest: "#193a33", on_surface: "#ebfaf4", on_surface_variant: "#93b8ac", outline: "#4f7a6e", outline_variant: "#1f3d36" } : etone === "soleil" ? {
      primary: "#ffc04d", on_primary: "#2b1a00", primary_container: "#6a4300", on_primary_container: "#ffe8bf",
      secondary: "#ffd99a", secondary_container: "#33240a", tertiary: "#ff7b54",
      surface: "#120c03", surface_container_low: "#1a1206", surface_container: "#231909", surface_container_high: "#30230d",
      surface_container_highest: "#3f2e12", on_surface: "#fff5e4", on_surface_variant: "#c9b28a", outline: "#86704a", outline_variant: "#4a3a1c" } : etone === "nebuleuse" ? {
      primary: "#c58bff", on_primary: "#1f0a38", primary_container: "#46256e", on_primary_container: "#ecdcff",
      secondary: "#b5a3d6", secondary_container: "#261b3f", tertiary: "#ff9ad6",
      surface: "#0c0816", surface_container_low: "#130d20", surface_container: "#1a122b", surface_container_high: "#241a3a",
      surface_container_highest: "#30234c", on_surface: "#f1ecfa", on_surface_variant: "#a99dc2", outline: "#6c5e88", outline_variant: "#35294f" } : {}),
    // Rubans : aplats saturés, encre blanche.
    ruban: Object.assign({
      primary: "#19d3ff", on_primary: "#001a33", primary_container: "#0a3a8c", on_primary_container: "#d8f6ff",
      secondary: "#8fe8ff", secondary_container: "#0d2a66", on_secondary_container: "#d8f6ff",
      tertiary: "#ffffff", tertiary_container: "#18367f", on_tertiary_container: "#ffffff",
      surface: "#06102e", surface_container_low: "#0a1840", surface_container: "#0d2050", surface_container_high: "#122a66",
      surface_container_highest: "#18367f", on_surface: "#ffffff", on_surface_variant: "#a8dfff",
      outline: "#4f8fd0", outline_variant: "#1d3f8a", error: "#ff5a6e" }, rtone === "rouge" ? {
      primary: "#ff3b3b", on_primary: "#ffffff", primary_container: "#7a1420", on_primary_container: "#ffd8d8",
      secondary: "#ff9a9a", secondary_container: "#4a0f18",
      surface: "#16040a", surface_container_low: "#220810", surface_container: "#2c0b14", surface_container_high: "#3c1019",
      surface_container_highest: "#521620", on_surface_variant: "#ffb8b8", outline: "#c05060", outline_variant: "#6a1f2c" } : rtone === "vert" ? {
      primary: "#2ee88a", on_primary: "#002a14", primary_container: "#0d5a33", on_primary_container: "#ccffe4",
      secondary: "#9af5c4", secondary_container: "#063820",
      surface: "#03140b", surface_container_low: "#051d10", surface_container: "#072515", surface_container_high: "#0b331d",
      surface_container_highest: "#104527", on_surface_variant: "#a8f0c8", outline: "#3fae74", outline_variant: "#145a35" } : rtone === "violet" ? {
      primary: "#c06bff", on_primary: "#ffffff", primary_container: "#4f1a7a", on_primary_container: "#f0dcff",
      secondary: "#e2b3ff", secondary_container: "#2c0d45",
      surface: "#10041c", surface_container_low: "#170828", surface_container: "#1e0b33", surface_container_high: "#2a1047",
      surface_container_highest: "#3a165f", on_surface_variant: "#dcb8ff", outline: "#9a5cd0", outline_variant: "#4a2070" } : rtone === "or" ? {
      primary: "#ffc800", on_primary: "#231800", primary_container: "#6a4e00", on_primary_container: "#fff0c0",
      secondary: "#ffe080", secondary_container: "#3a2a00",
      surface: "#151003", surface_container_low: "#1f1805", surface_container: "#282007", surface_container_high: "#362b0a",
      surface_container_highest: "#4a3a0e", on_surface_variant: "#ffe6a8", outline: "#b08a2c", outline_variant: "#5c4712" } : {}),
    gouts: tpal(themeColors),
    debian: dpal("#d70a53", "#1e1e1e"),
    fedora: dpal("#3c6eb4", "#1e2228"),
    mint: dpal("#35a854", "#262626"),
    kali: dpal("#367bf0", "#1b1d26"),
    arch: dpal("#1793d1", "#1b1e20"),
    blanc: tone === "creme" ? {
      primary: "#2b2723", on_primary: "#fbf7ee", primary_container: "#ebe3d2", on_primary_container: "#2b2723",
      secondary: "#6d655b", secondary_container: "#efe8da", on_secondary_container: "#2b2723",
      tertiary: "#c46d63", tertiary_container: "#f3dcd5", on_tertiary_container: "#4a221d",
      surface: "#fbf7ee", surface_container_low: "#fdfaf3", surface_container: "#fffdf8", surface_container_high: "#f4efe3",
      surface_container_highest: "#ebe5d6", on_surface: "#2b2723", on_surface_variant: "#7b7368",
      outline: "#a59d90", outline_variant: "#ddd5c5", error: "#c0392b" } : {
      primary: "#141414", on_primary: "#fafafa", primary_container: "#e6e6e6", on_primary_container: "#141414",
      secondary: "#5c5c5c", secondary_container: "#efefef", on_secondary_container: "#141414",
      tertiary: "#3d3d3d", tertiary_container: "#e0e0e0", on_tertiary_container: "#141414",
      surface: "#f7f7f7", surface_container_low: "#fbfbfb", surface_container: "#ffffff", surface_container_high: "#f0f0f0",
      surface_container_highest: "#e6e6e6", on_surface: "#141414", on_surface_variant: "#6e6e6e",
      outline: "#9a9a9a", outline_variant: "#d6d6d6", error: "#c0392b" },
    sombre: Object.assign({
      primary: "#f2f2f2", on_primary: "#0a0a0a", primary_container: "#262626", on_primary_container: "#f2f2f2",
      secondary: "#a8a8a8", secondary_container: "#1c1c1c", on_secondary_container: "#e6e6e6",
      tertiary: "#d0d0d0", tertiary_container: "#2e2e2e", on_tertiary_container: "#f2f2f2",
      surface: "#070707", surface_container_low: "#0b0b0b", surface_container: "#0f0f0f", surface_container_high: "#161616",
      surface_container_highest: "#202020", on_surface: "#ededed", on_surface_variant: "#8c8c8c",
      outline: "#5a5a5a", outline_variant: "#2a2a2a", error: "#ff6b6b" }, stone === "ambre" ? {
      primary: "#ffb454", on_primary: "#2a1700", primary_container: "#3a2a14", on_primary_container: "#ffdcb0",
      secondary: "#c9a77c", tertiary: "#ff8a5c", tertiary_container: "#3d2216", on_surface_variant: "#a08f7c" } : stone === "glace" ? {
      primary: "#9fd8ff", on_primary: "#00263d", primary_container: "#16303f", on_primary_container: "#d4efff",
      secondary: "#9cb4c8", tertiary: "#c7b8ff", tertiary_container: "#262140", on_surface_variant: "#8a99a6" } : stone === "sang" ? {
      primary: "#ff5a6e", on_primary: "#2a0008", primary_container: "#4a1420", on_primary_container: "#ffd0d6",
      secondary: "#d99aa2", tertiary: "#ff9a6b", tertiary_container: "#4a2014", on_surface_variant: "#b08a90" } : stone === "indigo" ? {
      primary: "#a6b1ff", on_primary: "#10154a", primary_container: "#262c66", on_primary_container: "#dde0ff",
      secondary: "#a0a6d8", tertiary: "#d0a6ff", tertiary_container: "#33245a", on_surface_variant: "#9096bf" } : {}),
    jouet: Object.assign({
      primary: "#ff5fa2", on_primary: "#1b1030", primary_container: "#ffd23f", on_primary_container: "#1b1030",
      secondary: "#3ddbb4", secondary_container: "#7ee8cf", on_secondary_container: "#1b1030",
      tertiary: "#6ec6ff", tertiary_container: "#b9a2ff", on_tertiary_container: "#1b1030",
      surface: "#e9e0ff", surface_container_low: "#fff8ee", surface_container: "#fffdf7", surface_container_high: "#ffe9f2",
      surface_container_highest: "#ffd9ea", on_surface: "#1b1030", on_surface_variant: "#5b4a7a",
      outline: "#1b1030", outline_variant: "#1b1030", error: "#ff3b3b" }, jtone === "menthe" ? {
      primary: "#18b98f", on_primary: "#062a20", secondary: "#ff7aa8", secondary_container: "#ffc2d6", tertiary: "#6ec6ff",
      surface: "#dcfff3", surface_container_low: "#f2fffa", surface_container: "#fbfffd", surface_container_high: "#e3fbf2",
      surface_container_highest: "#c9f5e6", on_surface: "#10302a", on_surface_variant: "#3f6b60" } : jtone === "peche" ? {
      primary: "#ff7a45", on_primary: "#2b1206", secondary: "#ff5fa2", secondary_container: "#ffc2dc", tertiary: "#7c6cff",
      surface: "#ffe9dc", surface_container_low: "#fff6ef", surface_container: "#fffbf7", surface_container_high: "#ffeadf",
      surface_container_highest: "#ffd7c2", on_surface: "#2b1206", on_surface_variant: "#7a4a33" } : jtone === "lagon" ? {
      primary: "#1aa7ec", on_primary: "#04203a", secondary: "#ffcf3f", secondary_container: "#ffe9a8", tertiary: "#ff6f91",
      surface: "#d9f2ff", surface_container_low: "#f0faff", surface_container: "#fafdff", surface_container_high: "#e2f4ff",
      surface_container_highest: "#c6e9ff", on_surface: "#082a40", on_surface_variant: "#3d6680" } : jtone === "lilas" ? {
      primary: "#9b6bff", on_primary: "#1b0b3a", secondary: "#ffb347", secondary_container: "#ffe0b8", tertiary: "#3ddbb4",
      surface: "#eee6ff", surface_container_low: "#faf6ff", surface_container: "#fdfbff", surface_container_high: "#f1e9ff",
      surface_container_highest: "#e0d2ff", on_surface: "#22104a", on_surface_variant: "#5e4b8a" } : {}),
    violet: vtone === "crepuscule" ? {
      primary: "#ffb38a", on_primary: "#0f0a1a", primary_container: "#66474d", on_primary_container: "#ffd9c7",
      secondary: "#e6b6f0", secondary_container: "#46304f", on_secondary_container: "#f6e9f2", tertiary: "#c48fd0",
      tertiary_container: "#503960", on_tertiary_container: "#ffd9c7", surface: "#1e1430", surface_container_low: "#241838",
      surface_container: "#2c1f44", surface_container_high: "#382749", surface_container_highest: "#46304f", on_surface: "#f6e9f2",
      on_surface_variant: "#c7aec4", outline: "#9a7a9c", outline_variant: "#46304f", error: "#ff98a6" } : vtone === "lavande" ? {
      primary: "#3d3554", on_primary: "#faf9fd", primary_container: "#dcd4f0", on_primary_container: "#2e2840",
      secondary: "#7b6fb0", secondary_container: "#ebe6f6", on_secondary_container: "#2e2840", tertiary: "#9b8fd0",
      tertiary_container: "#ebe9f6", on_tertiary_container: "#1a1528", surface: "#e9e5f2", surface_container_low: "#f3f1f8",
      surface_container: "#faf9fd", surface_container_high: "#e5e0f0", surface_container_highest: "#dcd6ea", on_surface: "#2e2840",
      on_surface_variant: "#6a6383", outline: "#a09bb8", outline_variant: "#dcd6ea", error: "#d65a74" } : vtone === "prune" ? {
      primary: "#e88ab8", on_primary: "#0e060c", primary_container: "#5d354d", on_primary_container: "#ffd9ea",
      secondary: "#f2a8cc", secondary_container: "#4a1f3e", on_secondary_container: "#f4e2ee", tertiary: "#ffcf7a",
      tertiary_container: "#604737", on_tertiary_container: "#ffd9ea", surface: "#1c0d1a", surface_container_low: "#22101f",
      surface_container: "#2a1426", surface_container_high: "#381931", surface_container_highest: "#4a1f3e", on_surface: "#f4e2ee",
      on_surface_variant: "#c2a0b6", outline: "#8e5f80", outline_variant: "#4a1f3e", error: "#ff8fa2" } : vtone === "ete" ? {
      primary: "#e2626f", on_primary: "#fffaf6", primary_container: "#ffd9c8", on_primary_container: "#40213a",
      secondary: "#e2626f", secondary_container: "#ffeadf", on_secondary_container: "#40213a", tertiary: "#8a63c9",
      tertiary_container: "#e8e0f4", on_tertiary_container: "#2a1024", surface: "#fde8dc", surface_container_low: "#fff4ec",
      surface_container: "#fffaf6", surface_container_high: "#fce2d4", surface_container_highest: "#f8d4c2", on_surface: "#40213a",
      on_surface_variant: "#85566e", outline: "#c08f9c", outline_variant: "#f6d6c8", error: "#e8566a" } : vtone === "automne" ? {
      primary: "#f0915a", on_primary: "#10090b", primary_container: "#623c2d", on_primary_container: "#ffd3b0",
      secondary: "#eaa6c2", secondary_container: "#4a2a26", on_secondary_container: "#f6e8de", tertiary: "#c9708a",
      tertiary_container: "#52303a", on_tertiary_container: "#ffd3b0", surface: "#1f1418", surface_container_low: "#25181c",
      surface_container: "#2d1d22", surface_container_high: "#3a2324", surface_container_highest: "#4a2a26", on_surface: "#f6e8de",
      on_surface_variant: "#c8a796", outline: "#9a7466", outline_variant: "#4a2a26", error: "#ff8a7a" } : vtone === "hiver" ? {
      primary: "#2c3a5e", on_primary: "#fafcff", primary_container: "#d6e0f6", on_primary_container: "#1f2a44",
      secondary: "#5f7fd0", secondary_container: "#e8eefa", on_secondary_container: "#1f2a44", tertiary: "#9b8fd0",
      tertiary_container: "#ebe9f6", on_tertiary_container: "#111a30", surface: "#e6ecf6", surface_container_low: "#f2f5fb",
      surface_container: "#fafcff", surface_container_high: "#e1e8f3", surface_container_highest: "#d4dded", on_surface: "#1f2a44",
      on_surface_variant: "#5a6788", outline: "#98a5c2", outline_variant: "#d4dded", error: "#d85670" } : vtone === "printemps" ? {
      primary: "#d2668c", on_primary: "#fdfcf8", primary_container: "#f6d6e2", on_primary_container: "#26352a",
      secondary: "#d2668c", secondary_container: "#fae9ed", on_secondary_container: "#26352a", tertiary: "#d2668c",
      tertiary_container: "#f6e0e8", on_tertiary_container: "#14211a", surface: "#eff0e6", surface_container_low: "#f8f6f0",
      surface_container: "#fdfcf8", surface_container_high: "#eaede1", surface_container_highest: "#e0e6d6", on_surface: "#26352a",
      on_surface_variant: "#5f7364", outline: "#9db2a2", outline_variant: "#e0e6d6", error: "#e05a78" } : vtone === "minuit" ? {
      primary: "#8f9bff", on_primary: "#0b1040", primary_container: "#2a3480", on_primary_container: "#dde0ff",
      secondary: "#b4a8ff", secondary_container: "#1d1850", on_secondary_container: "#e2ddff",
      tertiary: "#ff9ad6", tertiary_container: "#4a1a40", on_tertiary_container: "#ffd8ef",
      surface: "#06071a", surface_container_low: "#0b0d26", surface_container: "#101330", surface_container_high: "#171b40",
      surface_container_highest: "#202552", on_surface: "#eceeff", on_surface_variant: "#a3a8d6",
      outline: "#5d63a0", outline_variant: "#262b5c", error: "#ff7b9a" } : vtone === "aube" ? {
      primary: "#3b2463", on_primary: "#f4eeff", primary_container: "#d9c8f5", on_primary_container: "#2a1748",
      secondary: "#8a63c9", secondary_container: "#e6dafa", on_secondary_container: "#2a1748",
      tertiary: "#b06bd6", tertiary_container: "#f0d9fb", on_tertiary_container: "#3d1450",
      surface: "#eee6fb", surface_container_low: "#f6f1fd", surface_container: "#fbf8ff", surface_container_high: "#ece2fa",
      surface_container_highest: "#e0d3f5", on_surface: "#2c1b4d", on_surface_variant: "#6d5a91",
      outline: "#a593c7", outline_variant: "#d5c8ec", error: "#d64b6a" } : vtone === "rose" ? {
      primary: "#8a3e5c", on_primary: "#fff3f7", primary_container: "#f6cfdc", on_primary_container: "#4a1a2c",
      secondary: "#c06a8c", secondary_container: "#fbe1ea", on_secondary_container: "#4a1a2c",
      tertiary: "#9b6bd1", tertiary_container: "#ecdcfb", on_tertiary_container: "#341652",
      surface: "#fdeef3", surface_container_low: "#fff6f9", surface_container: "#fffafc", surface_container_high: "#fbe4ec",
      surface_container_highest: "#f6d6e2", on_surface: "#4a2533", on_surface_variant: "#8c5c6e",
      outline: "#c995a8", outline_variant: "#f0cfdb", error: "#d6365a" } : {
      primary: "#cdb6ff", on_primary: "#2a1858", primary_container: "#4a3687", on_primary_container: "#ece4ff",
      secondary: "#b79ce8", secondary_container: "#3a2b66", on_secondary_container: "#e3d7ff",
      tertiary: "#f0a6d8", tertiary_container: "#5a2d63", on_tertiary_container: "#ffd8f1",
      surface: "#1a1230", surface_container_low: "#211839", surface_container: "#271d43", surface_container_high: "#30254f",
      surface_container_highest: "#3b2f5e", on_surface: "#ece4ff", on_surface_variant: "#b6a8d8",
      outline: "#7e6fa6", outline_variant: "#43376b", error: "#ff7a9a" },
    // Windows 11 : gris mica, accent bleu système.
    windows: wtone === "sombre" ? {
      primary: "#4cc2ff", on_primary: "#002a40", primary_container: "#0f3a54", on_primary_container: "#cfeeff",
      secondary: "#9aa5b1", secondary_container: "#2d2d2d", on_secondary_container: "#ffffff",
      tertiary: "#60cdff", tertiary_container: "#1f3b4d", on_tertiary_container: "#d8f3ff",
      surface: "#1c1c1c", surface_container_low: "#202020", surface_container: "#2b2b2b", surface_container_high: "#323232",
      surface_container_highest: "#3a3a3a", on_surface: "#ffffff", on_surface_variant: "#c5c5c5",
      outline: "#7a7a7a", outline_variant: "#3d3d3d", error: "#ff99a4" } : {
      primary: "#005fb8", on_primary: "#ffffff", primary_container: "#d3e6f8", on_primary_container: "#00335f",
      secondary: "#5f6b78", secondary_container: "#e9eef3", on_secondary_container: "#1b1b1b",
      tertiary: "#0078d4", tertiary_container: "#dcebf9", on_tertiary_container: "#002a4d",
      surface: "#f3f3f3", surface_container_low: "#f9f9f9", surface_container: "#ffffff", surface_container_high: "#ececec",
      surface_container_highest: "#e3e3e3", on_surface: "#1b1b1b", on_surface_variant: "#5d5d5d",
      outline: "#8a8a8a", outline_variant: "#e0e0e0", error: "#c42b1c" },
    // Mono « Caelestia » : noir (sergioqtz), papier (archpitafio, tout blanc), sakura (rose).
    mono: mtone === "papier" ? {
      frame: "#ffffff",
      primary: "#1a1a1a", on_primary: "#ffffff", primary_container: "#e4e4e4", on_primary_container: "#1a1a1a",
      secondary: "#4a4a4a", secondary_container: "#ebebeb", on_secondary_container: "#1a1a1a",
      tertiary: "#d45a6a", tertiary_container: "#f6dde0", on_tertiary_container: "#4a1a22",
      surface: "#f4f4f4", surface_container_low: "#f8f8f8", surface_container: "#f1f1f1", surface_container_high: "#e7e7e7",
      surface_container_highest: "#dcdcdc", on_surface: "#161616", on_surface_variant: "#6a6a6a",
      outline: "#9a9a9a", outline_variant: "#dcdcdc", error: "#c0392b" } : mtone === "sakura" ? {
      frame: "#fdf1f3",
      primary: "#7a3d4f", on_primary: "#fff3f6", primary_container: "#f6c9d4", on_primary_container: "#4a1b29",
      secondary: "#9b6474", secondary_container: "#f8dde4", on_secondary_container: "#4a1b29",
      tertiary: "#e2708f", tertiary_container: "#f9d2dc", on_tertiary_container: "#4a1b29",
      surface: "#fbe9ed", surface_container_low: "#fdf1f3", surface_container: "#f9e3e8", surface_container_high: "#f5d9e0",
      surface_container_highest: "#f0ccd6", on_surface: "#5a2a38", on_surface_variant: "#9b6f7c",
      outline: "#c79aa7", outline_variant: "#efd2da", error: "#c8435f" } : {
      frame: "#000000",
      primary: "#f2f2f2", on_primary: "#121212", primary_container: "#2c2c2c", on_primary_container: "#f2f2f2",
      secondary: "#bdbdbd", secondary_container: "#262626", on_secondary_container: "#e8e8e8",
      tertiary: "#ff8a8a", tertiary_container: "#3a2323", on_tertiary_container: "#ffd6d6",
      surface: "#0d0d0d", surface_container_low: "#131313", surface_container: "#191919", surface_container_high: "#222222",
      surface_container_highest: "#2c2c2c", on_surface: "#e9e9e9", on_surface_variant: "#9e9e9e",
      outline: "#6b6b6b", outline_variant: "#2e2e2e", error: "#ff6b6b" },
    // Forêt (ilyamiro c01) : olive profond, vert tilleul, pêche et rose.
    foret: ftone === "cendre" ? {
      primary: "#f3b6c8", on_primary: "#3a1622", primary_container: "#5a2c3c", on_primary_container: "#ffd9e4",
      secondary: "#d9c3cb", secondary_container: "#3d3036", on_secondary_container: "#f5e3ea",
      tertiary: "#f6c59e", tertiary_container: "#5a3b22", on_tertiary_container: "#ffe2cb",
      surface: "#1c1719", surface_container_low: "#221c1f", surface_container: "#2a2326", surface_container_high: "#342c30",
      surface_container_highest: "#3f363a", on_surface: "#f1e6ea", on_surface_variant: "#c2b2b8",
      outline: "#8e7c83", outline_variant: "#4a3f44", error: "#ff9aa2" } : {
      primary: "#cfe89a", on_primary: "#22300a", primary_container: "#3f5120", on_primary_container: "#e8f7c4",
      secondary: "#c2caa6", secondary_container: "#3a4030", on_secondary_container: "#e2e9c9",
      tertiary: "#f4b6a6", tertiary_container: "#5c3a31", on_tertiary_container: "#ffdcd2",
      surface: "#1a1d14", surface_container_low: "#1f2318", surface_container: "#252a1d", surface_container_high: "#2e3424",
      surface_container_highest: "#383f2d", on_surface: "#e6e9d6", on_surface_variant: "#b9bea4",
      outline: "#868c72", outline_variant: "#434a36", error: "#ffb4a8" }
  })
  // Couleurs arc-en-ciel du style Jouet (visualiseur, accents qui tournent).
  readonly property var rainbow: ["#ff5fa2", "#ff9f43", "#ffd23f", "#3ddbb4", "#6ec6ff", "#b9a2ff"]
  readonly property string scheme: {
    var t = String(opt("scheme", "tonal-spot"))
    return ["tonal-spot", "expressive", "fruit-salad", "vibrant", "rainbow", "content", "fidelity", "neutral", "monochrome"].indexOf(t) >= 0 ? t : "tonal-spot"
  }
  property var m3: ({})
  property string bgPath: ""
  function mc(k, d) {
    var v
    if (!dyn) { var f = fixed[style]; v = f && f[k] ? f[k] : d }
    else {
      // Fond d'écran : variante claire de matugen pour les styles clairs, sombre sinon.
      var c = m3[k], m = darkSkin ? "dark" : "light"
      v = c && c[m] && c[m].color ? c[m].color : (c && c.dark && c.dark.color ? c.dark.color : d)
    }
    return colorMode === "perso" && accentHex !== "" ? accentify(k, v) : v
  }
  // Accent perso : primaire = l'accent, conteneurs et tertiaire dérivés, texte lisible dessus.
  function accentify(k, v) {
    var a = Qt.color(accentHex)
    var lum = 0.2126 * a.r + 0.7152 * a.g + 0.0722 * a.b
    if (k === "primary") return accentHex
    if (k === "on_primary") return lum > 0.55 ? "#141414" : "#ffffff"
    if (k === "primary_container") return Qt.tint(darkSkin ? "#1c1c1c" : "#ffffff", Qt.rgba(a.r, a.g, a.b, darkSkin ? 0.4 : 0.28))
    if (k === "on_primary_container") return darkSkin ? Qt.lighter(a, 1.45) : Qt.darker(a, 1.9)
    if (k === "tertiary") return Qt.hsla((a.hslHue + 0.09) % 1, Math.min(1, a.hslSaturation * 0.9), a.hslLightness, 1)
    if (k === "secondary") return Qt.hsla(a.hslHue, a.hslSaturation * 0.35, darkSkin ? 0.72 : 0.38, 1)
    return v
  }
  // Les Behavior sur des propriétés de la racine du plugin font planter
  // Quickshell (QQmlData::deferData) : la palette animée vit dans un Item enfant.
  Item {
    id: pal
    property color primary: svc.mc("primary", "#adc6ff")
    property color colOnPrimary: svc.mc("on_primary", "#102f60")
    property color primaryContainer: svc.mc("primary_container", "#2b4678")
    property color colOnPrimaryContainer: svc.mc("on_primary_container", "#d8e2ff")
    property color secondary: svc.mc("secondary", "#bfc6dc")
    property color secondaryContainer: svc.mc("secondary_container", "#3f4759")
    property color colOnSecondaryContainer: svc.mc("on_secondary_container", "#dbe2f9")
    property color tertiary: svc.mc("tertiary", "#debcdf")
    property color tertiaryContainer: svc.mc("tertiary_container", "#583e5b")
    property color colOnTertiaryContainer: svc.mc("on_tertiary_container", "#fbd7fc")
    property color surface: svc.mc("surface", "#111318")
    property color surfaceLow: svc.mc("surface_container_low", "#191c20")
    property color surfaceMid: svc.mc("surface_container", "#1d2024")
    property color surfaceHigh: svc.mc("surface_container_high", "#282a2f")
    property color surfaceHighest: svc.mc("surface_container_highest", "#33353a")
    property color colOnSurface: svc.mc("on_surface", "#e2e2e9")
    property color colOnSurfaceVariant: svc.mc("on_surface_variant", "#c4c6d0")
    property color outline: svc.mc("outline", "#8e9099")
    property color outlineVariant: svc.mc("outline_variant", "#44474f")
    property color errorColor: svc.mc("error", "#ffb4ab")
    Behavior on primary { ColorAnimation { duration: 700 } }
    Behavior on colOnPrimary { ColorAnimation { duration: 700 } }
    Behavior on primaryContainer { ColorAnimation { duration: 700 } }
    Behavior on colOnPrimaryContainer { ColorAnimation { duration: 700 } }
    Behavior on secondary { ColorAnimation { duration: 700 } }
    Behavior on secondaryContainer { ColorAnimation { duration: 700 } }
    Behavior on colOnSecondaryContainer { ColorAnimation { duration: 700 } }
    Behavior on tertiary { ColorAnimation { duration: 700 } }
    Behavior on tertiaryContainer { ColorAnimation { duration: 700 } }
    Behavior on colOnTertiaryContainer { ColorAnimation { duration: 700 } }
    Behavior on surface { ColorAnimation { duration: 700 } }
    Behavior on surfaceLow { ColorAnimation { duration: 700 } }
    Behavior on surfaceMid { ColorAnimation { duration: 700 } }
    Behavior on surfaceHigh { ColorAnimation { duration: 700 } }
    Behavior on surfaceHighest { ColorAnimation { duration: 700 } }
    Behavior on colOnSurface { ColorAnimation { duration: 700 } }
    Behavior on colOnSurfaceVariant { ColorAnimation { duration: 700 } }
    Behavior on outlineVariant { ColorAnimation { duration: 700 } }
  }
  readonly property color primary: pal.primary
  readonly property color colOnPrimary: pal.colOnPrimary
  readonly property color primaryContainer: pal.primaryContainer
  readonly property color colOnPrimaryContainer: pal.colOnPrimaryContainer
  readonly property color secondary: pal.secondary
  readonly property color secondaryContainer: pal.secondaryContainer
  readonly property color colOnSecondaryContainer: pal.colOnSecondaryContainer
  readonly property color tertiary: pal.tertiary
  readonly property color tertiaryContainer: pal.tertiaryContainer
  readonly property color colOnTertiaryContainer: pal.colOnTertiaryContainer
  readonly property color surface: pal.surface
  readonly property color surfaceLow: pal.surfaceLow
  readonly property color surfaceMid: pal.surfaceMid
  readonly property color surfaceHigh: pal.surfaceHigh
  readonly property color surfaceHighest: pal.surfaceHighest
  readonly property color colOnSurface: pal.colOnSurface
  readonly property color colOnSurfaceVariant: pal.colOnSurfaceVariant
  readonly property color outline: pal.outline
  readonly property color outlineVariant: pal.outlineVariant
  readonly property color errorColor: pal.errorColor
  function alpha(c, a) { return Qt.rgba(c.r, c.g, c.b, a) }

  Process {
    id: bgPoll
    command: ["readlink", "-f", svc.home + "/.local/state/omarchy/current/background"]
    stdout: StdioCollector {
      onStreamFinished: {
        var p = text.trim()
        if (p !== "" && p !== svc.bgPath) { svc.bgPath = p; svc.refreshPalette() }
      }
    }
  }
  Timer { interval: 2500; repeat: true; running: svc.ex; triggeredOnStart: true; onTriggered: if (!bgPoll.running) bgPoll.running = true }
  onSchemeChanged: refreshPalette()
  onDynChanged: refreshPalette()
  function refreshPalette() {
    if (!dyn || bgPath === "") return
    if (matu.running) { paletteAgain.restart(); return }
    matu.command = ["sh", "-c",
      "f=\"$1\"; t=\"$2\"; d=\"$HOME/.cache/liquid-glass/m3\"; mkdir -p \"$d\"; " +
      "case \"$f\" in *.mp4|*.webm|*.mkv|*.mov|*.gif) " +
      "  p=\"$HOME/.cache/liquid-glass/posters/$(basename \"${f%.*}\").jpg\"; [ -f \"$p\" ] && f=\"$p\";; esac; " +
      "k=$(printf '%s|%s|%s' \"$f\" \"$(stat -c %Y \"$f\" 2>/dev/null)\" \"$t\" | md5sum | cut -c1-16); c=\"$d/$k.json\"; " +
      "if [ ! -s \"$c\" ]; then matugen image \"$f\" -t \"scheme-$t\" -m dark --prefer saturation --json hex --dry-run " +
      "  > \"$c.tmp\" 2>/dev/null && mv \"$c.tmp\" \"$c\"; rm -f \"$c.tmp\"; fi; cat \"$c\" 2>/dev/null",
      "sh", bgPath, scheme]
    matu.running = true
  }
  Timer { id: paletteAgain; interval: 400; onTriggered: svc.refreshPalette() }
  Process {
    id: matu
    stdout: StdioCollector {
      onStreamFinished: { try { var j = JSON.parse(text); if (j.colors) svc.m3 = j.colors } catch (e) {} }
    }
  }

  // Bordures Hyprland aux couleurs de la palette (dégradé primaire → tertiaire ;
  // valeurs cibles de matugen, pas les couleurs en cours d'animation),
  // fenêtres arrondies et ombrées comme end4. Réappliqué après chaque rechargement
  // de la config Hyprland ; le style lain recharge la config pour revenir au carré.
  Timer { id: hyprDebounce; interval: 350; onTriggered: svc.applyHypr() }
  onM3Changed: { hyprDebounce.restart(); if (m3 && m3.primary && !testing) m3Cache.setText(JSON.stringify({ colors: m3 })) }
  onStyleChanged: { hyprDebounce.restart(); readTheme() }
  onThemeColorsChanged: hyprDebounce.restart()
  onVtoneChanged: hyprDebounce.restart()
  onToneChanged: hyprDebounce.restart()
  onWtoneChanged: hyprDebounce.restart()
  onFtoneChanged: hyprDebounce.restart()
  onStoneChanged: hyprDebounce.restart()
  onJtoneChanged: hyprDebounce.restart()
  onMtoneChanged: hyprDebounce.restart()
  onRtoneChanged: hyprDebounce.restart()
  onEtoneChanged: hyprDebounce.restart()
  onCtoneChanged: hyprDebounce.restart()
  onAccentHexChanged: hyprDebounce.restart()
  onColorModeChanged: hyprDebounce.restart()
  onExChanged: if (ex) hyprDebounce.restart(); else Quickshell.execDetached(["hyprctl", "reload"])
  function hex(c, a) { return String(c).replace("#", "").slice(-6) + a }
  function applyHypr() {
    if (!ex || (dyn && !m3.primary)) return
    var r = Math.min(16, radius)
    var act, inact, bw = 2, gin = 5, gout = 10, shadow = "rgba(00000055)"
    if (style === "blanc") {
      act = "\"rgba(" + hex(mc("primary", "#141414"), "ee") + ")\""; inact = "rgba(" + hex(mc("outline_variant", "#d6d6d6"), "ff") + ")"
      // Bords durs, ombre décalée pleine : les fenêtres sont des feuilles posées sur le papier.
      bw = 2; gin = 6; gout = 12; r = 0; shadow = "rgba(" + hex(mc("on_surface", "#141414"), "ff") + ")"
    } else if (style === "sombre") {
      act = "\"rgba(" + hex(mc("primary", "#f2f2f2"), "cc") + ")\""; inact = "rgba(2a2a2aff)"; bw = 1; gin = 4; gout = 8; shadow = "rgba(000000aa)"
    } else if (style === "jouet") {
      act = "{ colors = { \"rgba(ff5fa2ff)\", \"rgba(ffd23fff)\", \"rgba(3ddbb4ff)\", \"rgba(6ec6ffff)\" }, angle = 45 }"
      inact = "rgba(1b1030ff)"; bw = 3; gin = 7; gout = 14; shadow = "rgba(1b1030ff)"
    } else if (style === "violet") {
      act = "{ colors = { \"rgba(" + hex(mc("primary", "#cdb6ff"), "ff") + ")\", \"rgba(" + hex(mc("tertiary", "#f0a6d8"), "ff") + ")\" }, angle = 135 }"
      inact = "rgba(" + hex(mc("outline_variant", "#43376b"), "aa") + ")"; gin = 5; gout = 12; shadow = darkSkin ? "rgba(0a0418aa)" : "rgba(3b246340)"
    } else if (style === "windows") {
      // Fenêtres Windows 11 : coins 8 px, liseré gris d'un pixel, accent sur la fenêtre active, grande ombre douce.
      act = "\"rgba(" + hex(mc("primary", "#005fb8"), "cc") + ")\""; inact = darkSkin ? "rgba(3d3d3dff)" : "rgba(d0d0d0ff)"
      bw = 1; gin = 4; gout = 8; shadow = darkSkin ? "rgba(000000aa)" : "rgba(00000048)"; r = 8
    } else if (style === "mono") {
      act = "\"rgba(" + hex(mc("primary", "#e6e6e6"), "aa") + ")\""; inact = "rgba(" + hex(mc("outline_variant", "#2a2a2a"), "ff") + ")"
      bw = 1; gin = 6; gout = 12; shadow = darkSkin ? "rgba(000000cc)" : "rgba(00000040)"; r = 14
    } else if (style === "infini") {
      // Infini : liseré rose fin, coins arrondis, ombre douce (les fenêtres flottent sur la toile).
      act = "\"rgba(" + hex(mc("primary", "#e8a3b4"), "cc") + ")\""; inact = "rgba(" + hex(mc("outline_variant", "#4a3f42"), "aa") + ")"
      bw = 1; gin = 6; gout = 14; r = 12; shadow = "rgba(0a0607aa)"
    } else if (style === "hud") {
      // 7JOKS : un trait fin de la teinte, coins presque droits, pas d'ombre, cadre serré.
      act = "\"rgba(" + hex(mc("primary", "#e6e6e6"), "ff") + ")\""; inact = "rgba(3a3a3aff)"
      bw = 1; gin = 4; gout = 6; r = 4; shadow = "rgba(00000000)"
    } else if (style === "foret") {
      act = "{ colors = { \"rgba(" + hex(mc("primary", "#cfe89a"), "ee") + ")\", \"rgba(" + hex(mc("tertiary", "#f4b6a6"), "ee") + ")\" }, angle = 45 }"
      inact = "rgba(" + hex(mc("outline_variant", "#434a36"), "aa") + ")"; bw = 2; gin = 6; gout = 12; shadow = "rgba(0a0c06aa)"; r = 14
    } else {
      act = "{ colors = { \"rgba(" + hex(mc("primary", "#adc6ff"), "ee") + ")\", \"rgba(" + hex(mc("tertiary", "#debcdf"), "ee") + ")\" }, angle = 45 }"
      inact = "rgba(" + hex(mc("outline_variant", "#44474f"), "88") + ")"; gin = 4; gout = 8; shadow = "rgba(00000066)"
    }
    // Jouet : ombre dure décalée (néo-brutalisme) ; sinon ombre douce.
    var sh = style === "jouet" || style === "blanc" ? "shadow = { enabled = true, range = 0, render_power = 1, offset = \"6 6\", color = \"" + shadow + "\" }"
                               : "shadow = { enabled = true, range = 14, render_power = 3, color = \"" + shadow + "\" }"
    var lua = "hl.config({ general = { gaps_in = " + gin + ", gaps_out = " + gout + ", border_size = " + bw + ", col = { " +
      "active_border = " + act + ", inactive_border = \"" + inact + "\" } }, " +
      "decoration = { rounding = " + r + ", " + sh + " } })"
    Quickshell.execDetached(["hyprctl", "eval", lua])
  }


  // ------------------------------------------------------------ système
  property real cpu: 0
  property real memUsedGb: 0
  property real memPct: 0
  property real diskPct: 0
  property int temp: 0
  property int uptimeMin: 0
  property string netDev: ""
  property bool netWifi: false
  property var lastCpu: null
  property string hostname: ""
  FileView {
    path: "/etc/hostname"
    printErrors: false
    onLoaded: svc.hostname = text().trim()
  }
  Process {
    id: sys
    command: ["sh", "-c",
      "head -1 /proc/stat; " +
      "awk '/^MemTotal/{t=$2}/^MemAvailable/{a=$2}END{print \"mem\",t,a}' /proc/meminfo; " +
      "for z in /sys/class/thermal/thermal_zone*; do [ \"$(cat $z/type)\" = x86_pkg_temp ] && { echo temp $(cat $z/temp); break; }; done; " +
      "df -P / | awk 'NR==2{sub(\"%\",\"\",$5); print \"disk\",$5}'; " +
      "awk '{print \"up\",int($1/60)}' /proc/uptime; " +
      "d=$(ip route get 1.1.1.1 2>/dev/null | sed -n 's/.* dev \\([^ ]*\\).*/\\1/p'); " +
      "echo net \"$d\" $([ -n \"$d\" ] && [ -d /sys/class/net/$d/wireless ] && echo wifi || echo wired)"]
    stdout: StdioCollector {
      onStreamFinished: {
        var lines = text.split("\n")
        for (var i = 0; i < lines.length; i++) {
          var p = lines[i].trim().split(/\s+/)
          if (p[0] === "cpu") {
            var v = p.slice(1).map(Number), idle = v[3] + (v[4] || 0), total = 0
            for (var j = 0; j < v.length; j++) total += v[j]
            if (svc.lastCpu) {
              var dt = total - svc.lastCpu.total, di = idle - svc.lastCpu.idle
              if (dt > 0) svc.cpu = Math.max(0, Math.min(1, 1 - di / dt))
            }
            svc.lastCpu = { total: total, idle: idle }
          } else if (p[0] === "mem") {
            var t = Number(p[1]), a = Number(p[2])
            svc.memUsedGb = (t - a) / 1048576
            svc.memPct = t > 0 ? (t - a) / t : 0
          } else if (p[0] === "temp") {
            svc.temp = Math.round(Number(p[1]) / 1000)
          } else if (p[0] === "disk") {
            svc.diskPct = Number(p[1]) / 100
          } else if (p[0] === "up") {
            svc.uptimeMin = Number(p[1])
          } else if (p[0] === "net") {
            svc.netDev = p.length > 2 ? p[1] : ""
            svc.netWifi = p[p.length - 1] === "wifi"
          }
        }
      }
    }
  }
  Timer { interval: 2000; repeat: true; running: true; triggeredOnStart: true; onTriggered: if (!sys.running) sys.running = true }
  readonly property string uptimeText: uptimeMin < 60 ? uptimeMin + " min"
    : (uptimeMin < 1440 ? Math.floor(uptimeMin / 60) + " h " + (uptimeMin % 60) + " min" : Math.floor(uptimeMin / 1440) + " j " + Math.floor(uptimeMin % 1440 / 60) + " h")

  readonly property var battery: UPower.displayDevice
  readonly property int batteryPct: battery && battery.ready && battery.isLaptopBattery ? Math.round(battery.percentage * 100) : -1
  readonly property bool charging: !UPower.onBattery

  // Disposition clavier (« CH »), relue à chaque changement signalé par Hyprland.
  property string layout: ""
  Process {
    id: kbQuery
    command: ["hyprctl", "devices", "-j"]
    stdout: StdioCollector {
      onStreamFinished: {
        try {
          var kbs = JSON.parse(text).keyboards || [], kb = null
          for (var i = 0; i < kbs.length; i++) if (kbs[i].main) kb = kbs[i]
          kb = kb || kbs[kbs.length - 1]
          if (!kb) return
          var names = String(kb.layout || "").split(",")
          svc.layout = String(names[kb.active_layout_index || 0] || names[0] || "").toUpperCase()
        } catch (e) {}
      }
    }
  }
  Component.onCompleted: { kbQuery.running = true; weatherDebounce.restart(); readTheme() }
  Connections {
    target: Hyprland
    function onRawEvent(event) {
      if (event.name === "activelayout" && !kbQuery.running) kbQuery.running = true
      else if (event.name === "configreloaded") hyprDebounce.restart()
    }
  }

  // ------------------------------------------------------------ météo
  // Open-Meteo, ville de [widgets] weather_city ou du fuseau horaire.
  property bool hoverOpen: false      // tableau de bord Mono ouvert par le bord haut
  onPanelChanged: if (panel === "") hoverOpen = false
  property var weather: null
  // Copie pour l'écran de verrouillage, qui ne fait pas d'appel réseau.
  FileView { id: weatherCache; path: Quickshell.env("HOME") + "/.cache/liquid-glass/weather.json"; printErrors: false }
  onWeatherChanged: if (weather && !testing) weatherCache.setText(JSON.stringify(weather))
  FileView { id: m3Cache; path: Quickshell.env("HOME") + "/.cache/liquid-glass/m3/current.json"; printErrors: false }
  property var coords: null
  property string timezone: ""
  Process {
    command: ["timedatectl", "show", "-p", "Timezone", "--value"]
    running: true
    stdout: StdioCollector { onStreamFinished: svc.timezone = text.trim() }
  }
  readonly property string city: {
    var w = cfg.widgets || ({})
    var c = String(w.weather_city || "").trim()
    if (c !== "") return c
    var tz = String(timezone || "")
    return tz.indexOf("/") !== -1 ? tz.split("/").pop().replace(/_/g, " ") : ""
  }
  onCityChanged: { coords = null; weatherDebounce.restart() }
  Timer { id: weatherDebounce; interval: 2000; onTriggered: svc.refreshWeather() }
  Timer { interval: 30 * 60 * 1000; repeat: true; running: svc.ex; onTriggered: svc.refreshWeather() }
  function refreshWeather() {
    if (!ex || city === "" || geo.running || forecast.running) return
    if (!coords) {
      geo.command = ["curl", "-fsS", "--proto", "=https", "--max-time", "10", "--max-filesize", "200000",
                     "https://geocoding-api.open-meteo.com/v1/search?count=1&language=fr&format=json&name=" + encodeURIComponent(city)]
      geo.running = true
      return
    }
    forecast.command = ["curl", "-fsS", "--proto", "=https", "--max-time", "10", "--max-filesize", "200000",
                        "https://api.open-meteo.com/v1/forecast?latitude=" + coords.lat + "&longitude=" + coords.lon
                        + "&current=temperature_2m,apparent_temperature,relative_humidity_2m,wind_speed_10m,weather_code,is_day"
                        + "&hourly=temperature_2m,weather_code&forecast_hours=12"
                        + "&daily=temperature_2m_max,temperature_2m_min,sunrise,sunset,precipitation_probability_max&forecast_days=7&timezone=auto"]
    forecast.running = true
  }
  Process {
    id: geo
    stdout: StdioCollector {
      onStreamFinished: {
        try {
          var r = JSON.parse(text).results[0]
          svc.coords = { lat: Number(r.latitude).toFixed(3), lon: Number(r.longitude).toFixed(3), name: String(r.name) }
          svc.refreshWeather()
        } catch (e) {}
      }
    }
  }
  Process {
    id: forecast
    stdout: StdioCollector {
      onStreamFinished: {
        try {
          var j = JSON.parse(text), c = j.current, d = j.daily
          svc.weather = {
            temp: Math.round(c.temperature_2m), feels: Math.round(c.apparent_temperature),
            humidity: Math.round(c.relative_humidity_2m), wind: Math.round(c.wind_speed_10m),
            code: c.weather_code, isDay: c.is_day === 1,
            max: Math.round(d.temperature_2m_max[0]), min: Math.round(d.temperature_2m_min[0]),
            rain: d.precipitation_probability_max ? Math.round(d.precipitation_probability_max[0] || 0) : 0,
            sunrise: String(d.sunrise[0]).slice(11, 16), sunset: String(d.sunset[0]).slice(11, 16),
            city: svc.coords ? svc.coords.name : svc.city,
            days: d.time.map(function(t, i) { return { day: t, max: Math.round(d.temperature_2m_max[i]), min: Math.round(d.temperature_2m_min[i]) } }),
            hourly: (j.hourly && j.hourly.time ? j.hourly.time.map(function(t, i) {
              return { h: String(t).slice(11, 16), temp: Math.round(j.hourly.temperature_2m[i]), code: j.hourly.weather_code[i] } }) : [])
          }
        } catch (e) {}
      }
    }
  }
  // Code WMO → [libellé, icône Material Symbols (jour), icône (nuit)].
  function weatherInfo(code) {
    var c = Number(code)
    if (c === 0) return [T.t("ciel dégagé"), "clear_day", "clear_night"]
    if (c <= 2) return [T.t("quelques nuages"), "partly_cloudy_day", "partly_cloudy_night"]
    if (c === 3) return [T.t("couvert"), "cloud", "cloud"]
    if (c <= 48) return [T.t("brouillard"), "foggy", "foggy"]
    if (c <= 57) return [T.t("bruine"), "rainy_light", "rainy_light"]
    if (c <= 67) return [T.t("pluie"), "rainy", "rainy"]
    if (c <= 77) return [T.t("neige"), "weather_snowy", "weather_snowy"]
    if (c <= 82) return [T.t("averses"), "rainy_heavy", "rainy_heavy"]
    if (c <= 86) return [T.t("averses de neige"), "weather_snowy", "weather_snowy"]
    return [T.t("orages"), "thunderstorm", "thunderstorm"]
  }
  readonly property string weatherDesc: weather ? weatherInfo(weather.code)[0] : ""
  readonly property string weatherIcon: weather ? weatherInfo(weather.code)[weather.isDay ? 1 : 2] : "cloud_off"

  // ------------------------------------------------------------ musique
  readonly property var player: {
    var ps = Mpris.players ? Mpris.players.values : []
    var spotify = null, playingP = null
    for (var i = 0; i < ps.length; i++) {
      var id = String(ps[i].identity || "").toLowerCase() + String(ps[i].desktopEntry || "").toLowerCase()
      if (!spotify && id.indexOf("spotify") >= 0) spotify = ps[i]
      if (!playingP && ps[i].isPlaying) playingP = ps[i]
    }
    return spotify || playingP
  }
  readonly property bool playing: !!player && player.isPlaying
  readonly property bool hasTrack: !!player && String(player.trackTitle || "") !== ""

  // Paroles et pochette : now-playing.json écrit par liquid-glass.spotify.
  property var np: ({})
  FileView {
    path: svc.home + "/.cache/liquid-glass/now-playing.json"
    watchChanges: true
    printErrors: false
    onFileChanged: reload()
    onLoaded: { try { svc.np = JSON.parse(text()) } catch (e) {} }
  }
  // Dernier morceau écouté (gardé quand Spotify est fermé) : la carte le montre
  // avec ▶ pour reprendre (`liquid-glass resume-music`), comme l'écran verrouillé.
  property var last: ({})
  FileView {
    path: svc.home + "/.cache/liquid-glass/last-track.json"
    watchChanges: true
    printErrors: false
    onFileChanged: reload()
    onLoaded: { try { svc.last = JSON.parse(text()) } catch (e) {} }
  }
  readonly property bool resumeMode: !hasTrack && String(last.title || "") !== ""
  readonly property string trackTitle: hasTrack ? String(player.trackTitle || "") : String(last.title || "")
  readonly property string trackArtist: hasTrack ? String(player.trackArtist || "") : String(last.artist || "")
  property bool resuming: false
  onHasTrackChanged: if (hasTrack) resuming = false
  function resume() {
    if (resuming) return
    resuming = true
    resumeTimeout.restart()
    Quickshell.execDetached(["liquid-glass", "resume-music"])
  }
  Timer { id: resumeTimeout; interval: 30000; onTriggered: svc.resuming = false }
  function playPause() { if (hasTrack) player.togglePlaying(); else if (resumeMode) resume() }

  readonly property bool npMatches: hasTrack && np.title === player.trackTitle
  readonly property var lyrics: npMatches && Array.isArray(np.lyrics) ? np.lyrics : []
  readonly property string cover: npMatches && np.cover ? "file://" + np.cover
    : (player && String(player.trackArtUrl || "").indexOf("file://") === 0 ? player.trackArtUrl
    : (resumeMode && last.cover ? "file://" + last.cover : ""))
  property int lineIndex: -1
  property real position: 0
  readonly property real length: hasTrack && player.length > 0 ? player.length : 0
  readonly property real progress: length > 0 ? Math.max(0, Math.min(1, position / length)) : 0

  // ------------------------------------------------------------ réglages musique
  // Tous dans [linux] de config.toml (Réglages → Bureau Linux → Musique).
  function sdef(m) { return m[style] !== undefined ? m[style] : m["*"] }
  readonly property string vizMode: String(opt("viz", sdef({ blanc: "bars", sombre: "bars", jouet: "blocks", violet: "wave", expressive: "wave", "*": "bars" })))
  readonly property int vizHeight: Math.max(40, Math.min(400, Number(opt("viz_height", sdef({ jouet: 130, sombre: 170, "*": 140 })))))
  readonly property real vizGain: Math.max(0.3, Math.min(3, Number(opt("viz_gain", 1.0)) || 1))
  readonly property real vizOpacity: Math.max(0.1, Math.min(1, Number(opt("viz_opacity", sdef({ blanc: 0.85, "*": 0.9 })))))
  readonly property string vizColorMode: String(opt("viz_color", sdef({ jouet: "rainbow", "*": "auto" })))  // auto | cover | rainbow | ink
  readonly property string lyricsMode: String(opt("lyrics_mode", sdef({ expressive: "card", violet: "line", "*": "word" })))  // word | line | card | off
  readonly property string lyricsPos: String(opt("lyrics_pos", "center"))     // center | left | top
  readonly property real lyricsScale: Math.max(0.4, Math.min(2.5, Number(opt("lyrics_size", 1.0)) || 1))
  readonly property bool pulse: opt("pulse", true) !== false                 // halo qui respire avec les basses
  readonly property bool bump: opt("bump", true) !== false                   // widgets qui sautent sur les basses
  readonly property bool coverTint: opt("cover_tint", false) !== false        // accents à la couleur de la pochette
  readonly property color coverAccent: npMatches && np.palette && np.palette.accent ? np.palette.accent : primary
  function vizColor(i, n) {
    if (vizColorMode === "rainbow") return rainbow[Math.floor(i / Math.max(1, n) * rainbow.length) % rainbow.length]
    if (vizColorMode === "cover") return coverAccent
    if (vizColorMode === "ink") return colOnSurface
    return coverTint ? coverAccent : primary
  }

  // Paroles : ligne courante, et en mode « mot » le mot chanté (chaque ligne est
  // répartie sur sa durée jusqu'à la suivante, en finissant un peu en avance).
  property var lineWords: []
  property int wordIndex: -1
  readonly property string word: wordIndex >= 0 && wordIndex < lineWords.length ? lineWords[wordIndex] : ""
  readonly property string line: lineIndex >= 0 && lineIndex < lyrics.length ? String(lyrics[lineIndex].text || "") : ""
  // En pause aussi : la position (0:00 / 2:31) suit le morceau, lentement.
  Timer {
    interval: 1500; repeat: true; triggeredOnStart: true
    running: svc.hasTrack && !svc.playing
    onTriggered: if (svc.player) { svc.player.positionChanged(); svc.position = svc.player.position }
  }
  Timer {
    interval: svc.lyricsMode === "word" ? 80 : 250; repeat: true; triggeredOnStart: true
    running: svc.playing
    onTriggered: {
      if (!svc.player) return
      svc.player.positionChanged()
      svc.position = svc.player.position
      if (!svc.showLyrics || svc.lyrics.length === 0) { svc.lineIndex = -1; svc.wordIndex = -1; return }
      var t = svc.player.position + 0.2, i = -1, L = svc.lyrics
      while (i + 1 < L.length && L[i + 1].t <= t) i++
      if (i !== svc.lineIndex) {
        svc.lineIndex = i
        svc.lineWords = i >= 0 ? String(L[i].text || "").split(/\s+/).filter(function(w) { return w !== "" }) : []
      }
      if (i < 0 || svc.lineWords.length === 0) { svc.wordIndex = -1; return }
      var start = L[i].t, end = i + 1 < L.length ? L[i + 1].t : start + 4
      var dur = Math.max(0.6, Math.min(end - start, 1.2 + svc.lineWords.length * 0.55))
      var k = Math.floor((t - start) / (dur * 0.92) * svc.lineWords.length)
      svc.wordIndex = Math.max(0, Math.min(svc.lineWords.length - 1, k))
    }
  }
  function fmtTime(sec) {
    sec = Math.max(0, Math.floor(sec))
    var m = Math.floor(sec / 60), s = sec % 60
    return m + ":" + (s < 10 ? "0" : "") + s
  }

  // cava en sortie brute : « v1;v2;…; » par image, seulement pendant la lecture.
  property var cavaValues: []
  property real beat: 0
  Process {
    id: cava
    running: (svc.showCava || svc.pulse || svc.bump) && svc.playing
    command: ["sh", "-c",
      "d=\"$HOME/.cache/liquid-glass\"; mkdir -p \"$d\"; c=\"$d/cava-linux.conf\"; " +
      "printf '[general]\\nbars = %s\\nframerate = 30\\n[input]\\nmethod = pipewire\\n" +
      "[output]\\nmethod = raw\\nraw_target = /dev/stdout\\ndata_format = ascii\\n" +
      "ascii_max_range = 100\\nbar_delimiter = 59\\nframe_delimiter = 10\\n" +
      "[smoothing]\\nnoise_reduction = 77\\n' \"$1\" > \"$c\"; exec cava -p \"$c\"",
      "sh", String(svc.cavaBars)]
    stdout: SplitParser {
      onRead: function(line) {
        var parts = line.split(";"), out = [], g = svc.vizGain, bass = 0, nb = 0
        for (var i = 0; i < parts.length; i++) if (parts[i] !== "") out.push(Math.min(100, Number(parts[i]) * g))
        var lim = Math.max(3, Math.round(out.length * 0.12))
        for (var j = 0; j < lim && j < out.length; j++) { bass += out[j]; nb++ }
        bass = nb ? bass / nb / 100 : 0
        // Attaque immédiate, retombée douce : un « battement » lisible.
        svc.beat = Math.max(bass, svc.beat * 0.86)
        svc.cavaValues = out
      }
    }
    onExited: { svc.cavaValues = []; svc.beat = 0 }
  }

  // ------------------------------------------------------------ à faire
  // ~/.config/liquid-glass/linux-todo.json : [{ "text": "…", "done": false }]
  property var todos: []
  FileView {
    id: todoFile
    path: svc.home + "/.config/liquid-glass/linux-todo.json"
    printErrors: false
    onLoaded: { try { var t = JSON.parse(text()); if (Array.isArray(t)) svc.todos = t } catch (e) {} }
  }
  function saveTodos(list) { todos = list; todoFile.setText(JSON.stringify(list, null, 1) + "\n") }
  function addTodo(t) { t = String(t || "").trim(); if (t === "") return; var l = todos.slice(); l.push({ text: t, done: false }); saveTodos(l) }
  function toggleTodo(i) { var l = todos.slice(); if (!l[i]) return; l[i] = { text: l[i].text, done: !l[i].done }; saveTodos(l) }
  function removeTodo(i) { var l = todos.slice(); l.splice(i, 1); saveTodos(l) }

  // ------------------------------------------------------------ disposition
  // Position de chaque widget déplacé (glisser, puis aimanté à la grille de 8 px).
  property var layoutPos: ({})
  FileView {
    id: layoutFile
    path: svc.home + "/.config/liquid-glass/linux-layout.json"
    printErrors: false
    onLoaded: { try { var t = JSON.parse(text()); if (t && typeof t === "object") svc.layoutPos = t } catch (e) {} }
  }
  function savePos(key, x, y) {
    var l = JSON.parse(JSON.stringify(layoutPos))
    l[key] = { x: Math.round(x), y: Math.round(y) }
    layoutPos = l
    layoutFile.setText(JSON.stringify(l, null, 1) + "\n")
  }
  function resetLayout() { layoutPos = ({}); layoutFile.setText("{}\n") }

  // ------------------------------------------------------------ carrousel de fonds
  property bool wallsOpen: false

  // ------------------------------------------------------------ menus du style
  // À la place des interfaces Omarchy (lanceur, menu « Go… », menu système) :
  //   launcher  ⌘Espace       : menu Démarrer (windows), lanceur du style sinon
  //   menu      ⌘⌥Espace      : Paramètres (windows), centre de réglages du style sinon
  //   panel     clic sur la barre : volets propres au style (calendrier, son, batterie…)
  property bool launcherOpen: false
  property bool menuOpen: false
  property string panel: ""          // windows : quick | calendar ; mono : dashboard | media | perf | session ;
                                     // foret : music | dash | battery | net
  property string menuPage: ""       // page d'arrivée des Paramètres Windows (system, about…)
  function toggleLauncher() { menuOpen = false; panel = ""; keysOpen = false; launcherOpen = !launcherOpen }
  // ⌘K : feuille des raccourcis du bureau (à la place de celle d'Omarchy).
  property bool keysOpen: false
  function toggleKeys() { var o = !keysOpen; closeAll(); menuOpen = false; keysOpen = o }
  // ⌘⌥Espace : les Réglages communs à tous les bureaux, ouverts sur la page du style
  // (le style Windows garde ses Paramètres façon Windows 11).
  function openSettings() {
    if (win11) { toggleMenu("home"); return }
    closeAll(); menuOpen = false
    Quickshell.execDetached(["omarchy-shell", "liquid-glass.settings", "openPage", "linux"])
  }
  function toggleMenu(page) {
    launcherOpen = false; panel = ""

    if (menuOpen && (!page || page === menuPage)) { menuOpen = false; return }
    menuPage = page || ""
    menuOpen = true
  }
  function togglePanel(p) { launcherOpen = false; if (!win11) menuOpen = false; panel = panel === p ? "" : p }
  // Test : LG_OPEN="launcher" | "menu:about" | "panel:quick" ouvre un volet au démarrage.
  Timer {
    running: Quickshell.env("LG_OPEN") !== null && String(Quickshell.env("LG_OPEN") || "") !== ""
    interval: 600
    onTriggered: {
      var o = String(Quickshell.env("LG_OPEN")), k = o.split(":")
      if (k[0] === "walls") svc.wallsOpen = true; else if (k[0] === "moon") svc.launcherOpen = true; else if (k[0] === "keys") svc.toggleKeys(); else if (k[0] === "launcher") svc.toggleLauncher(); else if (k[0] === "menu") svc.toggleMenu(k[1] || "home"); else if (k[0] === "panel") svc.togglePanel(k[1] || "")
    }
  }
  function closeAll() { launcherOpen = false; panel = ""; keysOpen = false; if (!win11) menuOpen = false }
  // ⌘Échap : alimentation à la manière du style (menu Démarrer pour Windows,
  // colonne de session pour Mono, volet batterie pour Forêt, réglages sinon).
  function powerMenu() {
    if (win11) toggleLauncher()
    else if (isMono) togglePanel("session")
    else if (isForet) togglePanel("battery")
    else toggleMenu("power")
  }

  // Applications (index d'Omarchy quand le shell le fournit, sinon DesktopEntries).
  readonly property var appLib: shell && shell.appLibrary ? shell.appLibrary : null
  function apps(q) {
    q = String(q || "").trim()
    if (appLib) return appLib.sortedEntries(q) || []
    var all = DesktopEntries.applications.values || [], out = []
    var lq = q.toLowerCase()
    for (var i = 0; i < all.length; i++) {
      var e = all[i]
      if (e.noDisplay) continue
      if (lq === "" || String(e.name).toLowerCase().indexOf(lq) >= 0 || String(e.genericName || "").toLowerCase().indexOf(lq) >= 0) out.push(e)
    }
    out.sort(function(a, b) {
      if (lq !== "") {
        var pa = String(a.name).toLowerCase().indexOf(lq) === 0 ? 0 : 1, pb = String(b.name).toLowerCase().indexOf(lq) === 0 ? 0 : 1
        if (pa !== pb) return pa - pb
      }
      return String(a.name).localeCompare(String(b.name))
    })
    return out
  }
  function appName(e) { return appLib ? appLib.entryName(e) : String(e.name || "") }
  function appIcon(e) {
    if (appLib) return appLib.iconSource(e.icon)
    var p = Quickshell.iconPath(String(e.icon || ""), true)
    return p !== "" ? p : Quickshell.iconPath("application-x-executable", true)
  }
  function launch(e) {
    if (!e) return
    if (appLib) appLib.launch(e.id, appName(e))
    else Quickshell.execDetached(["sh", "-c", "uwsm-app -- gtk-launch \"$1\"", "sh", String(e.id) + ".desktop"])
    closeAll()
  }
  // Applis épinglées : premières trouvées parmi des identifiants courants.
  readonly property var pinCandidates: ["chromium", "firefox", "brave-browser", "org.gnome.Nautilus", "nautilus", "Alacritty", "com.mitchellh.ghostty",
    "foot", "kitty", "spotify", "code", "dev.zed.Zed", "obsidian", "org.gnome.Calculator", "typora", "signal-desktop",
    "org.telegram.desktop", "discord", "localsend", "org.pulseaudio.pavucontrol", "btop", "mechvibes", "steam", "obs", "gimp",
    "org.gnome.TextEditor", "libreoffice-writer", "xournalpp", "mpv", "imv", "1password", "org.kde.kdenlive"]
  function pinned(n) {
    var out = []
    for (var i = 0; i < pinCandidates.length && out.length < n; i++) {
      var e = DesktopEntries.byId(pinCandidates[i])
      if (e && !e.noDisplay) out.push(e)
    }
    if (out.length < n) {
      var all = apps("")
      for (var j = 0; j < all.length && out.length < n; j++) if (out.indexOf(all[j]) < 0) out.push(all[j])
    }
    return out
  }
  function power(what) {
    closeAll(); menuOpen = false
    var cmds = { lock: "omarchy-system-lock", suspend: "systemctl suspend", reboot: "omarchy-system reboot",
                 poweroff: "omarchy-system shutdown", logout: "omarchy-system logout" }
    if (cmds[what]) run(cmds[what])
  }
  // ------------------------------------------------------------ réglages système
  // Luminosité (brightnessctl), Wi-Fi (nmcli), infos de la machine (page « Informations »).
  property real brightness: -1
  Process {
    id: brightRead
    command: ["sh", "-c", "brightnessctl -m 2>/dev/null | head -1 | cut -d, -f4 | tr -d %"]
    stdout: StdioCollector { onStreamFinished: { var v = parseInt(text); svc.brightness = isNaN(v) ? -1 : v / 100 } }
  }
  function readBrightness() { if (!brightRead.running) brightRead.running = true }
  function setBrightness(v) {
    v = Math.max(0.02, Math.min(1, v)); brightness = v
    Quickshell.execDetached(["brightnessctl", "-q", "set", Math.round(v * 100) + "%"])
  }
  property bool wifiOn: true
  property var wifiList: []          // [{ ssid, signal, secure, active }]
  property bool wifiBusy: false
  Process {
    id: wifiScanP
    command: ["sh", "-c", "nmcli -t -f WIFI g; nmcli -t -f IN-USE,SIGNAL,SECURITY,SSID dev wifi list --rescan auto 2>/dev/null"]
    stdout: StdioCollector {
      onStreamFinished: {
        var lines = text.split("\n"), out = [], seen = ({})
        svc.wifiOn = lines.length > 0 && lines[0].trim() === "enabled"
        for (var i = 1; i < lines.length; i++) {
          var l = lines[i]; if (l.trim() === "") continue
          var f = l.split(":"), ssid = f.slice(3).join(":").replace(/\\:/g, ":")
          if (ssid === "" || seen[ssid]) continue
          seen[ssid] = true
          out.push({ ssid: ssid, signal: Number(f[1]) || 0, secure: f[2] !== "" && f[2] !== "--", active: f[0] === "*" })
        }
        out.sort(function(a, b) { return (b.active - a.active) || (b.signal - a.signal) })
        svc.wifiList = out
        svc.wifiBusy = false
      }
    }
  }
  // Temps d'écran (style Espace) : nom d'application et durée, jamais le titre des
  // fenêtres. Reste dans ce fichier local ; pause après deux minutes sans activité.
  property var usage: ({})
  property int usageTicks: 0
  FileView {
    id: usageView
    path: Quickshell.env("LG_USAGE_FILE") || (Quickshell.env("HOME") + "/.local/share/liquid-glass/usage.json")
    printErrors: false
    onLoaded: { try { svc.usage = JSON.parse(text()) } catch (e) { svc.usage = {} } }
  }
  IdleMonitor { id: usageIdle; enabled: svc.isEspace; timeout: 120; respectInhibitors: false }
  function tickUsage() {
    var t = ToplevelManager.activeToplevel
    if (usageIdle.isIdle || !t || !t.appId) return
    var now = new Date(), k = Qt.formatDate(now, "yyyy-MM-dd"), u = usage
    var d = u[k] || { apps: {}, hours: [] }
    d.apps[t.appId] = (d.apps[t.appId] || 0) + 10
    d.hours[now.getHours()] = (d.hours[now.getHours()] || 0) + 10
    u[k] = d
    var ks = Object.keys(u).sort()
    while (ks.length > 30) delete u[ks.shift()]
    usage = Object.assign({}, u)
    if (++usageTicks % 6 === 0) usageView.setText(JSON.stringify(usage))
  }
  Timer { interval: 10000; repeat: true; running: svc.isEspace && !svc.testing; onTriggered: svc.tickUsage() }

  function scanWifi() { if (!wifiScanP.running) { wifiBusy = true; wifiScanP.running = true } }
  function setWifi(on) { wifiOn = on; Quickshell.execDetached(["nmcli", "radio", "wifi", on ? "on" : "off"]); rescanLater.restart() }
  function connectWifi(ssid) {
    // Réseau déjà enregistré : connexion directe ; sinon l'outil réseau d'Omarchy demande le mot de passe.
    Quickshell.execDetached(["sh", "-c", "nmcli con up id \"$1\" 2>/dev/null || nmcli dev wifi connect \"$1\" 2>/dev/null || omarchy-launch-wifi", "sh", ssid])
    rescanLater.restart()
  }
  // La barre Forêt et la barre des tâches Windows affichent le nom du réseau.
  Timer { interval: 90000; repeat: true; running: svc.win11 || svc.isForet || svc.isMono; triggeredOnStart: true; onTriggered: svc.scanWifi() }
  Timer { id: rescanLater; interval: 2500; onTriggered: svc.scanWifi() }
  property var info: ({})
  Process {
    id: infoP
    running: true
    command: ["sh", "-c",
      "echo \"host=$(cat /etc/hostname 2>/dev/null || hostname)\"; " +
      "echo \"model=$(cat /sys/class/dmi/id/sys_vendor 2>/dev/null) $(cat /sys/class/dmi/id/product_version 2>/dev/null)\"; " +
      "echo \"cpu=$(grep -m1 'model name' /proc/cpuinfo | cut -d: -f2 | sed 's/^ *//')\"; " +
      "echo \"ram=$(awk '/MemTotal/ {printf \"%.1f\", $2/1048576}' /proc/meminfo)\"; " +
      "echo \"gpu=$(lspci 2>/dev/null | grep -m1 -iE 'vga|3d' | cut -d: -f3 | sed 's/^ *//')\"; " +
      "echo \"disk=$(df -h --output=size,used / | tail -1 | awk '{print $2\" / \"$1}')\"; " +
      "echo \"kernel=$(uname -r)\"; echo \"os=$(. /etc/os-release; echo $PRETTY_NAME)\"; " +
      "echo \"omarchy=$(cat \"${OMARCHY_PATH:-/usr/share/omarchy}/version\" 2>/dev/null)\"; " +
      "echo \"installed=$(stat -c %w / 2>/dev/null | cut -d' ' -f1)\"; " +
      "echo \"res=$(hyprctl monitors -j 2>/dev/null | grep -m1 -oE '\"width\": [0-9]+, \"height\": [0-9]+' | grep -oE '[0-9]+' | paste -sd x)\""]
    stdout: StdioCollector {
      onStreamFinished: {
        var o = ({}), l = text.split("\n")
        for (var i = 0; i < l.length; i++) { var k = l[i].indexOf("="); if (k > 0) o[l[i].slice(0, k)] = l[i].slice(k + 1).trim() }
        svc.info = o
      }
    }
  }

  // Profils et thème : tout passe par la CLI liquid-glass.
  function setOpt(k, v) { Quickshell.execDetached(["liquid-glass", "set", "linux." + k, String(v)]) }
  function pickStyle(id) { closeAll(); menuOpen = false; Quickshell.execDetached(["liquid-glass", "profile", id]) }
  Loader {
    // ShellIpc vit dans qs.Commons : chargé à part pour que le reste du plugin
    // reste testable seul avec `qs -p`.
    active: svc.ex
    source: "LinuxIpc.qml"
    onLoaded: item.service = svc
  }

  // ------------------------------------------------------------ fenêtres
  function run(cmd) { Quickshell.execDetached(["sh", "-c", cmd]) }
  // Claude Code (même lanceur que la barre du Mac : sélecteur d'agents d'Omarchy).
  function claude() { closeAll(); menuOpen = false; run("omarchy-agent --pick") }

  // LG_SCREEN (tests) : n'afficher que sur cette sortie.
  readonly property var screens: {
    var only = String(Quickshell.env("LG_SCREEN") || ""), all = Quickshell.screens
    if (only === "") return all
    var out = []
    for (var i = 0; i < all.length; i++) if (all[i].name === only) out.push(all[i])
    return out
  }
  readonly property bool testing: String(Quickshell.env("LG_SCREEN") || "") !== ""
  readonly property bool testingNoExtras: String(Quickshell.env("LG_NO_EXTRAS") || "") !== ""
  // Clavier exclusif pour les volets, sauf pendant les tests (pour ne rien voler à la session).
  function kbd(exclusive) { return testing ? WlrKeyboardFocus.None : (exclusive ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.OnDemand) }
  readonly property var mainScreen: screens.length ? [screens[0]] : []
  readonly property var primaryScreen: mainScreen.length ? mainScreen[0] : null

  // Styles blanc / sombre / jouet / violet / expressive (end4-pC, Serpantinum, rices TikTok)
  Variants {
    model: svc.style === "gouts" && svc.showWidgets && svc.opt("gouts_planets", true) !== false ? svc.mainScreen : []
    delegate: Component { GoutsDesk { required property var modelData; screen: modelData; service: svc } }
  }
  Variants {
    model: svc.isEspace ? svc.screens : []
    delegate: Component { EspaceBar { required property var modelData; screen: modelData; service: svc } }
  }
  Variants {
    model: String(svc.opt("wall_wipe", "on")) !== "off" && !svc.testing ? svc.screens : []
    delegate: Component { WallWipe { required property var modelData; screen: modelData; service: svc } }
  }
  Variants {
    model: String(svc.opt("live_wall", "off")) !== "off" && !svc.isCosmos ? svc.screens : []
    delegate: Component { LiveWall { required property var modelData; screen: modelData; service: svc } }
  }
  // Widgets en plus, par style (fractions de l'écran ; chaque carte se déplace à la souris).
  // Chacune se masque dans Réglages → Propre à <style> : <style>_card_<id> = false.
  readonly property var extraShown: (extraCards[style] || []).filter(function(c) { return opt(style + "_card_" + c[0], true) !== false })
  readonly property var extraCards: ({
    espace: [["weather", 0.025, 0.09], ["moon", 0.025, 0.33], ["calendar", 0.025, 0.5], ["gauges", 0.79, 0.27]],
    foret: [["clock", 0.04, 0.12], ["weather", 0.04, 0.36], ["calendar", 0.8, 0.12], ["todo", 0.8, 0.46], ["music", 0.4, 0.84]],
    ruban: [["calendar", 0.03, 0.13], ["gauges", 0.79, 0.37], ["quote", 0.79, 0.12]],
    violet: [["moon", 0.03, 0.8], ["quote", 0.8, 0.8]]
  })
  Variants {
    model: svc.showWidgets && svc.extraShown.length > 0 && !svc.testingNoExtras ? svc.mainScreen : []
    delegate: Component { DeskExtras { required property var modelData; screen: modelData; service: svc; cards: svc.extraShown } }
  }
  Variants {
    model: svc.isIle ? svc.screens : []
    delegate: Component { IleBar { required property var modelData; screen: modelData; service: svc } }
  }
  Variants {
    model: svc.isIle ? svc.mainScreen : []
    delegate: Component { IleDesk { required property var modelData; screen: modelData; service: svc } }
  }
  Variants {
    model: svc.isIle && svc.opt("ile_dock", true) !== false ? svc.mainScreen : []
    delegate: Component { IleDock { required property var modelData; screen: modelData; service: svc } }
  }
  Variants {
    model: svc.isIle ? svc.mainScreen : []
    delegate: Component { IlePanels { required property var modelData; screen: modelData; service: svc } }
  }
  Variants {
    model: svc.isIle ? svc.mainScreen : []
    delegate: Component { IleNotch { required property var modelData; screen: modelData; service: svc } }
  }
  Variants {
    model: svc.isInfini ? svc.mainScreen : []
    delegate: Component { InfiniDesk { required property var modelData; screen: modelData; service: svc } }
  }
  Variants {
    model: svc.isHud ? svc.mainScreen : []
    delegate: Component { HudDesk { required property var modelData; screen: modelData; service: svc } }
  }
  Variants {
    model: svc.isCosmos ? svc.mainScreen : []
    delegate: Component { CosmosDesk { required property var modelData; screen: modelData; service: svc } }
  }
  Variants {
    model: svc.style === "espace" && svc.showWidgets ? svc.mainScreen : []
    delegate: Component { EspaceDesk { required property var modelData; screen: modelData; service: svc } }
  }
  Variants {
    model: svc.isRuban ? svc.screens : []
    delegate: Component { RubanBar { required property var modelData; screen: modelData; service: svc } }
  }
  Variants {
    model: svc.isRuban && svc.showWidgets ? svc.mainScreen : []
    delegate: Component { RubanDesk { required property var modelData; screen: modelData; service: svc } }
  }
  Variants {
    model: svc.isDistro ? svc.screens : []
    delegate: Component { DistroPanel { required property var modelData; screen: modelData; service: svc } }
  }
  Variants {
    model: svc.wall ? svc.mainScreen : []
    delegate: Component { SombreWall { required property var modelData; screen: modelData; service: svc } }
  }
  Variants {
    model: svc.classic && !svc.wall ? svc.mainScreen : []
    delegate: Component { MusicScene { required property var modelData; screen: modelData; service: svc } }
  }
  Variants {
    model: svc.classic && !svc.wall && !svc.textBar && svc.showWidgets ? svc.mainScreen : []
    delegate: Component { ExDesktop { required property var modelData; screen: modelData; service: svc } }
  }
  Variants {
    model: svc.textBar && svc.showWidgets ? svc.mainScreen : []
    delegate: Component { BlancDesk { required property var modelData; screen: modelData; service: svc } }
  }
  Variants {
    model: svc.textBar ? svc.screens : []
    delegate: Component { BlancBar { required property var modelData; screen: modelData; service: svc } }
  }
  Variants {
    model: svc.toyDock ? svc.screens : []
    delegate: Component { JouetDock { required property var modelData; screen: modelData; service: svc } }
  }
  Variants {
    model: svc.classic && !svc.textBar && !svc.toyDock ? svc.screens : []
    delegate: Component { ExBar { required property var modelData; screen: modelData; service: svc } }
  }

  // Windows : barre des tâches, menu Démarrer, volets, Paramètres
  Variants {
    model: svc.win11 ? svc.screens : []
    delegate: Component { WinTaskbar { required property var modelData; screen: modelData; service: svc } }
  }
  Variants {
    model: svc.win11 && svc.showWidgets && svc.opt("windows_icons", true) !== false ? svc.mainScreen : []
    delegate: Component { WinDesktop { required property var modelData; screen: modelData; service: svc } }
  }
  LazyLoader { active: svc.win11 && (svc.launcherOpen || svc.panel !== ""); WinFlyouts { service: svc; screen: svc.primaryScreen } }
  LazyLoader { active: svc.win11 && svc.menuOpen && !svc.testing; WinSettings { service: svc } }
  LazyLoader {
    // Tests : la même page dans une couche sur la sortie de test (pas de fenêtre à placer).
    active: svc.win11 && svc.menuOpen && svc.testing
    PanelWindow {
      screen: svc.primaryScreen
      color: "transparent"
      anchors { top: true; bottom: true; left: true; right: true }
      exclusionMode: ExclusionMode.Ignore
      WlrLayershell.layer: WlrLayer.Top
      WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
      WinSettingsBody { width: 980; height: 640; anchors.centerIn: parent; service: svc }
    }
  }

  // Mono (caelestia / sergioqtz) : barre verticale, tableau de bord qui descend
  Variants {
    model: svc.isMono ? svc.screens : []
    delegate: Component { MonoBar { required property var modelData; screen: modelData; service: svc } }
  }
  LazyLoader { active: svc.isMono && svc.panel !== ""; MonoDash { service: svc; screen: svc.primaryScreen } }
  LazyLoader { active: svc.isMono && !svc.testingNoExtras && svc.opt("mono_edge", true) !== false; MonoEdge { service: svc; screen: svc.primaryScreen } }
  LazyLoader { active: svc.isMono && svc.opt("mono_unlock", true) !== false; MonoUnlock { service: svc; screen: svc.primaryScreen } }

  // Forêt (ilyamiro c01) : barre en puces, volets musique / horloge / batterie
  Variants {
    model: svc.isForet ? svc.screens : []
    delegate: Component { ForetBar { required property var modelData; screen: modelData; service: svc } }
  }
  LazyLoader { active: svc.isForet && svc.panel !== ""; ForetPanels { service: svc; screen: svc.primaryScreen } }

  // Lanceur et centre de réglages de chaque style (sauf Windows, qui a les siens)
  LazyLoader { active: svc.panel === "rice"; RiceMenu { service: svc; screen: svc.primaryScreen } }
  LazyLoader { active: svc.isEspace && svc.panel === "dash"; EspaceDash { service: svc; screen: svc.primaryScreen } }
  LazyLoader { active: svc.isEspace && svc.panel === "net"; EspaceNet { service: svc; screen: svc.primaryScreen } }
  LazyLoader { active: svc.isEspace && svc.panel === "stats"; EspaceStats { service: svc; screen: svc.primaryScreen } }
  LazyLoader { active: svc.isRuban && svc.launcherOpen; RubanMenu { service: svc; screen: svc.primaryScreen } }
  LazyLoader { active: svc.isCosmos && svc.launcherOpen; CosmosMoon { service: svc; screen: svc.primaryScreen } }
  LazyLoader { active: !svc.win11 && !svc.isDistro && !svc.isRuban && !svc.isCosmos && svc.launcherOpen; Launcher { service: svc; screen: svc.primaryScreen } }
  LazyLoader { active: svc.isDistro && svc.launcherOpen; DistroMenu { service: svc; screen: svc.primaryScreen } }
  LazyLoader { active: svc.keysOpen; KeySheet { service: svc; screen: svc.primaryScreen } }
  LazyLoader { active: !svc.win11 && svc.menuOpen; StyleMenu { service: svc; screen: svc.primaryScreen } }

  LazyLoader {
    active: svc.wallsOpen
    WallCarousel { service: svc; screen: svc.primaryScreen }
  }
}
