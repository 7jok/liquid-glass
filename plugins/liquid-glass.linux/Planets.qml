import QtQuick

// Horloge à planètes : trois orbites, chaque planète donne une aiguille
// (heures, minutes, secondes), l'heure est écrite dans le soleil.
Item {
  id: root
  property var s: null
  property date now: new Date()
  Timer { interval: 1000; repeat: true; running: true; onTriggered: root.now = new Date() }
  readonly property real r: Math.min(width, height) / 2
  readonly property var orbits: [
    [0.5, (root.now.getHours() % 12 + root.now.getMinutes() / 60) / 12, 0.1, root.s.tertiary],
    [0.72, (root.now.getMinutes() + root.now.getSeconds() / 60) / 60, 0.075, root.s.primary],
    [0.95, root.now.getSeconds() / 60, 0.05, root.s.colOnSurface]
  ]
  Repeater {
    model: root.orbits
    delegate: Item {
      id: orb
      required property var modelData
      anchors.fill: parent
      Rectangle {
        anchors.centerIn: parent
        width: root.r * 2 * orb.modelData[0]; height: width; radius: width / 2
        color: "transparent"; border.width: 1; border.color: root.s.alpha(root.s.colOnSurface, 0.22)
      }
      Rectangle {
        readonly property real a: orb.modelData[1] * 2 * Math.PI - Math.PI / 2
        readonly property real d: root.r * orb.modelData[0]
        width: root.r * orb.modelData[2] * 2; height: width; radius: width / 2
        x: root.width / 2 + d * Math.cos(a) - width / 2
        y: root.height / 2 + d * Math.sin(a) - height / 2
        color: orb.modelData[3]
        Behavior on x { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
        Behavior on y { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
      }
    }
  }
  Rectangle {
    anchors.centerIn: parent
    width: root.r * 0.74; height: width; radius: width / 2
    color: root.s.alpha(root.s.surface, 0.72)
    border.width: 1; border.color: root.s.alpha(root.s.primary, 0.6)
    Text {
      anchors.centerIn: parent
      text: Qt.formatTime(root.now, "HH:mm")
      font.family: root.s.sansFont; font.pixelSize: root.r * 0.2; font.weight: Font.Bold; color: root.s.colOnSurface
    }
  }
}
