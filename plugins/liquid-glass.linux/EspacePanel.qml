import QtQuick
import Quickshell
import Quickshell.Wayland

// Socle des volets du style Espace : carte centrée, Échap ou clic dehors pour fermer.
PanelWindow {
  id: win
  property var service: null
  readonly property var s: service
  property int cardW: 700
  property int cardH: 460
  default property alias content: card.data
  readonly property alias card: card

  color: "transparent"
  anchors { top: true; bottom: true; left: true; right: true }
  exclusionMode: ExclusionMode.Ignore
  WlrLayershell.layer: WlrLayer.Overlay
  WlrLayershell.namespace: "liquid-glass-linux-panel"
  WlrLayershell.keyboardFocus: s.kbd(false)

  readonly property string font: s.sansFont
  readonly property color ink: s.colOnSurface
  readonly property color sub: s.colOnSurfaceVariant
  property bool revealed: false
  Component.onCompleted: { revealed = true; keys.forceActiveFocus() }
  Item { id: keys; focus: true; Keys.onEscapePressed: win.s.closeAll() }
  MouseArea { anchors.fill: parent; onClicked: win.s.closeAll() }

  Rectangle {
    id: card
    anchors.centerIn: parent
    width: Math.min(win.cardW, parent.width - 32); height: Math.min(win.cardH, parent.height - 60)
    radius: Math.min(16, s.radius)
    color: win.s.alpha(win.s.surface, 0.97)
    border.width: 1; border.color: win.s.alpha(win.ink, 0.12)
    opacity: win.revealed ? 1 : 0
    scale: win.revealed ? 1 : 0.96
    Behavior on opacity { NumberAnimation { duration: 180 } }
    Behavior on scale { NumberAnimation { duration: 240; easing.type: Easing.OutCubic } }
    MouseArea { anchors.fill: parent }
  }
}
