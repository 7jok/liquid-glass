import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets
import "T.js" as T

// Lanceur du style Cosmos : les applications sont posées sur la Lune, en sphère.
// Glisser fait tourner la Lune, taper filtre, Entrée lance, Échap ferme.
PanelWindow {
  id: win
  property var service: null
  readonly property var s: service

  color: "transparent"
  anchors { top: true; bottom: true; left: true; right: true }
  exclusionMode: ExclusionMode.Ignore
  WlrLayershell.layer: WlrLayer.Overlay
  WlrLayershell.namespace: "liquid-glass-linux-moon"
  WlrLayershell.keyboardFocus: s.kbd(true)

  readonly property string font: s.sansFont
  property string query: ""
  readonly property var hits: s.apps(query).slice(0, query === "" ? 72 : 24)
  property real yaw: 0
  property real pitch: -0.15
  property real tt: 0
  property bool shown: false
  Component.onCompleted: { shown = true; input.forceActiveFocus() }
  Timer {
    interval: 33; repeat: true; running: true
    onTriggered: { win.tt += 0.033; if (!spin.pressed) win.yaw += 0.0035 }
  }
  readonly property real rr: Math.min(width, height) * 0.36

  Rectangle {
    anchors.fill: parent
    color: Qt.rgba(0, 0, 0, 0.62)
    opacity: win.shown ? 1 : 0
    Behavior on opacity { NumberAnimation { duration: 220 } }
  }
  MouseArea {
    id: spin
    anchors.fill: parent
    property real px: 0
    property real py: 0
    property bool moved: false
    onPressed: function(m) { px = m.x; py = m.y; moved = false }
    onPositionChanged: function(m) {
      win.yaw += (m.x - px) * 0.006
      win.pitch = Math.max(-1.2, Math.min(1.2, win.pitch + (m.y - py) * 0.006))
      if (Math.abs(m.x - px) + Math.abs(m.y - py) > 2) moved = true
      px = m.x; py = m.y
    }
    onClicked: function(m) {
      var dx = m.x - stage.x, dy = m.y - stage.y
      if (!moved && dx * dx + dy * dy > win.rr * win.rr * 1.5) win.s.closeAll()
    }
  }

  Item {
    id: stage
    x: win.width / 2; y: win.height / 2 - 26
    width: 0; height: 0
    scale: win.shown ? 1 : 0.55
    opacity: win.shown ? 1 : 0
    Behavior on scale { NumberAnimation { duration: 320; easing.type: Easing.OutBack } }
    Behavior on opacity { NumberAnimation { duration: 200 } }

    Planet {
      x: -width / 2; y: -height / 2
      width: win.rr * 2.16; height: width
      surfaceUrl: Qt.resolvedUrl("cosmos/moon.jpg")
      cloudsUrl: Qt.resolvedUrl("cosmos/moon.jpg")
      spin: -win.yaw / (2 * Math.PI)
      tilt: 0
      sunX: -0.3; sunY: 0.3; sunZ: 0.9
      glow: 0.14; rim: "#ffffff"
    }

    Repeater {
      model: win.hits
      delegate: Item {
        id: ic
        required property var modelData
        required property int index
        // Spirale de Fibonacci : des points réguliers sur la sphère.
        readonly property int n: Math.max(1, win.hits.length)
        readonly property real py0: n === 1 ? 0 : 1 - 2 * (index + 0.5) / n
        readonly property real rad: Math.sqrt(Math.max(0, 1 - py0 * py0))
        readonly property real th: index * 2.399963
        readonly property real x0: Math.cos(th) * rad
        readonly property real z0: Math.sin(th) * rad
        readonly property real x1: x0 * Math.cos(win.yaw) + z0 * Math.sin(win.yaw)
        readonly property real z1: -x0 * Math.sin(win.yaw) + z0 * Math.cos(win.yaw)
        readonly property real y2: py0 * Math.cos(win.pitch) - z1 * Math.sin(win.pitch)
        readonly property real z2: py0 * Math.sin(win.pitch) + z1 * Math.cos(win.pitch)
        readonly property real k: n === 1 ? 1 : Math.max(0, z2)
        visible: z2 > -0.05 || n === 1
        x: (n === 1 ? 0 : x1 * win.rr * 1.02) - width / 2
        y: (n === 1 ? 0 : y2 * win.rr * 1.02) - height / 2
        z: 10 + z2
        width: 66; height: 62
        scale: (ima.containsMouse ? 1.3 : 1) * (n === 1 ? 2 : (0.55 + 0.6 * k))
        opacity: 0.35 + 0.65 * k
        Behavior on scale { NumberAnimation { duration: 120 } }
        IconImage {
          anchors.horizontalCenter: parent.horizontalCenter
          width: 38; height: 38
          source: win.s.appIcon(ic.modelData)
          asynchronous: true
        }
        Rectangle {
          anchors.horizontalCenter: parent.horizontalCenter; y: 42
          visible: ic.k > 0.55 || ima.containsMouse
          width: Math.min(66, lbl.implicitWidth + 8); height: 14; radius: 3
          color: Qt.rgba(0, 0, 0, 0.72)
          Text {
            id: lbl
            anchors.centerIn: parent
            width: Math.min(implicitWidth, 60); elide: Text.ElideRight
            text: win.s.appName(ic.modelData)
            font.family: win.font; font.pixelSize: 9; color: "white"
          }
        }
        MouseArea {
          id: ima
          anchors.fill: parent; hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: { win.s.launch(ic.modelData); win.s.closeAll() }
        }
      }
    }
  }

  Rectangle {
    anchors.horizontalCenter: parent.horizontalCenter
    y: stage.y + win.rr + 30
    width: 400; height: 38; radius: 9
    color: win.s.alpha(win.s.surface, 0.92)
    border.width: 1; border.color: win.s.alpha(win.s.primary, 0.5)
    TextInput {
      id: input
      x: 14; width: parent.width - 28; anchors.verticalCenter: parent.verticalCenter
      font.family: win.font; font.pixelSize: 13; color: win.s.colOnSurface
      selectionColor: win.s.primary; focus: true; clip: true
      onTextChanged: win.query = text
      Keys.onEscapePressed: win.s.closeAll()
      Keys.onReturnPressed: { if (win.hits.length) { win.s.launch(win.hits[0]); win.s.closeAll() } }
    }
    Text {
      visible: input.text === ""
      x: 14; anchors.verticalCenter: parent.verticalCenter
      text: T.t("Chercher en orbite…")
      font.family: win.font; font.pixelSize: 13; color: win.s.colOnSurfaceVariant
    }
  }
}
