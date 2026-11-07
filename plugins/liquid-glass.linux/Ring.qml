import QtQuick
import QtQuick.Shapes

// Anneau de progression M3 (piste pâle + arc arrondi), 0 ≤ value ≤ 1.
Shape {
  id: ring
  property real value: 0
  property real thickness: 2.5
  property color color: "white"
  property color track: Qt.rgba(1, 1, 1, 0.15)
  preferredRendererType: Shape.CurveRenderer
  readonly property real r: Math.min(width, height) / 2 - thickness / 2
  property real shown: Math.max(0, Math.min(1, value))
  Behavior on shown { NumberAnimation { duration: 450; easing.type: Easing.OutCubic } }
  ShapePath {
    fillColor: "transparent"
    strokeColor: ring.track
    strokeWidth: ring.thickness
    capStyle: ShapePath.RoundCap
    PathAngleArc { centerX: ring.width / 2; centerY: ring.height / 2; radiusX: ring.r; radiusY: ring.r; startAngle: 0; sweepAngle: 360 }
  }
  ShapePath {
    fillColor: "transparent"
    strokeColor: ring.color
    strokeWidth: ring.thickness
    capStyle: ShapePath.RoundCap
    PathAngleArc { centerX: ring.width / 2; centerY: ring.height / 2; radiusX: ring.r; radiusY: ring.r; startAngle: -90; sweepAngle: 360 * ring.shown }
  }
}
