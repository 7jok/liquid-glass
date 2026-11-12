import QtQuick
import "T.js" as T

// Réglages Sombre : un mur de tuiles en plein écran, comme le bureau. À gauche
// une grille 3×3 de tuiles-pages marquées d'un kanji, à droite la page en tuiles
// (voyants ON/OFF, curseurs en blocs), liseré lumineux en haut de chaque tuile,
// grand kanji de la page en filigrane.
SetWin {
  id: w
  veil: Qt.rgba(0, 0, 0, 0.72)
  readonly property color ink: s.colOnSurface
  readonly property color acc: s.primary
  readonly property color tileC: s.alpha(s.surfaceMid, Number(s.opt("sombre_tile_alpha", 0.72)))
  readonly property int gap: Math.max(4, Number(s.opt("sombre_gap", 10)))
  readonly property bool glow: s.opt("sombre_glow", true) !== false
  readonly property string font: s.userFont || "JetBrainsMono Nerd Font"
  readonly property var kanji: ({ home: "家", style: "型", look: "色", net: "網", bt: "青", sound: "音", screen: "光", power: "電", system: "機" })
  readonly property var look: ({ font: w.font, head: w.font, px: 13, ink: w.ink, sub: s.colOnSurfaceVariant, acc: w.acc, accInk: s.colOnPrimary,
    tile: s.alpha(w.ink, 0.06), bcol: s.alpha(w.ink, 0.25), radius: 4, border: 1, toggle: "led", slider: "blocks", chip: "box", button: "box",
    headPrefix: "# ", headColor: w.acc, headPx: 12, headSpacing: 2, upper: false, swatch: "square", rowPad: 4 })

  Item {
    id: wall
    width: Math.min(parent.width - 60, 1180); height: Math.min(parent.height - 90, 640)
    anchors.centerIn: parent
    opacity: w.revealed ? 1 : 0
    scale: w.revealed ? 1 : 0.96
    Behavior on opacity { NumberAnimation { duration: 260 } }
    Behavior on scale { NumberAnimation { duration: 320; easing.type: Easing.OutCubic } }
    MouseArea { anchors.fill: parent }

    // ---- tuiles-pages
    Grid {
      id: pg
      columns: 3; spacing: w.gap
      readonly property real cell: (330 - 2 * w.gap) / 3
      Repeater {
        model: w.core.pages
        delegate: Rectangle {
          id: pt
          required property var modelData
          readonly property bool cur: w.core.page === modelData[0]
          width: pg.cell; height: pg.cell
          radius: 6
          color: cur ? w.acc : (pm.containsMouse ? s.alpha(w.ink, 0.1) : w.tileC)
          border.width: 1; border.color: s.alpha(w.ink, cur ? 0 : 0.08)
          Behavior on color { ColorAnimation { duration: 140 } }
          Rectangle { visible: w.glow && !pt.cur; x: 8; width: parent.width - 16; height: 2; color: w.acc; opacity: 0.55 }
          Text {
            anchors.centerIn: parent; anchors.verticalCenterOffset: -8
            text: w.kanji[pt.modelData[0]] || "・"
            font.pixelSize: 40; color: pt.cur ? s.colOnPrimary : w.ink
          }
          Text {
            anchors.bottom: parent.bottom; anchors.bottomMargin: 8; anchors.horizontalCenter: parent.horizontalCenter
            text: pt.modelData[1].toLowerCase()
            font.family: w.font; font.pixelSize: 11; color: pt.cur ? s.colOnPrimary : s.colOnSurfaceVariant
          }
          MouseArea { id: pm; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: w.core.page = pt.modelData[0] }
        }
      }
    }
    // tuile horloge sous les pages
    Rectangle {
      x: 0; y: pg.height + w.gap
      width: 330; height: wall.height - y
      radius: 6; color: w.tileC
      Rectangle { visible: w.glow; x: 8; width: parent.width - 16; height: 2; color: w.acc; opacity: 0.55 }
      Column {
        anchors.centerIn: parent; spacing: 4
        Text { anchors.horizontalCenter: parent.horizontalCenter; text: Qt.formatTime(new Date(), "HH:mm"); font.family: w.font; font.pixelSize: 44; font.weight: Font.Bold; color: w.ink }
        Text { anchors.horizontalCenter: parent.horizontalCenter; text: s.user + " · up " + s.uptimeText; font.family: w.font; font.pixelSize: 12; color: s.colOnSurfaceVariant }
        Text { anchors.horizontalCenter: parent.horizontalCenter; text: T.t("échap fermer · tab page"); font.family: w.font; font.pixelSize: 11; color: s.alpha(w.ink, 0.4) }
      }
    }
    // ---- la page
    Item {
      x: 330 + w.gap; width: wall.width - x; height: wall.height
      Text {
        anchors.right: parent.right; anchors.rightMargin: 10; y: -40
        text: w.kanji[w.core.page] || ""
        font.pixelSize: 260; color: s.alpha(w.acc, 0.07)
      }
      Text {
        x: 4; y: 0
        text: w.core.pageInfo[1].toLowerCase() + " /"
        font.family: w.font; font.pixelSize: 22; font.weight: Font.Bold; color: w.ink
      }
      SetList {
        y: 40; width: parent.width; height: parent.height - 40
        core: w.core; look: w.look
        mode: "tiles"; tileW: 250; gap: w.gap
        boxColor: w.tileC; boxRadius: 6; boxBorder: s.alpha(w.ink, 0.08); boxBorderW: 1
      }
    }
  }
}
