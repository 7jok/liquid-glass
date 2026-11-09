import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.Pipewire
import "T.js" as T

// Style Infini, barre du bas, transparente au-dessus du visualiseur :
//   gauche : alimentation, notifications, son, Spotify, Steam
//   centre : pastille réglages · enregistrement (point rouge + durée) · micro · arrêt,
//            puis la position sur la toile (clic : retour au centre)
//   droite : réseau, volume (molette), Bluetooth
PanelWindow {
  id: bar
  property var service: null
  property var desk: null
  readonly property var s: service
  readonly property real k: desk ? desk.k : 1
  readonly property color acc: desk ? desk.acc : "#e8a3b4"
  readonly property color ink: "#ece2e4"
  readonly property string ico: "Material Symbols Rounded"

  color: "transparent"
  anchors { bottom: true; left: true; right: true }
  implicitHeight: Math.round(40 * k)
  exclusiveZone: implicitHeight
  WlrLayershell.layer: WlrLayer.Top
  WlrLayershell.namespace: "liquid-glass-infini-bar"
  WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

  function run(cmd) { Quickshell.execDetached(["sh", "-c", cmd]) }
  function panel(id) { run("omarchy-shell shell toggle " + id) }

  // ---------------- enregistrement d'écran (omarchy-capture-screenrecording)
  property bool recording: false
  property real recStart: 0
  property int recSecs: 0
  Process {
    id: recP
    command: ["omarchy-capture-screenrecording", "--status"]
    onExited: function(code) {
      var on = code === 0
      if (on && !bar.recording) bar.recStart = Date.now()
      bar.recording = on
    }
  }
  Timer { interval: 2000; repeat: true; running: !(bar.s && bar.s.testing); triggeredOnStart: true; onTriggered: if (!recP.running) recP.running = true }
  Timer { interval: 1000; repeat: true; running: bar.recording; onTriggered: bar.recSecs = Math.floor((Date.now() - bar.recStart) / 1000) }
  function hms(t) { function d(n) { return (n < 10 ? "0" : "") + n } return d(Math.floor(t / 3600)) + ":" + d(Math.floor(t / 60) % 60) + ":" + d(t % 60) }
  function toggleRec() {
    run("omarchy-capture-screenrecording --stop-recording || omarchy-menu toggle trigger.capture.screenrecord")
    recTimer.restart()
  }
  Timer { id: recTimer; interval: 900; onTriggered: if (!recP.running) recP.running = true }

  // ---------------- son et micro
  PwObjectTracker { objects: [Pipewire.defaultAudioSink, Pipewire.defaultAudioSource] }
  readonly property var sink: Pipewire.defaultAudioSink
  readonly property var source: Pipewire.defaultAudioSource
  readonly property bool micMuted: !!source && !!source.audio && source.audio.muted

  component Btn: Item {
    id: b
    property string icon: ""
    property string glyph: ""          // icône Nerd Font (Spotify, Steam)
    property color tint: bar.ink
    property bool active: false
    signal clicked()
    signal wheel(var w)
    width: Math.round(26 * bar.k); height: width
    Rectangle { anchors.fill: parent; radius: width / 2; color: ma.containsMouse ? Qt.rgba(1, 1, 1, 0.12) : (b.active ? Qt.rgba(bar.acc.r, bar.acc.g, bar.acc.b, 0.25) : "transparent") }
    Text {
      anchors.centerIn: parent
      text: b.glyph !== "" ? b.glyph : b.icon
      font.family: b.glyph !== "" ? "JetBrainsMono Nerd Font" : bar.ico
      font.pixelSize: Math.round((b.glyph !== "" ? 15 : 17) * bar.k)
      color: b.tint
    }
    MouseArea { id: ma; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: b.clicked(); onWheel: function(w) { b.wheel(w) } }
  }
  // Capsule sombre en verre
  component Pill: Rectangle {
    default property alias content: row.data
    property real spacing: 4 * bar.k
    height: Math.round(30 * bar.k); width: row.implicitWidth + Math.round(14 * bar.k)
    radius: height / 2
    color: Qt.rgba(0.11, 0.09, 0.1, 0.72)
    border.color: Qt.rgba(1, 1, 1, 0.08); border.width: 1
    Row { id: row; anchors.centerIn: parent; spacing: parent.spacing }
  }

  // ---------------- gauche
  Pill {
    anchors.left: parent.left; anchors.leftMargin: Math.round(10 * bar.k); anchors.verticalCenter: parent.verticalCenter
    Btn { icon: "power_settings_new"; onClicked: bar.s ? bar.s.powerMenu() : bar.panel("omarchy.power") }
    Btn { icon: "notifications"; onClicked: bar.panel("omarchy.notifications") }
    Btn { icon: "headphones"; onClicked: bar.panel("omarchy.audio") }
    Btn { glyph: String.fromCodePoint(0xf1bc); tint: "#1ed760"; onClicked: bar.run("omarchy-launch-or-focus spotify spotify-launcher") }
    Btn { glyph: String.fromCodePoint(0xf1b6); onClicked: bar.run("omarchy-launch-or-focus steam steam") }
  }

  // ---------------- centre
  Row {
    anchors.centerIn: parent
    spacing: Math.round(8 * bar.k)
    Pill {
      Btn { icon: "settings"; tint: bar.acc; onClicked: bar.panel("liquid-glass.settings") }
      Item {
        width: recRow.implicitWidth + Math.round(8 * bar.k); height: Math.round(26 * bar.k)
        Row {
          id: recRow
          anchors.centerIn: parent; spacing: Math.round(6 * bar.k)
          Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: Math.round(9 * bar.k); height: width; radius: width / 2; color: "#ff4d5e"
            opacity: bar.recording ? (blink.on ? 1 : 0.35) : 0.9
          }
          Text {
            anchors.verticalCenter: parent.verticalCenter
            text: bar.hms(bar.recording ? bar.recSecs : 0)
            font.family: "JetBrainsMono Nerd Font"; font.pixelSize: Math.round(12 * bar.k); color: bar.ink
          }
        }
        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: bar.toggleRec() }
      }
      Btn { icon: bar.micMuted ? "mic_off" : "mic"; tint: bar.micMuted ? "#ff4d5e" : bar.ink; onClicked: bar.run("omarchy-audio-input-mute") }
      Btn { icon: "stop_circle"; tint: bar.recording ? "#ff4d5e" : bar.ink; onClicked: if (bar.recording) bar.toggleRec() }
    }
    // Position sur la toile : visible quand on s'est éloigné du centre.
    Pill {
      visible: !!bar.desk && !bar.desk.atHome
      Btn { icon: "my_location"; tint: bar.acc; onClicked: bar.desk.home() }
      Text {
        anchors.verticalCenter: parent.verticalCenter
        text: bar.desk ? Math.round(-bar.desk.px) + ", " + Math.round(-bar.desk.py) : ""
        font.family: "JetBrainsMono Nerd Font"; font.pixelSize: Math.round(11 * bar.k); color: bar.ink
        rightPadding: Math.round(6 * bar.k)
      }
    }
  }
  Timer { id: blink; property bool on: true; interval: 600; repeat: true; running: bar.recording; onTriggered: on = !on }

  // ---------------- droite
  Pill {
    anchors.right: parent.right; anchors.rightMargin: Math.round(10 * bar.k); anchors.verticalCenter: parent.verticalCenter
    Btn { icon: bar.s && bar.s.netDev === "" ? "wifi_off" : (bar.s && !bar.s.netWifi ? "lan" : "wifi"); onClicked: bar.panel("omarchy.network") }
    Btn {
      icon: !bar.sink || !bar.sink.audio || bar.sink.audio.muted ? "volume_off" : (bar.sink.audio.volume < 0.4 ? "volume_down" : "volume_up")
      onClicked: bar.panel("omarchy.audio")
      onWheel: function(w) { if (bar.sink && bar.sink.audio) bar.sink.audio.volume = Math.max(0, Math.min(1.5, bar.sink.audio.volume + (w.angleDelta.y > 0 ? 0.05 : -0.05))) }
    }
    Btn { icon: "bluetooth"; onClicked: bar.panel("omarchy.bluetooth") }
  }
}
