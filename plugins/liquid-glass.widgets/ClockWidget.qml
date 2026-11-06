import QtQuick
import QtQuick.Effects

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
      x: 14; y: 12
      textFormat: Text.PlainText
      text: Qt.locale("fr_FR").toString(w.now, "ddd d").toUpperCase().replace(".", "")
      font.family: w.font; font.pixelSize: 12; font.weight: Font.Bold; font.letterSpacing: 0.6
      color: "#ff453a"
    }
    Item {
      id: digits
      anchors.centerIn: parent
      anchors.verticalCenterOffset: 8
      width: dText.implicitWidth; height: dText.implicitHeight
      readonly property real pad: 12
      Text {
        id: dText
        textFormat: Text.PlainText
        text: Qt.formatTime(w.now, "H:mm")
        font.family: w.font
        // Taille qui tient dans la largeur de la tuile (mesurée à 100 px).
        font.pixelSize: Math.max(10, Math.round(Math.min(w.height * 0.42, 100 * (w.width - 30) / Math.max(1, dMeasure.implicitWidth))))
        font.weight: Font.DemiBold
        font.letterSpacing: -2
        font.features: { "tnum": 1 }
        visible: false
      }
      Text {
        id: dMeasure
        visible: false
        textFormat: Text.PlainText
        text: dText.text
        font.family: w.font; font.pixelSize: 100; font.weight: Font.DemiBold
        font.letterSpacing: -2; font.features: { "tnum": 1 }
      }
      Item {
        id: dMask
        x: -digits.pad; y: -digits.pad
        width: digits.width + 2 * digits.pad; height: digits.height + 2 * digits.pad
        visible: false; layer.enabled: true
        Text { x: digits.pad; y: digits.pad; textFormat: Text.PlainText; text: dText.text; font: dText.font; color: "black" }
      }
      Rectangle {
        id: dFill
        anchors.fill: dMask
        visible: false; layer.enabled: true
        gradient: Gradient {
          GradientStop { position: 0.15; color: w.fg }
          GradientStop { position: 0.95; color: Qt.rgba(w.fg.r, w.fg.g, w.fg.b, 0.55) }
        }
      }
      MultiEffect {
        anchors.fill: dMask
        source: dFill
        maskEnabled: true; maskSource: dMask; maskThresholdMin: 0.5; maskSpreadAtMin: 1.0
        shadowEnabled: true; shadowBlur: 0.6; shadowOpacity: 0.18; shadowVerticalOffset: 2
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
