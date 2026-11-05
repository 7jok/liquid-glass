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

// Liquid Glass — Centre de contrôle façon macOS.
//   Tuiles : Wi-Fi, Bluetooth, Ne pas déranger, Mode sombre, Lumière nocturne
//   Curseurs : luminosité, volume — Carte : lecture en cours (Spotify en priorité)
// Aucune interrogation périodique : l'état est relu à l'ouverture et après chaque action.
// Raccourci : omarchy-shell liquid-glass.control toggle
Panel {
  id: root
  moduleName: "liquid-glass.control"
  ipcTarget: "liquid-glass.control"

  readonly property string uiFont: "Inter"
  readonly property string iconFont: Style.font.family   // Nerd Font (glyphes)
  readonly property color fg: Commons.Color.popups.text
  readonly property color accent: Commons.Color.accent

  function g(cp) { return String.fromCodePoint(cp) }

  // ------------------------------------------------------------ état
  property bool wifiOn: true
  property string ssid: ""
  property bool dnd: false
  property bool nightlight: false
  property bool darkMode: false
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

  function refresh() {
    wifiProc.running = true
    dndProc.running = true
    nightProc.running = true
    themeFile.reload()
    brightProc.running = true
  }

  function run(argv) {
    actionProc.command = argv
    actionProc.running = true
  }

  onOpenedChanged: if (opened) refresh()
  Component.onCompleted: themeFile.reload()

  Process {
    id: wifiProc
    // Connexion Wi-Fi active, lue sans lancer de scan (instantané).
    command: ["sh", "-c", "nmcli -t -f WIFI radio; nmcli -t -f NAME,TYPE connection show --active 2>/dev/null | grep ':802-11-wireless$' | head -1 | sed 's/:802-11-wireless$//'"]
    stdout: StdioCollector {
      onStreamFinished: {
        var lines = text.split("\n")
        root.wifiOn = (lines[0] || "").trim() === "enabled"
        root.ssid = (lines[1] || "").trim()
      }
    }
  }
  Process {
    id: dndProc
    command: ["omarchy-shell", "notifications", "isDnd"]
    stdout: StdioCollector { onStreamFinished: root.dnd = text.trim() === "on" }
  }
  Process {
    id: nightProc
    command: ["omarchy-shell", "nightlight", "status"]
    stdout: StdioCollector {
      onStreamFinished: { try { root.nightlight = JSON.parse(text).enabled === true } catch (e) {} }
    }
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
    contentWidth: Style.space(316)
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

        // ---- Ligne 1 : connectivité (grande tuile) + deux tuiles carrées
        Row {
          width: parent.width
          spacing: Style.space(10)

          Tile {
            width: (parent.width - Style.space(10)) / 2
            height: Style.space(124)
            Column {
              anchors.fill: parent
              anchors.margins: Style.space(10)
              spacing: Style.space(8)
              ToggleLine {
                width: parent.width
                icon: root.wifiOn ? root.g(0xF05A9) : root.g(0xF05AA)
                title: "Wi-Fi"
                subtitle: root.wifiOn ? (root.ssid || "Non connecté") : "Désactivé"
                active: root.wifiOn
                onClicked: root.run(["nmcli", "radio", "wifi", root.wifiOn ? "off" : "on"])
                onSecondary: Util.execArgv(["omarchy-shell", "omarchy.network", "toggle"])
              }
              ToggleLine {
                width: parent.width
                icon: root.btOn ? root.g(0xF00AF) : root.g(0xF00B2)
                title: "Bluetooth"
                subtitle: root.btLabel
                active: root.btOn
                onClicked: if (root.btAdapter) root.btAdapter.enabled = !root.btOn
                onSecondary: Util.execArgv(["omarchy-shell", "omarchy.bluetooth", "toggle"])
              }
            }
          }

          Column {
            width: (parent.width - Style.space(10)) / 2
            spacing: Style.space(10)
            Tile {
              width: parent.width
              height: Style.space(57)
              ToggleLine {
                anchors.fill: parent
                anchors.margins: Style.space(10)
                icon: root.g(0xF0594)
                title: "Concentration"
                subtitle: root.dnd ? "Activé" : ""
                active: root.dnd
                onClicked: root.run(["omarchy-shell", "notifications", "toggleDnd"])
              }
            }
            Tile {
              width: parent.width
              height: Style.space(57)
              ToggleLine {
                anchors.fill: parent
                anchors.margins: Style.space(10)
                icon: root.g(0xF050E)
                title: "Mode sombre"
                subtitle: root.darkMode ? "Activé" : ""
                active: root.darkMode
                onClicked: root.run(["liquid-glass", "mode", "toggle"])
              }
            }
          }
        }

        // ---- Ligne 2 : lumière nocturne + réglages
        Row {
          width: parent.width
          spacing: Style.space(10)
          Tile {
            width: (parent.width - Style.space(10)) / 2
            height: Style.space(52)
            ToggleLine {
              anchors.fill: parent
              anchors.margins: Style.space(10)
              icon: root.g(0xF06E8)
              title: "Night Shift"
              subtitle: root.nightlight ? "Activée" : ""
              active: root.nightlight
              onClicked: root.run(["omarchy-shell", "nightlight", "toggle"])
            }
          }
          Tile {
            width: (parent.width - Style.space(10)) / 2
            height: Style.space(52)
            ToggleLine {
              anchors.fill: parent
              anchors.margins: Style.space(10)
              icon: root.g(0xF0493)
              title: "Réglages"
              subtitle: "Liquid Glass"
              active: false
              onClicked: { root.close(); Util.execArgv(["omarchy-shell", "liquid-glass.settings", "toggle"]) }
            }
          }
        }

        // ---- Luminosité
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
            Label { text: "Son"; font.weight: Font.DemiBold }
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

        // ---- Lecture en cours
        Tile {
          visible: root.player !== null && (root.player.trackTitle || "") !== ""
          width: parent.width
          height: visible ? Style.space(76) : 0
          Item {
            anchors.fill: parent
            anchors.margins: Style.space(10)

            Item {
              id: art
              width: Style.space(56)
              height: width
              anchors.verticalCenter: parent.verticalCenter
              Image {
                id: artImg
                anchors.fill: parent
                source: root.player ? (root.player.trackArtUrl || "") : ""
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                smooth: true
                visible: false
              }
              Rectangle { id: artMask; anchors.fill: parent; radius: Style.space(8); visible: false; layer.enabled: true }
              MultiEffect {
                anchors.fill: parent
                source: artImg
                maskEnabled: true
                maskSource: artMask
                visible: artImg.status === Image.Ready
              }
              Rectangle {
                anchors.fill: parent
                radius: Style.space(8)
                visible: artImg.status !== Image.Ready
                color: root.fg
                opacity: 0.1
              }
            }

            Column {
              anchors.left: art.right
              anchors.leftMargin: Style.space(10)
              anchors.right: controls.left
              anchors.rightMargin: Style.space(6)
              anchors.verticalCenter: parent.verticalCenter
              spacing: Style.space(2)
              Label {
                width: parent.width
                text: root.player ? (root.player.trackTitle || "") : ""
                font.weight: Font.DemiBold
                elide: Text.ElideRight
              }
              Label {
                width: parent.width
                text: root.player ? (root.player.trackArtist || "") : ""
                opacity: 0.6
                elide: Text.ElideRight
              }
            }

            Row {
              id: controls
              anchors.right: parent.right
              anchors.verticalCenter: parent.verticalCenter
              spacing: Style.space(2)
              IconButton { glyph: root.g(0xF04AE); onClicked: if (root.player) root.player.previous() }
              IconButton {
                glyph: root.player && root.player.isPlaying ? root.g(0xF03E4) : root.g(0xF040A)
                size: Style.space(22)
                onClicked: if (root.player) root.player.togglePlaying()
              }
              IconButton { glyph: root.g(0xF04AD); onClicked: if (root.player) root.player.next() }
            }
          }
        }
      }
    }
  }

  // ------------------------------------------------------------ composants
  // Tuile translucide aux coins arrondis.
  component Tile: Rectangle {
    radius: Style.space(14)
    color: Qt.rgba(root.fg.r, root.fg.g, root.fg.b, 0.07)
    border.width: 1
    border.color: Qt.rgba(1, 1, 1, Commons.Color.background.hslLightness > 0.5 ? 0.55 : 0.08)
  }

  component Label: Text {
    textFormat: Text.PlainText
    color: root.fg
    font.family: root.uiFont
    font.pixelSize: Style.font.body
  }

  // Pastille ronde (accent si active) + titre + sous-titre.
  component ToggleLine: Item {
    id: tl
    property string icon: ""
    property string title: ""
    property string subtitle: ""
    property bool active: false
    signal clicked()
    signal secondary()
    implicitHeight: Style.space(37)
    height: implicitHeight

    Rectangle {
      id: dot
      width: Style.space(30)
      height: width
      radius: width / 2
      anchors.verticalCenter: parent.verticalCenter
      color: tl.active ? root.accent : Qt.rgba(root.fg.r, root.fg.g, root.fg.b, 0.12)
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
        color: Commons.Color.background.hslLightness > 0.5 ? "#ffffff" : Qt.rgba(1, 1, 1, 0.92)
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
