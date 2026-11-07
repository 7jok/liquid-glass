import QtQuick

// Logo « quatre carreaux » dessiné ici (pas l'image officielle) : quatre vitres
// bleues en dégradé, légèrement écartées.
Item {
  id: logo
  property real size: 18
  property bool pressed: false
  property color c1: "#3fb3ff"
  property color c2: "#0067c0"
  width: size; height: size
  scale: pressed ? 0.86 : 1
  Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
  readonly property real gap: Math.max(1, size * 0.07)
  readonly property real pane: (size - gap) / 2
  Repeater {
    model: 4
    delegate: Rectangle {
      required property int index
      x: (index % 2) * (logo.pane + logo.gap)
      y: Math.floor(index / 2) * (logo.pane + logo.gap)
      width: logo.pane; height: logo.pane
      radius: Math.max(0.5, logo.size * 0.04)
      gradient: Gradient {
        orientation: Gradient.Vertical
        GradientStop { position: 0; color: logo.c1 }
        GradientStop { position: 1; color: logo.c2 }
      }
    }
  }
}
