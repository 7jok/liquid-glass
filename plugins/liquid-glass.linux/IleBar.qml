import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import "T.js" as T

// Style Île, barre du haut : très fine, sans fond. L'encoche passe par-dessus au milieu.
PanelWindow {
  id: win
  property var service: null
  readonly property var s: service

  anchors { top: true; left: true; right: true }
  implicitHeight: 26
  exclusiveZone: 26
  color: "transparent"
  WlrLayershell.layer: WlrLayer.Top
  WlrLayershell.namespace: "liquid-glass-linux-bar"
  WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

  readonly property color ink: "#c9c2cc"
  readonly property color sub: "#8a8490"
  readonly property var tl: Hyprland.activeToplevel
  readonly property string app: {
    var c = tl && tl.wayland ? String(tl.wayland.appId || "") : ""
    if (c === "") return T.t("Bureau")
    c = c.split(".").pop()
    return c.charAt(0).toUpperCase() + c.slice(1)
  }
  property date now: new Date()
  Timer { interval: 10000; repeat: true; running: true; onTriggered: win.now = new Date() }

  Rectangle { anchors.fill: parent; color: "#17151b"; opacity: 0.55 }

  component Word: Text {
    property bool strong: false
    property var act: null
    anchors.verticalCenter: parent.verticalCenter
    color: win.ink
    font.family: win.s.sansFont
    font.pixelSize: 12
    font.weight: strong ? Font.DemiBold : Font.Normal
    textFormat: Text.PlainText
    MouseArea { anchors.fill: parent; anchors.margins: -5; onClicked: if (parent.act) parent.act() }
  }

  Row {
    anchors { left: parent.left; leftMargin: 12; top: parent.top; bottom: parent.bottom }
    spacing: 16
    MIcon {
      anchors.verticalCenter: parent.verticalCenter
      icon: "deployed_code"; size: 15; fill: 1; color: win.ink
      MouseArea { anchors.fill: parent; anchors.margins: -5; onClicked: win.s.togglePanel("ile-menu") }
    }
    Word { text: win.app; strong: true; act: function() { win.s.toggleLauncher() } }
    Word { text: T.t("Fichier"); act: function() { win.s.run("uwsm-app -- nautilus --new-window") } }
    Word { text: T.t("Fenêtre"); act: function() { win.s.run("hyprctl dispatch 'hl.dsp.window.float({ action = \"toggle\" })'") } }
    Word { text: T.t("Aide"); act: function() { win.s.toggleKeys() } }
  }

  Row {
    anchors { right: parent.right; rightMargin: 12; top: parent.top; bottom: parent.bottom }
    spacing: 13
    MIcon { anchors.verticalCenter: parent.verticalCenter; icon: win.s.netDev === "" ? "wifi_off" : (win.s.netWifi ? "wifi" : "lan"); size: 14; color: win.ink }
    Word { text: win.s.batteryPct >= 0 ? win.s.batteryPct + " %" : ""; visible: text !== "" }
    MIcon {
      anchors.verticalCenter: parent.verticalCenter
      icon: "toggle_on"; size: 16; color: win.ink
      MouseArea { anchors.fill: parent; anchors.margins: -5; onClicked: win.s.togglePanel("ile-cc") }
    }
    Word { text: win.now.toLocaleString(Qt.locale(T.loc), "ddd d MMM  HH:mm"); act: function() { win.s.togglePanel("ile-cc") } }
  }
}
