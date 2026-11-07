import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Services.Mpris
import Quickshell.Widgets
import qs.Commons
import "T.js" as T

// Lecture en cours façon macOS, teintée par la couleur de la pochette.
//   small  (1×1) : pochette, titre, lecture
//   medium (2×1) : pochette, titre, « artiste — album », progression,
//                  aléatoire · précédent · lecture · suivant · répéter
//   large  (2×2) : grande pochette + tout le reste
// Bouton bulle (en haut à droite) : les paroles synchronisées remplacent la
// pochette et le titre, ligne chantée en gras, les voisines floutées.
Tile {
  id: w
  property string size: "medium"
  property bool lyricsMode: false
  signal lyricsToggled()
  // Pochette « sortie » au-dessus du widget (MusicWindow) : elle quitte la carte
  // et le titre glisse à sa place. Clic sur la pochette = artToggled().
  property bool artOut: false
  signal artToggled()
  property alias artItem: art
  readonly property bool small: size === "small"
  readonly property bool large: size === "large"
  function g(cp) { return String.fromCodePoint(cp) }

  readonly property var p: svc ? svc.player : null
  readonly property var pal: svc ? svc.palette : null
  readonly property var swatches: pal && pal.colors ? pal.colors : []
  // Teinte : la couleur sombre la plus saturée de la palette, sinon l'accent.
  readonly property color base: {
    var best = null, score = -1
    for (var i = 0; i < swatches.length; i++) {
      var c = Qt.color(swatches[i])
      var l = c.hslLightness, s = c.hslSaturation
      var sc = s * (1 - Math.abs(l - 0.32) * 1.6)
      if (l > 0.08 && l < 0.7 && sc > score) { score = sc; best = c }
    }
    if (best) return best
    return pal && pal.accent ? pal.accent : (svc && svc.dark ? "#2c2c2e" : "#6e6e73")
  }
  readonly property color tintTop: Qt.hsla(base.hslHue, Math.min(0.55, base.hslSaturation), Math.min(0.42, Math.max(0.2, base.hslLightness)), 0.86)
  readonly property color tintBottom: Qt.hsla(base.hslHue, Math.min(0.5, base.hslSaturation), Math.max(0.12, Math.min(0.3, base.hslLightness * 0.7)), 0.9)
  readonly property color ink: "white"
  readonly property color inkDim: Qt.rgba(1, 1, 1, 0.62)

  property real pos: 0
  readonly property real len: p && p.lengthSupported ? p.length : 0
  // Paroles synchronisées publiées par liquid-glass.spotify (now-playing.json).
  readonly property var lyrics: svc && svc.np && p && svc.np.title === p.trackTitle && Array.isArray(svc.np.lyrics) ? svc.np.lyrics : []
  readonly property bool hasLyrics: lyrics.length > 0
  readonly property bool showLyrics: lyricsMode && hasLyrics && !small
  property int lineIndex: -1
  Timer {
    interval: w.showLyrics && w.p && w.p.isPlaying ? 250 : 1000
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

  // ---------------------------------------------------------------- fond
  // Coins arrondis par découpe directe (pas de calque masqué : net à 1,5× et sans
  // texture à recréer quand la taille change).
  ClippingRectangle {
    id: backdrop
    anchors.fill: parent
    radius: w.radius
    color: "transparent"
    Image {
      id: blurSrc
      anchors.fill: parent
      source: svc ? svc.coverSource : ""
      fillMode: Image.PreserveAspectCrop
      sourceSize: Qt.size(64, 64)
      asynchronous: true
      visible: false
    }
    MultiEffect { anchors.fill: parent; source: blurSrc; blurEnabled: true; blur: 1.0; blurMax: 64; saturation: 0.1 }
    Rectangle {
      anchors.fill: parent
      gradient: Gradient {
        GradientStop { position: 0; color: w.tintTop }
        GradientStop { position: 1; color: w.tintBottom }
      }
    }
    // Reflet du verre.
    Rectangle {
      anchors.fill: parent
      gradient: Gradient {
        GradientStop { position: 0; color: Qt.rgba(1, 1, 1, 0.10) }
        GradientStop { position: 0.4; color: Qt.rgba(1, 1, 1, 0) }
      }
    }
  }
  Rectangle {
    anchors.fill: parent; radius: w.radius; color: "transparent"
    border.width: 1; border.color: Qt.rgba(1, 1, 1, 0.22)
  }

  readonly property real pad: small ? 14 : 18

  // --------------------------------------------------------------- en-tête
  Item {
    id: header
    x: w.pad; y: w.pad
    width: w.width - 2 * w.pad
    height: w.small ? w.height - 2 * w.pad : Math.max(30, transport.y - w.pad - (w.large ? 14 : 8))
    opacity: w.showLyrics ? 0 : 1
    scale: w.showLyrics ? 0.92 : 1
    visible: opacity > 0.01
    Behavior on opacity { NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }
    Behavior on scale { NumberAnimation { duration: 420; easing.type: Easing.OutBack; easing.overshoot: 2.2 } }

    Item {
      id: art
      readonly property real side: w.small ? Math.round(w.width * 0.44)
                                   : (w.large ? Math.min(header.height, Math.round(header.width * 0.55)) : header.height)
      width: side; height: side
      y: w.large ? Math.round((header.height - side) / 2) : 0
      opacity: w.artOut ? 0 : 1
      Behavior on opacity { NumberAnimation { duration: 160 } }
      // Un simple tap (le glisser-déposer de la carte reste possible depuis la pochette).
      TapHandler { onTapped: w.artToggled() }
      HoverHandler { cursorShape: Qt.PointingHandCursor }
      readonly property real r: w.large ? 14 : 10
      RectangularShadow {
        anchors.fill: parent
        offset.y: 4
        radius: art.r
        blur: 16
        spread: 0
        color: Qt.rgba(0, 0, 0, 0.38)
      }
      ClippingRectangle {
        anchors.fill: parent
        radius: art.r
        color: Qt.rgba(1, 1, 1, 0.08)
        Image {
          id: artImg
          anchors.fill: parent
          source: svc ? svc.coverSource : ""
          fillMode: Image.PreserveAspectCrop
          sourceSize: Qt.size(420, 420)
          asynchronous: true
          smooth: true; mipmap: true
        }
      }
      // Nouveau morceau : la pochette rebondit.
      property string key: w.p ? (w.p.trackTitle || "") : ""
      onKeyChanged: artPop.restart()
      SequentialAnimation {
        id: artPop
        NumberAnimation { target: art; property: "scale"; to: 0.82; duration: 110; easing.type: Easing.OutQuad }
        NumberAnimation { target: art; property: "scale"; to: 1; duration: 640; easing.type: Easing.OutBack; easing.overshoot: 2.6 }
      }
    }

    // Petit format : lecture en haut à droite, titre en bas.
    Btn {
      visible: w.small
      anchors.right: parent.right; anchors.top: parent.top
      glyph: w.p && w.p.isPlaying ? 0xF03E4 : 0xF040A; size: 26
      act: function() { if (w.p) w.p.togglePlaying() }
    }
    Column {
      visible: w.small
      anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom
      spacing: 1
      Text { width: parent.width; elide: Text.ElideRight; textFormat: Text.PlainText; text: w.p ? (w.p.trackTitle || "") : ""; font.family: w.font; font.pixelSize: 13; font.weight: Font.DemiBold; color: w.ink }
      Text { width: parent.width; elide: Text.ElideRight; textFormat: Text.PlainText; text: w.p ? (w.p.trackArtist || "") : ""; font.family: w.font; font.pixelSize: 11; color: w.inkDim }
    }

    // Moyen / grand : titre à droite de la pochette.
    Column {
      visible: !w.small
      anchors.left: parent.left; anchors.leftMargin: w.artOut ? 0 : art.side + 16
      Behavior on anchors.leftMargin { NumberAnimation { duration: 520; easing.type: Easing.OutBack; easing.overshoot: 1.4 } }
      anchors.right: parent.right; anchors.rightMargin: 34
      anchors.verticalCenter: w.large ? undefined : art.verticalCenter
      anchors.top: w.large ? art.top : undefined
      anchors.topMargin: w.large ? 6 : 0
      spacing: 3
      Text {
        width: parent.width; elide: Text.ElideRight; textFormat: Text.PlainText
        text: w.p ? (w.p.trackTitle || "") : ""
        wrapMode: w.large ? Text.WordWrap : Text.NoWrap; maximumLineCount: w.large ? 3 : 1
        font.family: w.font; font.pixelSize: w.large ? 19 : 16; font.weight: Font.DemiBold
        color: w.ink
      }
      Text {
        width: parent.width; elide: Text.ElideRight; textFormat: Text.PlainText
        text: w.p ? [w.p.trackArtist || "", w.p.trackAlbum || ""].filter(function(s) { return s !== "" }).join(" — ") : ""
        wrapMode: w.large ? Text.WordWrap : Text.NoWrap; maximumLineCount: w.large ? 2 : 1
        font.family: w.font; font.pixelSize: w.large ? 14 : 13
        color: w.inkDim
      }
    }
  }

  // ---------------------------------------------------------- paroles (bulle)
  ListView {
    id: lyricList
    x: w.pad; y: w.pad - 4
    width: w.width - 2 * w.pad - 30
    height: header.height + 8
    clip: true
    interactive: false
    model: w.showLyrics ? w.lyrics : []
    currentIndex: Math.max(0, w.lineIndex)
    highlightRangeMode: ListView.StrictlyEnforceRange
    preferredHighlightBegin: height * (w.large ? 0.34 : 0.3)
    preferredHighlightEnd: preferredHighlightBegin + 30
    highlightMoveDuration: 520
    highlightMoveVelocity: -1
    opacity: w.showLyrics ? 1 : 0
    visible: opacity > 0.01
    Behavior on opacity { NumberAnimation { duration: 300 } }
    layer.enabled: true
    layer.effect: MultiEffect { maskEnabled: true; maskSource: lyricFade; maskThresholdMin: 0.0; maskSpreadAtMin: 0.0 }
    delegate: Text {
      required property var modelData
      required property int index
      readonly property int dist: Math.abs(index - w.lineIndex)
      readonly property bool current: index === w.lineIndex
      width: lyricList.width
      textFormat: Text.PlainText
      text: modelData.text === "" ? "♪" : modelData.text
      wrapMode: Text.WordWrap
      maximumLineCount: 2
      elide: Text.ElideRight
      topPadding: 5; bottomPadding: 5
      font.family: w.font
      font.pixelSize: w.large ? 19 : 16
      font.weight: current ? Font.Bold : Font.DemiBold
      color: w.ink
      opacity: current ? 1 : Math.max(0.15, 0.45 - dist * 0.08)
      Behavior on opacity { NumberAnimation { duration: 300 } }
      layer.enabled: !current
      layer.effect: MultiEffect { blurEnabled: true; blurMax: 16; blur: Math.min(1, 0.25 + 0.25 * dist) }
    }
  }
  Item {
    id: lyricFade
    width: lyricList.width; height: lyricList.height
    visible: false; layer.enabled: true
    Rectangle {
      anchors.fill: parent
      gradient: Gradient {
        GradientStop { position: 0.0; color: "transparent" }
        GradientStop { position: 0.18; color: "black" }
        GradientStop { position: 0.82; color: "black" }
        GradientStop { position: 1.0; color: "transparent" }
      }
    }
  }

  // Bouton bulle : paroles.
  Rectangle {
    visible: !w.small
    anchors.right: parent.right; anchors.top: parent.top
    anchors.rightMargin: 12; anchors.topMargin: 12
    width: 28; height: 28; radius: 14
    // Pochette en fond d'écran : la bulle met les paroles sur le fond (comme la vidéo) ;
    // sinon elle retourne la carte. Clic droit : toujours retourner la carte.
    readonly property bool onWall: !!svc && svc.coverWallpaper
    readonly property bool lit: onWall ? (!!svc && svc.lyricsDesktop) : w.lyricsMode
    color: lit ? Qt.rgba(1, 1, 1, 0.9) : Qt.rgba(1, 1, 1, bubbleMouse.containsMouse ? 0.2 : 0.12)
    opacity: w.hasLyrics ? 1 : 0.55
    scale: bubbleMouse.pressed ? 0.82 : 1
    Behavior on scale { NumberAnimation { duration: 260; easing.type: Easing.OutBack; easing.overshoot: 3 } }
    Behavior on color { ColorAnimation { duration: 150 } }
    Text { anchors.centerIn: parent; textFormat: Text.PlainText; text: w.g(0xF0369); font.family: Style.font.family; font.pixelSize: 15; color: parent.lit ? "#1d1d1f" : w.ink }
    MouseArea {
      id: bubbleMouse
      anchors.fill: parent; anchors.margins: -4
      hoverEnabled: true; cursorShape: Qt.PointingHandCursor
      acceptedButtons: Qt.LeftButton | Qt.RightButton
      onClicked: function(m) {
        if (!w.hasLyrics && !(m.button === Qt.LeftButton && parent.onWall && svc && svc.lyricsDesktop)) { noLyrics.restart(); return }
        if (m.button === Qt.RightButton || !parent.onWall) w.lyricsToggled()
        else Quickshell.execDetached(["omarchy-shell", "liquid-glass.spotify", "desktop"])
      }
    }
  }
  // « Pas de paroles » : petite bulle qui apparaît puis s'efface.
  Rectangle {
    id: noLyricsTip
    anchors.right: parent.right; anchors.rightMargin: 46
    anchors.top: parent.top; anchors.topMargin: 14
    width: nlText.implicitWidth + 16; height: 24; radius: 12
    color: Qt.rgba(0, 0, 0, 0.55)
    opacity: 0
    visible: opacity > 0.01
    Text { id: nlText; anchors.centerIn: parent; textFormat: Text.PlainText; text: T.t("Pas de paroles pour ce titre"); font.family: w.font; font.pixelSize: 11; font.weight: Font.DemiBold; color: "white" }
    SequentialAnimation {
      id: noLyrics
      NumberAnimation { target: noLyricsTip; property: "opacity"; to: 1; duration: 160 }
      PauseAnimation { duration: 1600 }
      NumberAnimation { target: noLyricsTip; property: "opacity"; to: 0; duration: 400 }
    }
  }

  // -------------------------------------------------- progression + commandes
  Column {
    id: transport
    visible: !w.small
    x: w.pad
    width: w.width - 2 * w.pad
    anchors.bottom: parent.bottom
    anchors.bottomMargin: w.large ? 18 : 12
    spacing: 4
    Rectangle {
      id: bar
      width: parent.width; height: barMouse.containsMouse ? 8 : 5; radius: height / 2
      color: Qt.rgba(1, 1, 1, 0.22)
      Behavior on height { NumberAnimation { duration: 220; easing.type: Easing.OutBack; easing.overshoot: 3 } }
      Rectangle {
        width: w.len > 0 ? parent.width * Math.min(1, w.pos / w.len) : 0
        height: parent.height; radius: height / 2
        color: Qt.rgba(1, 1, 1, 0.85)
        Behavior on width { NumberAnimation { duration: 900 } }
      }
      MouseArea {
        id: barMouse
        anchors.fill: parent; anchors.margins: -8
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: function(m) { w.seekAt((m.x - 8) / (width - 16)) }
      }
    }
    Item {
      width: parent.width; height: 13
      Text { text: w.fmt(w.pos); font.family: w.font; font.pixelSize: 10; font.features: { "tnum": 1 }; color: w.inkDim; anchors.left: parent.left }
      Text { text: w.len > 0 ? "−" + w.fmt(w.len - w.pos) : ""; font.family: w.font; font.pixelSize: 10; font.features: { "tnum": 1 }; color: w.inkDim; anchors.right: parent.right }
    }
    Item {
      width: parent.width; height: 30
      Btn {
        anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter
        glyph: 0xF049D; size: 16
        dim: !(w.p && w.p.shuffle)
        act: function() { if (w.p && w.p.shuffleSupported) w.p.shuffle = !w.p.shuffle }
      }
      Row {
        anchors.centerIn: parent
        spacing: w.large ? 40 : 30
        Btn { anchors.verticalCenter: parent.verticalCenter; glyph: 0xF04AE; size: 24; act: function() { if (w.p && w.p.canGoPrevious) w.p.previous() } }
        Btn { anchors.verticalCenter: parent.verticalCenter; glyph: w.p && w.p.isPlaying ? 0xF03E4 : 0xF040A; size: 30; act: function() { if (w.p) w.p.togglePlaying() } }
        Btn { anchors.verticalCenter: parent.verticalCenter; glyph: 0xF04AD; size: 24; act: function() { if (w.p && w.p.canGoNext) w.p.next() } }
      }
      Btn {
        anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
        glyph: w.p && w.p.loopState === MprisLoopState.Track ? 0xF0458 : 0xF0456; size: 16
        dim: !(w.p && w.p.loopState !== MprisLoopState.None)
        act: function() {
          if (!w.p || !w.p.loopSupported) return
          w.p.loopState = w.p.loopState === MprisLoopState.None ? MprisLoopState.Playlist
                        : (w.p.loopState === MprisLoopState.Playlist ? MprisLoopState.Track : MprisLoopState.None)
        }
      }
    }
  }

  // Bouton à glyphe : rebond exagéré à l'appui.
  component Btn: Item {
    id: b
    property int glyph: 0
    property real size: 18
    property bool dim: false
    property var act: null
    width: Math.max(22, size + 6); height: width
    Text {
      anchors.centerIn: parent
      textFormat: Text.PlainText
      text: w.g(b.glyph)
      font.family: Style.font.family; font.pixelSize: b.size
      color: w.ink
      opacity: b.dim ? 0.5 : 1
      scale: bm.pressed ? 0.7 : (bm.containsMouse ? 1.12 : 1)
      Behavior on scale { NumberAnimation { duration: 320; easing.type: Easing.OutBack; easing.overshoot: 3.2 } }
    }
    MouseArea { id: bm; anchors.fill: parent; anchors.margins: -4; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: if (b.act) b.act() }
  }
}
