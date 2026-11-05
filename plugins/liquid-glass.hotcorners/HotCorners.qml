import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

// Liquid Glass — coins actifs (comme Réglages Système → Bureau et Dock → Coins actifs).
// Chaque coin configuré reçoit une surface de 2×2 px au-dessus de tout ; si le pointeur
// y reste un court instant, `liquid-glass hotcorner <action>` est lancé (qui ne fait
// rien si la fenêtre active est en plein écran). Réglages : [hotcorners] de config.toml.
Item {
  id: root
  property var shell: null
  property var manifest: null

  property var cfg: ({})
  readonly property var hc: cfg.hotcorners || ({})
  readonly property var corners: {
    var out = []
    var names = ["top_left", "top_right", "bottom_left", "bottom_right"]
    for (var i = 0; i < names.length; i++) {
      var a = String(hc[names[i]] || "")
      if (/^[a-z]+$/.test(a)) out.push({ corner: names[i], action: a })
    }
    return out
  }

  FileView {
    path: Quickshell.env("HOME") + "/.config/liquid-glass/config.json"
    watchChanges: true
    onFileChanged: reload()
    onLoaded: { try { root.cfg = JSON.parse(text()) } catch (e) {} }
  }

  property real lastFire: 0

  Variants {
    // Un jeu de coins par écran.
    model: {
      var out = []
      var screens = Quickshell.screens
      for (var s = 0; s < screens.length; s++)
        for (var c = 0; c < root.corners.length; c++)
          out.push({ screen: screens[s], corner: root.corners[c].corner, action: root.corners[c].action })
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
        implicitWidth: 2
        implicitHeight: 2
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "liquid-glass-hotcorner"
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

        MouseArea {
          anchors.fill: parent
          hoverEnabled: true
          onEntered: dwell.restart()
          onExited: dwell.stop()
        }
        Timer {
          id: dwell
          interval: 140
          onTriggered: {
            var now = Date.now()
            if (now - root.lastFire < 1200) return   // pas de rafale
            root.lastFire = now
            Quickshell.execDetached(["liquid-glass", "hotcorner", win.modelData.action])
          }
        }
      }
    }
  }
}
