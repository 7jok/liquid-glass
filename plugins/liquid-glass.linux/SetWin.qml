import QtQuick
import Quickshell
import Quickshell.Wayland

// Fenêtre de base des réglages de chaque thème (⌘Échap, ⌘⌥Espace, boutons des
// barres) : plein écran transparent au-dessus de tout, voile, Échap ou clic à
// côté pour fermer, Tab / ⇧Tab pour changer de page. Chaque Set<Thème>.qml y pose
// son propre panneau (forme, place, onglets, polices) ; SetCore fait le reste.
PanelWindow {
  id: win
  property var service: null
  readonly property var s: service
  default property alias content: stage.data
  readonly property alias core: core
  property color veil: "transparent"
  property bool revealed: false
  property bool closeOnOutside: true

  color: "transparent"
  anchors { top: true; bottom: true; left: true; right: true }
  exclusionMode: ExclusionMode.Ignore
  WlrLayershell.layer: WlrLayer.Overlay
  WlrLayershell.namespace: "liquid-glass-linux-settings"
  WlrLayershell.keyboardFocus: s.kbd(false)

  SetCore { id: core; service: win.s }
  Component.onCompleted: {
    var p = String(s.menuPage || "")
    core.page = p === "settings" ? "style" : (core.pages.some(function(x) { return x[0] === p }) ? p : "home")
    revealed = true
    keys.forceActiveFocus()
  }

  Rectangle {
    anchors.fill: parent
    color: win.veil
    opacity: win.revealed ? 1 : 0
    Behavior on opacity { NumberAnimation { duration: 220 } }
  }
  MouseArea { anchors.fill: parent; enabled: win.closeOnOutside; onClicked: core.close() }
  Item { id: stage; anchors.fill: parent }
  Item {
    id: keys
    focus: true
    Keys.onPressed: function(e) {
      if (e.key === Qt.Key_Escape) { core.close(); e.accepted = true }
      else if (e.key === Qt.Key_Tab || (e.key === Qt.Key_PageDown && e.modifiers & Qt.ControlModifier)) { core.step(1); e.accepted = true }
      else if (e.key === Qt.Key_Backtab || (e.key === Qt.Key_PageUp && e.modifiers & Qt.ControlModifier)) { core.step(-1); e.accepted = true }
      else if (e.key >= Qt.Key_1 && e.key <= Qt.Key_9 && e.modifiers & Qt.AltModifier) {
        var i = e.key - Qt.Key_1
        if (i < core.pages.length) core.page = core.pages[i][0]
        e.accepted = true
      }
    }
  }
}
