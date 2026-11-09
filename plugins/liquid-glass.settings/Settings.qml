import QtQuick
import "Mac.js" as Mac
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Bluetooth
import Quickshell.Services.Pipewire
import Quickshell.Services.UPower
import qs.Commons
import qs.Commons as Commons
import qs.Ui
import "T.js" as T

// ============================================================================
// Liquid Glass — Réglages Système (fenêtre de verre façon macOS Tahoe).
// Barre latérale : recherche, carte du compte, pages groupées à icônes de
// couleur ; en-tête avec retour (‹) et titre de la page.
// Lit ~/.config/liquid-glass/config.json (relu à chaud) et écrit via
// `liquid-glass set section.clé valeur` ; les réglages système (Wi-Fi,
// Bluetooth, son, luminosité, fond d'écran…) passent par leurs outils.
// Ouverture : omarchy-shell liquid-glass.settings toggle
//             omarchy-shell shell summon liquid-glass.settings '{"page":"lock"}'
// ============================================================================
Item {
  id: root

  property var shell: null
  property var manifest: null
  property bool opened: false
  property string page: "appearance"
  property var history: []
  property string search: ""

  readonly property string uiFont: val("appearance.font_ui", "Inter")
  readonly property string iconFont: Style.font.family
  readonly property color fg: Commons.Color.menu.text
  readonly property color accent: Commons.Color.accent
  readonly property bool dark: Commons.Color.background.hslLightness < 0.5
  readonly property string home: Quickshell.env("HOME")
  function g(cp) { return String.fromCodePoint(cp) }

  // ------------------------------------------------------------- config
  property var cfg: ({})
  FileView {
    path: root.home + "/.config/liquid-glass/config.json"
    watchChanges: true
    onFileChanged: reload()
    onLoaded: { try { root.cfg = JSON.parse(text()) } catch (e) {} }
  }
  function val(path, def) {
    var parts = path.split("."), v = cfg
    for (var i = 0; i < parts.length; i++) { if (v === undefined || v === null) return def; v = v[parts[i]] }
    return v === undefined || v === null ? def : v
  }

  // Écritures sérialisées : une seule commande à la fois, la dernière valeur gagne.
  property var queue: []
  function set(key, value) {
    // « off », « on », « » … seraient lus comme booléens : on les met entre guillemets.
    var raw = Array.isArray(value) ? JSON.stringify(value)
            : (typeof value === "string" && /^(on|off|yes|no|true|false|)$/i.test(value) ? JSON.stringify(value) : String(value))
    var q = queue.filter(function(e) { return e[0] !== key })
    q.push([key, raw])
    queue = q
    var parts = key.split("."), c = JSON.parse(JSON.stringify(cfg))
    if (!c[parts[0]]) c[parts[0]] = {}
    c[parts[0]][parts[1]] = value
    cfg = c
    pump()
  }
  function pump() {
    if (writer.running || queue.length === 0) return
    var e = queue[0]
    queue = queue.slice(1)
    busy = true
    writer.command = ["liquid-glass", "set", e[0], e[1]]
    writer.running = true
  }
  property bool busy: false
  Process {
    id: writer
    onExited: { root.busy = false; root.pump() }
  }
  // Commande système, puis relecture de l'état.
  Process { id: runner; onExited: root.refresh() }
  function run(argv) { runner.command = argv; runner.running = true }
  function launch(argv) { Util.execArgv(argv) }

  // ------------------------------------------------------------- pages
  // [id, titre, glyphe, couleur de l'icône, groupe]
  // Les mêmes Réglages sur tous les bureaux. Sur le bureau Linux, la page du style
  // actif passe en tête (« Infini », « Debian »…) et les pages propres au Mac
  // (barre des menus, Dock, île, coins actifs, verre…) sont masquées.
  readonly property bool linuxDesk: val("profile.active", "mac") === "linux"
  readonly property string linuxStyle: String(val("linux.style", "blanc"))
  readonly property var styleNames: ({ blanc: T.t("Blanc"), sombre: T.t("Sombre"), jouet: T.t("Jouet"), violet: "Violet", expressive: "Expressive",
    windows: "Windows", mono: "Mono", foret: T.t("Forêt"), ruban: T.t("Rubans"), espace: T.t("Espace"), cosmos: "Cosmos", ile: T.t("Île"),
    hud: "7JOKS", infini: T.t("Infini"), gouts: T.t("Mes goûts"), debian: "Debian", fedora: "Fedora", mint: "Mint", kali: "Kali", arch: "Arch" })
  readonly property var styleColors: ({ blanc: "#8e8e93", sombre: "#1c1c1e", jouet: "#ff6fb5", violet: "#8e6cf0", expressive: "#6750a4",
    windows: "#0078d4", mono: "#3a3a3c", foret: "#4f8a5b", ruban: "#ff453a", espace: "#0a84ff", cosmos: "#5ac8fa", ile: "#a39e93",
    hud: "#636366", infini: "#e8a3b4", gouts: "#ff9f0a", debian: "#d70a53", fedora: "#3c6eb4", mint: "#87cf3e", kali: "#367bf0", arch: "#1793d1" })
  readonly property var macOnly: ["appearance", "intelligence", "control", "desktop", "menubar", "shortcuts", "corners", "alcove"]
  // Profil connu après l'ouverture (ou bascule Mac ↔ Linux) : pas de page Mac affichée sur Linux.
  onLinuxDeskChanged: if (linuxDesk && macOnly.indexOf(page) >= 0) { history = []; page = "linux" }
  readonly property var pages: {
    if (!linuxDesk) return allPages
    var head = [["linux", styleNames[linuxStyle] || T.t("Bureau Linux"), 0xF033D, styleColors[linuxStyle] || "#2f9e9e", -1]]
    return head.concat(allPages.filter(function(p) { return p[0] !== "linux" && macOnly.indexOf(p[0]) < 0 }))
  }
  readonly property var allPages: [
    ["wifi", "Wi-Fi", 0xF05A9, "#0a84ff", 0],
    ["bluetooth", "Bluetooth", 0xF00AF, "#0a84ff", 0],
    ["network", T.t("Réseau"), 0xF0318, "#0a84ff", 0],
    ["battery", T.t("Batterie"), 0xF0079, "#30d158", 0],
    ["general", T.t("Général"), 0xF0493, "#8e8e93", 1],
    ["accessibility", T.t("Accessibilité"), 0xF02E6, "#0a84ff", 1],
    ["appearance", T.t("Apparence"), 0xF050E, "#1c1c1e", 1],
    ["intelligence", T.t("Claude (Siri)"), 0xF0674, "#bf5af2", 1],
    ["control", T.t("Centre de contrôle"), 0xF0521, "#8e8e93", 1],
    ["desktop", T.t("Bureau et Dock"), 0xF0379, "#1c1c1e", 1],
    ["displays", T.t("Écrans"), 0xF00DF, "#0a84ff", 1],
    ["menubar", T.t("Barre des menus"), 0xF035C, "#1c1c1e", 1],
    ["shortcuts", T.t("Raccourcis d'apps"), 0xF003B, "#5e5ce6", 1],
    ["wallpaper", T.t("Fond d'écran"), 0xF02E9, "#32ade6", 1],
    ["linux", T.t("Bureau Linux"), 0xF033D, "#2f9e9e", 1],
    ["notifications", "Notifications", 0xF009A, "#ff3b30", 2],
    ["sound", T.t("Son"), 0xF057E, "#ff2d55", 2],
    ["focus", T.t("Concentration"), 0xF0594, "#5e5ce6", 2],
    ["music", T.t("Musique et paroles"), 0xF075A, "#ff375f", 2],
    ["lock", T.t("Écran verrouillé"), 0xF033E, "#1c1c1e", 3],
    ["touchid", T.t("Touch ID et mot de passe"), 0xF0237, "#ff375f", 3],
    ["users", T.t("Utilisateurs et groupes"), 0xF0849, "#0a84ff", 3],
    ["language", T.t("Langue et région"), 0xF05CA, "#0a84ff", 3],
    ["keyboard", T.t("Clavier"), 0xF030C, "#8e8e93", 4],
    ["mouse", T.t("Souris"), 0xF037D, "#8e8e93", 4],
    ["trackpad", "Trackpad", 0xF0A2E, "#8e8e93", 4],
    ["corners", T.t("Coins actifs"), 0xF0294, "#8e8e93", 4],
    ["printers", T.t("Imprimantes et scanners"), 0xF042A, "#8e8e93", 4],
    ["alcove", "Alcove", 0xF0402, "#1c1c1e", 5],
    ["klack", "Klack", 0xF030C, "#ff9f0a", 5],
    ["about", T.t("À propos"), 0xF02FD, "#8e8e93", 6]
  ]
  function pageInfo(id) { for (var i = 0; i < pages.length; i++) if (pages[i][0] === id) return pages[i]; return pages[0] }
  readonly property var filteredPages: {
    var q = search.trim().toLowerCase()
    if (q === "") return pages
    return pages.filter(function(p) { return p[1].toLowerCase().indexOf(q) !== -1 || p[0].indexOf(q) !== -1 })
  }
  function go(id) {
    if (id === page) return
    var h = history.slice(); h.push(page); if (h.length > 30) h.shift()
    history = h
    page = id
  }
  function back() {
    if (history.length === 0) return
    var h = history.slice(); page = h.pop(); history = h
  }
  function step(d) {
    var list = filteredPages, i = 0
    for (var k = 0; k < list.length; k++) if (list[k][0] === page) i = k
    var n = list[(i + d + list.length) % list.length]
    if (n) go(n[0])
  }

  // ------------------------------------------------------------- état système
  property bool wifiOn: true
  property string ssid: ""
  property var wifiList: []
  property var devices: []
  property bool dnd: false
  property bool nightlight: false
  property real brightness: 1.0
  property string focusMode: "off"
  property string currentBg: ""
  property var backgrounds: []
  property string fullName: ""
  property string userName: Quickshell.env("USER") || ""
  property int faceVersion: 0
  property bool hasFace: false
  property var fonts: []

  function refresh() {
    wifiProc.running = true
    barProc.running = true
    devProc.running = true
    dndProc.running = true
    nightProc.running = true
    brightProc.running = true
    focusProc.running = true
    bgProc.running = true
    faceProc.running = true
  }
  onOpenedChanged: if (opened) { refresh(); if (!nameProc.ran) { nameProc.running = true; nameProc.ran = true } }

  Process {
    id: wifiProc
    command: ["sh", "-c", "nmcli -t -f WIFI radio; nmcli -t -f NAME,TYPE connection show --active 2>/dev/null | grep ':802-11-wireless$' | head -1 | sed 's/:802-11-wireless$//'; nmcli -t -f IN-USE,SSID,SIGNAL,SECURITY device wifi list --rescan no 2>/dev/null | head -14"]
    stdout: StdioCollector {
      onStreamFinished: {
        var lines = text.split("\n")
        root.wifiOn = (lines[0] || "").trim() === "enabled"
        root.ssid = (lines[1] || "").trim()
        var seen = {}, list = []
        for (var i = 2; i < lines.length; i++) {
          var f = lines[i].split(":")
          if (f.length < 3 || !f[1] || seen[f[1]]) continue
          seen[f[1]] = true
          list.push({ ssid: f[1], signal: parseInt(f[2]) || 0, secure: (f[3] || "") !== "", current: f[0] === "*" })
        }
        root.wifiList = list
      }
    }
  }
  Process {
    id: devProc
    command: ["nmcli", "-t", "-f", "DEVICE,TYPE,STATE,CONNECTION", "device", "status"]
    stdout: StdioCollector {
      onStreamFinished: {
        var out = []
        text.trim().split("\n").forEach(function(l) {
          var f = l.split(":")
          if (f.length >= 3 && (f[1] === "wifi" || f[1] === "ethernet")) out.push({ dev: f[0], type: f[1], state: f[2], conn: f[3] || "" })
        })
        root.devices = out
      }
    }
  }
  Process { id: dndProc; command: ["omarchy-shell", "notifications", "isDnd"]; stdout: StdioCollector { onStreamFinished: root.dnd = text.trim() === "on" } }
  Process { id: nightProc; command: ["omarchy-shell", "nightlight", "status"]; stdout: StdioCollector { onStreamFinished: { try { root.nightlight = JSON.parse(text).enabled === true } catch (e) {} } } }
  Process {
    id: brightProc
    command: ["brightnessctl", "-m"]
    stdout: StdioCollector { onStreamFinished: { var p = parseFloat(text.trim().split(",")[3]); if (isFinite(p)) root.brightness = p / 100 } }
  }
  Process { id: focusProc; command: ["liquid-glass", "focus", "status"]; stdout: StdioCollector { onStreamFinished: { try { root.focusMode = JSON.parse(text).mode } catch (e) {} } } }
  // Vidéos (fonds animés) : vignette = image extraite par « liquid-glass
  // animated-wallpapers » dans ~/.cache/liquid-glass/posters/<nom>.jpg.
  function isVideo(p) { return /\.(mp4|webm|mkv|mov)$/i.test(String(p || "")) }
  // Catégorie d'un fond : préfixe du nom pour la collection (liquid-glass wallpapers),
  // « dyn » pour les vidéos, « mac » pour le reste (fonds du thème, vos images).
  readonly property var bgCats: [["all", T.t("Tous")], ["macos", "macOS"], ["mac", "Mac"], ["dyn", T.t("Dynamiques")], ["anime", "Anime"], ["edit", "Edit"],
                                 ["basket", "Basket"], ["voiture", T.t("Voitures")], ["ville", T.t("Villes")], ["sakura", T.t("Cerisiers")],
                                 ["ascii", "ASCII"], ["minimal", "Minimal"], ["abstract", T.t("Abstrait")], ["fruit", T.t("Fruits")], ["genere", T.t("Générés")]]
  readonly property var bgCollection: bgCats.slice(4).map(function(c) { return c[0] })
  property string bgFilter: "all"
  // Les vignettes arrivent par paquets de 48 : ouvrir l'onglet ne décode pas 300 images.
  property int bgLimit: 48
  onBgFilterChanged: bgLimit = 48
  function bgCat(p) {
    if (root.isVideo(p)) return "dyn"
    if (String(p).split("/").pop().indexOf("os-") === 0) return "macos"
    var pre = String(p).split("/").pop().split("-")[0]
    return root.bgCollection.indexOf(pre) !== -1 ? pre : "mac"
  }
  function bgCount(c) { return c === "all" ? backgrounds.length : backgrounds.filter(function(p) { return root.bgCat(p) === c }).length }
  readonly property var shownBackgrounds: {
    if (bgFilter !== "all") return backgrounds.filter(function(p) { return root.bgCat(p) === root.bgFilter }).sort(function(a, b) { return root.osRank(b) - root.osRank(a) })
    // Tous : Mac et Dynamiques d'abord, puis la collection par catégorie.
    var order = bgCats.map(function(c) { return c[0] })
    return backgrounds.slice().sort(function(a, b) { return order.indexOf(root.bgCat(a)) - order.indexOf(root.bgCat(b)) || root.osRank(b) - root.osRank(a) })
  }
  // macOS : du plus récent (27) au plus ancien (10.0).
  function osRank(p) { var m = /\/os-(\d+(?:\.\d+)?)-/.exec(String(p)); return m ? parseFloat(m[1]) : 0 }
  function bgThumb(p) {
    if (!p) return ""
    if (String(p).indexOf("/.local/share/liquid-glass/wallpapers/") !== -1)
      return "file://" + root.home + "/.cache/liquid-glass/thumbs/" + String(p).split("/").pop()
    if (!root.isVideo(p)) return "file://" + p
    return "file://" + root.home + "/.cache/liquid-glass/posters/" + p.split("/").pop().replace(/\.[^.]+$/, "") + ".jpg"
  }
  Process {
    id: bgProc
    command: ["sh", "-c", "readlink -f \"$HOME/.local/state/omarchy/current/background\"; t=$(cat \"$HOME/.local/state/omarchy/current/theme.name\" 2>/dev/null); d=$(omarchy-theme-dir \"$t\" 2>/dev/null || omarchy theme dir \"$t\" 2>/dev/null); case \"$t\" in liquid-glass*) d2=\"$(omarchy-theme-dir liquid-glass 2>/dev/null)/backgrounds $(omarchy-theme-dir liquid-glass-dark 2>/dev/null)/backgrounds\";; esac; find -L \"$d/backgrounds\" $d2 \"$HOME/.config/omarchy/backgrounds/$t\" \"$HOME/Pictures/Wallpapers\" \"$HOME/Pictures\" -maxdepth 1 -type f \\( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' -o -iname '*.mp4' -o -iname '*.webm' \\) 2>/dev/null | xargs -r -d '\\n' readlink -f | sort -u | head -600"]
    stdout: StdioCollector {
      onStreamFinished: {
        var l = text.trim().split("\n").filter(function(x) { return x !== "" })
        root.currentBg = l.length ? l[0] : ""
        root.backgrounds = l.slice(1)
      }
    }
  }
  Process {
    id: nameProc
    property bool ran: false
    command: ["sh", "-c", "getent passwd \"$USER\" | cut -d: -f5 | cut -d, -f1"]
    stdout: StdioCollector { onStreamFinished: root.fullName = text.trim() }
  }
  Process { id: faceProc; command: ["sh", "-c", "test -f \"$HOME/.face\" && echo yes"]; stdout: StdioCollector { onStreamFinished: { root.hasFace = text.trim() === "yes"; root.faceVersion++ } } }
  Process {
    id: fontProc
    command: ["sh", "-c", "fc-list : family | cut -d, -f1 | grep -v -i -E 'nerd|emoji|symbol|mono' | sort -u | head -200"]
    stdout: StdioCollector { onStreamFinished: root.fonts = text.trim().split("\n").filter(function(x) { return x !== "" }) }
  }
  readonly property string displayName: fullName || (userName.charAt(0).toUpperCase() + userName.slice(1))

  // Bluetooth et son : services Quickshell.
  readonly property var batDev: UPower.displayDevice
  readonly property bool hasBat: !!(batDev && batDev.isPresent)
  readonly property var bt: Bluetooth.defaultAdapter
  readonly property var sink: Pipewire.defaultAudioSink
  PwObjectTracker { objects: root.sink ? [root.sink] : [] }
  readonly property var sinks: {
    var out = [], ns = Pipewire.nodes ? Pipewire.nodes.values : []
    for (var i = 0; i < ns.length; i++) if (ns[i].isSink && !ns[i].isStream && ns[i].audio) out.push(ns[i])
    return out
  }
  Timer { id: brightApply; interval: 40; property int pct: 100; onTriggered: Util.execArgv(["omarchy-brightness-display", "--no-osd", pct + "%"]) }

  // ------------------------------------------------------------- cycle de vie
  function open(payloadJson) {
    opened = true
    try {
      var p = JSON.parse(payloadJson || "{}")
      if (typeof p.page === "string") { history = []; page = pageInfo(p.page)[0] }
      else if (linuxDesk && macOnly.indexOf(page) >= 0) { history = []; page = "linux" }
      else if (typeof p.page === "number" && pages[p.page]) { history = []; page = pages[p.page][0] }
    } catch (e) {}
  }
  function close() { opened = false }
  function dismiss() {
    opened = false
    if (shell && typeof shell.hide === "function") shell.hide((manifest && manifest.id) || "liquid-glass.settings")
  }

  ShellIpc {
    target: "liquid-glass.settings"
    function toggle(): void { if (root.opened) root.dismiss(); else if (root.shell) root.shell.summon((root.manifest && root.manifest.id) || "liquid-glass.settings", "") }
    function open(): void { if (root.shell) root.shell.summon((root.manifest && root.manifest.id) || "liquid-glass.settings", "") }
    function openPage(id: string): void { if (root.shell) root.shell.summon((root.manifest && root.manifest.id) || "liquid-glass.settings", JSON.stringify({ page: id })) }
  }

  OverlayWindow {
    id: win
    shown: root.opened
    WlrLayershell.namespace: "liquid-glass-settings"

    Item {
      id: keys
      anchors.fill: parent
      focus: true
      Keys.onPressed: function(ev) {
        if (ev.key === Qt.Key_Escape) { if (root.search !== "") root.search = ""; else root.dismiss() }
        else if (ev.key === Qt.Key_Down || ev.key === Qt.Key_Tab) root.step(1)
        else if (ev.key === Qt.Key_Up || ev.key === Qt.Key_Backtab) root.step(-1)
        else if (ev.key === Qt.Key_Left && (ev.modifiers & Qt.AltModifier)) root.back()
        else if (ev.key === Qt.Key_F && (ev.modifiers & Qt.ControlModifier)) searchInput.forceActiveFocus()
        else return
        ev.accepted = true
      }
    }
    // Pas de voile sur l'écran (macOS n'en met pas) : un voile au-dessus du seuil
    // ignore_alpha ferait flouter tout le bureau par Hyprland.
    MouseArea { anchors.fill: parent; onClicked: root.dismiss() }

    Rectangle {
      id: card
      // Centrée à l'ouverture ; se déplace en tirant la bande du haut (comme la
      // barre de titre d'une fenêtre Mac).
      x: Math.round((parent.width - width) / 2)
      y: Math.round((parent.height - height) / 2)
      width: Math.min(parent.width - 40, Style.space(Mac.settings.width))
      height: Math.min(parent.height - 40, Style.space(560))
      radius: Style.space(24)
      // Verre : fond translucide (flouté par Hyprland), liseré clair.
      color: Qt.rgba(Commons.Color.menu.background.r, Commons.Color.menu.background.g, Commons.Color.menu.background.b, root.dark ? 0.74 : 0.7)
      border.width: 1
      border.color: Qt.rgba(1, 1, 1, root.dark ? 0.14 : 0.55)
      scale: win.contentRevealed ? 1 : 0.86
      opacity: win.contentRevealed ? 1 : 0
      Behavior on scale { SpringAnimation { spring: 3.6; damping: 0.3; epsilon: 0.002 } }
      Behavior on opacity { NumberAnimation { duration: 180 } }
      MouseArea { anchors.fill: parent }

      // Bande de titre : glisser pour déplacer la fenêtre (les clics passent aux boutons).
      Item {
        z: 50
        width: parent.width; height: Style.space(36)
        DragHandler {
          target: card
          cursorShape: Qt.ClosedHandCursor
          xAxis.minimum: 0; xAxis.maximum: card.parent.width - card.width
          yAxis.minimum: 0; yAxis.maximum: card.parent.height - Style.space(60)
        }
      }

      // ---- Barre latérale (panneau de verre inséré, comme Tahoe)
      Rectangle {
        id: sidebar
        x: Style.space(8); y: Style.space(8)
        width: Style.space(Mac.sidebar.width - 15)
        height: parent.height - Style.space(16)
        radius: Style.space(18)
        color: Qt.rgba(root.fg.r, root.fg.g, root.fg.b, root.dark ? 0.06 : 0.05)
        border.width: 1
        border.color: Qt.rgba(1, 1, 1, root.dark ? 0.06 : 0.4)

        Row {
          x: Style.space(14); y: Style.space(14)
          spacing: Style.space(8)
          Repeater {
            model: ["#ff5f57", "#febc2e", "#28c840"]
            delegate: Rectangle {
              required property var modelData
              required property int index
              width: Style.space(12); height: width; radius: width / 2
              color: modelData
              border.width: 1; border.color: Qt.rgba(0, 0, 0, 0.12)
              MouseArea { anchors.fill: parent; anchors.margins: -3; cursorShape: Qt.PointingHandCursor; onClicked: if (index === 0) root.dismiss() }
            }
          }
        }

        // Recherche.
        Rectangle {
          id: searchBox
          x: Style.space(10); y: Style.space(40)
          width: parent.width - Style.space(20); height: Style.space(28)
          radius: height / 2
          color: Qt.rgba(root.fg.r, root.fg.g, root.fg.b, 0.07)
          border.width: searchInput.activeFocus ? 2 : 0
          border.color: root.accent
          Text { id: sIcon; x: Style.space(9); anchors.verticalCenter: parent.verticalCenter; textFormat: Text.PlainText; text: root.g(0xF0349); font.family: root.iconFont; font.pixelSize: Style.space(13); color: root.fg; opacity: 0.5 }
          TextInput {
            id: searchInput
            anchors.left: sIcon.right; anchors.leftMargin: Style.space(6)
            anchors.right: parent.right; anchors.rightMargin: Style.space(10)
            anchors.verticalCenter: parent.verticalCenter
            text: root.search
            onTextChanged: { root.search = text; if (text !== "" && root.filteredPages.length) root.page = root.filteredPages[0][0] }
            font.family: root.uiFont; font.pixelSize: Style.space(12.5)
            color: root.fg
            clip: true
            Keys.onEscapePressed: { text = ""; keys.forceActiveFocus() }
            Keys.onReturnPressed: keys.forceActiveFocus()
            Text { visible: !searchInput.text; anchors.verticalCenter: parent.verticalCenter; text: T.t("Rechercher"); font: searchInput.font; color: root.fg; opacity: 0.4 }
          }
        }

        Flickable {
          id: nav
          x: Style.space(8)
          y: Style.space(78)
          width: parent.width - Style.space(16)
          height: parent.height - y - Style.space(28)
          contentHeight: navCol.implicitHeight
          clip: true
          boundsBehavior: Flickable.DragOverBounds
          Behavior on contentY { enabled: !nav.dragging && !nav.flicking; NumberAnimation { duration: 320; easing.type: Easing.OutCubic } }

          // Fait défiler la barre latérale pour garder l'entrée active visible.
          property Item activeItem: null
          onHeightChanged: Qt.callLater(reveal, activeItem)
          onContentHeightChanged: Qt.callLater(reveal, activeItem)
          function reveal(item) {
            if (!item || typeof item.mapToItem !== "function" || nav.height < Style.space(120) || navCol.implicitHeight <= 0) return
            // Première page (la page du thème sur Linux) : tout en haut, carte du compte comprise.
            if (item.parent && item.parent.index === 0) { nav.contentY = 0; return }
            var p = item.mapToItem(navCol, 0, 0)
            var maxY = Math.max(0, navCol.implicitHeight - nav.height)
            var pad = Style.space(12)
            if (p.y < nav.contentY + pad) nav.contentY = Math.max(0, p.y - pad)
            else if (p.y + item.height > nav.contentY + nav.height - pad) nav.contentY = Math.min(maxY, p.y + item.height - nav.height + pad)
          }

          Column {
            id: navCol
            width: nav.width
            spacing: Style.space(1)

            // Carte du compte.
            Rectangle {
              width: parent.width; height: Style.space(52)
              radius: Style.space(12)
              visible: root.search === ""
              color: root.page === "users" ? root.accent : (accMouse.containsMouse ? Qt.rgba(root.fg.r, root.fg.g, root.fg.b, 0.07) : "transparent")
              Avatar { id: accAvatar; x: Style.space(6); anchors.verticalCenter: parent.verticalCenter; side: Style.space(36) }
              Column {
                anchors.left: accAvatar.right; anchors.leftMargin: Style.space(9)
                anchors.verticalCenter: parent.verticalCenter
                Text { textFormat: Text.PlainText; text: root.displayName; font.family: root.uiFont; font.pixelSize: Style.space(13); font.weight: Font.DemiBold; color: root.page === "users" ? "white" : root.fg }
                Text { textFormat: Text.PlainText; text: T.t("Compte local"); font.family: root.uiFont; font.pixelSize: Style.space(11); color: root.page === "users" ? "white" : root.fg; opacity: 0.6 }
              }
              MouseArea { id: accMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.go("users") }
            }

            Repeater {
              model: root.filteredPages
              delegate: Column {
                id: navEntry
                required property var modelData
                required property int index
                readonly property bool newGroup: root.search === "" && (index === 0 || root.filteredPages[index - 1][4] !== modelData[4])
                width: navCol.width
                Item { width: 1; height: navEntry.newGroup ? Style.space(10) : 0 }
                Rectangle {
                  id: navItem
                  readonly property bool current: root.page === navEntry.modelData[0]
                  onCurrentChanged: if (current) { nav.activeItem = navItem; Qt.callLater(nav.reveal, navItem) }
                  Component.onCompleted: if (current) { nav.activeItem = navItem; Qt.callLater(nav.reveal, navItem) }
                  width: parent.width
                  height: Style.space(Mac.sidebar.row)
                  radius: Style.space(Mac.sidebar.selRadius)
                  color: current ? root.accent : (navMouse.containsMouse ? Qt.rgba(root.fg.r, root.fg.g, root.fg.b, 0.07) : "transparent")
                  Behavior on color { ColorAnimation { duration: 120 } }
                  Rectangle {
                    id: navIcon
                    x: Style.space(6)
                    anchors.verticalCenter: parent.verticalCenter
                    width: Style.space(Mac.sidebar.icon); height: width; radius: Style.space(Mac.sidebar.iconRadius)
                    color: navEntry.modelData[3]
                    gradient: Gradient {
                      GradientStop { position: 0; color: Qt.lighter(navEntry.modelData[3], 1.25) }
                      GradientStop { position: 1; color: navEntry.modelData[3] }
                    }
                    Text { anchors.centerIn: parent; textFormat: Text.PlainText; text: root.g(navEntry.modelData[2]); font.family: root.iconFont; font.pixelSize: Style.space(12); color: "white" }
                  }
                  Text {
                    anchors.left: navIcon.right; anchors.leftMargin: Style.space(9)
                    anchors.right: parent.right; anchors.rightMargin: Style.space(6)
                    anchors.verticalCenter: parent.verticalCenter
                    textFormat: Text.PlainText
                    elide: Text.ElideRight
                    text: navEntry.modelData[1]
                    font.family: root.uiFont; font.pixelSize: Style.space(Mac.font.body)
                    color: navItem.current ? "white" : root.fg
                  }
                  MouseArea { id: navMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.go(navEntry.modelData[0]) }
                }
              }
            }
          }
        }

        Text {
          anchors.bottom: parent.bottom; anchors.bottomMargin: Style.space(10)
          x: Style.space(14)
          textFormat: Text.PlainText
          text: root.busy ? T.t("Application…") : T.t("Enregistré automatiquement")
          font.family: root.uiFont; font.pixelSize: Style.space(10.5)
          color: root.fg; opacity: 0.45
        }
      }

      // ---- En-tête : ‹ et titre
      Item {
        id: header
        anchors.left: sidebar.right; anchors.leftMargin: Style.space(14)
        anchors.right: parent.right; anchors.rightMargin: Style.space(18)
        y: Style.space(10)
        height: Style.space(34)
        Rectangle {
          id: backBtn
          anchors.verticalCenter: parent.verticalCenter
          width: Style.space(28); height: width; radius: width / 2
          color: backMouse.containsMouse && root.history.length ? Qt.rgba(root.fg.r, root.fg.g, root.fg.b, 0.1) : "transparent"
          opacity: root.history.length ? 1 : 0.35
          Text { anchors.centerIn: parent; textFormat: Text.PlainText; text: root.g(0xF0141); font.family: root.iconFont; font.pixelSize: Style.space(20); color: root.fg }
          MouseArea { id: backMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.back() }
        }
        Text {
          anchors.left: backBtn.right; anchors.leftMargin: Style.space(8)
          anchors.verticalCenter: parent.verticalCenter
          textFormat: Text.PlainText
          text: root.pageInfo(root.page)[1]
          font.family: root.uiFont; font.pixelSize: Style.space(15); font.weight: Font.Bold
          color: root.fg
        }
      }

      // ---- Contenu (glisse depuis la droite à chaque page)
      Flickable {
        id: content
        anchors.left: sidebar.right; anchors.leftMargin: Style.space(16)
        anchors.right: parent.right; anchors.rightMargin: Style.space(18)
        anchors.top: header.bottom; anchors.topMargin: Style.space(8)
        anchors.bottom: parent.bottom; anchors.bottomMargin: Style.space(12)
        contentHeight: pageLoader.item ? pageLoader.item.implicitHeight + Style.space(10) : 0
        clip: true
        boundsBehavior: Flickable.DragOverBounds

        Loader {
          id: pageLoader
          width: content.width
          sourceComponent: ({
            wifi: pWifi, bluetooth: pBluetooth, network: pNetwork, battery: pBattery,
            general: pGeneral, appearance: pAppearance, control: pControl, desktop: pDesktop,
            displays: pDisplays, menubar: pMenubar, shortcuts: pShortcuts, wallpaper: pWallpaper, linux: pLinux,
            notifications: pNotifications, sound: pSound, focus: pFocus, music: pMusic,
            lock: pLock, users: pUsers, keyboard: pKeys, mouse: pMouse, trackpad: pTrackpad, corners: pCorners, about: pAbout,
            accessibility: pAccess, intelligence: pClaude, touchid: pTouch, language: pLanguage, printers: pPrinters,
            alcove: pAlcove, klack: pKlack
          })[root.page] || pAppearance
          property real slide: 0
          x: slide
          opacity: 1 - Math.min(1, Math.abs(slide) / 60)
          onSourceComponentChanged: { content.contentY = 0; enter.restart() }
          NumberAnimation { id: enter; target: pageLoader; property: "slide"; from: 46; to: 0; duration: 520; easing.type: Easing.OutBack; easing.overshoot: 1.6 }
        }
      }
    }
  }

  Connections {
    target: win
    function onContentRevealedChanged() { if (win.contentRevealed) keys.forceActiveFocus() }
  }

  // =============================================================== pages
  Component {
    id: pWifi
    Column {
      spacing: Style.space(14)
      Group {
        Row_ {
          label: "Wi-Fi"
          sub: root.wifiOn ? (root.ssid ? T.t("Connecté à « ") + root.ssid + " »" : T.t("Non connecté")) : T.t("Désactivé")
          icon: 0xF05A9; iconColor: "#0a84ff"
          Switch_ { checked: root.wifiOn; onToggled: function(v) { root.wifiOn = v; root.run(["nmcli", "radio", "wifi", v ? "on" : "off"]) } }
        }
      }
      SectionTitle { text: T.t("Réseaux disponibles"); visible: root.wifiOn }
      Group {
        visible: root.wifiOn && root.wifiList.length > 0
        Repeater {
          model: root.wifiList
          delegate: Row_ {
            required property var modelData
            label: modelData.ssid
            sub: modelData.current ? T.t("Connecté") : (modelData.secure ? T.t("Sécurisé") : T.t("Ouvert"))
            icon: modelData.signal > 66 ? 0xF0928 : (modelData.signal > 33 ? 0xF0925 : 0xF091F)
            iconColor: modelData.current ? "#0a84ff" : "#8e8e93"
            Btn {
              visible: !modelData.current
              text: T.t("Se connecter")
              secondary: true
              onClicked: root.run(["sh", "-c", "nmcli device wifi connect \"$1\" || omarchy-shell omarchy.network toggle", "sh", modelData.ssid])
            }
          }
        }
      }
      Row {
        spacing: Style.space(8)
        Btn { text: T.t("Actualiser"); secondary: true; onClicked: root.run(["nmcli", "device", "wifi", "rescan"]) }
        Btn { text: T.t("Réglages du réseau…"); secondary: true; onClicked: { root.dismiss(); root.launch(["omarchy-shell", "omarchy.network", "toggle"]) } }
      }
    }
  }

  Component {
    id: pBluetooth
    Column {
      spacing: Style.space(14)
      Group {
        Row_ {
          label: "Bluetooth"
          sub: root.bt ? (root.bt.enabled ? T.t("Activé — visible en tant que « ") + (root.bt.name || "Omarchy") + " »" : T.t("Désactivé")) : T.t("Aucun adaptateur")
          icon: 0xF00AF; iconColor: "#0a84ff"
          Switch_ { checked: !!(root.bt && root.bt.enabled); onToggled: function(v) { if (root.bt) root.bt.enabled = v } }
        }
      }
      SectionTitle { text: T.t("Mes appareils"); visible: devRep.count > 0 }
      Group {
        visible: devRep.count > 0
        Repeater {
          id: devRep
          model: root.bt && root.bt.devices ? root.bt.devices.values.filter(function(d) { return d.paired || d.connected }) : []
          delegate: Row_ {
            required property var modelData
            label: modelData.name || modelData.address
            sub: modelData.connected ? T.t("Connecté") + (modelData.batteryAvailable ? " — " + Math.round(modelData.battery * 100) + " %" : "") : T.t("Non connecté")
            icon: 0xF00AF; iconColor: modelData.connected ? "#0a84ff" : "#8e8e93"
            Btn { text: modelData.connected ? T.t("Déconnecter") : T.t("Connecter"); secondary: true; onClicked: modelData.connected = !modelData.connected }
          }
        }
      }
      Btn { text: T.t("Ajouter un appareil…"); secondary: true; onClicked: { root.dismiss(); root.launch(["omarchy-shell", "omarchy.bluetooth", "toggle"]) } }
    }
  }

  Component {
    id: pNetwork
    Column {
      spacing: Style.space(14)
      Group {
        Repeater {
          model: root.devices
          delegate: Row_ {
            required property var modelData
            label: modelData.type === "wifi" ? "Wi-Fi" : "Ethernet"
            sub: modelData.state === "connected" ? T.t("Connecté — ") + modelData.conn + " (" + modelData.dev + ")" : T.t("Non connecté (") + modelData.dev + ")"
            icon: modelData.type === "wifi" ? 0xF05A9 : 0xF0200
            iconColor: modelData.state === "connected" ? "#30d158" : "#8e8e93"
            Dot { on: modelData.state === "connected" }
          }
        }
        Row_ { visible: root.devices.length === 0; label: T.t("Aucune interface réseau") }
      }
      Btn { text: T.t("Détails…"); secondary: true; onClicked: { root.dismiss(); root.launch(["omarchy-shell", "omarchy.network", "toggle"]) } }
    }
  }

  Component {
    id: pBattery
    Column {
      spacing: Style.space(14)
      Group {
        Row_ {
          label: root.hasBat ? T.t("Niveau de la batterie") : T.t("Pas de batterie")
          sub: root.hasBat ? (UPower.onBattery ? T.t("Sur batterie") : T.t("Branché sur secteur")) : ""
          icon: 0xF0079; iconColor: "#30d158"
          Label_ { visible: root.hasBat; text: root.hasBat ? Math.round(root.batDev.percentage * 100) + " %" : ""; opacity: 0.9; font.weight: Font.DemiBold }
        }
        Row_ {
          visible: root.hasBat
          label: T.t("Charge")
          Rectangle {
            width: Style.space(200); height: Style.space(10); radius: height / 2
            color: Qt.rgba(root.fg.r, root.fg.g, root.fg.b, 0.12)
            Rectangle {
              readonly property real p: root.hasBat ? root.batDev.percentage : 0
              width: parent.width * p; height: parent.height; radius: height / 2
              color: p <= 0.2 ? "#ff453a" : "#30d158"
            }
          }
        }
      }
      SectionTitle { text: T.t("Mode d'énergie") }
      Group {
        Row_ {
          label: T.t("Profil")
          sub: T.t("Économie d'énergie, équilibré ou performances")
          Seg {
            options: [["0", T.t("Économie")], ["1", T.t("Équilibré")], ["2", T.t("Performances")]]
            value: String(PowerProfiles.profile === PowerProfile.PowerSaver ? 0 : (PowerProfiles.profile === PowerProfile.Performance ? 2 : 1))
            onPicked: function(v) { PowerProfiles.profile = [PowerProfile.PowerSaver, PowerProfile.Balanced, PowerProfile.Performance][parseInt(v)] }
          }
        }
      }
    }
  }

  Component {
    id: pGeneral
    Column {
      spacing: Style.space(14)
      Group {
        Row_ { label: T.t("Nom de l'ordinateur"); icon: 0xF0379; iconColor: "#8e8e93"; Label_ { text: Quickshell.env("HOSTNAME") || "Omarchy" } }
        Row_ { label: T.t("Système"); icon: 0xF08C7; iconColor: "#8e8e93"; Label_ { text: "Omarchy — Liquid Glass" } }
      }
      Group {
        ToggleRow { label: T.t("Raccourcis façon macOS"); key: "keys.macos_shortcuts"; def: true; sub: T.t("⌘Espace, ⌘Q, ⌘Tab, ⌘↑, ⌘⇧3/4/5…"); icon: 0xF030C; iconColor: "#8e8e93" }
        ToggleRow { label: T.t("Animations à ressort"); key: "glass.animations"; def: true; icon: 0xF0E61; iconColor: "#ff9f0a" }
      }
      Group {
        Row_ { label: T.t("Réappliquer tous les réglages"); icon: 0xF0450; iconColor: "#30d158"; Btn { text: T.t("Appliquer"); secondary: true; onClicked: root.launch(["liquid-glass", "apply"]) } }
        Row_ { label: T.t("Ouvrir le fichier de configuration"); icon: 0xF0214; iconColor: "#0a84ff"; Btn { text: T.t("Ouvrir"); secondary: true; onClicked: { root.dismiss(); root.launch(["xdg-open", root.home + "/.config/liquid-glass/config.toml"]) } } }
      }
    }
  }

  Component {
    id: pAppearance
    Column {
      spacing: Style.space(14)
      Group {
        Row_ {
          label: T.t("Apparence")
          Row {
            spacing: Style.space(14)
            Repeater {
              model: [["light", T.t("Clair")], ["dark", T.t("Sombre")], ["auto", "Auto"]]
              delegate: Column {
                id: ap
                required property var modelData
                readonly property bool on: root.val("appearance.mode", "light") === modelData[0]
                spacing: Style.space(4)
                Rectangle {
                  width: Style.space(66); height: Style.space(44); radius: Style.space(8)
                  border.width: ap.on ? 3 : 1
                  border.color: ap.on ? root.accent : Qt.rgba(root.fg.r, root.fg.g, root.fg.b, 0.15)
                  gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0; color: ap.modelData[0] === "dark" ? "#1c1c1e" : "#f5f5f7" }
                    GradientStop { position: 0.5; color: ap.modelData[0] === "dark" ? "#1c1c1e" : "#f5f5f7" }
                    GradientStop { position: 0.51; color: ap.modelData[0] === "light" ? "#f5f5f7" : "#1c1c1e" }
                    GradientStop { position: 1; color: ap.modelData[0] === "light" ? "#f5f5f7" : "#1c1c1e" }
                  }
                  Rectangle { x: Style.space(8); y: Style.space(8); width: parent.width * 0.55; height: Style.space(6); radius: 3; color: root.accent }
                  scale: apMouse.pressed ? 0.9 : 1
                  Behavior on scale { NumberAnimation { duration: 300; easing.type: Easing.OutBack; easing.overshoot: 3 } }
                  MouseArea { id: apMouse; anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.set("appearance.mode", ap.modelData[0]) }
                }
                Text { anchors.horizontalCenter: parent.horizontalCenter; textFormat: Text.PlainText; text: ap.modelData[1]; font.family: root.uiFont; font.pixelSize: Style.space(11); font.weight: ap.on ? Font.DemiBold : Font.Normal; color: root.fg }
              }
            }
          }
        }
        Row_ {
          label: T.t("Passage au clair")
          visible: root.val("appearance.mode", "light") === "auto"
          Stepper { value: root.val("appearance.auto_light_at", "07:30"); onChanged_: function(v) { root.set("appearance.auto_light_at", v) } }
        }
        Row_ {
          label: T.t("Passage au sombre")
          visible: root.val("appearance.mode", "light") === "auto"
          Stepper { value: root.val("appearance.auto_dark_at", "19:30"); onChanged_: function(v) { root.set("appearance.auto_dark_at", v) } }
        }
      }
      SectionTitle { text: T.t("Verre") }
      Group {
        // macOS 27 : un seul curseur, du verre transparent au verre teinté.
        SliderRow {
          label: "Liquid Glass"; sub: T.t("De transparent à teinté, sur tout le système")
          key: "glass.tint"; from: 0; to: 1; step: 0.05; def: 0.5
          fmt: function(v) { return v <= 0.15 ? T.t("Transparent") : (v >= 0.85 ? T.t("Teinté") : Math.round(v * 100) + " %") }
        }
        Row_ {
          label: T.t("Style du verre")
          sub: T.t("Clair : plus transparent · Teinté : plus opaque")
          Seg {
            options: [["clear", T.t("Clair")], ["standard", "Standard"], ["tinted", T.t("Teinté")]]
            value: root.val("glass.style", "standard")
            onPicked: function(v) { root.set("glass.style", v) }
          }
        }
        SliderRow { label: T.t("Opacité du verre"); key: "glass.opacity"; from: 0.5; to: 1.4; step: 0.05; def: 1.0; fmt: function(v) { return Math.round(v * 100) + " %" } }
        SliderRow { label: T.t("Intensité du flou"); key: "glass.blur_size"; from: 2; to: 14; step: 1; def: 7 }
        SliderRow { label: T.t("Passes de flou"); key: "glass.blur_passes"; from: 1; to: 4; step: 1; def: 3 }
        SliderRow { label: T.t("Arrondi des fenêtres"); key: "glass.rounding"; from: 0; to: 28; step: 1; def: 16; fmt: function(v) { return v + " px" } }
      }
      Group {
        SliderRow { label: T.t("Fenêtre active"); key: "glass.window_opacity_active"; from: 0.7; to: 1.0; step: 0.01; def: 0.96; fmt: function(v) { return Math.round(v * 100) + " %" } }
        SliderRow { label: T.t("Fenêtres inactives"); key: "glass.window_opacity_inactive"; from: 0.6; to: 1.0; step: 0.01; def: 0.9; fmt: function(v) { return Math.round(v * 100) + " %" } }
        SliderRow { label: T.t("Terminal (clair)"); key: "terminal.opacity_light"; from: 0.5; to: 1.0; step: 0.02; def: 0.8; fmt: function(v) { return Math.round(v * 100) + " %" } }
        SliderRow { label: T.t("Terminal (sombre)"); key: "terminal.opacity_dark"; from: 0.5; to: 1.0; step: 0.02; def: 0.76; fmt: function(v) { return Math.round(v * 100) + " %" } }
        SliderRow { label: T.t("Espace entre fenêtres"); key: "glass.gaps_in"; from: 0; to: 20; step: 1; def: 5; fmt: function(v) { return v + " px" } }
        SliderRow { label: T.t("Marge d'écran"); key: "glass.gaps_out"; from: 0; to: 40; step: 1; def: 10; fmt: function(v) { return v + " px" } }
      }
      SectionTitle { text: T.t("Police") }
      Group {
        FontRow { label: T.t("Police de l'interface"); key: "appearance.font_ui"; def: "Inter" }
      }
      Hint { text: T.t("Opacité du verre, police et terminal : le thème est régénéré (≈1 s). Le reste s'applique instantanément.") }
    }
  }

  Component {
    id: pControl
    Column {
      spacing: Style.space(14)
      SectionTitle { text: T.t("Pastilles") }
      Group {
        Repeater {
          model: [T.t("Pastille 2 (sous Concentration)"), T.t("Pastille 3"), T.t("Sous « Lecture en cours »")]
          delegate: Row_ {
            id: tileRow
            required property var modelData
            required property int index
            readonly property var cur: root.val("control.tiles", ["wifi", "record", "gamemode"])
            label: modelData
            Picker {
              options: [["wifi", "Wi-Fi"], ["bluetooth", "Bluetooth"], ["airplane", T.t("Mode avion")], ["record", T.t("Enregistrement")],
                        ["gamemode", T.t("Mode Jeu")], ["nightshift", "Night Shift"], ["awake", T.t("Rester éveillé")], ["dark", T.t("Mode sombre")]]
              value: tileRow.cur[tileRow.index] || ["wifi", "record", "gamemode"][tileRow.index]
              onPicked: function(v) {
                var t = tileRow.cur.slice(0, 3)
                while (t.length < 3) t.push(["wifi", "record", "gamemode"][t.length])
                t[tileRow.index] = v
                root.set("control.tiles", t)
              }
            }
          }
        }
      }
      Hint { text: T.t("Concentration et « Lecture en cours » sont toujours affichés. Mode Jeu : sans flou, ombres ni animations, profil d'énergie performance.") }
      SectionTitle { text: T.t("Boutons ronds") }
      Hint { text: T.t("Choisissez les boutons ronds du Centre de contrôle (le mode sombre est toujours affiché). L'ordre suit cette liste.") }
      Group {
        Repeater {
          model: [["nightshift", "Night Shift", 0xF06E8, "#ff9f0a"], ["awake", T.t("Rester éveillé"), 0xF0176, "#a2845e"], ["screenshot", T.t("Capture d'écran"), 0xF0100, "#8e8e93"],
                  ["record", T.t("Enregistrement de l'écran"), 0xF044A, "#ff453a"], ["glass", T.t("Style du verre"), 0xF0F5A, "#32ade6"], ["lyrics", T.t("Paroles sur le bureau"), 0xF0387, "#ff375f"],
                  ["karaoke", T.t("Karaoké"), 0xF0E54, "#bf5af2"], ["mission", "Mission Control", 0xF0570, "#0a84ff"], ["desktop", T.t("Afficher le bureau"), 0xF01C4, "#30d158"],
                  ["lock", T.t("Verrouiller l'écran"), 0xF033E, "#1c1c1e"], ["calculator", T.t("Calculette"), 0xF00EC, "#ff9f0a"], ["clipboard", T.t("Presse-papiers"), 0xF014F, "#8e8e93"],
                  ["emoji", T.t("Émojis"), 0xF0785, "#ffd60a"], ["settings", T.t("Réglages"), 0xF0493, "#8e8e93"]]
          delegate: Row_ {
            id: cb
            required property var modelData
            readonly property var current: root.val("control.buttons", ["nightshift", "awake", "screenshot", "record", "glass", "lyrics", "mission", "settings"])
            label: modelData[1]
            icon: modelData[2]; iconColor: modelData[3]
            Switch_ {
              checked: cb.current.indexOf(cb.modelData[0]) !== -1
              onToggled: function(v) {
                var all = ["nightshift", "awake", "screenshot", "record", "glass", "lyrics", "karaoke", "mission", "desktop", "lock", "calculator", "clipboard", "emoji", "settings"]
                var cur = cb.current.slice()
                if (v && cur.indexOf(cb.modelData[0]) === -1) cur.push(cb.modelData[0])
                if (!v) cur = cur.filter(function(x) { return x !== cb.modelData[0] })
                cur.sort(function(a, b) { return all.indexOf(a) - all.indexOf(b) })
                root.set("control.buttons", cur)
              }
            }
          }
        }
      }
    }
  }

  Component {
    id: pDesktop
    Column {
      spacing: Style.space(14)
      // Bandeau d'aperçu du Dock.
      Rectangle {
        width: parent.width; height: Style.space(86); radius: Style.space(16)
        clip: true
        Image { anchors.fill: parent; source: root.currentBg ? "file://" + root.currentBg : ""; fillMode: Image.PreserveAspectCrop; sourceSize: Qt.size(640, 200); asynchronous: true }
        Rectangle {
          anchors.horizontalCenter: parent.horizontalCenter; anchors.bottom: parent.bottom; anchors.bottomMargin: Style.space(10)
          readonly property real s: Number(root.val("dock.icon_size", 42)) * 0.62
          width: 6 * (s + 6) + 10; height: s + 12; radius: Style.space(14)
          color: Qt.rgba(1, 1, 1, 0.35); border.width: 1; border.color: Qt.rgba(1, 1, 1, 0.6)
          Behavior on width { NumberAnimation { duration: 400; easing.type: Easing.OutBack; easing.overshoot: 2 } }
          Row {
            anchors.centerIn: parent; spacing: 6
            Repeater {
              model: ["#0a84ff", "#30d158", "#ff9f0a", "#ff375f", "#bf5af2", "#8e8e93"]
              delegate: Rectangle { required property var modelData; width: parent.parent.s; height: width; radius: width * 0.24; color: modelData
                Behavior on width { NumberAnimation { duration: 400; easing.type: Easing.OutBack; easing.overshoot: 2 } } }
            }
          }
        }
      }
      SectionTitle { text: "Dock" }
      Group {
        SliderRow { label: T.t("Taille"); key: "dock.icon_size"; from: 32; to: 72; step: 2; def: 42; fmt: function(v) { return v + " px" } }
        SliderRow { label: T.t("Agrandissement"); key: "dock.magnification"; from: 1.0; to: 2.2; step: 0.1; def: 1.6; fmt: function(v) { return v <= 1.0 ? T.t("Désactivé") : "×" + v.toFixed(1) } }
        ToggleRow { label: T.t("Toujours visible"); key: "dock.always_visible"; def: true }
        ToggleRow { label: T.t("Masquer automatiquement"); key: "dock.autohide"; def: false }
      }
      SectionTitle { text: T.t("Fenêtres") }
      Group {
        ToggleRow { label: T.t("Fenêtres flottantes comme sur Mac"); key: "windows.floating"; def: true; sub: T.t("Ouvertes au centre ; ⌘T remet une fenêtre en mosaïque") }
        ToggleRow { label: T.t("Barre de titre avec feux tricolores"); key: "glass.titlebars"; def: true; sub: T.t("Fermer, réduire dans le Dock, agrandir — sur toutes les apps flottantes ; double-clic sur la barre : agrandir") }
        Row_ {
          label: T.t("Bouton vert")
          Seg { options: [["menu", T.t("Menu Mosaïque")], ["zoom", T.t("Agrandir")]]; value: root.val("windows.green_button", "menu"); onPicked: function(v) { root.set("windows.green_button", v) } }
        }
      }
      SectionTitle { text: "Widgets" }
      Group {
        ToggleRow { label: T.t("Widgets sur le bureau"); key: "widgets.enabled"; def: true }
        Row_ {
          label: T.t("Colonne")
          Seg { options: [["left", T.t("À gauche")], ["right", T.t("À droite")]]; value: root.val("widgets.position", "left"); onPicked: function(v) { root.set("widgets.position", v) } }
        }
        ToggleRow { label: T.t("Horloge"); key: "widgets.clock"; def: true }
        Row_ {
          label: T.t("Style de l'horloge")
          visible: root.val("widgets.clock", true) === true
          Seg { options: [["digital", T.t("Numérique")], ["analog", T.t("Cadran")]]; value: String(root.val("widgets.clock_style", "digital")); onPicked: function(v) { root.set("widgets.clock_style", v) } }
        }
        Row_ {
          label: T.t("Taille de l'horloge")
          visible: root.val("widgets.clock", true) === true
          Seg { options: root.widgetSizes; value: root.widgetSize("clock"); onPicked: function(v) { root.set("widgets.clock_size", v) } }
        }
        ToggleRow { label: T.t("Calendrier"); key: "widgets.calendar"; def: true }
        Row_ {
          label: T.t("Taille du calendrier")
          visible: root.val("widgets.calendar", true) === true
          Seg { options: root.widgetSizes; value: root.widgetSize("calendar"); onPicked: function(v) { root.set("widgets.calendar_size", v) } }
        }
        ToggleRow { label: T.t("Météo"); key: "widgets.weather"; def: true }
        Row_ {
          label: T.t("Taille de la météo")
          visible: root.val("widgets.weather", true) === true
          Seg { options: root.widgetSizes; value: root.widgetSize("weather"); onPicked: function(v) { root.set("widgets.weather_size", v) } }
        }
        ToggleRow { label: T.t("Batterie"); key: "widgets.battery"; def: true }
        Row_ {
          label: T.t("Taille de la batterie")
          visible: root.val("widgets.battery", true) === true
          Seg { options: root.widgetSizes; value: root.widgetSize("battery"); onPicked: function(v) { root.set("widgets.battery_size", v) } }
        }
        Row_ {
          label: T.t("Ville de la météo")
          TextBox { value: String(root.val("widgets.weather_city", "")); placeholder: T.t("Automatique"); onCommitted: function(t) { root.set("widgets.weather_city", t) } }
        }
      }
      SectionTitle { text: T.t("Widget musique") }
      Group {
        ToggleRow { label: T.t("Lecture en cours sur le bureau"); key: "widgets.music"; def: true; sub: T.t("Glissez-le où vous voulez : il glisse et rebondit") }
        Row_ {
          label: T.t("Taille")
          Seg { options: [["small", T.t("Petit")], ["medium", T.t("Moyen")], ["large", T.t("Grand")]]; value: root.val("widgets.music_size", "medium"); onPicked: function(v) { root.set("widgets.music_size", v) } }
        }
        Row_ {
          label: "Position"
          Btn { text: T.t("Replacer"); secondary: true; onClicked: { root.set("widgets.music_x", -1); root.set("widgets.music_y", -1) } }
        }
      }
    }
  }

  Component {
    id: pDisplays
    Column {
      spacing: Style.space(14)
      Group {
        Row_ {
          label: T.t("Luminosité")
          icon: 0xF00DF; iconColor: "#0a84ff"
          LiveSlider {
            value: root.brightness
            onMoved: function(v) { root.brightness = Math.max(0.03, v); brightApply.pct = Math.round(root.brightness * 100); brightApply.restart() }
          }
        }
        Row_ {
          label: "Night Shift"
          sub: T.t("Couleurs plus chaudes le soir")
          icon: 0xF06E8; iconColor: "#ff9f0a"
          Switch_ { checked: root.nightlight; onToggled: function(v) { root.nightlight = v; root.run(["omarchy-shell", "nightlight", "toggle"]) } }
        }
      }
      // Moniteurs (comme la section « Écrans » de la vidéo) : nom, définition, fréquence, échelle.
      SectionTitle { text: T.t("Moniteurs") }
      Group {
        id: monGroup
        property var mons: []
        Process {
          running: true
          command: ["hyprctl", "monitors", "-j"]
          stdout: StdioCollector { onStreamFinished: { try { monGroup.mons = JSON.parse(text) } catch (e) {} } }
        }
        Repeater {
          model: monGroup.mons
          delegate: Column {
            id: mon
            required property var modelData
            width: parent.width
            Row_ {
              label: ((mon.modelData.make || "") + " " + (mon.modelData.model || "")).trim() || mon.modelData.name
              sub: mon.modelData.name + (mon.modelData.focused ? T.t(" · écran principal") : "")
              icon: 0xF0379; iconColor: "#0a84ff"
            }
            Row_ { label: T.t("Définition"); Label_ { text: mon.modelData.width + " × " + mon.modelData.height + T.t("  (comme ") + Math.round(mon.modelData.width / mon.modelData.scale) + " × " + Math.round(mon.modelData.height / mon.modelData.scale) + ")" } }
            Row_ { label: T.t("Fréquence de rafraîchissement"); Label_ { text: Math.round(mon.modelData.refreshRate) + " Hz" } }
            Row_ { label: T.t("Échelle"); Label_ { text: Math.round(mon.modelData.scale * 100) + " %" } }
          }
        }
      }
      Group {
        ToggleRow { label: T.t("Coins d'écran arrondis"); key: "corners.enabled"; def: true; sub: T.t("Comme la dalle d'un MacBook ; les clics passent au travers") }
        SliderRow { visible: root.val("corners.enabled", true) === true; label: T.t("Rayon"); key: "corners.radius"; from: 4; to: 24; step: 1; def: 10; fmt: function(v) { return v + " px" } }
      }
      Btn { text: T.t("Moniteurs…"); secondary: true; onClicked: { root.dismiss(); root.launch(["omarchy-shell", "omarchy.monitor", "toggle"]) } }
    }
  }

  Component {
    id: pMenubar
    Column {
      spacing: Style.space(14)
      Group {
        Row_ {
          label: T.t("Logo de la barre")
          sub: T.t("Le menu tout à gauche")
          Seg {
            options: [["pomme", T.t("Pomme")], ["arch", "Arch"], ["tux", "Tux"], ["omarchy", "Omarchy"], ["orb", T.t("Bille")], ["goutte", T.t("Goutte")]]
            value: root.val("appearance.logo", "pomme")
            onPicked: function(v) { root.set("appearance.logo", v) }
          }
        }
      }
      Group {
        Row_ {
          label: T.t("Masquer la barre automatiquement")
          sub: T.t("Amenez la souris tout en haut de l'écran pour la faire apparaître")
          Seg {
            options: [["never", T.t("Jamais")], ["always", T.t("Toujours")]]
            value: String(root.val("menubar.autohide", "never"))
            onPicked: function(v) { root.set("menubar.autohide", v) }
          }
        }
      }
      Group {
        Row_ {
          label: T.t("Fond de la barre")
          sub: T.t("Transparente comme macOS Tahoe : le texte devient sombre ou blanc selon le fond d'écran")
          Seg {
            options: [["none", T.t("Transparente")], ["glassy", T.t("Verre")], ["opaque", "Opaque"]]
            value: String(root.barItems.background || "opaque")
            onPicked: function(v) {
              var next = Object.assign({}, root.barItems); next.background = v; root.barItems = next
              root.run(["liquid-glass", "bar", "background", v])
            }
          }
        }
      }
      SectionTitle { text: T.t("Éléments de la barre") }
      Group {
        BarRow { label: T.t("Batterie"); item: "battery" }
        Row_ {
          label: T.t("Pourcentage de la batterie")
          sub: T.t("À gauche de la pile (aussi : clic droit sur la batterie)")
          visible: root.barItems.battery === true
          Switch_ { checked: root.barItems.battery_percent === true; onToggled: function(v) { root.run(["omarchy-shell", "liquid-glass.power", "togglePercentage"]); barTimer.restart() } }
        }
        BarRow { label: "Wi-Fi"; item: "wifi" }
        BarRow { label: T.t("Spotlight (loupe)"); item: "spotlight" }
        BarRow { label: "Bluetooth"; item: "bluetooth"; sub: T.t("Aussi dans le Centre de contrôle") }
        BarRow { label: T.t("Son"); item: "sound"; sub: T.t("Aussi dans le Centre de contrôle") }
        BarRow { label: T.t("Bureaux (1 2 3…)"); item: "workspaces"; sub: T.t("Pas sur macOS : Mission Control (⌘↑) les remplace") }
        BarRow { label: T.t("Morceau en cours"); item: "nowplaying"; sub: T.t("Pochette et titre à droite (déjà dans l'île)") }
        BarRow { label: "Agents"; item: "agents"; sub: T.t("Indicateur des agents Omarchy") }
        BarRow { label: T.t("Indicateurs Omarchy"); item: "indicators"; sub: T.t("Enregistrement, Ne pas déranger, veille… (apparaissent au survol de la barre)") }
        BarRow { label: T.t("Disposition du clavier"); item: "keyboard"; sub: T.t("Déjà dans l'île quand elle change (⌃Espace)") }
        BarRow { label: T.t("Mises à jour"); item: "updates"; sub: T.t("Icône quand des mises à jour Omarchy sont disponibles") }
      }
      SectionTitle { text: T.t("Paroles") }
      Group {
        ToggleRow { label: T.t("Dans l'île dynamique"); key: "island.lyrics"; def: true; sub: T.t("L'île s'élargit et la ligne chantée défile dedans") }
        ToggleRow { label: T.t("Dans la barre"); key: "lyrics.bar"; def: false; sub: T.t("Ancienne présentation : la ligne à côté du titre") }
        ToggleRow { label: T.t("Sur le fond d'écran"); key: "lyrics.desktop"; def: false; sub: T.t("En grand à côté de la pochette (bulle du widget musique)") }
      }
      SectionTitle { text: T.t("Horloge") }
      Group {
        ToggleRow { label: T.t("Horloge 24 heures"); key: "menubar.clock_24h"; def: true }
        ToggleRow { label: T.t("Afficher la date"); key: "menubar.show_date"; def: true }
        ToggleRow { label: T.t("Afficher les secondes"); key: "menubar.show_seconds"; def: false }
        ToggleRow { label: T.t("La semaine commence le lundi"); key: "menubar.week_monday"; def: true; sub: T.t("Widget Calendrier") }
      }
      SectionTitle { text: T.t("Île dynamique") }
      Group {
        Row_ { label: T.t("Réglages de l'île (Alcove)"); icon: 0xF0402; iconColor: "#1c1c1e"; Btn { text: T.t("Ouvrir"); secondary: true; onClicked: root.go("alcove") } }
      }
      Hint { text: T.t("Molette sur l'île : volume. Balayage horizontal : morceau suivant ou précédent. Clic droit : ces réglages.") }
      Hint { text: T.t("La barre est celle d'Omarchy, habillée en verre par le thème Liquid Glass. Organisation des widgets : omarchy bar --help.") }
    }
  }

  // ------------------------------------------------ raccourcis d'apps (barre)
  // shortcuts.apps : « claude-code » (Claude Code via omarchy-agent) ou ids .desktop.
  readonly property var shortcutIds: {
    var a = root.val("shortcuts.apps", ["claude-code"])
    return Array.isArray(a) ? a : ["claude-code"]
  }
  readonly property string claudeIcon: "file:///usr/share/omarchy/shell/plugins/agents/assets/claude.svg"
  function normId(id) { return String(id).toLowerCase().replace(/\.desktop$/, "") }
  function appEntry(id) {
    var all = DesktopEntries.applications.values, want = normId(id)
    for (var i = 0; i < all.length; i++) if (normId(all[i].id) === want) return all[i]
    return null
  }
  function appIcon(icon) {
    var lib = root.shell ? root.shell.appLibrary : null
    return lib ? lib.iconSource(icon) : Quickshell.iconPath(icon, true)
  }
  function shortcutInfo(id) {
    if (id === "claude-code") return { name: "Claude Code", sub: T.t("Terminal avec Claude Code (omarchy-agent)"), icon: root.claudeIcon }
    var e = appEntry(id)
    return e ? { name: e.name, sub: e.genericName || e.comment || "", icon: appIcon(e.icon) }
             : { name: id, sub: T.t("App introuvable"), icon: "" }
  }
  function hasShortcut(id) { var n = normId(id); return shortcutIds.some(function(x) { return normId(x) === n }) }
  function addShortcut(id) { if (!hasShortcut(id)) root.set("shortcuts.apps", shortcutIds.concat([id])) }
  function removeShortcut(i) { var a = shortcutIds.slice(); a.splice(i, 1); root.set("shortcuts.apps", a) }
  function moveShortcut(i, d) {
    var a = shortcutIds.slice(), j = i + d
    if (j < 0 || j >= a.length) return
    var t = a[i]; a[i] = a[j]; a[j] = t
    root.set("shortcuts.apps", a)
  }
  property string appQuery: ""
  readonly property var installedApps: {
    var q = appQuery.trim().toLowerCase(), out = []
    if (!hasShortcut("claude-code") && (q === "" || "claude code".indexOf(q) !== -1))
      out.push({ id: "claude-code", name: "Claude Code", sub: T.t("Terminal avec Claude Code"), icon: root.claudeIcon })
    var all = DesktopEntries.applications.values.slice().sort(function(a, b) { return String(a.name).localeCompare(String(b.name)) })
    for (var i = 0; i < all.length; i++) {
      var e = all[i]
      if (e.noDisplay || hasShortcut(e.id)) continue
      var hay = (String(e.name) + " " + String(e.genericName || "") + " " + String(e.id)).toLowerCase()
      if (q !== "" && hay.indexOf(q) === -1) continue
      out.push({ id: e.id, name: e.name, sub: e.genericName || e.comment || "", icon: appIcon(e.icon) })
    }
    return out
  }

  // Ligne d'app : icône réelle de l'app, nom, sous-titre, contrôles à droite.
  component AppRow: Item {
    id: ar
    property string name: ""
    property string sub: ""
    property string icon: ""
    default property alias control: arSlot.data
    width: parent ? parent.width : 0
    height: Style.space(44)
    Rectangle {
      visible: ar.y > 0
      x: arLabels.x; width: parent.width - x - Style.space(14); height: 1
      color: root.fg; opacity: 0.07
    }
    Image {
      id: arIcon
      x: Style.space(12); anchors.verticalCenter: parent.verticalCenter
      width: Style.space(26); height: width
      sourceSize.width: width * 2; sourceSize.height: height * 2
      source: ar.icon; fillMode: Image.PreserveAspectFit; smooth: true; mipmap: true
    }
    Column {
      id: arLabels
      x: arIcon.x + arIcon.width + Style.space(10)
      anchors.verticalCenter: parent.verticalCenter
      width: parent.width - x - arSlot.width - Style.space(28)
      spacing: 1
      Text { width: parent.width; textFormat: Text.PlainText; text: ar.name; elide: Text.ElideRight; font.family: root.uiFont; font.pixelSize: Style.space(13); color: root.fg }
      Text { width: parent.width; visible: ar.sub !== ""; textFormat: Text.PlainText; text: ar.sub; elide: Text.ElideRight; font.family: root.uiFont; font.pixelSize: Style.space(11); color: root.fg; opacity: 0.5 }
    }
    Row {
      id: arSlot
      anchors.right: parent.right; anchors.rightMargin: Style.space(14)
      anchors.verticalCenter: parent.verticalCenter
      spacing: Style.space(6)
    }
  }

  // Petit bouton rond à glyphe (monter, descendre, retirer, ajouter).
  component RoundGlyph: Rectangle {
    id: rg
    property int glyph: 0
    property color tint: root.fg
    property bool filled: false
    property bool enabled_: true
    signal clicked()
    width: Style.space(24); height: width; radius: width / 2
    opacity: enabled_ ? 1 : 0.3
    color: filled ? tint : Qt.rgba(root.fg.r, root.fg.g, root.fg.b, rgMouse.containsMouse && enabled_ ? 0.16 : 0.08)
    scale: rgMouse.pressed && enabled_ ? 0.85 : 1
    Behavior on scale { NumberAnimation { duration: 280; easing.type: Easing.OutBack; easing.overshoot: 3 } }
    Text { anchors.centerIn: parent; textFormat: Text.PlainText; text: root.g(rg.glyph); font.family: root.iconFont; font.pixelSize: Style.space(14); color: rg.filled ? "white" : rg.tint }
    MouseArea { id: rgMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: rg.enabled_ ? Qt.PointingHandCursor : Qt.ArrowCursor; onClicked: if (rg.enabled_) rg.clicked() }
  }

  Component {
    id: pShortcuts
    Column {
      spacing: Style.space(14)
      Group {
        BarRow { label: T.t("Raccourcis dans la barre des menus"); item: "shortcuts"; sub: T.t("Icônes d'apps à gauche des indicateurs, comme le bouton Claude") }
      }
      SectionTitle { text: T.t("Dans la barre (de gauche à droite)") }
      Group {
        Repeater {
          model: root.shortcutIds
          AppRow {
            required property var modelData
            required property int index
            readonly property var info: root.shortcutInfo(modelData)
            name: info.name; sub: info.sub; icon: info.icon
            RoundGlyph { glyph: 0xF0143; enabled_: index > 0; onClicked: root.moveShortcut(index, -1) }
            RoundGlyph { glyph: 0xF0140; enabled_: index < root.shortcutIds.length - 1; onClicked: root.moveShortcut(index, 1) }
            RoundGlyph { glyph: 0xF0374; filled: true; tint: "#ff3b30"; onClicked: root.removeShortcut(index) }
          }
        }
        Row_ { visible: root.shortcutIds.length === 0; label: T.t("Aucun raccourci"); sub: T.t("Ajoutez des apps ci-dessous") }
      }
      SectionTitle { text: T.t("Ajouter une app") }
      TextBox {
        width: parent.width
        placeholder: T.t("Rechercher une app installée…")
        value: root.appQuery
        onEdited: function(t) { root.appQuery = t }
      }
      Group {
        Repeater {
          model: root.installedApps.slice(0, 60)
          AppRow {
            required property var modelData
            name: modelData.name; sub: modelData.sub; icon: modelData.icon
            RoundGlyph { glyph: 0xF0415; filled: true; tint: "#30d158"; onClicked: root.addShortcut(modelData.id) }
          }
        }
        Row_ { visible: root.installedApps.length === 0; label: T.t("Aucune app trouvée") }
      }
      Hint { visible: root.installedApps.length > 60; text: (root.installedApps.length - 60) + T.t(" autres apps : affinez la recherche.") }
      Hint { text: T.t("Clic sur un raccourci : ouvre l'app, ou passe sur sa fenêtre si elle est déjà ouverte. Clic droit : cette page.") }
    }
  }

  Component {
    id: pWallpaper
    Column {
      spacing: Style.space(14)
      Row {
        spacing: Style.space(16)
        Rectangle {
          width: Style.space(200); height: Style.space(118); radius: Style.space(12)
          clip: true
          color: Qt.rgba(root.fg.r, root.fg.g, root.fg.b, 0.1)
          Image { anchors.fill: parent; source: root.bgThumb(root.currentBg); fillMode: Image.PreserveAspectCrop; sourceSize: Qt.size(400, 240); asynchronous: true }
        }
        Column {
          anchors.verticalCenter: parent.verticalCenter
          spacing: Style.space(8)
          Text { textFormat: Text.PlainText; text: root.currentBg ? root.currentBg.split("/").pop().replace(/\.[^.]+$/, "") : "—"; font.family: root.uiFont; font.pixelSize: Style.space(14); font.weight: Font.DemiBold; color: root.fg; width: Style.space(260); elide: Text.ElideRight }
          Row {
            spacing: Style.space(8)
            Btn { text: T.t("Ouvrir le dossier"); secondary: true; onClicked: { root.dismiss(); root.launch(["omarchy", "theme", "bg", "install"]) } }
            Btn { text: T.t("Actualiser"); secondary: true; onClicked: root.refresh() }
          }
        }
      }
      SectionTitle { text: T.t("Bureau dynamique") }
      Group {
        Row_ {
          label: T.t("Fond dynamique")
          sub: T.t("Change au fil de la journée (aube, jour, crépuscule, nuit) ou suit le mode clair / sombre")
        }
        Item {
          id: dynBox
          readonly property string cur: String(root.val("wallpaper.dynamic", ""))
          width: parent ? parent.width : 0
          height: dynFlow.implicitHeight + Style.space(12)
          Flow {
            id: dynFlow
            x: Style.space(12); width: parent.width - Style.space(24)
            spacing: Style.space(6)
            Repeater {
              model: [["", T.t("Désactivé")], ["golden-gate", "Golden Gate"], ["golden-gate-abstrait", T.t("Vagues 27")],
                      ["tahoe-plage", T.t("Plage de Tahoe")], ["tahoe", "Tahoe"], ["sequoia", "Sequoia"], ["sonoma", "Sonoma"],
                      ["ventura", "Ventura"], ["monterey", "Monterey"], ["big-sur", "Big Sur"], ["catalina", "Catalina"], ["mojave", "Mojave"]]
              Btn {
                required property var modelData
                text: modelData[1]; secondary: dynBox.cur !== modelData[0]
                onClicked: { root.set("wallpaper.dynamic", modelData[0]); root.launch(["liquid-glass", "dynamic-wallpaper", "tick"]) }
              }
            }
          }
        }
      }
      SectionTitle { text: T.t("Pendant la musique") }
      Group {
        Row_ {
          label: T.t("Fond d'écran Spotify")
          sub: T.t("Off : le fond normal reste, seul le widget s'affiche")
          Seg {
            options: [["off", "Off"], ["cover", T.t("Pochette")], ["blur", T.t("Flou")], ["gradient", T.t("Dégradé")]]
            value: String(root.val("spotify.wallpaper", "off"))
            onPicked: function(v) { root.set("spotify.wallpaper", v) }
          }
        }
      }
      SectionTitle { text: T.t("Fonds d'écran") }
      // Filtre par catégorie (pastilles, avec le nombre de fonds).
      Flow {
        width: parent.width
        spacing: Style.space(6)
        Repeater {
          model: root.bgCats.filter(function(c) { return root.bgCount(c[0]) > 0 })
          delegate: Rectangle {
            id: chipC
            required property var modelData
            readonly property bool on: root.bgFilter === modelData[0]
            width: chipT.implicitWidth + Style.space(20); height: Style.space(24); radius: height / 2
            color: on ? root.accent : Qt.rgba(root.fg.r, root.fg.g, root.fg.b, chipM.containsMouse ? 0.14 : 0.08)
            Behavior on color { ColorAnimation { duration: 140 } }
            scale: chipM.pressed ? 0.9 : 1
            Behavior on scale { NumberAnimation { duration: 280; easing.type: Easing.OutBack; easing.overshoot: 3 } }
            Text {
              id: chipT; anchors.centerIn: parent; textFormat: Text.PlainText
              text: chipC.modelData[1] + "  " + root.bgCount(chipC.modelData[0])
              font.family: root.uiFont; font.pixelSize: Style.space(11.5); font.weight: Font.Medium
              color: chipC.on ? "white" : root.fg
            }
            MouseArea { id: chipM; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.bgFilter = chipC.modelData[0] }
          }
        }
      }
      Grid {
        id: bgGrid
        width: parent.width
        columns: 3
        spacing: Style.space(10)
        readonly property real cw: (width - 2 * spacing) / 3
        Repeater {
          model: root.shownBackgrounds.slice(0, root.bgLimit)
          delegate: Column {
            id: bgItem
            required property var modelData
            readonly property bool on: modelData === root.currentBg
            spacing: Style.space(4)
            Rectangle {
              width: bgGrid.cw; height: bgGrid.cw * 0.6; radius: Style.space(10)
              color: Qt.rgba(root.fg.r, root.fg.g, root.fg.b, 0.08)
              border.width: bgItem.on ? 3 : 0
              border.color: root.accent
              clip: true
              Image { anchors.fill: parent; anchors.margins: bgItem.on ? 3 : 0; source: root.bgThumb(bgItem.modelData); fillMode: Image.PreserveAspectCrop; sourceSize: Qt.size(320, 200); asynchronous: true; cache: false
                      onStatusChanged: if (status === Image.Error && !root.isVideo(bgItem.modelData)) source = "file://" + bgItem.modelData }
              // Pastille « animé » sur les fonds vidéo.
              Rectangle {
                visible: root.isVideo(bgItem.modelData)
                anchors.left: parent.left; anchors.bottom: parent.bottom; anchors.margins: Style.space(6)
                width: animTxt.implicitWidth + Style.space(12); height: Style.space(16); radius: height / 2
                color: Qt.rgba(0, 0, 0, 0.5)
                Text { id: animTxt; anchors.centerIn: parent; textFormat: Text.PlainText; text: root.g(0xF040A) + " Animé"; font.family: root.iconFont; font.pixelSize: Style.space(9); color: "white" }
              }
              scale: bgMouse.pressed ? 0.92 : (bgMouse.containsMouse ? 1.04 : 1)
              Behavior on scale { NumberAnimation { duration: 340; easing.type: Easing.OutBack; easing.overshoot: 2.6 } }
              MouseArea { id: bgMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: { root.currentBg = bgItem.modelData; root.launch(["omarchy", "theme", "bg", "set", bgItem.modelData]) } }
            }
            Text { width: bgGrid.cw; horizontalAlignment: Text.AlignHCenter; elide: Text.ElideMiddle; textFormat: Text.PlainText; text: bgItem.modelData.split("/").pop().replace(/\.[^.]+$/, ""); font.family: root.uiFont; font.pixelSize: Style.space(10); color: root.fg; opacity: 0.6 }
          }
        }
      }
      Rectangle {
        visible: root.shownBackgrounds.length > root.bgLimit
        anchors.horizontalCenter: parent.horizontalCenter
        width: moreT.implicitWidth + Style.space(28); height: Style.space(30); radius: height / 2
        color: moreM.containsMouse ? Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.25) : Qt.rgba(root.fg.r, root.fg.g, root.fg.b, 0.08)
        Text {
          id: moreT; anchors.centerIn: parent; textFormat: Text.PlainText
          text: T.t("Afficher plus") + "  (" + (root.shownBackgrounds.length - root.bgLimit) + ")"
          font.family: root.uiFont; font.pixelSize: Style.space(11.5); font.weight: Font.Medium; color: root.fg
        }
        MouseArea { id: moreM; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.bgLimit += 48 }
      }
    }
  }

  Component {
    id: pNotifications
    Column {
      spacing: Style.space(14)
      Group {
        Row_ {
          label: T.t("Ne pas déranger")
          sub: T.t("Les notifications sont silencieuses")
          icon: 0xF0594; iconColor: "#5e5ce6"
          Switch_ { checked: root.dnd; onToggled: function(v) { root.dnd = v; root.run(["omarchy-shell", "notifications", "setDnd", v ? "on" : "off"]) } }
        }
      }
      SectionTitle { text: T.t("Écran verrouillé") }
      Group {
        Row_ {
          label: T.t("Aperçu des notifications")
          Seg {
            options: [["full", T.t("Complet")], ["summary", T.t("Résumé")], ["count", T.t("Nombre")], ["off", T.t("Aucun")]]
            value: String(root.val("lock.notifications", "summary"))
            onPicked: function(v) { root.set("lock.notifications", v) }
          }
        }
      }
      Btn { text: T.t("Historique des notifications"); secondary: true; onClicked: { root.dismiss(); root.launch(["omarchy-shell", "notifications", "showHistory"]) } }
    }
  }

  Component {
    id: pSound
    Column {
      spacing: Style.space(14)
      Group {
        Row_ {
          label: T.t("Volume de sortie")
          icon: 0xF057E; iconColor: "#ff2d55"
          LiveSlider {
            value: root.sink && root.sink.audio ? Math.min(1, root.sink.audio.volume) : 0
            onMoved: function(v) { if (root.sink && root.sink.audio) { root.sink.audio.muted = false; root.sink.audio.volume = v } }
          }
        }
        Row_ {
          label: T.t("Muet")
          Switch_ { checked: !!(root.sink && root.sink.audio && root.sink.audio.muted); onToggled: function(v) { if (root.sink && root.sink.audio) root.sink.audio.muted = v } }
        }
      }
      SectionTitle { text: T.t("Sortie") }
      Group {
        Repeater {
          model: root.sinks
          delegate: Row_ {
            required property var modelData
            label: modelData.description || modelData.nickname || modelData.name
            icon: 0xF04C3; iconColor: modelData === root.sink ? "#ff2d55" : "#8e8e93"
            Dot { visible: modelData === root.sink; on: true }
            Btn { visible: modelData !== root.sink; text: T.t("Utiliser"); secondary: true; onClicked: Pipewire.preferredDefaultAudioSink = modelData }
          }
        }
      }
    }
  }

  Component {
    id: pFocus
    Column {
      spacing: Style.space(14)
      Hint { text: T.t("Un mode de concentration coupe les notifications. Sommeil active aussi Night Shift.") }
      Group {
        Repeater {
          model: [["dnd", T.t("Ne pas déranger"), 0xF0594, "#5e5ce6"], ["work", T.t("Travail"), 0xF0D6B, "#30b0c7"],
                  ["personal", T.t("Personnel"), 0xF0004, "#bf5af2"], ["sleep", T.t("Sommeil"), 0xF04B2, "#64d2ff"]]
          delegate: Row_ {
            required property var modelData
            label: modelData[1]
            icon: modelData[2]; iconColor: modelData[3]
            Switch_ {
              checked: root.focusMode === modelData[0]
              onToggled: function(v) { root.focusMode = v ? modelData[0] : "off"; root.run(["liquid-glass", "focus", v ? modelData[0] : "off"]) }
            }
          }
        }
      }
    }
  }

  Component {
    id: pMusic
    Column {
      spacing: Style.space(14)
      Group {
        ToggleRow { label: T.t("Couleurs de la pochette"); key: "spotify.dynamic_colors"; def: true; sub: T.t("Accent, bordures, barre, dock et terminal"); icon: 0xF03D8; iconColor: "#ff9f0a" }
        SliderRow { label: T.t("Retour au fond après pause"); key: "spotify.restore_after_minutes"; from: 0; to: 30; step: 1; def: 5; fmt: function(v) { return v === 0 ? T.t("Jamais") : v + " min" } }
      }
      SectionTitle { text: T.t("Paroles") }
      Group {
        ToggleRow { label: T.t("Sur le bureau, en grand"); key: "lyrics.desktop"; def: false; sub: T.t("Derrière les fenêtres") }
        ToggleRow { label: T.t("Widget flottant"); key: "lyrics.widget"; def: false; sub: T.t("Carte déplaçable ; double-clic pour le karaoké") }
        ToggleRow { label: T.t("Dans la barre"); key: "lyrics.bar"; def: true }
        Row_ { label: T.t("Karaoké plein écran"); Btn { text: T.t("Ouvrir  ⌘⌥M"); secondary: true; onClicked: { root.dismiss(); root.launch(["omarchy-shell", "liquid-glass.spotify", "karaoke"]) } } }
      }
      SectionTitle { text: T.t("Visualiseur") }
      Group {
        ToggleRow { label: T.t("Visualiseur audio"); key: "visualizer.enabled"; def: false; sub: T.t("cava en bas du fond d'écran pendant la lecture") }
        SliderRow { label: T.t("Nombre de barres"); key: "visualizer.bars"; from: 16; to: 128; step: 8; def: 64 }
      }
      Hint { text: T.t("Paroles synchronisées fournies par LRCLIB (gratuit, sans compte), mises en cache dans ~/.cache/liquid-glass.") }
    }
  }

  Component {
    id: pLock
    Column {
      spacing: Style.space(14)
      // Profil Linux : quel écran, vidéo de fond, mouvement, écran de veille.
      Group {
        Row_ {
          label: T.t("Écran (bureau Linux)")
          sub: T.t("Automatique : celui du style de bureau")
          Picker {
            options: [["auto", T.t("Automatique")], ["classic", T.t("Bonbon")], ["mono", "Mono (Caelestia)"], ["foret", T.t("Forêt")],
                      ["ile", T.t("Île")], ["ruban", T.t("Rubans")], ["espace", T.t("Espace")], ["sombre", T.t("Sombre")], ["blanc", T.t("Blanc")],
                      ["jouet", T.t("Jouet")], ["windows", "Windows"], ["lain", "Lain"], ["expressive", "Expressive"], ["hud", "7JOKS"], ["infini", T.t("Infini")]]
            value: String(root.val("lock.linux_face", "auto"))
            onPicked: function(v) { root.set("lock.linux_face", v) }
          }
        }
        Row_ {
          label: T.t("Vidéo de fond")
          sub: String(root.val("lock.video", "")) !== "" ? String(root.val("lock.video", "")).replace(/^.*\//, "") : T.t("Aucune : le fond d'écran (s'il est une vidéo, elle joue)")
          Row {
            spacing: Style.space(6)
            Btn {
              text: T.t("Choisir…"); secondary: true
              onClicked: root.run(["sh", "-c", "f=$(zenity --file-selection --title='Vidéo du verrouillage' --file-filter='Vidéos | *.mp4 *.webm *.mkv *.mov *.gif') && \"$HOME/.local/bin/liquid-glass\" set lock.video \"$f\""])
            }
            Btn {
              visible: String(root.val("lock.video", "")) !== ""
              text: T.t("Retirer"); secondary: true
              onClicked: root.set("lock.video", "")
            }
          }
        }
        ToggleRow { label: T.t("Fond qui bouge lentement"); key: "lock.drift"; def: true; sub: T.t("Zoom et glissement très lents de l'image") }
        ToggleRow { label: T.t("Écran de veille feu ASCII"); key: "lock.saver"; def: true; sub: T.t("Après une minute sans rien toucher") }
      }
      Group {
        Row_ {
          label: T.t("Lecture en cours")
          sub: T.t("Position ; se déplace aussi au doigt")
          Seg {
            options: [["clock", T.t("Sous l'horloge")], ["password", T.t("Au-dessus du mot de passe")]]
            value: String(root.val("lock.music_position", "password"))
            onPicked: function(v) { root.set("lock.music_position", v); root.set("lock.music_x", -1); root.set("lock.music_y", -1) }
          }
        }
        ToggleRow { label: T.t("Widget musique"); key: "lock.music_card"; def: true; sub: T.t("La bulle l'agrandit") }
        ToggleRow { label: T.t("Garder le dernier morceau"); key: "lock.music_last"; def: true; sub: T.t("Spotify fermé : la carte reste avec la dernière chanson, ▶ la relance (fond pochette et paroles reviennent)") }
        Row_ {
          label: T.t("Fond quand la pochette est agrandie")
          Seg {
            options: [["art", T.t("Pochette floue")], ["off", T.t("Fond normal")]]
            value: String(root.val("lock.music_background", "art")) === "off" ? "off" : "art"
            onPicked: function(v) { root.set("lock.music_background", v) }
          }
        }
        ToggleRow { label: T.t("Paroles synchronisées"); key: "lock.lyrics"; def: true; sub: T.t("À côté du widget agrandi") }
        ToggleRow { label: T.t("Horloge 24 heures"); key: "lock.clock_24h"; def: true }
        ToggleRow { label: T.t("Fond d'écran flouté"); key: "lock.wallpaper_blur"; def: false }
        ToggleRow { label: T.t("Batterie en haut à droite"); key: "lock.status"; def: true }
      }
      SectionTitle { text: T.t("Horloge") }
      Row {
        spacing: Style.space(10)
        Repeater {
          model: [["glass", T.t("Verre")], ["bold", T.t("Classique")], ["serif", "Serif"], ["liquid", T.t("Liquide")], ["light", T.t("Fine")]]
          delegate: Column {
            id: cs
            required property var modelData
            readonly property bool on: String(root.val("lock.clock_style", "glass")) === modelData[0]
            spacing: Style.space(4)
            Rectangle {
              width: Style.space(84); height: Style.space(56); radius: Style.space(12)
              clip: true
              border.width: cs.on ? 3 : 0; border.color: root.accent
              Image { anchors.fill: parent; source: root.currentBg ? "file://" + root.currentBg : ""; fillMode: Image.PreserveAspectCrop; sourceSize: Qt.size(200, 130); asynchronous: true }
              Text {
                anchors.centerIn: parent
                textFormat: Text.PlainText
                text: "9:41"
                font.family: cs.modelData[0] === "serif" ? "Noto Serif" : (String(root.val("lock.clock_font", "")) || root.uiFont)
                font.pixelSize: Style.space(23)
                font.weight: cs.modelData[0] === "light" ? Font.Thin : (cs.modelData[0] === "serif" ? Font.Medium : (cs.modelData[0] === "bold" ? Font.Bold : Font.DemiBold))
                color: cs.modelData[0] === "liquid" ? Qt.rgba(1, 1, 1, 0.22) : "white"
                opacity: cs.modelData[0] === "glass" ? 0.85 : 1
                style: cs.modelData[0] === "liquid" ? Text.Outline : Text.Raised
                styleColor: cs.modelData[0] === "liquid" ? Qt.rgba(1, 1, 1, 0.9) : Qt.rgba(0, 0, 0, 0.25)
              }
              scale: csMouse.pressed ? 0.9 : 1
              Behavior on scale { NumberAnimation { duration: 320; easing.type: Easing.OutBack; easing.overshoot: 3 } }
              MouseArea { id: csMouse; anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.set("lock.clock_style", cs.modelData[0]) }
            }
            Text { anchors.horizontalCenter: parent.horizontalCenter; textFormat: Text.PlainText; text: cs.modelData[1]; font.family: root.uiFont; font.pixelSize: Style.space(11); font.weight: cs.on ? Font.DemiBold : Font.Normal; color: root.fg }
          }
        }
      }
      Group {
        FontRow { label: T.t("Police de l'horloge"); key: "lock.clock_font"; def: ""; allowDefault: true }
        SliderRow {
          label: T.t("Graisse"); key: "lock.clock_weight"; from: 100; to: 900; step: 100
          def: ({ light: 100, serif: 500, bold: 700 })[String(root.val("lock.clock_style", "glass"))] || 600
          fmt: function(v) { return ({ 100: T.t("Fine"), 200: T.t("Très légère"), 300: T.t("Légère"), 400: T.t("Normale"), 500: T.t("Moyenne"), 600: T.t("Demi-grasse"), 700: T.t("Grasse"), 800: T.t("Très grasse"), 900: T.t("Épaisse") })[v] || String(v) }
        }
        SliderRow { label: T.t("Luminosité"); key: "lock.clock_brightness"; from: 0.4; to: 1; step: 0.05; def: 1; fmt: function(v) { return v <= 0.55 ? T.t("Discrète") : (v >= 0.95 ? T.t("Vive") : Math.round(v * 100) + " %") } }
        Row_ {
          label: T.t("Couleur")
          Row {
            spacing: Style.space(7)
            Repeater {
              model: ["#ffffff", "#ffe3c2", "#ffc4cf", "#e3cbff", "#c4dcff", "#bff3ee", "#e8f7b8"]
              delegate: Rectangle {
                id: cdot
                required property var modelData
                readonly property bool on: String(root.val("lock.clock_color", "#ffffff")).toLowerCase() === modelData
                width: Style.space(18); height: width; radius: width / 2
                color: modelData
                border.width: on ? 2 : 1
                border.color: on ? root.accent : Qt.rgba(0, 0, 0, 0.15)
                scale: cdMouse.pressed ? 0.8 : (on ? 1.15 : 1)
                Behavior on scale { NumberAnimation { duration: 320; easing.type: Easing.OutBack; easing.overshoot: 3 } }
                MouseArea { id: cdMouse; anchors.fill: parent; anchors.margins: -3; cursorShape: Qt.PointingHandCursor; onClicked: root.set("lock.clock_color", cdot.modelData) }
              }
            }
          }
        }
        ToggleRow { label: T.t("Chiffres hauts"); key: "lock.clock_tall"; def: false; sub: T.t("Étire les chiffres pour remplir l'espace, comme iOS 26") }
        Row_ {
          label: "Date"
          Seg {
            readonly property date now: new Date()
            options: [["long", (function(t) { return t.charAt(0).toUpperCase() + t.slice(1) })(Qt.locale(T.loc).toString(now, "dddd d MMMM"))],
                      ["short", (function(t) { return t.charAt(0).toUpperCase() + t.slice(1) })(Qt.locale(T.loc).toString(now, "ddd d MMM"))]]
            value: String(root.val("lock.date_format", "long"))
            onPicked: function(v) { root.set("lock.date_format", v) }
          }
        }
      }
      Row {
        spacing: Style.space(8)
        Btn { text: T.t("Aperçu"); secondary: true; onClicked: { root.dismiss(); root.launch(["sh", "-c", "omarchy-shell lock preview; sleep 8; omarchy-shell lock hidePreview"]) } }
        Btn { text: T.t("Verrouiller maintenant"); onClicked: { root.dismiss(); root.launch(["omarchy-shell", "lock", "lock"]) } }
        Btn { text: T.t("Replacer le widget"); secondary: true; onClicked: { root.set("lock.music_x", -1); root.set("lock.music_y", -1) } }
      }
    }
  }

  Component {
    id: pUsers
    Column {
      spacing: Style.space(14)
      Item {
        width: parent.width; height: Style.space(120)
        Column {
          anchors.centerIn: parent
          spacing: Style.space(6)
          Avatar { anchors.horizontalCenter: parent.horizontalCenter; side: Style.space(72) }
          Text { anchors.horizontalCenter: parent.horizontalCenter; textFormat: Text.PlainText; text: root.displayName; font.family: root.uiFont; font.pixelSize: Style.space(16); font.weight: Font.Bold; color: root.fg }
        }
      }
      Group {
        Row_ { label: T.t("Nom complet"); Label_ { text: root.fullName || "—" } }
        Row_ { label: T.t("Nom du compte"); Label_ { text: root.userName } }
        Row_ { label: T.t("Dossier de départ"); Label_ { text: root.home } }
        Row_ {
          label: "Photo"
          sub: T.t("Affichée sur l'écran verrouillé (~/.face)")
          Btn {
            text: T.t("Changer…"); secondary: true
            onClicked: root.run(["sh", "-c", "f=$(zenity --file-selection --title='Photo du compte' --file-filter='Images | *.png *.jpg *.jpeg *.webp') && magick \"$f\" -resize 256x256^ -gravity center -extent 256x256 \"$HOME/.face.png\" && mv \"$HOME/.face.png\" \"$HOME/.face\""])
          }
        }
      }
    }
  }

  // ---------------------------------------------------------- Accessibilité
  Component {
    id: pAccess
    Column {
      spacing: Style.space(14)
      SectionTitle { text: T.t("Vue") }
      Group {
        Row_ {
          label: "Zoom"; sub: T.t("⌥⌘8 pour activer, ⌥⌘ + molette pour agrandir ou réduire")
          icon: 0xF0349; iconColor: "#0a84ff"
          Btn { text: T.t("Activer / désactiver"); secondary: true; onClicked: { root.zoomOn = !root.zoomOn; root.launch(["hyprctl", "eval", "hl.config({ cursor = { zoom_factor = " + (root.zoomOn ? 2 : 1) + " } })"]) } }
        }
        SliderRow {
          label: T.t("Taille du pointeur"); key: "access.cursor_size"; from: 24; to: 64; step: 4; def: 24
          fmt: function(v) { return v + " px" }
        }
        Row_ {
          label: T.t("Appliquer la taille du pointeur")
          Btn { text: T.t("Appliquer"); secondary: true; onClicked: root.launch(["hyprctl", "setcursor", "MacTahoe-cursors", String(root.val("access.cursor_size", 24))]) }
        }
      }
      SectionTitle { text: T.t("Affichage") }
      Group {
        Row_ {
          label: T.t("Réduire la transparence"); sub: T.t("Verre teinté et plus opaque partout")
          Switch_ { checked: Number(root.val("glass.tint", 0.5)) >= 0.99; onToggled: function(v) { root.set("glass.tint", v ? 1 : 0.5) } }
        }
        Row_ {
          label: T.t("Réduire les animations"); sub: T.t("Coupe les animations à ressort des fenêtres")
          Switch_ { checked: root.val("glass.animations", true) === false; onToggled: function(v) { root.set("glass.animations", !v) } }
        }
        Row_ {
          label: T.t("Mode sombre")
          Switch_ { checked: root.val("appearance.mode", "light") === "dark"; onToggled: function(v) { root.set("appearance.mode", v ? "dark" : "light") } }
        }
      }
    }
  }
  property bool zoomOn: false

  // ---------------------------------------------------------- Claude (à la place de Siri)
  Component {
    id: pClaude
    Column {
      spacing: Style.space(14)
      Item {
        width: parent.width; height: Style.space(130)
        Column {
          anchors.centerIn: parent; spacing: Style.space(6)
          Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            width: Style.space(64); height: width; radius: width * 0.24
            gradient: Gradient {
              GradientStop { position: 0; color: "#d97757" }
              GradientStop { position: 1; color: "#bf5af2" }
            }
            Text { anchors.centerIn: parent; text: root.g(0xF0674); font.family: root.iconFont; font.pixelSize: Style.space(34); color: "white" }
          }
          Text { anchors.horizontalCenter: parent.horizontalCenter; text: T.t("Claude"); font.family: root.uiFont; font.pixelSize: Style.space(17); font.weight: Font.Bold; color: root.fg }
          Text { anchors.horizontalCenter: parent.horizontalCenter; text: T.t("Comme Siri dans macOS 27 : « Rechercher ou demander » dans Spotlight"); font.family: root.uiFont; font.pixelSize: Style.space(11); color: root.fg; opacity: 0.6 }
        }
      }
      Group {
        ToggleRow { label: T.t("Demander à Claude dans Spotlight"); key: "spotlight.ask"; def: true; sub: T.t("⌘Espace, tapez une question puis ⇥ ou « Demander à Claude »"); icon: 0xF0674; iconColor: "#bf5af2" }
        Row_ {
          label: T.t("Modèle")
          Seg {
            options: [["haiku", "Haiku"], ["sonnet", "Sonnet"], ["opus", "Opus"]]
            value: root.val("spotlight.ask_model", "haiku")
            onPicked: function(v) { root.set("spotlight.ask_model", v) }
          }
        }
        Row_ {
          label: T.t("Ouvrir Claude Code"); sub: T.t("Le bouton Claude de la barre des menus")
          Btn { text: T.t("Ouvrir"); secondary: true; onClicked: { root.dismiss(); root.launch(["omarchy-agent", "--pick"]) } }
        }
      }
      Hint { text: T.t("Les réponses passent par le CLI « claude » déjà connecté à votre compte ; rien d'autre n'est envoyé.") }
    }
  }

  // ---------------------------------------------------------- Touch ID et mot de passe
  Component {
    id: pTouch
    Column {
      id: touchCol
      spacing: Style.space(14)
      property string fp: ""
      Process {
        running: true
        command: ["sh", "-c", "command -v fprintd-list >/dev/null && fprintd-list \"$USER\" 2>&1 | grep -c 'finger' || echo none"]
        stdout: StdioCollector { onStreamFinished: touchCol.fp = text.trim() }
      }
      Group {
        Row_ {
          label: T.t("Mot de passe de session"); icon: 0xF033E; iconColor: "#8e8e93"
          Btn { text: T.t("Changer…"); secondary: true; onClicked: { root.dismiss(); root.launch(["xdg-terminal-exec", "sh", "-c", "passwd; echo; read -p 'Entrée pour fermer'"]) } }
        }
      }
      SectionTitle { text: "Touch ID" }
      Group {
        Row_ {
          label: T.t("Empreintes digitales"); icon: 0xF0237; iconColor: "#ff375f"
          sub: touchCol.fp === "none" ? T.t("fprintd n'est pas installé") : (Number(touchCol.fp) > 0 ? touchCol.fp + T.t(" empreinte(s) enregistrée(s)") : T.t("Aucune empreinte"))
          Btn { text: T.t("Ajouter une empreinte…"); secondary: true; onClicked: { root.dismiss(); root.launch(["xdg-terminal-exec", "sh", "-c", "fprintd-enroll; echo; read -p 'Entrée pour fermer'"]) } }
        }
        Row_ { label: T.t("Déverrouiller avec Touch ID"); sub: T.t("Automatique sur l'écran verrouillé dès qu'une empreinte est enregistrée"); Label_ { text: Number(touchCol.fp) > 0 ? T.t("Activé") : T.t("Désactivé") } }
      }
    }
  }

  // ---------------------------------------------------------- Langue et région
  Component {
    id: pLanguage
    Column {
      id: lang
      spacing: Style.space(14)
      readonly property var all: [["ch:fr", T.t("Suisse romand")], ["ch:", T.t("Suisse alémanique")], ["fr:", T.t("Français (AZERTY)")],
        ["us:", T.t("Anglais (É.-U.)")], ["us:intl", T.t("Anglais international")], ["gb:", T.t("Anglais (R.-U.)")], ["de:", T.t("Allemand")],
        ["es:", T.t("Espagnol")], ["it:", T.t("Italien")], ["pt:", T.t("Portugais")], ["ru:", T.t("Russe")], ["ara:", T.t("Arabe")], ["jp:", T.t("Japonais")]]
      readonly property var layouts: { var l = root.val("language.layouts", []); return l && l.length ? l : ["ch:fr"] }
      function label(code) { for (var i = 0; i < all.length; i++) if (all[i][0] === code || all[i][0] === code + ":") return all[i][1]; return code }
      function setLayouts(l) { root.set("language.layouts", l) }
      SectionTitle { text: T.t("Langues préférées") }
      Group {
        Row_ {
          label: T.t("Langue de l'interface"); icon: 0xF05CA; iconColor: "#0a84ff"
          Seg {
            options: [["fr", "Français"], ["en", "English"]]
            value: root.val("linux.lang", "fr")
            onPicked: function(v) { root.set("linux.lang", v); root.launch(["liquid-glass", "lang", v]) }
          }
        }
      }
      SectionTitle { text: T.t("Sources de saisie") }
      Group {
        Repeater {
          model: lang.layouts
          Row_ {
            id: lr
            required property var modelData
            required property int index
            label: lang.label(modelData)
            sub: index === 0 ? T.t("Par défaut") : ""
            icon: 0xF030C; iconColor: "#8e8e93"
            Btn { visible: lang.layouts.length > 1; text: T.t("Retirer"); secondary: true; onClicked: { var l = lang.layouts.slice(); l.splice(lr.index, 1); lang.setLayouts(l) } }
          }
        }
        Row_ { label: T.t("Ajouter une source"); sub: T.t("Cliquez sur un clavier pour l'ajouter") }
        // Toutes les dispositions restantes, en pastilles (noms complets, comme la liste de macOS).
        Item {
          width: parent ? parent.width : 0
          height: addFlow.implicitHeight + Style.space(12)
          Flow {
            id: addFlow
            x: Style.space(12); width: parent.width - Style.space(24)
            spacing: Style.space(6)
            Repeater {
              model: lang.all.filter(function(x) { return lang.layouts.indexOf(x[0]) < 0 && lang.layouts.indexOf(x[0].replace(/:$/, "")) < 0 })
              Btn {
                required property var modelData
                text: "+ " + modelData[1]; secondary: true
                onClicked: lang.setLayouts(lang.layouts.concat([modelData[0].replace(/:$/, "")]))
              }
            }
          }
        }
        ToggleRow { label: T.t("Afficher la source dans l'île"); key: "island.input"; def: true; sub: T.t("⌃Espace passe à la source suivante") }
      }
      SectionTitle { text: T.t("Région") }
      Group {
        ToggleRow { label: T.t("Horloge 24 heures"); key: "menubar.clock_24h"; def: true }
        ToggleRow { label: T.t("La semaine commence le lundi"); key: "menubar.week_monday"; def: true }
      }
    }
  }

  // ---------------------------------------------------------- Imprimantes
  Component {
    id: pPrinters
    Column {
      id: prn
      spacing: Style.space(14)
      property var list: []
      property bool cups: true
      Process {
        running: true
        command: ["sh", "-c", "command -v lpstat >/dev/null || { echo NOCUPS; exit; }; lpstat -p 2>/dev/null | awk '$1==\"printer\"{print $2}'"]
        stdout: StdioCollector { onStreamFinished: { var t = text.trim(); prn.cups = t !== "NOCUPS"; prn.list = prn.cups && t ? t.split("\n") : [] } }
      }
      Group {
        Repeater {
          model: prn.list
          Row_ { required property string modelData; label: modelData; icon: 0xF042A; iconColor: "#8e8e93"; Label_ { text: T.t("Prête") } }
        }
        Row_ {
          visible: prn.list.length === 0
          label: prn.cups ? T.t("Aucune imprimante") : T.t("CUPS n'est pas installé")
          sub: prn.cups ? "" : "sudo pacman -S cups system-config-printer"
          icon: 0xF042A; iconColor: "#8e8e93"
        }
        Row_ {
          label: T.t("Ajouter une imprimante, un scanner ou un fax…")
          Btn { text: T.t("Ajouter…"); secondary: true; onClicked: { root.dismiss(); root.launch(["sh", "-c", "system-config-printer || xdg-open http://localhost:631"]) } }
        }
      }
    }
  }

  // ---------------------------------------------------------- Alcove (île dynamique)
  Component {
    id: pAlcove
    Column {
      spacing: Style.space(14)
      Group {
        ToggleRow { label: T.t("Activer Alcove"); key: "island.enabled"; def: true; sub: T.t("L'encoche devient une île dynamique : survol pour agrandir, clic pour les commandes"); icon: 0xF0402; iconColor: "#1c1c1e" }
        Row_ {
          label: T.t("Au repos")
          visible: root.val("island.enabled", true) === true
          Seg {
            options: [["hidden", T.t("Masquée")], ["notch", T.t("Encoche")]]
            value: root.val("island.idle", "hidden")
            onPicked: function(v) { root.set("island.idle", v) }
          }
        }
      }
      SectionTitle { text: T.t("Activités") }
      Group {
        ToggleRow { label: T.t("Lecture en cours"); key: "island.music"; def: true; sub: T.t("Pochette et égaliseur aux couleurs de la pochette") }
        ToggleRow { label: T.t("Paroles"); key: "island.lyrics"; def: true; sub: T.t("L'île s'élargit et la ligne chantée défile dedans") }
        ToggleRow { label: T.t("Batterie et secteur"); key: "island.battery"; def: true; sub: T.t("Branchement et débranchement, avec le niveau") }
        ToggleRow { label: T.t("Appareils Bluetooth"); key: "island.bluetooth"; def: true; sub: T.t("Casque connecté, avec sa batterie") }
        ToggleRow { label: T.t("Concentration"); key: "island.focus"; def: true }
        ToggleRow { label: T.t("Source de saisie"); key: "island.input"; def: true; sub: T.t("⌃Espace") }
      }
      SectionTitle { text: "HUD" }
      Group {
        ToggleRow { label: T.t("Volume dans l'île"); key: "island.hud"; def: false; sub: T.t("Remplace l'OSD au-dessus du Dock") }
      }
      Hint { text: T.t("Molette sur l'île : volume. Balayage horizontal : morceau suivant ou précédent. Clic droit : ces réglages.") }
    }
  }

  // ---------------------------------------------------------- Klack (sons du clavier)
  Component {
    id: pKlack
    Column {
      id: kl
      spacing: Style.space(14)
      property var packs: []
      Process {
        running: true
        command: ["sh", "-c", "ls \"$HOME/.local/share/liquid-glass/keysounds\" 2>/dev/null"]
        stdout: StdioCollector { onStreamFinished: kl.packs = text.trim() ? text.trim().split("\n") : [] }
      }
      Item {
        width: parent.width; height: Style.space(110)
        Column {
          anchors.centerIn: parent; spacing: Style.space(6)
          Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            width: Style.space(58); height: width; radius: width * 0.24
            gradient: Gradient { GradientStop { position: 0; color: "#ffb340" } GradientStop { position: 1; color: "#ff7a1a" } }
            Text { anchors.centerIn: parent; text: root.g(0xF030C); font.family: root.iconFont; font.pixelSize: Style.space(30); color: "white" }
          }
          Text { anchors.horizontalCenter: parent.horizontalCenter; text: "Klack"; font.family: root.uiFont; font.pixelSize: Style.space(17); font.weight: Font.Bold; color: root.fg }
        }
      }
      Group {
        Row_ {
          label: T.t("Sons du clavier")
          sub: T.t("Sans aucun accès donné aux apps : Hyprland signale seulement « une touche »")
          Switch_ { checked: root.val("keys.sound", false) === true; onToggled: function(v) { root.set("keys.sound", v); root.launch(["liquid-glass", "keys", v ? "on" : "off"]) } }
        }
        SliderRow { label: "Volume"; key: "keys.sound_volume"; from: 0; to: 1; step: 0.05; def: 0.6; fmt: function(v) { return Math.round(v * 100) + " %" } }
        ToggleRow { label: T.t("Son au relâchement"); key: "keys.sound_release"; def: true }
        ToggleRow { label: T.t("Clics de la souris"); key: "keys.sound_mouse"; def: true }
      }
      SectionTitle { text: T.t("Clavier") }
      Group {
        Repeater {
          model: ["auto", "creamy", "thocky", "clicky"].concat(kl.packs)
          Row_ {
            id: kp
            required property string modelData
            label: modelData === "auto" ? T.t("Celui de Mechvibes") : modelData.replace(/-/g, " ")
            Switch_ { checked: String(root.val("keys.sound_pack", "auto")) === kp.modelData; onToggled: function(v) { if (v) root.set("keys.sound_pack", kp.modelData) } }
          }
        }
        Row_ {
          label: T.t("Écouter"); sub: T.t("Joue quelques touches avec le clavier choisi")
          Btn { text: T.t("Essai"); secondary: true; onClicked: root.launch(["liquid-glass", "keys", "test"]) }
        }
      }
    }
  }

  Component {
    id: pLinux
    Column {
      id: lp
      spacing: Style.space(14)
      readonly property bool active: root.val("profile.active", "mac") === "linux"
      readonly property string st: root.val("linux.style", "blanc")
      // Valeur par défaut d'un réglage musique selon le style (comme le service).
      function sdef(m) { return m[lp.st] !== undefined ? m[lp.st] : m["*"] }
      // Réglage propre au thème affiché : linux.<style>__<clé> (la valeur commune sert de base).
      function k(n) { return "linux." + lp.st + "__" + n }
      // Sur le bureau Linux, un style passe par la CLI (thème, fonds, bordures) ;
      // sur le Mac, on le note seulement pour la prochaine bascule.
      function pick(arg, key, v) { if (lp.active) root.launch(["liquid-glass", "profile", arg]); else root.set(key, v) }
      Group {
        Row_ {
          label: lp.active ? T.t("Bureau Linux actif") : T.t("Bureau Mac actif")
          sub: T.t("⌘⇧Espace ouvre le sélecteur : Mac, Omarchy d'origine, Windows, Mono, Forêt, Blanc, Sombre, Jouet, Violet, Expressive. ⌃⌘T change la teinte.")
          Btn { text: T.t("Choisir un bureau  ⌘⇧␣"); onClicked: { root.dismiss(); root.launch(["liquid-glass", "profile", "pick"]) } }
        }
      }
      // ---------------- réglages propres au thème (chacun a les siens)
      // [type, clé, libellé, sous-titre, défaut, extra] ; type : t (interrupteur), s (curseur
      // [de, à, pas, format]), b (bouton : commande). Les clés sont lues par le style.
      readonly property var own: ({
        infini: [["t", "infini_clock", T.t("Horloge sur la toile"), T.t("Heures sur minutes, au centre de la toile"), true],
                 ["t", "infini_frame", T.t("Cadre du visualiseur"), T.t("Posé sur la toile, il suit le glisser et le zoom"), true],
                 ["t", "infini_viz", T.t("Visualiseur du bas"), T.t("Sur toute la largeur, sous la barre"), true],
                 ["t", "infini_zoom_windows", T.t("Zoomer aussi les fenêtres"), T.t("⌘ + molette, ⌘ + pincer, ⌘⌃Z / ⌘⌃⇧Z : les fenêtres rapetissent avec la toile"), true],
                 ["s", "infini_zoom_speed", T.t("Vitesse du zoom"), "", 1.08, [1.02, 1.25, 0.01, "pct"]],
                 ["t", "infini_dblclick", T.t("Double-clic : retour au centre"), T.t("Et zoom à 100 %"), true],
                 ["t", "infini_pos", T.t("Position dans la barre"), T.t("Coordonnées et zoom, clic pour revenir"), true]],
        windows: [["c", "windows_align", T.t("Alignement de la barre des tâches"), "", "center", [["center", T.t("Centre")], ["left", T.t("Gauche")]]],
                  ["t", "windows_weather", T.t("Météo dans la barre"), T.t("À gauche (pas avec l'alignement à gauche)"), true],
                  ["t", "windows_search", T.t("Rechercher"), T.t("La pilule de recherche à côté de Démarrer"), true],
                  ["t", "windows_taskview", T.t("Vue des tâches"), "", true],
                  ["t", "windows_icons", T.t("Icônes du bureau"), T.t("Ce PC, Corbeille, Documents…"), true]],
        hud: [["t", "hud_globe", T.t("Globe"), T.t("Vue du monde en fil de fer, à droite"), true],
              ["t", "hud_files", T.t("Dossiers"), T.t("En bas à gauche"), true],
              ["t", "hud_keyboard", T.t("Clavier"), T.t("En bas à droite, les touches s'allument"), true]],
        cosmos: [["s", "cosmos_speed", T.t("Vitesse du système solaire"), "", 1, [0.25, 3, 0.05, "x"]],
                 ["t", "cosmos_drift", T.t("Caméra automatique"), T.t("Repart seule après une minute sans action"), true],
                 ["t", "cosmos_notifs", T.t("Satellites de notifications"), "", true],
                 ["t", "cosmos_weather", T.t("Satellites météo"), T.t("Prévision des prochaines heures autour de la Terre"), true]],
        ile: [["t", "ile_dock", T.t("Dock"), "", true],
              ["t", "ile_dock_autohide", T.t("Masquer le dock"), T.t("Il apparaît quand la souris touche le bas"), true],
              ["t", "ile_snap", T.t("Aimanter à la grille"), T.t("En déplaçant l'horloge et la carte musique"), true],
              ["t", "ile_weather", T.t("Météo dans l'encoche"), "", true]],
        ruban: [["t", "ruban_date", T.t("Date en filigrane"), "", true], ["t", "ruban_music", T.t("Bande musique"), "", true],
                ["t", "ruban_weather", T.t("Bande météo"), "", true], ["t", "ruban_battery", T.t("Bloc batterie"), "", true]],
        espace: [["t", "espace_lyrics", T.t("Paroles dans le ciel"), "", true], ["t", "espace_planets", T.t("Horloge à planètes"), "", true],
                 ["t", "espace_activity", T.t("Activité du processeur"), T.t("Une case par minute, en haut à droite"), true]],
        foret: [["t", "foret_seconds", T.t("Secondes"), "", true], ["t", "foret_weather", T.t("Météo dans la barre"), "", true],
                ["t", "foret_media", T.t("Morceau dans la barre"), T.t("Pochette, temps et commandes"), true]],
        mono: [["t", "mono_title", T.t("Titre de la fenêtre"), T.t("À la verticale dans la barre"), true],
               ["t", "mono_edge", T.t("Tableau de bord par le haut"), T.t("La souris posée au milieu du bord haut l'ouvre"), true],
               ["t", "mono_unlock", T.t("Cadenas au déverrouillage"), "", true]],
        blanc: [["t", "blanc_fetch", T.t("Fiche système"), "", true], ["t", "blanc_track", T.t("Morceau en cours"), "", true],
                ["t", "blanc_clock", T.t("Grande heure"), "", true]],
        jouet: [["t", "jouet_magnify", T.t("Grossir au survol"), T.t("Les autocollants du dock rebondissent sous la souris"), true]],
        gouts: [["b", "", T.t("Thème Omarchy"), T.t("Mes goûts reprend un thème Omarchy installé"), "", T.t("Suivant  ⌃⌘T"), ["liquid-glass", "profile", "tone"]]],
        debian: [["t", "debian_seconds", T.t("Secondes"), "", false]],
        fedora: [["t", "fedora_seconds", T.t("Secondes"), "", false]],
        mint: [["t", "mint_seconds", T.t("Secondes"), "", false], ["t", "mint_launchers", T.t("Lanceurs du panneau"), "", true]],
        kali: [["t", "kali_seconds", T.t("Secondes"), "", false], ["t", "kali_launchers", T.t("Lanceurs du panneau"), "", true]],
        arch: [["t", "arch_seconds", T.t("Secondes"), "", false], ["t", "arch_launchers", T.t("Tâches épinglées"), "", true]]
      })
      readonly property var ownRows: own[lp.st] || []
      SectionTitle { visible: lp.ownRows.length > 0; text: T.t("Propre à ") + (root.styleNames[lp.st] || lp.st) }
      Group {
        visible: lp.ownRows.length > 0
        Repeater {
          model: lp.ownRows
          Item {
            id: orow
            required property var modelData
            required property int index
            width: parent ? parent.width : 0
            height: childrenRect.height
            // Séparateur fin entre les lignes (comme les autres groupes).
            Rectangle { visible: orow.index > 0; z: 1; x: Style.space(14); width: parent.width - Style.space(28); height: 1; color: root.fg; opacity: 0.07 }
            readonly property string key: "linux." + modelData[1]
            ToggleRow { visible: orow.modelData[0] === "t"; label: orow.modelData[2]; sub: orow.modelData[3]; key: orow.key; def: orow.modelData[4] === true }
            SliderRow {
              visible: orow.modelData[0] === "s"
              label: orow.modelData[2]; key: orow.key
              from: orow.modelData[0] === "s" ? orow.modelData[5][0] : 0; to: orow.modelData[0] === "s" ? orow.modelData[5][1] : 1
              step: orow.modelData[0] === "s" ? orow.modelData[5][2] : 0.1; def: Number(orow.modelData[4]) || 0
              fmt: function(v) { return orow.modelData[0] === "s" && orow.modelData[5][3] === "pct" ? "+" + Math.round((v - 1) * 100) + " %" : "×" + Number(v).toFixed(2) }
            }
            Row_ {
              visible: orow.modelData[0] === "c"; label: orow.modelData[2]; sub: orow.modelData[3]
              Seg {
                options: orow.modelData[0] === "c" ? orow.modelData[5] : []
                value: String(root.val(orow.key, orow.modelData[4]))
                onPicked: function(v) { root.set(orow.key, v) }
              }
            }
            Row_ {
              visible: orow.modelData[0] === "b"; label: orow.modelData[2]; sub: orow.modelData[3]
              Btn { text: orow.modelData[0] === "b" ? orow.modelData[5] : ""; secondary: true; onClicked: root.launch(orow.modelData[6]) }
            }
          }
        }
      }
      Hint { visible: lp.ownRows.length > 0; text: T.t("Musique, paroles, widgets et arrondi (plus bas) sont aussi mémorisés pour chaque thème : en changer garde les siens.") }
      SectionTitle { text: "Style" }
      Group {
        Row_ {
          label: T.t("Allure")
          sub: ({ blanc: T.t("Tout en blanc, police mono, horloge pixel, lecteur vinyle"),
                  sombre: T.t("Noir profond, blanc cassé, jour en kanji"),
                  jouet: T.t("Bonbon : contours épais, ombres dures, arc-en-ciel"),
                  violet: T.t("Montagnes dans la brume, grosse horloge « bonbon » empilée"),
                  expressive: "Material 3 façon end4-pC / Serpantinum : couleurs tirées du fond",
                  windows: T.t("Barre des tâches, menu Démarrer, Paramètres, comme Windows 11"),
                  mono: T.t("Cadre noir façon caelestia, barre latérale, tableau de bord"),
                  foret: T.t("Puces flottantes, météo en orbite, spectre musical (rice c01)") })[lp.st] || ""
          Chips {
            options: [["blanc", T.t("Blanc")], ["sombre", T.t("Sombre")], ["jouet", T.t("Jouet")], ["violet", "Violet"], ["expressive", "Expr."]]
            value: lp.st
            onPicked: function(v) { lp.pick(v, "linux.style", v) }
          }
        }
        Row_ {
          label: T.t("Bureaux complets")
          sub: T.t("Chacun avec sa barre, son lanceur (⌘Espace) et ses réglages (⌘⌥Espace)")
          Chips {
            options: [["windows", "Windows"], ["mono", "Mono"], ["foret", T.t("Forêt")], ["ruban", T.t("Rubans")], ["espace", T.t("Espace")], ["cosmos", "Cosmos"], ["ile", T.t("Île")], ["hud", "7JOKS"], ["infini", T.t("Infini")], ["gouts", T.t("Mes goûts")]]
            value: lp.st
            onPicked: function(v) { lp.pick(v, "linux.style", v) }
          }
        }
        Row_ {
          label: "Distributions"
          sub: T.t("Le panneau et le menu de GNOME, Cinnamon, Xfce ou Plasma")
          Chips {
            options: [["debian", "Debian"], ["fedora", "Fedora"], ["mint", "Mint"], ["kali", "Kali"], ["arch", "Arch"]]
            value: lp.st
            onPicked: function(v) { lp.pick(v, "linux.style", v) }
          }
        }
        Row_ {
          label: T.t("Teinte")
          visible: lp.st === "violet"
          sub: T.t("Nuit (violet profond), aube (lilas clair) ou rose pastel")
          Chips {
            options: [["nuit", T.t("Nuit")], ["aube", T.t("Aube")], ["rose", "Rose"], ["minuit", T.t("Minuit")], ["crepuscule", T.t("Crépuscule")], ["lavande", T.t("Lavande")], ["prune", T.t("Prune")], ["ete", T.t("Été")], ["automne", T.t("Automne")], ["hiver", T.t("Hiver")], ["printemps", T.t("Printemps")]]
            value: root.val("linux.violet_tone", "nuit")
            onPicked: function(v) { lp.pick("violet:" + v, "linux.violet_tone", v) }
          }
        }
        Row_ {
          label: T.t("Blanc")
          visible: lp.st === "blanc"
          sub: T.t("Pur (gris neutres) ou crème (papier chaud)")
          Seg {
            options: [["pur", T.t("Pur")], ["creme", T.t("Crème")]]
            value: root.val("linux.blanc_tone", "pur")
            onPicked: function(v) { lp.pick("blanc:" + v, "linux.blanc_tone", v) }
          }
        }
        Row_ {
          label: T.t("Teinte")
          visible: lp.st === "sombre"
          sub: T.t("Encre, ambre, glace, sang (rouge) ou indigo (bleu violet)")
          Seg {
            options: [["encre", T.t("Encre")], ["ambre", T.t("Ambre")], ["glace", T.t("Glace")], ["sang", T.t("Sang")], ["indigo", "Indigo"]]
            value: root.val("linux.sombre_tone", "encre")
            onPicked: function(v) { lp.pick("sombre:" + v, "linux.sombre_tone", v) }
          }
        }
        Row_ {
          label: T.t("Teinte")
          visible: lp.st === "jouet"
          sub: T.t("Bonbon (rose), menthe (vert d'eau) ou pêche (orange)")
          Seg {
            options: [["bonbon", T.t("Bonbon")], ["menthe", T.t("Menthe")], ["peche", T.t("Pêche")], ["lagon", T.t("Lagon")], ["lilas", T.t("Lilas")]]
            value: root.val("linux.jouet_tone", "bonbon")
            onPicked: function(v) { lp.pick("jouet:" + v, "linux.jouet_tone", v) }
          }
        }
        Row_ {
          label: T.t("Teinte")
          visible: lp.st === "mono"
          sub: T.t("Noir (cadre noir), papier (tout blanc, brume) ou sakura (prune et rose)")
          Seg {
            options: [["noir", T.t("Noir")], ["papier", T.t("Papier")], ["sakura", "Sakura"]]
            value: root.val("linux.mono_tone", "noir")
            onPicked: function(v) { lp.pick("mono:" + v, "linux.mono_tone", v) }
          }
        }
        Row_ {
          label: T.t("Teinte")
          visible: lp.st === "ruban"
          sub: T.t("Bleu, rouge ou or")
          Seg {
            options: [["bleu", T.t("Bleu")], ["rouge", T.t("Rouge")], ["or", T.t("Or")], ["vert", T.t("Vert")], ["violet", "Violet"]]
            value: root.val("linux.ruban_tone", "bleu")
            onPicked: function(v) { lp.pick("ruban:" + v, "linux.ruban_tone", v) }
          }
        }
        Row_ {
          label: T.t("Teinte")
          visible: lp.st === "cosmos"
          sub: T.t("Orbite, mousse ou corail")
          Seg {
            options: [["orbite", T.t("Orbite")], ["mousse", T.t("Mousse")], ["corail", T.t("Corail")]]
            value: root.val("linux.cosmos_tone", "orbite")
            onPicked: function(v) { lp.pick("cosmos:" + v, "linux.cosmos_tone", v) }
          }
        }
        Row_ {
          label: T.t("Langue")
          sub: T.t("Français ou anglais")
          Seg {
            options: [["fr", T.t("Français")], ["en", "English"]]
            value: root.val("linux.lang", "fr")
            onPicked: function(v) { root.launch(["liquid-glass", "lang", v]) }
          }
        }
        Row_ {
          label: T.t("Fond vivant")
          sub: T.t("Anime le fond sans vidéo, en pause quand une fenêtre est ouverte")
          Seg {
            options: [["off", T.t("Fixe")], ["tourbillon", T.t("Tourbillon")], ["vague", T.t("Vague")], ["respire", T.t("Respire")]]
            value: root.val(lp.k("live_wall"), root.val("linux.live_wall", "off"))
            onPicked: function(v) { root.set(lp.k("live_wall"), v) }
          }
        }
        Row_ {
          label: T.t("Teinte")
          visible: lp.st === "espace"
          sub: T.t("Bleu glacé, Mars ou nébuleuse")
          Seg {
            options: [["bleu", T.t("Bleu")], ["mars", "Mars"], ["nebuleuse", T.t("Nébuleuse")], ["aurore", T.t("Aurore")], ["soleil", T.t("Soleil")]]
            value: root.val("linux.espace_tone", "bleu")
            onPicked: function(v) { lp.pick("espace:" + v, "linux.espace_tone", v) }
          }
        }
        ToggleRow { visible: lp.st === "sombre"; label: T.t("Mur de tuiles"); key: lp.k("sombre_wall"); def: root.val("linux.sombre_wall", true) === true}
        Row_ {
          label: T.t("Teinte")
          visible: lp.st === "infini"
          sub: T.t("Couleur du visualiseur et des liserés")
          Seg {
            options: [["sakura", "Sakura"], ["lilas", T.t("Lilas")], ["menthe", T.t("Menthe")], ["peche", T.t("Pêche")]]
            value: root.val("linux.infini_tone", "sakura")
            onPicked: function(v) { lp.pick("infini:" + v, "linux.infini_tone", v) }
          }
        }
        ToggleRow { visible: lp.st === "infini"; label: T.t("Fenêtres flottantes"); key: "linux.infini_float"; def: true; sub: T.t("Pour qu'elles suivent la toile quand on la fait glisser") }
        ToggleRow { visible: lp.st === "infini"; label: T.t("Étoiles filantes"); key: "linux.infini_stars"; def: true }
        Row_ {
          label: T.t("Teinte")
          visible: lp.st === "hud"
          sub: T.t("Couleur des traits du bureau 7JOKS")
          Seg {
            options: [["blanc", T.t("Blanc")], ["cyan", "Cyan"], ["ambre", T.t("Ambre")], ["vert", T.t("Vert")], ["rouge", T.t("Rouge")]]
            value: root.val("linux.hud_tone", "blanc")
            onPicked: function(v) { lp.pick("hud:" + v, "linux.hud_tone", v) }
          }
        }
        Row_ {
          label: T.t("Démarrage")
          visible: lp.st === "hud"
          sub: T.t("Lignes du noyau puis 7JOKS au milieu de l'écran")
          Seg {
            options: [["session", T.t("À l'ouverture")], ["toujours", T.t("À chaque rechargement")], ["jamais", T.t("Jamais")]]
            value: root.val("linux.hud_boot", "session")
            onPicked: function(v) { root.set("linux.hud_boot", v) }
          }
        }
        ToggleRow { visible: lp.st === "hud"; label: T.t("Terminal au démarrage"); key: "linux.hud_terminal"; def: true; sub: T.t("S'ouvre dans le cadre avec la fiche 7JOKS, si le bureau est vide") }
        Row_ {
          label: T.t("Couleurs")
          visible: true
          sub: T.t("Celles du style, tirées du fond d'écran (Material You), ou un accent à toi (⌘Échap → Couleurs pour le nuancier)")
          Seg {
            options: [["theme", T.t("Du style")], ["fond", T.t("Du fond")], ["perso", T.t("Perso")]]
            value: root.val("linux." + lp.st + "_colors", lp.st === "expressive" ? "fond" : "theme")
            onPicked: function(v) { root.set("linux." + lp.st + "_colors", v); if (v === "perso" && root.val("linux." + lp.st + "_accent", "") === "") root.set("linux." + lp.st + "_accent", "#4c9aff") }
          }
        }
        Row_ {
          label: T.t("Teinte")
          visible: lp.st === "windows"
          sub: T.t("Clair ou sombre, comme dans Windows")
          Seg {
            options: [["clair", T.t("Clair")], ["sombre", T.t("Sombre")]]
            value: root.val("linux.windows_tone", "clair")
            onPicked: function(v) { lp.pick("windows:" + v, "linux.windows_tone", v) }
          }
        }
        Row_ {
          label: T.t("Teinte")
          visible: lp.st === "foret"
          sub: T.t("Mousse (vert tilleul) ou cendre (rose poudré)")
          Seg {
            options: [["mousse", T.t("Mousse")], ["cendre", T.t("Cendre")]]
            value: root.val("linux.foret_tone", "mousse")
            onPicked: function(v) { lp.pick("foret:" + v, "linux.foret_tone", v) }
          }
        }
        Row_ {
          label: "Palette Material You"
          sub: T.t("Variante matugen calculée depuis le fond d'écran (ou la pochette)")
          visible: lp.st === "expressive"
          Seg {
            options: [["tonal-spot", T.t("Douce")], ["expressive", "Expressive"], ["vibrant", T.t("Vive")], ["fruit-salad", T.t("Fruitée")], ["monochrome", "Mono"]]
            value: root.val("linux.scheme", "tonal-spot")
            onPicked: function(v) { root.set("linux.scheme", v) }
          }
        }
        SliderRow { label: T.t("Arrondi des cartes"); key: lp.k("radius"); from: 0; to: 32; step: 1
                    def: Number(root.val(lp.k("radius"), root.val("linux.radius", ({ blanc: 0, sombre: 8, jouet: 20, violet: 20, expressive: 24, windows: 8, mono: 18, foret: 16 })[lp.st] || 14)))
                    fmt: function(v) { return Math.round(v) + " px" } }
      }


      SectionTitle { text: T.t("Musique") }
      Group {
        Row_ {
          label: T.t("Visualiseur")
          sub: T.t("Les sons dessinés en bas de l'écran (cava), seulement pendant la lecture")
          Seg {
            options: [["bars", T.t("Barres")], ["wave", T.t("Vague")], ["mirror", T.t("Miroir")], ["blocks", T.t("Blocs")], ["line", T.t("Ligne")], ["radial", T.t("Anneau")], ["off", T.t("Aucun")]]
            value: root.val(lp.k("viz"), root.val("linux.viz", lp.sdef({ jouet: "blocks", violet: "wave", expressive: "wave", "*": "bars" })))
            onPicked: function(v) { root.set(lp.k("viz"), v) }
          }
        }
        Row_ {
          label: T.t("Couleur")
          Seg {
            options: [["auto", T.t("Thème")], ["cover", T.t("Pochette")], ["rainbow", T.t("Arc-en-ciel")], ["ink", T.t("Encre")]]
            value: root.val(lp.k("viz_color"), root.val("linux.viz_color", lp.sdef({ jouet: "rainbow", "*": "auto" })))
            onPicked: function(v) { root.set(lp.k("viz_color"), v) }
          }
        }
        SliderRow { label: T.t("Hauteur"); key: lp.k("viz_height"); from: 40; to: 400; step: 10; def: Number(root.val("linux.viz_height", lp.sdef({ jouet: 130, sombre: 170, "*": 140 }))); fmt: function(v) { return Math.round(v) + " px" } }
        SliderRow { label: T.t("Sensibilité"); key: lp.k("viz_gain"); from: 0.3; to: 3; step: 0.1; def: Number(root.val("linux.viz_gain", 1)); fmt: function(v) { return "×" + v.toFixed(1) } }
        SliderRow { label: T.t("Opacité"); key: lp.k("viz_opacity"); from: 0.1; to: 1; step: 0.05; def: Number(root.val("linux.viz_opacity", lp.sdef({ blanc: 0.85, "*": 0.9 }))); fmt: function(v) { return Math.round(v * 100) + " %" } }
        SliderRow { label: T.t("Nombre de barres"); key: lp.k("cava_bars"); from: 24; to: 160; step: 4; def: Number(root.val("linux.cava_bars", 110)); fmt: function(v) { return Math.round(v) } }
        ToggleRow { label: T.t("Halo sur les basses"); key: lp.k("pulse"); def: root.val("linux.pulse", true) === true; sub: T.t("Une lueur qui respire en bas de l'écran au rythme des basses") }
        ToggleRow { label: T.t("Rebond"); key: lp.k("bump"); def: root.val("linux.bump", true) === true; sub: T.t("Horloges, lecteur et paroles sautent un peu sur chaque basse") }
        ToggleRow { label: T.t("Couleur de la pochette"); key: lp.k("cover_tint"); def: root.val("linux.cover_tint", false) === true; sub: T.t("Accents du visualiseur à la couleur de l'album en cours") }
      }
      Group {
        ToggleRow { label: T.t("Paroles"); key: lp.k("lyrics"); def: root.val("linux.lyrics", true) === true; sub: T.t("Paroles synchronisées (LRCLIB)") }
        Row_ {
          label: T.t("Affichage des paroles")
          sub: T.t("Mot géant chanté au centre, ligne entière, dans la carte du lecteur, ou rien")
          Seg {
            options: [["word", T.t("Mot géant")], ["line", T.t("Ligne")], ["card", T.t("Carte")], ["off", T.t("Aucune")]]
            value: root.val(lp.k("lyrics_mode"), root.val("linux.lyrics_mode", lp.sdef({ expressive: "card", violet: "line", "*": "word" })))
            onPicked: function(v) { root.set(lp.k("lyrics_mode"), v) }
          }
        }
        Row_ {
          label: "Position"
          Seg {
            options: [["center", T.t("Centre")], ["left", T.t("Gauche")], ["top", T.t("Haut")]]
            value: root.val(lp.k("lyrics_pos"), root.val("linux.lyrics_pos", "center"))
            onPicked: function(v) { root.set(lp.k("lyrics_pos"), v) }
          }
        }
        SliderRow { label: T.t("Taille des paroles"); key: lp.k("lyrics_size"); from: 0.4; to: 2.5; step: 0.1; def: Number(root.val("linux.lyrics_size", 1)); fmt: function(v) { return "×" + v.toFixed(1) } }
      }

      SectionTitle { text: T.t("Bureau") }
      Group {
        ToggleRow { label: "Widgets"; key: lp.k("widgets"); def: root.val("linux.widgets", true) === true; sub: T.t("Tous les widgets du style (à glisser où tu veux ; chaque style garde ses places)") }
        ToggleRow { visible: lp.st === "violet"; label: T.t("Horloge bonbon"); key: lp.k("w_stack"); def: root.val("linux.w_stack", true) === true}
        SliderRow { visible: lp.st === "violet"; label: T.t("Taille de l'horloge"); key: lp.k("stack_size"); from: 80; to: 220; step: 4; def: Number(root.val("linux.stack_size", 132)); fmt: function(v) { return Math.round(v) + " px" } }
        ToggleRow { visible: lp.st === "violet"; label: T.t("Anneau batterie"); key: lp.k("w_ring"); def: root.val("linux.w_ring", true) === true; sub: T.t("Ou la charge du processeur sur un ordinateur fixe") }
        ToggleRow { visible: ["blanc", "sombre", "jouet"].indexOf(lp.st) >= 0; label: T.t("Horloge pixel"); key: lp.k("w_pixclock"); def: root.val("linux.w_pixclock", true) === true}
        ToggleRow { visible: lp.st === "blanc" || lp.st === "sombre"; label: T.t("Jour en grand"); key: lp.k("w_day"); def: root.val("linux.w_day", true) === true}
        ToggleRow { visible: lp.st === "sombre"; label: T.t("Jour en kanji"); key: lp.k("day_kanji"); def: root.val("linux.day_kanji", true) === true}
        ToggleRow { visible: lp.st === "expressive"; label: T.t("Horloge cookie"); key: lp.k("w_clock"); def: root.val("linux.w_clock", true) === true}
        ToggleRow { visible: lp.st !== "lain"; label: T.t("Lecteur"); key: lp.k("w_music"); def: root.val("linux.w_music", true) === true}
        ToggleRow { visible: lp.st !== "lain" && lp.st !== "sombre"; label: T.t("Météo"); key: lp.k("w_weather"); def: root.val("linux.w_weather", true) === true}
        ToggleRow { visible: lp.st !== "lain"; label: T.t("Système"); key: lp.k("w_system"); def: root.val("linux.w_system", true) === true}
        ToggleRow { visible: lp.st !== "lain" && lp.st !== "sombre"; label: T.t("À faire"); key: lp.k("w_todo"); def: root.val("linux.w_todo", true) === true}
        ToggleRow { visible: lp.st === "lain"; label: T.t("Horloge pixel"); key: lp.k("clock"); def: root.val("linux.clock", true) === true; sub: T.t("Grands chiffres en blocs façon tty-clock, à droite") }
        ToggleRow { label: T.t("Visualiseur cava"); key: lp.k("cava"); def: root.val("linux.cava", true) === true; sub: T.t("Arrête complètement le visualiseur (et cava) si désactivé") }
        SliderRow { label: T.t("Espaces de travail"); key: "linux.workspaces"; from: 4; to: 10; step: 1; def: 7; fmt: function(v) { return Math.round(v) } }
        Row_ {
          label: T.t("Disposition des widgets")
          sub: T.t("Remet chaque widget à sa place d'origine")
          Btn { text: T.t("Réinitialiser"); onClicked: root.launch(["omarchy-shell", "liquid-glass.linux", "resetLayout"]) }
        }
      }
      Hint { text: T.t("Réglages appliqués à chaud. ⌘⇧Espace : bureaux. ⌃⌘Espace : carrousel de fonds. En ligne de commande : liquid-glass profile blanc|sombre|jouet|violet|aube|rose|expressive|lain|mac.") }
    }
  }

  Component {
    id: pKeys
    Column {
      spacing: Style.space(14)
      Group {
        ToggleRow { label: T.t("Raccourcis façon macOS"); key: "keys.macos_shortcuts"; def: true; sub: T.t("⌘Espace, ⌘Q, ⌘Tab, ⌘↑, ⌘⇧3/4/5… Désactivé : raccourcis Omarchy d'origine") }
        Row_ { label: T.t("Aide-mémoire des raccourcis"); Btn { text: T.t("Afficher  ⌘K"); secondary: true; onClicked: { root.dismiss(); root.launch(["omarchy-shell", "liquid-glass.cheatsheet", "toggle"]) } } }
      }
    }
  }

  Component {
    id: pMouse
    Column {
      spacing: Style.space(14)
      Group {
        SliderRow { label: T.t("Vitesse du pointeur"); key: "input.sensitivity"; from: -1; to: 1; step: 0.05; def: 0; fmt: function(v) { return v <= -0.6 ? T.t("Lente") : (v >= 0.6 ? T.t("Rapide") : (v > 0 ? "+" : "") + v.toFixed(2)) } }
        SliderRow { label: T.t("Vitesse de défilement"); key: "input.mouse_scroll"; from: 0.2; to: 3; step: 0.1; def: 1; fmt: function(v) { return "×" + v.toFixed(1) } }
        ToggleRow { label: T.t("Défilement naturel"); key: "input.mouse_natural_scroll"; def: false; sub: T.t("Le contenu suit le mouvement de la molette") }
      }
      Hint { text: T.t("Appliqué tout de suite à Hyprland (souris et TrackPoint). Le trackpad a sa propre page.") }
    }
  }

  Component {
    id: pTrackpad
    Column {
      spacing: Style.space(14)
      Group {
        ToggleRow { label: T.t("Toucher pour cliquer"); key: "input.tap_to_click"; def: true; sub: T.t("Touchez avec un doigt pour cliquer") }
        ToggleRow { label: T.t("Clic secondaire à deux doigts"); key: "input.clickfinger"; def: true; sub: T.t("Cliquez avec deux doigts : clic droit ; trois : clic du milieu") }
        ToggleRow { label: T.t("Défilement naturel"); key: "input.natural_scroll"; def: true; sub: T.t("Le contenu suit le mouvement des doigts") }
        SliderRow { label: T.t("Vitesse de défilement"); key: "input.trackpad_scroll"; from: 0.1; to: 2; step: 0.05; def: 0.4; fmt: function(v) { return "×" + v.toFixed(2) } }
        ToggleRow { label: T.t("Ignorer en tapant au clavier"); key: "input.disable_while_typing"; def: true }
      }
      SectionTitle { text: T.t("Gestes") }
      Group {
        Row_ { label: "Mission Control"; sub: T.t("Balayer vers le haut avec quatre doigts"); Label_ { text: T.t("4 doigts ↑") } }
        Row_ { label: T.t("Fermer Mission Control"); sub: T.t("Balayer vers le bas avec quatre doigts"); Label_ { text: T.t("4 doigts ↓") } }
        Row_ { label: T.t("Changer de bureau"); sub: T.t("Balayer à gauche ou à droite avec trois doigts"); Label_ { text: T.t("3 doigts ← →") } }
      }
    }
  }

  Component {
    id: pCorners
    Column {
      spacing: Style.space(14)
      Group {
        CornerRow { label: T.t("En haut à gauche"); key: "hotcorners.top_left" }
        CornerRow { label: T.t("En haut à droite"); key: "hotcorners.top_right" }
        CornerRow { label: T.t("En bas à gauche"); key: "hotcorners.bottom_left" }
        CornerRow { label: T.t("En bas à droite"); key: "hotcorners.bottom_right" }
      }
      Hint { text: T.t("Pointez dans un coin de l'écran pour déclencher l'action (pas en plein écran). ⌘F3 affiche aussi le bureau.") }
    }
  }

  Component {
    id: pAbout
    Column {
      spacing: Style.space(14)
      Item {
        width: parent.width; height: Style.space(130)
        Column {
          anchors.centerIn: parent
          spacing: Style.space(6)
          Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            width: Style.space(64); height: width; radius: Style.space(16)
            gradient: Gradient { GradientStop { position: 0; color: "#6fd8ff" } GradientStop { position: 1; color: "#4f6cf7" } }
            Text { anchors.centerIn: parent; textFormat: Text.PlainText; text: root.g(0xF058C); font.family: root.iconFont; font.pixelSize: Style.space(34); color: "white" }
          }
          Text { anchors.horizontalCenter: parent.horizontalCenter; textFormat: Text.PlainText; text: "Liquid Glass"; font.family: root.uiFont; font.pixelSize: Style.space(18); font.weight: Font.Bold; color: root.fg }
          Text { anchors.horizontalCenter: parent.horizontalCenter; textFormat: Text.PlainText; text: "Version 1.1 · Omarchy + Hyprland + Quickshell"; font.family: root.uiFont; font.pixelSize: Style.space(11); color: root.fg; opacity: 0.55 }
        }
      }
      Group {
        Row_ { label: T.t("Configuration"); sub: "~/.config/liquid-glass"; Btn { text: T.t("Ouvrir"); secondary: true; onClicked: { root.dismiss(); root.launch(["xdg-open", root.home + "/.config/liquid-glass"]) } } }
        Row_ { label: T.t("Thème actif"); Label_ { text: root.dark ? "Liquid Glass Dark" : "Liquid Glass" } }
        Row_ { label: T.t("Réappliquer tout"); sub: T.t("Régénère thème, Hyprland, dock et shell"); Btn { text: T.t("Appliquer"); secondary: true; onClicked: root.launch(["liquid-glass", "apply"]) } }
      }
      Hint { text: T.t("Pour tout annuler : ~/.config-backup-<date>/restore.sh restaure l'état d'avant l'installation.") }
    }
  }

  // Ligne de coin actif : un bouton qui fait défiler les actions.
  component CornerRow: Row_ {
    id: cr
    property string key: ""
    readonly property var actions: [["", "—"], ["mission", "Mission Control"], ["desktop", T.t("Afficher le bureau")], ["spotlight", "Spotlight"],
                                    ["control", T.t("Centre de contrôle")], ["karaoke", T.t("Paroles karaoké")], ["lock", T.t("Verrouiller l'écran")], ["settings", T.t("Réglages")]]
    readonly property string current: String(root.val(key, ""))
    function idx() { for (var i = 0; i < actions.length; i++) if (actions[i][0] === current) return i; return 0 }
    Btn {
      text: cr.actions[cr.idx()][1] + "  ⌄"
      secondary: true
      width: Style.space(190)
      onClicked: root.set(cr.key, cr.actions[(cr.idx() + 1) % cr.actions.length][0])
    }
  }

  // =============================================================== composants
  component SectionTitle: Text {
    textFormat: Text.PlainText
    font.family: root.uiFont; font.pixelSize: Style.space(12); font.weight: Font.DemiBold
    color: root.fg; opacity: 0.6
    leftPadding: Style.space(6)
    bottomPadding: -Style.space(6)
  }

  component Hint: Text {
    width: parent ? parent.width : 0
    textFormat: Text.PlainText
    wrapMode: Text.WordWrap
    font.family: root.uiFont; font.pixelSize: Style.space(11.5)
    color: root.fg; opacity: 0.5
    leftPadding: Style.space(6); rightPadding: Style.space(6)
  }

  // Groupe de lignes façon Tahoe : verre légèrement contrasté, séparateurs fins.
  component Group: Rectangle {
    id: grp
    default property alias rows: col.data
    width: parent ? parent.width : 0
    height: visible ? col.implicitHeight : 0
    radius: Style.space(12)
    color: Qt.rgba(root.fg.r, root.fg.g, root.fg.b, root.dark ? 0.07 : 0.05)
    border.width: 1
    border.color: Qt.rgba(1, 1, 1, root.dark ? 0.06 : 0.45)
    Column { id: col; width: parent.width }
  }

  // Ligne : icône de couleur facultative, libellé, sous-titre, contrôle à droite.
  component Row_: Item {
    id: r
    property string label: ""
    property string sub: ""
    property int icon: 0
    property color iconColor: "#8e8e93"
    default property alias control: slot.data
    width: parent ? parent.width : 0
    // Hauteur macOS (≈ 40 pt) mais jamais plus petite que le contrôle de droite
    // (sinon un grand contrôle, comme les vignettes d'apparence, déborde).
    // Contrôle trop large pour tenir à côté du libellé : il passe dessous.
    readonly property bool stacked: slot.width > r.width - Style.space(170)
    height: !visible ? 0 : stacked
      ? labels.implicitHeight + slot.height + Style.space(26)
      : Math.max(Style.space(Mac.settings.row), labels.implicitHeight + Style.space(16), slot.height + Style.space(16))
    // Séparateur (pas sur la première ligne).
    Rectangle {
      visible: r.y > 0
      x: labels.x; width: parent.width - x - Style.space(14); height: 1
      color: root.fg; opacity: 0.07
    }
    Rectangle {
      id: ico
      visible: r.icon !== 0
      x: Style.space(12)
      anchors.verticalCenter: parent.verticalCenter
      width: Style.space(24); height: width; radius: Style.space(7)
      gradient: Gradient {
        GradientStop { position: 0; color: Qt.lighter(r.iconColor, 1.25) }
        GradientStop { position: 1; color: r.iconColor }
      }
      Text { anchors.centerIn: parent; textFormat: Text.PlainText; text: r.icon ? root.g(r.icon) : ""; font.family: root.iconFont; font.pixelSize: Style.space(13); color: "white" }
    }
    Column {
      id: labels
      x: r.icon !== 0 ? ico.x + ico.width + Style.space(10) : Style.space(14)
      // Positions calculées (pas d'ancre qu'on retire en route : la position resterait figée).
      y: r.stacked ? Style.space(10) : Math.round((r.height - implicitHeight) / 2)
      width: r.stacked ? parent.width - x - Style.space(14) : parent.width - x - slot.width - Style.space(28)
      spacing: 1
      Text { width: parent.width; textFormat: Text.PlainText; text: r.label; elide: Text.ElideRight; font.family: root.uiFont; font.pixelSize: Style.space(13); color: root.fg }
      Text { width: parent.width; visible: r.sub !== ""; textFormat: Text.PlainText; text: r.sub; wrapMode: Text.WordWrap; font.family: root.uiFont; font.pixelSize: Style.space(11); color: root.fg; opacity: 0.5 }
    }
    Item {
      id: slot
      x: r.stacked ? labels.x : r.width - width - Style.space(14)
      y: r.stacked ? labels.y + labels.implicitHeight + Style.space(8) : Math.round((r.height - height) / 2)
      width: childrenRect.width; height: childrenRect.height
    }
  }

  component Label_: Text {
    textFormat: Text.PlainText
    font.family: root.uiFont; font.pixelSize: Style.space(12.5)
    color: root.fg; opacity: 0.6
  }

  // Bouton : bleu (principal) ou gris (secondaire), rebond à l'appui.
  component Btn: Rectangle {
    id: b
    property string text: ""
    property bool secondary: false
    signal clicked()
    width: bt.implicitWidth + Style.space(24); height: Style.space(26); radius: height / 2
    color: b.secondary ? Qt.rgba(root.fg.r, root.fg.g, root.fg.b, bMouse.containsMouse ? 0.16 : 0.1)
                       : (bMouse.pressed ? Qt.darker(root.accent, 1.15) : root.accent)
    scale: bMouse.pressed ? 0.9 : 1
    Behavior on scale { NumberAnimation { duration: 320; easing.type: Easing.OutBack; easing.overshoot: 3 } }
    Text { id: bt; anchors.centerIn: parent; textFormat: Text.PlainText; text: b.text; font.family: root.uiFont; font.pixelSize: Style.space(12); font.weight: Font.Medium; color: b.secondary ? root.fg : "white" }
    MouseArea { id: bMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: b.clicked() }
  }

  // Contrôle segmenté : la pastille blanche glisse vers l'option choisie.
  readonly property var widgetSizes: [["small", T.t("Petit")], ["medium", T.t("Moyen")], ["large", T.t("Grand")], ["xl", T.t("Très grand")]]
  function widgetSize(key) {
    var v = String(root.val("widgets." + key + "_size", key === "weather" ? "medium" : "small"))
    return v === "wide" ? "medium" : v
  }

  // Pastilles qui passent à la ligne (longues listes : styles, teintes…), même API que Seg.
  component Chips: Flow {
    id: ch
    property var options: []
    property string value: ""
    signal picked(string v)
    width: parent && parent.parent ? parent.parent.width - Style.space(40) : Style.space(480)
    spacing: Style.space(6)
    Repeater {
      model: ch.options
      Btn {
        required property var modelData
        text: modelData[1]; secondary: ch.value !== modelData[0]
        onClicked: ch.picked(modelData[0])
      }
    }
  }

  component Seg: Rectangle {
    id: seg
    property var options: []
    property string value: ""
    signal picked(string v)
    width: segRow.implicitWidth + 4; height: Style.space(28); radius: height / 2
    color: Qt.rgba(root.fg.r, root.fg.g, root.fg.b, 0.08)
    readonly property int idx: { for (var i = 0; i < options.length; i++) if (options[i][0] === value) return i; return -1 }
    Rectangle {
      id: thumb
      visible: seg.idx >= 0
      // count : réévalué quand le Repeater a créé ses boutons (sinon pas de pastille au départ).
      readonly property var it: seg.idx >= 0 && segRep.count > seg.idx ? segRep.itemAt(seg.idx) : null
      x: it ? segRow.x + it.x : 2
      width: it ? it.width : 0
      y: 2; height: seg.height - 4; radius: height / 2
      color: root.dark ? Qt.rgba(1, 1, 1, 0.22) : "#ffffff"
      border.width: 1; border.color: Qt.rgba(0, 0, 0, 0.06)
      Behavior on x { NumberAnimation { duration: 420; easing.type: Easing.OutBack; easing.overshoot: 1.8 } }
      Behavior on width { NumberAnimation { duration: 420; easing.type: Easing.OutBack; easing.overshoot: 1.8 } }
    }
    Row {
      id: segRow
      anchors.centerIn: parent
      Repeater {
        id: segRep
        model: seg.options
        delegate: Item {
          id: opt
          required property var modelData
          required property int index
          readonly property bool on: seg.idx === index
          width: Math.max(Style.space(58), ot.implicitWidth + Style.space(20)); height: seg.height - 4
          Text { id: ot; anchors.centerIn: parent; textFormat: Text.PlainText; text: opt.modelData[1]; font.family: root.uiFont; font.pixelSize: Style.space(12); font.weight: opt.on ? Font.DemiBold : Font.Normal; color: root.fg }
          MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: seg.picked(opt.modelData[0]) }
        }
      }
    }
  }

  // Menu déroulant façon macOS (« Arrondie ⌄ ») : la liste se déplie sous le bouton.
  component Picker: Column {
    id: pk
    property var options: []     // [[valeur, libellé]]
    property string value: ""
    property bool open: false
    signal picked(string v)
    spacing: Style.space(4)
    readonly property string current: { for (var i = 0; i < options.length; i++) if (options[i][0] === value) return options[i][1]; return value }
    width: pk.open ? Math.max(pkBtn.width, pkList.width) : pkBtn.width
    Rectangle {
      id: pkBtn
      anchors.right: parent.right
      width: pkTxt.implicitWidth + Style.space(34); height: Style.space(26); radius: height / 2
      color: Qt.rgba(root.fg.r, root.fg.g, root.fg.b, pkMouse.containsMouse || pk.open ? 0.16 : 0.1)
      scale: pkMouse.pressed ? 0.92 : 1
      Behavior on scale { NumberAnimation { duration: 300; easing.type: Easing.OutBack; easing.overshoot: 3 } }
      Text { id: pkTxt; x: Style.space(12); anchors.verticalCenter: parent.verticalCenter; textFormat: Text.PlainText; text: pk.current; font.family: root.uiFont; font.pixelSize: Style.space(12); font.weight: Font.Medium; color: root.fg }
      Text {
        anchors.right: parent.right; anchors.rightMargin: Style.space(10); anchors.verticalCenter: parent.verticalCenter
        textFormat: Text.PlainText; text: root.g(0xF0140); font.family: root.iconFont; font.pixelSize: Style.space(12); color: root.fg; opacity: 0.6
        rotation: pk.open ? 180 : 0
        Behavior on rotation { NumberAnimation { duration: 380; easing.type: Easing.OutBack; easing.overshoot: 2.5 } }
      }
      MouseArea { id: pkMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: pk.open = !pk.open }
    }
    Rectangle {
      id: pkList
      visible: pk.open
      anchors.right: parent.right
      width: Math.max(Style.space(170), pkCol.implicitWidth + Style.space(10)); height: pkCol.implicitHeight + Style.space(10)
      radius: Style.space(10)
      color: root.dark ? Qt.rgba(0.2, 0.2, 0.22, 0.9) : Qt.rgba(1, 1, 1, 0.85)
      border.width: 1; border.color: Qt.rgba(root.fg.r, root.fg.g, root.fg.b, 0.1)
      Column {
        id: pkCol
        x: Style.space(5); y: Style.space(5)
        width: parent.width - Style.space(10)
        Repeater {
          model: pk.options
          delegate: Rectangle {
            id: po
            required property var modelData
            readonly property bool on: pk.value === modelData[0]
            width: pkCol.width; height: Style.space(Mac.menu.row); radius: Style.space(Mac.menu.selRadius)
            color: poMouse.containsMouse ? root.accent : "transparent"
            Text { x: Style.space(6); anchors.verticalCenter: parent.verticalCenter; textFormat: Text.PlainText; text: po.on ? "✓" : ""; font.family: root.uiFont; font.pixelSize: Style.space(12); color: poMouse.containsMouse ? "white" : root.fg }
            Text { x: Style.space(22); anchors.verticalCenter: parent.verticalCenter; textFormat: Text.PlainText; text: po.modelData[1]; font.family: root.uiFont; font.pixelSize: Style.space(13); color: poMouse.containsMouse ? "white" : root.fg }
            MouseArea { id: poMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: { pk.open = false; pk.picked(po.modelData[0]) } }
          }
        }
      }
    }
  }

  // Interrupteur façon macOS : le bouton s'étire quand on appuie.
  component Switch_: Rectangle {
    id: sw
    property bool checked: false
    signal toggled(bool v)
    width: Style.space(40); height: Style.space(24); radius: height / 2
    color: checked ? "#34c759" : Qt.rgba(root.fg.r, root.fg.g, root.fg.b, 0.18)
    Behavior on color { ColorAnimation { duration: 160 } }
    Rectangle {
      readonly property real base: parent.height - 4
      width: swMouse.pressed ? base * 1.35 : base
      height: base; radius: height / 2
      y: 2; x: sw.checked ? sw.width - width - 2 : 2
      color: "white"
      border.width: 1; border.color: Qt.rgba(0, 0, 0, 0.08)
      Behavior on x { SpringAnimation { spring: 5; damping: 0.32; epsilon: 0.2 } }
      Behavior on width { NumberAnimation { duration: 180; easing.type: Easing.OutBack } }
    }
    MouseArea { id: swMouse; anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: sw.toggled(!sw.checked) }
  }

  // Éléments de la barre des menus (liquid-glass bar …, shell.json rechargé à chaud).
  property var barItems: ({})
  Process {
    id: barProc
    command: ["liquid-glass", "bar", "status"]
    stdout: StdioCollector { onStreamFinished: { try { root.barItems = JSON.parse(text) } catch (e) {} } }
  }
  Timer { id: barTimer; interval: 500; onTriggered: barProc.running = true }
  Component.onCompleted: barProc.running = true
  component BarRow: Row_ {
    id: br
    property string item: ""
    Switch_ {
      checked: root.barItems[br.item] === true
      onToggled: function(v) {
        var next = Object.assign({}, root.barItems); next[br.item] = v; root.barItems = next
        root.run(["liquid-glass", "bar", br.item, v ? "on" : "off"])
        barTimer.restart()
      }
    }
  }

  component ToggleRow: Row_ {
    id: tr
    property string key: ""
    property bool def: false
    Switch_ { checked: root.val(tr.key, tr.def) === true; onToggled: function(v) { root.set(tr.key, v) } }
  }

  // Curseur : aperçu pendant le glissement, écriture au relâchement.
  component SliderRow: Row_ {
    id: sr
    property string key: ""
    property real from: 0
    property real to: 1
    property real step: 1
    property real def: 0
    property var fmt: function(v) { return String(v) }
    readonly property real stored: Number(root.val(key, def))
    property real live: stored
    property bool dragging: false
    onStoredChanged: if (!dragging) live = stored
    function snap(v) {
      var s = Math.round((v - from) / step) * step + from
      s = Math.max(from, Math.min(to, s))
      return Number(s.toFixed(4))
    }
    Row {
      spacing: Style.space(10)
      Item {
        width: Style.space(160); height: Style.space(22)
        anchors.verticalCenter: parent.verticalCenter
        Rectangle {
          anchors.verticalCenter: parent.verticalCenter
          width: parent.width; height: Style.space(4); radius: 2
          color: Qt.rgba(root.fg.r, root.fg.g, root.fg.b, 0.15)
          Rectangle { width: knob.x + knob.width / 2; height: parent.height; radius: 2; color: root.accent }
        }
        Rectangle {
          id: knob
          width: Style.space(20); height: Style.space(18); radius: height / 2
          anchors.verticalCenter: parent.verticalCenter
          x: (sr.live - sr.from) / (sr.to - sr.from) * (parent.width - width)
          color: "white"
          border.width: 1; border.color: Qt.rgba(0, 0, 0, 0.12)
          scale: sr.dragging ? 1.25 : 1
          Behavior on scale { NumberAnimation { duration: 300; easing.type: Easing.OutBack; easing.overshoot: 3 } }
        }
        MouseArea {
          anchors.fill: parent
          anchors.margins: -6
          cursorShape: Qt.PointingHandCursor
          preventStealing: true
          function at(x) { return sr.snap(sr.from + Math.max(0, Math.min(1, (x - 6 - knob.width / 2) / (parent.width - knob.width))) * (sr.to - sr.from)) }
          onPressed: function(m) { sr.dragging = true; sr.live = at(m.x) }
          onPositionChanged: function(m) { if (pressed) sr.live = at(m.x) }
          onReleased: { sr.dragging = false; if (sr.live !== sr.stored) root.set(sr.key, sr.live) }
        }
      }
      Text {
        width: Style.space(60)
        anchors.verticalCenter: parent.verticalCenter
        horizontalAlignment: Text.AlignRight
        textFormat: Text.PlainText
        text: sr.fmt(sr.live)
        font.family: root.uiFont; font.pixelSize: Style.space(12); font.features: { "tnum": 1 }
        color: root.fg; opacity: 0.6
      }
    }
  }

  // Curseur direct (luminosité, volume) : applique pendant le glissement.
  component LiveSlider: Item {
    id: ls
    property real value: 0
    signal moved(real v)
    // Curseur standard macOS : piste fine accentuée + bouton blanc (comme SliderRow).
    width: Style.space(200); height: Style.space(22)
    Rectangle {
      anchors.verticalCenter: parent.verticalCenter
      width: parent.width; height: Style.space(4); radius: 2
      color: Qt.rgba(root.fg.r, root.fg.g, root.fg.b, 0.15)
      Rectangle { width: lsKnob.x + lsKnob.width / 2; height: parent.height; radius: 2; color: root.accent }
    }
    Rectangle {
      id: lsKnob
      width: Style.space(20); height: Style.space(18); radius: height / 2
      anchors.verticalCenter: parent.verticalCenter
      x: Math.max(0, Math.min(1, ls.value)) * (ls.width - width)
      color: "white"
      border.width: 1; border.color: Qt.rgba(0, 0, 0, 0.12)
      scale: lsArea.pressed ? 1.25 : 1
      Behavior on scale { NumberAnimation { duration: 300; easing.type: Easing.OutBack; easing.overshoot: 3 } }
      Behavior on x { enabled: !lsArea.pressed; NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
    }
    MouseArea {
      id: lsArea
      anchors.fill: parent
      anchors.margins: -6
      preventStealing: true
      cursorShape: Qt.PointingHandCursor
      function apply(x) { ls.moved(Math.max(0, Math.min(1, (x - 6 - lsKnob.width / 2) / (ls.width - lsKnob.width)))) }
      onPressed: function(m) { apply(m.x) }
      onPositionChanged: function(m) { if (pressed) apply(m.x) }
    }
    WheelHandler { onWheel: function(e) { ls.moved(Math.max(0, Math.min(1, ls.value + (e.angleDelta.y > 0 ? 0.05 : -0.05)))) } }
  }

  // Pastille d'état (connecté / actif).
  component Dot: Rectangle {
    property bool on: false
    width: Style.space(9); height: width; radius: width / 2
    color: on ? "#30d158" : Qt.rgba(root.fg.r, root.fg.g, root.fg.b, 0.25)
  }

  // Avatar : ~/.face ou l'initiale sur un dégradé.
  component Avatar: Item {
    id: av
    property real side: Style.space(36)
    width: side; height: side
    Image {
      id: avImg
      anchors.fill: parent
      source: root.hasFace ? "file://" + root.home + "/.face?v=" + root.faceVersion : ""
      sourceSize: Qt.size(160, 160)
      fillMode: Image.PreserveAspectCrop
      cache: false
      visible: false
    }
    Item { id: avMask; anchors.fill: parent; visible: false; layer.enabled: true
      Rectangle { anchors.fill: parent; radius: width / 2; color: "black" } }
    MultiEffect { anchors.fill: parent; source: avImg; maskEnabled: true; maskSource: avMask; maskThresholdMin: 0.5; maskSpreadAtMin: 1.0; visible: avImg.status === Image.Ready }
    Rectangle {
      anchors.fill: parent; radius: width / 2
      visible: avImg.status !== Image.Ready
      gradient: Gradient { GradientStop { position: 0; color: "#a5b4c8" } GradientStop { position: 1; color: "#6b7a90" } }
      Text { anchors.centerIn: parent; textFormat: Text.PlainText; text: root.displayName.charAt(0).toUpperCase(); font.family: root.uiFont; font.pixelSize: av.side * 0.44; font.weight: Font.DemiBold; color: "white" }
    }
  }

  // Champ texte validé à la sortie / Entrée.
  component TextBox: Rectangle {
    id: tb
    property string value: ""
    property string placeholder: ""
    signal committed(string t)
    signal edited(string t)
    width: Style.space(180); height: Style.space(28); radius: height / 2
    color: Qt.rgba(root.fg.r, root.fg.g, root.fg.b, 0.08)
    border.width: tbIn.activeFocus ? 2 : 0
    border.color: root.accent
    TextInput {
      id: tbIn
      anchors.fill: parent
      anchors.leftMargin: Style.space(12); anchors.rightMargin: Style.space(12)
      verticalAlignment: TextInput.AlignVCenter
      text: tb.value
      font.family: root.uiFont; font.pixelSize: Style.space(12.5)
      color: root.fg
      selectByMouse: true
      clip: true
      onEditingFinished: if (text.trim() !== tb.value) tb.committed(text.trim())
      onTextChanged: tb.edited(text)
      Keys.onEscapePressed: { text = tb.value; keys.forceActiveFocus() }
      Text { visible: !tbIn.text && !tbIn.activeFocus; anchors.verticalCenter: parent.verticalCenter; text: tb.placeholder; font: tbIn.font; color: root.fg; opacity: 0.4 }
    }
  }

  // Choix de police : bouton avec la police actuelle, liste filtrable dessous.
  component FontRow: Column {
    id: fr
    property string label: ""
    property string key: ""
    property string def: ""
    property bool allowDefault: false
    property bool expanded: false
    property string filter: ""
    readonly property string current: String(root.val(key, def))
    width: parent ? parent.width : 0
    Row_ {
      label: fr.label
      Btn {
        secondary: true
        text: (fr.current || T.t("Police de l'interface")) + "  ⌄"
        onClicked: { fr.expanded = !fr.expanded; if (fr.expanded && root.fonts.length === 0) fontProc.running = true }
      }
    }
    Item {
      width: parent.width
      height: fr.expanded ? Style.space(220) : 0
      clip: true
      Behavior on height { NumberAnimation { duration: 420; easing.type: Easing.OutBack; easing.overshoot: 1.2 } }
      TextBox {
        id: ff
        x: Style.space(14)
        width: parent.width - Style.space(28)
        placeholder: T.t("Filtrer les polices")
        value: ""
        onCommitted: function(t) { fr.filter = t }
      }
      ListView {
        x: Style.space(8); y: ff.height + Style.space(6)
        width: parent.width - Style.space(16); height: parent.height - y - Style.space(6)
        clip: true
        model: (fr.allowDefault ? [""] : []).concat(root.fonts.filter(function(f) { return fr.filter === "" || f.toLowerCase().indexOf(fr.filter.toLowerCase()) !== -1 }))
        delegate: Rectangle {
          id: fi
          required property var modelData
          width: ListView.view.width; height: Style.space(28); radius: Style.space(8)
          color: fr.current === modelData ? Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.25) : (fiMouse.containsMouse ? Qt.rgba(root.fg.r, root.fg.g, root.fg.b, 0.07) : "transparent")
          Text {
            x: Style.space(10); anchors.verticalCenter: parent.verticalCenter
            textFormat: Text.PlainText
            text: fi.modelData === "" ? T.t("Police de l'interface") : fi.modelData
            font.family: fi.modelData === "" ? root.uiFont : fi.modelData
            font.pixelSize: Style.space(13)
            color: root.fg
          }
          MouseArea { id: fiMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: { root.set(fr.key, fi.modelData); fr.expanded = false } }
        }
      }
    }
  }

  // Heure HH:MM par pas de 30 min.
  component Stepper: Row {
    id: st
    property string value: "07:30"
    signal changed_(string v)
    spacing: Style.space(6)
    function shift(d) {
      var p = value.split(":"), m = (parseInt(p[0]) * 60 + parseInt(p[1]) + d + 1440) % 1440
      var h = Math.floor(m / 60), mm = m % 60
      changed_((h < 10 ? "0" : "") + h + ":" + (mm < 10 ? "0" : "") + mm)
    }
    Btn { text: "−"; secondary: true; width: Style.space(26); onClicked: st.shift(-30) }
    Text { anchors.verticalCenter: parent.verticalCenter; width: Style.space(48); horizontalAlignment: Text.AlignHCenter; textFormat: Text.PlainText; text: st.value; font.family: root.uiFont; font.pixelSize: Style.space(13); font.features: { "tnum": 1 }; color: root.fg }
    Btn { text: "+"; secondary: true; width: Style.space(26); onClicked: st.shift(30) }
  }
}
