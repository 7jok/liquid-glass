import QtQuick
import Quickshell
import Quickshell.Wayland
import "T.js" as T

// Bureau du style Espace : les paroles défilent au centre du ciel, l'horloge à
// planètes tourne en bas à droite, l'activité du processeur se remplit en haut à droite.
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

  readonly property string font: s.sansFont

  // Paroles : la ligne chantée au centre, les voisines s'estompent.
  Column {
    visible: win.s.showLyrics && win.s.lyrics.length > 0 && win.s.lineIndex >= 0 && win.s.opt("espace_lyrics", true) !== false
    anchors.centerIn: parent
    width: parent.width * 0.6
    spacing: 7
    Repeater {
      model: 7
      delegate: Text {
        required property int index
        readonly property int li: win.s.lineIndex + index - 3
        readonly property int dist: Math.abs(index - 3)
        width: parent.width; horizontalAlignment: Text.AlignHCenter; elide: Text.ElideRight
        text: li >= 0 && li < win.s.lyrics.length ? String(win.s.lyrics[li].text || " ") : " "
        font.family: win.font; font.pixelSize: dist === 0 ? 20 : 14; font.weight: dist === 0 ? Font.Bold : Font.Normal
        color: dist === 0 ? win.s.colOnSurface : win.s.colOnSurfaceVariant
        opacity: 1 - dist * 0.25
        style: Text.Raised; styleColor: win.s.alpha("#000000", 0.5)
        Behavior on opacity { NumberAnimation { duration: 240 } }
      }
    }
  }

  // Activité : une case par minute, plus elle brille plus le processeur a travaillé.
  Rectangle {
    visible: win.s.opt("espace_activity", true) !== false
    anchors.right: parent.right; anchors.rightMargin: 16; y: 14
    width: heat.width + 20; height: heat.height + 34
    radius: 10; color: win.s.alpha(win.s.surface, 0.6)
    border.width: 1; border.color: win.s.alpha(win.s.colOnSurface, 0.1)
    Text { x: 10; y: 8; text: T.t("Activité · 1 h"); font.family: win.font; font.pixelSize: 10; color: win.s.colOnSurfaceVariant }
    Grid {
      id: heat
      x: 10; y: 26; columns: 12; spacing: 3
      Repeater {
        model: 60
        delegate: Rectangle {
          required property int index
          readonly property real v: index < win.hist.length ? win.hist[index] : -1
          width: 13; height: 13; radius: 3
          color: v < 0 ? win.s.alpha(win.s.colOnSurface, 0.07) : win.s.alpha(win.s.primary, 0.2 + 0.8 * v)
        }
      }
    }
  }
  property var hist: []
  function sample() { var h = hist.slice(-59); h.push(Math.min(1, s.cpu * 1.6)); hist = h }
  Timer { interval: 60000; repeat: true; running: true; triggeredOnStart: true; onTriggered: win.sample() }

  Planets {
    visible: win.s.showClock && win.s.opt("espace_planets", true) !== false
    anchors.right: parent.right; anchors.rightMargin: 26
    anchors.bottom: parent.bottom; anchors.bottomMargin: 26
    width: 210; height: 210
    s: win.s
  }
}
