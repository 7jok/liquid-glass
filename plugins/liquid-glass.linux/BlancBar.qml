import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Services.Pipewire
import Quickshell.Services.SystemTray
import Quickshell.Wayland
import Quickshell.Widgets
import "T.js" as T

// Barre du style Blanc : une ligne de texte en bas de l'écran, comme dwm / vxwm.
// Pas d'îlots ni d'icônes décoratives : des numéros de bureaux, un titre, des valeurs.
PanelWindow {
  id: win
  property var service: null
  readonly property var s: service

  readonly property bool atBottom: s.barAt("bottom") === "bottom"
  anchors { top: !atBottom; bottom: atBottom; left: true; right: true }
  implicitHeight: 24
  exclusiveZone: 24
  color: s.surfaceMid
  WlrLayershell.layer: WlrLayer.Top
  WlrLayershell.namespace: "liquid-glass-linux-bar"
  WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

  readonly property string font: s && s.userFont ? s.userFont : "JetBrainsMono Nerd Font"
  readonly property color ink: s.colOnSurface
  readonly property color dim: s.colOnSurfaceVariant
  readonly property var monitor: screen ? Hyprland.monitorFor(screen) : Hyprland.focusedMonitor
  readonly property int activeWs: monitor && monitor.activeWorkspace ? monitor.activeWorkspace.id : 1
  readonly property var occupied: {
    var o = {}, v = Hyprland.workspaces ? Hyprland.workspaces.values : []
    for (var i = 0; i < v.length; i++) if (v[i].id > 0) o[v[i].id] = true
    return o
  }
  PwObjectTracker { objects: [Pipewire.defaultAudioSink] }
  readonly property var sink: Pipewire.defaultAudioSink
  readonly property int vol: sink && sink.audio ? Math.round(sink.audio.volume * 100) : 0
  readonly property bool muted: !sink || !sink.audio || sink.audio.muted
  property date now: new Date()
  Timer { interval: 1000; repeat: true; running: true; onTriggered: win.now = new Date() }
  function run(cmd) { Quickshell.execDetached(["sh", "-c", cmd]) }

  Rectangle { width: parent.width; height: 2; color: win.ink }

  Row {
    id: left
    x: 0; height: parent.height
    Cell { label: "≡"; bold: true; onClicked: s.toggleLauncher() }
    ClaudeButton {
      anchors.verticalCenter: parent.verticalCenter; anchors.verticalCenterOffset: 1
      s: win.s; size: 22; iconSize: 14; mono: true; radius: 0
    }
    Item { width: 6; height: 1 }
    Repeater {
      model: Math.max(s.wsCount, win.activeWs)
      delegate: Cell {
        required property int index
        readonly property int ws: index + 1
        label: String(ws)
        on: ws === win.activeWs
        bold: on
        dimmed: !on && !win.occupied[ws]
        mark: !on && !!win.occupied[ws]
        onClicked: Quickshell.execDetached(["hyprctl", "dispatch", "hl.dsp.focus({ workspace = \"" + ws + "\" })"])
      }
    }
    Item { width: 8; height: 1 }
  }

  // Réglages propres à Blanc (Réglages → Propre à Blanc) : blanc_bar_<élément>.
  function bo(k, d) { return s.opt("blanc_bar_" + k, d === undefined ? true : d) !== false }

  Text {
    visible: win.bo("title")
    x: left.width; y: 2
    width: right.x - left.width - 12; height: parent.height - 2
    verticalAlignment: Text.AlignVCenter; elide: Text.ElideRight
    readonly property var tl: Hyprland.activeToplevel
    text: tl ? String(tl.title || "") : ""
    font.family: win.font; font.pixelSize: 11; color: win.ink
  }

  Row {
    id: right
    anchors.right: parent.right; height: parent.height
    Cell {
      visible: s.hasTrack && win.bo("track")
      label: (s.playing ? "♪ " : "‖ ") + (s.trackTitle.length > 26 ? s.trackTitle.slice(0, 25) + "…" : s.trackTitle)
      onClicked: s.playPause()
    }
    Sep { visible: s.hasTrack && win.bo("track") }
    Cell {
      visible: win.bo("res")
      label: "cpu " + Math.round(s.cpu * 100) + " ram " + Math.round(s.memPct * 100) + (s.temp > 0 ? " " + s.temp + "°" : "")
      onClicked: win.run("omarchy-launch-or-focus-tui btop")
    }
    Sep { visible: win.bo("res") }
    Repeater {
      model: win.bo("tray") ? SystemTray.items : []
      delegate: Item {
        id: tray
        required property var modelData
        width: 20; height: win.height
        IconImage { anchors.centerIn: parent; anchors.verticalCenterOffset: 1; width: 14; height: 14; source: tray.modelData.icon; asynchronous: true }
        MouseArea {
          anchors.fill: parent
          acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
          onClicked: function(m) {
            var it = tray.modelData
            if (m.button === Qt.MiddleButton) it.secondaryActivate()
            else if (m.button === Qt.RightButton || it.onlyMenu) {
              if (it.hasMenu) { var p = tray.mapToItem(null, 0, -6); it.display(win, p.x, p.y) }
            } else it.activate()
          }
        }
      }
    }
    Cell {
      label: "vol " + (win.muted ? "--" : win.vol)
      onClicked: s.toggleMenu("home")
      onWheeled: function(d) { win.run("wpctl set-volume -l 1.0 @DEFAULT_AUDIO_SINK@ 5%" + (d > 0 ? "+" : "-")) }
    }
    Cell { label: s.netDev === "" ? "hors-ligne" : (s.netWifi ? "wifi" : "lan"); onClicked: s.toggleMenu("home") }
    Cell {
      visible: s.batteryPct >= 0
      label: (s.charging ? "sec " : "bat ") + s.batteryPct
      on: !s.charging && s.batteryPct <= 15
      onClicked: s.toggleMenu("home")
    }
    Sep {}
    Cell {
      label: win.now.toLocaleDateString(Qt.locale(T.loc), "ddd dd/MM") + " " + Qt.formatTime(win.now, win.bo("seconds", false) ? "HH:mm:ss" : "HH:mm")
      bold: true
      onClicked: s.toggleMenu("home")
    }
    Cell { label: "⏻"; bold: true; onClicked: s.powerMenu() }
  }

  component Sep: Text {
    y: 2; height: win.height - 2; verticalAlignment: Text.AlignVCenter
    text: "|"; font.family: win.font; font.pixelSize: 11; color: win.dim
  }
  // Texte cliquable ; `on` = inversé (encre pleine), `mark` = petit trait dessous.
  component Cell: Rectangle {
    id: cl
    property string label: ""
    property bool on: false
    property bool bold: false
    property bool dimmed: false
    property bool mark: false
    signal clicked()
    signal wheeled(int d)
    width: tx.implicitWidth + 12; height: win.height
    color: on || cma.containsMouse ? win.ink : "transparent"
    Text {
      id: tx
      anchors.centerIn: parent; anchors.verticalCenterOffset: 1
      text: cl.label; font.family: win.font; font.pixelSize: 11
      font.capitalization: win.bo("upper", false) ? Font.AllUppercase : Font.MixedCase
      font.weight: cl.bold ? Font.Bold : Font.Normal
      color: cl.on || cma.containsMouse ? win.s.surfaceMid : (cl.dimmed ? win.s.outline : win.ink)
    }
    Rectangle { visible: cl.mark; x: 3; y: 4; width: 4; height: 4; color: win.ink }
    MouseArea {
      id: cma; anchors.fill: parent; hoverEnabled: true
      onClicked: cl.clicked()
      onWheel: function(w) { cl.wheeled(w.angleDelta.y > 0 ? 1 : -1) }
    }
  }
}
