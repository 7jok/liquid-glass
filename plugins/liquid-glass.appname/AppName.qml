import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.Commons
import qs.Commons as Commons
import qs.Ui

// Liquid Glass — nom de l'application active (« Firefox », « Fichiers »…),
// en gras comme sur macOS. Clic milieu / droit : fermer la fenêtre.
BarWidget {
  id: root
  moduleName: "liquid-glass.appname"

  readonly property var toplevel: ToplevelManager.activeToplevel
  readonly property string appId: toplevel ? (toplevel.appId || "") : ""
  readonly property var entry: appId !== "" ? DesktopEntries.heuristicLookup(appId) : null
  readonly property string name: {
    if (!toplevel) return "Bureau"
    if (entry && entry.name) return entry.name
    if (appId === "") return toplevel.title || ""
    // org.gnome.Nautilus → Nautilus, foot → Foot
    var last = appId.split(".").pop()
    return last.charAt(0).toUpperCase() + last.slice(1)
  }

  visible: !vertical
  implicitWidth: visible ? Math.min(220, label.implicitWidth) + Style.space(14) : 0
  implicitHeight: barSize
  Behavior on implicitWidth { NumberAnimation { duration: Style.duration(160); easing.type: Easing.OutCubic } }

  Text {
    id: label
    textFormat: Text.PlainText
    anchors.verticalCenter: parent.verticalCenter
    x: Style.space(7)
    width: parent.width - Style.space(14)
    text: root.name
    elide: Text.ElideRight
    color: root.bar ? root.bar.barForeground : Commons.Color.foreground
    font.family: "Inter"
    font.pixelSize: Style.font.subtitle
    font.weight: Font.Bold
  }

  MouseArea {
    anchors.fill: parent
    acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
    cursorShape: Qt.PointingHandCursor
    onClicked: function(mouse) {
      if (!root.toplevel) return
      if (mouse.button === Qt.LeftButton) root.toplevel.activate()
      else root.toplevel.close()
    }
  }
}
