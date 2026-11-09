import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Services.Pipewire
import Quickshell.Services.SystemTray
import Quickshell.Wayland
import Quickshell.Widgets

// Style Jouet : pas de barre en haut, un gros dock en bas, tout en autocollants.
// Contours épais, ombre dure, boutons qui rebondissent, bureaux en blocs de couleur.
PanelWindow {
  id: win
  property var service: null
  readonly property var s: service

  anchors { bottom: true; left: true; right: true }
  implicitHeight: 92
  exclusiveZone: 86
  color: "transparent"
  mask: Region { item: body }
  WlrLayershell.layer: WlrLayer.Top
  WlrLayershell.namespace: "liquid-glass-linux-bar"
  WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

  readonly property color line: s.outline
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
  function run(cmd) { Quickshell.execDetached(["sh", "-c", cmd]) }
  // Réglages propres à Jouet (Réglages → Propre à Jouet).
  function jo(k, d) { return s.opt("jouet_" + k, d === undefined ? true : d) !== false }
  readonly property real tk: jo("tilt") ? 1 : 0     // autocollants penchés

  Rectangle {
    x: body.x + 6; y: body.y + 6; width: body.width; height: body.height
    radius: body.radius; color: win.line
  }
  Rectangle {
    id: body
    anchors.horizontalCenter: parent.horizontalCenter
    y: 8
    width: dock.width + 24; height: 72
    radius: 24
    color: s.surfaceMid
    border.width: 3; border.color: win.line

    Row {
      id: dock
      anchors.centerIn: parent
      spacing: 8

      Sticker { size: 54; fill: s.primary; icon: "apps"; iconColor: s.colOnPrimary; tilt: -5; onClicked: s.toggleLauncher() }
      Rectangle {
        anchors.verticalCenter: parent.verticalCenter
        visible: win.jo("claude")
        width: 54; height: 54; radius: 16; rotation: 4 * win.tk
        color: s.surfaceHighest; border.width: 3; border.color: win.line
        ClaudeButton { anchors.centerIn: parent; s: win.s; size: 44; iconSize: 30; radius: 12 }
      }
      Bar_ {}
      Row {
        anchors.verticalCenter: parent.verticalCenter
        spacing: 4
        Repeater {
          model: Math.max(s.wsCount, win.activeWs)
          delegate: Rectangle {
            id: wsb
            required property int index
            readonly property int ws: index + 1
            readonly property bool active: ws === win.activeWs
            readonly property bool used: !!win.occupied[ws]
            anchors.verticalCenter: parent.verticalCenter
            width: active ? 42 : 30; height: active ? 48 : 34
            radius: 10
            color: active || used ? (win.jo("rainbow") ? s.rainbow[index % 6] : (active ? s.primary : s.primaryContainer)) : s.surfaceHigh
            border.width: 2.5; border.color: win.line
            scale: wma.pressed ? 0.9 : (wma.containsMouse && win.s.opt("jouet_magnify", true) !== false ? 1.1 : 1)
            Behavior on width { NumberAnimation { duration: 240; easing.type: Easing.OutBack; easing.overshoot: 3 } }
            Behavior on height { NumberAnimation { duration: 240; easing.type: Easing.OutBack; easing.overshoot: 3 } }
            Behavior on scale { NumberAnimation { duration: 140; easing.type: Easing.OutBack } }
            Text {
              anchors.centerIn: parent; text: wsb.ws
              font.family: win.font; font.pixelSize: wsb.active ? 20 : 13; font.weight: Font.Black; color: "#1b1030"
            }
            MouseArea {
              id: wma; anchors.fill: parent; hoverEnabled: true
              onClicked: Quickshell.execDetached(["hyprctl", "dispatch", "hl.dsp.focus({ workspace = \"" + wsb.ws + "\" })"])
            }
          }
        }
      }
      Bar_ {}
      // Pochette ronde qui tourne pendant la lecture.
      Rectangle {
        visible: s.hasTrack && win.jo("cover")
        anchors.verticalCenter: parent.verticalCenter
        width: 54; height: 54; radius: 27
        color: s.primaryContainer; border.width: 3; border.color: win.line
        ClippingRectangle {
          id: disc
          anchors.centerIn: parent; width: 46; height: 46; radius: 23; color: "transparent"
          Image { anchors.fill: parent; source: s.cover; fillMode: Image.PreserveAspectCrop; asynchronous: true; cache: false; sourceSize.width: 96 }
          RotationAnimation on rotation { from: 0; to: 360; duration: 9000; loops: Animation.Infinite; running: s.playing && win.jo("spin") }
        }
        MIcon { visible: !s.playing; anchors.centerIn: parent; icon: "play_arrow"; size: 26; fill: 1; color: "white" }
        MouseArea { anchors.fill: parent; onClicked: s.playPause() }
      }
      // Horloge autocollant.
      Rectangle {
        anchors.verticalCenter: parent.verticalCenter
        width: clock.implicitWidth + 26; height: 50; radius: 12; rotation: -3 * win.tk
        color: s.primaryContainer; border.width: 3; border.color: win.line
        Text {
          id: clock
          anchors.centerIn: parent
          text: Qt.formatTime(win.now, win.jo("seconds", false) ? "HH:mm:ss" : "HH:mm")
          font.family: win.font; font.pixelSize: 25; font.weight: Font.Black; color: "#1b1030"
        }
        MouseArea { anchors.fill: parent; onClicked: s.toggleMenu("home") }
      }
      Repeater {
        model: win.jo("tray") ? SystemTray.items : []
        delegate: Item {
          id: tray
          required property var modelData
          anchors.verticalCenter: parent.verticalCenter
          width: 26; height: 26
          IconImage { anchors.fill: parent; source: tray.modelData.icon; asynchronous: true }
          MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            onClicked: function(m) {
              var it = tray.modelData
              if (m.button === Qt.RightButton || it.onlyMenu) {
                if (it.hasMenu) { var p = tray.mapToItem(null, 0, -8); it.display(win, p.x, p.y) }
              } else it.activate()
            }
          }
        }
      }
      Sticker {
        size: 42; fill: s.rainbow[3]; tilt: 3
        icon: win.muted ? "volume_off" : "volume_up"
        onClicked: s.toggleMenu("home")
        onWheeled: function(d) { win.run("wpctl set-volume -l 1.0 @DEFAULT_AUDIO_SINK@ 5%" + (d > 0 ? "+" : "-")) }
      }
      Sticker {
        size: 42; fill: s.rainbow[4]; tilt: -3
        icon: s.netDev === "" ? "wifi_off" : (s.netWifi ? "wifi" : "lan")
        onClicked: s.toggleMenu("home")
      }
      Rectangle {
        visible: s.batteryPct >= 0 && win.jo("battery")
        anchors.verticalCenter: parent.verticalCenter
        width: 52; height: 42; radius: 12; rotation: 2 * win.tk
        color: !s.charging && s.batteryPct <= 15 ? s.errorColor : s.rainbow[2]
        border.width: 3; border.color: win.line
        Text {
          anchors.centerIn: parent; text: s.batteryPct + (s.charging ? "⚡" : "%")
          font.family: win.font; font.pixelSize: 15; font.weight: Font.Black; color: "#1b1030"
        }
      }
      Sticker { size: 42; fill: s.rainbow[0]; icon: "power_settings_new"; tilt: 5; onClicked: s.powerMenu() }
    }
  }

  component Bar_: Rectangle { anchors.verticalCenter: parent.verticalCenter; width: 3; height: 40; radius: 2; color: win.s.alpha(win.line, 0.25) }
  component Sticker: Rectangle {
    id: st
    property real size: 42
    property string icon: ""
    property color fill: "white"
    property color iconColor: "#1b1030"
    property real tilt: 0
    signal clicked()
    signal wheeled(int d)
    anchors.verticalCenter: parent.verticalCenter
    width: size; height: size; radius: size * 0.3
    color: fill; border.width: 3; border.color: win.line
    rotation: sma.containsMouse ? 0 : tilt * win.tk
    scale: sma.pressed ? 0.88 : (sma.containsMouse && win.s.opt("jouet_magnify", true) !== false ? 1.14 : 1)
    Behavior on scale { NumberAnimation { duration: 160; easing.type: Easing.OutBack; easing.overshoot: 3 } }
    Behavior on rotation { NumberAnimation { duration: 160 } }
    MIcon { anchors.centerIn: parent; icon: st.icon; size: st.size * 0.56; fill: 1; weight: 600; color: st.iconColor }
    MouseArea {
      id: sma; anchors.fill: parent; hoverEnabled: true
      onClicked: st.clicked()
      onWheel: function(w) { st.wheeled(w.angleDelta.y > 0 ? 1 : -1) }
    }
  }
}
