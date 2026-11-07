import QtQuick
import QtQuick.Shapes
import Quickshell
import Quickshell.Hyprland
import Quickshell.Services.Pipewire
import Quickshell.Services.SystemTray
import Quickshell.Wayland
import Quickshell.Widgets

// Style Rubans : pas de barre droite, deux rubans en biais dans les coins du haut.
PanelWindow {
  id: win
  property var service: null
  readonly property var s: service

  anchors { top: true; left: true; right: true }
  implicitHeight: 52
  exclusiveZone: 40
  color: "transparent"
  mask: Region { Region { item: leftHit } Region { item: rightHit } }
  WlrLayershell.layer: WlrLayer.Top
  WlrLayershell.namespace: "liquid-glass-linux-bar"
  WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

  readonly property string font: "Rubik"
  readonly property var monitor: screen ? Hyprland.monitorFor(screen) : Hyprland.focusedMonitor
  readonly property int activeWs: monitor && monitor.activeWorkspace ? monitor.activeWorkspace.id : 1
  readonly property var occupied: {
    var o = {}, v = Hyprland.workspaces ? Hyprland.workspaces.values : []
    for (var i = 0; i < v.length; i++) if (v[i].id > 0) o[v[i].id] = true
    return o
  }
  PwObjectTracker { objects: [Pipewire.defaultAudioSink] }
  readonly property var sink: Pipewire.defaultAudioSink
  readonly property bool muted: !sink || !sink.audio || sink.audio.muted
  property date now: new Date()
  Timer { interval: 1000; repeat: true; running: true; onTriggered: win.now = new Date() }

  // Rubans : un trait d'accent décalé sous un aplat sombre.
  Shape {
    anchors.fill: parent
    preferredRendererType: Shape.CurveRenderer
    ShapePath {
      strokeWidth: -1; fillColor: win.s.primary
      startX: 0; startY: 0
      PathLine { x: leftHit.width + 34; y: 0 }
      PathLine { x: leftHit.width + 6; y: 46 }
      PathLine { x: 0; y: 50 }
      PathLine { x: 0; y: 0 }
    }
    ShapePath {
      strokeWidth: -1; fillColor: win.s.surface
      startX: 0; startY: 0
      PathLine { x: leftHit.width + 22; y: 0 }
      PathLine { x: leftHit.width; y: 40 }
      PathLine { x: 0; y: 44 }
      PathLine { x: 0; y: 0 }
    }
    ShapePath {
      strokeWidth: -1; fillColor: win.s.primary
      startX: win.width; startY: 0
      PathLine { x: win.width - rightHit.width - 34; y: 0 }
      PathLine { x: win.width - rightHit.width - 10; y: 44 }
      PathLine { x: win.width; y: 50 }
      PathLine { x: win.width; y: 0 }
    }
    ShapePath {
      strokeWidth: -1; fillColor: win.s.surface
      startX: win.width; startY: 0
      PathLine { x: win.width - rightHit.width - 22; y: 0 }
      PathLine { x: win.width - rightHit.width - 4; y: 38 }
      PathLine { x: win.width; y: 44 }
      PathLine { x: win.width; y: 0 }
    }
  }

  Row {
    id: leftHit
    x: 8; y: 4; height: 34
    spacing: 8
    Rectangle {
      anchors.verticalCenter: parent.verticalCenter
      width: 34; height: 28; color: lma.containsMouse ? win.s.primary : "transparent"
      transform: Matrix4x4 { matrix: Qt.matrix4x4(1, -0.2, 0, 3, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1) }
      MIcon { anchors.centerIn: parent; icon: "menu"; size: 22; weight: 700; color: lma.containsMouse ? win.s.colOnPrimary : win.s.colOnSurface }
      MouseArea { id: lma; anchors.fill: parent; hoverEnabled: true; onClicked: win.s.toggleLauncher() }
    }
    ClaudeButton { anchors.verticalCenter: parent.verticalCenter; s: win.s; size: 28; iconSize: 19; radius: 2 }
    Repeater {
      model: Math.max(win.s.wsCount, win.activeWs)
      delegate: Item {
        id: wb
        required property int index
        readonly property int ws: index + 1
        readonly property bool on: ws === win.activeWs
        anchors.verticalCenter: parent.verticalCenter
        width: on ? 32 : 18; height: 30
        Behavior on width { NumberAnimation { duration: 200; easing.type: Easing.OutBack } }
        Rectangle {
          visible: wb.on
          anchors.fill: parent; color: win.s.primary
          transform: Matrix4x4 { matrix: Qt.matrix4x4(1, -0.25, 0, 3.5, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1) }
        }
        Text {
          anchors.centerIn: parent; text: wb.ws
          font.family: win.font; font.pixelSize: wb.on ? 20 : 13; font.weight: Font.Black; font.italic: true
          color: wb.on ? win.s.colOnPrimary : (win.occupied[wb.ws] ? win.s.colOnSurface : win.s.outline)
        }
        MouseArea {
          anchors.fill: parent
          onClicked: Quickshell.execDetached(["hyprctl", "dispatch", "hl.dsp.focus({ workspace = \"" + wb.ws + "\" })"])
        }
      }
    }
  }

  Row {
    id: rightHit
    anchors.right: parent.right; anchors.rightMargin: 10
    y: 4; height: 34
    spacing: 10
    Repeater {
      model: SystemTray.items
      delegate: Item {
        id: tray
        required property var modelData
        anchors.verticalCenter: parent.verticalCenter
        width: 18; height: 18
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
    Stat { icon: win.s.netDev === "" ? "wifi_off" : (win.s.netWifi ? "wifi" : "lan") }
    Stat { icon: win.muted ? "volume_off" : "volume_up" }
    Text {
      anchors.verticalCenter: parent.verticalCenter
      text: Qt.formatTime(win.now, "HH:mm")
      font.family: win.font; font.pixelSize: 21; font.weight: Font.Black; font.italic: true; color: win.s.colOnSurface
      MouseArea { anchors.fill: parent; onClicked: win.s.toggleMenu("home") }
    }
    Stat { icon: "power_settings_new"; onClicked: win.s.powerMenu() }
  }

  component Stat: Item {
    id: st
    property string icon: ""
    signal clicked()
    anchors.verticalCenter: parent.verticalCenter
    width: 22; height: 28
    MIcon { anchors.centerIn: parent; icon: st.icon; size: 19; fill: 1; color: sma.containsMouse ? win.s.primary : win.s.colOnSurface }
    MouseArea { id: sma; anchors.fill: parent; hoverEnabled: true; onClicked: st.icon === "power_settings_new" ? st.clicked() : win.s.toggleMenu("home") }
  }
}
