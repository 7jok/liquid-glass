import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import qs.Commons
import qs.Commons as Commons
import qs.Ui

// Karaoké plein écran : pochette floutée en fond, paroles géantes centrées.
// SUPER+ALT+K (ou omarchy-shell liquid-glass.spotify karaoke). Échap / clic pour fermer.
OverlayWindow {
  id: win

  property var service: null

  shown: !!service && service.karaokeOpen
  WlrLayershell.namespace: "liquid-glass-karaoke"

  readonly property string cover: service && service.coverPath !== "" ? "file://" + service.coverPath : ""

  Item {
    id: root
    anchors.fill: parent
    focus: true
    Keys.onEscapePressed: win.service.karaokeOpen = false
    Keys.onSpacePressed: if (win.service.player) win.service.player.togglePlaying()
    Keys.onRightPressed: if (win.service.player) win.service.player.next()
    Keys.onLeftPressed: if (win.service.player) win.service.player.previous()

    Rectangle { anchors.fill: parent; color: "#0b0b0d" }

    Image {
      id: bg
      anchors.fill: parent
      source: win.cover
      sourceSize: Qt.size(320, 320)
      fillMode: Image.PreserveAspectCrop
      visible: false
    }
    MultiEffect {
      anchors.fill: parent
      source: bg
      blurEnabled: true
      blurMax: 64
      blur: 1
      saturation: 0.35
      brightness: -0.28
      visible: bg.status === Image.Ready
    }
    // Voile pour la lisibilité.
    Rectangle {
      anchors.fill: parent
      gradient: Gradient {
        GradientStop { position: 0; color: "#66000000" }
        GradientStop { position: 0.5; color: "#22000000" }
        GradientStop { position: 1; color: "#77000000" }
      }
    }

    // En-tête : pochette, titre, artiste.
    Row {
      x: 48; y: 40
      spacing: 18
      Item {
        width: 76; height: 76
        Image { id: thumb; anchors.fill: parent; source: win.cover; sourceSize: Qt.size(152, 152); fillMode: Image.PreserveAspectCrop; visible: false }
        Rectangle { id: thumbMask; anchors.fill: parent; radius: 12; visible: false; layer.enabled: true }
        MultiEffect { anchors.fill: parent; source: thumb; maskEnabled: true; maskSource: thumbMask; shadowEnabled: true; shadowBlur: 0.8; shadowColor: "#80000000" }
      }
      Column {
        anchors.verticalCenter: parent.verticalCenter
        spacing: 4
        Text { textFormat: Text.PlainText; text: win.service ? win.service.title : ""; color: "white"; font.family: "Inter"; font.pixelSize: 22; font.weight: Font.Bold }
        Text { textFormat: Text.PlainText; text: win.service ? win.service.artist : ""; color: "white"; opacity: 0.7; font.family: "Inter"; font.pixelSize: 17 }
      }
    }

    LyricsColumn {
      service: win.service
      visible: !!win.service && win.service.lyricsSynced
      x: parent.width * 0.12
      width: parent.width * 0.76
      y: parent.height * 0.16
      height: parent.height * 0.72
      fontSize: Math.round(parent.height * 0.062)
      horizontalAlignment: Text.AlignHCenter
      visibleRadius: 4
      blurPerLine: 0.3
      shadowColor: "#60000000"
      clip: true
    }

    // Paroles non synchronisées : texte brut défilable.
    Flickable {
      visible: !!win.service && !win.service.lyricsSynced
      x: parent.width * 0.2; width: parent.width * 0.6
      y: parent.height * 0.16; height: parent.height * 0.76
      contentHeight: plain.implicitHeight
      clip: true
      Text {
        id: plain
        width: parent.width
        textFormat: Text.PlainText
        wrapMode: Text.WordWrap
        horizontalAlignment: Text.AlignHCenter
        text: !win.service ? "" : (win.service.lyricsLoading ? "Recherche des paroles…"
              : (win.service.lyricsPlain !== "" ? win.service.lyricsPlain : "Aucune parole trouvée pour ce titre."))
        color: "white"
        font.family: "Inter"
        font.pixelSize: 26
        font.weight: Font.DemiBold
        lineHeight: 1.3
      }
    }

    // Barre de progression discrète.
    Rectangle {
      anchors.bottom: parent.bottom; anchors.bottomMargin: 36
      anchors.horizontalCenter: parent.horizontalCenter
      width: parent.width * 0.4; height: 4; radius: 2
      color: "#33ffffff"
      Rectangle {
        height: parent.height; radius: 2; color: "white"
        width: win.service && win.service.length > 0 ? parent.width * Math.min(1, win.service.position / win.service.length) : 0
        Behavior on width { NumberAnimation { duration: 250 } }
      }
    }

    Text {
      anchors.right: parent.right; anchors.top: parent.top; anchors.margins: 36
      textFormat: Text.PlainText
      text: "Échap pour fermer"
      color: "white"; opacity: 0.45
      font.family: "Inter"; font.pixelSize: 13
    }

    MouseArea { anchors.fill: parent; onClicked: win.service.karaokeOpen = false }
  }

  onShownChanged: if (shown) root.forceActiveFocus()
}
