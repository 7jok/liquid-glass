import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland
import "T.js" as T

// Style Cosmos : le bureau est un système solaire. La Terre tourne sur elle-même, la
// Lune tourne autour et passe devant comme derrière, et les widgets sont des
// satellites. Glisser déplace la caméra, la molette zoome, un clic sur la Lune ouvre
// les applications. Sans action pendant une minute, la caméra repart seule.
PanelWindow {
  id: win
  property var service: null
  readonly property var s: service

  color: "#02070c"
  anchors { top: true; bottom: true; left: true; right: true }
  exclusionMode: ExclusionMode.Ignore
  WlrLayershell.layer: WlrLayer.Bottom
  WlrLayershell.namespace: "liquid-glass-linux-cosmos"
  WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

  readonly property string font: s.sansFont
  readonly property color ink: s.colOnSurface
  readonly property color sub: s.colOnSurfaceVariant
  readonly property color acc: s.primary

  // Horloge du monde : on s'arrête quand une fenêtre couvre le bureau.
  readonly property var ws: Hyprland.focusedWorkspace
  readonly property bool covered: !s.testing && !!ws && !!ws.toplevels && ws.toplevels.values.length > 0
  property real tt: 0
  Timer {
    interval: 40; repeat: true; running: !win.covered
    onTriggered: win.tt += 0.04
  }
  property date now: new Date()
  Timer { interval: 1000; repeat: true; running: true; onTriggered: win.now = new Date() }

  // Caméra
  property real camX: -90
  property real camY: 10
  property real zoom: 1
  Behavior on camX { id: bx; enabled: !drag.pressed; SpringAnimation { spring: 1.4; damping: 0.42 } }
  Behavior on camY { id: by; enabled: !drag.pressed; SpringAnimation { spring: 1.4; damping: 0.42 } }
  Behavior on zoom { SpringAnimation { spring: 1.6; damping: 0.45 } }
  readonly property var views: [[-90, 10, 1], [260, -40, 1.75], [-420, 80, 2.1], [40, 0, 0.72], [-260, -120, 1.35]]
  property int view: 0
  function go(i) { view = i % views.length; camX = views[view][0]; camY = views[view][1]; zoom = views[view][2] }
  Timer {
    id: idle
    interval: 60000; repeat: true; running: !win.covered && win.s.opt("cosmos_drift", true) !== false
    onTriggered: win.go(win.view + 1)
  }
  function focusOn(x, y, z) { camX = -x; camY = -y; zoom = z; idle.restart() }

  // Ciel, un peu décalé par la caméra : la profondeur vient de là.
  Image {
    source: Qt.resolvedUrl("cosmos/sky.jpg")
    width: parent.width * 1.5; height: parent.height * 1.5
    x: (parent.width - width) / 2 + win.camX * 0.12
    y: (parent.height - height) / 2 + win.camY * 0.12
    fillMode: Image.PreserveAspectCrop
    asynchronous: true
  }

  MouseArea {
    id: drag
    anchors.fill: parent
    property real sx: 0
    property real sy: 0
    property real cx: 0
    property real cy: 0
    onPressed: function(m) { sx = m.x; sy = m.y; cx = win.camX; cy = win.camY; idle.restart() }
    onPositionChanged: function(m) { win.camX = cx + (m.x - sx) / win.zoom; win.camY = cy + (m.y - sy) / win.zoom }
    onWheel: function(w) { win.zoom = Math.max(0.5, Math.min(3.2, win.zoom * (w.angleDelta.y > 0 ? 1.12 : 0.89))); idle.restart() }
    onDoubleClicked: win.go(0)
  }

  // Le monde : tout ce qui suit la caméra.
  Item {
    id: world
    x: parent.width / 2; y: parent.height / 2
    width: 0; height: 0
    transform: [
      Translate { x: win.camX; y: win.camY },
      Scale { xScale: win.zoom; yScale: win.zoom }
    ]

    readonly property real er: 330                       // rayon de la Terre
    readonly property real ma: win.tt * 0.035 + 0.6      // angle de la Lune
    readonly property real depth: Math.sin(ma)           // > 0 : devant la Terre
    readonly property real mx: 610 * Math.cos(ma)
    readonly property real my: 120 * Math.sin(ma) + 40 * Math.cos(ma)
    readonly property real mr: 120 * (1 + 0.28 * depth)

    Planet {
      id: earth
      x: -world.er * 1.08; y: -world.er * 1.08
      width: world.er * 2.16; height: width
      z: 10
      surfaceUrl: Qt.resolvedUrl("cosmos/earth.jpg")
      cloudsUrl: Qt.resolvedUrl("cosmos/clouds.jpg")
      spin: win.tt * 0.004 + 0.55
      cloudSpin: win.tt * 0.0052 + 0.55
      tilt: 0.3
      cloudAmount: 0.9
      glow: 0.9
      rim: win.s.alpha(win.acc, 1)
      MouseArea { anchors.fill: parent; anchors.margins: 30; onClicked: win.focusOn(0, 0, 1.3) }
    }

    // Heure et météo, posées sur la Terre : la Lune les cache en passant.
    Column {
      z: 11
      x: -width / 2 - 40; y: -86
      width: 400; spacing: 2
      opacity: 0.72
      Row {
        anchors.horizontalCenter: parent.horizontalCenter; spacing: 6
        MIcon { anchors.verticalCenter: parent.verticalCenter; icon: win.s.weatherIcon; size: 18; fill: 1; color: win.ink }
        Text { text: win.s.weather ? win.s.weather.temp + " °C" : ""; font.family: win.font; font.pixelSize: 14; font.weight: Font.Bold; color: win.ink }
      }
      Text {
        anchors.horizontalCenter: parent.horizontalCenter
        text: Qt.formatTime(win.now, "HH:mm:ss")
        font.family: win.font; font.pixelSize: 62; font.weight: Font.Black; color: win.ink
        style: Text.Raised; styleColor: Qt.rgba(0, 0, 0, 0.35)
      }
      Text {
        anchors.horizontalCenter: parent.horizontalCenter
        text: win.now.toLocaleDateString(Qt.locale(T.loc), "dddd d MMMM").toUpperCase()
        font.family: win.font; font.pixelSize: 15; font.weight: Font.Bold; font.letterSpacing: 2; color: win.ink
      }
    }

    // Lune
    Planet {
      id: moon
      z: world.depth > 0 ? 20 : 5
      x: world.mx - width / 2; y: world.my - height / 2
      width: world.mr * 2.16; height: width
      surfaceUrl: Qt.resolvedUrl("cosmos/moon.jpg")
      cloudsUrl: Qt.resolvedUrl("cosmos/moon.jpg")
      spin: win.tt * 0.01
      tilt: 0.1
      cloudAmount: 0
      glow: 0.12
      rim: "#ffffff"
      MouseArea {
        anchors.fill: parent; anchors.margins: 12
        cursorShape: Qt.PointingHandCursor
        onClicked: win.s.toggleLauncher()
      }
    }

    // Petite lune décorative, loin derrière.
    Planet {
      z: 2
      x: 600; y: 70
      width: 60; height: 60
      surfaceUrl: Qt.resolvedUrl("cosmos/moon.jpg")
      cloudsUrl: Qt.resolvedUrl("cosmos/moon.jpg")
      spin: 0.2; tilt: 0; cloudAmount: 0; glow: 0.2; rim: "#ffffff"
      sunX: 0.8; sunY: 0.1; sunZ: 0.1
    }

    // Satellites de la Lune : ils tournent à hauteurs différentes et passent derrière elle.
    Repeater {
      model: [
        { a: 0.2, r: 1.55, k: "net" }, { a: 1.5, r: 1.9, k: "music" }, { a: 2.7, r: 1.65, k: "ws" },
        { a: 3.9, r: 2.05, k: "power" }, { a: 5.1, r: 1.75, k: "stats" }, { a: 4.5, r: 1.6, k: "mode" }
      ]
      delegate: Item {
        id: sat
        required property var modelData
        readonly property real a: modelData.a + win.tt * 0.12
        readonly property real front: Math.sin(a)
        readonly property real big: hov.containsMouse ? 1.25 : (0.82 + 0.18 * front)
        x: world.mx + world.mr * modelData.r * Math.cos(a) - width / 2
        y: world.my + world.mr * modelData.r * 0.42 * Math.sin(a) - world.mr * 0.25 * Math.cos(a) - height / 2
        z: moon.z + (front > 0 ? 1 : -1)
        width: body.width + 56; height: body.height
        scale: big
        opacity: front > 0 ? 1 : 0.65
        Behavior on scale { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
        // Panneaux solaires
        Repeater {
          model: [0, 1]
          delegate: Rectangle {
            required property int modelData
            x: modelData === 0 ? 0 : sat.width - width
            anchors.verticalCenter: parent.verticalCenter
            width: 24; height: 20; radius: 1
            color: Qt.rgba(0.11, 0.17, 0.25, 0.95)
            border.width: 1; border.color: Qt.rgba(0.5, 0.65, 0.8, 0.55)
            Row {
              anchors.centerIn: parent; spacing: 5
              Repeater { model: 3; delegate: Rectangle { width: 1; height: 18; color: Qt.rgba(0.5, 0.65, 0.8, 0.4) } }
            }
          }
        }
        Rectangle {
          id: body
          anchors.centerIn: parent
          width: inner.implicitWidth + 16; height: inner.implicitHeight + 12
          radius: 7; color: win.s.alpha(win.s.surface, 0.92)
          border.width: 1; border.color: win.s.alpha(win.acc, hov.containsMouse ? 0.9 : 0.4)
          Loader {
            id: inner
            anchors.centerIn: parent
            sourceComponent: sat.modelData.k === "net" ? netSat : sat.modelData.k === "music" ? musicSat
              : sat.modelData.k === "ws" ? wsSat : sat.modelData.k === "power" ? powerSat
              : sat.modelData.k === "mode" ? modeSat : statsSat
          }
        }
        MouseArea {
          id: hov
          anchors.fill: parent; hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          enabled: sat.modelData.k !== "ws"
          onClicked: {
            var k = sat.modelData.k
            if (k === "mode") { Quickshell.execDetached(["omarchy-hyprland-workspace-layout-toggle"]); modeRead.restart() }
            else if (k === "power") win.s.powerMenu()
            else win.s.togglePanel(k === "music" ? "dash" : k)
          }
        }
      }
    }

    // Satellites de notifications : les trois dernières tournent loin autour de la Terre.
    Repeater {
      model: win.notes
      delegate: Rectangle {
        id: note
        required property var modelData
        required property int index
        // Sur l'arc gauche de la Terre, où il reste de la place à l'écran.
        readonly property real a: Math.PI + (index - 1) * 0.5 + 0.1 * Math.sin(win.tt * 0.2 + index)
        x: (world.er + 100) * Math.cos(a) - width / 2
        y: (world.er + 100) * 0.9 * Math.sin(a) - height / 2
        z: 13
        width: Math.min(230, noteCol.implicitWidth + 40); height: noteCol.implicitHeight + 12; radius: 7
        color: win.s.alpha(win.s.surface, 0.92)
        border.width: 1; border.color: win.s.alpha(win.acc, 0.55)
        MIcon { x: 8; anchors.verticalCenter: parent.verticalCenter; icon: "notifications"; size: 15; fill: 1; color: win.acc }
        Column {
          id: noteCol
          x: 30; anchors.verticalCenter: parent.verticalCenter; spacing: 1
          Text { width: Math.min(implicitWidth, 190); elide: Text.ElideRight; text: note.modelData.app || ""; font.family: win.font; font.pixelSize: 9; color: win.s.alpha(win.ink, 0.65) }
          Text { width: Math.min(implicitWidth, 190); elide: Text.ElideRight; textFormat: Text.PlainText; text: note.modelData.summary || ""; font.family: win.font; font.pixelSize: 11; font.weight: Font.DemiBold; color: win.ink }
        }
      }
    }

    // Satellites météo autour de la Terre : prévision des prochaines heures.
    Repeater {
      model: win.s.weather && win.s.weather.hourly ? win.s.weather.hourly.slice(0, 12).filter(function(h, i) { return i % 3 === 0 }) : []
      delegate: Rectangle {
        id: fc
        required property var modelData
        required property int index
        readonly property real a: index * Math.PI / 2 + 0.4 + win.tt * 0.03
        x: (world.er + 70) * Math.cos(a) - width / 2
        y: (world.er + 70) * 0.94 * Math.sin(a) - height / 2
        z: 12
        width: fcRow.implicitWidth + 12; height: 22; radius: 6
        color: win.s.alpha(win.s.surface, 0.88)
        border.width: 1; border.color: win.s.alpha(win.ink, 0.28)
        Row {
          id: fcRow
          anchors.centerIn: parent; spacing: 5
          Text { anchors.verticalCenter: parent.verticalCenter; text: fc.modelData.h; font.family: win.font; font.pixelSize: 10; color: win.sub }
          MIcon { anchors.verticalCenter: parent.verticalCenter; icon: win.s.weatherInfo(fc.modelData.code)[1]; size: 13; color: win.ink }
          Text { anchors.verticalCenter: parent.verticalCenter; text: fc.modelData.temp + "°"; font.family: win.font; font.pixelSize: 10; font.weight: Font.Bold; color: win.ink }
        }
      }
    }
  }

  // Mode du bureau et notifications, lus sans rien réclamer au service d'Omarchy.
  property string mode: "dwindle"
  property var notes: []
  Process {
    id: modeProc
    command: ["omarchy-hyprland-workspace-layout-current"]
    stdout: StdioCollector { onStreamFinished: { var m = text.trim(); if (m !== "") win.mode = m } }
  }
  Timer { id: modeRead; interval: 350; onTriggered: { modeProc.running = false; modeProc.running = true } }
  Timer { interval: 5000; repeat: true; running: true; triggeredOnStart: true; onTriggered: modeRead.restart() }
  FileView {
    id: noteFile
    path: Quickshell.env("HOME") + "/.local/state/omarchy/notifications/history.json"
    watchChanges: true
    onFileChanged: reload()
    onLoaded: {
      try { win.notes = JSON.parse(text()).slice(0, 3) } catch (e) { win.notes = [] }
    }
  }

  component Chip: Rectangle {
    id: chip
    property string icon: ""
    property string label: ""
    property bool lit: false
    width: chipRow.implicitWidth + 10; height: 17; radius: 4
    color: lit ? win.acc : win.s.alpha(win.ink, 0.1)
    Row {
      id: chipRow
      anchors.centerIn: parent; spacing: 3
      MIcon { anchors.verticalCenter: parent.verticalCenter; icon: chip.icon; size: 11; fill: 1; color: chip.lit ? win.s.colOnPrimary : win.ink }
      Text { anchors.verticalCenter: parent.verticalCenter; text: chip.label; font.family: win.font; font.pixelSize: 9; font.weight: Font.Bold; color: chip.lit ? win.s.colOnPrimary : win.ink }
    }
  }

  Component {
    id: netSat
    Grid {
      columns: 2; spacing: 3
      Chip { icon: win.s.netDev === "" ? "wifi_off" : "wifi"; label: win.s.netDev === "" ? T.t("Hors ligne") : T.t("Réseau"); lit: win.s.netDev !== "" }
      Chip { visible: win.s.batteryPct >= 0; icon: "battery_full"; label: win.s.batteryPct + " %" }
    }
  }
  Component {
    id: musicSat
    Row {
      spacing: 6
      MIcon { anchors.verticalCenter: parent.verticalCenter; icon: win.s.playing ? "equalizer" : "music_note"; size: 15; color: win.acc }
      Column {
        Text { width: 96; elide: Text.ElideRight; text: win.s.trackTitle || T.t("Pas de musique"); font.family: win.font; font.pixelSize: 10; font.weight: Font.Bold; color: win.ink }
        Text { width: 96; elide: Text.ElideRight; text: win.s.trackArtist; font.family: win.font; font.pixelSize: 9; color: win.sub }
      }
    }
  }
  Component {
    id: wsSat
    Grid {
      columns: 4; spacing: 3
      Repeater {
        model: 8
        delegate: Rectangle {
          id: wb
          required property int index
          readonly property bool on: !!win.ws && win.ws.id === index + 1
          width: 17; height: 15; radius: 3
          color: on ? win.acc : win.s.alpha(win.ink, 0.1)
          Text { anchors.centerIn: parent; text: wb.index + 1; font.family: win.font; font.pixelSize: 9; font.weight: Font.Bold; color: wb.on ? win.s.colOnPrimary : win.ink }
          MouseArea {
            anchors.fill: parent; cursorShape: Qt.PointingHandCursor
            onClicked: Quickshell.execDetached(["hyprctl", "dispatch", "hl.dsp.focus({ workspace = \"" + (wb.index + 1) + "\" })"])
          }
        }
      }
    }
  }
  Component { id: powerSat; MIcon { icon: "power_settings_new"; size: 18; color: win.acc } }
  Component {
    id: modeSat
    Chip {
      icon: win.mode === "floating" ? "open_with" : (win.mode === "scrolling" ? "view_carousel" : "grid_view")
      label: win.mode === "floating" ? T.t("Libre") : (win.mode === "scrolling" ? T.t("Ouvert") : T.t("Grille"))
      lit: win.mode !== "dwindle"
    }
  }
  Component {
    id: statsSat
    Row {
      spacing: 5
      Chip { icon: "memory"; label: Math.round(win.s.cpu * 100) + " %" }
      Chip { icon: "bar_chart"; label: Math.round(win.s.memPct * 100) + " %" }
    }
  }
}
