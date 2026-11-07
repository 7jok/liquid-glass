import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets

// Style Île, dock : petites icônes colorées, caché tant que la souris n'est pas en bas.
PanelWindow {
  id: win
  property var service: null
  readonly property var s: service

  anchors { bottom: true; left: true; right: true }
  implicitHeight: 74
  exclusionMode: ExclusionMode.Ignore
  color: "transparent"
  mask: Region { item: shown ? body : edge }
  WlrLayershell.layer: WlrLayer.Top
  WlrLayershell.namespace: "liquid-glass-linux-dock"
  WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

  property bool shown: edgeHover.hovered || bodyHover.hovered
  readonly property var pins: s.pinned(16)

  Item {
    id: edge
    anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
    height: 3
    HoverHandler { id: edgeHover }
  }
  Rectangle {
    id: body
    anchors.horizontalCenter: parent.horizontalCenter
    y: win.shown ? win.height - height - 6 : win.height + 2
    Behavior on y { SpringAnimation { spring: 4; damping: 0.42 } }
    width: row.width + 18; height: 52; radius: 14
    color: "#17151b"; opacity: 0.94
    border.color: Qt.rgba(1, 1, 1, 0.07); border.width: 1
    HoverHandler { id: bodyHover }
    Row {
      id: row
      anchors.centerIn: parent
      spacing: 6
      Repeater {
        model: win.pins
        Item {
          id: tile
          required property var modelData
          width: 36; height: 36
          IconImage {
            anchors.centerIn: parent
            implicitSize: tileHover.hovered ? 36 : 30
            Behavior on implicitSize { NumberAnimation { duration: 120 } }
            source: win.s.appIcon(tile.modelData)
          }
          HoverHandler { id: tileHover }
          TapHandler { onTapped: win.s.launch(tile.modelData) }
        }
      }
    }
  }
}
