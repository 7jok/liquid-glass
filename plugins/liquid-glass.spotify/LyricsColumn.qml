import QtQuick
import QtQuick.Effects

// Colonne de paroles synchronisées façon Apple Music : la ligne chantée est
// nette et pleine opacité, centrée verticalement ; les autres sont réduites,
// atténuées et floutées selon leur distance. Défilement par ressort.
Item {
  id: col

  property var service: null
  property string fontFamily: "Inter"
  property real fontSize: 34
  property color textColor: "#ffffff"
  property color shadowColor: "#80000000"
  property int horizontalAlignment: Text.AlignLeft
  property int visibleRadius: 5          // lignes affichées de part et d'autre
  property real blurPerLine: 0.22
  property bool showShadow: true

  readonly property var lines: service ? service.lyricLines : []
  readonly property int active: service ? service.lineIndex : -1
  readonly property real lineGap: fontSize * 0.55

  clip: false

  // Hauteur de chaque ligne mesurée, pour centrer exactement la ligne active.
  property var heights: []
  function offsetOf(i) {
    var y = 0
    for (var k = 0; k < i && k < rows.count; k++) {
      var it = rows.itemAt(k)
      y += (it ? it.height : fontSize) + lineGap
    }
    return y
  }
  readonly property real targetY: {
    var i = Math.max(0, active)
    var it = rows.itemAt(i)
    var h = it ? it.height : fontSize
    return height / 2 - offsetOf(i) - h / 2
  }

  Column {
    id: stack
    width: col.width
    spacing: col.lineGap
    y: col.targetY
    Behavior on y { SpringAnimation { spring: 2.2; damping: 0.32; epsilon: 0.25 } }

    Repeater {
      id: rows
      model: col.lines

      delegate: Item {
        id: row
        required property var modelData
        required property int index
        readonly property int distance: col.active < 0 ? index + 1 : Math.abs(index - col.active)
        readonly property bool current: index === col.active
        readonly property bool shown: distance <= col.visibleRadius
        width: stack.width
        height: label.implicitHeight
        // Pas de « visible: false » : Column ne réserve pas de place aux éléments
        // invisibles, ce qui fausserait le calcul du défilement. Opacité 0 = non dessiné.
        opacity: !shown ? 0 : (current ? 1 : Math.max(0.12, 0.62 - distance * 0.1))
        Behavior on opacity { NumberAnimation { duration: 380; easing.type: Easing.OutCubic } }

        Text {
          id: label
          width: parent.width
          textFormat: Text.PlainText
          wrapMode: Text.WordWrap
          horizontalAlignment: col.horizontalAlignment
          text: row.modelData.text === "" ? "♪" : row.modelData.text
          font.family: col.fontFamily
          font.pixelSize: col.fontSize
          font.weight: Font.Bold
          font.letterSpacing: -0.4
          color: col.textColor
          transformOrigin: col.horizontalAlignment === Text.AlignHCenter ? Item.Center : Item.Left
          scale: row.current ? 1 : 0.84
          Behavior on scale { SpringAnimation { spring: 3; damping: 0.4; epsilon: 0.002 } }

          layer.enabled: row.shown && (col.showShadow || !row.current)
          layer.effect: MultiEffect {
            blurEnabled: !row.current
            blurMax: 24
            blur: row.current ? 0 : Math.min(1, row.distance * col.blurPerLine)
            shadowEnabled: col.showShadow
            shadowColor: col.shadowColor
            shadowBlur: 0.9
            shadowVerticalOffset: 2
            shadowHorizontalOffset: 0
          }
        }
      }
    }
  }
}
