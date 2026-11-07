import QtQuick
import QtQuick.Effects
import Quickshell.Widgets

// Bouton « Claude Code » (omarchy-agent --pick), présent dans la barre de chaque
// style Linux, comme sur la barre du Mac. Logo d'Omarchy (agents/assets/claude.svg),
// petit tour de rotation au survol, rebond au clic.
//   mono  : true → logo désaturé (styles noir et blanc)
//   tint  : couleur du logo (sinon couleur d'origine, orange Claude)
Item {
  id: cb
  property var s: null
  property real size: 24
  property real iconSize: size * 0.62
  property bool mono: false
  property color tint: "transparent"
  property color base: "transparent"
  property color hover: s ? s.alpha(s.colOnSurface, 0.1) : Qt.rgba(1, 1, 1, 0.1)
  property real radius: width / 2
  width: size; height: size
  anchors.verticalCenter: parent ? parent.verticalCenter : undefined

  Rectangle {
    anchors.fill: parent
    radius: cb.radius
    color: ma.containsMouse ? cb.hover : cb.base
    scale: ma.pressed ? 0.86 : 1
    Behavior on scale { NumberAnimation { duration: 260; easing.type: Easing.OutBack; easing.overshoot: 3 } }
    Behavior on color { ColorAnimation { duration: 140 } }
  }
  IconImage {
    id: logo
    anchors.centerIn: parent
    implicitSize: cb.iconSize
    source: "file:///usr/share/omarchy/shell/plugins/agents/assets/claude.svg"
    rotation: ma.containsMouse ? 90 : 0
    Behavior on rotation { NumberAnimation { duration: 520; easing.type: Easing.OutBack; easing.overshoot: 1.4 } }
    layer.enabled: cb.mono || cb.tint.a > 0
    layer.effect: MultiEffect {
      saturation: cb.mono ? -1 : 0
      colorization: cb.tint.a > 0 ? 1 : 0
      colorizationColor: cb.tint
      brightness: cb.mono ? 0.25 : 0
    }
  }
  MouseArea {
    id: ma
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    onClicked: if (cb.s) cb.s.claude()
  }
}
