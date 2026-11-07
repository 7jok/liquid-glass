import QtQuick
import QtQuick.Shapes

// Icônes des cinq bulles de Spotlight, dessinées au trait comme sur la vidéo de
// référence : creuses, trait fin arrondi, sur une grille de 24 × 24.
//   apps : un « A » fin · files : dossier · actions : trois calques empilés
//   clipboard : presse-papiers avec deux lignes · emoji : visage souriant
Item {
  id: ic
  property string kind: "apps"
  property color color: "#1d1d1f"
  property real stroke: 1.7
  implicitWidth: 22; implicitHeight: 22
  readonly property real u: width / 24

  readonly property var paths: ({
    apps: ["M 5.2 20 L 12 3.8 L 18.8 20", "M 7.6 14.6 L 16.4 14.6"],
    files: ["M 3.5 7.2 Q 3.5 5 5.7 5 L 9.3 5 Q 10.3 5 11 5.8 L 12.1 7.1 L 18.3 7.1 Q 20.5 7.1 20.5 9.3 L 20.5 16.9 Q 20.5 19.1 18.3 19.1 L 5.7 19.1 Q 3.5 19.1 3.5 16.9 Z"],
    actions: ["M 12 3.6 L 20.6 8.2 L 12 12.8 L 3.4 8.2 Z", "M 3.4 12.1 L 12 16.7 L 20.6 12.1", "M 3.4 16 L 12 20.6 L 20.6 16"],
    clipboard: ["M 8.6 5.2 L 7 5.2 Q 5 5.2 5 7.2 L 5 19 Q 5 21 7 21 L 17 21 Q 19 21 19 19 L 19 7.2 Q 19 5.2 17 5.2 L 15.4 5.2",
                "M 9.6 3.2 L 14.4 3.2 Q 15.4 3.2 15.4 4.2 L 15.4 6.2 Q 15.4 7.2 14.4 7.2 L 9.6 7.2 Q 8.6 7.2 8.6 6.2 L 8.6 4.2 Q 8.6 3.2 9.6 3.2 Z",
                "M 8.8 12 L 15.2 12", "M 8.8 15.8 L 15.2 15.8"],
    emoji: ["M 12 3.2 A 8.8 8.8 0 1 1 11.99 3.2 Z", "M 8.2 13.9 Q 12 17.9 15.8 13.9"]
  })

  component Stroke: ShapePath {
    property int n: 0
    strokeColor: ic.color
    strokeWidth: ic.stroke * ic.u
    fillColor: "transparent"
    capStyle: ShapePath.RoundCap
    joinStyle: ShapePath.RoundJoin
    scale: Qt.size(ic.u, ic.u)
    PathSvg { path: (ic.paths[ic.kind] || [])[n] || "M 0 0" }
  }
  Shape {
    anchors.fill: parent
    preferredRendererType: Shape.CurveRenderer
    Stroke { n: 0 }
    Stroke { n: 1; strokeWidth: (ic.paths[ic.kind] || []).length > 1 ? ic.stroke * ic.u : 0 }
    Stroke { n: 2; strokeWidth: (ic.paths[ic.kind] || []).length > 2 ? ic.stroke * ic.u : 0 }
    Stroke { n: 3; strokeWidth: (ic.paths[ic.kind] || []).length > 3 ? ic.stroke * ic.u : 0 }
  }

  // Yeux du visage souriant (points pleins).
  Repeater {
    model: ic.kind === "emoji" ? [9, 15] : []
    Rectangle {
      required property real modelData
      width: 1.9 * ic.u; height: 2.3 * ic.u; radius: width / 2
      color: ic.color
      x: modelData * ic.u - width / 2; y: 9.6 * ic.u - height / 2
    }
  }
}
