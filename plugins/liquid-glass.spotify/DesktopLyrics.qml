import QtQuick
import Quickshell
import Quickshell.Wayland

// Paroles géantes sur le bureau : couche « Bottom » (au-dessus du fond, sous
// toutes les fenêtres), totalement transparente aux clics. Quand le fond
// Spotify est en mode « cover », la pochette est à gauche et les paroles
// occupent la moitié droite ; sinon elles sont centrées.
PanelWindow {
  id: win

  property var service: null

  readonly property bool wanted: !!service && service.lyricsDesktop && service.lyricsSynced
    && service.playing && service.showingCover && !service.karaokeOpen
  readonly property bool sideLayout: !!service && service.wallMode === "cover"

  visible: wanted || fade.opacity > 0.01
  color: "transparent"
  anchors { top: true; left: true; right: true; bottom: true }
  exclusionMode: ExclusionMode.Ignore
  WlrLayershell.layer: WlrLayer.Bottom
  WlrLayershell.namespace: "liquid-glass-lyrics-desktop"
  WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
  mask: Region {}

  Item {
    id: fade
    anchors.fill: parent
    opacity: win.wanted ? 1 : 0
    Behavior on opacity { NumberAnimation { duration: 600; easing.type: Easing.OutCubic } }

    LyricsColumn {
      service: win.service
      x: win.sideLayout ? parent.width * 0.54 : parent.width * 0.14
      width: win.sideLayout ? parent.width * 0.40 : parent.width * 0.72
      y: parent.height * 0.12
      height: parent.height * 0.76
      fontSize: Math.round(parent.height * (win.sideLayout ? 0.040 : 0.046))
      horizontalAlignment: win.sideLayout ? Text.AlignLeft : Text.AlignHCenter
      visibleRadius: 4
      clip: true
    }
  }
}
