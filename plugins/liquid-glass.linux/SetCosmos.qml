import QtQuick
import "T.js" as T

// Réglages Cosmos : la console de bord d'une station, en bas de l'écran sur
// toute la largeur. Les pages sont des stations sur une ligne de temps (points
// reliés, la station en cours clignote), quadrillage au fond, réglages en
// modules carrés, police JetBrains, voyants et curseurs en pointillés.
SetWin {
  id: w
  veil: Qt.rgba(0, 0.03, 0.05, 0.3)
  readonly property color ink: s.colOnSurface
  readonly property color acc: s.primary
  readonly property string font: s.userFont || "JetBrainsMono Nerd Font"
  readonly property var look: ({ font: w.font, head: w.font, px: 12, ink: w.ink, sub: s.colOnSurfaceVariant, acc: w.acc, accInk: s.colOnPrimary,
    tile: s.alpha(w.acc, 0.1), bcol: s.alpha(w.acc, 0.5), radius: 3, border: 1, toggle: "led", slider: "dots", chip: "box", button: "box",
    headColor: w.acc, headPx: 11, headPrefix: "▸ ", headSpacing: 2, upper: true, rowPad: 4 })

  Item {
    id: deck
    width: parent.width - 24; x: 12
    height: Math.min(parent.height * 0.56, 520)
    y: w.revealed ? parent.height - height - 12 : parent.height + 10
    Behavior on y { NumberAnimation { duration: 420; easing.type: Easing.OutCubic } }
    MouseArea { anchors.fill: parent }
    Rectangle { anchors.fill: parent; radius: 10; color: s.alpha(s.surface, 0.94); border.width: 1; border.color: s.alpha(w.acc, 0.5) }
    // quadrillage
    Canvas {
      anchors.fill: parent; anchors.margins: 1
      opacity: 0.12
      onPaint: {
        var c = getContext("2d"); c.reset(); c.strokeStyle = w.acc; c.lineWidth = 1
        for (var x = 0; x < width; x += 28) { c.beginPath(); c.moveTo(x, 0); c.lineTo(x, height); c.stroke() }
        for (var y = 0; y < height; y += 28) { c.beginPath(); c.moveTo(0, y); c.lineTo(width, y); c.stroke() }
      }
    }
    // en-tête de mission
    Text { x: 22; y: 14; text: "COSMOS // " + T.t("CONSOLE DE BORD") + "  ·  " + s.user.toUpperCase() + "  ·  T+" + s.uptimeText.toUpperCase(); font.family: w.font; font.pixelSize: 12; font.letterSpacing: 2; color: w.acc }
    Text { anchors.right: parent.right; anchors.rightMargin: 22; y: 14; text: Qt.formatTime(new Date(), "HH:mm:ss") + " UTC" + (new Date().getTimezoneOffset() <= 0 ? "+" : "-") + Math.abs(new Date().getTimezoneOffset() / 60); font.family: w.font; font.pixelSize: 12; color: s.colOnSurfaceVariant }
    // ligne des stations
    Item {
      id: line
      x: 40; y: 46; width: parent.width - 80; height: 54
      Rectangle { y: 12; width: parent.width; height: 2; color: s.alpha(w.acc, 0.35) }
      Rectangle { y: 12; width: parent.width * w.core.pageIndex / (w.core.pages.length - 1); height: 2; color: w.acc
        Behavior on width { NumberAnimation { duration: 400; easing.type: Easing.OutCubic } } }
      Repeater {
        model: w.core.pages
        delegate: Item {
          id: stn
          required property var modelData
          required property int index
          readonly property bool cur: w.core.page === modelData[0]
          readonly property bool past: index <= w.core.pageIndex
          x: index / (w.core.pages.length - 1) * line.width - 40; width: 80; height: 54
          Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter; y: 13 - height / 2
            width: stn.cur ? 18 : 12; height: width; radius: width / 2
            color: stn.past ? w.acc : s.surface; border.width: 2; border.color: w.acc
            SequentialAnimation on opacity { running: stn.cur; loops: Animation.Infinite; NumberAnimation { to: 0.35; duration: 600 } NumberAnimation { to: 1; duration: 600 } }
          }
          Text { anchors.horizontalCenter: parent.horizontalCenter; y: 28; text: stn.modelData[1].toUpperCase(); font.family: w.font; font.pixelSize: 10; font.weight: stn.cur ? Font.Bold : Font.Normal; color: stn.cur ? w.acc : s.colOnSurfaceVariant }
          MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: w.core.page = stn.modelData[0] }
        }
      }
    }
    SetList {
      x: 22; y: 108; width: parent.width - 44; height: parent.height - y - 14
      core: w.core; look: w.look
      mode: "tiles"; tileW: 270; gap: 8
      boxColor: s.alpha(s.surfaceMid, 0.9); boxRadius: 4; boxBorder: s.alpha(w.acc, 0.3); boxBorderW: 1
    }
  }
}
