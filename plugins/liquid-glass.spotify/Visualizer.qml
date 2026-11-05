import QtQuick
import Quickshell
import Quickshell.Wayland

// Visualiseur cava en bas du fond d'écran, aux couleurs de la pochette.
// Couche « Bottom » (derrière les fenêtres), transparent aux clics.
// Les valeurs viennent du service (un seul processus cava pour tous les écrans).
PanelWindow {
  id: win

  property var service: null
  readonly property var values: service ? service.cavaValues : []

  visible: !!service && service.cavaRunning
  color: "transparent"
  anchors { left: true; right: true; bottom: true }
  implicitHeight: 150
  exclusionMode: ExclusionMode.Ignore
  WlrLayershell.layer: WlrLayer.Bottom
  WlrLayershell.namespace: "liquid-glass-visualizer"
  WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
  mask: Region {}

  Row {
    id: bars
    anchors.bottom: parent.bottom
    anchors.bottomMargin: 8
    anchors.horizontalCenter: parent.horizontalCenter
    readonly property int count: Math.max(1, win.values.length)
    readonly property real slot: Math.min(22, (win.width * 0.8) / count)
    spacing: slot * 0.28

    Repeater {
      model: bars.count
      delegate: Rectangle {
        required property int index
        readonly property real v: index < win.values.length ? win.values[index] : 0
        anchors.bottom: parent.bottom
        width: bars.slot * 0.72
        height: Math.max(width, v / 100 * (win.height - 16))
        radius: width / 2
        opacity: 0.78
        gradient: Gradient {
          GradientStop { position: 0; color: win.service ? win.service.accent2 : "white" }
          GradientStop { position: 1; color: win.service ? win.service.accent : "white" }
        }
        Behavior on height { NumberAnimation { duration: 60 } }
      }
    }
  }
}
