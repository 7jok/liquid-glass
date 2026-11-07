import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Services.Pipewire
import Quickshell.Services.SystemTray
import Quickshell.Wayland
import Quickshell.Widgets
import "T.js" as T

// Style Espace : barre fine et sombre, presque invisible sur le ciel. Bureaux en
// points, morceau et heure au centre, état en petites pastilles de couleur.
PanelWindow {
  id: win
  property var service: null
  readonly property var s: service

  anchors { top: true; left: true; right: true }
  implicitHeight: 28
  exclusiveZone: 28
  color: s.alpha(s.surface, 0.62)
  WlrLayershell.layer: WlrLayer.Top
  WlrLayershell.namespace: "liquid-glass-linux-bar"
  WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

  readonly property string font: s.sansFont
  readonly property var monitor: screen ? Hyprland.monitorFor(screen) : Hyprland.focusedMonitor
  readonly property int activeWs: monitor && monitor.activeWorkspace ? monitor.activeWorkspace.id : 1
  readonly property var occupied: {
    var o = {}, v = Hyprland.workspaces ? Hyprland.workspaces.values : []
    for (var i = 0; i < v.length; i++) if (v[i].id > 0) o[v[i].id] = true
    return o
  }
  PwObjectTracker { objects: [Pipewire.defaultAudioSink] }
  readonly property var sink: Pipewire.defaultAudioSink
  readonly property int vol: sink && sink.audio ? Math.round(sink.audio.volume * 100) : 0
  readonly property bool muted: !sink || !sink.audio || sink.audio.muted
  property date now: new Date()
  Timer { interval: 1000; repeat: true; running: true; onTriggered: win.now = new Date() }

  Row {
    id: left
    x: 8; height: parent.height; spacing: 8
    Item {
      anchors.verticalCenter: parent.verticalCenter
      width: 20; height: 20
      MIcon { anchors.centerIn: parent; icon: "search"; size: 17; color: lma.containsMouse ? s.primary : s.colOnSurface }
      MouseArea { id: lma; anchors.fill: parent; hoverEnabled: true; onClicked: s.toggleLauncher() }
    }
    ClaudeButton { anchors.verticalCenter: parent.verticalCenter; s: win.s; size: 20; iconSize: 14; radius: 4 }
    Row {
      anchors.verticalCenter: parent.verticalCenter
      spacing: 3
      Repeater {
        model: Math.max(s.wsCount, win.activeWs)
        delegate: Rectangle {
          id: wb
          required property int index
          readonly property int ws: index + 1
          readonly property bool on: ws === win.activeWs
          anchors.verticalCenter: parent.verticalCenter
          width: on ? 22 : 16; height: 16; radius: 4
          color: on ? s.primary : (win.occupied[ws] ? s.alpha(s.colOnSurface, 0.16) : "transparent")
          Behavior on width { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
          Text {
            anchors.centerIn: parent; text: wb.ws
            font.family: win.font; font.pixelSize: 10; font.weight: wb.on ? Font.Bold : Font.Normal
            color: wb.on ? s.colOnPrimary : s.colOnSurfaceVariant
          }
          MouseArea {
            anchors.fill: parent
            onClicked: Quickshell.execDetached(["hyprctl", "dispatch", "hl.dsp.focus({ workspace = \"" + wb.ws + "\" })"])
          }
        }
      }
    }
  }

  // Centre : heure sur deux lignes, morceau à côté. Ouvre le tableau de bord.
  Row {
    anchors.centerIn: parent
    spacing: 12
    Item {
      anchors.verticalCenter: parent.verticalCenter
      width: clockCol.implicitWidth; height: clockCol.implicitHeight
      Column {
      id: clockCol
      Text {
        anchors.horizontalCenter: parent.horizontalCenter
        text: Qt.formatTime(win.now, "HH:mm:ss")
        font.family: win.font; font.pixelSize: 11; font.weight: Font.Bold; color: s.colOnSurface
      }
      Text {
        anchors.horizontalCenter: parent.horizontalCenter
        text: win.now.toLocaleDateString(Qt.locale(T.loc), "ddd d MMM")
        font.family: win.font; font.pixelSize: 9; color: s.colOnSurfaceVariant
      }
      }
      MouseArea { anchors.fill: parent; onClicked: s.togglePanel("dash") }
    }
    Text {
      visible: s.hasTrack
      anchors.verticalCenter: parent.verticalCenter
      width: Math.min(implicitWidth, 240); elide: Text.ElideRight
      text: (s.playing ? "▶ " : "❚❚ ") + s.trackTitle
      font.family: win.font; font.pixelSize: 11; color: s.colOnSurfaceVariant
      MouseArea { anchors.fill: parent; onClicked: s.playPause() }
    }
  }

  Row {
    anchors.right: parent.right; anchors.rightMargin: 8
    height: parent.height; spacing: 5
    Repeater {
      model: SystemTray.items
      delegate: Item {
        id: tray
        required property var modelData
        anchors.verticalCenter: parent.verticalCenter
        width: 16; height: 16
        IconImage { anchors.fill: parent; source: tray.modelData.icon; asynchronous: true }
        MouseArea {
          anchors.fill: parent
          acceptedButtons: Qt.LeftButton | Qt.RightButton
          onClicked: function(m) {
            var it = tray.modelData
            if (m.button === Qt.RightButton || it.onlyMenu) {
              if (it.hasMenu) { var p = tray.mapToItem(null, 0, tray.height + 6); it.display(win, p.x, p.y) }
            } else it.activate()
          }
        }
      }
    }
    // Mode du bureau : grille, ouvert (ruban qu'on fait défiler), libre (fenêtres flottantes).
    Rectangle {
      id: modePill
      property string mode: "dwindle"
      readonly property var names: ({ dwindle: T.t("Grille"), scrolling: T.t("Ouvert"), floating: T.t("Libre") })
      anchors.verticalCenter: parent.verticalCenter
      width: modeRow.implicitWidth + 12; height: 18; radius: 5
      color: mma.containsMouse ? s.primary : s.alpha(s.colOnSurface, 0.14)
      Row {
        id: modeRow
        anchors.centerIn: parent; spacing: 3
        MIcon {
          anchors.verticalCenter: parent.verticalCenter; size: 12
          icon: modePill.mode === "floating" ? "open_with" : (modePill.mode === "scrolling" ? "view_carousel" : "grid_view")
          color: mma.containsMouse ? s.colOnPrimary : s.colOnSurface
        }
        Text {
          anchors.verticalCenter: parent.verticalCenter
          text: modePill.names[modePill.mode] || T.t("Grille")
          font.family: win.font; font.pixelSize: 10; font.weight: Font.Bold
          color: mma.containsMouse ? s.colOnPrimary : s.colOnSurface
        }
      }
      MouseArea {
        id: mma
        anchors.fill: parent; hoverEnabled: true
        onClicked: { Quickshell.execDetached(["omarchy-hyprland-workspace-layout-toggle"]); modeRead.restart() }
      }
      Process {
        id: modeProc
        command: ["omarchy-hyprland-workspace-layout-current"]
        stdout: StdioCollector { onStreamFinished: { var m = text.trim(); if (m !== "") modePill.mode = m } }
      }
      Timer { id: modeRead; interval: 350; onTriggered: { modeProc.running = false; modeProc.running = true } }
      Connections { target: win; function onActiveWsChanged() { modeRead.restart() } }
      Component.onCompleted: modeRead.restart()
    }
    Rectangle {
      anchors.verticalCenter: parent.verticalCenter
      width: 20; height: 18; radius: 5
      color: tma.containsMouse ? s.primary : s.alpha(s.colOnSurface, 0.14)
      MIcon { anchors.centerIn: parent; icon: "bar_chart"; size: 13; color: tma.containsMouse ? s.colOnPrimary : s.colOnSurface }
      MouseArea { id: tma; anchors.fill: parent; hoverEnabled: true; onClicked: s.togglePanel("stats") }
    }
    Chip { panel: "net"; fill: s.primary; ink: s.colOnPrimary; icon: s.netDev === "" ? "wifi_off" : (s.netWifi ? "wifi" : "lan"); label: s.netDev === "" ? T.t("Hors ligne") : (s.netWifi ? "Wi-Fi" : "Ethernet") }
    Chip { fill: s.tertiary; ink: s.colOnPrimary; icon: win.muted ? "volume_off" : "volume_up"; label: win.muted ? "--" : win.vol + " %" }
    Chip {
      visible: s.batteryPct >= 0
      fill: !s.charging && s.batteryPct <= 15 ? s.errorColor : s.colOnSurface; ink: s.surface
      icon: s.charging ? "bolt" : "battery_full"; label: s.batteryPct + " %"
    }
    Rectangle {
      anchors.verticalCenter: parent.verticalCenter
      width: 20; height: 18; radius: 5
      color: pma.containsMouse ? s.errorColor : s.alpha(s.colOnSurface, 0.14)
      MIcon { anchors.centerIn: parent; icon: "power_settings_new"; size: 13; color: s.colOnSurface }
      MouseArea { id: pma; anchors.fill: parent; hoverEnabled: true; onClicked: s.powerMenu() }
    }
  }

  component Chip: Rectangle {
    id: ch
    property color fill: "white"
    property color ink: "black"
    property string icon: ""
    property string label: ""
    property string panel: ""
    anchors.verticalCenter: parent.verticalCenter
    width: chRow.implicitWidth + 12; height: 18; radius: 5
    color: fill
    Row {
      id: chRow
      anchors.centerIn: parent; spacing: 3
      MIcon { anchors.verticalCenter: parent.verticalCenter; icon: ch.icon; size: 12; fill: 1; color: ch.ink }
      Text { anchors.verticalCenter: parent.verticalCenter; text: ch.label; font.family: win.font; font.pixelSize: 10; font.weight: Font.Bold; color: ch.ink }
    }
    MouseArea {
      anchors.fill: parent
      onClicked: { if (ch.panel !== "") win.s.togglePanel(ch.panel); else win.s.toggleMenu("home") }
    }
  }
}
