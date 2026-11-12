import QtQuick
import QtQuick.Effects
import "T.js" as T

// Réglages Rubans : une grande bande penchée entre par la gauche, onglets en
// rubans numérotés empilés, lignes sur des bandes alternées, tout en capitales
// italiques grasses, ombres dures noires, accent de la teinte (bleu, rouge, or).
SetWin {
  id: w
  veil: Qt.rgba(0, 0, 0, 0.45)
  readonly property color acc: s.primary
  readonly property color ink: "#f4f4f4"
  readonly property color paper: Qt.darker(s.surface, 1.35)
  readonly property string font: s.userFont || "Rubik"
  readonly property var look: ({ font: w.font, head: w.font, px: 14, ink: w.ink, sub: s.alpha(w.ink, 0.6), acc: w.acc, accInk: "#0b0b0b",
    tile: s.alpha(w.ink, 0.08), bcol: "#000000", radius: 0, border: 0, hard: 4, upper: true, italic: true, labelWeight: Font.Black,
    toggle: "ribbon", slider: "ribbon", chip: "ribbon", button: "ribbon", headItalic: true, headPx: 13, headSpacing: 3,
    headColor: w.acc, headPrefix: "/// ", swatch: "square", headGap: 16 })

  // ---- la bande
  Item {
    id: band
    width: Math.min(parent.width * 0.62, 860)
    height: parent.height
    x: w.revealed ? 0 : -width - 200
    Behavior on x { NumberAnimation { duration: 460; easing.type: Easing.OutExpo } }
    MouseArea { anchors.fill: parent }
    // bord droit penché + liseré d'accent
    Rectangle {
      x: -200; width: parent.width + 200; height: parent.height; color: "#000000"
      transform: Matrix4x4 { matrix: Qt.matrix4x4(1, -0.12, 0, 0.12 * band.height + 18, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1) }
    }
    Rectangle {
      x: -200; width: parent.width + 200; height: parent.height; color: w.acc
      transform: Matrix4x4 { matrix: Qt.matrix4x4(1, -0.12, 0, 0.12 * band.height + 8, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1) }
    }
    Rectangle {
      x: -200; width: parent.width + 200; height: parent.height; color: w.paper
      transform: Matrix4x4 { matrix: Qt.matrix4x4(1, -0.12, 0, 0.12 * band.height, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1) }
    }
    // filigrane : nom de la page en géant
    Item {
      width: parent.width; height: parent.height; clip: true
    Text {
      x: 150; y: parent.height - 260
      rotation: -8
      text: w.core.pageInfo[1].toUpperCase()
      font.family: w.font; font.pixelSize: 210; font.weight: Font.Black; font.italic: true
      color: s.alpha(w.ink, 0.045)
    }
    }
    // titre
    Item {
      x: 44; y: 34
      width: parent.width - 80; height: 86
      Text {
        id: title
        text: T.t("RÉGLAGES")
        font.family: w.font; font.pixelSize: 54; font.weight: Font.Black; font.italic: true; font.letterSpacing: -1
        color: w.ink
      }
      Rectangle {
        anchors.left: title.right; anchors.leftMargin: 14; anchors.verticalCenter: title.verticalCenter
        width: 64; height: 14; color: w.acc
        transform: Matrix4x4 { matrix: Qt.matrix4x4(1, -0.6, 0, 4, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1) }
      }
      Text {
        y: title.height - 4
        text: (T.t("bureau ") + w.core.styleName() + " · " + s.user + " · up " + s.uptimeText).toUpperCase()
        font.family: w.font; font.pixelSize: 12; font.weight: Font.Bold; font.italic: true; font.letterSpacing: 2
        color: s.alpha(w.ink, 0.55)
      }
    }
    // ---- onglets : rubans empilés
    Column {
      id: tabs
      x: 0; y: 150
      spacing: 8
      Repeater {
        model: w.core.pages
        delegate: Item {
          id: tab
          required property var modelData
          required property int index
          readonly property bool cur: w.core.page === modelData[0]
          width: cur ? 214 : (tm.containsMouse ? 196 : 184); height: 38
          Behavior on width { NumberAnimation { duration: 240; easing.type: Easing.OutBack } }
          Rectangle {
            visible: tab.cur
            x: 5; y: 5; width: parent.width; height: parent.height; color: "#000000"
            transform: Matrix4x4 { matrix: Qt.matrix4x4(1, -0.35, 0, 6.6, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1) }
          }
          Rectangle {
            width: parent.width; height: parent.height
            color: tab.cur ? w.acc : (tm.containsMouse ? s.alpha(w.ink, 0.16) : s.alpha(w.ink, 0.07))
            transform: Matrix4x4 { matrix: Qt.matrix4x4(1, -0.35, 0, 6.6, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1) }
            Behavior on color { ColorAnimation { duration: 140 } }
          }
          Row {
            x: 26; anchors.verticalCenter: parent.verticalCenter
            spacing: 10
            Text {
              text: (tab.index + 1 < 10 ? "0" : "") + (tab.index + 1)
              font.family: w.font; font.pixelSize: 12; font.weight: Font.Black; font.italic: true
              color: tab.cur ? s.alpha("#000000", 0.55) : w.acc
            }
            Text {
              text: tab.modelData[1].toUpperCase()
              font.family: w.font; font.pixelSize: 14; font.weight: Font.Black; font.italic: true; font.letterSpacing: 1
              color: tab.cur ? "#0b0b0b" : w.ink
            }
          }
          MouseArea { id: tm; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: w.core.page = tab.modelData[0] }
        }
      }
    }
    // ---- contenu
    SetList {
      id: list
      x: 250; y: 140
      width: parent.width - x - 90
      height: parent.height - y - 60
      core: w.core; look: w.look
      mode: "band"
      bandColor: s.alpha(w.ink, 0.045); bandAlt: s.alpha(w.ink, 0.085)
      bandSkew: -0.25
      opacity: 0
      Component.onCompleted: opacity = 1
      Behavior on opacity { NumberAnimation { duration: 300 } }
    }
    // pied : raccourcis clavier
    Text {
      x: 44; y: parent.height - 34
      text: T.t("TAB PAGE SUIVANTE  ·  ÉCHAP FERMER")
      font.family: w.font; font.pixelSize: 11; font.weight: Font.Bold; font.italic: true; font.letterSpacing: 2
      color: s.alpha(w.ink, 0.35)
    }
  }
}
