import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Services.Pipewire
import qs.Commons
import qs.Commons as Commons
import qs.Ui

// Liquid Glass — mini-lecteur de la barre.
//   Barre : petite pochette + ligne de paroles en cours (ou « titre · artiste »).
//   Clic : popup façon macOS (pochette, progression déplaçable, contrôles, volume,
//   raccourcis paroles/karaoké/fond). Clic milieu : lecture/pause. Molette : piste.
// Tout l'état vient du service liquid-glass.spotify (aucun polling ici).
Panel {
  id: root
  moduleName: "liquid-glass.spotify"
  ipcTarget: "liquid-glass.spotify.popup"

  readonly property string uiFont: "Inter"
  readonly property string iconFont: Style.font.family
  readonly property color fg: Commons.Color.popups.text
  function g(cp) { return String.fromCodePoint(cp) }

  // Le service peut s'enregistrer après la barre : on le cherche jusqu'à le trouver.
  property var service: null
  Timer {
    interval: 300
    repeat: true
    running: !root.service
    triggeredOnStart: true
    onTriggered: if (root.bar && root.bar.shell) root.service = root.bar.shell.serviceFor("liquid-glass.spotify")
  }
  readonly property var s: service
  readonly property var player: s ? s.player : null
  readonly property bool active: !!s && s.hasTrack

  onOpenedChanged: if (s) { s.popupOpen = opened; if (opened) s.syncPosition() }

  function fmt(sec) {
    sec = Math.max(0, Math.floor(sec || 0))
    var m = Math.floor(sec / 60), r = sec % 60
    return m + ":" + (r < 10 ? "0" : "") + r
  }

  readonly property string barText: {
    if (!s) return ""
    if (s.lyricsBar && s.lyricsSynced && s.playing && s.currentLine !== "") return s.currentLine
    return s.title + (s.artist !== "" ? " · " + s.artist : "")
  }

  // Volume : celui du lecteur si exposé par MPRIS, sinon la sortie audio.
  readonly property var sink: Pipewire.defaultAudioSink
  PwObjectTracker { objects: root.sink ? [root.sink] : [] }
  readonly property bool playerVolume: !!player && player.volumeSupported && player.canControl
  readonly property real volume: playerVolume ? player.volume : (sink && sink.audio ? sink.audio.volume : 0)
  function setVolume(v) {
    v = Math.max(0, Math.min(1, v))
    if (playerVolume) player.volume = v
    else if (sink && sink.audio) sink.audio.volume = v
  }

  // ------------------------------------------------------------ barre
  visible: active
  implicitWidth: active ? pill.implicitWidth : 0
  implicitHeight: root.bar ? root.bar.barSize : Style.space(28)

  Item {
    id: pill
    anchors.fill: parent
    implicitWidth: Style.space(8) + art.width + Style.space(7) + Math.min(label.implicitWidth, Style.space(250)) + Style.space(10)

    Rectangle {
      anchors.centerIn: parent
      width: parent.width
      height: Style.space(22)
      radius: Style.space(6)
      color: root.bar ? root.bar.barForeground : Commons.Color.foreground
      opacity: root.opened ? 0.14 : (pillMouse.containsMouse ? 0.08 : 0)
      Behavior on opacity { NumberAnimation { duration: Style.duration(100) } }
    }

    Item {
      id: art
      x: Style.space(8)
      anchors.verticalCenter: parent.verticalCenter
      width: Style.space(17); height: width
      Image {
        id: artImg
        anchors.fill: parent
        source: root.s && root.s.coverPath !== "" ? "file://" + root.s.coverPath
              : (root.s && root.s.artUrl.indexOf("https://") === 0 ? root.s.artUrl : "")
        sourceSize: Qt.size(64, 64)
        fillMode: Image.PreserveAspectCrop
        visible: false
      }
      Rectangle { id: artMask; anchors.fill: parent; radius: Style.space(4); visible: false; layer.enabled: true }
      MultiEffect { anchors.fill: parent; source: artImg; maskEnabled: true; maskSource: artMask; visible: artImg.status === Image.Ready }
      Text {
        anchors.centerIn: parent
        visible: artImg.status !== Image.Ready
        textFormat: Text.PlainText
        text: root.g(0xF075A)
        font.family: root.iconFont
        font.pixelSize: Style.space(14)
        color: root.bar ? root.bar.barForeground : Commons.Color.foreground
      }
    }

    Text {
      id: label
      anchors.left: art.right
      anchors.leftMargin: Style.space(7)
      anchors.right: parent.right
      anchors.rightMargin: Style.space(10)
      anchors.verticalCenter: parent.verticalCenter
      textFormat: Text.PlainText
      text: root.barText
      elide: Text.ElideRight
      font.family: root.uiFont
      font.pixelSize: Style.font.body
      font.weight: Font.Medium
      color: root.bar ? root.bar.barForeground : Commons.Color.foreground
      opacity: root.s && root.s.playing ? 1 : 0.6
      Behavior on text {
        SequentialAnimation {
          NumberAnimation { target: label; property: "opacity"; to: 0.15; duration: 90 }
          PropertyAction {}
          NumberAnimation { target: label; property: "opacity"; to: root.s && root.s.playing ? 1 : 0.6; duration: 200; easing.type: Easing.OutCubic }
        }
      }
    }

    MouseArea {
      id: pillMouse
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
      onClicked: function(m) {
        if (m.button === Qt.MiddleButton) { if (root.player) root.player.togglePlaying() }
        else if (m.button === Qt.RightButton) { if (root.s) root.s.karaokeOpen = true }
        else root.toggle()
      }
      onWheel: function(w) {
        if (!root.player) return
        if (w.angleDelta.y < 0) root.player.next(); else root.player.previous()
      }
    }
  }

  // ------------------------------------------------------------ popup
  KeyboardPanel {
    id: panel
    anchorItem: pill
    owner: root
    bar: root.bar
    open: root.opened && root.active
    padding: Style.space(14)
    focusTarget: panel.loadedContent
    contentWidth: Style.space(300)
    contentHeight: panel.fittedContentHeight(panel.loadedContentHeight)

    content: PanelKeyCatcher {
      anchors.fill: parent
      implicitHeight: col.implicitHeight
      onCloseRequested: root.close()
      onTabRequested: function(d) { root.switchPanel(d) }
      onActivateRequested: if (root.player) root.player.togglePlaying()
      onMoveRequested: function(dx, dy) {
        if (!root.player) return
        if (dx > 0) root.player.next()
        else if (dx < 0) root.player.previous()
        else if (dy !== 0) root.setVolume(root.volume - dy * 0.05)
      }

      Column {
        id: col
        width: parent.width
        spacing: Style.space(12)

        // Pochette
        Item {
          width: parent.width
          height: width
          Image {
            id: bigArt
            anchors.fill: parent
            source: artImg.source
            sourceSize: Qt.size(600, 600)
            fillMode: Image.PreserveAspectCrop
            visible: false
          }
          Rectangle { id: bigMask; anchors.fill: parent; radius: Style.space(12); visible: false; layer.enabled: true }
          MultiEffect {
            anchors.fill: parent
            source: bigArt
            maskEnabled: true
            maskSource: bigMask
            shadowEnabled: true
            shadowBlur: 0.7
            shadowColor: "#55000000"
            shadowVerticalOffset: 6
            scale: root.s && root.s.playing ? 1 : 0.9
            Behavior on scale { SpringAnimation { spring: 3; damping: 0.35; epsilon: 0.002 } }
          }
        }

        // Titre / artiste + j'aime
        Item {
          width: parent.width
          height: titles.implicitHeight
          Column {
            id: titles
            anchors.left: parent.left
            anchors.right: likeBtn.visible ? likeBtn.left : parent.right
            anchors.rightMargin: Style.space(6)
            spacing: Style.space(2)
            Text {
              width: parent.width
              textFormat: Text.PlainText
              text: root.s ? root.s.title : ""
              elide: Text.ElideRight
              font.family: root.uiFont
              font.pixelSize: Style.space(15)
              font.weight: Font.DemiBold
              color: root.fg
            }
            Text {
              width: parent.width
              textFormat: Text.PlainText
              text: root.s ? root.s.artist : ""
              elide: Text.ElideRight
              font.family: root.uiFont
              font.pixelSize: Style.space(13)
              color: root.fg
              opacity: 0.6
            }
          }
          IconButton {
            id: likeBtn
            visible: !!root.s && root.s.canLike
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            glyph: root.g(0xF02D5)   // cœur
            onClicked: root.s.like()
          }
        }

        // Progression déplaçable
        Column {
          width: parent.width
          spacing: Style.space(4)
          Item {
            id: prog
            width: parent.width
            height: Style.space(14)
            readonly property real frac: root.s && root.s.length > 0 ? Math.min(1, (seekArea.pressed ? seekArea.preview : root.s.position) / root.s.length) : 0
            Rectangle {
              anchors.verticalCenter: parent.verticalCenter
              width: parent.width
              height: seekArea.containsMouse || seekArea.pressed ? Style.space(7) : Style.space(5)
              radius: height / 2
              color: Qt.rgba(root.fg.r, root.fg.g, root.fg.b, 0.14)
              Behavior on height { NumberAnimation { duration: Style.duration(100) } }
              Rectangle {
                width: parent.width * prog.frac
                height: parent.height
                radius: height / 2
                color: root.fg
                opacity: 0.75
              }
            }
            MouseArea {
              id: seekArea
              anchors.fill: parent
              hoverEnabled: true
              enabled: !!root.player && root.player.canSeek
              cursorShape: Qt.PointingHandCursor
              preventStealing: true
              property real preview: 0
              function at(x) { return Math.max(0, Math.min(1, x / width)) * (root.s ? root.s.length : 0) }
              onPressed: function(m) { preview = at(m.x) }
              onPositionChanged: function(m) { if (pressed) preview = at(m.x) }
              onReleased: function(m) { root.s.seek(at(m.x)) }
            }
          }
          Item {
            width: parent.width
            height: tl.implicitHeight
            Text {
              id: tl
              textFormat: Text.PlainText
              text: root.fmt(root.s ? (seekArea.pressed ? seekArea.preview : root.s.position) : 0)
              font.family: root.uiFont; font.pixelSize: Style.space(11); font.features: { "tnum": 1 }
              color: root.fg; opacity: 0.55
            }
            Text {
              anchors.right: parent.right
              textFormat: Text.PlainText
              text: "-" + root.fmt(root.s ? root.s.length - root.s.position : 0)
              font.family: root.uiFont; font.pixelSize: Style.space(11); font.features: { "tnum": 1 }
              color: root.fg; opacity: 0.55
            }
          }
        }

        // Contrôles
        Row {
          anchors.horizontalCenter: parent.horizontalCenter
          spacing: Style.space(22)
          IconButton { glyph: root.g(0xF04AE); size: Style.space(24); onClicked: if (root.player) root.player.previous() }
          IconButton {
            glyph: root.s && root.s.playing ? root.g(0xF03E4) : root.g(0xF040A)
            size: Style.space(32)
            width: Style.space(40); height: Style.space(40)
            onClicked: if (root.player) root.player.togglePlaying()
          }
          IconButton { glyph: root.g(0xF04AD); size: Style.space(24); onClicked: if (root.player) root.player.next() }
        }

        // Volume
        Row {
          width: parent.width
          spacing: Style.space(8)
          Text {
            anchors.verticalCenter: parent.verticalCenter
            textFormat: Text.PlainText
            text: root.g(0xF057F)
            font.family: root.iconFont; font.pixelSize: Style.space(13)
            color: root.fg; opacity: 0.6
          }
          Item {
            id: vol
            width: parent.width - Style.space(42)
            height: Style.space(14)
            anchors.verticalCenter: parent.verticalCenter
            Rectangle {
              anchors.verticalCenter: parent.verticalCenter
              width: parent.width; height: Style.space(5); radius: height / 2
              color: Qt.rgba(root.fg.r, root.fg.g, root.fg.b, 0.14)
              Rectangle { width: parent.width * Math.min(1, root.volume); height: parent.height; radius: height / 2; color: root.fg; opacity: 0.75 }
            }
            MouseArea {
              anchors.fill: parent
              cursorShape: Qt.PointingHandCursor
              preventStealing: true
              onPressed: function(m) { root.setVolume(m.x / width) }
              onPositionChanged: function(m) { if (pressed) root.setVolume(m.x / width) }
            }
            WheelHandler { onWheel: function(e) { root.setVolume(root.volume + (e.angleDelta.y > 0 ? 0.05 : -0.05)) } }
          }
          Text {
            anchors.verticalCenter: parent.verticalCenter
            textFormat: Text.PlainText
            text: root.g(0xF057E)
            font.family: root.iconFont; font.pixelSize: Style.space(13)
            color: root.fg; opacity: 0.6
          }
        }

        // Raccourcis paroles / fond
        Flow {
          width: parent.width
          spacing: Style.space(6)
          Chip { text: "Paroles bureau"; on: !!root.s && root.s.lyricsDesktop; onClicked: root.s.setConfig("lyrics.desktop", !root.s.lyricsDesktop) }
          Chip { text: "Widget"; on: !!root.s && root.s.lyricsWidget; onClicked: root.s.setConfig("lyrics.widget", !root.s.lyricsWidget) }
          Chip { text: "Barre"; on: !!root.s && root.s.lyricsBar; onClicked: root.s.setConfig("lyrics.bar", !root.s.lyricsBar) }
          Chip { text: "Karaoké"; on: !!root.s && root.s.karaokeOpen; onClicked: { root.close(); root.s.karaokeOpen = true } }
          Chip { text: "Couleurs"; on: !!root.s && root.s.dynamicColors; onClicked: root.s.setConfig("spotify.dynamic_colors", !root.s.dynamicColors) }
          Chip { text: "Visualiseur"; on: !!root.s && root.s.visualizer; onClicked: root.s.setConfig("visualizer.enabled", !root.s.visualizer) }
          Chip {
            readonly property var modes: ["cover", "blur", "gradient", "off"]
            readonly property var names: ({ cover: "Fond : pochette", blur: "Fond : flou", gradient: "Fond : dégradé", off: "Fond : thème" })
            text: root.s ? (names[root.s.wallMode] || "Fond") : "Fond"
            on: !!root.s && root.s.wallMode !== "off"
            onClicked: {
              var i = modes.indexOf(root.s.wallMode)
              root.s.setConfig("spotify.wallpaper", modes[(i + 1) % modes.length])
            }
          }
        }
      }
    }
  }

  // ------------------------------------------------------------ composants
  component IconButton: Item {
    id: ib
    property string glyph: ""
    property real size: Style.space(18)
    signal clicked()
    width: Style.space(30)
    height: Style.space(30)
    Rectangle { anchors.fill: parent; radius: width / 2; color: root.fg; opacity: ibMouse.containsMouse ? 0.1 : 0 }
    Text {
      anchors.centerIn: parent
      textFormat: Text.PlainText
      text: ib.glyph
      font.family: root.iconFont
      font.pixelSize: ib.size
      color: root.fg
      scale: ibMouse.pressed ? 0.86 : 1
      Behavior on scale { NumberAnimation { duration: Style.duration(90) } }
    }
    MouseArea { id: ibMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: ib.clicked() }
  }

  component Chip: Rectangle {
    id: chip
    property string text: ""
    property bool on: false
    signal clicked()
    width: chipText.implicitWidth + Style.space(18)
    height: Style.space(24)
    radius: height / 2
    color: on ? Commons.Color.accent : Qt.rgba(root.fg.r, root.fg.g, root.fg.b, chipMouse.containsMouse ? 0.14 : 0.08)
    Behavior on color { ColorAnimation { duration: Style.duration(120) } }
    Text {
      id: chipText
      anchors.centerIn: parent
      textFormat: Text.PlainText
      text: chip.text
      font.family: root.uiFont
      font.pixelSize: Style.space(11.5)
      font.weight: Font.Medium
      color: chip.on ? "#ffffff" : root.fg
    }
    MouseArea { id: chipMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: chip.clicked() }
  }
}
