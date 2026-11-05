import QtQuick
import QtQuick.Shapes
import Quickshell.Services.UPower
import qs.Commons

// Batterie façon macOS : anneau de charge (vert, rouge sous 20 %), éclair en charge.
Tile {
  id: w
  readonly property var dev: UPower.displayDevice
  readonly property bool present: !!(dev && dev.isPresent)
  readonly property real frac: present ? Math.max(0, Math.min(1, dev.percentage)) : 0
  readonly property bool charging: present && !UPower.onBattery
  readonly property color ring: frac <= 0.2 && !charging ? "#ff3b30" : "#30d158"

  Item {
    id: gauge
    width: w.width * 0.56; height: width
    anchors.horizontalCenter: parent.horizontalCenter
    anchors.top: parent.top
    anchors.topMargin: w.height * 0.12

    Shape {
      anchors.fill: parent
      preferredRendererType: Shape.CurveRenderer
      ShapePath {
        strokeColor: Qt.rgba(w.ring.r, w.ring.g, w.ring.b, 0.22)
        strokeWidth: gauge.width * 0.09
        fillColor: "transparent"
        capStyle: ShapePath.RoundCap
        PathAngleArc { centerX: gauge.width / 2; centerY: gauge.height / 2; radiusX: gauge.width / 2 - gauge.width * 0.05; radiusY: radiusX; startAngle: -90; sweepAngle: 360 }
      }
      ShapePath {
        strokeColor: w.ring
        strokeWidth: gauge.width * 0.09
        fillColor: "transparent"
        capStyle: ShapePath.RoundCap
        PathAngleArc { centerX: gauge.width / 2; centerY: gauge.height / 2; radiusX: gauge.width / 2 - gauge.width * 0.05; radiusY: radiusX; startAngle: -90; sweepAngle: 360 * w.frac }
      }
    }
    Text {
      anchors.centerIn: parent
      text: ""   // ordinateur portable
      font.family: Style.font.family
      font.pixelSize: gauge.width * 0.32
      color: w.fg
    }
    Rectangle {
      visible: w.charging
      width: gauge.width * 0.3; height: width; radius: width / 2
      anchors.right: parent.right; anchors.top: parent.top
      anchors.rightMargin: -width * 0.1; anchors.topMargin: -width * 0.1
      color: "#30d158"
      Text { anchors.centerIn: parent; text: ""; font.family: Style.font.family; font.pixelSize: parent.width * 0.55; color: "white" }
    }
  }

  Column {
    anchors.horizontalCenter: parent.horizontalCenter
    anchors.bottom: parent.bottom
    anchors.bottomMargin: w.height * 0.1
    Text {
      anchors.horizontalCenter: parent.horizontalCenter
      text: Math.round(w.frac * 100) + " %"
      font.family: w.font; font.pixelSize: 18; font.weight: Font.DemiBold
      color: w.fg
    }
    Text {
      anchors.horizontalCenter: parent.horizontalCenter
      text: w.charging ? (w.frac >= 0.99 ? "Chargé" : "En charge") : "Sur batterie"
      font.family: w.font; font.pixelSize: 10; font.weight: Font.Medium
      color: w.dim
    }
  }
}
