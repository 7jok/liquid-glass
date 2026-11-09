import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets
import "T.js" as T

// Bureau du style Rubans : date géante en filigrane, jour de la semaine, bandes
// obliques (musique, météo) et bloc de batterie dont le niveau ondule.
PanelWindow {
  id: win
  property var service: null
  readonly property var s: service

  color: "transparent"
  anchors { top: true; bottom: true; left: true; right: true }
  exclusionMode: ExclusionMode.Normal
  WlrLayershell.layer: WlrLayer.Bottom
  WlrLayershell.namespace: "liquid-glass-linux-desktop"
  WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
  mask: Region {}

  readonly property string font: s && s.userFont ? s.userFont : "Rubik"
  property date now: new Date()
  Timer { interval: 10000; repeat: true; running: true; onTriggered: win.now = new Date() }
  // Biais commun à tous les blocs.
  function skew(h) { return Qt.matrix4x4(1, -0.22, 0, 0.22 * h, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1) }

  // Date en filigrane
  Row {
    visible: win.s.opt("ruban_date", true) !== false
    anchors.right: parent.right; anchors.rightMargin: 34; y: 2
    spacing: 18
    opacity: 0.32
    Text { text: Qt.formatDate(win.now, "dd"); font.family: win.font; font.pixelSize: 210; font.weight: Font.Black; font.italic: true; color: win.s.colOnSurface }
    Text { text: Qt.formatDate(win.now, "MM"); font.family: win.font; font.pixelSize: 210; font.weight: Font.Black; font.italic: true; color: "transparent"; style: Text.Outline; styleColor: win.s.colOnSurface }
  }
  Rectangle {
    anchors.right: parent.right; y: 226
    width: dayT.implicitWidth + 60; height: 44
    color: win.s.primary
    transform: Matrix4x4 { matrix: win.skew(44) }
    Text {
      id: dayT
      anchors.centerIn: parent
      text: win.now.toLocaleDateString(Qt.locale(T.loc), "dddd").toUpperCase()
      font.family: win.font; font.pixelSize: 26; font.weight: Font.Black; font.italic: true; color: win.s.colOnPrimary
    }
  }

  // Bande musique
  Item {
    visible: win.s.hasTrack && win.s.opt("ruban_music", true) !== false
    x: -14; anchors.bottom: parent.bottom; anchors.bottomMargin: 120
    width: 470; height: 92
    Rectangle { x: 8; y: 8; width: parent.width; height: parent.height; color: win.s.primary; transform: Matrix4x4 { matrix: win.skew(92) } }
    Rectangle {
      anchors.fill: parent; color: win.s.surface
      transform: Matrix4x4 { matrix: win.skew(92) }
      ClippingRectangle {
        x: 40; y: 10; width: 72; height: 72; radius: 0; color: win.s.surfaceHigh
        Image { anchors.fill: parent; source: win.s.cover; fillMode: Image.PreserveAspectCrop; asynchronous: true; cache: false; sourceSize.width: 160 }
      }
      Column {
        x: 126; y: 14; width: parent.width - 150; spacing: 2
        Text { width: parent.width; elide: Text.ElideRight; text: win.s.trackTitle.toUpperCase(); font.family: win.font; font.pixelSize: 22; font.weight: Font.Black; font.italic: true; color: win.s.colOnSurface }
        Text { width: parent.width; elide: Text.ElideRight; text: win.s.trackArtist; font.family: win.font; font.pixelSize: 13; font.weight: Font.Medium; color: win.s.primary }
        Item { width: 1; height: 5 }
        Rectangle {
          width: parent.width; height: 4; color: win.s.outlineVariant
          Rectangle { width: parent.width * win.s.progress; height: parent.height; color: win.s.primary }
        }
      }
    }
  }

  // Bande météo
  Item {
    visible: !!win.s.weather && win.s.opt("ruban_weather", true) !== false
    x: -14; anchors.bottom: parent.bottom; anchors.bottomMargin: 40
    width: 330; height: 62
    Rectangle { x: 8; y: 8; width: parent.width; height: parent.height; color: win.s.colOnSurface; transform: Matrix4x4 { matrix: win.skew(62) } }
    Rectangle {
      anchors.fill: parent; color: win.s.primary
      transform: Matrix4x4 { matrix: win.skew(62) }
      Row {
        x: 34; anchors.verticalCenter: parent.verticalCenter; spacing: 12
        MIcon { anchors.verticalCenter: parent.verticalCenter; icon: win.s.weatherIcon; size: 34; fill: 1; color: win.s.colOnPrimary }
        Text { anchors.verticalCenter: parent.verticalCenter; text: win.s.weather ? win.s.weather.temp + "°" : ""; font.family: win.font; font.pixelSize: 34; font.weight: Font.Black; font.italic: true; color: win.s.colOnPrimary }
        Text { anchors.verticalCenter: parent.verticalCenter; text: win.s.weatherDesc; font.family: win.font; font.pixelSize: 14; font.weight: Font.Bold; color: win.s.colOnPrimary }
      }
    }
  }

  // Batterie : un bloc en biais, le niveau ondule.
  Item {
    visible: win.s.batteryPct >= 0 && win.s.opt("ruban_battery", true) !== false
    anchors.right: parent.right; anchors.rightMargin: 36
    anchors.bottom: parent.bottom; anchors.bottomMargin: 40
    width: 170; height: 96
    Rectangle { x: 8; y: 8; width: parent.width; height: parent.height; color: win.s.primary; transform: Matrix4x4 { matrix: win.skew(96) } }
    Rectangle {
      anchors.fill: parent; color: win.s.surface; clip: true
      transform: Matrix4x4 { matrix: win.skew(96) }
      Canvas {
        id: wave
        anchors.fill: parent
        property real t: 0
        onTChanged: requestPaint()
        NumberAnimation on t { from: 0; to: Math.PI * 2; duration: 3600; loops: Animation.Infinite; running: true }
        onPaint: {
          var ctx = getContext("2d"), lvl = height * (1 - win.s.batteryPct / 100)
          ctx.clearRect(0, 0, width, height)
          ctx.fillStyle = String(win.s.alpha(win.s.primary, 0.45))
          ctx.beginPath(); ctx.moveTo(0, height)
          for (var x = 0; x <= width; x += 6) ctx.lineTo(x, lvl + 5 * Math.sin(x / 26 + t))
          ctx.lineTo(width, height); ctx.closePath(); ctx.fill()
        }
      }
      Text {
        anchors.centerIn: parent
        text: win.s.batteryPct + (win.s.charging ? "+" : "%")
        font.family: win.font; font.pixelSize: 42; font.weight: Font.Black; font.italic: true; color: win.s.colOnSurface
      }
    }
  }
}
