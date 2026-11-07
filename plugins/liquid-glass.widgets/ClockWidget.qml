import QtQuick
import "T.js" as T

// Horloge façon macOS. Numérique (défaut) : grands chiffres en verre dégradé,
// jour et date au-dessus. Analogique : cadran clair, trotteuse orange.
Tile {
  id: w
  property bool digital: true
  property date now: new Date()
  Timer { interval: 1000; repeat: true; running: w.visible; triggeredOnStart: true; onTriggered: w.now = new Date() }

  readonly property real face: Math.min(width, height) - 22
  readonly property bool night: now.getHours() < 7 || now.getHours() >= 19
  readonly property color faceColor: night ? "#1c1c1e" : "#ffffff"
  readonly property color ink: night ? "#ffffff" : "#1d1d1f"

  // ---- Numérique
  Item {
    anchors.fill: parent
    visible: w.digital
    Text {
      x: 14 * w.k; y: 12 * w.k
      textFormat: Text.PlainText
      text: Qt.locale(T.loc).toString(w.now, w.width > w.height * 1.4 ? "dddd d MMMM" : "ddd d").toUpperCase().replace(".", "")
      font.family: w.font; font.pixelSize: Math.round(12 * w.k); font.weight: Font.Bold; font.letterSpacing: 0.6
      color: "#ff453a"
    }
    // Chiffres en texte vectoriel (net à toutes les échelles, y compris 1,5×) :
    // la taille s'ajuste toute seule à la tuile (Text.Fit), donc rien n'est rogné.
    // Un second calque décalé fait l'ombre douce ; l'éclairage « verre » vient
    // d'un léger dégradé d'opacité entre les deux.
    Item {
      id: digits
      anchors.fill: parent
      anchors.leftMargin: 12 * w.k; anchors.rightMargin: 12 * w.k
      anchors.topMargin: 30 * w.k; anchors.bottomMargin: 8 * w.k
      Text {
        id: dShadow
        anchors.fill: parent
        anchors.topMargin: 2
        textFormat: Text.PlainText
        text: dText.text
        horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
        fontSizeMode: Text.Fit; minimumPixelSize: 10
        font: dText.font
        color: Qt.rgba(0, 0, 0, 0.16)
      }
      Text {
        id: dText
        anchors.fill: parent
        textFormat: Text.PlainText
        text: Qt.formatTime(w.now, "H:mm")
        horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
        fontSizeMode: Text.Fit; minimumPixelSize: 10
        font.family: w.font
        font.pixelSize: 220
        font.weight: Font.DemiBold
        font.features: { "tnum": 1 }
        color: w.fg
        opacity: 0.94
      }
    }
  }

  // ---- Analogique
  Rectangle {
    id: dial
    visible: !w.digital
    anchors.centerIn: parent
    width: w.face; height: w.face; radius: width / 2
    color: w.faceColor
    border.width: 1
    border.color: Qt.rgba(0, 0, 0, 0.08)

    // Chiffres
    Repeater {
      model: 12
      Text {
        required property int index
        readonly property real a: (index + 1) * Math.PI / 6
        readonly property real r: dial.width * 0.38
        x: dial.width / 2 + Math.sin(a) * r - width / 2
        y: dial.height / 2 - Math.cos(a) * r - height / 2
        text: index + 1
        font.family: w.font
        font.pixelSize: dial.width * 0.105
        font.weight: Font.Medium
        color: w.ink
      }
    }

    // Aiguilles : chaque aiguille tourne avec un Item plein cadran (pivot au centre).
    Item {
      anchors.fill: parent
      rotation: (w.now.getHours() % 12 + w.now.getMinutes() / 60) * 30
      Rectangle { width: dial.width * 0.045; height: dial.width * 0.27; radius: width / 2; color: w.ink; x: parent.width / 2 - width / 2; y: parent.height / 2 - height + width / 2 }
    }
    Item {
      anchors.fill: parent
      rotation: (w.now.getMinutes() + w.now.getSeconds() / 60) * 6
      Rectangle { width: dial.width * 0.035; height: dial.width * 0.4; radius: width / 2; color: w.ink; x: parent.width / 2 - width / 2; y: parent.height / 2 - height + width / 2 }
    }
    Item {
      anchors.fill: parent
      rotation: w.now.getSeconds() * 6
      Behavior on rotation { RotationAnimation { duration: 180; direction: RotationAnimation.Clockwise; easing.type: Easing.OutBack } }
      Rectangle { width: 1.5; height: dial.width * 0.52; color: "#ff9500"; x: parent.width / 2 - width / 2; y: parent.height / 2 - dial.width * 0.42 }
    }
    Rectangle { anchors.centerIn: parent; width: dial.width * 0.06; height: width; radius: width / 2; color: "#ff9500"; border.width: 1.5; border.color: w.ink }
  }
}
