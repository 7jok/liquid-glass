import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Widgets
import "T.js" as T

// Bureau du style Blanc : presque rien. Une fiche système et le morceau en cours,
// bords durs et ombres décalées, plus une grande heure en bas à droite.
PanelWindow {
  id: win
  property var service: null
  readonly property var s: service

  color: "transparent"
  anchors { top: true; bottom: true; left: true; right: true }
  exclusionMode: ExclusionMode.Normal
  WlrLayershell.layer: WlrLayer.Bottom
  WlrLayershell.namespace: "liquid-glass-linux-desktop"
  WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
  mask: Region {}

  readonly property string font: s && s.userFont ? s.userFont : "JetBrainsMono Nerd Font"
  readonly property color ink: s.colOnSurface
  readonly property color paper: s.surfaceMid
  property date now: new Date()
  Timer { interval: 5000; repeat: true; running: true; onTriggered: win.now = new Date() }

  property string kernel: ""
  Process {
    running: true
    command: ["uname", "-r"]
    stdout: StdioCollector { onStreamFinished: win.kernel = text.trim().split("-").slice(0, 1).join("") }
  }
  function pad(k) { return (k + "        ").slice(0, 8) }

  // Fiche système
  Slab {
    id: fetch
    visible: win.s.opt("blanc_fetch", true) !== false
    x: 28; anchors.bottom: parent.bottom; anchors.bottomMargin: 28
    width: 250; height: col.height + 26
    Column {
      id: col
      x: 14; y: 13; spacing: 3
      Text { text: win.s.user + "@omarchy"; font.family: win.font; font.pixelSize: 13; font.weight: Font.Bold; color: win.ink }
      Rectangle { width: fetch.width - 28; height: 2; color: win.ink }
      Repeater {
        model: [["wm", "Hyprland"], ["noyau", win.kernel], ["actif", win.s.uptimeText],
                ["mémoire", Math.round(win.s.memPct * 100) + " %"], ["disque", Math.round(win.s.diskPct * 100) + " %"],
                ["dehors", win.s.weather ? win.s.weather.temp + "°C " + win.s.weatherDesc : "--"]]
        delegate: Text {
          required property var modelData
          text: win.pad(modelData[0]) + " " + modelData[1]
          font.family: win.font; font.pixelSize: 11; color: win.ink
        }
      }
      Row {
        topPadding: 5
        Repeater {
          model: 8
          delegate: Rectangle { required property int index; width: 18; height: 10; color: Qt.tint(win.ink, Qt.rgba(1, 1, 1, index / 8)) }
        }
      }
    }
  }

  // Morceau en cours : bloc d'encre, comme un terminal posé sur le papier.
  Slab {
    visible: win.s.hasTrack && win.s.opt("blanc_track", true) !== false
    x: (fetch.visible ? 28 + 250 + 20 : 28); anchors.bottom: parent.bottom; anchors.bottomMargin: 28
    width: 300; height: 96
    inverted: true
    Row {
      x: 12; y: 12; spacing: 12
      ClippingRectangle {
        width: 72; height: 72; radius: 0; color: win.paper
        Image { anchors.fill: parent; source: win.s.cover; fillMode: Image.PreserveAspectCrop; asynchronous: true; cache: false; sourceSize.width: 160 }
      }
      Column {
        width: 190; spacing: 3
        Text { width: parent.width; elide: Text.ElideRight; text: win.s.trackTitle; font.family: win.font; font.pixelSize: 13; font.weight: Font.Bold; color: win.paper }
        Text { width: parent.width; elide: Text.ElideRight; text: win.s.trackArtist; font.family: win.font; font.pixelSize: 11; color: win.paper; opacity: 0.7 }
        Item { width: 1; height: 8 }
        Text {
          readonly property int n: Math.round(win.s.progress * 20)
          text: "[" + "=".repeat(n) + " ".repeat(20 - n) + "]"
          font.family: win.font; font.pixelSize: 11; color: win.paper
        }
        Text { text: win.s.fmtTime(win.s.position) + " / " + win.s.fmtTime(win.s.length); font.family: win.font; font.pixelSize: 10; color: win.paper; opacity: 0.7 }
      }
    }
  }

  // Grande heure
  Column {
    visible: win.s.showClock && win.s.opt("blanc_clock", true) !== false
    anchors.right: parent.right; anchors.rightMargin: 28
    anchors.bottom: parent.bottom; anchors.bottomMargin: 20
    Text {
      anchors.right: parent.right
      text: Qt.formatTime(win.now, "HH:mm")
      font.family: win.font; font.pixelSize: 112; font.weight: Font.ExtraBold; font.letterSpacing: -6; color: win.ink
    }
    Rectangle { width: parent.width; height: 4; color: win.ink }
    Text {
      anchors.right: parent.right; topPadding: 6
      text: win.now.toLocaleDateString(Qt.locale(T.loc), "dddd d MMMM").toUpperCase()
      font.family: win.font; font.pixelSize: 13; font.weight: Font.Bold; font.letterSpacing: 2; color: win.ink
    }
  }

  // Bloc à bords durs et ombre décalée.
  component Slab: Item {
    id: sl
    property bool inverted: false
    default property alias content: inner.data
    Rectangle { x: 7; y: 7; width: parent.width; height: parent.height; color: win.ink }
    Rectangle {
      id: inner
      anchors.fill: parent
      color: sl.inverted ? win.ink : win.paper
      border.width: 2; border.color: sl.inverted ? win.paper : win.ink
    }
  }
}
