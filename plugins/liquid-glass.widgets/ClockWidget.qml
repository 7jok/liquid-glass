import QtQuick

// Horloge analogique façon macOS : cadran clair, trotteuse orange.
Tile {
  id: w
  property date now: new Date()
  Timer { interval: 1000; repeat: true; running: w.visible; triggeredOnStart: true; onTriggered: w.now = new Date() }

  readonly property real face: Math.min(width, height) - 22
  readonly property bool night: now.getHours() < 7 || now.getHours() >= 19
  readonly property color faceColor: night ? "#1c1c1e" : "#ffffff"
  readonly property color ink: night ? "#ffffff" : "#1d1d1f"

  Rectangle {
    id: dial
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
