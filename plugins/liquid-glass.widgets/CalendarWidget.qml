import QtQuick

// Calendrier du mois façon macOS : mois en rouge, semaine du lundi, aujourd'hui cerclé.
// Clic : ouvre le calendrier d'Omarchy s'il existe, sinon rien.
Tile {
  id: w
  property date now: new Date()
  // Recalcule à minuit (et au réveil de veille, via la minute qui change).
  Timer { interval: 60000; repeat: true; running: w.visible; onTriggered: w.now = new Date() }

  readonly property var months: ["JANVIER", "FÉVRIER", "MARS", "AVRIL", "MAI", "JUIN", "JUILLET", "AOÛT", "SEPTEMBRE", "OCTOBRE", "NOVEMBRE", "DÉCEMBRE"]
  readonly property int year: now.getFullYear()
  readonly property int month: now.getMonth()
  readonly property int today: now.getDate()
  readonly property int offset: (new Date(year, month, 1).getDay() + 6) % 7   // lundi = 0
  readonly property int days: new Date(year, month + 1, 0).getDate()
  readonly property int rows: Math.ceil((offset + days) / 7)

  Column {
    anchors.fill: parent
    anchors.margins: 12
    anchors.topMargin: 11
    spacing: 3

    Text {
      text: w.months[w.month]
      font.family: w.font
      font.pixelSize: 11
      font.weight: Font.Bold
      font.letterSpacing: 0.4
      color: "#ff3b30"
    }

    Grid {
      id: grid
      columns: 7
      width: parent.width
      readonly property real cell: width / 7
      readonly property real cellH: (w.height - 12 - 11 - 17 - 3) / (w.rows + 1)

      Repeater {
        model: ["L", "M", "M", "J", "V", "S", "D"]
        Text {
          required property string modelData
          required property int index
          width: grid.cell; height: grid.cellH
          horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
          text: modelData
          font.family: w.font; font.pixelSize: 9; font.weight: Font.DemiBold
          color: index >= 5 ? Qt.darker(w.dim, 1.0) : w.dim
          opacity: 0.9
        }
      }
      Repeater {
        model: w.rows * 7
        Item {
          required property int index
          readonly property int day: index - w.offset + 1
          readonly property bool valid: day >= 1 && day <= w.days
          readonly property bool isToday: day === w.today
          width: grid.cell; height: grid.cellH
          Rectangle {
            visible: parent.valid && parent.isToday
            anchors.centerIn: parent
            width: Math.min(parent.width, parent.height) + 1; height: width; radius: width / 2
            color: "#ff3b30"
          }
          Text {
            visible: parent.valid
            anchors.centerIn: parent
            text: parent.day
            font.family: w.font; font.pixelSize: 10
            font.weight: parent.isToday ? Font.Bold : Font.Medium
            color: parent.isToday ? "#ffffff" : ((parent.index % 7) >= 5 ? w.dim : w.fg)
          }
        }
      }
    }
  }
}
