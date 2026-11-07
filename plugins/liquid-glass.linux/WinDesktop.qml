import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets
import "T.js" as T

// Style « windows » : icônes du bureau en colonne à gauche (Ce PC, Corbeille,
// Documents, navigateur, Paramètres). Double-clic pour ouvrir, comme sous Windows.
PanelWindow {
  id: win
  property var service: null
  readonly property var s: service

  color: "transparent"
  anchors { top: true; left: true; bottom: true }
  implicitWidth: 96
  exclusionMode: ExclusionMode.Ignore
  WlrLayershell.layer: WlrLayer.Bottom
  WlrLayershell.namespace: "liquid-glass-win-desktop"
  WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
  mask: Region { item: col }

  readonly property string home: Quickshell.env("HOME")
  readonly property var browser: s.pinned(1)[0]
  readonly property var icons: [
    { name: T.t("Ce PC"), sym: "computer", tint: "#4aa3df", run: ["sh", "-c", "xdg-open \"$HOME\""] },
    { name: T.t("Corbeille"), sym: "delete", tint: "#9aa7b4", run: ["sh", "-c", "mkdir -p \"$HOME/.local/share/Trash/files\"; xdg-open \"$HOME/.local/share/Trash/files\""] },
    { name: "Documents", sym: "folder", tint: "#f2c14e", run: ["sh", "-c", "xdg-open \"$(xdg-user-dir DOCUMENTS 2>/dev/null || echo $HOME)\""] },
    { name: T.t("Paramètres"), sym: "settings", tint: "#7a8a9a", menu: true }
  ]
  property int sel: -1

  Column {
    id: col
    x: 6; y: 8
    spacing: 6
    Repeater {
      model: win.icons
      delegate: Rectangle {
        id: ic
        required property var modelData
        required property int index
        width: 84; height: 78; radius: 3
        color: win.sel === index ? Qt.rgba(0.6, 0.8, 1, 0.35) : (ma.containsMouse ? Qt.rgba(1, 1, 1, 0.16) : "transparent")
        border.width: win.sel === index ? 1 : 0
        border.color: Qt.rgba(0.7, 0.85, 1, 0.6)
        MIcon {
          anchors.horizontalCenter: parent.horizontalCenter; y: 6
          icon: ic.modelData.sym; size: 38; fill: 1; color: ic.modelData.tint
          style: Text.Raised; styleColor: Qt.rgba(0, 0, 0, 0.35)
        }
        Text {
          anchors.horizontalCenter: parent.horizontalCenter; y: 50
          width: parent.width - 4; horizontalAlignment: Text.AlignHCenter; wrapMode: Text.Wrap; maximumLineCount: 2
          text: ic.modelData.name
          font.family: s.sansFont; font.pixelSize: 11
          // Encre du thème, contour opposé : lisible sur un fond clair comme sombre.
          color: win.s.colOnSurface
          style: Text.Outline; styleColor: win.s.alpha(win.s.surface, 0.55)
        }
        MouseArea {
          id: ma
          anchors.fill: parent
          hoverEnabled: true
          onClicked: win.sel = ic.index
          onDoubleClicked: { win.sel = -1; if (ic.modelData.menu) s.toggleMenu("home"); else Quickshell.execDetached(ic.modelData.run) }
        }
      }
    }
  }
}
