import QtQuick
import "T.js" as T

// Réglages Espace : plein écran étoilé. À gauche une planète porte le nom de la
// page, les autres pages sont des lunes en orbite (ellipse qui tourne lentement,
// clic = la lune devient la page). À droite la page sur un panneau de verre fin
// au trait d'un pixel, police Inter légère, interrupteurs en points.
SetWin {
  id: w
  veil: Qt.rgba(0.01, 0.02, 0.05, 0.86)
  readonly property color ink: s.colOnSurface
  readonly property color acc: s.primary
  readonly property string font: s.userFont || "Inter"
  readonly property var look: ({ font: w.font, head: w.font, px: 13, ink: w.ink, sub: s.colOnSurfaceVariant, acc: w.acc, accInk: s.colOnPrimary,
    tile: s.alpha(w.ink, 0.06), bcol: s.alpha(w.acc, 0.45), radius: 8, border: 1, toggle: "dot", slider: "line", chip: "box", button: "box",
    headColor: w.acc, headPx: 11, headSpacing: 3, upperHead: true, labelWeight: Font.Light, rowPad: 8, headPrefix: "◦ " })
  property real spin: 0
  NumberAnimation on spin { from: 0; to: Math.PI * 2; duration: 120000; loops: Animation.Infinite; running: w.revealed }

  // étoiles
  Repeater {
    model: 120
    delegate: Rectangle {
      required property int index
      x: (index * 7919 % 10007) / 10007 * w.width; y: (index * 104729 % 10007) / 10007 * w.height
      width: index % 7 ? 1 : 2; height: width; color: "white"
      opacity: w.revealed ? 0.2 + (index % 5) * 0.12 : 0
      Behavior on opacity { NumberAnimation { duration: 1200 } }
    }
  }
  // ---- système : planète + lunes
  Item {
    id: sys
    width: parent.width * 0.48; height: parent.height
    readonly property real cx: width / 2
    readonly property real cy: height / 2
    Rectangle {
      width: 360; height: 220; radius: 180
      x: sys.cx - width / 2; y: sys.cy - height / 2
      color: "transparent"; border.width: 1; border.color: s.alpha(w.acc, 0.25)
      scale: w.revealed ? 1 : 0.4
      Behavior on scale { NumberAnimation { duration: 700; easing.type: Easing.OutCubic } }
    }
    Rectangle {
      id: planet
      width: 150; height: 150; radius: 75
      x: sys.cx - 75; y: sys.cy - 75
      gradient: Gradient {
        GradientStop { position: 0; color: Qt.lighter(w.acc, 1.25) }
        GradientStop { position: 1; color: Qt.darker(w.acc, 2.6) }
      }
      Rectangle { anchors.centerIn: parent; width: 196; height: 196; radius: 98; color: "transparent"; border.width: 8; border.color: s.alpha(w.acc, 0.08) }
      Column {
        anchors.centerIn: parent
        MIcon { anchors.horizontalCenter: parent.horizontalCenter; icon: w.core.pageInfo[2]; size: 34; fill: 1; color: "white" }
        Text { anchors.horizontalCenter: parent.horizontalCenter; text: w.core.pageInfo[1]; font.family: w.font; font.pixelSize: 15; font.weight: Font.DemiBold; color: "white" }
      }
    }
    Repeater {
      model: w.core.pages
      delegate: Item {
        id: mo
        required property var modelData
        required property int index
        readonly property bool cur: w.core.page === modelData[0]
        readonly property real a: w.spin + index / w.core.pages.length * Math.PI * 2
        width: 80; height: 60
        x: sys.cx + Math.cos(a) * 180 - width / 2
        y: sys.cy + Math.sin(a) * 110 - 16
        z: Math.sin(a) > 0 ? 2 : 0
        visible: !cur
        Rectangle {
          anchors.horizontalCenter: parent.horizontalCenter
          width: 32; height: 32; radius: 16
          color: mm.containsMouse ? w.acc : Qt.tint(s.surfaceHigh, s.alpha(w.acc, 0.25))
          border.width: 1; border.color: s.alpha(w.acc, 0.6)
          scale: 0.8 + Math.sin(mo.a) * 0.2
          MIcon { anchors.centerIn: parent; icon: mo.modelData[2]; size: 16; color: mm.containsMouse ? s.colOnPrimary : w.ink }
        }
        Text { anchors.horizontalCenter: parent.horizontalCenter; y: 36; text: mo.modelData[1]; font.family: w.font; font.pixelSize: 10; color: s.colOnSurfaceVariant }
        MouseArea { id: mm; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: w.core.page = mo.modelData[0] }
      }
    }
    Text {
      anchors.horizontalCenter: parent.horizontalCenter; y: parent.height - 80
      text: T.t("clic sur une lune pour y aller · tab · échap")
      font.family: w.font; font.pixelSize: 11; font.letterSpacing: 2; color: s.alpha(w.ink, 0.4)
    }
  }
  // ---- panneau de verre
  Item {
    id: glass
    x: parent.width * 0.48; width: parent.width * 0.48; y: 70; height: parent.height - 120
    opacity: w.revealed ? 1 : 0
    Behavior on opacity { NumberAnimation { duration: 500 } }
    MouseArea { anchors.fill: parent }
    Rectangle { anchors.fill: parent; radius: 14; color: s.alpha(s.surface, 0.55); border.width: 1; border.color: s.alpha(w.acc, 0.35) }
    // repères aux angles
    Repeater {
      model: 4
      delegate: Rectangle {
        required property int index
        width: 14; height: 2; color: w.acc
        x: index % 2 ? glass.width - 22 : 8; y: index < 2 ? 8 : glass.height - 10
      }
    }
    Text { x: 26; y: 20; text: (w.core.pageIndex + 1) + " / " + w.core.pages.length + "  —  " + w.core.pageInfo[1].toUpperCase(); font.family: w.font; font.pixelSize: 12; font.letterSpacing: 4; color: w.acc }
    SetList {
      x: 26; y: 52; width: parent.width - 52; height: parent.height - y - 14
      core: w.core; look: w.look
      mode: "plain"; sepColor: s.alpha(w.acc, 0.12)
    }
  }
}
