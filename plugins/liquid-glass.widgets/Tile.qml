import QtQuick
import qs.Commons
import qs.Commons as Commons

// Carte de verre d'un widget : coins arrondis façon macOS, liseré clair.
// Le flou d'arrière-plan est fait par Hyprland (règle de calque liquid-glass-widgets).
Item {
  id: tile
  property var svc: null
  property color tint: svc && svc.dark ? Qt.rgba(0.11, 0.11, 0.13, 0.55) : Qt.rgba(1, 1, 1, 0.58)
  property alias background: bg
  readonly property color fg: svc && svc.dark ? "#f5f5f7" : "#1d1d1f"
  readonly property color dim: svc && svc.dark ? Qt.rgba(1, 1, 1, 0.55) : Qt.rgba(0, 0, 0, 0.5)
  readonly property string font: svc ? svc.uiFont : "Inter"
  readonly property real radius: Style.space(24)
  default property alias content: inner.data

  Rectangle {
    id: bg
    anchors.fill: parent
    radius: tile.radius
    color: tile.tint
    border.width: 1
    border.color: svc && svc.dark ? Qt.rgba(1, 1, 1, 0.12) : Qt.rgba(1, 1, 1, 0.65)
    clip: true
  }
  Item {
    id: inner
    anchors.fill: parent
  }
}
