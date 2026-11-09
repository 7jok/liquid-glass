import QtQuick
import Quickshell
import Quickshell.Services.Pipewire
import Quickshell.Wayland
import Quickshell.Widgets
import "T.js" as T

// Style Île : menu système, confirmation d'extinction, centre de contrôle, volume.
PanelWindow {
  id: win
  property var service: null
  readonly property var s: service

  anchors { top: true; bottom: true; left: true; right: true }
  exclusionMode: ExclusionMode.Ignore
  color: "transparent"
  mask: Region { item: open ? catcher : osd }
  WlrLayershell.layer: WlrLayer.Overlay
  WlrLayershell.namespace: "liquid-glass-linux-ile-panels"
  WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

  readonly property color ink: "#c9c2cc"
  readonly property color sub: "#8a8490"
  readonly property bool menu: s.panel === "ile-menu"
  readonly property bool cc: s.panel === "ile-cc"
  readonly property bool off: s.panel === "ile-off"
  readonly property bool open: menu || cc || off

  PwObjectTracker { objects: [Pipewire.defaultAudioSink] }
  readonly property var sink: Pipewire.defaultAudioSink
  readonly property real vol: sink && sink.audio ? sink.audio.volume : 0

  MouseArea { id: catcher; anchors.fill: parent; enabled: win.open; onClicked: win.s.closeAll() }

  // Menu système : bleu au survol, comme un menu de Mac.
  Rectangle {
    visible: win.menu
    x: 10; y: 30; width: 236; height: col.height + 12; radius: 8
    color: "#1b191f"; border.color: Qt.rgba(1, 1, 1, 0.1); border.width: 1
    MouseArea { anchors.fill: parent }
    Column {
      id: col
      x: 6; y: 6; width: parent.width - 12
      Repeater {
        model: [
          [T.t("Moniteur système"), "uwsm-app -- xdg-terminal-exec -e btop"], [T.t("Réglages…"), "omarchy-shell liquid-glass.settings openPage linux"], ["-", ""],
          [T.t("Suspendre"), "@suspend"], [T.t("Redémarrer…"), "@reboot"], [T.t("Éteindre…"), "@off"], ["-", ""],
          [T.t("Verrouiller l'écran"), "@lock"], [T.t("Fermer la session"), "@logout"]
        ]
        Item {
          id: line
          required property var modelData
          width: col.width
          height: modelData[0] === "-" ? 9 : 25
          Rectangle { visible: line.modelData[0] === "-"; anchors.centerIn: parent; width: parent.width - 12; height: 1; color: Qt.rgba(1, 1, 1, 0.1) }
          Rectangle { visible: line.modelData[0] !== "-" && over.hovered; anchors.fill: parent; radius: 5; color: "#1f4fd1" }
          Text {
            visible: line.modelData[0] !== "-"
            x: 10; anchors.verticalCenter: parent.verticalCenter
            text: line.modelData[0]; color: over.hovered ? "#ffffff" : win.ink
            font.family: win.s.sansFont; font.pixelSize: 13; textFormat: Text.PlainText
          }
          HoverHandler { id: over }
          TapHandler {
            onTapped: {
              var c = line.modelData[1]
              if (c === "@off") { win.s.panel = "ile-off"; return }
              if (c === "@suspend") win.s.power("suspend")
              else if (c === "@reboot") win.s.power("reboot")
              else if (c === "@lock") win.s.power("lock")
              else if (c === "@logout") win.s.power("logout")
              else if (c !== "") { win.s.closeAll(); win.s.run(c) }
            }
          }
        }
      }
    }
  }

  // Confirmation : triangle jaune, deux boutons.
  Rectangle {
    visible: win.off
    anchors.centerIn: parent
    width: 270; height: 214; radius: 12
    color: "#1b191f"; border.color: Qt.rgba(1, 1, 1, 0.1); border.width: 1
    MouseArea { anchors.fill: parent }
    MIcon { x: (parent.width - width) / 2; y: 20; icon: "warning"; size: 54; fill: 1; color: "#e8b13a" }
    Text {
      x: 22; y: 86; width: parent.width - 44
      horizontalAlignment: Text.AlignHCenter; wrapMode: Text.WordWrap
      text: T.t("Voulez-vous éteindre cet ordinateur ?")
      color: win.ink; font.family: win.s.sansFont; font.pixelSize: 14; font.weight: Font.DemiBold
    }
    Row {
      anchors { bottom: parent.bottom; bottomMargin: 18; horizontalCenter: parent.horizontalCenter }
      spacing: 10
      Repeater {
        model: [[T.t("Annuler"), false], [T.t("Éteindre"), true]]
        Rectangle {
          id: btn
          required property var modelData
          width: 110; height: 32; radius: 7
          color: modelData[1] ? "#1f4fd1" : "#35313b"
          Text { anchors.centerIn: parent; text: btn.modelData[0]; color: "#ffffff"; font.family: win.s.sansFont; font.pixelSize: 13 }
          TapHandler { onTapped: { if (btn.modelData[1]) win.s.power("poweroff"); else win.s.closeAll() } }
        }
      }
    }
  }

  // Centre de contrôle
  Rectangle {
    visible: win.cc
    anchors { right: parent.right; rightMargin: 10; top: parent.top; topMargin: 30 }
    width: 320; height: ccCol.height + 24; radius: 16
    color: "#1b191f"; border.color: Qt.rgba(1, 1, 1, 0.08); border.width: 1
    MouseArea { anchors.fill: parent }
    Column {
      id: ccCol
      x: 12; y: 12; width: parent.width - 24; spacing: 10
      Row {
        spacing: 10
        Rectangle {
          width: 170; height: 124; radius: 12; color: "#26232b"
          Column {
            anchors.centerIn: parent; spacing: 11; width: parent.width - 20
            Repeater {
              model: [["wifi", "Wi-Fi", "nm-connection-editor"], ["bluetooth", "Bluetooth", "omarchy-bluetooth-power toggle"], ["dark_mode", T.t("Thème sombre"), "liquid-glass mode toggle"]]
              Row {
                id: cr
                required property var modelData
                spacing: 9
                Rectangle {
                  width: 26; height: 26; radius: 13; color: "#7c74c8"
                  MIcon { anchors.centerIn: parent; icon: cr.modelData[0]; size: 15; color: "#ffffff" }
                  TapHandler { onTapped: win.s.run(cr.modelData[2]) }
                }
                Text { anchors.verticalCenter: parent.verticalCenter; text: cr.modelData[1]; color: win.ink; font.family: win.s.sansFont; font.pixelSize: 12; font.weight: Font.DemiBold }
              }
            }
          }
        }
        Column {
          spacing: 10
          Repeater {
            model: [["nightlight", T.t("Lumière nocturne"), "omarchy-toggle-nightlight"], ["screen_record", T.t("Enregistrer"), "omarchy-capture-screenrecording"]]
            Rectangle {
              id: cb
              required property var modelData
              width: 116; height: 57; radius: 12; color: "#26232b"
              Column {
                anchors.centerIn: parent; spacing: 2
                MIcon { anchors.horizontalCenter: parent.horizontalCenter; icon: cb.modelData[0]; size: 17; color: win.ink }
                Text { anchors.horizontalCenter: parent.horizontalCenter; text: cb.modelData[1]; color: win.ink; font.family: win.s.sansFont; font.pixelSize: 10 }
              }
              TapHandler { onTapped: { win.s.closeAll(); win.s.run(cb.modelData[2]) } }
            }
          }
        }
      }
      Repeater {
        model: [[T.t("Écran"), "light_mode", "b"], [T.t("Son"), "volume_up", "v"]]
        Rectangle {
          id: sl
          required property var modelData
          readonly property real level: modelData[2] === "v" ? win.vol : Math.max(0, win.s.brightness) / 100
          width: ccCol.width; height: 58; radius: 12; color: "#26232b"
          Text { x: 12; y: 8; text: sl.modelData[0]; color: win.ink; font.family: win.s.sansFont; font.pixelSize: 11; font.weight: Font.DemiBold }
          Rectangle {
            x: 12; y: 28; width: parent.width - 24; height: 20; radius: 10; color: "#3a3640"
            Rectangle { width: Math.max(20, parent.width * sl.level); height: parent.height; radius: 10; color: win.ink }
            MIcon { x: 4; anchors.verticalCenter: parent.verticalCenter; icon: sl.modelData[1]; size: 13; color: "#26232b" }
            MouseArea {
              anchors.fill: parent
              function apply(mx) {
                var v = Math.max(0, Math.min(1, mx / width))
                if (sl.modelData[2] === "v") { if (win.sink && win.sink.audio) win.sink.audio.volume = v }
                else win.s.setBrightness(Math.round(v * 100))
              }
              onPressed: function(e) { apply(e.x) }
              onPositionChanged: function(e) { if (pressed) apply(e.x) }
            }
          }
        }
      }
      Rectangle {
        width: ccCol.width; height: 52; radius: 12; color: "#26232b"
        ClippingRectangle {
          id: ccArt
          x: 9; y: 9; width: 34; height: 34; radius: 6; color: "#35313b"
          Image { anchors.fill: parent; source: win.s.cover; fillMode: Image.PreserveAspectCrop }
        }
        Text {
          anchors { left: ccArt.right; leftMargin: 10; right: ccCtl.left; rightMargin: 8; verticalCenter: parent.verticalCenter }
          text: win.s.trackTitle || T.t("Aucune musique"); color: win.ink; elide: Text.ElideRight
          font.family: win.s.sansFont; font.pixelSize: 12; font.weight: Font.DemiBold; textFormat: Text.PlainText
        }
        Row {
          id: ccCtl
          anchors { right: parent.right; rightMargin: 10; verticalCenter: parent.verticalCenter }
          spacing: 8
          MIcon { icon: "skip_previous"; size: 18; fill: 1; color: win.ink; TapHandler { onTapped: if (win.s.player) win.s.player.previous() } }
          MIcon { icon: win.s.playing ? "pause" : "play_arrow"; size: 18; fill: 1; color: win.ink; TapHandler { onTapped: win.s.playPause() } }
          MIcon { icon: "skip_next"; size: 18; fill: 1; color: win.ink; TapHandler { onTapped: if (win.s.player) win.s.player.next() } }
        }
      }
    }
  }

  // Volume : carré discret en bas, au moindre changement.
  property real shownVol: -1
  onVolChanged: { if (shownVol >= 0) { osd.opacity = 1; hideOsd.restart() } shownVol = vol }
  Timer { id: hideOsd; interval: 1600; onTriggered: osd.opacity = 0 }
  Rectangle {
    id: osd
    anchors { horizontalCenter: parent.horizontalCenter; bottom: parent.bottom; bottomMargin: 110 }
    width: 104; height: 104; radius: 14
    color: "#26232b"; opacity: 0
    Behavior on opacity { NumberAnimation { duration: 220 } }
    MIcon { anchors.centerIn: parent; anchors.verticalCenterOffset: -6; icon: win.vol <= 0 ? "volume_off" : "volume_up"; size: 54; fill: 1; color: win.sub }
    Row {
      anchors { bottom: parent.bottom; bottomMargin: 12; horizontalCenter: parent.horizontalCenter }
      spacing: 2
      Repeater {
        model: 16
        Rectangle { required property int index; width: 3; height: 5; color: index / 16 < win.vol ? win.ink : "#3a3640" }
      }
    }
  }
}
