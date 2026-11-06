import QtQuick
import QtQuick.Effects
import Quickshell
import qs.Commons

// Lecture en cours façon macOS, teintée par la palette de la pochette.
// Trois tailles, comme les widgets de macOS :
//   small  (1×1) : pochette, titre, bouton lecture
//   medium (2×1) : pochette, titre, artiste, progression, commandes, palette
//   large  (2×2) : grande pochette, paroles en cours, progression, commandes, palette
// Fond = pochette très floutée + voile des couleurs dominantes.
// Palette : clic sur une couleur = copie du code hexadécimal.
Tile {
  id: w
  property string size: "medium"
  readonly property bool small: size === "small"
  readonly property bool large: size === "large"

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
  // Paroles synchronisées publiées par liquid-glass.spotify (grand format seulement).
  readonly property var lyrics: large && svc && svc.np && svc.np.title === (p ? p.trackTitle : "") && Array.isArray(svc.np.lyrics) ? svc.np.lyrics : []
  property int lineIndex: -1
  readonly property string lyricLine: lineIndex >= 0 && lineIndex < lyrics.length ? lyrics[lineIndex].text : ""
  readonly property string nextLyric: lineIndex + 1 < lyrics.length && lineIndex + 1 >= 0 ? lyrics[lineIndex + 1].text : ""
  Timer {
    interval: w.lyrics.length > 0 && w.p && w.p.isPlaying ? 300 : 1000
    repeat: true; triggeredOnStart: true
    running: w.visible && !!w.p
    onTriggered: {
      if (!w.p) return
      w.p.positionChanged()
      w.pos = w.p.position
      var t = w.pos + 0.25, i = -1
      while (i + 1 < w.lyrics.length && w.lyrics[i + 1].t <= t) i++
      w.lineIndex = i
    }
  }
  function fmt(s) { s = Math.max(0, Math.floor(s)); return Math.floor(s / 60) + ":" + ("0" + s % 60).slice(-2) }
  function seekAt(frac) {
    if (w.p && w.p.canSeek && w.len > 0) { w.p.position = Math.max(0, Math.min(1, frac)) * w.len; w.pos = w.p.position }
  }

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
        orientation: w.large ? Gradient.Vertical : Gradient.Horizontal
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

  // ---- pochette (taille et place selon le format)
  Item {
    id: art
    readonly property real side: w.small ? Math.round(w.width * 0.46)
                               : w.large ? Math.round(w.width * 0.42)
                               : w.height - 26 - 22
    width: side; height: side
    x: 13; y: 13
    Behavior on width { NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }
    Image {
      id: artImg
      anchors.fill: parent
      source: svc ? svc.coverSource : ""
      fillMode: Image.PreserveAspectCrop
      sourceSize: Qt.size(400, 400)
      asynchronous: true
      visible: false
    }
    Item {
      id: artMask
      anchors.fill: parent
      layer.enabled: true
      visible: false
      Rectangle { anchors.fill: parent; radius: w.large ? 16 : 12; color: "black" }
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

  component Btn: Text {
    property var act: null
    font.family: Style.font.family
    color: w.ink
    scale: ma.pressed ? 0.85 : 1
    Behavior on scale { NumberAnimation { duration: 90 } }
    MouseArea { id: ma; anchors.fill: parent; anchors.margins: -6; cursorShape: Qt.PointingHandCursor; onClicked: if (parent.act) parent.act() }
  }

  // ================================================================ petit
  Btn {
    visible: w.small
    anchors { right: parent.right; rightMargin: 16; top: parent.top; topMargin: 16 }
    text: String.fromCodePoint(w.p && w.p.isPlaying ? 0xF03E4 : 0xF040A)
    font.pixelSize: 24
    act: function() { if (w.p) w.p.togglePlaying() }
  }
  Column {
    visible: w.small
    anchors { left: parent.left; leftMargin: 14; right: parent.right; rightMargin: 14; bottom: parent.bottom; bottomMargin: 13 }
    spacing: 1
    Text { width: parent.width; elide: Text.ElideRight; textFormat: Text.PlainText; text: w.p ? (w.p.trackTitle || "") : ""; font.family: w.font; font.pixelSize: 13; font.weight: Font.DemiBold; color: w.ink }
    Text { width: parent.width; elide: Text.ElideRight; textFormat: Text.PlainText; text: w.p ? (w.p.trackArtist || "") : ""; font.family: w.font; font.pixelSize: 11; color: w.inkDim }
  }

  // ================================================================ moyen et grand
  Column {
    id: info
    visible: !w.small
    anchors {
      left: art.right; leftMargin: 14; right: parent.right; rightMargin: 14
      top: parent.top; topMargin: w.large ? 18 : 15
    }
    spacing: 2
    Text {
      width: parent.width; elide: Text.ElideRight; textFormat: Text.PlainText
      text: w.p ? (w.p.trackTitle || "") : ""
      font.family: w.font; font.pixelSize: w.large ? 17 : 14; font.weight: Font.DemiBold
      wrapMode: w.large ? Text.WordWrap : Text.NoWrap
      maximumLineCount: w.large ? 2 : 1
      color: w.ink
    }
    Text {
      width: parent.width; elide: Text.ElideRight; textFormat: Text.PlainText
      text: w.p ? (w.p.trackArtist || "") : ""
      font.family: w.font; font.pixelSize: w.large ? 13 : 12
      color: w.inkDim
    }
    Text {
      visible: w.large && text !== ""
      width: parent.width; elide: Text.ElideRight; textFormat: Text.PlainText
      text: w.p ? (w.p.trackAlbum || "") : ""
      font.family: w.font; font.pixelSize: 11
      color: w.inkDim; opacity: 0.8
    }
  }

  // Paroles en cours (grand format) : ligne chantée en gras, la suivante atténuée.
  Column {
    id: lyricBox
    visible: w.large
    anchors { left: parent.left; leftMargin: 16; right: parent.right; rightMargin: 16; top: art.bottom; topMargin: 14 }
    spacing: 4
    Text {
      width: parent.width; textFormat: Text.PlainText
      text: w.lyricLine !== "" ? w.lyricLine : (w.lyrics.length ? "♪" : (w.p && w.p.trackAlbum ? "" : ""))
      wrapMode: Text.WordWrap; maximumLineCount: 2; elide: Text.ElideRight
      font.family: w.font; font.pixelSize: 17; font.weight: Font.Bold
      color: w.ink
      Behavior on text { SequentialAnimation { NumberAnimation { target: lyricBox; property: "opacity"; to: 0.3; duration: 90 } PropertyAction {} NumberAnimation { target: lyricBox; property: "opacity"; to: 1; duration: 220 } } }
    }
    Text {
      width: parent.width; textFormat: Text.PlainText
      visible: text !== ""
      text: w.nextLyric
      elide: Text.ElideRight
      font.family: w.font; font.pixelSize: 13; font.weight: Font.DemiBold
      color: w.inkDim; opacity: 0.8
    }
  }

  // Progression + commandes : sous le titre (moyen) ou en bas (grand).
  Column {
    id: transport
    visible: !w.small
    anchors.left: w.large ? parent.left : art.right
    anchors.leftMargin: w.large ? 16 : 14
    anchors.right: parent.right
    anchors.rightMargin: w.large ? 16 : 14
    y: w.large ? w.height - height - 40 : info.y + info.height + 8
    spacing: 2
    Rectangle {
      width: parent.width; height: w.large ? 5 : 4; radius: height / 2
      color: Qt.rgba(w.ink.r, w.ink.g, w.ink.b, 0.25)
      Rectangle {
        width: w.len > 0 ? parent.width * Math.min(1, w.pos / w.len) : 0
        height: parent.height; radius: height / 2
        color: w.ink
        Behavior on width { NumberAnimation { duration: 900 } }
      }
      MouseArea {
        anchors.fill: parent; anchors.margins: -6
        cursorShape: Qt.PointingHandCursor
        onClicked: function(m) { w.seekAt((m.x - 6) / (width - 12)) }
      }
    }
    Item {
      width: parent.width; height: 14
      Text { text: w.fmt(w.pos); font.family: w.font; font.pixelSize: 9; font.features: { "tnum": 1 }; color: w.inkDim; anchors.left: parent.left; anchors.bottom: parent.bottom }
      Text { text: w.len > 0 ? "-" + w.fmt(w.len - w.pos) : ""; font.family: w.font; font.pixelSize: 9; font.features: { "tnum": 1 }; color: w.inkDim; anchors.right: parent.right; anchors.bottom: parent.bottom }
    }
    Row {
      anchors.horizontalCenter: parent.horizontalCenter
      spacing: w.large ? 30 : 18
      Btn { text: String.fromCodePoint(0xF04AE); font.pixelSize: w.large ? 18 : 15; anchors.verticalCenter: parent.verticalCenter; act: function() { if (w.p && w.p.canGoPrevious) w.p.previous() } }
      Btn { text: String.fromCodePoint(w.p && w.p.isPlaying ? 0xF03E4 : 0xF040A); font.pixelSize: w.large ? 26 : 20; anchors.verticalCenter: parent.verticalCenter; act: function() { if (w.p) w.p.togglePlaying() } }
      Btn { text: String.fromCodePoint(0xF04AD); font.pixelSize: w.large ? 18 : 15; anchors.verticalCenter: parent.verticalCenter; act: function() { if (w.p && w.p.canGoNext) w.p.next() } }
    }
  }

  // ---- palette de la pochette
  Row {
    id: swatchRow
    visible: !w.small
    anchors { left: parent.left; leftMargin: w.large ? 16 : 13; bottom: parent.bottom; bottomMargin: w.large ? 14 : 11 }
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
    visible: !w.small
    anchors { left: swatchRow.right; leftMargin: 8; verticalCenter: swatchRow.verticalCenter }
    text: swatchRow.copied !== "" ? swatchRow.copied + " copié" : (w.swatches.length ? "Palette" : "")
    font.family: w.font; font.pixelSize: 9; font.weight: Font.DemiBold
    color: w.inkDim
  }
  Timer { id: copiedReset; interval: 1600; onTriggered: swatchRow.copied = "" }
}
