import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire
import Quickshell.Wayland
import Quickshell.Widgets
import "T.js" as T

// Style Île, bureau : horloge large, carte musique, tous deux à glisser. Pendant le glisser,
// la grille apparaît avec deux guides et la position, et le widget s'aimante à la grille.
PanelWindow {
  id: win
  property var service: null
  readonly property var s: service

  color: "transparent"
  anchors { top: true; bottom: true; left: true; right: true }
  exclusionMode: ExclusionMode.Ignore
  mask: Region { regions: [ clockRegion, cardRegion ] }
  Region { id: clockRegion; item: clock }
  Region { id: cardRegion; item: card }
  WlrLayershell.layer: WlrLayer.Bottom
  WlrLayershell.namespace: "liquid-glass-linux-ile"
  WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

  readonly property color ink: "#c9c2cc"
  readonly property color sub: "#8a8490"
  readonly property int cell: 40
  property date now: new Date()
  Timer { interval: 1000; repeat: true; running: true; onTriggered: win.now = new Date() }

  function en(fmt) { return Qt.locale("en_US").toString(win.now, fmt).toUpperCase() }
  property int face: 0
  readonly property string dateLine: en("dd") + " | " + en("MM") + " | " + en("yyyy")

  // Grille d'édition
  readonly property bool editing: clockDrag.active || cardDrag.active
  property real guideX: 0
  property real guideY: 0
  Canvas {
    id: grid
    anchors.fill: parent
    opacity: win.editing ? 1 : 0
    visible: opacity > 0
    Behavior on opacity { NumberAnimation { duration: 220 } }
    onWidthChanged: requestPaint()
    onHeightChanged: requestPaint()
    onPaint: {
      var c = getContext("2d")
      c.reset()
      c.strokeStyle = Qt.rgba(0.79, 0.76, 0.8, 0.13)
      c.lineWidth = 1
      c.beginPath()
      for (var x = 0.5; x < width; x += win.cell) { c.moveTo(x, 0); c.lineTo(x, height) }
      for (var y = 0.5; y < height; y += win.cell) { c.moveTo(0, y); c.lineTo(width, y) }
      c.stroke()
    }
  }
  Rectangle { visible: win.editing; x: win.guideX; width: 1; height: parent.height; color: Qt.rgba(0.79, 0.76, 0.8, 0.5) }
  Rectangle { visible: win.editing; y: win.guideY; width: parent.width; height: 1; color: Qt.rgba(0.79, 0.76, 0.8, 0.5) }
  Rectangle {
    visible: win.editing
    x: win.guideX - 7; y: win.guideY - 7; width: 14; height: 14; rotation: 45
    color: "#2c2933"; border.color: win.ink; border.width: 1
    Rectangle { anchors.centerIn: parent; width: 4; height: 4; radius: 2; color: win.ink }
  }
  Text {
    visible: win.editing
    x: win.guideX + 12; y: win.guideY - 22
    text: Math.round(win.guideX) + " × " + Math.round(win.guideY)
    color: win.ink; font.family: "Michroma"; font.pixelSize: 10
  }

  function place(it, key, dx, dy) {
    var p = s.layoutPos[key]
    it.x = p ? Math.min(p.x, width - it.width) : width * dx
    it.y = p ? Math.min(p.y, height - it.height) : height * dy
  }
  // Réglage du thème : aimanter à la grille (sinon, position libre au pixel près).
  function snap(v) { return s.opt("ile_snap", true) === false ? Math.round(v) : Math.round(v / cell) * cell }
  Component.onCompleted: { place(clock, "ile:clock", 0.4, 0.17); place(card, "ile:card", 0.055, 0.56) }
  onWidthChanged: { place(clock, "ile:clock", 0.4, 0.17); place(card, "ile:card", 0.055, 0.56) }

  // Horloge : clic pour passer de l'heure au jour, puis au mois.
  Item {
    id: clock
    width: Math.max(faceTime.width, faceDate.width) + 24
    height: 74
    Column {
      anchors.centerIn: parent
      spacing: 8
      IleWord {
        id: faceTime
        visible: win.face === 0
        anchors.horizontalCenter: parent.horizontalCenter
        text: Qt.formatTime(win.now, "HH:mm:ss")
        px: 26
        color: win.ink
      }
      Column {
        id: faceDate
        visible: win.face !== 0
        spacing: 6
        anchors.horizontalCenter: parent.horizontalCenter
        IleWord {
          anchors.horizontalCenter: parent.horizontalCenter
          text: win.en(win.face === 1 ? "dddd" : "MMMM")
          px: 24
          color: win.ink
        }
        IleWord { anchors.horizontalCenter: parent.horizontalCenter; text: win.dateLine; px: 15; color: win.ink }
      }
    }
    MouseArea {
      anchors.fill: parent
      cursorShape: Qt.PointingHandCursor
      drag.target: clock
      drag.threshold: 6
      onClicked: win.face = (win.face + 1) % 3
      onReleased: if (clockDrag.active) { clock.x = win.snap(clock.x); clock.y = win.snap(clock.y); win.s.savePos("ile:clock", clock.x, clock.y) }
    }
    DragHandler { id: clockDrag; target: clock; onActiveChanged: if (!active) { clock.x = win.snap(clock.x); clock.y = win.snap(clock.y); win.s.savePos("ile:clock", clock.x, clock.y) } }
    onXChanged: if (clockDrag.active) { win.guideX = x; win.guideY = y + height }
    onYChanged: if (clockDrag.active) { win.guideX = x; win.guideY = y + height }
  }

  // Carte musique : pochette, titre à droite dans la police de l'horloge, petit spectre.
  Rectangle {
    id: card
    width: 300; height: 120
    color: "#1f1c24"
    opacity: 0.94
    visible: win.s.hasTrack || win.s.resumeMode
    ClippingRectangle {
      id: art
      x: 16; y: 14; width: 92; height: 92; radius: 8
      color: "#35313b"
      Image {
        anchors.fill: parent
        source: win.s.cover
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        layer.enabled: true
      }
    }
    Text {
      anchors { right: parent.right; rightMargin: 16; top: parent.top; topMargin: 14; left: art.right; leftMargin: 14 }
      horizontalAlignment: Text.AlignRight
      text: win.s.trackTitle
      color: win.ink; font.family: "Michroma"; font.pixelSize: 14
      wrapMode: Text.WordWrap; maximumLineCount: 2; elide: Text.ElideRight
      textFormat: Text.PlainText
    }
    Text {
      anchors { right: parent.right; rightMargin: 16; bottom: spectrum.top; bottomMargin: 6; left: art.right; leftMargin: 14 }
      horizontalAlignment: Text.AlignRight
      text: win.s.trackArtist
      color: win.sub; font.family: "Michroma"; font.pixelSize: 8; elide: Text.ElideRight
      textFormat: Text.PlainText
    }
    Row {
      id: spectrum
      anchors { right: parent.right; rightMargin: 16; bottom: parent.bottom; bottomMargin: 14 }
      height: 14; spacing: 1
      Repeater {
        model: 44
        Rectangle {
          required property int index
          anchors.bottom: parent.bottom
          width: 2
          height: 1 + 13 * Math.min(1, Number((win.s.cavaValues || [])[Math.floor(index * (win.s.cavaValues || []).length / 44)] || 0))
          color: win.ink
        }
      }
    }
    MouseArea {
      anchors.fill: parent
      cursorShape: Qt.PointingHandCursor
      onClicked: win.s.playPause()
    }
    DragHandler { id: cardDrag; target: card; onActiveChanged: if (!active) { card.x = win.snap(card.x); card.y = win.snap(card.y); win.s.savePos("ile:card", card.x, card.y) } }
    onXChanged: if (cardDrag.active) { win.guideX = x; win.guideY = y }
    onYChanged: if (cardDrag.active) { win.guideX = x; win.guideY = y }
  }
}
