import QtQuick
import QtQuick.Effects
import "T.js" as T

// Réglages Violet : une grande lune ronde au centre de l'écran, dans la brume.
// Les pages sont les phases de la Lune posées en arc au-dessus (de la nouvelle
// lune à la pleine), la page s'affiche en cartes douces et translucides sous
// un titre en police ronde « bonbon ». Interrupteurs en points lumineux.
SetWin {
  id: w
  veil: s.alpha(s.darkSkin ? "#0c0716" : "#e9e0f7", 0.55)
  readonly property color ink: s.colOnSurface
  readonly property color acc: s.primary
  readonly property string font: s.userFont || "Google Sans Flex"
  readonly property var look: ({ font: w.font, head: s.roundFont, px: 14, ink: w.ink, sub: s.colOnSurfaceVariant, acc: w.acc, accInk: s.colOnPrimary,
    tile: s.alpha(w.ink, 0.07), bcol: s.alpha(w.ink, 0.2), radius: 16, border: 0, toggle: "dot", slider: "line", chip: "pill", button: "pill",
    headColor: w.acc, headPx: 13, headWeight: Font.Bold, headSpacing: 1, rowPad: 8 })

  // étoiles
  Repeater {
    model: 46
    delegate: Rectangle {
      required property int index
      x: (index * 397 % 1000) / 1000 * w.width; y: (index * 613 % 1000) / 1000 * w.height
      width: index % 5 ? 2 : 3; height: width; radius: width / 2
      color: s.darkSkin ? "white" : w.acc
      opacity: w.revealed ? (index % 3 ? 0.35 : 0.7) : 0
      Behavior on opacity { NumberAnimation { duration: 900 } }
    }
  }
  Item {
    id: orb
    width: Math.min(parent.width - 80, 900); height: Math.min(parent.height - 70, 660)
    anchors.centerIn: parent
    opacity: w.revealed ? 1 : 0
    scale: w.revealed ? 1 : 0.85
    Behavior on opacity { NumberAnimation { duration: 380 } }
    Behavior on scale { NumberAnimation { duration: 520; easing.type: Easing.OutBack } }
    MouseArea { anchors.fill: parent }
    RectangularShadow { anchors.fill: disc; radius: disc.radius; blur: 60; spread: 4; color: s.alpha(w.acc, 0.35) }
    Rectangle {
      id: disc
      anchors.fill: parent; radius: 120
      gradient: Gradient {
        GradientStop { position: 0; color: Qt.tint(s.surfaceMid, s.alpha(w.acc, 0.12)) }
        GradientStop { position: 1; color: s.alpha(s.surface, 0.96) }
      }
      border.width: 1; border.color: s.alpha(w.acc, 0.35)
    }
    // phases en arc
    Item {
      id: arc
      width: parent.width; height: 120
      Repeater {
        model: w.core.pages
        delegate: Item {
          id: ph
          required property var modelData
          required property int index
          readonly property real t: index / (w.core.pages.length - 1)
          readonly property bool cur: w.core.page === modelData[0]
          readonly property real ang: Math.PI * (0.92 - 0.84 * t)
          width: 58; height: 78
          x: arc.width / 2 + Math.cos(ang) * arc.width * 0.4 - width / 2
          y: 96 - Math.sin(ang) * 84
          // lune : un disque clair, mordu par un disque de fond selon la phase
          Rectangle {
            id: moon
            width: ph.cur ? 46 : 36; height: width; radius: width / 2
            anchors.horizontalCenter: parent.horizontalCenter
            color: ph.cur ? w.acc : s.alpha(w.ink, 0.85)
            clip: true
            Behavior on width { NumberAnimation { duration: 300; easing.type: Easing.OutBack } }
            Rectangle {
              width: parent.width; height: parent.height; radius: width / 2
              x: ph.t * parent.width * 1.04
              color: Qt.tint(s.surfaceMid, s.alpha(w.acc, 0.12))
            }
            Rectangle { anchors.fill: parent; radius: width / 2; color: "transparent"; border.width: 1; border.color: s.alpha(w.ink, 0.3) }
          }
          Text {
            anchors.horizontalCenter: parent.horizontalCenter; y: moon.height + 4
            text: ph.modelData[1]
            font.family: w.font; font.pixelSize: 11; font.weight: ph.cur ? Font.Bold : Font.Normal
            color: ph.cur ? w.acc : s.colOnSurfaceVariant
          }
          MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: w.core.page = ph.modelData[0] }
        }
      }
    }
    Text {
      anchors.horizontalCenter: parent.horizontalCenter; y: 120
      text: w.core.pageInfo[1]
      font.family: s.roundFont; font.variableAxes: s.roundAxes; font.pixelSize: 40; color: w.ink
    }
    SetList {
      x: 110; y: 182
      width: parent.width - 220; height: parent.height - y - 50
      core: w.core; look: w.look
      mode: "cards"; gap: 8; boxPad: 16
      boxColor: s.alpha(w.ink, 0.05); boxRadius: 22; sepColor: s.alpha(w.ink, 0.06)
    }
  }
}
