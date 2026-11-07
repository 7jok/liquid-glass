import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Widgets
import Quickshell.Services.SystemTray
import Quickshell.Services.Pipewire
import Quickshell.Bluetooth

// Style « foret » (rice c01 d'ilyamiro) : barre en puces sombres qui flottent
// au-dessus du fond, police mono, accents vert tilleul.
//   gauche : 🔍 lanceur · 🔔 notifications · bureaux 1–8 · morceau en cours (pochette, temps, ◁ ▮▮ ▷)
//   centre : heure (secondes), date, météo → tableau de bord
//   droite : zone de notification · clavier · Wi-Fi · Bluetooth · volume · batterie
PanelWindow {
  id: win
  property var service: null
  readonly property var s: service

  readonly property int barH: 30
  color: "transparent"
  anchors { top: true; left: true; right: true }
  margins { top: s.testing ? 40 : 6; left: 8; right: 8 }
  implicitHeight: barH
  exclusiveZone: barH + 4
  WlrLayershell.layer: WlrLayer.Top
  WlrLayershell.namespace: "liquid-glass-foret-bar"
  WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

  readonly property string font: "JetBrainsMono Nerd Font"
  readonly property color chip: s.alpha(s.surface, 0.92)
  readonly property color chip2: s.alpha(s.surfaceHigh, 0.95)
  readonly property color ink: s.colOnSurface
  readonly property color sub: s.colOnSurfaceVariant
  readonly property color acc: s.primary
  readonly property color accInk: s.colOnPrimary

  readonly property var monitor: screen ? Hyprland.monitorFor(screen) : Hyprland.focusedMonitor
  readonly property int activeWs: monitor && monitor.activeWorkspace ? monitor.activeWorkspace.id : 1
  property date now: new Date()
  Timer { interval: 1000; repeat: true; running: true; onTriggered: win.now = new Date() }

  PwObjectTracker { objects: [Pipewire.defaultAudioSink] }
  readonly property var sink: Pipewire.defaultAudioSink
  readonly property real volume: sink && sink.audio ? sink.audio.volume : 0
  readonly property var bt: Bluetooth.defaultAdapter
  readonly property var btDev: {
    if (!bt || !bt.enabled || !bt.devices) return null
    var d = bt.devices.values
    for (var i = 0; i < d.length; i++) if (d[i].connected) return d[i]
    return null
  }
  function run(cmd) { Quickshell.execDetached(["sh", "-c", cmd]) }

  // ------------------------------------------------------------ gauche
  Row {
    anchors.left: parent.left
    spacing: 6
    Chip { width: barH; onClicked: s.toggleLauncher(); MIcon { anchors.centerIn: parent; icon: "search"; size: 16; color: win.ink } }
    Chip { width: barH; onClicked: s.claude(); ClaudeButton { anchors.centerIn: parent; s: win.s; size: barH; iconSize: 17; hover: "transparent"; enabled: false } }
    Chip { width: barH; onClicked: win.run("omarchy-shell notifications showHistory"); MIcon { anchors.centerIn: parent; icon: "notifications"; size: 16; fill: 1; color: win.ink } }
    Chip {
      width: wsRow.implicitWidth + 8
      Row {
        id: wsRow
        anchors.centerIn: parent
        spacing: 2
        Repeater {
          model: s.wsCount
          delegate: Rectangle {
            id: ws
            required property int index
            readonly property int num: index + 1
            readonly property bool active: win.activeWs === num
            readonly property bool used: { var w = Hyprland.workspaces.values; for (var i = 0; i < w.length; i++) if (w[i].id === num) return true; return false }
            width: 22; height: 22; radius: 6
            color: active ? win.acc : (used ? win.chip2 : "transparent")
            Behavior on color { ColorAnimation { duration: 160 } }
            Text { anchors.centerIn: parent; text: ws.num; font.family: win.font; font.pixelSize: 11; font.weight: ws.active ? Font.Bold : Font.Normal; color: ws.active ? win.accInk : win.ink }
            MouseArea { anchors.fill: parent; onClicked: Quickshell.execDetached(["hyprctl", "dispatch", "hl.dsp.focus({ workspace = \"" + ws.num + "\" })"]) }
          }
        }
      }
    }
    Chip {
      visible: s.hasTrack || s.resumeMode
      width: 236
      onClicked: s.togglePanel("music")
      ClippingRectangle {
        x: 4; anchors.verticalCenter: parent.verticalCenter; width: 22; height: 22; radius: 5; color: win.chip2
        Image { anchors.fill: parent; source: s.cover; fillMode: Image.PreserveAspectCrop; asynchronous: true }
      }
      Column {
        x: 32; anchors.verticalCenter: parent.verticalCenter; width: 120
        Text { width: parent.width; elide: Text.ElideRight; text: s.trackTitle; font.family: win.font; font.pixelSize: 10; font.weight: Font.Bold; color: win.ink }
        Text { text: s.fmtTime(s.position) + " / " + s.fmtTime(s.length); font.family: win.font; font.pixelSize: 8; color: win.sub }
      }
      Row {
        anchors.right: parent.right; anchors.rightMargin: 6; anchors.verticalCenter: parent.verticalCenter; spacing: 2
        MiniBtn { icon: "skip_previous"; onClicked: if (s.player) s.player.previous() }
        MiniBtn { icon: s.playing ? "pause" : "play_arrow"; onClicked: s.playPause() }
        MiniBtn { icon: "skip_next"; onClicked: if (s.player) s.player.next() }
      }
    }
  }

  // ------------------------------------------------------------ centre
  Chip {
    anchors.horizontalCenter: parent.horizontalCenter
    width: centerRow.implicitWidth + 22
    active: s.panel === "dash"
    onClicked: s.togglePanel("dash")
    Row {
      id: centerRow
      anchors.centerIn: parent
      spacing: 14
      Column {
        anchors.verticalCenter: parent.verticalCenter
        Text { text: Qt.formatTime(win.now, "HH:mm:ss"); font.family: win.font; font.pixelSize: 11; font.weight: Font.Bold; color: win.acc }
        Text { text: win.now.toLocaleDateString(Qt.locale("fr_FR"), "dddd d MMMM"); font.family: win.font; font.pixelSize: 8; color: win.sub }
      }
      Row {
        visible: !!s.weather
        anchors.verticalCenter: parent.verticalCenter; spacing: 6
        MIcon { anchors.verticalCenter: parent.verticalCenter; icon: s.weatherIcon; size: 17; fill: 1; color: win.ink }
        Text { anchors.verticalCenter: parent.verticalCenter; text: s.weather ? s.weather.temp + "°C" : ""; font.family: win.font; font.pixelSize: 12; color: win.ink }
      }
    }
  }

  // ------------------------------------------------------------ droite
  Row {
    anchors.right: parent.right
    spacing: 6
    Chip {
      visible: SystemTray.items.values.length > 0
      width: trayRow.implicitWidth + 16
      Row {
        id: trayRow
        anchors.centerIn: parent; spacing: 6
        Repeater {
          model: SystemTray.items
          delegate: Item {
            id: ti
            required property var modelData
            width: 15; height: 15
            anchors.verticalCenter: parent.verticalCenter
            IconImage { anchors.fill: parent; source: ti.modelData.icon; asynchronous: true }
            MouseArea {
              anchors.fill: parent
              acceptedButtons: Qt.LeftButton | Qt.RightButton
              onClicked: function(m) {
                if (m.button === Qt.RightButton || ti.modelData.onlyMenu) {
                  if (ti.modelData.hasMenu) { var p = ti.mapToItem(null, 0, ti.height + 8); ti.modelData.display(win, p.x, p.y) }
                } else ti.modelData.activate()
              }
            }
          }
        }
      }
    }
    Chip {
      width: statRow.implicitWidth + 10
      Row {
        id: statRow
        anchors.centerIn: parent
        spacing: 4
        Pill { icon: "keyboard"; label: (s.layout || "fr").slice(0, 2).toUpperCase(); filled: false }
        Pill { icon: s.netDev === "" ? "wifi_off" : (s.netWifi ? "wifi" : "lan"); label: s.netDev === "" ? "Hors ligne" : (s.netWifi && s.wifiList.length && s.wifiList[0].active ? s.wifiList[0].ssid : s.netDev)
               filled: s.netDev !== ""; onClicked: s.togglePanel("net") }
        Pill { visible: !!win.bt; icon: win.btDev ? "headphones" : "bluetooth"; label: win.btDev ? (win.btDev.name || "Appareil") : (win.bt && win.bt.enabled ? "Bluetooth" : "Désactivé")
               filled: !!win.btDev; onClicked: s.togglePanel("net") }
        Pill { icon: win.volume <= 0.01 ? "volume_off" : "volume_up"; label: Math.round(win.volume * 100); filled: true; tint: s.secondary
               onClicked: s.togglePanel("music")
               onWheel: function(d) { Quickshell.execDetached(["wpctl", "set-volume", "-l", "1.0", "@DEFAULT_AUDIO_SINK@", "5%" + (d > 0 ? "+" : "-")]) } }
        Pill { visible: s.batteryPct >= 0; icon: s.charging ? "battery_charging_full" : "battery_full"; label: s.batteryPct; filled: false
               onClicked: s.togglePanel("battery") }
      }
    }
  }

  // ------------------------------------------------------------ briques
  component Chip: Rectangle {
    id: ch
    property bool active: false
    signal clicked()
    height: win.barH; radius: 9
    color: ma.containsMouse || active ? win.chip2 : win.chip
    border.width: 1
    border.color: s.alpha(win.ink, 0.06)
    Behavior on color { ColorAnimation { duration: 120 } }
    MouseArea { id: ma; anchors.fill: parent; hoverEnabled: true; onClicked: ch.clicked() }
  }
  component MiniBtn: Item {
    id: mb
    property string icon: ""
    signal clicked()
    width: 20; height: 22
    MIcon { anchors.centerIn: parent; icon: mb.icon; size: 16; fill: 1; color: mbma.containsMouse ? win.acc : win.ink }
    MouseArea { id: mbma; anchors.fill: parent; hoverEnabled: true; onClicked: mb.clicked() }
  }
  component Pill: Rectangle {
    id: pl
    property string icon: ""
    property string label: ""
    property bool filled: false
    property color tint: win.acc
    signal clicked()
    signal wheel(int delta)
    height: 22; radius: 6
    width: Math.min(120, plRow.implicitWidth + 16)
    color: filled ? pl.tint : (plma.containsMouse ? win.chip2 : "transparent")
    anchors.verticalCenter: parent ? parent.verticalCenter : undefined
    Row {
      id: plRow
      anchors.centerIn: parent; spacing: 5
      MIcon { anchors.verticalCenter: parent.verticalCenter; icon: pl.icon; size: 13; fill: 1; color: pl.filled ? win.accInk : win.ink }
      Text {
        anchors.verticalCenter: parent.verticalCenter
        width: Math.min(implicitWidth, 80); elide: Text.ElideRight
        text: pl.label; font.family: win.font; font.pixelSize: 10; font.weight: Font.Bold; color: pl.filled ? win.accInk : win.ink
      }
    }
    MouseArea { id: plma; anchors.fill: parent; hoverEnabled: true; onClicked: pl.clicked(); onWheel: function(w) { pl.wheel(w.angleDelta.y) } }
  }
}
