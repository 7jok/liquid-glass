import QtQuick
import qs.Commons

// Météo façon macOS : ciel en dégradé selon le temps et l'heure, ville, température,
// condition et min/max ; en large, les prochaines heures à droite.
// Données Open-Meteo (voir Widgets.qml).
Tile {
  id: w
  property bool wide: false
  readonly property real leftW: wide ? height : width
  readonly property var wx: svc ? svc.weather : null
  readonly property int code: wx ? wx.code : -1
  readonly property bool day: wx ? wx.isDay : true

  // [libellé, glyphe Nerd Font (Material Design), famille de ciel]
  function describe(c, dayFlag) {
    var day = dayFlag === undefined ? w.day : dayFlag
    if (c === 0) return ["Dégagé", day ? 0xF0599 : 0xF0594, "clear"]
    if (c === 1 || c === 2) return [c === 1 ? "Plutôt dégagé" : "Partiellement nuageux", day ? 0xF0595 : 0xF0F31, "partly"]
    if (c === 3) return ["Couvert", 0xF0590, "cloudy"]
    if (c === 45 || c === 48) return ["Brouillard", 0xF0591, "cloudy"]
    if (c >= 51 && c <= 57) return ["Bruine", 0xF0597, "rain"]
    if (c >= 61 && c <= 67) return [c >= 65 ? "Forte pluie" : "Pluie", c >= 65 ? 0xF0596 : 0xF0597, "rain"]
    if (c >= 71 && c <= 77) return ["Neige", 0xF0598, "snow"]
    if (c >= 80 && c <= 82) return ["Averses", 0xF0596, "rain"]
    if (c === 85 || c === 86) return ["Averses de neige", 0xF0598, "snow"]
    if (c >= 95) return ["Orage", 0xF0593, "rain"]
    return ["—", 0xF0590, "cloudy"]
  }
  readonly property var d: describe(code)
  readonly property var sky: {
    var k = d[2]
    if (!day) return k === "clear" || k === "partly" ? ["#0b1636", "#2a3a6e"] : ["#1b2330", "#3a4658"]
    if (k === "clear") return ["#2f7fd8", "#7dbdf2"]
    if (k === "partly") return ["#4a86c5", "#97bfe0"]
    if (k === "snow") return ["#7f95ad", "#c4d0dc"]
    if (k === "rain") return ["#45556a", "#76869a"]
    return ["#5d6e80", "#93a3b3"]
  }

  tint: "transparent"
  Rectangle {
    anchors.fill: parent
    radius: w.radius
    gradient: Gradient {
      GradientStop { position: 0; color: w.sky[0] }
      GradientStop { position: 1; color: w.sky[1] }
    }
    border.width: 1
    border.color: Qt.rgba(1, 1, 1, 0.18)
  }

  Column {
    anchors { left: parent.left; top: parent.top; margins: 13 * w.k }
    width: w.leftW - 26 * w.k
    spacing: 0
    Row {
      spacing: 3
      Text {
        text: w.wx ? w.wx.city : (svc ? svc.city : "")
        width: Math.min(implicitWidth, w.leftW - 40 * w.k)
        elide: Text.ElideRight
        font.family: w.font; font.pixelSize: Math.round(13 * w.k); font.weight: Font.DemiBold
        color: "white"
      }
      Text { text: ""; font.family: Style.font.family; font.pixelSize: Math.round(8 * w.k); color: "white"; anchors.verticalCenter: parent.verticalCenter; visible: !(svc && svc.cfg.widgets && svc.cfg.widgets.weather_city) }
    }
    Text {
      text: w.wx ? w.wx.temp + "°" : "--°"
      font.family: w.font; font.pixelSize: Math.round(40 * w.k); font.weight: Font.Light
      color: "white"
    }
  }

  Column {
    anchors { left: parent.left; bottom: parent.bottom; margins: 13 * w.k }
    width: w.leftW - 26 * w.k
    spacing: 1
    Text {
      text: w.wx ? String.fromCodePoint(w.d[1]) : ""
      font.family: Style.font.family; font.pixelSize: Math.round(17 * w.k)
      color: "white"
    }
    Text {
      text: svc && svc.weatherError !== "" && !w.wx ? svc.weatherError : w.d[0]
      width: parent.width; elide: Text.ElideRight
      font.family: w.font; font.pixelSize: Math.round(11 * w.k); font.weight: Font.DemiBold
      color: "white"
    }
    Text {
      text: w.wx ? "Max. " + w.wx.max + "°  Min. " + w.wx.min + "°" : ""
      font.family: w.font; font.pixelSize: Math.round(11 * w.k); font.weight: Font.Medium
      color: Qt.rgba(1, 1, 1, 0.85)
    }
  }

  // Prévisions heure par heure (format large).
  Rectangle {
    visible: w.wide
    x: w.leftW - 1; y: 16 * w.k
    width: 1; height: w.height - 32 * w.k
    color: Qt.rgba(1, 1, 1, 0.22)
  }
  Row {
    visible: w.wide && hours.count > 0
    anchors.left: parent.left; anchors.leftMargin: w.leftW + 8 * w.k
    anchors.right: parent.right; anchors.rightMargin: 10 * w.k
    anchors.verticalCenter: parent.verticalCenter
    Repeater {
      id: hours
      model: w.wx && w.wx.hourly ? w.wx.hourly : []
      delegate: Column {
        required property var modelData
        required property int index
        width: (w.width - w.leftW - 18 * w.k) / Math.max(1, hours.count)
        spacing: 6 * w.k
        Text { anchors.horizontalCenter: parent.horizontalCenter; textFormat: Text.PlainText; text: modelData.h < 0 ? "Maint." : modelData.h + " h"; font.family: w.font; font.pixelSize: Math.round(11 * w.k); font.weight: Font.DemiBold; color: Qt.rgba(1, 1, 1, 0.85) }
        Text { anchors.horizontalCenter: parent.horizontalCenter; textFormat: Text.PlainText; text: String.fromCodePoint(w.describe(modelData.code, modelData.isDay)[1]); font.family: Style.font.family; font.pixelSize: Math.round(18 * w.k); color: "white" }
        Text { anchors.horizontalCenter: parent.horizontalCenter; textFormat: Text.PlainText; text: modelData.temp + "°"; font.family: w.font; font.pixelSize: Math.round(14 * w.k); font.weight: Font.DemiBold; color: "white" }
      }
    }
  }

  MouseArea {
    anchors.fill: parent
    cursorShape: Qt.PointingHandCursor
    onClicked: if (svc) svc.refreshWeather()
  }
}
