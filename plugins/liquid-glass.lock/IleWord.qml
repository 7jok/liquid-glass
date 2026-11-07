import QtQuick

// Texte de l'horloge du style Île : large, et les A et les M sans barre, en chevrons.
Row {
  id: w
  property string text: ""
  property int px: 20
  property color color: "#c9c2cc"
  property string family: "Michroma"
  spacing: 0
  Repeater {
    model: w.text.split("")
    Item {
      id: cell
      required property string modelData
      readonly property bool peak: modelData === "A" || modelData === "M"
      readonly property real one: w.px * 0.92
      width: peak ? (modelData === "M" ? one * 1.72 : one) + w.px * 0.1 : txt.implicitWidth
      height: txt.implicitHeight
      Text {
        id: txt
        visible: !cell.peak
        text: cell.modelData
        color: w.color
        font.family: w.family
        font.pixelSize: w.px
        textFormat: Text.PlainText
      }
      Canvas {
        visible: cell.peak
        anchors.fill: parent
        property color ink: w.color
        onInkChanged: requestPaint()
        onWidthChanged: requestPaint()
        onPaint: {
          var c = getContext("2d"), s = w.px * 0.15, top = cell.height * 0.2, low = cell.height * 0.8, o = cell.one
          c.reset()
          c.strokeStyle = ink
          c.lineWidth = s
          c.lineJoin = "round"
          c.lineCap = "round"
          c.beginPath()
          c.moveTo(s, low)
          c.lineTo(o / 2, top)
          c.lineTo(o - s, low)
          if (cell.modelData === "M") {
            c.lineTo(o * 1.36 - s / 2, top)
            c.lineTo(o * 1.72 - s, low)
          }
          c.stroke()
        }
      }
    }
  }
}
