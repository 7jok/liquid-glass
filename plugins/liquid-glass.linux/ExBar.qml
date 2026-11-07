import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Widgets
import Quickshell.Services.SystemTray
import Quickshell.Services.Pipewire
import Quickshell.Bluetooth
import "T.js" as T

// Barre façon end4-pC (style « Float ») : une bande arrondie aux couleurs
// Material You, découpée en îlots.
//   gauche : ✦ menu Omarchy · fenêtre active (classe / titre) · CPU et RAM en anneaux
//   centre : morceau en cours (anneau de progression) · espaces (indicateur
//            élastique) · date, heure et météo
//   droite : capture, enregistrement, pipette, fonds (carrousel) · tray ·
//            volume, réseau, Bluetooth, batterie · alimentation
PanelWindow {
  id: win
  property var service: null
  readonly property var s: service

  readonly property int barH: 34
  readonly property int pillH: 26
  color: "transparent"
  anchors { top: true; left: true; right: true }
  margins { top: 5; left: 6; right: 6 }
  // Peau : « line » (blanc, sombre) = bande fine presque carrée, bordure d'encre ;
  // « chunky » (jouet) = contour épais et ombre dure ; « float » = îlot arrondi.
  readonly property string kind: s.skin && s.skin.bar ? s.skin.bar : "float"
  readonly property bool hard: kind === "chunky"
  implicitHeight: barH + (hard ? 5 : 0)
  exclusiveZone: barH + 3
  WlrLayershell.layer: WlrLayer.Top
  WlrLayershell.namespace: "liquid-glass-linux-bar"
  WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

  readonly property var monitor: screen ? Hyprland.monitorFor(screen) : Hyprland.focusedMonitor
  readonly property int activeWs: monitor && monitor.activeWorkspace ? monitor.activeWorkspace.id : 1

  function run(cmd) { Quickshell.execDetached(["sh", "-c", cmd]) }
  function dispatch(expr) { Quickshell.execDetached(["hyprctl", "dispatch", expr]) }

  property date now: new Date()
  Timer { interval: 1000; repeat: true; running: true; onTriggered: win.now = new Date() }

  // Place restante si tous les îlots étaient affichés (écran 1280 px logiques :
  // le centre chevauchait la droite). Négatif : on masque les outils, puis les jauges.
  // Mesuré par minuterie : en liaison directe, ce serait une boucle (visible → largeur → visible).
  property int compact: 0
  Timer {
    interval: 400; repeat: true; running: true; triggeredOnStart: true
    onTriggered: {
      var full = body.width - 28 - center.width
        - (left.width + (resIsl.visible || win.s.wall ? 0 : resIsl.width + 6))
        - (right.width + (toolsIsl.visible ? 0 : toolsIsl.width + 6))
      win.compact = full >= 0 ? 0 : (full + toolsIsl.width + 6 >= 0 ? 1 : 2)
    }
  }

  PwObjectTracker { objects: [Pipewire.defaultAudioSink] }
  readonly property var sink: Pipewire.defaultAudioSink
  readonly property real volume: sink && sink.audio ? sink.audio.volume : 0
  readonly property bool muted: !sink || !sink.audio || sink.audio.muted
  readonly property var bt: Bluetooth.defaultAdapter
  readonly property bool btOn: !!bt && bt.enabled
  readonly property bool btConnected: {
    if (!btOn || !bt.devices) return false
    var d = bt.devices.values
    for (var i = 0; i < d.length; i++) if (d[i].connected) return true
    return false
  }

  Rectangle {
    visible: win.hard
    x: 4; y: 4
    width: body.width; height: body.height
    radius: body.radius
    color: "#1b1030"
  }
  Rectangle {
    id: body
    width: parent.width
    height: win.barH
    radius: win.kind === "line" ? Math.min(8, s.radius) : (win.hard ? 14 : height / 2)
    color: win.kind === "line" ? s.alpha(s.surface, 0.97) : (s.style === "violet" ? s.alpha(s.surface, 0.82) : s.alpha(s.surface, 0.94))
    border.width: win.hard ? 2.5 : 1
    border.color: win.hard ? "#1b1030" : (win.kind === "line" ? s.alpha(s.colOnSurface, s.darkSkin ? 0.35 : 0.85) : s.alpha(s.outlineVariant, 0.35))

    // ------------------------------------------------------------ gauche
    Row {
      id: left
      anchors.left: parent.left
      anchors.leftMargin: 4
      anchors.verticalCenter: parent.verticalCenter
      spacing: 6

      IconButton {
        icon: "auto_awesome"; fill: 1
        size: win.pillH; iconSize: 16
        tint: s.primary
        base: s.alpha(s.primary, 0.14)
        onClicked: s.toggleLauncher()
      }
      ClaudeButton { s: win.s; size: win.pillH; mono: win.s.style === "blanc" || win.s.style === "sombre" }

      // Fenêtre active : classe en petit, titre dessous ; « Bureau / Espace N » sinon.
      Item {
        id: winLabel
        readonly property var ws: Hyprland.focusedWorkspace
        readonly property var tl: Hyprland.activeToplevel
        readonly property bool empty: !tl || !ws || !tl.workspace || tl.workspace.id !== ws.id
        readonly property string appId: !empty && tl.wayland ? String(tl.wayland.appId || "") : ""
        width: Math.min(170, Math.max(top1.implicitWidth, top2.implicitWidth))
        height: win.pillH
        Column {
          anchors.verticalCenter: parent.verticalCenter
          width: parent.width
          spacing: -1
          Text {
            id: top1
            width: parent.width
            text: winLabel.empty ? T.t("Bureau") : (winLabel.appId !== "" ? winLabel.appId : T.t("Fenêtre"))
            elide: Text.ElideRight
            font.family: s.sansFont
            font.pixelSize: 9
            color: s.colOnSurfaceVariant
          }
          Text {
            id: top2
            width: parent.width
            text: winLabel.empty ? T.t("Espace ") + win.activeWs : String(winLabel.tl.title || "")
            elide: Text.ElideRight
            font.family: s.sansFont
            font.pixelSize: 12
            font.weight: Font.Medium
            color: s.colOnSurface
          }
        }
      }

      Island {
        id: resIsl
        // Sombre affiche déjà tout ça sur son mur ; sinon on cède la place à la date.
        visible: !s.wall && win.compact < 2
        Row {
          spacing: 10
          anchors.verticalCenter: parent.verticalCenter
          Resource { icon: "memory"; value: s.cpu; label: Math.round(s.cpu * 100) }
          Resource { icon: "memory_alt"; value: s.memPct; label: Math.round(s.memPct * 100) }
          Resource { icon: "thermostat"; value: Math.min(1, s.temp / 100); label: s.temp + "°"; visible: s.temp > 0; hot: s.temp >= 80 }
        }
        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: win.run("omarchy-launch-or-focus-tui btop") }
      }
    }

    // ------------------------------------------------------------ centre
    Row {
      id: center
      spacing: 6
      anchors.verticalCenter: parent.verticalCenter
      x: Math.max(left.x + left.width + 10, Math.min(right.x - 10 - width, (body.width - width) / 2))
      Behavior on x { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }

      // Morceau en cours
      Island {
        visible: (s.hasTrack || s.resumeMode) && !s.wall
        Row {
          spacing: 7
          anchors.verticalCenter: parent.verticalCenter
          // Petit égaliseur qui suit la musique (cava).
          Row {
            visible: s.playing && s.cavaValues.length > 0
            anchors.verticalCenter: parent.verticalCenter
            height: 14
            spacing: 2
            Repeater {
              model: 5
              delegate: Rectangle {
                required property int index
                readonly property int n: s.cavaValues.length
                width: 3
                radius: win.kind === "line" ? 0 : 1.5
                anchors.bottom: parent.bottom
                height: Math.max(2, 14 * (n > 0 ? s.cavaValues[Math.floor((index + 0.5) / 5 * n * 0.6)] / 100 : 0))
                color: s.style === "jouet" ? s.rainbow[index] : s.primary
                Behavior on height { NumberAnimation { duration: 70 } }
              }
            }
          }
          Item {
            width: 20; height: 20
            anchors.verticalCenter: parent.verticalCenter
            Ring { anchors.fill: parent; value: s.progress; thickness: 2; color: s.primary; track: s.alpha(s.colOnSurface, 0.15) }
            MIcon { anchors.centerIn: parent; icon: s.playing ? "pause" : "play_arrow"; size: 13; fill: 1; color: s.primary }
          }
          Text {
            anchors.verticalCenter: parent.verticalCenter
            width: Math.min(implicitWidth, 170)
            text: s.trackTitle + (s.trackArtist !== "" ? " • " + s.trackArtist : "")
            elide: Text.ElideRight
            font.family: s.sansFont
            font.pixelSize: 12
            color: s.colOnSurface
          }
        }
        MouseArea {
          anchors.fill: parent
          cursorShape: Qt.PointingHandCursor
          acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
          onClicked: function(m) {
            if (m.button === Qt.RightButton && s.hasTrack) s.player.next()
            else if (m.button === Qt.MiddleButton && s.hasTrack) s.player.previous()
            else s.playPause()
          }
        }
      }

      // Espaces de travail : points (vides / occupés), indicateur primaire
      // élastique (bord avant rapide, bord arrière en retard, petit rebond).
      Island {
        id: wsIsland
        hpad: 4
        readonly property int slot: 22
        readonly property var occupied: {
          var o = {}
          var vals = Hyprland.workspaces ? Hyprland.workspaces.values : []
          for (var i = 0; i < vals.length; i++) if (vals[i].id > 0) o[vals[i].id] = true
          return o
        }
        readonly property int count: Math.max(s.wsCount, win.activeWs)
        Item {
          width: wsIsland.count * wsIsland.slot
          height: win.pillH
          anchors.verticalCenter: parent.verticalCenter

          property real a: win.activeWs - 1
          property real b: win.activeWs - 1
          Behavior on a { NumberAnimation { duration: 160; easing.type: Easing.OutSine } }
          Behavior on b { NumberAnimation { duration: 460; easing.type: Easing.OutBack; easing.overshoot: 2.2 } }
          Rectangle {
            x: Math.min(parent.a, parent.b) * wsIsland.slot + 1
            width: Math.abs(parent.a - parent.b) * wsIsland.slot + wsIsland.slot - 2
            height: 20
            radius: 10
            anchors.verticalCenter: parent.verticalCenter
            color: s.primary
          }
          Row {
            Repeater {
              model: wsIsland.count
              delegate: Item {
                required property int index
                readonly property int ws: index + 1
                readonly property bool active: ws === win.activeWs
                readonly property bool used: !!wsIsland.occupied[ws]
                width: wsIsland.slot
                height: win.pillH
                Rectangle {
                  anchors.centerIn: parent
                  width: parent.used ? 6 : 4
                  height: width
                  radius: width / 2
                  color: parent.used ? s.colOnSurfaceVariant : s.alpha(s.colOnSurfaceVariant, 0.4)
                  opacity: parent.active ? 0 : 1
                  Behavior on opacity { NumberAnimation { duration: 150 } }
                }
                Text {
                  anchors.centerIn: parent
                  text: String(parent.ws)
                  font.family: s.numFont
                  font.pixelSize: 11
                  font.weight: Font.DemiBold
                  color: s.colOnPrimary
                  opacity: parent.active ? 1 : 0
                  scale: parent.active ? 1 : 0.5
                  Behavior on opacity { NumberAnimation { duration: 200 } }
                  Behavior on scale { NumberAnimation { duration: 320; easing.type: Easing.OutBack; easing.overshoot: 2.5 } }
                }
                MouseArea {
                  anchors.fill: parent
                  cursorShape: Qt.PointingHandCursor
                  onClicked: win.dispatch("hl.dsp.focus({ workspace = \"" + parent.ws + "\" })")
                }
              }
            }
          }
        }
        MouseArea {
          anchors.fill: parent
          acceptedButtons: Qt.NoButton
          onWheel: function(w) { win.dispatch("hl.dsp.focus({ workspace = \"" + (w.angleDelta.y > 0 ? "e-1" : "e+1") + "\" })") }
        }
      }

      // Date • heure, météo
      Island {
        Row {
          spacing: 8
          anchors.verticalCenter: parent.verticalCenter
          Text {
            anchors.verticalCenter: parent.verticalCenter
            text: {
              var d = win.now.toLocaleDateString(Qt.locale(T.loc), "ddd dd/MM")
              return d.charAt(0).toUpperCase() + d.slice(1) + "  •  " + Qt.formatTime(win.now, "HH:mm")
            }
            font.family: s.sansFont
            font.pixelSize: 12
            font.weight: Font.Medium
            color: s.colOnSurface
          }
          Row {
            visible: !!s.weather
            spacing: 3
            anchors.verticalCenter: parent.verticalCenter
            MIcon { icon: s.weatherIcon; size: 15; fill: 1; color: s.primary; anchors.verticalCenter: parent.verticalCenter }
            Text {
              anchors.verticalCenter: parent.verticalCenter
              text: s.weather ? s.weather.temp + "°C" : ""
              font.family: s.sansFont
              font.pixelSize: 12
              color: s.colOnSurface
            }
          }
        }
      }
    }

    // ------------------------------------------------------------ droite
    Row {
      id: right
      anchors.right: parent.right
      anchors.rightMargin: 4
      anchors.verticalCenter: parent.verticalCenter
      spacing: 6

      Island {
        id: toolsIsl
        hpad: 3
        visible: win.compact < 1
        Row {
          anchors.verticalCenter: parent.verticalCenter
          spacing: 0
          IconButton { icon: "screenshot_region"; onClicked: win.run("omarchy-capture-screenshot") }
          IconButton { icon: "screen_record"; onClicked: win.run("omarchy-capture-screenrecording") }
          IconButton { icon: "colorize"; onClicked: win.run("hyprpicker -a") }
          IconButton { icon: "wallpaper"; onClicked: s.wallsOpen = !s.wallsOpen }
        }
      }

      Island {
        visible: SystemTray.items.values.length > 0
        hpad: 6
        Row {
          anchors.verticalCenter: parent.verticalCenter
          spacing: 6
          Repeater {
            model: SystemTray.items
            delegate: Item {
              id: trayItem
              required property var modelData
              width: 18; height: 18
              anchors.verticalCenter: parent.verticalCenter
              IconImage { anchors.fill: parent; source: trayItem.modelData.icon; asynchronous: true }
              MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
                onClicked: function(m) {
                  var it = trayItem.modelData
                  if (m.button === Qt.MiddleButton) it.secondaryActivate()
                  else if (m.button === Qt.RightButton || it.onlyMenu) {
                    if (it.hasMenu) { var p = trayItem.mapToItem(null, 0, trayItem.height + 6); it.display(win, p.x, p.y) }
                  } else it.activate()
                }
                onWheel: function(w) { trayItem.modelData.scroll(w.angleDelta.y, false) }
              }
            }
          }
        }
      }

      Island {
        hpad: 4
        Row {
          anchors.verticalCenter: parent.verticalCenter
          spacing: 0
          IconButton {
            icon: win.muted ? "volume_off" : (win.volume < 0.34 ? "volume_mute" : (win.volume < 0.67 ? "volume_down" : "volume_up"))
            onClicked: s.toggleMenu("home")
            onRightClicked: win.run("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle")
            onWheel: function(d) { win.run("wpctl set-volume -l 1.0 @DEFAULT_AUDIO_SINK@ 5%" + (d > 0 ? "+" : "-")) }
          }
          IconButton {
            icon: s.netDev === "" ? "signal_wifi_off" : (s.netWifi ? "wifi" : "lan")
            onClicked: s.toggleMenu("home")
          }
          IconButton {
            visible: !!win.bt
            icon: !win.btOn ? "bluetooth_disabled" : (win.btConnected ? "bluetooth_connected" : "bluetooth")
            onClicked: s.toggleMenu("home")
          }
          Row {
            visible: s.batteryPct >= 0
            spacing: 2
            anchors.verticalCenter: parent.verticalCenter
            leftPadding: 2; rightPadding: 6
            MIcon {
              anchors.verticalCenter: parent.verticalCenter
              rotation: 90
              size: 17
              fill: 1
              color: !s.charging && s.batteryPct <= 15 ? s.errorColor : s.colOnSurface
              icon: s.charging ? "battery_charging_full"
                : ["battery_0_bar", "battery_1_bar", "battery_2_bar", "battery_3_bar", "battery_4_bar", "battery_5_bar", "battery_6_bar", "battery_full"][Math.max(0, Math.min(7, Math.round(s.batteryPct / 100 * 7)))]
            }
            Text {
              anchors.verticalCenter: parent.verticalCenter
              text: s.batteryPct + "%"
              font.family: s.sansFont
              font.pixelSize: 12
              color: s.colOnSurface
            }
          }
        }
      }

      IconButton {
        icon: "power_settings_new"
        size: win.pillH; iconSize: 16
        tint: s.errorColor
        base: s.alpha(s.errorColor, 0.12)
        onClicked: s.toggleMenu("power")
      }
    }
  }

  // ------------------------------------------------------------ briques
  component Island: Rectangle {
    id: isl
    default property alias content: inner.data
    property int hpad: 10
    // Largeur prise sur le premier enfant seulement : une MouseArea qui remplit
    // l'îlot ne doit pas entrer dans le calcul (boucle de liaison).
    readonly property Item first: inner.children.length > 0 ? inner.children[0] : null
    height: win.pillH
    width: (first ? first.width : 0) + hpad * 2
    radius: win.kind === "line" ? Math.min(5, win.s.radius) : height / 2
    color: win.s.surfaceHigh
    border.width: win.hard ? 1.5 : (win.kind === "line" ? 1 : 0)
    border.color: win.hard ? "#1b1030" : win.s.outlineVariant
    anchors.verticalCenter: parent ? parent.verticalCenter : undefined
    Item {
      id: inner
      x: isl.hpad
      width: isl.first ? isl.first.width : 0
      height: parent.height
    }
  }

  component IconButton: Item {
    id: ib
    property string icon: ""
    property real fill: 0
    property real size: 24
    property real iconSize: 15
    property color tint: win.s.colOnSurface
    property color base: "transparent"
    signal clicked()
    signal rightClicked()
    signal wheel(real delta)
    width: size; height: size
    anchors.verticalCenter: parent ? parent.verticalCenter : undefined
    Rectangle {
      anchors.fill: parent
      radius: width / 2
      color: ibm.containsMouse ? win.s.alpha(win.s.colOnSurface, 0.1) : ib.base
      scale: ibm.pressed ? 0.88 : 1
      Behavior on scale { NumberAnimation { duration: 260; easing.type: Easing.OutBack; easing.overshoot: 3 } }
      Behavior on color { ColorAnimation { duration: 140 } }
    }
    MIcon { anchors.centerIn: parent; icon: ib.icon; size: ib.iconSize; fill: ibm.containsMouse ? 1 : ib.fill; color: ib.tint }
    MouseArea {
      id: ibm
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      acceptedButtons: Qt.LeftButton | Qt.RightButton
      onClicked: function(m) { if (m.button === Qt.RightButton) ib.rightClicked(); else ib.clicked() }
      onWheel: function(w) { ib.wheel(w.angleDelta.y) }
    }
  }

  component Resource: Row {
    id: res
    property string icon: ""
    property real value: 0
    property var label: ""
    property bool hot: false
    spacing: 4
    Item {
      width: 20; height: 20
      anchors.verticalCenter: parent.verticalCenter
      Ring { anchors.fill: parent; value: res.value; thickness: 2; color: res.hot ? win.s.errorColor : win.s.primary; track: win.s.alpha(win.s.colOnSurface, 0.15) }
      MIcon { anchors.centerIn: parent; icon: res.icon; size: 11; fill: 1; color: win.s.colOnSurfaceVariant }
    }
    Text {
      anchors.verticalCenter: parent.verticalCenter
      text: String(res.label)
      font.family: win.s.sansFont
      font.pixelSize: 12
      color: win.s.colOnSurface
    }
  }
}
