import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import Quickshell.Bluetooth
import Quickshell.Services.Mpris
import Quickshell.Services.Pipewire
import qs.Commons
import qs.Commons as Commons
import qs.Ui
import "T.js" as T

// Liquid Glass — Centre de contrôle façon macOS Tahoe : pas de panneau, des
// capsules de verre séparées qui flottent sous la barre et arrivent en cascade.
//   Confidentialité (micro / enregistrement d'écran, bouton Arrêter), si actif
//   Concentration · Wi-Fi · Bluetooth | Lecture en cours (carré) · Mode avion
//   Boutons ronds : mode sombre + [control] buttons de config.toml
//   Capsules Son (sortie audio) et Écran ; « Modifier les commandes… ».
// Aucune interrogation périodique : l'état est relu à l'ouverture et après chaque action.
// Raccourci : omarchy-shell liquid-glass.control toggle
Panel {
  id: root
  moduleName: "liquid-glass.control"
  ipcTarget: "liquid-glass.control"

  readonly property string iconFont: Style.font.family   // Nerd Font (glyphes)
  readonly property color fg: Commons.Color.popups.text
  readonly property color accent: Commons.Color.accent
  readonly property bool lightUi: Commons.Color.background.hslLightness > 0.5

  function g(cp) { return String.fromCodePoint(cp) }

  // ------------------------------------------------------------ config
  property var cfg: ({})
  FileView {
    path: Quickshell.env("HOME") + "/.config/liquid-glass/config.json"
    watchChanges: true
    printErrors: false
    onFileChanged: reload()
    onLoaded: { try { root.cfg = JSON.parse(text()) } catch (e) {} }
  }
  readonly property string uiFont: (cfg.appearance && cfg.appearance.font_ui) || "Inter"
  readonly property string glassStyle: (cfg.glass && cfg.glass.style) || "standard"
  readonly property var defaultButtons: ["nightshift", "awake", "screenshot", "record", "glass", "lyrics", "mission", "settings"]
  readonly property var buttons: cfg.control && Array.isArray(cfg.control.buttons) ? cfg.control.buttons : defaultButtons
  // Pastilles comme sur la vidéo de référence : Concentration, Wi-Fi, Arrêter | Lecture en cours, Mode Jeu.
  // [control] tiles = 3 identifiants parmi wifi bluetooth airplane record gamemode nightshift awake dark.
  readonly property var defaultTiles: ["wifi", "record", "gamemode"]
  readonly property var tiles: {
    var t = cfg.control && Array.isArray(cfg.control.tiles) ? cfg.control.tiles : defaultTiles
    var out = []
    for (var i = 0; i < 3; i++) out.push(t[i] !== undefined ? String(t[i]) : defaultTiles[i])
    return out
  }

  // ------------------------------------------------------------ édition
  // « Modifier les commandes » dans le panneau lui-même, comme macOS Tahoe :
  // les commandes tremblent ; clic sur une pastille = la changer, « − » retire
  // un bouton rond, glisser le réordonne, la rangée « Ajouter » en propose d'autres.
  property bool editing: false
  readonly property var allTiles: ["wifi", "bluetooth", "airplane", "record", "gamemode", "nightshift", "awake", "dark"]
  readonly property var allButtons: ["nightshift", "awake", "screenshot", "record", "glass", "lyrics", "karaoke", "mission", "desktop", "lock", "calculator", "clipboard", "emoji", "settings"]
  // Boutons ronds affichés (sans « dark », toujours premier, ni ceux déjà en pastille).
  readonly property var roundIds: root.buttons.filter(function(b) { return b !== "dark" && root.tiles.indexOf(b) === -1 })
  readonly property var addable: root.allButtons.filter(function(b) { return root.buttons.indexOf(b) === -1 && root.tiles.indexOf(b) === -1 })
  function saveList(key, list) { root.run(["liquid-glass", "set", "control." + key, JSON.stringify(list)]) }
  function cycleTile(slot) {
    var t = root.tiles.slice()
    var start = root.allTiles.indexOf(t[slot])
    for (var i = 1; i <= root.allTiles.length; i++) {
      var cand = root.allTiles[(start + i) % root.allTiles.length]
      if (t.indexOf(cand) === -1) { t[slot] = cand; break }
    }
    root.saveList("tiles", t)
  }
  function removeButton(id) { root.saveList("buttons", root.buttons.filter(function(b) { return b !== id })) }
  function addButton(id) { root.saveList("buttons", root.buttons.concat([id])) }
  // Déplace un bouton rond (indices dans roundIds) en gardant les autres à leur place.
  function moveButton(from, to) {
    var r = root.roundIds.slice()
    if (from < 0 || from >= r.length) return
    to = Math.max(0, Math.min(r.length - 1, to))
    if (from === to) return
    var id = r.splice(from, 1)[0]
    r.splice(to, 0, id)
    var hidden = root.buttons.filter(function(b) { return r.indexOf(b) === -1 && b !== id })
    root.saveList("buttons", hidden.concat(r))
  }

  // ------------------------------------------------------------ état
  property bool wifiOn: true
  property string ssid: ""
  property bool airplane: false
  property bool dnd: false
  property string focusMode: "off"
  property string focusLabel: ""
  property bool focusMenu: false
  property bool nightlight: false
  property bool darkMode: false
  property bool awake: false
  property bool recording: false
  property bool gameMode: false
  property int micUsers: 0
  property real brightness: 1.0

  readonly property var btAdapter: Bluetooth.defaultAdapter
  readonly property bool btOn: btAdapter ? btAdapter.enabled : false
  readonly property string btLabel: {
    if (!btAdapter || !btOn) return T.t("Désactivé")
    var devs = btAdapter.devices ? btAdapter.devices.values : []
    for (var i = 0; i < devs.length; i++) if (devs[i].connected) return devs[i].name
    return T.t("Activé")
  }

  readonly property var sink: Pipewire.defaultAudioSink
  PwObjectTracker { objects: root.sink ? [root.sink] : [] }
  readonly property real volume: sink && sink.audio ? sink.audio.volume : 0
  readonly property bool muted: sink && sink.audio ? sink.audio.muted : false
  readonly property string sinkName: sink ? (sink.description || sink.nickname || sink.name || "") : ""

  // Lecteur : Spotify d'abord, sinon celui qui joue, sinon le premier.
  readonly property var player: {
    var ps = Mpris.players ? Mpris.players.values : []
    var playing = null, spotify = null
    for (var i = 0; i < ps.length; i++) {
      var id = String(ps[i].identity || ps[i].desktopEntry || "").toLowerCase()
      if (id.indexOf("spotify") !== -1) spotify = ps[i]
      if (ps[i].isPlaying && !playing) playing = ps[i]
    }
    return spotify || playing || (ps.length ? ps[0] : null)
  }
  readonly property bool hasTrack: !!player && (player.trackTitle || "") !== ""
  // Pochette en cache (nette, locale) publiée par liquid-glass.spotify.
  property var np: ({})
  FileView {
    path: Quickshell.env("HOME") + "/.cache/liquid-glass/now-playing.json"
    watchChanges: true
    printErrors: false
    onFileChanged: reload()
    onLoaded: { try { root.np = JSON.parse(text()) } catch (e) {} }
  }
  readonly property string coverSource: {
    if (!hasTrack) return ""
    if (np.title === player.trackTitle && np.cover) return "file://" + np.cover
    // Jamais d'URL réseau dans une Image : le chargeur d'images de Qt ouvre
    // alors OpenSSL depuis plusieurs threads au démarrage du shell, ce qui a
    // fait planter Quickshell. La pochette en cache (file://) arrive juste après.
    var a = String(player.trackArtUrl || "")
    return a.indexOf("file://") === 0 ? a : ""
  }

  function refresh() {
    wifiProc.running = true
    dndProc.running = true
    focusProc.running = true
    nightProc.running = true
    awakeProc.running = true
    recProc.running = true
    micProc.running = true
    gameProc.running = true
    themeFile.reload()
    brightProc.running = true
  }

  function run(argv) {
    actionProc.command = argv
    actionProc.running = true
  }
  function launch(argv) { root.close(); Util.execArgv(argv) }

  // Fermeture comme sur la vidéo : les capsules repartent en cascade inverse (le bas
  // d'abord) ; le panneau reste ouvert le temps de cette sortie.
  property bool closing: false
  Timer { id: closeHold; interval: 330; onTriggered: root.closing = false }
  onOpenedChanged: {
    if (opened) { closeHold.stop(); closing = false; refresh() }
    else { focusMenu = false; editing = false; closing = true; closeHold.restart() }
  }
  Component.onCompleted: themeFile.reload()

  Process {
    id: wifiProc
    // Radios et connexion Wi-Fi active, lues sans lancer de scan (instantané).
    command: ["sh", "-c", "nmcli -t -f WIFI radio; nmcli -t -f NAME,TYPE connection show --active 2>/dev/null | grep ':802-11-wireless$' | head -1 | sed 's/:802-11-wireless$//'; nmcli -t -f WWAN radio 2>/dev/null"]
    stdout: StdioCollector {
      onStreamFinished: {
        var lines = text.split("\n")
        root.wifiOn = (lines[0] || "").trim() === "enabled"
        root.ssid = (lines[1] || "").trim()
        root.airplane = !root.wifiOn && !root.btOn
      }
    }
  }
  Process {
    id: dndProc
    command: ["omarchy-shell", "notifications", "isDnd"]
    stdout: StdioCollector { onStreamFinished: root.dnd = text.trim() === "on" }
  }
  Process {
    id: focusProc
    command: ["liquid-glass", "focus", "status"]
    stdout: StdioCollector {
      onStreamFinished: { try { var j = JSON.parse(text); root.focusMode = j.mode; root.focusLabel = j.label } catch (e) {} }
    }
  }
  Process {
    id: nightProc
    command: ["omarchy-shell", "nightlight", "status"]
    stdout: StdioCollector {
      onStreamFinished: { try { root.nightlight = JSON.parse(text).enabled === true } catch (e) {} }
    }
  }
  Process {
    id: awakeProc
    command: ["omarchy", "toggle", "idle", "status"]
    stdout: StdioCollector {
      onStreamFinished: { try { root.awake = JSON.parse(text).enabled === true } catch (e) {} }
    }
  }
  Process {
    id: recProc
    command: ["sh", "-c", "pgrep -x gpu-screen-recorder >/dev/null && echo on || echo off"]
    stdout: StdioCollector { onStreamFinished: root.recording = text.trim() === "on" }
  }
  Process {
    id: gameProc
    command: ["liquid-glass", "gamemode", "status"]
    stdout: StdioCollector { onStreamFinished: { try { root.gameMode = JSON.parse(text).enabled === true } catch (e) {} } }
  }
  Process {
    id: micProc
    // Applications qui écoutent le micro (indicateur de confidentialité).
    command: ["sh", "-c", "pactl list source-outputs short 2>/dev/null | wc -l"]
    stdout: StdioCollector { onStreamFinished: root.micUsers = parseInt(text.trim()) || 0 }
  }
  Process {
    id: brightProc
    command: ["brightnessctl", "-m"]
    stdout: StdioCollector {
      onStreamFinished: {
        var parts = text.trim().split(",")
        var pct = parseFloat(parts[3])
        if (isFinite(pct)) root.brightness = pct / 100
      }
    }
  }
  Process {
    id: actionProc
    onExited: root.refresh()
  }
  FileView {
    id: themeFile
    path: Quickshell.env("HOME") + "/.local/state/omarchy/current/theme.name"
    watchChanges: true
    onFileChanged: reload()
    onLoaded: root.darkMode = text().trim() === "liquid-glass-dark"
  }

  // Luminosité : applique sans OSD, avec un léger anti-rebond pendant le glissé.
  Timer {
    id: brightApply
    interval: 40
    property int pct: 100
    onTriggered: Util.execArgv(["omarchy-brightness-display", "--no-osd", pct + "%"])
  }

  // ------------------------------------------------------------ boutons ronds
  // [id] → { libellé, glyphe, actif, action }
  function buttonInfo(id) {
    switch (id) {
    case "dark": return { label: darkMode ? T.t("Mode sombre") : T.t("Mode clair"), glyph: 0xF050E, on: darkMode, act: function() { root.run(["liquid-glass", "mode", "toggle"]) } }
    case "nightshift": return { label: "Night Shift", glyph: 0xF06E8, on: nightlight, act: function() { root.run(["omarchy-shell", "nightlight", "toggle"]) } }
    case "awake": return { label: T.t("Rester éveillé"), glyph: 0xF0176, on: awake, act: function() { root.run(["omarchy", "toggle", "idle", "toggle"]) } }
    case "screenshot": return { label: T.t("Capture"), glyph: 0xF0100, on: false, act: function() { root.launch(["omarchy", "capture", "screenshot", "region"]) } }
    case "record": return { label: recording ? T.t("Arrêter") : T.t("Enregistrer"), glyph: recording ? 0xF04DB : 0xF044A, on: recording,
                            act: function() { root.launch(recording ? ["omarchy", "capture", "screenrecording", "--stop-recording"] : ["omarchy", "capture", "screenrecording"]) } }
    case "glass": return { label: glassStyle === "clear" ? T.t("Verre clair") : (glassStyle === "tinted" ? T.t("Verre teinté") : T.t("Verre")), glyph: 0xF0F5A, on: glassStyle !== "standard",
                           act: function() { var n = { standard: "clear", clear: "tinted", tinted: "standard" }[glassStyle] || "standard"; root.run(["liquid-glass", "set", "glass.style", n]) } }
    case "lyrics": return { label: T.t("Paroles"), glyph: 0xF0387, on: !(cfg.lyrics && cfg.lyrics.desktop === false), act: function() { root.run(["omarchy-shell", "liquid-glass.spotify", "desktop"]) } }
    case "karaoke": return { label: T.t("Karaoké"), glyph: 0xF0E54, on: false, act: function() { root.launch(["omarchy-shell", "liquid-glass.spotify", "karaoke"]) } }
    case "mission": return { label: "Mission Control", glyph: 0xF0570, on: false, act: function() { root.launch(["omarchy-shell", "shell", "toggle", "liquid-glass.mission"]) } }
    case "desktop": return { label: T.t("Bureau"), glyph: 0xF01C4, on: false, act: function() { root.launch(["liquid-glass", "show-desktop"]) } }
    case "lock": return { label: T.t("Verrouiller"), glyph: 0xF033E, on: false, act: function() { root.launch(["omarchy-shell", "lock", "lock"]) } }
    case "calculator": return { label: T.t("Calculette"), glyph: 0xF00EC, on: false, act: function() { root.launch(["omarchy-shell", "shell", "summon", "liquid-glass.spotlight", "{\"query\":\"=\"}"]) } }
    case "clipboard": return { label: T.t("Presse-papiers"), glyph: 0xF014F, on: false, act: function() { root.launch(["omarchy-shell", "shell", "summon", "liquid-glass.spotlight", "{\"mode\":\"clipboard\"}"]) } }
    case "emoji": return { label: T.t("Émojis"), glyph: 0xF0785, on: false, act: function() { root.launch(["omarchy-shell", "shell", "toggle", "omarchy.emojis"]) } }
    case "settings": return { label: T.t("Réglages"), glyph: 0xF0493, on: false, act: function() { root.launch(["omarchy-shell", "liquid-glass.settings", "toggle"]) } }
    }
    return null
  }

  // ------------------------------------------------------------ pastilles
  // [id] → { icon, title, subtitle, on, color, act, secondary }
  function tileInfo(id) {
    switch (id) {
    case "wifi": return { icon: wifiOn ? 0xF05A9 : 0xF05AA, title: "Wi-Fi", subtitle: wifiOn ? (ssid || T.t("Non connecté")) : T.t("Désactivé"), on: wifiOn, color: accent,
                          act: function() { root.run(["nmcli", "radio", "wifi", root.wifiOn ? "off" : "on"]) },
                          secondary: function() { root.launch(["omarchy-shell", "omarchy.network", "toggle"]) } }
    case "bluetooth": return { icon: btOn ? 0xF00AF : 0xF00B2, title: "Bluetooth", subtitle: btLabel, on: btOn, color: accent,
                               act: function() { if (root.btAdapter) root.btAdapter.enabled = !root.btOn },
                               secondary: function() { root.launch(["omarchy-shell", "omarchy.bluetooth", "toggle"]) } }
    case "airplane": return { icon: 0xF001D, title: T.t("Mode avion"), subtitle: airplane ? T.t("Activé") : T.t("Désactivé"), on: airplane, color: "#ff9f0a",
                              act: function() { var off = !root.airplane; if (root.btAdapter) root.btAdapter.enabled = !off; root.run(["nmcli", "radio", "all", off ? "off" : "on"]) },
                              secondary: null }
    case "record": return { icon: recording ? 0xF04DB : 0xF044A, title: recording ? T.t("Arrêter") : T.t("Enregistrer"), subtitle: recording ? T.t("Enregistrement…") : T.t("Écran"), on: true, color: "#ff3b30",
                            act: function() { root.launch(recording ? ["omarchy", "capture", "screenrecording", "--stop-recording"] : ["omarchy", "capture", "screenrecording"]) },
                            secondary: null }
    case "gamemode": return { icon: 0xF0297, title: T.t("Mode Jeu"), subtitle: gameMode ? T.t("Activé") : "Auto", on: gameMode, color: "#30d158",
                              act: function() { root.gameMode = !root.gameMode; root.run(["liquid-glass", "gamemode", "toggle"]) }, secondary: null }
    case "nightshift": return { icon: 0xF06E8, title: "Night Shift", subtitle: nightlight ? T.t("Activé") : T.t("Désactivé"), on: nightlight, color: "#ff9f0a",
                                act: function() { root.run(["omarchy-shell", "nightlight", "toggle"]) }, secondary: null }
    case "awake": return { icon: 0xF0176, title: T.t("Rester éveillé"), subtitle: awake ? T.t("Activé") : T.t("Désactivé"), on: awake, color: accent,
                           act: function() { root.run(["omarchy", "toggle", "idle", "toggle"]) }, secondary: null }
    case "dark": return { icon: 0xF050E, title: T.t("Mode sombre"), subtitle: darkMode ? T.t("Activé") : T.t("Désactivé"), on: darkMode, color: accent,
                          act: function() { root.run(["liquid-glass", "mode", "toggle"]) }, secondary: null }
    }
    return null
  }

  // ------------------------------------------------------------ bouton barre
  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    // Icône dessinée comme celle de macOS : deux interrupteurs superposés
    // (pastille à droite en haut, à gauche en bas).
    iconComponent: Component { Item {} }
    tooltipText: ""
    onPressed: function(b) { root.toggle() }
  }
  Column {
    anchors.centerIn: button
    spacing: Style.space(2.2)
    scale: button.pressScale
    readonly property color ink: button.foreground
    Repeater {
      model: [true, false]
      Rectangle {
        required property bool modelData
        width: Style.space(15); height: Style.space(6.4); radius: height / 2
        color: "transparent"
        border.width: Math.max(1.2, Style.space(1.3)); border.color: parent.ink
        Rectangle {
          width: parent.height - Style.space(2.6); height: width; radius: width / 2
          anchors.verticalCenter: parent.verticalCenter
          x: parent.modelData ? parent.width - width - Style.space(1.3) : Style.space(1.3)
          color: parent.parent.ink
        }
      }
    }
  }

  // ------------------------------------------------------------ panneau
  KeyboardPanel {
    id: panel
    anchorItem: button
    owner: root
    bar: root.bar
    open: root.opened || root.closing
    padding: Style.space(4)
    borderSpec: Border.none()
    focusTarget: panel.loadedContent
    contentWidth: Style.space(318)
    contentHeight: panel.fittedContentHeight(panel.loadedContentHeight)

    content: PanelKeyCatcher {
      id: catcher
      anchors.fill: parent
      implicitHeight: col.implicitHeight
      onCloseRequested: root.close()
      onTabRequested: function(d) { root.switchPanel(d) }
      // Pas de fond de panneau : seules les capsules sont dessinées.
      Component.onCompleted: {
        var p = catcher.parent
        while (p) {
          if (p.contentTopInset !== undefined && p.color !== undefined) { p.color = "transparent"; break }
          p = p.parent
        }
      }

      Column {
        id: col
        width: parent.width
        spacing: Style.space(9)
        readonly property real gap: Style.space(9)
        readonly property real half: (width - gap) / 2
        readonly property real pillH: Style.space(50)

        // ---- Confidentialité : micro / enregistrement d'écran
        Capsule {
          order: 0
          visible: root.recording || root.micUsers > 0
          width: parent.width
          height: visible ? privCol.implicitHeight + Style.space(18) : 0
          radius: Style.space(22)
          Column {
            id: privCol
            x: Style.space(12); y: Style.space(9)
            width: parent.width - Style.space(24)
            spacing: Style.space(6)
            PrivacyLine {
              visible: root.micUsers > 0
              width: parent.width
              dot: "#ff9f0a"; glyph: 0xF036C
              title: T.t("Micro")
              subtitle: root.micUsers > 1 ? root.micUsers + " applications" : T.t("Utilisé par une application")
            }
            PrivacyLine {
              visible: root.recording
              width: parent.width
              dot: "#bf5af2"; glyph: 0xF0A1C
              title: T.t("Enregistrement de l'écran")
              subtitle: T.t("En cours")
              stop: true
            }
          }
        }

        // ---- Pastilles | Lecture en cours
        Row {
          width: parent.width
          spacing: col.gap
          Column {
            width: col.half
            spacing: col.gap
            // Concentration, avec la liste des modes au chevron.
            Capsule {
              order: 1
              width: parent.width; height: col.pillH
              ToggleLine {
                anchors.fill: parent
                anchors.leftMargin: Style.space(9); anchors.rightMargin: Style.space(24)
                icon: root.g(0xF0594)
                title: T.t("Concentration")
                subtitle: root.focusMode !== "off" ? root.focusLabel : (root.dnd ? T.t("Ne pas déranger") : T.t("Désactivée"))
                active: root.focusMode !== "off" || root.dnd
                activeColor: "#5e5ce6"
                onClicked: root.run(["liquid-glass", "focus", "toggle"])
                onSecondary: root.focusMenu = !root.focusMenu
              }
              Text {
                anchors.right: parent.right; anchors.rightMargin: Style.space(9)
                anchors.verticalCenter: parent.verticalCenter
                textFormat: Text.PlainText
                text: root.g(0xF0140)
                rotation: root.focusMenu ? 180 : 0
                Behavior on rotation { NumberAnimation { duration: 420; easing.type: Easing.OutBack; easing.overshoot: 2.5 } }
                font.family: root.iconFont; font.pixelSize: Style.space(15)
                color: root.fg; opacity: 0.6
                MouseArea { anchors.fill: parent; anchors.margins: -8; cursorShape: Qt.PointingHandCursor; onClicked: root.focusMenu = !root.focusMenu }
              }
            }
            Repeater {
              model: root.tiles.slice(0, 2)
              delegate: TileCapsule { required property var modelData; required property int index; tile: modelData; slot: index; order: 2 + index }
            }
          }
          Column {
            width: col.half
            spacing: col.gap
            // Lecture en cours : carré (hauteur de deux pastilles).
            Capsule {
              order: 2
              width: parent.width; height: col.pillH * 2 + col.gap
              radius: Style.space(24)
              Item {
                anchors.fill: parent
                anchors.margins: Style.space(11)
                visible: root.hasTrack
                // Comme sur la vidéo : pochette en haut à gauche, titre et artiste dessous,
                // grandes commandes en bas.
                Item {
                  id: art
                  width: Style.space(34); height: width
                  Image { id: artImg; anchors.fill: parent; source: root.coverSource; sourceSize: Qt.size(128, 128); fillMode: Image.PreserveAspectCrop; asynchronous: true; visible: false }
                  Item { id: artMask; anchors.fill: parent; visible: false; layer.enabled: true
                    Rectangle { anchors.fill: parent; radius: Style.space(7); color: "black" } }
                  MultiEffect { anchors.fill: parent; source: artImg; maskEnabled: true; maskSource: artMask; maskThresholdMin: 0.5; maskSpreadAtMin: 1.0; visible: artImg.status === Image.Ready; shadowEnabled: true; shadowOpacity: 0.25; shadowBlur: 0.5; shadowVerticalOffset: 2 }
                  Rectangle { anchors.fill: parent; radius: Style.space(7); visible: artImg.status !== Image.Ready; color: root.fg; opacity: 0.1 }
                  // Changement de morceau : la pochette rebondit.
                  property string key: root.player ? (root.player.trackTitle || "") : ""
                  onKeyChanged: artPop.restart()
                  SequentialAnimation {
                    id: artPop
                    NumberAnimation { target: art; property: "scale"; to: 0.7; duration: 90; easing.type: Easing.OutQuad }
                    NumberAnimation { target: art; property: "scale"; to: 1; duration: 520; easing.type: Easing.OutBack; easing.overshoot: 3 }
                  }
                }
                Column {
                  anchors.left: parent.left; anchors.right: parent.right
                  anchors.top: art.bottom; anchors.topMargin: Style.space(5)
                  Label { width: parent.width; text: root.player ? (root.player.trackTitle || "") : ""; font.weight: Font.DemiBold; font.pixelSize: Style.space(11); elide: Text.ElideRight }
                  Label { width: parent.width; text: root.player ? (root.player.trackArtist || "") : ""; opacity: 0.6; font.pixelSize: Style.space(10); elide: Text.ElideRight }
                }
                Row {
                  anchors.horizontalCenter: parent.horizontalCenter
                  anchors.bottom: parent.bottom; anchors.bottomMargin: -Style.space(3)
                  spacing: Style.space(2)
                  IconButton { glyph: root.g(0xF04AE); size: Style.space(17); onClicked: if (root.player) root.player.previous() }
                  IconButton {
                    glyph: root.player && root.player.isPlaying ? root.g(0xF03E4) : root.g(0xF040A)
                    size: Style.space(22)
                    onClicked: if (root.player) root.player.togglePlaying()
                  }
                  IconButton { glyph: root.g(0xF04AD); size: Style.space(17); onClicked: if (root.player) root.player.next() }
                }
              }
              Column {
                anchors.centerIn: parent
                visible: !root.hasTrack
                spacing: Style.space(6)
                Text { anchors.horizontalCenter: parent.horizontalCenter; textFormat: Text.PlainText; text: root.g(0xF075A); font.family: root.iconFont; font.pixelSize: Style.space(26); color: root.fg; opacity: 0.35 }
                Rectangle {
                  anchors.horizontalCenter: parent.horizontalCenter
                  width: openLbl.implicitWidth + Style.space(16); height: Style.space(22); radius: height / 2
                  color: Qt.rgba(root.fg.r, root.fg.g, root.fg.b, openMouse.containsMouse ? 0.16 : 0.09)
                  Label { id: openLbl; anchors.centerIn: parent; text: T.t("Ouvrir Spotify"); font.pixelSize: Style.font.caption; font.weight: Font.DemiBold }
                  MouseArea { id: openMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.launch(["omarchy-launch-or-focus", "spotify", "spotify"]) }
                }
              }
            }
            TileCapsule { tile: root.tiles[2]; slot: 2; order: 4 }
          }
        }

        // ---- Modes de concentration (dépliable)
        Capsule {
          order: 0
          visible: root.focusMenu
          width: parent.width
          height: visible ? focusCol.implicitHeight + Style.space(12) : 0
          radius: Style.space(20)
          Column {
            id: focusCol
            x: Style.space(6); y: Style.space(6)
            width: parent.width - Style.space(12)
            Repeater {
              model: [["dnd", T.t("Ne pas déranger"), 0xF0594, "#5e5ce6"], ["work", T.t("Travail"), 0xF0D6B, "#30b0c7"],
                      ["personal", T.t("Personnel"), 0xF0004, "#bf5af2"], ["sleep", T.t("Sommeil"), 0xF04B2, "#64d2ff"]]
              delegate: Rectangle {
                id: fm
                required property var modelData
                readonly property bool on: root.focusMode === modelData[0]
                width: focusCol.width; height: Style.space(36); radius: height / 2
                color: fmMouse.containsMouse ? Qt.rgba(root.fg.r, root.fg.g, root.fg.b, 0.08) : "transparent"
                Rectangle {
                  id: fmDot
                  x: Style.space(6); anchors.verticalCenter: parent.verticalCenter
                  width: Style.space(26); height: width; radius: width / 2
                  color: fm.on ? fm.modelData[3] : Qt.rgba(root.fg.r, root.fg.g, root.fg.b, 0.12)
                  Text { anchors.centerIn: parent; textFormat: Text.PlainText; text: root.g(fm.modelData[2]); font.family: root.iconFont; font.pixelSize: Style.space(13); color: fm.on ? "white" : root.fg }
                }
                Label { anchors.left: fmDot.right; anchors.leftMargin: Style.space(10); anchors.verticalCenter: parent.verticalCenter; text: fm.modelData[1]; font.pixelSize: Style.font.bodySmall; font.weight: fm.on ? Font.DemiBold : Font.Normal }
                Label { anchors.right: parent.right; anchors.rightMargin: Style.space(10); anchors.verticalCenter: parent.verticalCenter; visible: fm.on; text: T.t("Activé"); opacity: 0.5; font.pixelSize: Style.font.caption }
                MouseArea { id: fmMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                  onClicked: { root.run(["liquid-glass", "focus", fm.on ? "off" : fm.modelData[0]]); root.focusMenu = false } }
              }
            }
          }
        }

        // ---- Boutons ronds : chacun sa capsule de verre
        Flow {
          id: rounds
          width: parent.width
          spacing: col.gap
          readonly property real d: (width - 4 * col.gap) / 5
          Repeater {
            model: ["dark"].concat(root.roundIds)
            delegate: Capsule {
              id: rb
              required property var modelData
              required property int index
              readonly property var info: root.buttonInfo(modelData)
              editable: index > 0
              z: rbMouse.drag.active ? 5 : 0
              order: 5 + index
              visible: info !== null
              width: rounds.d; height: rounds.d
              radius: width / 2
              active: !!(info && info.on)
              Text {
                anchors.centerIn: parent
                textFormat: Text.PlainText
                text: rb.info ? root.g(rb.info.glyph) : ""
                font.family: root.iconFont; font.pixelSize: Style.space(19)
                color: rb.active ? "white" : root.fg
                scale: rbMouse.pressed ? 0.7 : 1
                Behavior on scale { NumberAnimation { duration: 340; easing.type: Easing.OutBack; easing.overshoot: 3.2 } }
              }
              // En édition : glisser pour réordonner (lâcher sur la place voulue).
              property real dragX: 0
              property real dragY: 0
              transform: [
                Translate { y: (1 - rb.t) * -Style.space(26) },
                Translate { x: rb.dragX; y: rb.dragY }
              ]
              Item { id: dragProxy }
              MouseArea {
                id: rbMouse
                anchors.fill: parent; hoverEnabled: true
                cursorShape: root.editing && rb.editable ? (pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor) : Qt.PointingHandCursor
                property point start
                property bool moved: false
                onPressed: function(m) { start = Qt.point(m.x, m.y); moved = false }
                onPositionChanged: function(m) {
                  if (!pressed || !root.editing || !rb.editable) return
                  rb.dragX = m.x - start.x; rb.dragY = m.y - start.y
                  if (Math.abs(rb.dragX) + Math.abs(rb.dragY) > 6) moved = true
                }
                onReleased: {
                  if (root.editing && rb.editable && moved) {
                    var step = rounds.d + col.gap
                    var perRow = Math.max(1, Math.round((rounds.width + col.gap) / step))
                    var cx = rb.x + rb.width / 2 + rb.dragX, cy = rb.y + rb.height / 2 + rb.dragY
                    var target = Math.round((Math.max(0, Math.min(perRow - 1, Math.floor(cx / step)))) + Math.max(0, Math.floor(cy / step)) * perRow)
                    root.moveButton(rb.index - 1, Math.max(1, target) - 1)
                  }
                  rb.dragX = 0; rb.dragY = 0
                }
                onClicked: if (!root.editing && rb.info) { rb.pulse(); rb.info.act() }
              }
              Behavior on dragX { enabled: !rbMouse.pressed; NumberAnimation { duration: 320; easing.type: Easing.OutBack } }
              Behavior on dragY { enabled: !rbMouse.pressed; NumberAnimation { duration: 320; easing.type: Easing.OutBack } }
              EditBadge { visible: root.editing && rb.editable; onClicked: root.removeButton(rb.modelData) }
              PanelToolTip { visible: rbMouse.containsMouse; text: rb.info ? rb.info.label : "" }
            }
          }
        }

        // ---- Ajouter (en édition) : les commandes absentes, « + » pour les ajouter.
        Capsule {
          visible: root.editing && root.addable.length > 0
          order: 12
          width: parent.width
          height: visible ? addCol.implicitHeight + Style.space(18) : 0
          radius: Style.space(22)
          Column {
            id: addCol
            x: Style.space(11); y: Style.space(9)
            width: parent.width - Style.space(22)
            spacing: Style.space(7)
            Label { text: T.t("Ajouter des commandes"); font.weight: Font.DemiBold; font.pixelSize: Style.font.bodySmall }
            Flow {
              width: parent.width
              spacing: Style.space(8)
              Repeater {
                model: root.addable
                delegate: Rectangle {
                  id: ad
                  required property var modelData
                  readonly property var info: root.buttonInfo(modelData)
                  visible: info !== null
                  width: Style.space(44); height: width; radius: width / 2
                  color: Qt.rgba(root.fg.r, root.fg.g, root.fg.b, adMouse.containsMouse ? 0.16 : 0.08)
                  scale: adMouse.pressed ? 0.8 : 1
                  Behavior on scale { NumberAnimation { duration: 320; easing.type: Easing.OutBack; easing.overshoot: 3 } }
                  Text { anchors.centerIn: parent; textFormat: Text.PlainText; text: ad.info ? root.g(ad.info.glyph) : ""; font.family: root.iconFont; font.pixelSize: Style.space(17); color: root.fg }
                  Rectangle {
                    x: parent.width - width * 0.8; y: -height * 0.2
                    width: Style.space(17); height: width; radius: width / 2
                    color: "#34c759"
                    Text { anchors.centerIn: parent; text: "+"; font.family: root.uiFont; font.pixelSize: Style.space(13); font.weight: Font.Bold; color: "white" }
                  }
                  MouseArea { id: adMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.addButton(ad.modelData) }
                  PanelToolTip { visible: adMouse.containsMouse; text: ad.info ? ad.info.label : "" }
                }
              }
            }
          }
        }

        // ---- Son
        Capsule {
          order: 13
          width: parent.width
          height: Style.space(66)
          radius: Style.space(24)
          Column {
            anchors.fill: parent
            anchors.margins: Style.space(11)
            spacing: Style.space(7)
            Item {
              width: parent.width; height: soundLbl.implicitHeight
              Label { id: soundLbl; text: T.t("Son"); font.weight: Font.DemiBold; font.pixelSize: Style.font.bodySmall }
              Label {
                anchors.right: parent.right; anchors.left: soundLbl.right; anchors.leftMargin: Style.space(12)
                horizontalAlignment: Text.AlignRight
                text: root.sinkName; opacity: 0.5; elide: Text.ElideLeft; font.pixelSize: Style.font.caption
              }
            }
            Row {
              width: parent.width
              spacing: Style.space(8)
              GlassSlider {
                width: parent.width - outBtn.width - parent.spacing
                icon: root.muted || root.volume <= 0.001 ? root.g(0xF0581) : root.g(0xF057F)
                iconRight: root.g(0xF057E)
                value: root.muted ? 0 : Math.min(1, root.volume)
                onMoved: function(v) {
                  if (!root.sink || !root.sink.audio) return
                  root.sink.audio.muted = false
                  root.sink.audio.volume = v
                }
                onIconClicked: if (root.sink && root.sink.audio) root.sink.audio.muted = !root.muted
              }
              // Sortie audio (comme le bouton AirPlay de macOS).
              Rectangle {
                id: outBtn
                width: Style.space(24); height: width; radius: width / 2
                color: Qt.rgba(root.fg.r, root.fg.g, root.fg.b, outMouse.containsMouse ? 0.18 : 0.1)
                Text { anchors.centerIn: parent; textFormat: Text.PlainText; text: root.g(0xF04C3); font.family: root.iconFont; font.pixelSize: Style.space(13); color: root.fg }
                MouseArea { id: outMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.launch(["omarchy-shell", "omarchy.audio", "toggle"]) }
              }
            }
          }
        }

        // ---- Écran
        Capsule {
          order: 14
          width: parent.width
          height: Style.space(66)
          radius: Style.space(24)
          Column {
            anchors.fill: parent
            anchors.margins: Style.space(11)
            spacing: Style.space(7)
            Label { text: T.t("Écran"); font.weight: Font.DemiBold; font.pixelSize: Style.font.bodySmall }
            GlassSlider {
              width: parent.width
              icon: root.g(0xF00DE)
              iconRight: root.g(0xF00E0)
              value: root.brightness
              onMoved: function(v) {
                root.brightness = Math.max(0.03, v)
                brightApply.pct = Math.round(root.brightness * 100)
                brightApply.restart()
              }
            }
          }
        }

        // ---- Modifier les commandes
        Item {
          width: parent.width
          height: Style.space(30)
          Capsule {
            order: 15
            anchors.centerIn: parent
            width: editLbl.implicitWidth + Style.space(24); height: Style.space(28)
            radius: height / 2
            active: root.editing
            Label { id: editLbl; anchors.centerIn: parent; text: root.editing ? T.t("Terminé") : T.t("Modifier les commandes…"); color: root.editing ? "white" : root.fg; font.pixelSize: Style.font.caption; font.weight: Font.DemiBold }
            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor
              onClicked: root.editing = !root.editing
              // Clic droit : réglages détaillés.
              acceptedButtons: Qt.LeftButton | Qt.RightButton
              onPressed: function(m) { if (m.button === Qt.RightButton) root.launch(["omarchy-shell", "shell", "summon", "liquid-glass.settings", "{\"page\":\"control\"}"]) }
            }
          }
        }
      }
    }
  }

  // ------------------------------------------------------------ composants
  // Capsule de verre indépendante (le flou vient de Hyprland). Arrive en
  // cascade à l'ouverture (ordre = rang), avec un rebond marqué.
  component Capsule: Rectangle {
    id: cap
    property int order: 0
    property bool active: false
    property bool editable: false
    property real t: 0
    // Tremblement en mode édition (rythme propre à chaque commande).
    readonly property int jitter: 105 + Math.floor(Math.random() * 45)
    property real wob: 0
    rotation: wob
    SequentialAnimation {
      running: root.editing && cap.editable && root.opened
      loops: Animation.Infinite
      NumberAnimation { target: cap; property: "wob"; to: 1.6; duration: cap.jitter; easing.type: Easing.InOutSine }
      NumberAnimation { target: cap; property: "wob"; to: -1.6; duration: cap.jitter; easing.type: Easing.InOutSine }
      onRunningChanged: if (!running) cap.wob = 0
    }
    radius: Style.space(25)
    color: active ? root.accent
                  : (root.lightUi ? Qt.rgba(1, 1, 1, capHover.hovered ? 0.62 : 0.5) : Qt.rgba(0.16, 0.16, 0.18, capHover.hovered ? 0.62 : 0.5))
    Behavior on color { ColorAnimation { duration: 180 } }
    border.width: 1
    border.color: Qt.rgba(1, 1, 1, root.lightUi ? 0.7 : 0.16)
    HoverHandler { id: capHover }
    Rectangle {
      anchors.fill: parent; anchors.margins: 1
      radius: Math.max(0, parent.radius - 1)
      gradient: Gradient {
        GradientStop { position: 0.0; color: Qt.rgba(1, 1, 1, root.lightUi ? 0.35 : 0.08) }
        GradientStop { position: 0.55; color: Qt.rgba(1, 1, 1, 0) }
      }
    }
    opacity: t
    scale: 0.55 + 0.45 * t
    transform: Translate { y: (1 - cap.t) * -Style.space(26) }
    function pulse() { pulseAnim.restart() }
    SequentialAnimation {
      id: enter
      PropertyAction { target: cap; property: "t"; value: 0 }
      PauseAnimation { duration: Math.min(14, cap.order) * 28 }
      NumberAnimation { target: cap; property: "t"; to: 1; duration: 560; easing.type: Easing.OutBack; easing.overshoot: 2.2 }
    }
    SequentialAnimation {
      id: pulseAnim
      NumberAnimation { target: cap; property: "t"; to: 0.86; duration: 90; easing.type: Easing.OutQuad }
      NumberAnimation { target: cap; property: "t"; to: 1; duration: 520; easing.type: Easing.OutElastic; easing.amplitude: 1.2; easing.period: 0.35 }
    }
    SequentialAnimation {
      id: leave
      PauseAnimation { duration: Math.max(0, 15 - Math.min(15, cap.order)) * 16 }
      NumberAnimation { target: cap; property: "t"; to: 0; duration: 190; easing.type: Easing.InBack; easing.overshoot: 1.6 }
    }
    Connections {
      target: root
      function onOpenedChanged() { if (root.opened) { leave.stop(); enter.restart() } else { enter.stop(); leave.restart() } }
    }
    Component.onCompleted: if (root.opened) enter.restart(); else t = 0
  }

  // Pastille générique (voir tileInfo).
  component TileCapsule: Capsule {
    id: tc
    property string tile: ""
    property int slot: 0
    editable: true
    readonly property var info: root.tileInfo(tile)
    visible: info !== null
    width: parent ? parent.width : 0
    height: visible ? Style.space(50) : 0
    ToggleLine {
      anchors.fill: parent; anchors.leftMargin: Style.space(9); anchors.rightMargin: Style.space(6)
      icon: tc.info ? root.g(tc.info.icon) : ""
      title: tc.info ? tc.info.title : ""
      subtitle: tc.info ? tc.info.subtitle : ""
      active: !!(tc.info && tc.info.on)
      activeColor: tc.info ? tc.info.color : root.accent
      onClicked: if (tc.info) { tc.pulse(); tc.info.act() }
      onSecondary: if (tc.info && tc.info.secondary) tc.info.secondary()
    }
    // En édition, un clic change la pastille (commande suivante libre).
    MouseArea {
      z: 8
      anchors.fill: parent
      visible: root.editing
      cursorShape: Qt.PointingHandCursor
      onClicked: { tc.pulse(); root.cycleTile(tc.slot) }
    }
    Rectangle {
      z: 9
      visible: scale > 0.01
      scale: root.editing ? 1 : 0
      Behavior on scale { NumberAnimation { duration: 360; easing.type: Easing.OutBack; easing.overshoot: 2.4 } }
      x: -Style.space(5); y: -Style.space(5)
      width: Style.space(19); height: width; radius: width / 2
      color: Qt.rgba(0.32, 0.32, 0.35, 0.95)
      border.width: 1; border.color: Qt.rgba(1, 1, 1, 0.35)
      Text { anchors.centerIn: parent; textFormat: Text.PlainText; text: root.g(0xF0456); font.family: root.iconFont; font.pixelSize: Style.space(11); color: "white" }
    }
  }

  // « − » d'édition en haut à gauche d'une commande.
  component EditBadge: Rectangle {
    id: eb
    signal clicked()
    z: 9
    x: -Style.space(4); y: -Style.space(4)
    width: Style.space(18); height: width; radius: width / 2
    scale: visible ? (ebMouse.pressed ? 0.8 : 1) : 0
    Behavior on scale { NumberAnimation { duration: 360; easing.type: Easing.OutBack; easing.overshoot: 2.4 } }
    color: Qt.rgba(0.32, 0.32, 0.35, 0.95)
    border.width: 1; border.color: Qt.rgba(1, 1, 1, 0.35)
    Rectangle { anchors.centerIn: parent; width: parent.width * 0.48; height: Math.max(2, Math.round(parent.width * 0.11)); radius: height / 2; color: "white" }
    MouseArea { id: ebMouse; anchors.fill: parent; anchors.margins: -4; cursorShape: Qt.PointingHandCursor; onClicked: eb.clicked() }
  }

  component Label: Text {
    textFormat: Text.PlainText
    color: root.fg
    font.family: root.uiFont
    font.pixelSize: Style.font.body
  }

  // Ligne de confidentialité : pastille colorée, titre, détail, « Arrêter ».
  component PrivacyLine: Item {
    id: pl
    property color dot: "#ff9f0a"
    property int glyph: 0
    property string title: ""
    property string subtitle: ""
    property bool stop: false
    height: Style.space(34)
    Rectangle {
      id: plDot
      width: Style.space(26); height: width; radius: width / 2
      anchors.verticalCenter: parent.verticalCenter
      color: pl.dot
      Text { anchors.centerIn: parent; textFormat: Text.PlainText; text: root.g(pl.glyph); font.family: root.iconFont; font.pixelSize: Style.space(13); color: "white" }
    }
    Column {
      anchors.left: plDot.right; anchors.leftMargin: Style.space(9)
      anchors.right: stopBtn.visible ? stopBtn.left : parent.right; anchors.rightMargin: Style.space(6)
      anchors.verticalCenter: parent.verticalCenter
      Label { width: parent.width; text: pl.title; font.weight: Font.DemiBold; font.pixelSize: Style.font.bodySmall; elide: Text.ElideRight }
      Label { width: parent.width; text: pl.subtitle; opacity: 0.6; font.pixelSize: Style.font.caption; elide: Text.ElideRight }
    }
    Rectangle {
      id: stopBtn
      visible: pl.stop
      anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
      width: stopLbl.implicitWidth + Style.space(18); height: Style.space(22); radius: height / 2
      color: stopMouse.containsMouse ? "#ff5f57" : "#ff453a"
      scale: stopMouse.pressed ? 0.85 : 1
      Behavior on scale { NumberAnimation { duration: 300; easing.type: Easing.OutBack; easing.overshoot: 3 } }
      Text { id: stopLbl; anchors.centerIn: parent; textFormat: Text.PlainText; text: T.t("Arrêter"); font.family: root.uiFont; font.pixelSize: Style.font.caption; font.weight: Font.DemiBold; color: "white" }
      MouseArea { id: stopMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
        onClicked: root.launch(["omarchy", "capture", "screenrecording", "--stop-recording"]) }
    }
  }

  // Pastille ronde (accent si active) + titre + sous-titre.
  component ToggleLine: Item {
    id: tl
    property string icon: ""
    property string title: ""
    property string subtitle: ""
    property bool active: false
    property color activeColor: root.accent
    signal clicked()
    signal secondary()
    implicitHeight: Style.space(40)
    height: implicitHeight

    Rectangle {
      id: dot
      width: Style.space(30)
      height: width
      radius: width / 2
      anchors.verticalCenter: parent.verticalCenter
      color: tl.active ? tl.activeColor : Qt.rgba(root.fg.r, root.fg.g, root.fg.b, 0.12)
      Behavior on color { ColorAnimation { duration: Style.duration(140) } }
      scale: dotMouse.pressed ? 0.92 : 1
      Behavior on scale { NumberAnimation { duration: Style.duration(90) } }
      Text {
        anchors.centerIn: parent
        textFormat: Text.PlainText
        text: tl.icon
        font.family: root.iconFont
        font.pixelSize: Style.space(15)
        color: tl.active ? "#ffffff" : root.fg
      }
      MouseArea {
        id: dotMouse
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: function(m) { if (m.button === Qt.RightButton) tl.secondary(); else tl.clicked() }
      }
    }
    Column {
      anchors.left: dot.right
      anchors.leftMargin: Style.space(8)
      anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter
      Label {
        width: parent.width
        text: tl.title
        font.weight: Font.DemiBold
        font.pixelSize: Style.font.bodySmall
        wrapMode: Text.WordWrap
        maximumLineCount: tl.subtitle === "" ? 2 : 1
        elide: Text.ElideRight
        lineHeight: 0.95
      }
      Label {
        width: parent.width
        visible: tl.subtitle !== ""
        text: tl.subtitle
        opacity: 0.6
        elide: Text.ElideRight
        font.pixelSize: Style.font.caption
      }
    }
    MouseArea {
      anchors.fill: parent
      anchors.leftMargin: dot.width
      cursorShape: Qt.PointingHandCursor
      acceptedButtons: Qt.LeftButton | Qt.RightButton
      onClicked: function(m) { if (m.button === Qt.RightButton) tl.secondary(); else tl.clicked() }
    }
  }

  // Curseur fin comme sur la vidéo : petite icône à gauche, piste fine (remplissage
  // blanc + bouton), grande icône à droite. Le bouton grossit pendant le glissé.
  component GlassSlider: Item {
    id: sl
    property real value: 0
    property string icon: ""
    property string iconRight: icon
    signal moved(real v)
    signal iconClicked()
    height: Style.space(24)
    readonly property real v: Math.max(0, Math.min(1, value))

    Text {
      id: lIcon
      anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter
      width: Style.space(16)
      textFormat: Text.PlainText
      text: sl.icon
      font.family: root.iconFont; font.pixelSize: Style.space(11)
      color: root.fg; opacity: 0.75
      MouseArea { anchors.fill: parent; anchors.margins: -4; cursorShape: Qt.PointingHandCursor; onClicked: sl.iconClicked() }
    }
    Text {
      id: rIcon
      anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
      width: Style.space(18); horizontalAlignment: Text.AlignRight
      textFormat: Text.PlainText
      text: sl.iconRight
      font.family: root.iconFont; font.pixelSize: Style.space(15)
      color: root.fg; opacity: 0.75
    }
    Item {
      id: lane
      anchors.left: lIcon.right; anchors.leftMargin: Style.space(4)
      anchors.right: rIcon.left; anchors.rightMargin: Style.space(6)
      height: parent.height
      Rectangle {
        id: track
        anchors.verticalCenter: parent.verticalCenter
        width: parent.width; height: Style.space(5); radius: height / 2
        color: Qt.rgba(root.fg.r, root.fg.g, root.fg.b, 0.16)
        Rectangle {
          width: knob.x + knob.width / 2
          height: parent.height; radius: height / 2
          color: root.lightUi ? "#ffffff" : Qt.rgba(1, 1, 1, 0.92)
          border.width: root.lightUi ? 1 : 0; border.color: Qt.rgba(0, 0, 0, 0.08)
        }
      }
      Rectangle {
        id: knob
        width: Style.space(15); height: width; radius: width / 2
        anchors.verticalCenter: parent.verticalCenter
        x: sl.v * (lane.width - width)
        Behavior on x { enabled: !area.pressed; NumberAnimation { duration: Style.duration(140); easing.type: Easing.OutCubic } }
        color: "white"
        border.width: 1; border.color: Qt.rgba(0, 0, 0, 0.12)
        scale: area.pressed ? 1.3 : 1
        Behavior on scale { NumberAnimation { duration: 320; easing.type: Easing.OutBack; easing.overshoot: 3 } }
      }
      MouseArea {
        id: area
        anchors.fill: parent
        anchors.topMargin: -4; anchors.bottomMargin: -4
        preventStealing: true
        cursorShape: Qt.PointingHandCursor
        function apply(x) { sl.moved(Math.max(0, Math.min(1, (x - knob.width / 2) / (lane.width - knob.width)))) }
        onPressed: function(m) { apply(m.x) }
        onPositionChanged: function(m) { if (pressed) apply(m.x) }
      }
    }
    WheelHandler {
      onWheel: function(e) { sl.moved(Math.max(0, Math.min(1, sl.value + (e.angleDelta.y > 0 ? 0.05 : -0.05)))) }
    }
  }

  component IconButton: Item {
    id: ib
    property string glyph: ""
    property real size: Style.space(18)
    signal clicked()
    width: Style.space(28)
    height: Style.space(28)
    Rectangle {
      anchors.fill: parent
      radius: width / 2
      color: root.fg
      opacity: ibMouse.containsMouse ? 0.1 : 0
    }
    Text {
      anchors.centerIn: parent
      textFormat: Text.PlainText
      text: ib.glyph
      font.family: root.iconFont
      font.pixelSize: ib.size
      color: root.fg
      scale: ibMouse.pressed ? 0.88 : 1
    }
    MouseArea {
      id: ibMouse
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onClicked: ib.clicked()
    }
  }
}
