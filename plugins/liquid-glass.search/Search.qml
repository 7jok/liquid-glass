import QtQuick
import Quickshell
import qs.Commons
import qs.Commons as Commons
import qs.Ui

// Liquid Glass — loupe Spotlight de la barre des menus (dessinée, fine comme
// le symbole de macOS). Clic : ouvre / ferme Spotlight (comme ⌘Espace).
Panel {
  id: root
  moduleName: "liquid-glass.search"
  ipcTarget: "liquid-glass.search"
  readonly property color tint: root.bar ? root.bar.barForeground : Commons.Color.foreground

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  Item {
    id: button
    anchors.fill: parent
    implicitWidth: Style.space(30)
    implicitHeight: root.bar ? root.bar.barSize : Style.space(28)

    Rectangle {
      anchors.centerIn: parent
      width: Style.space(26); height: Style.space(22); radius: Style.space(6)
      color: root.tint
      opacity: mouse.containsMouse ? 0.08 : 0
      Behavior on opacity { NumberAnimation { duration: Style.duration(100) } }
    }

    Item {
      anchors.centerIn: parent
      width: Style.space(14); height: Style.space(14)
      scale: mouse.pressed ? 0.85 : 1
      Behavior on scale { NumberAnimation { duration: 260; easing.type: Easing.OutBack; easing.overshoot: 3 } }
      // Verre de la loupe
      Rectangle {
        x: 0; y: 0
        width: Style.space(10.5); height: width; radius: width / 2
        color: "transparent"
        border.width: Math.max(1.5, Style.space(1.6)); border.color: root.tint
      }
      // Manche
      Rectangle {
        width: Style.space(5.5); height: Math.max(1.5, Style.space(1.8)); radius: height / 2
        color: root.tint
        x: Style.space(8.6); y: Style.space(10)
        rotation: 45
        transformOrigin: Item.Left
      }
    }

    MouseArea {
      id: mouse
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onClicked: Quickshell.execDetached(["omarchy-shell", "shell", "toggle", "liquid-glass.spotlight"])
    }
  }
}
