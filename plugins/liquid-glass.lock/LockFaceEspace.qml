import QtQuick
import "T.js" as T

// Verrouillage des styles Espace et Cosmos : ciel noir, étoiles qui scintillent, l'heure
// fine au centre d'orbites où tournent des planètes, la date espacée, un champ de verre.
// Couleurs : espace_tone (bleu, mars, nébuleuse, aurore, soleil) ; Cosmos en sarcelle.
Item {
  id: f
  property var lock: null
  readonly property var lk: lock
  readonly property real k: Math.min(width / 1280, height / 720)
  readonly property bool cosmos: lk && lk.style === "cosmos"
  readonly property string tone: cosmos ? "cosmos" : (lk ? lk.tone("espace_tone", "bleu") : "bleu")
  readonly property var tones: ({ bleu: "#8fc7ff", mars: "#ff8a6b", nebuleuse: "#c58bff", aurore: "#6ff0b4", soleil: "#ffc04d", cosmos: "#9fdcf5" })
  readonly property color acc: tones[tone] || tones.bleu
  readonly property color ink: "#eef3fa"
  readonly property int typed: lk ? lk.passwordText.length : 0
  readonly property rect fieldBox: {
    var c = field.mapToItem(f, 0, 0)
    return Qt.rect(c.x, c.y, field.width, field.height)
  }

  Rectangle { anchors.fill: parent; color: "#03050a" }
  FaceWall { anchors.fill: parent; lk: f.lk; brightness: -0.55; blur: 0.3; opacity: 0.7 }

  // Étoiles
  Canvas {
    id: sky
    anchors.fill: parent
    property real ph: 0
    property var stars: []
    Component.onCompleted: {
      var a = []
      for (var i = 0; i < 260; i++) a.push([Math.random(), Math.random(), Math.random() * 1.4 + 0.3, Math.random() * 6.28])
      stars = a
    }
    NumberAnimation on ph { from: 0; to: 6.283; duration: 6000; loops: Animation.Infinite }
    onPhChanged: requestPaint()
    onPaint: {
      var c = getContext("2d"); c.reset()
      for (var i = 0; i < stars.length; i++) {
        var s = stars[i]
        c.globalAlpha = 0.35 + 0.65 * (0.5 + 0.5 * Math.sin(ph + s[3]))
        c.fillStyle = i % 9 === 0 ? f.acc : "#ffffff"
        c.beginPath(); c.arc(s[0] * width, s[1] * height, s[2], 0, 6.283); c.fill()
      }
    }
  }

  LockData { id: sys; running: f.visible }
  WeatherFx { anchors.fill: parent; code: sys.weather ? Number(sys.weather.code) : -1; tint: f.acc }
  Row {
    anchors.left: parent.left; anchors.bottom: parent.bottom; anchors.margins: 22 * f.k
    spacing: 8 * f.k
    visible: !!sys.weather
    Text { anchors.verticalCenter: parent.verticalCenter; text: sys.wIcon; font.family: "Material Symbols Rounded"; font.pixelSize: 22 * f.k; color: f.acc }
    Text { anchors.verticalCenter: parent.verticalCenter; text: sys.weather ? sys.weather.temp + "°  " + T.t(sys.wDesc) : ""; font.family: "Inter"; font.pixelSize: 13 * f.k; font.letterSpacing: 2; color: f.ink }
  }
  // Orbites et planètes autour de l'heure
  Item {
    id: orbits
    anchors.horizontalCenter: parent.horizontalCenter
    y: f.height * 0.33 - height / 2
    width: 560 * f.k; height: 560 * f.k
    Repeater {
      model: [[1.0, 26000, 9, 0.0], [0.74, 15000, 6, 2.1], [0.5, 9000, 4.5, 4.0]]
      Item {
        id: orb
        required property var modelData
        anchors.centerIn: parent
        width: orbits.width * modelData[0]; height: width * 0.38
        Rectangle { anchors.fill: parent; radius: height / 2; color: "transparent"; border.color: Qt.rgba(1, 1, 1, 0.12); border.width: 1 }
        property real a: modelData[3]
        NumberAnimation on a { from: orb.modelData[3]; to: orb.modelData[3] + 6.283; duration: orb.modelData[1]; loops: Animation.Infinite }
        Rectangle {
          width: orb.modelData[2] * 2 * f.k; height: width; radius: width / 2
          x: orb.width / 2 + Math.cos(orb.a) * orb.width / 2 - width / 2
          y: orb.height / 2 + Math.sin(orb.a) * orb.height / 2 - height / 2
          color: orb.modelData[0] === 1.0 ? f.acc : (orb.modelData[0] > 0.6 ? "#ffd27a" : "#d6e3f2")
          z: Math.sin(orb.a) > 0 ? 2 : 0
        }
      }
    }
  }
  Column {
    anchors.horizontalCenter: parent.horizontalCenter
    y: f.height * 0.33 - 70 * f.k
    spacing: 4 * f.k
    Text {
      anchors.horizontalCenter: parent.horizontalCenter
      text: f.lk ? f.lk.hh + ":" + f.lk.mm : ""
      font.family: "Inter"; font.pixelSize: 110 * f.k; font.weight: Font.Thin; color: f.ink
    }
    Text {
      anchors.horizontalCenter: parent.horizontalCenter
      text: f.lk ? f.lk.now.toLocaleDateString(Qt.locale(T.loc), "dddd d MMMM").toUpperCase() : ""
      font.family: "Inter"; font.pixelSize: 12 * f.k; font.letterSpacing: 6; color: f.acc
    }
  }

  Column {
    anchors.horizontalCenter: parent.horizontalCenter
    y: f.height * 0.72
    spacing: 12 * f.k
    Text { anchors.horizontalCenter: parent.horizontalCenter; text: f.lk ? f.lk.userName : ""; font.family: "Inter"; font.pixelSize: 14 * f.k; font.letterSpacing: 4; color: f.ink; opacity: 0.8 }
    Rectangle {
      id: field
      anchors.horizontalCenter: parent.horizontalCenter
      anchors.horizontalCenterOffset: f.lk ? f.lk.shakeX : 0
      width: 300 * f.k; height: 40 * f.k; radius: height / 2
      color: Qt.rgba(1, 1, 1, 0.07)
      border.color: f.lk && f.lk.errorState ? "#ff7b86" : Qt.rgba(f.acc.r, f.acc.g, f.acc.b, 0.45); border.width: 1
      Text {
        anchors.centerIn: parent; visible: f.typed === 0
        text: f.lk && f.lk.authenticatingPassword ? T.t("Vérification…") : f.lk && f.lk.errorState ? f.lk.failureMessage : T.t("Mot de passe")
        font.family: "Inter"; font.pixelSize: 12 * f.k; font.letterSpacing: 2; color: f.lk && f.lk.errorState ? "#ff7b86" : Qt.rgba(1, 1, 1, 0.5)
      }
      FaceDots { anchors.centerIn: parent; count: f.typed; size: 7 * f.k; color: f.acc }
    }
  }
  Text {
    anchors.right: parent.right; anchors.bottom: parent.bottom; anchors.margins: 20 * f.k
    text: "power_settings_new"; font.family: "Material Symbols Rounded"; font.pixelSize: 22 * f.k; color: f.acc
    MouseArea { anchors.fill: parent; anchors.margins: -8; cursorShape: Qt.PointingHandCursor; onClicked: if (f.lk) { f.lk.powerOpen = !f.lk.powerOpen; f.lk.forcePasswordFocus() } }
  }
}
