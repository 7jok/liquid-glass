import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland

// Fond vivant : anime le fond d'écran courant par un shader, sans fichier vidéo.
// S'arrête dès qu'une fenêtre est ouverte sur le bureau, pour garder la batterie.
PanelWindow {
  id: win
  property var service: null
  readonly property var s: service
  color: "transparent"
  anchors { top: true; bottom: true; left: true; right: true }
  exclusionMode: ExclusionMode.Ignore
  WlrLayershell.layer: WlrLayer.Background
  WlrLayershell.namespace: "liquid-glass-linux-livewall"
  WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
  mask: Region {}

  readonly property var ws: Hyprland.focusedWorkspace
  readonly property bool covered: !s.testing && !!ws && !!ws.toplevels && ws.toplevels.values.length > 0
  property real clock: 0
  Timer { interval: 40; repeat: true; running: !win.covered; onTriggered: win.clock += 0.04 }

  Image {
    id: img
    source: win.s.bgPath ? "file://" + win.s.bgPath : ""
    visible: false
    sourceSize.width: 1920
    fillMode: Image.PreserveAspectCrop
    width: win.width; height: win.height
    layer.enabled: true
  }
  ShaderEffect {
    anchors.fill: parent
    property variant wall: img
    property real time: win.clock
    property real mode: ["tourbillon", "vague", "respire"].indexOf(String(win.s.opt("live_wall", "off")))
    property real aspect: width / Math.max(1, height)
    fragmentShader: Qt.resolvedUrl("cosmos/live.frag.qsb")
  }
}
