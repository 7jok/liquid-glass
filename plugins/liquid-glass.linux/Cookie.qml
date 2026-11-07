import QtQuick
import QtQuick.Shapes

// Forme Material 3 Expressive : cercle festonné (« cookie », « fleur », « soleil »).
// lobes = nombre de festons, depth = profondeur relative au rayon, spin = rotation (rad).
Shape {
  id: sh
  property int lobes: 9
  property real depth: 0.07
  property real spin: 0
  property color color: "white"
  property color strokeColor: "transparent"
  property real strokeWidth: 0
  preferredRendererType: Shape.CurveRenderer
  readonly property var points: {
    var pts = [], n = Math.max(64, lobes * 18)
    var r = Math.min(width, height) / 2 - strokeWidth / 2, cx = width / 2, cy = height / 2
    for (var i = 0; i <= n; i++) {
      var a = i / n * Math.PI * 2
      var rr = r * (1 - depth) + r * depth * Math.cos(lobes * a + sh.spin)
      pts.push(Qt.point(cx + rr * Math.cos(a), cy + rr * Math.sin(a)))
    }
    return pts
  }
  ShapePath {
    fillColor: sh.color
    strokeColor: sh.strokeColor
    strokeWidth: sh.strokeWidth > 0 ? sh.strokeWidth : -1
    PathPolyline { path: sh.points }
  }
}
