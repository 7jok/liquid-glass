import QtQuick
import QtQuick.Effects
import Quickshell
import qs.Commons

// Lecture en cours façon macOS, teintée par la palette de la pochette :
// fond = pochette très floutée + voile des couleurs dominantes ; pochette, titre,
// artiste, progression, commandes ; en bas, les 6 couleurs de la palette
// (clic = copie le code hexadécimal).
Tile {
  id: w
  readonly property var p: svc ? svc.player : null
  readonly property var pal: svc ? svc.palette : null
  readonly property var swatches: pal && pal.colors ? pal.colors : []
  readonly property color c1: swatches.length > 0 ? swatches[0] : (svc && svc.dark ? "#2c2c2e" : "#e5e5ea")
  readonly property color c2: swatches.length > 1 ? swatches[1] : c1
  readonly property color accentC: pal && pal.accent ? pal.accent : "#ff2d55"
  // Texte clair ou sombre selon la luminance du fond.
  readonly property bool lightText: (0.299 * c1.r + 0.587 * c1.g + 0.114 * c1.b) < 0.62
  readonly property color ink: lightText ? "white" : "#1d1d1f"
  readonly property color inkDim: lightText ? Qt.rgba(1, 1, 1, 0.72) : Qt.rgba(0, 0, 0, 0.6)

  property real pos: 0
  readonly property real len: p && p.lengthSupported ? p.length : 0
  Timer {
    interval: 1000; repeat: true; triggeredOnStart: true
    running: w.visible && !!w.p
    onTriggered: { if (w.p) { w.p.positionChanged(); w.pos = w.p.position } }
  }
  function fmt(s) { s = Math.max(0, Math.floor(s)); return Math.floor(s / 60) + ":" + ("0" + s % 60).slice(-2) }

  tint: "transparent"

  // ---- fond : pochette floutée + dégradé de palette
  Item {
    id: backdrop
    anchors.fill: parent
    layer.enabled: true
    layer.effect: MultiEffect {
      maskEnabled: true
      maskSource: roundMask
      maskThresholdMin: 0.5
      maskSpreadAtMin: 1.0
    }
    Image {
      id: blurSrc
      anchors.fill: parent
      source: svc ? svc.coverSource : ""
      fillMode: Image.PreserveAspectCrop
      sourceSize: Qt.size(96, 96)
      asynchronous: true
      visible: false
    }
    MultiEffect {
      anchors.fill: parent
      source: blurSrc
      blurEnabled: true
      blur: 1.0
      blurMax: 48
      saturation: 0.2
    }
    Rectangle {
      anchors.fill: parent
      gradient: Gradient {
        orientation: Gradient.Horizontal
        GradientStop { position: 0; color: Qt.rgba(w.c1.r, w.c1.g, w.c1.b, 0.78) }
        GradientStop { position: 1; color: Qt.rgba(w.c2.r, w.c2.g, w.c2.b, 0.62) }
      }
    }
  }
  Item {
    id: roundMask
    anchors.fill: parent
    layer.enabled: true
    visible: false
    Rectangle { anchors.fill: parent; radius: w.radius; color: "black" }
  }
  Rectangle {
    anchors.fill: parent; radius: w.radius; color: "transparent"
    border.width: 1; border.color: Qt.rgba(1, 1, 1, 0.2)
  }

  // ---- pochette
  Item {
    id: art
    width: w.height - 26 - 22; height: width
    x: 13; y: 13
    Image {
      id: artImg
      anchors.fill: parent
      source: svc ? svc.coverSource : ""
      fillMode: Image.PreserveAspectCrop
      sourceSize: Qt.size(256, 256)
      asynchronous: true
      visible: false
    }
    Item {
      id: artMask
      anchors.fill: parent
      layer.enabled: true
      visible: false
      Rectangle { anchors.fill: parent; radius: 12; color: "black" }
    }
    MultiEffect {
      anchors.fill: parent
      source: artImg
      maskEnabled: true
      maskSource: artMask
      maskThresholdMin: 0.5
      maskSpreadAtMin: 1.0
      shadowEnabled: true
      shadowOpacity: 0.35
      shadowBlur: 0.6
      shadowVerticalOffset: 3
    }
  }

  // ---- titre, artiste, progression, commandes
  Column {
    anchors { left: art.right; leftMargin: 14; right: parent.right; rightMargin: 14; top: parent.top; topMargin: 15 }
    spacing: 2
    Text {
      width: parent.width; elide: Text.ElideRight; textFormat: Text.PlainText
      text: w.p ? (w.p.trackTitle || "") : ""
      font.family: w.font; font.pixelSize: 14; font.weight: Font.DemiBold
      color: w.ink
    }
    Text {
      width: parent.width; elide: Text.ElideRight; textFormat: Text.PlainText
      text: w.p ? (w.p.trackArtist || "") : ""
      font.family: w.font; font.pixelSize: 12
      color: w.inkDim
    }
    Item { width: 1; height: 8 }
    Rectangle {
      width: parent.width; height: 4; radius: 2
      color: Qt.rgba(w.ink.r, w.ink.g, w.ink.b, 0.25)
      Rectangle {
        width: w.len > 0 ? parent.width * Math.min(1, w.pos / w.len) : 0
        height: parent.height; radius: 2
        color: w.ink
        Behavior on width { NumberAnimation { duration: 900 } }
      }
      MouseArea {
        anchors.fill: parent; anchors.margins: -6
        cursorShape: Qt.PointingHandCursor
        onClicked: function(m) { if (w.p && w.p.canSeek && w.len > 0) { w.p.position = Math.max(0, Math.min(1, (m.x - 6) / (width - 12))) * w.len; w.pos = w.p.position } }
      }
    }
    Item {
      width: parent.width; height: 14
      Text { text: w.fmt(w.pos); font.family: w.font; font.pixelSize: 9; color: w.inkDim; anchors.left: parent.left; anchors.bottom: parent.bottom }
      Text { text: w.len > 0 ? "-" + w.fmt(w.len - w.pos) : ""; font.family: w.font; font.pixelSize: 9; color: w.inkDim; anchors.right: parent.right; anchors.bottom: parent.bottom }
    }
    Row {
      anchors.horizontalCenter: parent.horizontalCenter
      spacing: 18
      component Btn: Text {
        property var act: null
        font.family: Style.font.family
        color: w.ink
        scale: ma.pressed ? 0.85 : 1
        Behavior on scale { NumberAnimation { duration: 90 } }
        MouseArea { id: ma; anchors.fill: parent; anchors.margins: -6; cursorShape: Qt.PointingHandCursor; onClicked: if (parent.act) parent.act() }
      }
      Btn { text: ""; font.pixelSize: 15; anchors.verticalCenter: parent.verticalCenter; act: function() { if (w.p && w.p.canGoPrevious) w.p.previous() } }
      Btn { text: w.p && w.p.isPlaying ? "" : ""; font.pixelSize: 20; anchors.verticalCenter: parent.verticalCenter; act: function() { if (w.p) w.p.togglePlaying() } }
      Btn { text: ""; font.pixelSize: 15; anchors.verticalCenter: parent.verticalCenter; act: function() { if (w.p && w.p.canGoNext) w.p.next() } }
    }
  }

  // ---- palette de la pochette
  Row {
    id: swatchRow
    anchors { left: parent.left; leftMargin: 13; bottom: parent.bottom; bottomMargin: 11 }
    spacing: 6
    property string copied: ""
    Repeater {
      model: w.swatches
      Rectangle {
        required property string modelData
        width: 13; height: 13; radius: 7
        color: modelData
        border.width: 1.5
        border.color: Qt.rgba(1, 1, 1, swatchRow.copied === modelData ? 1 : 0.55)
        scale: sm.containsMouse ? 1.25 : 1
        Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutBack } }
        MouseArea {
          id: sm; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
          onClicked: { Quickshell.execDetached(["wl-copy", parent.modelData]); swatchRow.copied = parent.modelData; copiedReset.restart() }
        }
      }
    }
  }
  Text {
    anchors { left: swatchRow.right; leftMargin: 8; verticalCenter: swatchRow.verticalCenter }
    text: swatchRow.copied !== "" ? swatchRow.copied + " copié" : (w.swatches.length ? "Palette" : "")
    font.family: w.font; font.pixelSize: 9; font.weight: Font.DemiBold
    color: w.inkDim
  }
  Timer { id: copiedReset; interval: 1600; onTriggered: swatchRow.copied = "" }
}
