import QtQuick
import Quickshell
import Quickshell.Wayland
ShellRoot {
  Variants {
    model: Quickshell.screens.filter(function(s) { return s.name === (Quickshell.env("LG_SCREEN") || s.name) })
    delegate: Component {
      PanelWindow {
        required property var modelData
        screen: modelData
        anchors { top: true; bottom: true; left: true; right: true }
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Background
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
        mask: Region {}
        color: "black"
        Image { anchors.fill: parent; source: "file://" + Quickshell.env("LG_BG"); fillMode: Image.PreserveAspectCrop; sourceSize.width: 1920 }
      }
    }
  }
  Linux {}
}
