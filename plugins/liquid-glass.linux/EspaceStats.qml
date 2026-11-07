import QtQuick
import Quickshell
import Quickshell.Widgets

// Temps d'écran : par application aujourd'hui, sur sept jours, et heure par heure.
// Ne montre que ce que Linux.qml compte : nom d'application et durée, en local.
EspacePanel {
  id: p
  cardW: 800; cardH: 440

  function key(off) { var d = new Date(); d.setDate(d.getDate() - off); return Qt.formatDate(d, "yyyy-MM-dd") }
  function total(day) { var t = 0, a = day && day.apps ? day.apps : {}; for (var k in a) t += a[k]; return t }
  function dur(sec) {
    var m = Math.round(sec / 60)
    return m < 60 ? m + " min" : Math.floor(m / 60) + " h " + (m % 60 < 10 ? "0" : "") + (m % 60)
  }
  function label(id) {
    var e = DesktopEntries.heuristicLookup(id), n = id.split(".").pop()
    return e && e.name ? e.name : n.charAt(0).toUpperCase() + n.slice(1)
  }
  readonly property var today: s.usage[key(0)] || null
  readonly property int todaySec: total(today)
  readonly property var top: {
    var a = today && today.apps ? today.apps : {}, out = []
    for (var k in a) out.push([k, a[k]])
    out.sort(function(x, y) { return y[1] - x[1] })
    return out.slice(0, 6)
  }
  readonly property var week: {
    var out = [], names = ["D", "L", "M", "M", "J", "V", "S"]
    for (var i = 6; i >= 0; i--) {
      var d = new Date(); d.setDate(d.getDate() - i)
      out.push({ name: names[d.getDay()], sec: total(s.usage[key(i)]), hours: (s.usage[key(i)] || {}).hours || [], now: i === 0 })
    }
    return out
  }
  readonly property int weekMax: { var m = 1; for (var i = 0; i < week.length; i++) m = Math.max(m, week[i].sec); return m }
  readonly property int hourMax: {
    var m = 1
    for (var i = 0; i < week.length; i++) for (var h = 0; h < week[i].hours.length; h++) m = Math.max(m, week[i].hours[h])
    return m
  }

  Column {
    x: 24; y: 22; width: 340; spacing: 2
    Text { text: "Aujourd'hui"; font.family: p.font; font.pixelSize: 12; color: p.sub }
    Text { text: p.dur(p.todaySec); font.family: p.font; font.pixelSize: 40; font.weight: Font.Bold; color: p.ink }
    Item { width: 1; height: 12 }
    Text {
      visible: p.top.length === 0
      width: parent.width; wrapMode: Text.WordWrap
      text: "Le compteur vient de démarrer. Reviens dans quelques minutes."
      font.family: p.font; font.pixelSize: 12; color: p.sub
    }
    Column {
      width: parent.width; spacing: 11
      Repeater {
        model: p.top
        delegate: Item {
          id: row
          required property var modelData
          width: parent.width; height: 34
          IconImage {
            y: 3; width: 26; height: 26; asynchronous: true
            source: {
              var e = DesktopEntries.heuristicLookup(row.modelData[0])
              return Quickshell.iconPath(e && e.icon ? e.icon : row.modelData[0].toLowerCase(), "application-x-executable")
            }
          }
          Text {
            x: 36; width: 210; elide: Text.ElideRight
            text: p.label(row.modelData[0])
            font.family: p.font; font.pixelSize: 12; font.weight: Font.Bold; color: p.ink
          }
          Text {
            anchors.right: parent.right
            text: p.dur(row.modelData[1])
            font.family: p.font; font.pixelSize: 11; color: p.sub
          }
          Rectangle {
            x: 36; y: 21; width: parent.width - 36; height: 5; radius: 2.5; color: p.s.alpha(p.ink, 0.1)
            Rectangle {
              width: parent.width * row.modelData[1] / Math.max(1, p.top[0][1]); height: parent.height; radius: 2.5
              color: p.s.primary
            }
          }
        }
      }
    }
  }

  Rectangle { x: 388; y: 24; width: 1; height: parent.height - 48; color: p.s.alpha(p.ink, 0.1) }

  // Sept jours
  Item {
    x: 412; y: 22; width: parent.width - 436; height: 180
    Text { text: "Sept jours"; font.family: p.font; font.pixelSize: 12; color: p.sub }
    Row {
      y: 24; width: parent.width; height: 156; spacing: 14
      Repeater {
        model: p.week
        delegate: Item {
          id: bar
          required property var modelData
          width: (parent.width - 6 * 14) / 7; height: parent.height
          Rectangle {
            anchors.bottom: parent.bottom; anchors.bottomMargin: 20
            width: parent.width; radius: 5
            height: Math.max(3, (parent.height - 38) * bar.modelData.sec / p.weekMax)
            color: bar.modelData.now ? p.s.primary : p.s.alpha(p.s.primary, 0.35)
          }
          Text {
            anchors.bottom: parent.bottom; anchors.horizontalCenter: parent.horizontalCenter
            text: bar.modelData.name
            font.family: p.font; font.pixelSize: 10; font.weight: bar.modelData.now ? Font.Bold : Font.Normal
            color: bar.modelData.now ? p.ink : p.sub
          }
        }
      }
    }
  }

  // Heure par heure
  Item {
    x: 412; y: 222; width: parent.width - 436; height: 226
    Text { text: "Heure par heure"; font.family: p.font; font.pixelSize: 12; color: p.sub }
    Column {
      y: 24; spacing: 4
      Repeater {
        model: p.week
        delegate: Row {
          id: line
          required property var modelData
          spacing: 3
          Text {
            width: 14; anchors.verticalCenter: parent.verticalCenter
            text: line.modelData.name
            font.family: p.font; font.pixelSize: 9; color: p.sub
          }
          Repeater {
            model: 24
            delegate: Rectangle {
              required property int index
              readonly property real v: (line.modelData.hours[index] || 0) / p.hourMax
              width: 11; height: 17; radius: 3
              color: v > 0 ? p.s.alpha(p.s.primary, 0.25 + 0.75 * v) : p.s.alpha(p.ink, 0.06)
            }
          }
        }
      }
      Row {
        x: 17; spacing: 0
        Repeater {
          model: ["0 h", "6 h", "12 h", "18 h"]
          delegate: Text {
            required property string modelData
            width: 84; text: modelData
            font.family: p.font; font.pixelSize: 9; color: p.sub
          }
        }
      }
    }
  }
}
