import QtQuick
import Quickshell
import Quickshell.Wayland

// Changement de fond en balayage : l'ancien fond reste affiché par-dessus le nouveau
// et se retire vers la droite, avec un liseré clair sur le bord (vidéo d'arch.inix, 25 s).
PanelWindow {
  id: win
  property var service: null
  readonly property var s: service
  color: "transparent"
  anchors { top: true; bottom: true; left: true; right: true }
  exclusionMode: ExclusionMode.Ignore
  WlrLayershell.layer: WlrLayer.Background
  WlrLayershell.namespace: "liquid-glass-linux-wallwipe"
  WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
  mask: Region {}
  visible: wipe.running

  property string last: ""
  property real edge: 0          // 0 → 1 : part du nouveau fond découverte
  function isImage(p) { return /\.(jpe?g|png|webp|bmp)$/i.test(p) }

  Connections {
    target: win.s
    function onBgPathChanged() {
      var p = win.s.bgPath
      if (win.last !== "" && p !== win.last && win.isImage(win.last)) {
        old.source = "file://" + win.last
        win.edge = 0
        wipe.restart()
      }
      win.last = p
    }
  }
  Component.onCompleted: last = s.bgPath

  Item {
    id: clip
    x: win.width * win.edge
    width: win.width - x; height: win.height
    clip: true
    Image {
      id: old
      x: -clip.x
      width: win.width; height: win.height
      fillMode: Image.PreserveAspectCrop
      sourceSize: Qt.size(win.width, win.height)
      cache: true
    }
    Rectangle { width: 3; height: parent.height; color: Qt.rgba(1, 1, 1, 0.7) }
    Rectangle { x: 3; width: 40; height: parent.height
      gradient: Gradient { orientation: Gradient.Horizontal
        GradientStop { position: 0; color: Qt.rgba(0, 0, 0, 0.25) } GradientStop { position: 1; color: "transparent" } } }
  }
  SequentialAnimation {
    id: wipe
    PauseAnimation { duration: 120 }          // le temps que le nouveau fond s'affiche dessous
    NumberAnimation { target: win; property: "edge"; from: 0; to: 1; duration: 900; easing.type: Easing.InOutCubic }
  }
}
