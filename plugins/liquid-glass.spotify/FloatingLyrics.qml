import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.Commons
import qs.Commons as Commons
import qs.Ui

// Widget de paroles flottant : carte de verre déplaçable (glisser n'importe
// où), au-dessus des fenêtres. Ligne en cours + ligne suivante, pochette.
// Position mémorisée dans ~/.cache/liquid-glass/widget-pos.json.
PanelWindow {
  id: win

  property var service: null
  readonly property bool wanted: !!service && service.lyricsWidget && service.hasTrack && !service.karaokeOpen

  property real posX: -1
  property real posY: -1

  visible: wanted
  color: "transparent"
  implicitWidth: 440
  implicitHeight: 112
  anchors { top: true; left: true }
  margins.left: posX >= 0 ? posX : (screen ? screen.width - implicitWidth - 24 : 24)
  margins.top: posY >= 0 ? posY : 64
  exclusionMode: ExclusionMode.Ignore
  WlrLayershell.layer: WlrLayer.Top
  WlrLayershell.namespace: "liquid-glass-lyrics-widget"
  WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

  FileView {
    id: posFile
    path: Quickshell.env("HOME") + "/.cache/liquid-glass/widget-pos.json"
    atomicWrites: true
    printErrors: false
    onLoaded: {
      try { var p = JSON.parse(text()); win.posX = Number(p.x); win.posY = Number(p.y) } catch (e) {}
    }
  }

  readonly property bool dark: Commons.Color.background.hslLightness < 0.5
  readonly property string line: {
    if (!service) return ""
    if (service.lyricsSynced) return service.currentLine !== "" ? service.currentLine : "♪"
    return service.title
  }
  readonly property string sub: {
    if (!service) return ""
    if (service.lyricsSynced) return service.nextLine
    return service.artist + (service.lyricsLoading ? "" : " · paroles indisponibles")
  }

  BorderSurface {
    id: card
    anchors.fill: parent
    radius: 22
    color: Util.alpha(Commons.Color.popups.background, win.dark ? 0.55 : 0.62)
    borderSpec: Border.surfaceSpec("popups", "border", Commons.Color.popups.border, 1)

    Item {
      id: art
      x: 14
      anchors.verticalCenter: parent.verticalCenter
      width: 84; height: 84
      Image {
        id: artImg
        anchors.fill: parent
        source: win.service && win.service.coverPath !== "" ? "file://" + win.service.coverPath : ""
        sourceSize: Qt.size(168, 168)
        fillMode: Image.PreserveAspectCrop
        visible: false
      }
      Rectangle { id: artMask; anchors.fill: parent; radius: 12; visible: false; layer.enabled: true }
      MultiEffect {
        anchors.fill: parent
        source: artImg
        maskEnabled: true
        maskSource: artMask
        visible: artImg.status === Image.Ready
      }
      Rectangle {
        anchors.fill: parent; radius: 12
        visible: artImg.status !== Image.Ready
        color: win.service ? win.service.accent : Commons.Color.accent
        opacity: 0.5
      }
    }

    Column {
      anchors.left: art.right
      anchors.leftMargin: 16
      anchors.right: parent.right
      anchors.rightMargin: 18
      anchors.verticalCenter: parent.verticalCenter
      spacing: 6

      Text {
        id: current
        width: parent.width
        textFormat: Text.PlainText
        text: win.line
        font.family: "Inter"
        font.pixelSize: 21
        font.weight: Font.Bold
        font.letterSpacing: -0.3
        color: Commons.Color.popups.text
        wrapMode: Text.WordWrap
        maximumLineCount: 2
        elide: Text.ElideRight
        Behavior on text {
          SequentialAnimation {
            NumberAnimation { target: current; property: "opacity"; to: 0.2; duration: 110 }
            PropertyAction {}
            NumberAnimation { target: current; property: "opacity"; to: 1; duration: 220; easing.type: Easing.OutCubic }
          }
        }
      }
      Text {
        width: parent.width
        textFormat: Text.PlainText
        text: win.sub
        visible: text !== ""
        font.family: "Inter"
        font.pixelSize: 14
        color: Commons.Color.popups.text
        opacity: 0.55
        elide: Text.ElideRight
      }
    }
  }

  // Glisser pour déplacer ; double-clic pour ouvrir le karaoké.
  MouseArea {
    anchors.fill: parent
    cursorShape: pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor
    property point origin
    property point start
    onPressed: function(m) {
      start = Qt.point(win.margins.left, win.margins.top)
      origin = mapToGlobal(m.x, m.y)
    }
    onPositionChanged: function(m) {
      if (!pressed) return
      var g = mapToGlobal(m.x, m.y)
      var sw = win.screen ? win.screen.width : 1920
      var sh = win.screen ? win.screen.height : 1080
      win.posX = Math.max(0, Math.min(sw - win.width, start.x + g.x - origin.x))
      win.posY = Math.max(0, Math.min(sh - win.height, start.y + g.y - origin.y))
    }
    onReleased: posFile.setText(JSON.stringify({ x: Math.round(win.posX), y: Math.round(win.posY) }) + "\n")
    onDoubleClicked: if (win.service) win.service.karaokeOpen = true
  }
}
