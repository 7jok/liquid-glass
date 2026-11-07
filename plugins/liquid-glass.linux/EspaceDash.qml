import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets
import "T.js" as T

// Tableau de bord du style Espace, au centre de l'écran : heure, calendrier,
// météo, lecteur avec égaliseur, batterie et jauges.
PanelWindow {
  id: win
  property var service: null
  readonly property var s: service

  color: "transparent"
  anchors { top: true; bottom: true; left: true; right: true }
  exclusionMode: ExclusionMode.Ignore
  WlrLayershell.layer: WlrLayer.Overlay
  WlrLayershell.namespace: "liquid-glass-linux-panel"
  WlrLayershell.keyboardFocus: s.kbd(false)

  readonly property string font: s.sansFont
  readonly property color ink: s.colOnSurface
  readonly property color sub: s.colOnSurfaceVariant
  property date now: new Date()
  Timer { interval: 1000; repeat: true; running: true; onTriggered: win.now = new Date() }
  property bool revealed: false
  Component.onCompleted: { revealed = true; keys.forceActiveFocus() }
  Item { id: keys; focus: true; Keys.onEscapePressed: win.s.closeAll() }
  MouseArea { anchors.fill: parent; onClicked: win.s.closeAll() }

  readonly property date first: new Date(now.getFullYear(), now.getMonth(), 1)
  readonly property int lead: (first.getDay() + 6) % 7

  Rectangle {
    anchors.centerIn: parent
    width: 820; height: 450
    radius: 16
    color: win.s.alpha(win.s.surface, 0.9)
    border.width: 1; border.color: win.s.alpha(win.ink, 0.12)
    opacity: win.revealed ? 1 : 0
    scale: win.revealed ? 1 : 0.96
    Behavior on opacity { NumberAnimation { duration: 180 } }
    Behavior on scale { NumberAnimation { duration: 240; easing.type: Easing.OutCubic } }
    MouseArea { anchors.fill: parent }

    // Calendrier
    Column {
      x: 24; y: 22; width: 250; spacing: 8
      Text { text: win.now.toLocaleDateString(Qt.locale(T.loc), "MMMM yyyy"); font.family: win.font; font.pixelSize: 13; font.weight: Font.Bold; color: win.ink }
      Grid {
        columns: 7; rowSpacing: 3; columnSpacing: 0
        Repeater {
          model: ["L", "M", "M", "J", "V", "S", "D"]
          delegate: Text {
            required property string modelData
            width: 250 / 7; horizontalAlignment: Text.AlignHCenter; text: modelData
            font.family: win.font; font.pixelSize: 10; color: win.sub
          }
        }
        Repeater {
          model: 42
          delegate: Item {
            required property int index
            readonly property date d: new Date(win.first.getFullYear(), win.first.getMonth(), index - win.lead + 1)
            readonly property bool inMonth: d.getMonth() === win.first.getMonth()
            readonly property bool today: d.toDateString() === win.now.toDateString()
            width: 250 / 7; height: 25
            Rectangle { anchors.centerIn: parent; visible: parent.today; width: 25; height: 25; radius: 7; color: win.s.primary }
            Text {
              anchors.centerIn: parent; text: parent.d.getDate()
              font.family: win.font; font.pixelSize: 11; font.weight: parent.today ? Font.Bold : Font.Normal
              color: parent.today ? win.s.colOnPrimary : (parent.inMonth ? win.ink : win.s.alpha(win.sub, 0.45))
            }
          }
        }
      }
    }

    // Heure et météo
    Column {
      x: 300; y: 34; width: 220; spacing: 2
      Text {
        anchors.horizontalCenter: parent.horizontalCenter
        text: Qt.formatTime(win.now, "HH:mm")
        font.family: win.font; font.pixelSize: 62; font.weight: Font.Bold; color: win.ink
      }
      Text {
        anchors.horizontalCenter: parent.horizontalCenter
        text: win.now.toLocaleDateString(Qt.locale(T.loc), "dddd d MMMM")
        font.family: win.font; font.pixelSize: 12; color: win.sub
      }
      Item { width: 1; height: 14 }
      Row {
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: 10
        MIcon { anchors.verticalCenter: parent.verticalCenter; icon: win.s.weatherIcon; size: 30; fill: 1; color: win.s.primary }
        Column {
          anchors.verticalCenter: parent.verticalCenter
          Text { text: win.s.weather ? win.s.weather.temp + " °C" : "--"; font.family: win.font; font.pixelSize: 19; font.weight: Font.Bold; color: win.ink }
          Text { text: win.s.weatherDesc.charAt(0).toUpperCase() + win.s.weatherDesc.slice(1); font.family: win.font; font.pixelSize: 11; color: win.sub }
        }
      }
    }

    // Jauges
    Row {
      x: 300; y: 196; width: 220; spacing: 14
      Repeater {
        model: [["CPU", win.s.cpu], ["RAM", win.s.memPct], ["SSD", win.s.diskPct]]
        delegate: Item {
          required property var modelData
          width: 62; height: 62
          Ring { anchors.fill: parent; value: modelData[1]; thickness: 4; color: win.s.primary; track: win.s.alpha(win.ink, 0.12) }
          Column {
            anchors.centerIn: parent
            Text { anchors.horizontalCenter: parent.horizontalCenter; text: Math.round(modelData[1] * 100); font.family: win.font; font.pixelSize: 15; font.weight: Font.Bold; color: win.ink }
            Text { anchors.horizontalCenter: parent.horizontalCenter; text: modelData[0]; font.family: win.font; font.pixelSize: 8; color: win.sub }
          }
        }
      }
    }

    // Lecteur et égaliseur
    Item {
      x: 546; y: 22; width: 250; height: 250
      ClippingRectangle {
        anchors.horizontalCenter: parent.horizontalCenter
        width: 104; height: 104; radius: 52; color: win.s.surfaceHigh
        Image { anchors.fill: parent; source: win.s.cover; fillMode: Image.PreserveAspectCrop; asynchronous: true; cache: false; sourceSize.width: 220 }
        RotationAnimation on rotation { from: 0; to: 360; duration: 14000; loops: Animation.Infinite; running: win.s.playing }
      }
      Column {
        y: 112; width: parent.width; spacing: 1
        Text { width: parent.width; horizontalAlignment: Text.AlignHCenter; elide: Text.ElideRight; text: win.s.trackTitle || T.t("Rien en lecture"); font.family: win.font; font.pixelSize: 14; font.weight: Font.Bold; color: win.ink }
        Text { width: parent.width; horizontalAlignment: Text.AlignHCenter; elide: Text.ElideRight; text: win.s.trackArtist; font.family: win.font; font.pixelSize: 11; color: win.sub }
      }
      Row {
        anchors.horizontalCenter: parent.horizontalCenter; y: 156; spacing: 10
        Ctl { icon: "skip_previous"; onClicked: { if (win.s.player) win.s.player.previous() } }
        Ctl { icon: win.s.playing ? "pause" : "play_arrow"; big: true; onClicked: win.s.playPause() }
        Ctl { icon: "skip_next"; onClicked: { if (win.s.player) win.s.player.next() } }
      }
      // Égaliseur : 12 curseurs qui suivent le spectre.
      Row {
        id: eq
        anchors.horizontalCenter: parent.horizontalCenter; y: 200; spacing: 11
        Repeater {
          model: 12
          delegate: Item {
            required property int index
            readonly property real v: win.s.cavaValues.length ? win.s.cavaValues[Math.floor(index / 12 * win.s.cavaValues.length)] / 100 : 0.12
            width: 9; height: 46
            Rectangle { anchors.horizontalCenter: parent.horizontalCenter; width: 2; height: parent.height; radius: 1; color: win.s.alpha(win.ink, 0.16) }
            Rectangle {
              anchors.horizontalCenter: parent.horizontalCenter
              y: (parent.height - height) * (1 - parent.v)
              width: 9; height: 5; radius: 2; color: win.s.primary
              Behavior on y { NumberAnimation { duration: 90 } }
            }
          }
        }
      }
    }

    // Bas : batterie, et tous les raccourcis de session.
    Rectangle { x: 24; y: 292; width: parent.width - 48; height: 1; color: win.s.alpha(win.ink, 0.1) }
    Item {
      x: 24; y: 306; width: parent.width - 48; height: 124
      Item {
        visible: win.s.batteryPct >= 0
        width: 116; height: 116
        Ring { anchors.fill: parent; value: win.s.batteryPct / 100; thickness: 7; color: win.s.primary; track: win.s.alpha(win.ink, 0.12) }
        Text { anchors.centerIn: parent; text: win.s.batteryPct + " %"; font.family: win.font; font.pixelSize: 22; font.weight: Font.Bold; color: win.ink }
      }
      Planets { x: 142; width: 116; height: 116; s: win.s }
      Column {
        x: 286; anchors.verticalCenter: parent.verticalCenter; spacing: 6
        Text { text: win.s.user; font.family: win.font; font.pixelSize: 15; font.weight: Font.Bold; color: win.ink }
        Text { text: T.t("Allumé depuis ") + win.s.uptimeText; font.family: win.font; font.pixelSize: 11; color: win.sub }
      }
      Row {
        anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
        spacing: 8
        Repeater {
          model: [["lock", "lock"], ["suspend", "bedtime"], ["logout", "logout"], ["reboot", "restart_alt"], ["poweroff", "power_settings_new"]]
          delegate: Rectangle {
            required property var modelData
            width: 44; height: 44; radius: 12
            color: sma.containsMouse ? win.s.primary : win.s.alpha(win.ink, 0.08)
            MIcon { anchors.centerIn: parent; icon: modelData[1]; size: 20; color: sma.containsMouse ? win.s.colOnPrimary : win.ink }
            MouseArea { id: sma; anchors.fill: parent; hoverEnabled: true; onClicked: win.s.power(modelData[0]) }
          }
        }
      }
    }
  }

  component Ctl: Rectangle {
    id: ct
    property string icon: ""
    property bool big: false
    signal clicked()
    width: big ? 46 : 32; height: 32; radius: 10
    color: big ? win.s.primary : (cma.containsMouse ? win.s.alpha(win.ink, 0.14) : win.s.alpha(win.ink, 0.07))
    MIcon { anchors.centerIn: parent; icon: ct.icon; size: 19; fill: 1; color: ct.big ? win.s.colOnPrimary : win.ink }
    MouseArea { id: cma; anchors.fill: parent; hoverEnabled: true; onClicked: ct.clicked() }
  }
}
