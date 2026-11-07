import QtQuick
import Quickshell
import Quickshell.Io

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
  // Réglages → Barre des menus → « La semaine commence le lundi » (oui par défaut).
  property bool mondayFirst: true
  FileView {
    path: Quickshell.env("HOME") + "/.config/liquid-glass/config.json"
    watchChanges: true
    printErrors: false
    onFileChanged: reload()
    onLoaded: { try { var c = JSON.parse(text()); w.mondayFirst = !(c.menubar && c.menubar.week_monday === false) } catch (e) {} }
  }
  readonly property int offset: mondayFirst ? (new Date(year, month, 1).getDay() + 6) % 7 : new Date(year, month, 1).getDay()
  readonly property int days: new Date(year, month + 1, 0).getDate()
  readonly property int rows: Math.ceil((offset + days) / 7)
  // Format large (moyen / XL) : le jour en grand à gauche, le mois à droite.
  readonly property bool wideCal: width > height * 1.4
  readonly property var weekdays: ["DIMANCHE", "LUNDI", "MARDI", "MERCREDI", "JEUDI", "VENDREDI", "SAMEDI"]

  Column {
    visible: w.wideCal
    x: 14 * w.k; y: 12 * w.k
    width: w.width / 2 - 20 * w.k
    spacing: 0
    Text { text: w.weekdays[w.now.getDay()]; font.family: w.font; font.pixelSize: Math.round(11 * w.k); font.weight: Font.Bold; font.letterSpacing: 0.4; color: "#ff3b30" }
    Text { text: w.today; font.family: w.font; font.pixelSize: Math.round(46 * w.k); font.weight: Font.Light; color: w.fg }
    Text { text: "Aucun événement aujourd'hui"; width: parent.width; wrapMode: Text.WordWrap; font.family: w.font; font.pixelSize: Math.round(10 * w.k); font.weight: Font.Medium; color: w.dim }
  }

  Column {
    anchors.fill: parent
    anchors.margins: 12 * w.k
    anchors.topMargin: 11 * w.k
    anchors.leftMargin: w.wideCal ? w.width / 2 : 12 * w.k
    spacing: 3 * w.k

    Text {
      text: w.months[w.month]
      font.family: w.font
      font.pixelSize: Math.round(11 * w.k)
      font.weight: Font.Bold
      font.letterSpacing: 0.4
      color: w.wideCal ? w.dim : "#ff3b30"
    }

    Grid {
      id: grid
      columns: 7
      width: parent.width
      readonly property real cell: width / 7
      readonly property real cellH: (w.height - (12 + 11 + 17 + 3) * w.k) / (w.rows + 1)

      Repeater {
        model: w.mondayFirst ? ["L", "M", "M", "J", "V", "S", "D"] : ["D", "L", "M", "M", "J", "V", "S"]
        Text {
          required property string modelData
          required property int index
          width: grid.cell; height: grid.cellH
          horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
          text: modelData
          font.family: w.font; font.pixelSize: Math.round(9 * w.k); font.weight: Font.DemiBold
          color: w.dim
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
            font.family: w.font; font.pixelSize: Math.round(10 * w.k)
            font.weight: parent.isToday ? Font.Bold : Font.Medium
            color: parent.isToday ? "#ffffff" : ((w.mondayFirst ? (parent.index % 7) >= 5 : ((parent.index % 7) === 0 || (parent.index % 7) === 6)) ? w.dim : w.fg)
          }
        }
      }
    }
  }
}
