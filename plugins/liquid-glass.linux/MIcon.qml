import QtQuick

// Icône Material Symbols Rounded (ligature : icon: "pause"), axes variables
// FILL/wght/opsz comme dans end4 (fill 0 → contour, 1 → plein).
Text {
  property string icon: ""
  property real size: 18
  property real fill: 0
  property int weight: 500
  text: icon
  font.family: "Material Symbols Rounded"
  font.pixelSize: Math.max(1, Math.round(size))
  font.variableAxes: ({ "FILL": fill, "wght": weight, "opsz": Math.max(20, Math.min(48, size)) })
  horizontalAlignment: Text.AlignHCenter
  verticalAlignment: Text.AlignVCenter
  Behavior on fill { NumberAnimation { duration: 200 } }
}
