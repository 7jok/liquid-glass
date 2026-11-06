import QtQuick
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
  readonly property var pages: [
    ["wifi", "Wi-Fi", 0xF05A9, "#0a84ff", 0],
    ["bluetooth", "Bluetooth", 0xF00AF, "#0a84ff", 0],
    ["network", "Réseau", 0xF0318, "#0a84ff", 0],
    ["battery", "Batterie", 0xF0079, "#30d158", 0],
    ["general", "Général", 0xF0493, "#8e8e93", 1],
    ["appearance", "Apparence", 0xF050E, "#1c1c1e", 1],
    ["control", "Centre de contrôle", 0xF0521, "#8e8e93", 1],
    ["desktop", "Bureau et Dock", 0xF0379, "#1c1c1e", 1],
    ["displays", "Écrans", 0xF00DF, "#0a84ff", 1],
    ["menubar", "Barre des menus", 0xF035C, "#1c1c1e", 1],
    ["wallpaper", "Fond d'écran", 0xF02E9, "#32ade6", 1],
    ["notifications", "Notifications", 0xF009A, "#ff3b30", 2],
    ["sound", "Son", 0xF057E, "#ff2d55", 2],
    ["focus", "Concentration", 0xF0594, "#5e5ce6", 2],
    ["music", "Musique et paroles", 0xF075A, "#ff375f", 2],
    ["lock", "Écran verrouillé", 0xF033E, "#1c1c1e", 3],
    ["users", "Utilisateurs et groupes", 0xF0849, "#0a84ff", 3],
    ["keyboard", "Clavier", 0xF030C, "#8e8e93", 4],
    ["corners", "Coins actifs", 0xF0294, "#8e8e93", 4],
    ["about", "À propos", 0xF02FD, "#8e8e93", 5]
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
  Process {
    id: bgProc
    command: ["sh", "-c", "readlink -f \"$HOME/.local/state/omarchy/current/background\"; t=$(cat \"$HOME/.local/state/omarchy/current/theme.name\" 2>/dev/null); d=$(omarchy-theme-dir \"$t\" 2>/dev/null || omarchy theme dir \"$t\" 2>/dev/null); find -L \"$d/backgrounds\" \"$HOME/.config/omarchy/backgrounds/$t\" \"$HOME/Pictures/Wallpapers\" \"$HOME/Pictures\" -maxdepth 1 -type f \\( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' \\) 2>/dev/null | sort -u | head -90"]
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
    Rectangle { anchors.fill: parent; color: Qt.rgba(0, 0, 0, 0.10) }
    MouseArea { anchors.fill: parent; onClicked: root.dismiss() }

    Rectangle {
      id: card
      anchors.centerIn: parent
      width: Math.min(parent.width - 40, Style.space(800))
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

      // ---- Barre latérale (panneau de verre inséré, comme Tahoe)
      Rectangle {
        id: sidebar
        x: Style.space(8); y: Style.space(8)
        width: Style.space(228)
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
            Text { visible: !searchInput.text; anchors.verticalCenter: parent.verticalCenter; text: "Rechercher"; font: searchInput.font; color: root.fg; opacity: 0.4 }
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
            if (!item || nav.height < Style.space(120) || navCol.implicitHeight <= 0) return
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
                Text { textFormat: Text.PlainText; text: "Compte local"; font.family: root.uiFont; font.pixelSize: Style.space(11); color: root.page === "users" ? "white" : root.fg; opacity: 0.6 }
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
                  height: Style.space(30)
                  radius: Style.space(9)
                  color: current ? root.accent : (navMouse.containsMouse ? Qt.rgba(root.fg.r, root.fg.g, root.fg.b, 0.07) : "transparent")
                  Behavior on color { ColorAnimation { duration: 120 } }
                  Rectangle {
                    id: navIcon
                    x: Style.space(6)
                    anchors.verticalCenter: parent.verticalCenter
                    width: Style.space(21); height: width; radius: Style.space(6)
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
                    font.family: root.uiFont; font.pixelSize: Style.space(12.5)
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
          text: root.busy ? "Application…" : "Enregistré automatiquement"
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
            displays: pDisplays, menubar: pMenubar, wallpaper: pWallpaper,
            notifications: pNotifications, sound: pSound, focus: pFocus, music: pMusic,
            lock: pLock, users: pUsers, keyboard: pKeys, corners: pCorners, about: pAbout
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
          sub: root.wifiOn ? (root.ssid ? "Connecté à « " + root.ssid + " »" : "Non connecté") : "Désactivé"
          icon: 0xF05A9; iconColor: "#0a84ff"
          Switch_ { checked: root.wifiOn; onToggled: function(v) { root.wifiOn = v; root.run(["nmcli", "radio", "wifi", v ? "on" : "off"]) } }
        }
      }
      SectionTitle { text: "Réseaux disponibles"; visible: root.wifiOn }
      Group {
        visible: root.wifiOn && root.wifiList.length > 0
        Repeater {
          model: root.wifiList
          delegate: Row_ {
            required property var modelData
            label: modelData.ssid
            sub: modelData.current ? "Connecté" : (modelData.secure ? "Sécurisé" : "Ouvert")
            icon: modelData.signal > 66 ? 0xF0928 : (modelData.signal > 33 ? 0xF0925 : 0xF091F)
            iconColor: modelData.current ? "#0a84ff" : "#8e8e93"
            Btn {
              visible: !modelData.current
              text: "Se connecter"
              secondary: true
              onClicked: root.run(["sh", "-c", "nmcli device wifi connect \"$1\" || omarchy-shell omarchy.network toggle", "sh", modelData.ssid])
            }
          }
        }
      }
      Row {
        spacing: Style.space(8)
        Btn { text: "Actualiser"; secondary: true; onClicked: root.run(["nmcli", "device", "wifi", "rescan"]) }
        Btn { text: "Réglages du réseau…"; secondary: true; onClicked: { root.dismiss(); root.launch(["omarchy-shell", "omarchy.network", "toggle"]) } }
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
          sub: root.bt ? (root.bt.enabled ? "Activé — visible en tant que « " + (root.bt.name || "Omarchy") + " »" : "Désactivé") : "Aucun adaptateur"
          icon: 0xF00AF; iconColor: "#0a84ff"
          Switch_ { checked: !!(root.bt && root.bt.enabled); onToggled: function(v) { if (root.bt) root.bt.enabled = v } }
        }
      }
      SectionTitle { text: "Mes appareils"; visible: devRep.count > 0 }
      Group {
        visible: devRep.count > 0
        Repeater {
          id: devRep
          model: root.bt && root.bt.devices ? root.bt.devices.values.filter(function(d) { return d.paired || d.connected }) : []
          delegate: Row_ {
            required property var modelData
            label: modelData.name || modelData.address
            sub: modelData.connected ? "Connecté" + (modelData.batteryAvailable ? " — " + Math.round(modelData.battery * 100) + " %" : "") : "Non connecté"
            icon: 0xF00AF; iconColor: modelData.connected ? "#0a84ff" : "#8e8e93"
            Btn { text: modelData.connected ? "Déconnecter" : "Connecter"; secondary: true; onClicked: modelData.connected = !modelData.connected }
          }
        }
      }
      Btn { text: "Ajouter un appareil…"; secondary: true; onClicked: { root.dismiss(); root.launch(["omarchy-shell", "omarchy.bluetooth", "toggle"]) } }
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
            sub: modelData.state === "connected" ? "Connecté — " + modelData.conn + " (" + modelData.dev + ")" : "Non connecté (" + modelData.dev + ")"
            icon: modelData.type === "wifi" ? 0xF05A9 : 0xF0200
            iconColor: modelData.state === "connected" ? "#30d158" : "#8e8e93"
            Dot { on: modelData.state === "connected" }
          }
        }
        Row_ { visible: root.devices.length === 0; label: "Aucune interface réseau" }
      }
      Btn { text: "Détails…"; secondary: true; onClicked: { root.dismiss(); root.launch(["omarchy-shell", "omarchy.network", "toggle"]) } }
    }
  }

  Component {
    id: pBattery
    Column {
      spacing: Style.space(14)
      Group {
        Row_ {
          label: root.hasBat ? "Niveau de la batterie" : "Pas de batterie"
          sub: root.hasBat ? (UPower.onBattery ? "Sur batterie" : "Branché sur secteur") : ""
          icon: 0xF0079; iconColor: "#30d158"
          Label_ { visible: root.hasBat; text: root.hasBat ? Math.round(root.batDev.percentage * 100) + " %" : ""; opacity: 0.9; font.weight: Font.DemiBold }
        }
        Row_ {
          visible: root.hasBat
          label: "Charge"
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
      SectionTitle { text: "Mode d'énergie" }
      Group {
        Row_ {
          label: "Profil"
          sub: "Économie d'énergie, équilibré ou performances"
          Seg {
            options: [["0", "Économie"], ["1", "Équilibré"], ["2", "Performances"]]
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
        Row_ { label: "Nom de l'ordinateur"; icon: 0xF0379; iconColor: "#8e8e93"; Label_ { text: Quickshell.env("HOSTNAME") || "Omarchy" } }
        Row_ { label: "Système"; icon: 0xF08C7; iconColor: "#8e8e93"; Label_ { text: "Omarchy — Liquid Glass" } }
      }
      Group {
        ToggleRow { label: "Raccourcis façon macOS"; key: "keys.macos_shortcuts"; def: true; sub: "⌘Espace, ⌘Q, ⌘Tab, ⌘↑, ⌘⇧3/4/5…"; icon: 0xF030C; iconColor: "#8e8e93" }
        ToggleRow { label: "Animations à ressort"; key: "glass.animations"; def: true; icon: 0xF0E61; iconColor: "#ff9f0a" }
      }
      Group {
        Row_ { label: "Réappliquer tous les réglages"; icon: 0xF0450; iconColor: "#30d158"; Btn { text: "Appliquer"; secondary: true; onClicked: root.launch(["liquid-glass", "apply"]) } }
        Row_ { label: "Ouvrir le fichier de configuration"; icon: 0xF0214; iconColor: "#0a84ff"; Btn { text: "Ouvrir"; secondary: true; onClicked: { root.dismiss(); root.launch(["xdg-open", root.home + "/.config/liquid-glass/config.toml"]) } } }
      }
    }
  }

  Component {
    id: pAppearance
    Column {
      spacing: Style.space(14)
      Group {
        Row_ {
          label: "Apparence"
          Row {
            spacing: Style.space(14)
            Repeater {
              model: [["light", "Clair"], ["dark", "Sombre"], ["auto", "Auto"]]
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
          label: "Passage au clair"
          visible: root.val("appearance.mode", "light") === "auto"
          Stepper { value: root.val("appearance.auto_light_at", "07:30"); onChanged_: function(v) { root.set("appearance.auto_light_at", v) } }
        }
        Row_ {
          label: "Passage au sombre"
          visible: root.val("appearance.mode", "light") === "auto"
          Stepper { value: root.val("appearance.auto_dark_at", "19:30"); onChanged_: function(v) { root.set("appearance.auto_dark_at", v) } }
        }
      }
      SectionTitle { text: "Verre" }
      Group {
        Row_ {
          label: "Style du verre"
          sub: "Clair : plus transparent · Teinté : plus opaque"
          Seg {
            options: [["clear", "Clair"], ["standard", "Standard"], ["tinted", "Teinté"]]
            value: root.val("glass.style", "standard")
            onPicked: function(v) { root.set("glass.style", v) }
          }
        }
        SliderRow { label: "Opacité du verre"; key: "glass.opacity"; from: 0.5; to: 1.4; step: 0.05; def: 1.0; fmt: function(v) { return Math.round(v * 100) + " %" } }
        SliderRow { label: "Intensité du flou"; key: "glass.blur_size"; from: 2; to: 14; step: 1; def: 7 }
        SliderRow { label: "Passes de flou"; key: "glass.blur_passes"; from: 1; to: 4; step: 1; def: 3 }
        SliderRow { label: "Arrondi des fenêtres"; key: "glass.rounding"; from: 0; to: 28; step: 1; def: 16; fmt: function(v) { return v + " px" } }
      }
      Group {
        SliderRow { label: "Fenêtre active"; key: "glass.window_opacity_active"; from: 0.7; to: 1.0; step: 0.01; def: 0.96; fmt: function(v) { return Math.round(v * 100) + " %" } }
        SliderRow { label: "Fenêtres inactives"; key: "glass.window_opacity_inactive"; from: 0.6; to: 1.0; step: 0.01; def: 0.9; fmt: function(v) { return Math.round(v * 100) + " %" } }
        SliderRow { label: "Terminal (clair)"; key: "terminal.opacity_light"; from: 0.5; to: 1.0; step: 0.02; def: 0.8; fmt: function(v) { return Math.round(v * 100) + " %" } }
        SliderRow { label: "Terminal (sombre)"; key: "terminal.opacity_dark"; from: 0.5; to: 1.0; step: 0.02; def: 0.76; fmt: function(v) { return Math.round(v * 100) + " %" } }
        SliderRow { label: "Espace entre fenêtres"; key: "glass.gaps_in"; from: 0; to: 20; step: 1; def: 5; fmt: function(v) { return v + " px" } }
        SliderRow { label: "Marge d'écran"; key: "glass.gaps_out"; from: 0; to: 40; step: 1; def: 10; fmt: function(v) { return v + " px" } }
      }
      SectionTitle { text: "Police" }
      Group {
        FontRow { label: "Police de l'interface"; key: "appearance.font_ui"; def: "Inter" }
      }
      Hint { text: "Opacité du verre, police et terminal : le thème est régénéré (≈1 s). Le reste s'applique instantanément." }
    }
  }

  Component {
    id: pControl
    Column {
      spacing: Style.space(14)
      Hint { text: "Choisissez les boutons ronds du Centre de contrôle (le mode sombre est toujours affiché). L'ordre suit cette liste." }
      Group {
        Repeater {
          model: [["nightshift", "Night Shift", 0xF06E8, "#ff9f0a"], ["awake", "Rester éveillé", 0xF0176, "#a2845e"], ["screenshot", "Capture d'écran", 0xF0100, "#8e8e93"],
                  ["record", "Enregistrement de l'écran", 0xF044A, "#ff453a"], ["glass", "Style du verre", 0xF0F5A, "#32ade6"], ["lyrics", "Paroles sur le bureau", 0xF0387, "#ff375f"],
                  ["karaoke", "Karaoké", 0xF0E54, "#bf5af2"], ["mission", "Mission Control", 0xF0570, "#0a84ff"], ["desktop", "Afficher le bureau", 0xF01C4, "#30d158"],
                  ["lock", "Verrouiller l'écran", 0xF033E, "#1c1c1e"], ["calculator", "Calculette", 0xF00EC, "#ff9f0a"], ["clipboard", "Presse-papiers", 0xF014F, "#8e8e93"],
                  ["emoji", "Émojis", 0xF0785, "#ffd60a"], ["settings", "Réglages", 0xF0493, "#8e8e93"]]
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
        SliderRow { label: "Taille"; key: "dock.icon_size"; from: 32; to: 72; step: 2; def: 42; fmt: function(v) { return v + " px" } }
        SliderRow { label: "Agrandissement"; key: "dock.magnification"; from: 1.0; to: 2.2; step: 0.1; def: 1.6; fmt: function(v) { return v <= 1.0 ? "Désactivé" : "×" + v.toFixed(1) } }
        ToggleRow { label: "Toujours visible"; key: "dock.always_visible"; def: true }
        ToggleRow { label: "Masquer automatiquement"; key: "dock.autohide"; def: false }
      }
      SectionTitle { text: "Widgets" }
      Group {
        ToggleRow { label: "Widgets sur le bureau"; key: "widgets.enabled"; def: true }
        Row_ {
          label: "Colonne"
          Seg { options: [["left", "À gauche"], ["right", "À droite"]]; value: root.val("widgets.position", "left"); onPicked: function(v) { root.set("widgets.position", v) } }
        }
        ToggleRow { label: "Horloge"; key: "widgets.clock"; def: true }
        Row_ {
          label: "Style de l'horloge"
          visible: root.val("widgets.clock", true) === true
          Seg { options: [["digital", "Numérique"], ["analog", "Cadran"]]; value: String(root.val("widgets.clock_style", "digital")); onPicked: function(v) { root.set("widgets.clock_style", v) } }
        }
        ToggleRow { label: "Calendrier"; key: "widgets.calendar"; def: true }
        ToggleRow { label: "Météo"; key: "widgets.weather"; def: true }
        Row_ {
          label: "Taille de la météo"
          visible: root.val("widgets.weather", true) === true
          Seg { options: [["wide", "Large (heures)"], ["small", "Petite"]]; value: String(root.val("widgets.weather_size", "wide")); onPicked: function(v) { root.set("widgets.weather_size", v) } }
        }
        ToggleRow { label: "Batterie"; key: "widgets.battery"; def: true }
        Row_ {
          label: "Ville de la météo"
          TextBox { value: String(root.val("widgets.weather_city", "")); placeholder: "Automatique"; onCommitted: function(t) { root.set("widgets.weather_city", t) } }
        }
      }
      SectionTitle { text: "Widget musique" }
      Group {
        ToggleRow { label: "Lecture en cours sur le bureau"; key: "widgets.music"; def: true; sub: "Glissez-le où vous voulez : il glisse et rebondit" }
        Row_ {
          label: "Taille"
          Seg { options: [["small", "Petit"], ["medium", "Moyen"], ["large", "Grand"]]; value: root.val("widgets.music_size", "medium"); onPicked: function(v) { root.set("widgets.music_size", v) } }
        }
        Row_ {
          label: "Position"
          Btn { text: "Replacer"; secondary: true; onClicked: { root.set("widgets.music_x", -1); root.set("widgets.music_y", -1) } }
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
          label: "Luminosité"
          icon: 0xF00DF; iconColor: "#0a84ff"
          LiveSlider {
            value: root.brightness
            onMoved: function(v) { root.brightness = Math.max(0.03, v); brightApply.pct = Math.round(root.brightness * 100); brightApply.restart() }
          }
        }
        Row_ {
          label: "Night Shift"
          sub: "Couleurs plus chaudes le soir"
          icon: 0xF06E8; iconColor: "#ff9f0a"
          Switch_ { checked: root.nightlight; onToggled: function(v) { root.nightlight = v; root.run(["omarchy-shell", "nightlight", "toggle"]) } }
        }
      }
      Btn { text: "Moniteurs…"; secondary: true; onClicked: { root.dismiss(); root.launch(["omarchy-shell", "omarchy.monitor", "toggle"]) } }
    }
  }

  Component {
    id: pMenubar
    Column {
      spacing: Style.space(14)
      Group {
        Row_ {
          label: "Logo de la barre"
          sub: "Le menu tout à gauche"
          Seg {
            options: [["pomme", "Pomme"], ["arch", "Arch"], ["tux", "Tux"], ["omarchy", "Omarchy"], ["orb", "Bille"], ["goutte", "Goutte"]]
            value: root.val("appearance.logo", "pomme")
            onPicked: function(v) { root.set("appearance.logo", v) }
          }
        }
        ToggleRow { label: "Paroles dans la barre"; key: "lyrics.bar"; def: true; sub: "La ligne chantée remplace le titre du morceau" }
      }
      Hint { text: "La barre est celle d'Omarchy, habillée en verre par le thème Liquid Glass. Organisation des widgets : omarchy bar --help." }
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
          Image { anchors.fill: parent; source: root.currentBg ? "file://" + root.currentBg : ""; fillMode: Image.PreserveAspectCrop; sourceSize: Qt.size(400, 240); asynchronous: true }
        }
        Column {
          anchors.verticalCenter: parent.verticalCenter
          spacing: Style.space(8)
          Text { textFormat: Text.PlainText; text: root.currentBg ? root.currentBg.split("/").pop().replace(/\.[^.]+$/, "") : "—"; font.family: root.uiFont; font.pixelSize: Style.space(14); font.weight: Font.DemiBold; color: root.fg; width: Style.space(260); elide: Text.ElideRight }
          Row {
            spacing: Style.space(8)
            Btn { text: "Ouvrir le dossier"; secondary: true; onClicked: { root.dismiss(); root.launch(["omarchy", "theme", "bg", "install"]) } }
            Btn { text: "Actualiser"; secondary: true; onClicked: root.refresh() }
          }
        }
      }
      SectionTitle { text: "Pendant la musique" }
      Group {
        Row_ {
          label: "Fond d'écran Spotify"
          sub: "Off : le fond normal reste, seul le widget s'affiche"
          Seg {
            options: [["off", "Off"], ["cover", "Pochette"], ["blur", "Flou"], ["gradient", "Dégradé"]]
            value: String(root.val("spotify.wallpaper", "off"))
            onPicked: function(v) { root.set("spotify.wallpaper", v) }
          }
        }
      }
      SectionTitle { text: "Fonds d'écran" }
      Grid {
        id: bgGrid
        width: parent.width
        columns: 3
        spacing: Style.space(10)
        readonly property real cw: (width - 2 * spacing) / 3
        Repeater {
          model: root.backgrounds
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
              Image { anchors.fill: parent; anchors.margins: bgItem.on ? 3 : 0; source: "file://" + bgItem.modelData; fillMode: Image.PreserveAspectCrop; sourceSize: Qt.size(320, 200); asynchronous: true }
              scale: bgMouse.pressed ? 0.92 : (bgMouse.containsMouse ? 1.04 : 1)
              Behavior on scale { NumberAnimation { duration: 340; easing.type: Easing.OutBack; easing.overshoot: 2.6 } }
              MouseArea { id: bgMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: { root.currentBg = bgItem.modelData; root.launch(["omarchy", "theme", "bg", "set", bgItem.modelData]) } }
            }
            Text { width: bgGrid.cw; horizontalAlignment: Text.AlignHCenter; elide: Text.ElideMiddle; textFormat: Text.PlainText; text: bgItem.modelData.split("/").pop().replace(/\.[^.]+$/, ""); font.family: root.uiFont; font.pixelSize: Style.space(10); color: root.fg; opacity: 0.6 }
          }
        }
      }
    }
  }

  Component {
    id: pNotifications
    Column {
      spacing: Style.space(14)
      Group {
        Row_ {
          label: "Ne pas déranger"
          sub: "Les notifications sont silencieuses"
          icon: 0xF0594; iconColor: "#5e5ce6"
          Switch_ { checked: root.dnd; onToggled: function(v) { root.dnd = v; root.run(["omarchy-shell", "notifications", "setDnd", v ? "on" : "off"]) } }
        }
      }
      SectionTitle { text: "Écran verrouillé" }
      Group {
        Row_ {
          label: "Aperçu des notifications"
          Seg {
            options: [["full", "Complet"], ["summary", "Résumé"], ["count", "Nombre"], ["off", "Aucun"]]
            value: String(root.val("lock.notifications", "summary"))
            onPicked: function(v) { root.set("lock.notifications", v) }
          }
        }
      }
      Btn { text: "Historique des notifications"; secondary: true; onClicked: { root.dismiss(); root.launch(["omarchy-shell", "notifications", "showHistory"]) } }
    }
  }

  Component {
    id: pSound
    Column {
      spacing: Style.space(14)
      Group {
        Row_ {
          label: "Volume de sortie"
          icon: 0xF057E; iconColor: "#ff2d55"
          LiveSlider {
            value: root.sink && root.sink.audio ? Math.min(1, root.sink.audio.volume) : 0
            onMoved: function(v) { if (root.sink && root.sink.audio) { root.sink.audio.muted = false; root.sink.audio.volume = v } }
          }
        }
        Row_ {
          label: "Muet"
          Switch_ { checked: !!(root.sink && root.sink.audio && root.sink.audio.muted); onToggled: function(v) { if (root.sink && root.sink.audio) root.sink.audio.muted = v } }
        }
      }
      SectionTitle { text: "Sortie" }
      Group {
        Repeater {
          model: root.sinks
          delegate: Row_ {
            required property var modelData
            label: modelData.description || modelData.nickname || modelData.name
            icon: 0xF04C3; iconColor: modelData === root.sink ? "#ff2d55" : "#8e8e93"
            Dot { visible: modelData === root.sink; on: true }
            Btn { visible: modelData !== root.sink; text: "Utiliser"; secondary: true; onClicked: Pipewire.preferredDefaultAudioSink = modelData }
          }
        }
      }
    }
  }

  Component {
    id: pFocus
    Column {
      spacing: Style.space(14)
      Hint { text: "Un mode de concentration coupe les notifications. Sommeil active aussi Night Shift." }
      Group {
        Repeater {
          model: [["dnd", "Ne pas déranger", 0xF0594, "#5e5ce6"], ["work", "Travail", 0xF0D6B, "#30b0c7"],
                  ["personal", "Personnel", 0xF0004, "#bf5af2"], ["sleep", "Sommeil", 0xF04B2, "#64d2ff"]]
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
        ToggleRow { label: "Couleurs de la pochette"; key: "spotify.dynamic_colors"; def: true; sub: "Accent, bordures, barre, dock et terminal"; icon: 0xF03D8; iconColor: "#ff9f0a" }
        SliderRow { label: "Retour au fond après pause"; key: "spotify.restore_after_minutes"; from: 0; to: 30; step: 1; def: 5; fmt: function(v) { return v === 0 ? "Jamais" : v + " min" } }
      }
      SectionTitle { text: "Paroles" }
      Group {
        ToggleRow { label: "Sur le bureau, en grand"; key: "lyrics.desktop"; def: false; sub: "Derrière les fenêtres" }
        ToggleRow { label: "Widget flottant"; key: "lyrics.widget"; def: false; sub: "Carte déplaçable ; double-clic pour le karaoké" }
        ToggleRow { label: "Dans la barre"; key: "lyrics.bar"; def: true }
        Row_ { label: "Karaoké plein écran"; Btn { text: "Ouvrir  ⌘⌥M"; secondary: true; onClicked: { root.dismiss(); root.launch(["omarchy-shell", "liquid-glass.spotify", "karaoke"]) } } }
      }
      SectionTitle { text: "Visualiseur" }
      Group {
        ToggleRow { label: "Visualiseur audio"; key: "visualizer.enabled"; def: false; sub: "cava en bas du fond d'écran pendant la lecture" }
        SliderRow { label: "Nombre de barres"; key: "visualizer.bars"; from: 16; to: 128; step: 8; def: 64 }
      }
      Hint { text: "Paroles synchronisées fournies par LRCLIB (gratuit, sans compte), mises en cache dans ~/.cache/liquid-glass." }
    }
  }

  Component {
    id: pLock
    Column {
      spacing: Style.space(14)
      Group {
        ToggleRow { label: "Widget musique"; key: "lock.music_card"; def: true; sub: "Au-dessus de l'avatar ; la bulle l'agrandit" }
        Row_ {
          label: "Fond quand la pochette est agrandie"
          Seg {
            options: [["art", "Pochette floue"], ["off", "Fond normal"]]
            value: String(root.val("lock.music_background", "art")) === "off" ? "off" : "art"
            onPicked: function(v) { root.set("lock.music_background", v) }
          }
        }
        ToggleRow { label: "Paroles synchronisées"; key: "lock.lyrics"; def: true; sub: "À côté du widget agrandi" }
        ToggleRow { label: "Horloge 24 heures"; key: "lock.clock_24h"; def: true }
        ToggleRow { label: "Fond d'écran flouté"; key: "lock.wallpaper_blur"; def: false }
        ToggleRow { label: "Batterie en haut à droite"; key: "lock.status"; def: true }
      }
      SectionTitle { text: "Horloge" }
      Row {
        spacing: Style.space(10)
        Repeater {
          model: [["glass", "Verre"], ["bold", "Classique"], ["light", "Fine"]]
          delegate: Column {
            id: cs
            required property var modelData
            readonly property bool on: String(root.val("lock.clock_style", "glass")) === modelData[0]
            spacing: Style.space(4)
            Rectangle {
              width: Style.space(96); height: Style.space(62); radius: Style.space(12)
              clip: true
              border.width: cs.on ? 3 : 0; border.color: root.accent
              Image { anchors.fill: parent; source: root.currentBg ? "file://" + root.currentBg : ""; fillMode: Image.PreserveAspectCrop; sourceSize: Qt.size(200, 130); asynchronous: true }
              Text {
                anchors.centerIn: parent
                textFormat: Text.PlainText
                text: "9:41"
                font.family: String(root.val("lock.clock_font", "")) || root.uiFont
                font.pixelSize: Style.space(26)
                font.weight: cs.modelData[0] === "light" ? Font.Light : (cs.modelData[0] === "glass" ? Font.DemiBold : Font.Bold)
                color: "white"
                opacity: cs.modelData[0] === "glass" ? 0.85 : 1
                style: Text.Raised; styleColor: Qt.rgba(0, 0, 0, 0.25)
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
        FontRow { label: "Police de l'horloge"; key: "lock.clock_font"; def: ""; allowDefault: true }
      }
      Row {
        spacing: Style.space(8)
        Btn { text: "Aperçu"; secondary: true; onClicked: { root.dismiss(); root.launch(["sh", "-c", "omarchy-shell lock preview; sleep 8; omarchy-shell lock hidePreview"]) } }
        Btn { text: "Verrouiller maintenant"; onClicked: { root.dismiss(); root.launch(["omarchy-shell", "lock", "lock"]) } }
        Btn { text: "Replacer le widget"; secondary: true; onClicked: { root.set("lock.music_x", -1); root.set("lock.music_y", -1) } }
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
        Row_ { label: "Nom complet"; Label_ { text: root.fullName || "—" } }
        Row_ { label: "Nom du compte"; Label_ { text: root.userName } }
        Row_ { label: "Dossier de départ"; Label_ { text: root.home } }
        Row_ {
          label: "Photo"
          sub: "Affichée sur l'écran verrouillé (~/.face)"
          Btn {
            text: "Changer…"; secondary: true
            onClicked: root.run(["sh", "-c", "f=$(zenity --file-selection --title='Photo du compte' --file-filter='Images | *.png *.jpg *.jpeg *.webp') && magick \"$f\" -resize 256x256^ -gravity center -extent 256x256 \"$HOME/.face.png\" && mv \"$HOME/.face.png\" \"$HOME/.face\""])
          }
        }
      }
    }
  }

  Component {
    id: pKeys
    Column {
      spacing: Style.space(14)
      Group {
        ToggleRow { label: "Raccourcis façon macOS"; key: "keys.macos_shortcuts"; def: true; sub: "⌘Espace, ⌘Q, ⌘Tab, ⌘↑, ⌘⇧3/4/5… Désactivé : raccourcis Omarchy d'origine" }
        Row_ { label: "Aide-mémoire des raccourcis"; Btn { text: "Afficher  ⌘K"; secondary: true; onClicked: { root.dismiss(); root.launch(["omarchy-shell", "liquid-glass.cheatsheet", "toggle"]) } } }
      }
    }
  }

  Component {
    id: pCorners
    Column {
      spacing: Style.space(14)
      Group {
        CornerRow { label: "En haut à gauche"; key: "hotcorners.top_left" }
        CornerRow { label: "En haut à droite"; key: "hotcorners.top_right" }
        CornerRow { label: "En bas à gauche"; key: "hotcorners.bottom_left" }
        CornerRow { label: "En bas à droite"; key: "hotcorners.bottom_right" }
      }
      Hint { text: "Pointez dans un coin de l'écran pour déclencher l'action (pas en plein écran). ⌘F3 affiche aussi le bureau." }
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
        Row_ { label: "Configuration"; sub: "~/.config/liquid-glass"; Btn { text: "Ouvrir"; secondary: true; onClicked: { root.dismiss(); root.launch(["xdg-open", root.home + "/.config/liquid-glass"]) } } }
        Row_ { label: "Thème actif"; Label_ { text: root.dark ? "Liquid Glass Dark" : "Liquid Glass" } }
        Row_ { label: "Réappliquer tout"; sub: "Régénère thème, Hyprland, dock et shell"; Btn { text: "Appliquer"; secondary: true; onClicked: root.launch(["liquid-glass", "apply"]) } }
      }
      Hint { text: "Pour tout annuler : ~/.config-backup-<date>/restore.sh restaure l'état d'avant l'installation." }
    }
  }

  // Ligne de coin actif : un bouton qui fait défiler les actions.
  component CornerRow: Row_ {
    id: cr
    property string key: ""
    readonly property var actions: [["", "—"], ["mission", "Mission Control"], ["desktop", "Afficher le bureau"], ["spotlight", "Spotlight"],
                                    ["control", "Centre de contrôle"], ["karaoke", "Paroles karaoké"], ["lock", "Verrouiller l'écran"], ["settings", "Réglages"]]
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
    radius: Style.space(16)
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
    height: visible ? Math.max(Style.space(46), labels.implicitHeight + Style.space(18)) : 0
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
      anchors.verticalCenter: parent.verticalCenter
      width: parent.width - x - slot.width - Style.space(28)
      spacing: 1
      Text { width: parent.width; textFormat: Text.PlainText; text: r.label; elide: Text.ElideRight; font.family: root.uiFont; font.pixelSize: Style.space(13); color: root.fg }
      Text { width: parent.width; visible: r.sub !== ""; textFormat: Text.PlainText; text: r.sub; wrapMode: Text.WordWrap; font.family: root.uiFont; font.pixelSize: Style.space(11); color: root.fg; opacity: 0.5 }
    }
    Item {
      id: slot
      anchors.right: parent.right; anchors.rightMargin: Style.space(14)
      anchors.verticalCenter: parent.verticalCenter
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
      readonly property var it: seg.idx >= 0 ? segRep.itemAt(seg.idx) : null
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
    width: Style.space(200); height: Style.space(22)
    Rectangle {
      id: lsTrack
      anchors.fill: parent
      radius: height / 2
      color: Qt.rgba(root.fg.r, root.fg.g, root.fg.b, 0.12)
      clip: true
      Rectangle {
        width: Math.max(lsTrack.height, lsTrack.width * Math.max(0, Math.min(1, ls.value)))
        height: parent.height; radius: height / 2
        color: root.dark ? Qt.rgba(1, 1, 1, 0.9) : "white"
        border.width: 1; border.color: Qt.rgba(0, 0, 0, 0.08)
        Behavior on width { enabled: !lsArea.pressed; NumberAnimation { duration: 200; easing.type: Easing.OutBack } }
      }
    }
    MouseArea {
      id: lsArea
      anchors.fill: parent
      preventStealing: true
      cursorShape: Qt.PointingHandCursor
      function apply(x) { ls.moved(Math.max(0, Math.min(1, x / width))) }
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
        text: (fr.current || "Police de l'interface") + "  ⌄"
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
        placeholder: "Filtrer les polices"
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
            text: fi.modelData === "" ? "Police de l'interface" : fi.modelData
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
