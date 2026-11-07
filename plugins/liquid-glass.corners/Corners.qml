import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

// Liquid Glass — coins d'écran arrondis, comme la dalle d'un MacBook.
// Quatre petites surfaces noires (quart de cercle évidé) au-dessus de tout,
// sans zone de saisie : les clics et les coins actifs passent au travers.
// Réglages : [corners] enabled / radius de config.toml.
Item {
  id: root
  property var shell: null
  property var manifest: null

  property var cfg: ({})
  readonly property var cc: cfg.corners || ({})
  readonly property bool enabled: cc.enabled !== false
  readonly property int radius: Math.max(4, Math.min(30, Number(cc.radius) || 10))

  FileView {
    path: Quickshell.env("HOME") + "/.config/liquid-glass/config.json"
    watchChanges: true
    printErrors: false
    onFileChanged: reload()
    onLoaded: { try { root.cfg = JSON.parse(text()) } catch (e) {} }
  }

  Variants {
    model: {
      if (!root.enabled) return []
      var out = []
      var screens = Quickshell.screens
      var names = ["top_left", "top_right", "bottom_left", "bottom_right"]
      for (var s = 0; s < screens.length; s++)
        for (var c = 0; c < names.length; c++) out.push({ screen: screens[s], corner: names[c] })
      return out
    }
    delegate: Component {
      PanelWindow {
        id: win
        required property var modelData
        screen: modelData.screen
        readonly property bool isTop: modelData.corner.indexOf("top") === 0
        readonly property bool isLeft: modelData.corner.indexOf("left") !== -1
        anchors { top: win.isTop; bottom: !win.isTop; left: win.isLeft; right: !win.isLeft }
        implicitWidth: root.radius
        implicitHeight: root.radius
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "liquid-glass-corners"
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
        mask: Region {}

        Canvas {
          anchors.fill: parent
          antialiasing: true
          onPaint: {
            var g = getContext("2d"), r = width
            g.reset()
            // Coin de l'écran (cx, cy) et centre de l'arc (ox, oy).
            var cx = win.isLeft ? 0 : r, cy = win.isTop ? 0 : r
            var ox = win.isLeft ? r : 0, oy = win.isTop ? r : 0
            g.fillStyle = "black"
            g.beginPath()
            g.moveTo(cx, cy)
            g.lineTo(ox, cy)
            var a0 = Math.atan2(cy - oy, 0), a1 = Math.atan2(0, cx - ox)
            g.arc(ox, oy, r, a0, a1, win.isLeft === win.isTop)
            g.closePath()
            g.fill()
          }
          onWidthChanged: requestPaint()
        }
      }
    }
  }
}
