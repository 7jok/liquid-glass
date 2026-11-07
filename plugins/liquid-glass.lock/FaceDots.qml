import QtQuick

// Un point par caractère tapé, qui apparaît en rebondissant.
Row {
  id: d
  property int count: 0
  property real size: 10
  property real radius: size / 2
  property color color: "white"
  property int max: 18
  spacing: size * 0.45
  Repeater {
    model: Math.min(d.max, d.count)
    Rectangle {
      width: d.size; height: d.size; radius: d.radius; color: d.color
      scale: 0; Component.onCompleted: scale = 1
      Behavior on scale { NumberAnimation { duration: 200; easing.type: Easing.OutBack; easing.overshoot: 2 } }
    }
  }
}
