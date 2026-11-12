import QtQuick
import QtQuick.Effects
import "T.js" as T

// Réglages Infini : une toile pointillée sans bord. Chaque page est une carte
// posée sur la toile en file, légèrement penchée ; celle du centre est grande et
// lisible, les voisines rapetissent sur les côtés. Molette, Tab ou clic sur une
// carte : la toile glisse jusqu'à elle (ressort). Gros titres Bebas Neue, sakura.
SetWin {
  id: w
  veil: s.alpha("#120d0e", 0.78)
  readonly property color ink: s.colOnSurface
  readonly property color acc: s.primary
  readonly property string font: s.userFont || "Inter"
  readonly property string display: s.userDisplay || "Bebas Neue"
  readonly property var look: ({ font: w.font, head: w.display, px: 13, ink: w.ink, sub: s.colOnSurfaceVariant, acc: w.acc, accInk: s.colOnPrimary,
    tile: s.alpha(w.ink, 0.07), bcol: s.alpha(w.acc, 0.4), radius: 10, border: 1, toggle: "switch", slider: "line", chip: "pill", button: "pill",
    headColor: w.acc, headPx: 18, headWeight: Font.Normal, headSpacing: 2, rowPad: 7 })
  property real pos: core.pageIndex
  Behavior on pos { SpringAnimation { spring: 2.6; damping: 0.3; epsilon: 0.002 } }

  // toile pointillée qui glisse avec les cartes
  Canvas {
    id: dots
    anchors.fill: parent
    opacity: 0.22
    property real off: -w.pos * 90
    onOffChanged: requestPaint()
    onPaint: {
      var c = getContext("2d"); c.reset(); c.fillStyle = w.acc
      var o = ((off % 30) + 30) % 30
      for (var x = o; x < width; x += 30) for (var y = 0; y < height; y += 30) { c.fillRect(x, y, 2, 2) }
    }
  }
  MouseArea {
    anchors.fill: parent
    onWheel: function(e) { w.core.step(e.angleDelta.y < 0 || e.angleDelta.x < 0 ? 1 : -1) }
    onClicked: w.core.close()
  }
  Repeater {
    model: w.core.pages
    delegate: Item {
      id: card
      required property var modelData
      required property int index
      readonly property real d: index - w.pos
      readonly property bool cur: Math.abs(d) < 0.5
      readonly property real k: Math.max(0.36, 1 - Math.abs(d) * 0.3)
      width: Math.min(w.width * 0.46, 600); height: Math.min(w.height - 140, 640)
      x: w.width / 2 - width / 2 + d * (width * 0.62 + 40) * (Math.abs(d) > 1 ? 0.8 : 1)
      y: (w.height - height) / 2 + Math.abs(d) * 30
      scale: k
      rotation: d * 4
      z: 10 - Math.abs(d)
      opacity: Math.abs(d) > 2.6 ? 0 : (w.revealed ? 1 : 0)
      visible: opacity > 0
      Behavior on opacity { NumberAnimation { duration: 300 } }
      RectangularShadow { anchors.fill: face; radius: face.radius; blur: 40; offset.y: 16; color: Qt.rgba(0, 0, 0, 0.5) }
      Rectangle {
        id: face
        anchors.fill: parent; radius: 18
        color: s.alpha(s.surfaceMid, 0.96)
        border.width: 1; border.color: s.alpha(w.acc, card.cur ? 0.7 : 0.25)
      }
      Text {
        x: 26; y: 16
        text: (card.index + 1 < 10 ? "0" : "") + (card.index + 1)
        font.family: w.display; font.pixelSize: 64; color: s.alpha(w.acc, 0.35)
      }
      Text {
        x: 26; y: 70
        text: card.modelData[1].toUpperCase()
        font.family: w.display; font.pixelSize: 46; font.letterSpacing: 2; color: w.ink
      }
      MIcon { anchors.right: parent.right; anchors.rightMargin: 26; y: 30; icon: card.modelData[2]; size: 40; fill: 1; color: w.acc }
      // seul le centre montre ses réglages ; les autres un aperçu
      Loader {
        x: 26; y: 130; width: parent.width - 52; height: parent.height - y - 20
        active: Math.abs(card.d) < 1.4
        sourceComponent: SetList {
          core: w.core; look: w.look; page: card.modelData[0]
          mode: "plain"; sepColor: s.alpha(w.ink, 0.07)
          interactive: card.cur
        }
      }
      MouseArea {
        anchors.fill: parent
        enabled: !card.cur
        cursorShape: Qt.PointingHandCursor
        onClicked: w.core.page = card.modelData[0]
      }
    }
  }
  Text {
    anchors.horizontalCenter: parent.horizontalCenter; anchors.bottom: parent.bottom; anchors.bottomMargin: 26
    text: T.t("molette ou tab : glisser sur la toile · échap : fermer")
    font.family: w.font; font.pixelSize: 12; color: s.alpha(w.ink, 0.45)
  }
}
