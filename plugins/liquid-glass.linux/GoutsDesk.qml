import QtQuick
import Quickshell
import Quickshell.Wayland

// « Mes goûts » : l'horloge à planètes s'ajoute aux widgets déplaçables du bureau.
PanelWindow {
  id: win
  property var service: null
  color: "transparent"
  anchors { top: true; bottom: true; left: true; right: true }
  exclusionMode: ExclusionMode.Normal
  WlrLayershell.layer: WlrLayer.Bottom
  WlrLayershell.namespace: "liquid-glass-linux-planets"
  WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
  mask: Region {}
  Planets {
    anchors.right: parent.right; anchors.rightMargin: 26
    anchors.bottom: parent.bottom; anchors.bottomMargin: 24
    width: 176; height: 176
    s: win.service
  }
}
