import QtQuick
import Quickshell

// Style « windows » : la fenêtre Paramètres (une vraie fenêtre Hyprland,
// flottante et centrée par la règle « Paramètres » de liquid-glass-linux.lua).
FloatingWindow {
  id: w
  property var service: null
  title: "Paramètres"
  implicitWidth: 980
  implicitHeight: 640
  color: service && service.darkSkin ? "#202020" : "#f3f3f3"
  visible: true
  onVisibleChanged: if (!visible && service) service.menuOpen = false
  WinSettingsBody { anchors.fill: parent; service: w.service }
}
