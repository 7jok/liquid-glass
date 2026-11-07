import QtQuick
import Quickshell
import Quickshell.Wayland

// Style Mono : une bande de 3 px au milieu du bord haut. La souris qui s'y pose ouvre
// le tableau de bord (comme caelestia) ; il se referme quand elle en sort.
PanelWindow {
  id: win
  property var service: null
  readonly property var s: service
  color: "transparent"
  anchors.top: true
  implicitWidth: 640
  implicitHeight: 3
  exclusionMode: ExclusionMode.Ignore
  WlrLayershell.layer: WlrLayer.Top
  WlrLayershell.namespace: "liquid-glass-mono-edge"
  WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
  HoverHandler { id: hov }
  Timer {
    interval: 140; running: hov.hovered && win.s.panel === ""
    onTriggered: { win.s.hoverOpen = true; win.s.togglePanel("dashboard") }
  }
}
