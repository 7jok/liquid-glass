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

// Liquid Glass — Centre de contrôle façon macOS Tahoe.
//   Haut : connectivité (Wi-Fi, Bluetooth, Mode avion) | lecture en cours
//   Puis : Concentration (avec ses modes) | Mode sombre | Verre (clair/teinté)
//   Curseurs : Écran, Son (sortie audio)
//   Boutons ronds personnalisables ([control] buttons dans config.toml)
//   « Modifier les commandes… » ouvre la page des Réglages.
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
  property real brightness: 1.0

  readonly property var btAdapter: Bluetooth.defaultAdapter
  readonly property bool btOn: btAdapter ? btAdapter.enabled : false
  readonly property string btLabel: {
    if (!btAdapter || !btOn) return "Désactivé"
    var devs = btAdapter.devices ? btAdapter.devices.values : []
    for (var i = 0; i < devs.length; i++) if (devs[i].connected) return devs[i].name
    return "Activé"
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
    var a = String(player.trackArtUrl || "")
    return a.indexOf("data:") === 0 ? "" : a
  }

  function refresh() {
    wifiProc.running = true
    dndProc.running = true
    focusProc.running = true
    nightProc.running = true
    awakeProc.running = true
    recProc.running = true
    themeFile.reload()
    brightProc.running = true
  }

  function run(argv) {
    actionProc.command = argv
    actionProc.running = true
  }
  function launch(argv) { root.close(); Util.execArgv(argv) }

  onOpenedChanged: { if (opened) refresh(); else focusMenu = false }
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
    case "nightshift": return { label: "Night Shift", glyph: 0xF06E8, on: nightlight, act: function() { root.run(["omarchy-shell", "nightlight", "toggle"]) } }
    case "awake": return { label: "Rester éveillé", glyph: 0xF0176, on: awake, act: function() { root.run(["omarchy", "toggle", "idle", "toggle"]) } }
    case "screenshot": return { label: "Capture", glyph: 0xF0100, on: false, act: function() { root.launch(["omarchy", "capture", "screenshot", "region"]) } }
    case "record": return { label: recording ? "Arrêter" : "Enregistrer", glyph: recording ? 0xF04DB : 0xF044A, on: recording,
                            act: function() { root.launch(recording ? ["omarchy", "capture", "screenrecording", "--stop-recording"] : ["omarchy", "capture", "screenrecording"]) } }
    case "glass": return { label: glassStyle === "clear" ? "Verre clair" : (glassStyle === "tinted" ? "Verre teinté" : "Verre"), glyph: 0xF0F5A, on: glassStyle !== "standard",
                           act: function() { var n = { standard: "clear", clear: "tinted", tinted: "standard" }[glassStyle] || "standard"; root.run(["liquid-glass", "set", "glass.style", n]) } }
    case "lyrics": return { label: "Paroles", glyph: 0xF0387, on: !(cfg.lyrics && cfg.lyrics.desktop === false), act: function() { root.run(["omarchy-shell", "liquid-glass.spotify", "desktop"]) } }
    case "karaoke": return { label: "Karaoké", glyph: 0xF0E54, on: false, act: function() { root.launch(["omarchy-shell", "liquid-glass.spotify", "karaoke"]) } }
    case "mission": return { label: "Mission Control", glyph: 0xF0570, on: false, act: function() { root.launch(["omarchy-shell", "shell", "toggle", "liquid-glass.mission"]) } }
    case "desktop": return { label: "Bureau", glyph: 0xF01C4, on: false, act: function() { root.launch(["liquid-glass", "show-desktop"]) } }
    case "lock": return { label: "Verrouiller", glyph: 0xF033E, on: false, act: function() { root.launch(["omarchy-shell", "lock", "lock"]) } }
    case "calculator": return { label: "Calculette", glyph: 0xF00EC, on: false, act: function() { root.launch(["omarchy-shell", "shell", "summon", "liquid-glass.spotlight", "{\"query\":\"=\"}"]) } }
    case "clipboard": return { label: "Presse-papiers", glyph: 0xF014F, on: false, act: function() { root.launch(["omarchy-shell", "shell", "summon", "liquid-glass.spotlight", "{\"mode\":\"clipboard\"}"]) } }
    case "emoji": return { label: "Émojis", glyph: 0xF0785, on: false, act: function() { root.launch(["omarchy-shell", "shell", "toggle", "omarchy.emojis"]) } }
    case "settings": return { label: "Réglages", glyph: 0xF0493, on: false, act: function() { root.launch(["omarchy-shell", "liquid-glass.settings", "toggle"]) } }
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
    text: root.g(0xF0521)   // interrupteurs (comme l'icône macOS)
    tooltipText: ""
    onPressed: function(b) { root.toggle() }
  }

  // ------------------------------------------------------------ panneau
  KeyboardPanel {
    id: panel
    anchorItem: button
    owner: root
    bar: root.bar
    open: root.opened
    padding: Style.space(12)
    focusTarget: panel.loadedContent
    contentWidth: Style.space(332)
    contentHeight: panel.fittedContentHeight(panel.loadedContentHeight)

    content: PanelKeyCatcher {
      anchors.fill: parent
      implicitHeight: col.implicitHeight
      onCloseRequested: root.close()
      onTabRequested: function(d) { root.switchPanel(d) }

      Column {
        id: col
        width: parent.width
        spacing: Style.space(10)
        readonly property real half: (width - Style.space(10)) / 2

        // ---- Ligne 1 : connectivité | lecture en cours
        Row {
          width: parent.width
          spacing: Style.space(10)

          Tile {
            width: col.half
            height: Style.space(150)
            Column {
              anchors.fill: parent
              anchors.margins: Style.space(10)
              spacing: Style.space(6)
              ToggleLine {
                width: parent.width
                icon: root.wifiOn ? root.g(0xF05A9) : root.g(0xF05AA)
                title: "Wi-Fi"
                subtitle: root.wifiOn ? (root.ssid || "Non connecté") : "Désactivé"
                active: root.wifiOn
                onClicked: root.run(["nmcli", "radio", "wifi", root.wifiOn ? "off" : "on"])
                onSecondary: root.launch(["omarchy-shell", "omarchy.network", "toggle"])
              }
              ToggleLine {
                width: parent.width
                icon: root.btOn ? root.g(0xF00AF) : root.g(0xF00B2)
                title: "Bluetooth"
                subtitle: root.btLabel
                active: root.btOn
                onClicked: if (root.btAdapter) root.btAdapter.enabled = !root.btOn
                onSecondary: root.launch(["omarchy-shell", "omarchy.bluetooth", "toggle"])
              }
              ToggleLine {
                width: parent.width
                icon: root.g(0xF001D)
                title: "Mode avion"
                subtitle: root.airplane ? "Activé" : ""
                active: root.airplane
                activeColor: "#ff9f0a"
                onClicked: {
                  var off = !root.airplane
                  if (root.btAdapter) root.btAdapter.enabled = !off
                  root.run(["nmcli", "radio", "all", off ? "off" : "on"])
                }
              }
            }
          }

          // Lecture en cours : pochette, titre, commandes (ou Spotify à ouvrir).
          Tile {
            id: musicTile
            width: col.half
            height: Style.space(150)
            clip: true
            Item {
              anchors.fill: parent
              anchors.margins: Style.space(11)
              visible: root.hasTrack
              Item {
                id: art
                width: Style.space(52); height: width
                Image { id: artImg; anchors.fill: parent; source: root.coverSource; sourceSize: Qt.size(128, 128); fillMode: Image.PreserveAspectCrop; asynchronous: true; visible: false }
                Rectangle { id: artMask; anchors.fill: parent; radius: Style.space(9); visible: false; layer.enabled: true }
                MultiEffect { anchors.fill: parent; source: artImg; maskEnabled: true; maskSource: artMask; visible: artImg.status === Image.Ready; shadowEnabled: true; shadowOpacity: 0.25; shadowBlur: 0.5; shadowVerticalOffset: 2 }
                Rectangle { anchors.fill: parent; radius: Style.space(9); visible: artImg.status !== Image.Ready; color: root.fg; opacity: 0.1
                  Text { anchors.centerIn: parent; textFormat: Text.PlainText; text: root.g(0xF075A); font.family: root.iconFont; font.pixelSize: Style.space(20); color: root.fg } }
              }
              Text {
                anchors.right: parent.right; anchors.top: parent.top
                textFormat: Text.PlainText
                text: root.g(0xF04C7)
                font.family: root.iconFont; font.pixelSize: Style.space(14)
                color: "#1db954"
                visible: String((root.player && (root.player.identity || root.player.desktopEntry)) || "").toLowerCase().indexOf("spotify") !== -1
              }
              Column {
                anchors.left: parent.left; anchors.right: parent.right
                anchors.top: art.bottom; anchors.topMargin: Style.space(8)
                spacing: 0
                Label { width: parent.width; text: root.player ? (root.player.trackTitle || "") : ""; font.weight: Font.DemiBold; font.pixelSize: Style.font.bodySmall; elide: Text.ElideRight }
                Label { width: parent.width; text: root.player ? (root.player.trackArtist || "") : ""; opacity: 0.6; font.pixelSize: Style.font.caption; elide: Text.ElideRight }
              }
              Row {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.bottom
                spacing: Style.space(6)
                IconButton { glyph: root.g(0xF04AE); onClicked: if (root.player) root.player.previous() }
                IconButton {
                  glyph: root.player && root.player.isPlaying ? root.g(0xF03E4) : root.g(0xF040A)
                  size: Style.space(22)
                  onClicked: if (root.player) root.player.togglePlaying()
                }
                IconButton { glyph: root.g(0xF04AD); onClicked: if (root.player) root.player.next() }
              }
            }
            Column {
              anchors.centerIn: parent
              visible: !root.hasTrack
              spacing: Style.space(8)
              Text { anchors.horizontalCenter: parent.horizontalCenter; textFormat: Text.PlainText; text: root.g(0xF075A); font.family: root.iconFont; font.pixelSize: Style.space(30); color: root.fg; opacity: 0.35 }
              Label { anchors.horizontalCenter: parent.horizontalCenter; text: "Aucune lecture"; opacity: 0.55; font.pixelSize: Style.font.caption }
              Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                width: openLbl.implicitWidth + Style.space(18); height: Style.space(24); radius: height / 2
                color: openMouse.containsMouse ? Qt.rgba(root.fg.r, root.fg.g, root.fg.b, 0.16) : Qt.rgba(root.fg.r, root.fg.g, root.fg.b, 0.09)
                Label { id: openLbl; anchors.centerIn: parent; text: "Ouvrir Spotify"; font.pixelSize: Style.font.caption; font.weight: Font.DemiBold }
                MouseArea { id: openMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.launch(["omarchy-launch-or-focus", "spotify", "spotify"]) }
              }
            }
          }
        }

        // ---- Ligne 2 : Concentration | Mode sombre + Verre
        Row {
          width: parent.width
          spacing: Style.space(10)
          Tile {
            width: col.half
            height: Style.space(62)
            ToggleLine {
              anchors.fill: parent
              anchors.margins: Style.space(10)
              anchors.rightMargin: Style.space(28)
              icon: root.g(0xF0594)
              title: "Concentration"
              subtitle: root.focusMode !== "off" ? root.focusLabel : (root.dnd ? "Ne pas déranger" : "")
              active: root.focusMode !== "off" || root.dnd
              activeColor: "#5e5ce6"
              onClicked: root.run(["liquid-glass", "focus", "toggle"])
              onSecondary: root.focusMenu = !root.focusMenu
            }
            // Chevron : liste des modes.
            Text {
              anchors.right: parent.right; anchors.rightMargin: Style.space(10)
              anchors.verticalCenter: parent.verticalCenter
              textFormat: Text.PlainText
              text: root.g(root.focusMenu ? 0xF0143 : 0xF0140)
              font.family: root.iconFont; font.pixelSize: Style.space(16)
              color: root.fg; opacity: 0.6
              MouseArea { anchors.fill: parent; anchors.margins: -8; cursorShape: Qt.PointingHandCursor; onClicked: root.focusMenu = !root.focusMenu }
            }
          }
          Row {
            spacing: Style.space(10)
            SquareToggle {
              width: (col.half - Style.space(10)) / 2; height: Style.space(62)
              icon: root.g(0xF050E); label: "Sombre"; active: root.darkMode
              onClicked: root.run(["liquid-glass", "mode", "toggle"])
            }
            SquareToggle {
              width: (col.half - Style.space(10)) / 2; height: Style.space(62)
              icon: root.g(0xF0F5A)
              label: root.glassStyle === "clear" ? "Clair" : (root.glassStyle === "tinted" ? "Teinté" : "Verre")
              active: root.glassStyle !== "standard"
              onClicked: { var n = { standard: "clear", clear: "tinted", tinted: "standard" }[root.glassStyle] || "standard"; root.run(["liquid-glass", "set", "glass.style", n]) }
            }
          }
        }

        // ---- Modes de concentration (dépliable)
        Tile {
          visible: root.focusMenu
          width: parent.width
          height: visible ? focusCol.implicitHeight + Style.space(12) : 0
          Column {
            id: focusCol
            x: Style.space(6); y: Style.space(6)
            width: parent.width - Style.space(12)
            Repeater {
              model: [["dnd", "Ne pas déranger", 0xF0594, "#5e5ce6"], ["work", "Travail", 0xF0D6B, "#30b0c7"],
                      ["personal", "Personnel", 0xF0004, "#bf5af2"], ["sleep", "Sommeil", 0xF04B2, "#64d2ff"]]
              delegate: Rectangle {
                id: fm
                required property var modelData
                readonly property bool on: root.focusMode === modelData[0]
                width: focusCol.width; height: Style.space(36); radius: Style.space(9)
                color: fmMouse.containsMouse ? Qt.rgba(root.fg.r, root.fg.g, root.fg.b, 0.08) : "transparent"
                Rectangle {
                  id: fmDot
                  x: Style.space(6); anchors.verticalCenter: parent.verticalCenter
                  width: Style.space(26); height: width; radius: width / 2
                  color: fm.on ? fm.modelData[3] : Qt.rgba(root.fg.r, root.fg.g, root.fg.b, 0.12)
                  Text { anchors.centerIn: parent; textFormat: Text.PlainText; text: root.g(fm.modelData[2]); font.family: root.iconFont; font.pixelSize: Style.space(13); color: fm.on ? "white" : root.fg }
                }
                Label { anchors.left: fmDot.right; anchors.leftMargin: Style.space(10); anchors.verticalCenter: parent.verticalCenter; text: fm.modelData[1]; font.pixelSize: Style.font.bodySmall; font.weight: fm.on ? Font.DemiBold : Font.Normal }
                Label { anchors.right: parent.right; anchors.rightMargin: Style.space(10); anchors.verticalCenter: parent.verticalCenter; visible: fm.on; text: "Activé"; opacity: 0.5; font.pixelSize: Style.font.caption }
                MouseArea { id: fmMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                  onClicked: { root.run(["liquid-glass", "focus", fm.on ? "off" : fm.modelData[0]]); root.focusMenu = false } }
              }
            }
          }
        }

        // ---- Écran
        Tile {
          width: parent.width
          height: Style.space(62)
          Column {
            anchors.fill: parent
            anchors.margins: Style.space(10)
            spacing: Style.space(6)
            Label { text: "Écran"; font.weight: Font.DemiBold }
            GlassSlider {
              width: parent.width
              icon: root.g(0xF00DF)
              value: root.brightness
              onMoved: function(v) {
                root.brightness = Math.max(0.03, v)
                brightApply.pct = Math.round(root.brightness * 100)
                brightApply.restart()
              }
            }
          }
        }

        // ---- Son
        Tile {
          width: parent.width
          height: Style.space(62)
          Column {
            anchors.fill: parent
            anchors.margins: Style.space(10)
            spacing: Style.space(6)
            Item {
              width: parent.width; height: soundLbl.implicitHeight
              Label { id: soundLbl; text: "Son"; font.weight: Font.DemiBold }
              Label {
                anchors.right: parent.right; anchors.left: soundLbl.right; anchors.leftMargin: Style.space(12)
                horizontalAlignment: Text.AlignRight
                text: root.sinkName; opacity: 0.5; elide: Text.ElideLeft; font.pixelSize: Style.font.caption
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.launch(["omarchy-shell", "omarchy.audio", "toggle"]) }
              }
            }
            GlassSlider {
              width: parent.width
              icon: root.muted || root.volume <= 0.001 ? root.g(0xF0581) : root.g(0xF057E)
              value: root.muted ? 0 : Math.min(1, root.volume)
              onMoved: function(v) {
                if (!root.sink || !root.sink.audio) return
                root.sink.audio.muted = false
                root.sink.audio.volume = v
              }
              onIconClicked: if (root.sink && root.sink.audio) root.sink.audio.muted = !root.muted
            }
          }
        }

        // ---- Boutons ronds (4 par ligne)
        Grid {
          id: grid
          width: parent.width
          columns: 4
          rowSpacing: Style.space(8)
          columnSpacing: 0
          Repeater {
            model: root.buttons
            delegate: Item {
              id: rb
              required property var modelData
              readonly property var info: root.buttonInfo(modelData)
              visible: info !== null
              width: grid.width / 4
              height: Style.space(70)
              Rectangle {
                id: circle
                anchors.horizontalCenter: parent.horizontalCenter
                width: Style.space(44); height: width; radius: width / 2
                color: rb.info && rb.info.on ? root.accent : Qt.rgba(root.fg.r, root.fg.g, root.fg.b, rbMouse.containsMouse ? 0.16 : 0.09)
                border.width: 1
                border.color: Qt.rgba(1, 1, 1, root.lightUi ? 0.6 : 0.08)
                scale: rbMouse.pressed ? 0.92 : 1
                Behavior on color { ColorAnimation { duration: Style.duration(140) } }
                Behavior on scale { NumberAnimation { duration: Style.duration(90) } }
                Text {
                  anchors.centerIn: parent
                  textFormat: Text.PlainText
                  text: rb.info ? root.g(rb.info.glyph) : ""
                  font.family: root.iconFont; font.pixelSize: Style.space(18)
                  color: rb.info && rb.info.on ? "white" : root.fg
                }
                MouseArea { id: rbMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: if (rb.info) rb.info.act() }
              }
              Label {
                anchors.top: circle.bottom; anchors.topMargin: Style.space(4)
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                text: rb.info ? rb.info.label : ""
                font.pixelSize: Style.font.caption
                elide: Text.ElideRight
                opacity: 0.8
              }
            }
          }
        }

        // ---- Modifier les commandes
        Item {
          width: parent.width
          height: Style.space(30)
          Rectangle {
            anchors.centerIn: parent
            width: editLbl.implicitWidth + Style.space(22); height: Style.space(28); radius: height / 2
            color: editMouse.containsMouse ? Qt.rgba(root.fg.r, root.fg.g, root.fg.b, 0.14) : Qt.rgba(root.fg.r, root.fg.g, root.fg.b, 0.07)
            Label { id: editLbl; anchors.centerIn: parent; text: "Modifier les commandes…"; font.pixelSize: Style.font.caption; font.weight: Font.DemiBold }
            MouseArea { id: editMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
              onClicked: root.launch(["omarchy-shell", "shell", "summon", "liquid-glass.settings", "{\"page\":\"control\"}"]) }
          }
        }
      }
    }
  }

  // ------------------------------------------------------------ composants
  // Tuile de verre aux coins arrondis, avec un reflet sur le haut.
  component Tile: Rectangle {
    radius: Style.space(18)
    color: Qt.rgba(root.fg.r, root.fg.g, root.fg.b, 0.07)
    border.width: 1
    border.color: Qt.rgba(1, 1, 1, root.lightUi ? 0.55 : 0.08)
    Rectangle {
      anchors.fill: parent; anchors.margins: 1
      radius: parent.radius - 1
      gradient: Gradient {
        GradientStop { position: 0.0; color: Qt.rgba(1, 1, 1, root.lightUi ? 0.22 : 0.05) }
        GradientStop { position: 0.6; color: Qt.rgba(1, 1, 1, 0) }
      }
    }
  }

  component Label: Text {
    textFormat: Text.PlainText
    color: root.fg
    font.family: root.uiFont
    font.pixelSize: Style.font.body
  }

  // Tuile carrée : icône ronde + libellé dessous (Mode sombre, Verre).
  component SquareToggle: Tile {
    id: sq
    property string icon: ""
    property string label: ""
    property bool active: false
    signal clicked()
    Rectangle {
      id: sqDot
      anchors.horizontalCenter: parent.horizontalCenter
      y: Style.space(7)
      width: Style.space(30); height: width; radius: width / 2
      color: sq.active ? root.accent : Qt.rgba(root.fg.r, root.fg.g, root.fg.b, 0.12)
      Behavior on color { ColorAnimation { duration: Style.duration(140) } }
      Text { anchors.centerIn: parent; textFormat: Text.PlainText; text: sq.icon; font.family: root.iconFont; font.pixelSize: Style.space(15); color: sq.active ? "white" : root.fg }
    }
    Label {
      anchors.top: sqDot.bottom; anchors.topMargin: Style.space(3)
      width: parent.width; horizontalAlignment: Text.AlignHCenter
      text: sq.label; font.pixelSize: Style.font.caption; font.weight: Font.DemiBold; elide: Text.ElideRight
    }
    scale: sqMouse.pressed ? 0.95 : 1
    Behavior on scale { NumberAnimation { duration: Style.duration(90) } }
    MouseArea { id: sqMouse; anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: sq.clicked() }
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

  // Curseur épais façon macOS : piste translucide, remplissage blanc, icône dedans.
  component GlassSlider: Item {
    id: sl
    property real value: 0
    property string icon: ""
    signal moved(real v)
    signal iconClicked()
    height: Style.space(24)

    Rectangle {
      id: track
      anchors.fill: parent
      radius: height / 2
      color: Qt.rgba(root.fg.r, root.fg.g, root.fg.b, 0.12)
      clip: true
      Rectangle {
        width: Math.max(track.height, track.width * Math.max(0, Math.min(1, sl.value)))
        height: parent.height
        radius: height / 2
        color: root.lightUi ? "#ffffff" : Qt.rgba(1, 1, 1, 0.92)
        border.width: 1
        border.color: Qt.rgba(0, 0, 0, 0.06)
        Behavior on width { enabled: !area.pressed; NumberAnimation { duration: Style.duration(120); easing.type: Easing.OutCubic } }
      }
    }
    Text {
      x: Style.space(7)
      anchors.verticalCenter: parent.verticalCenter
      textFormat: Text.PlainText
      text: sl.icon
      font.family: root.iconFont
      font.pixelSize: Style.space(13)
      color: "#3a3a3c"
      MouseArea {
        anchors.fill: parent
        anchors.margins: -4
        cursorShape: Qt.PointingHandCursor
        onClicked: sl.iconClicked()
      }
    }
    MouseArea {
      id: area
      anchors.fill: parent
      anchors.leftMargin: Style.space(26)
      preventStealing: true
      cursorShape: Qt.PointingHandCursor
      function apply(x) { sl.moved(Math.max(0, Math.min(1, (x + Style.space(26)) / sl.width))) }
      onPressed: function(m) { apply(m.x) }
      onPositionChanged: function(m) { if (pressed) apply(m.x) }
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
