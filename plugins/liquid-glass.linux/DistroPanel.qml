import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Services.Pipewire
import Quickshell.Services.SystemTray
import Quickshell.Wayland
import Quickshell.Widgets
import "T.js" as T

// Panneau des bureaux de distributions, avec la disposition de chaque environnement :
//   gnome    (Debian, Fedora) : barre noire en haut, Activités, heure au centre, état à droite
//   cinnamon (Mint)           : panneau en bas, menu, lanceurs, liste des fenêtres, heure
//   xfce     (Kali)           : panneau en haut, menu, lanceurs, bureaux, fenêtres, heure
//   plasma   (Arch)           : panneau flottant en bas, Kickoff, tâches, heure sur 2 lignes
PanelWindow {
  id: win
  property var service: null
  readonly property var s: service
  readonly property var d: s.distro
  readonly property string lay: d.layout
  readonly property bool gnome: lay === "gnome"
  readonly property bool plasma: lay === "plasma"
  readonly property bool bottomBar: d.bottom === true
  readonly property int barH: d.barH

  anchors { top: !bottomBar; bottom: bottomBar; left: true; right: true }
  margins { left: plasma ? 8 : 0; right: plasma ? 8 : 0; bottom: plasma ? 6 : 0 }
  implicitHeight: barH
  exclusiveZone: barH + (plasma ? 6 : 0)
  color: "transparent"
  WlrLayershell.layer: WlrLayer.Top
  WlrLayershell.namespace: "liquid-glass-linux-bar"
  WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

  readonly property color ink: gnome ? "#ffffff" : s.colOnSurface
  readonly property string font: s.sansFont
  readonly property var monitor: screen ? Hyprland.monitorFor(screen) : Hyprland.focusedMonitor
  readonly property int activeWs: monitor && monitor.activeWorkspace ? monitor.activeWorkspace.id : 1
  readonly property var tops: ToplevelManager.toplevels.values
  PwObjectTracker { objects: [Pipewire.defaultAudioSink] }
  readonly property var sink: Pipewire.defaultAudioSink
  readonly property real volume: sink && sink.audio ? sink.audio.volume : 0
  readonly property bool muted: !sink || !sink.audio || sink.audio.muted
  property date now: new Date()
  Timer { interval: 1000; repeat: true; running: true; onTriggered: win.now = new Date() }
  function fr(fmt) { return win.now.toLocaleDateString(Qt.locale(T.loc), fmt) }
  function ws(n) { Quickshell.execDetached(["hyprctl", "dispatch", "hl.dsp.focus({ workspace = \"" + n + "\" })"]) }
  function term(cmd) { Quickshell.execDetached(["sh", "-c", cmd]) }

  Rectangle {
    id: body
    anchors.fill: parent
    radius: win.plasma ? 10 : 0
    color: win.gnome ? "#000000" : win.s.alpha(win.s.surfaceMid, win.plasma ? 0.94 : 0.98)
    border.width: win.plasma ? 1 : 0
    border.color: win.s.alpha(win.s.colOnSurface, 0.12)
    // Liseré du panneau (Cinnamon en haut, Xfce en bas).
    Rectangle {
      visible: !win.gnome && !win.plasma
      y: win.bottomBar ? 0 : parent.height - 1
      width: parent.width; height: 1; color: win.s.alpha(win.s.colOnSurface, 0.14)
    }

    Row {
      id: left
      x: win.plasma ? 6 : (win.gnome ? 8 : 2)
      height: parent.height
      spacing: win.gnome ? 6 : 3

      // Menu principal : Activités sous GNOME, logo ailleurs.
      Rectangle {
        id: menuBtn
        anchors.verticalCenter: parent.verticalCenter
        width: menuRow.implicitWidth + 16
        height: parent.height - (win.gnome ? 6 : 4)
        radius: win.gnome ? height / 2 : 4
        color: win.s.launcherOpen ? win.s.alpha(win.gnome ? "#ffffff" : win.s.primary, win.gnome ? 0.22 : 0.9)
                                  : (mma.containsMouse ? win.s.alpha(win.ink, 0.12) : "transparent")
        Row {
          id: menuRow
          anchors.centerIn: parent
          spacing: 6
          Text {
            anchors.verticalCenter: parent.verticalCenter
            text: win.d.glyph
            font.family: "JetBrainsMono Nerd Font"; font.pixelSize: win.gnome ? 14 : win.barH * 0.56
            color: win.gnome || win.s.launcherOpen ? "#ffffff" : win.s.primary
          }
          Text {
            visible: win.d.menuLabel !== ""
            anchors.verticalCenter: parent.verticalCenter
            text: win.d.menuLabel
            font.family: win.font; font.pixelSize: 13; font.weight: win.gnome ? Font.DemiBold : Font.Normal; color: win.ink
          }
        }
        MouseArea { id: mma; anchors.fill: parent; hoverEnabled: true; onClicked: win.s.toggleLauncher() }
      }

      // Fedora : points des bureaux façon GNOME récent, à côté du logo.
      Row {
        visible: win.d.pills === true
        anchors.verticalCenter: parent.verticalCenter
        spacing: 5
        Repeater {
          model: 4
          delegate: Rectangle {
            required property int index
            readonly property bool on: index + 1 === win.activeWs
            anchors.verticalCenter: parent.verticalCenter
            width: on ? 30 : 7; height: 7; radius: 4
            color: on ? "#ffffff" : "#8a8a8a"
            Behavior on width { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
            MouseArea { anchors.fill: parent; anchors.margins: -4; onClicked: win.ws(index + 1) }
          }
        }
      }

      ClaudeButton {
        anchors.verticalCenter: parent.verticalCenter
        s: win.s; size: win.gnome ? 22 : win.barH - 8; iconSize: win.gnome ? 15 : (win.barH - 8) * 0.68; radius: 5
      }

      // Lanceurs rapides (pas sous GNOME).
      Repeater {
        model: win.gnome || win.s.opt(win.s.style + "_launchers", true) === false ? [] : win.s.pinned(win.d.pins)
        delegate: Rectangle {
          id: pin
          required property var modelData
          anchors.verticalCenter: parent.verticalCenter
          width: win.barH - 4; height: win.barH - 4; radius: 4
          color: pma.containsMouse ? win.s.alpha(win.ink, 0.12) : "transparent"
          IconImage { anchors.centerIn: parent; width: win.barH * 0.62; height: width; source: win.s.appIcon(pin.modelData); asynchronous: true }
          MouseArea { id: pma; anchors.fill: parent; hoverEnabled: true; onClicked: win.s.launch(pin.modelData) }
        }
      }

      // Xfce : petits rectangles des bureaux.
      Row {
        visible: win.lay === "xfce"
        anchors.verticalCenter: parent.verticalCenter
        spacing: 2
        leftPadding: 4; rightPadding: 4
        Repeater {
          model: 4
          delegate: Rectangle {
            required property int index
            readonly property bool on: index + 1 === win.activeWs
            width: 26; height: win.barH - 8; radius: 2
            color: on ? win.s.primary : win.s.alpha(win.ink, 0.08)
            border.width: 1; border.color: win.s.alpha(win.ink, 0.2)
            Text { anchors.centerIn: parent; text: index + 1; font.family: win.font; font.pixelSize: 10; color: on ? "white" : win.ink }
            MouseArea { anchors.fill: parent; onClicked: win.ws(index + 1) }
          }
        }
      }
    }

    // Liste des fenêtres (Cinnamon, Xfce, Plasma).
    Item {
      visible: !win.gnome
      x: left.x + left.width + 6
      width: right.x - x - 6; height: parent.height
      clip: true
      Row {
        height: parent.height
        spacing: 2
        Repeater {
          model: win.gnome ? [] : win.tops
          delegate: Rectangle {
            id: task
            required property var modelData
            readonly property var entry: DesktopEntries.heuristicLookup(modelData.appId)
            anchors.verticalCenter: parent.verticalCenter
            width: win.plasma ? win.barH : 170
            height: win.barH - 4; radius: 4
            color: modelData.activated ? win.s.alpha(win.s.primary, 0.3) : (tma.containsMouse ? win.s.alpha(win.ink, 0.1) : "transparent")
            Rectangle {
              anchors.horizontalCenter: parent.horizontalCenter
              y: win.bottomBar ? parent.height - 2 : 0
              width: task.modelData.activated ? parent.width : parent.width * 0.5; height: 2
              color: win.s.primary
            }
            Row {
              x: win.plasma ? (parent.width - 22) / 2 : 6
              anchors.verticalCenter: parent.verticalCenter
              spacing: 6
              IconImage {
                anchors.verticalCenter: parent.verticalCenter
                width: win.plasma ? 22 : 16; height: width; asynchronous: true
                source: task.entry ? win.s.appIcon(task.entry)
                                 : Quickshell.iconPath(String(task.modelData.appId || "").toLowerCase(), "application-x-executable")
              }
              Text {
                visible: !win.plasma
                anchors.verticalCenter: parent.verticalCenter
                width: 134; elide: Text.ElideRight
                text: String(task.modelData.title || task.modelData.appId || "")
                font.family: win.font; font.pixelSize: 12; color: win.ink
              }
            }
            MouseArea { id: tma; anchors.fill: parent; hoverEnabled: true; onClicked: task.modelData.activate() }
          }
        }
      }
    }

    // Heure au centre sous GNOME.
    Rectangle {
      visible: win.gnome
      anchors.centerIn: parent
      width: gclock.implicitWidth + 22; height: parent.height - 6; radius: height / 2
      color: gcm.containsMouse ? win.s.alpha("#ffffff", 0.14) : "transparent"
      Text {
        id: gclock
        anchors.centerIn: parent
        text: win.fr("ddd d MMM") + "  " + Qt.formatTime(win.now, win.s.opt(win.s.style + "_seconds", false) === true ? "HH:mm:ss" : "HH:mm")
        font.family: win.font; font.pixelSize: 13; font.weight: Font.DemiBold; color: "#ffffff"
      }
      MouseArea { id: gcm; anchors.fill: parent; hoverEnabled: true; onClicked: win.s.toggleMenu("home") }
    }

    Row {
      id: right
      anchors.right: parent.right; anchors.rightMargin: win.gnome ? 8 : 4
      height: parent.height
      spacing: 6

      Repeater {
        model: SystemTray.items
        delegate: Item {
          id: tray
          required property var modelData
          anchors.verticalCenter: parent.verticalCenter
          width: 18; height: 18
          IconImage { anchors.fill: parent; source: tray.modelData.icon; asynchronous: true }
          MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            onClicked: function(m) {
              var it = tray.modelData
              if (m.button === Qt.RightButton || it.onlyMenu) {
                if (it.hasMenu) { var p = tray.mapToItem(null, 0, win.bottomBar ? -8 : tray.height + 6); it.display(win, p.x, p.y) }
              } else it.activate()
            }
          }
        }
      }

      // État : réseau, son, batterie ; ouvre le volet rapide.
      Rectangle {
        anchors.verticalCenter: parent.verticalCenter
        width: st.implicitWidth + 16; height: parent.height - (win.gnome ? 6 : 4); radius: win.gnome ? height / 2 : 4
        color: sma.containsMouse || win.s.menuOpen ? win.s.alpha(win.ink, 0.14) : "transparent"
        Row {
          id: st
          anchors.centerIn: parent
          spacing: 8
          MIcon { anchors.verticalCenter: parent.verticalCenter; icon: win.s.netDev === "" ? "wifi_off" : (win.s.netWifi ? "wifi" : "lan"); size: 16; fill: 1; color: win.ink }
          MIcon { anchors.verticalCenter: parent.verticalCenter; icon: win.muted ? "volume_off" : "volume_up"; size: 16; fill: 1; color: win.ink }
          Row {
            visible: win.s.batteryPct >= 0
            anchors.verticalCenter: parent.verticalCenter
            spacing: 2
            MIcon {
              anchors.verticalCenter: parent.verticalCenter; rotation: 90; size: 16; fill: 1
              icon: win.s.charging ? "battery_charging_full" : "battery_full"
              color: !win.s.charging && win.s.batteryPct <= 15 ? win.s.errorColor : win.ink
            }
            Text {
              visible: !win.gnome
              anchors.verticalCenter: parent.verticalCenter
              text: win.s.batteryPct + " %"; font.family: win.font; font.pixelSize: 12; color: win.ink
            }
          }
          MIcon { visible: win.gnome; anchors.verticalCenter: parent.verticalCenter; icon: "power_settings_new"; size: 16; color: win.ink }
        }
        MouseArea {
          id: sma; anchors.fill: parent; hoverEnabled: true
          onClicked: win.s.toggleMenu("home")
          onWheel: function(w) { win.term("wpctl set-volume -l 1.0 @DEFAULT_AUDIO_SINK@ 5%" + (w.angleDelta.y > 0 ? "+" : "-")) }
        }
      }

      // Heure : deux lignes sous Plasma, une ligne ailleurs.
      Item {
        visible: !win.gnome
        anchors.verticalCenter: parent.verticalCenter
        width: clockCol.implicitWidth + 12; height: parent.height
        Column {
          id: clockCol
          anchors.centerIn: parent
          Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: win.lay === "xfce" ? win.fr("ddd d MMM") + "  " + Qt.formatTime(win.now, win.s.opt(win.s.style + "_seconds", false) === true ? "HH:mm:ss" : "HH:mm") : Qt.formatTime(win.now, win.s.opt(win.s.style + "_seconds", false) === true ? "HH:mm:ss" : "HH:mm")
            font.family: win.font; font.pixelSize: win.plasma ? 13 : 12; color: win.ink
          }
          Text {
            visible: win.bottomBar
            anchors.horizontalCenter: parent.horizontalCenter
            text: win.fr("dd/MM/yyyy")
            font.family: win.font; font.pixelSize: 10; color: win.s.colOnSurfaceVariant
          }
        }
        MouseArea { anchors.fill: parent; onClicked: win.s.toggleMenu("home") }
      }
      // Plasma : afficher le bureau, à l'extrême droite.
      Rectangle {
        visible: win.plasma
        anchors.verticalCenter: parent.verticalCenter
        width: 8; height: parent.height - 12; radius: 2
        color: dma.containsMouse ? win.s.primary : win.s.alpha(win.ink, 0.18)
        MouseArea { id: dma; anchors.fill: parent; hoverEnabled: true; onClicked: win.ws(10) }
      }
    }
  }
}
