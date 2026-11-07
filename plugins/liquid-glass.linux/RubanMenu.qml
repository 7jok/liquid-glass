import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets

// Lanceur du style Rubans : le fond passe à l'accent, un grand mot vertical,
// et une liste en biais dont les lignes glissent l'une après l'autre.
PanelWindow {
  id: win
  property var service: null
  readonly property var s: service

  color: "transparent"
  anchors { top: true; bottom: true; left: true; right: true }
  exclusionMode: ExclusionMode.Ignore
  WlrLayershell.layer: WlrLayer.Overlay
  WlrLayershell.namespace: "liquid-glass-linux-launcher"
  WlrLayershell.keyboardFocus: s.kbd(true)

  readonly property string font: "Rubik"
  property string query: ""
  property int sel: 0
  property bool revealed: false
  readonly property var results: s.apps(query).slice(0, 8)
  onQueryChanged: sel = 0
  Component.onCompleted: { revealed = true; input.forceActiveFocus() }

  MouseArea { anchors.fill: parent; onClicked: win.s.closeAll() }

  // Aplat qui balaie l'écran en diagonale.
  Rectangle {
    width: win.width * 0.78; height: win.height * 1.6
    y: -win.height * 0.3
    x: win.revealed ? -win.width * 0.08 : -win.width
    rotation: 10
    color: win.s.alpha(win.s.surface, 0.96)
    Behavior on x { NumberAnimation { duration: 320; easing.type: Easing.OutQuart } }
    Rectangle { anchors.right: parent.right; width: 14; height: parent.height; color: win.s.primary }
  }

  Text {
    x: -46; y: win.height / 2 - 90
    rotation: -90
    opacity: win.revealed ? 0.16 : 0
    text: "APPS"
    font.family: win.font; font.pixelSize: 170; font.weight: Font.Black; font.italic: true; color: win.s.primary
    Behavior on opacity { NumberAnimation { duration: 400 } }
  }

  Column {
    x: 130; y: Math.max(70, win.height / 2 - 270)
    spacing: 7

    // Recherche
    Rectangle {
      width: 470; height: 48
      color: win.s.primary
      transform: Matrix4x4 { matrix: Qt.matrix4x4(1, -0.2, 0, 9.6, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1) }
      TextInput {
        id: input
        x: 22; width: parent.width - 44; anchors.verticalCenter: parent.verticalCenter
        font.family: win.font; font.pixelSize: 22; font.weight: Font.Black; font.italic: true
        color: win.s.colOnPrimary; clip: true
        onTextChanged: win.query = text
        Keys.onEscapePressed: win.s.closeAll()
        Keys.onDownPressed: win.sel = Math.min(win.results.length - 1, win.sel + 1)
        Keys.onUpPressed: win.sel = Math.max(0, win.sel - 1)
        Keys.onTabPressed: win.sel = (win.sel + 1) % Math.max(1, win.results.length)
        Keys.onReturnPressed: if (win.results.length) win.s.launch(win.results[win.sel])
        Text {
          visible: input.text === ""; anchors.verticalCenter: parent.verticalCenter
          text: "QUE LANCER ?"
          font.family: win.font; font.pixelSize: 22; font.weight: Font.Black; font.italic: true
          color: win.s.alpha(win.s.colOnPrimary, 0.55)
        }
      }
    }

    Repeater {
      model: win.results
      delegate: Item {
        id: row
        required property var modelData
        required property int index
        readonly property bool cur: index === win.sel
        width: 470; height: 48
        // Chaque ligne arrive un peu après la précédente, et se décale quand on la choisit.
        x: (win.revealed ? 0 : -560) + (cur ? 26 : index % 2 * 8)
        Behavior on x { SequentialAnimation { PauseAnimation { duration: row.index * 22 } NumberAnimation { duration: 240; easing.type: Easing.OutBack } } }
        Rectangle {
          anchors.fill: parent
          color: row.cur ? win.s.colOnSurface : win.s.surfaceHigh
          transform: Matrix4x4 { matrix: Qt.matrix4x4(1, -0.2, 0, 9.6, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1) }
          Rectangle { visible: row.cur; width: 8; height: parent.height; color: win.s.primary }
          IconImage { x: 22; anchors.verticalCenter: parent.verticalCenter; width: 28; height: 28; source: win.s.appIcon(row.modelData); asynchronous: true }
          Text {
            x: 62; width: parent.width - 80; anchors.verticalCenter: parent.verticalCenter; elide: Text.ElideRight
            text: win.s.appName(row.modelData)
            font.family: win.font; font.pixelSize: 19; font.weight: Font.Black; font.italic: true
            color: row.cur ? win.s.surface : win.s.colOnSurface
          }
        }
        MouseArea {
          anchors.fill: parent; hoverEnabled: true
          onEntered: win.sel = row.index
          onClicked: win.s.launch(row.modelData)
        }
      }
    }
  }
}
