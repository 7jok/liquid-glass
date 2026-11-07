import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

// Style Mono : au déverrouillage, un cadenas sur une tuile givrée apparaît au centre,
// s'ouvre puis s'efface (comme dans la vidéo caelestia d'arch.inix).
PanelWindow {
  id: win
  property var service: null
  readonly property var s: service
  color: "transparent"
  anchors { top: true; bottom: true; left: true; right: true }
  exclusionMode: ExclusionMode.Ignore
  WlrLayershell.layer: WlrLayer.Overlay
  WlrLayershell.namespace: "liquid-glass-unlock"
  WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
  mask: Region {}
  visible: anim.running || win.s.testing && String(Quickshell.env("LG_UNLOCK") || "") !== ""

  FileView {
    path: Quickshell.env("HOME") + "/.cache/liquid-glass/unlocked"
    watchChanges: true; printErrors: false
    property bool primed: false
    onLoaded: { if (primed) anim.restart(); primed = true }
    onLoadFailed: primed = true
    onFileChanged: reload()
  }
  Component.onCompleted: if (win.s.testing && String(Quickshell.env("LG_UNLOCK") || "") !== "") anim.restart()

  Rectangle {
    id: tile
    anchors.centerIn: parent
    width: 150; height: 150; radius: 34
    color: Qt.rgba(1, 1, 1, win.s.darkSkin ? 0.16 : 0.42)
    border.color: Qt.rgba(1, 1, 1, 0.35)
    opacity: 0; scale: 0.8
    layer.enabled: true
    layer.effect: MultiEffect { shadowEnabled: true; shadowBlur: 0.8; shadowOpacity: 0.18; shadowVerticalOffset: 6 }
    MIcon {
      id: ico
      anchors.centerIn: parent
      icon: "lock"; size: 92; weight: 500; fill: 0
      color: win.s.darkSkin ? "#f2f2f2" : Qt.darker(win.s.colOnSurface, 1.1)
    }
  }
  SequentialAnimation {
    id: anim
    ScriptAction { script: ico.icon = "lock" }
    ParallelAnimation {
      NumberAnimation { target: tile; property: "opacity"; from: 0; to: 1; duration: 180 }
      NumberAnimation { target: tile; property: "scale"; from: 0.8; to: 1; duration: 320; easing.type: Easing.OutBack }
    }
    PauseAnimation { duration: 260 }
    ScriptAction { script: ico.icon = "lock_open" }
    PauseAnimation { duration: 380 }
    ParallelAnimation {
      NumberAnimation { target: tile; property: "opacity"; to: 0; duration: 360 }
      NumberAnimation { target: tile; property: "scale"; to: 1.15; duration: 360; easing.type: Easing.InCubic }
    }
  }
}
