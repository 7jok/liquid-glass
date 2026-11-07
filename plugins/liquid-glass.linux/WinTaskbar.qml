import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets
import Quickshell.Services.SystemTray
import Quickshell.Services.Pipewire
import "T.js" as T

// Style « windows » : barre des tâches façon Windows 11, en bas, centrée.
//   gauche : météo · centre : Démarrer, Rechercher, Vue des tâches, applis épinglées
//   et ouvertes (trait sous l'appli active) · droite : ^ zone de notification,
//   groupe Wi-Fi / son / batterie (paramètres rapides), date et heure (calendrier),
//   fine bande « afficher le bureau » tout au bout.
PanelWindow {
  id: win
  property var service: null
  readonly property var s: service

  readonly property int barH: 48
  color: "transparent"
  anchors { bottom: true; left: true; right: true }
  implicitHeight: barH
  exclusiveZone: barH
  WlrLayershell.layer: WlrLayer.Top
  WlrLayershell.namespace: "liquid-glass-win-taskbar"
  WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

  readonly property bool dark: s.darkSkin
  readonly property color ink: s.colOnSurface
  readonly property color hoverFill: dark ? Qt.rgba(1, 1, 1, 0.07) : Qt.rgba(1, 1, 1, 0.7)
  readonly property color pressFill: dark ? Qt.rgba(1, 1, 1, 0.04) : Qt.rgba(1, 1, 1, 0.5)

  property date now: new Date()
  Timer { interval: 1000; repeat: true; running: true; onTriggered: win.now = new Date() }

  PwObjectTracker { objects: [Pipewire.defaultAudioSink] }
  readonly property var sink: Pipewire.defaultAudioSink
  readonly property real volume: sink && sink.audio ? sink.audio.volume : 0
  readonly property bool muted: !sink || !sink.audio || sink.audio.muted

  // Applis épinglées + fenêtres ouvertes qui n'y sont pas.
  readonly property var pins: s.pinned(6)
  readonly property var tops: ToplevelManager.toplevels.values
  function sameApp(entry, appId) {
    if (!entry || !appId) return false
    var a = String(appId).toLowerCase(), id = String(entry.id).toLowerCase()
    if (a === id || id.indexOf(a) >= 0 || a.indexOf(id) >= 0) return true
    var h = DesktopEntries.heuristicLookup(appId)
    return !!h && h.id === entry.id
  }
  readonly property var tasks: {
    var out = [], used = []
    for (var i = 0; i < pins.length; i++) {
      var w = []
      for (var j = 0; j < tops.length; j++) if (sameApp(pins[i], tops[j].appId)) { w.push(tops[j]); used.push(tops[j]) }
      out.push({ entry: pins[i], wins: w })
    }
    for (var k = 0; k < tops.length; k++) {
      var t = tops[k]
      if (used.indexOf(t) >= 0) continue
      var found = false
      for (var m = 0; m < out.length; m++) if (!out[m].entry && out[m].appId === t.appId) { out[m].wins.push(t); found = true; break }
      if (!found) out.push({ entry: DesktopEntries.heuristicLookup(t.appId), appId: t.appId, wins: [t] })
    }
    return out
  }

  // Fond « mica » : gris clair (ou sombre) presque opaque, liseré en haut.
  Rectangle {
    anchors.fill: parent
    color: win.dark ? Qt.rgba(0.12, 0.12, 0.13, 0.94) : Qt.rgba(0.93, 0.94, 0.96, 0.93)
    Rectangle { width: parent.width; height: 1; color: win.dark ? Qt.rgba(1, 1, 1, 0.08) : Qt.rgba(0, 0, 0, 0.08) }
  }

  // ------------------------------------------------------------ gauche : météo
  TaskBtn {
    id: weatherBtn
    anchors.left: parent.left
    anchors.leftMargin: 6
    anchors.verticalCenter: parent.verticalCenter
    visible: !!s.weather
    width: wRow.implicitWidth + 20
    onClicked: s.togglePanel("widgets")
    Row {
      id: wRow
      anchors.centerIn: parent
      spacing: 8
      MIcon { anchors.verticalCenter: parent.verticalCenter; icon: s.weatherIcon; size: 24; fill: 1; color: s.weather && s.weather.isDay ? "#f4b400" : "#9fb4d8" }
      Column {
        anchors.verticalCenter: parent.verticalCenter
        Text { text: s.weather ? s.weather.temp + "°C" : ""; font.family: s.sansFont; font.pixelSize: 12; font.weight: Font.DemiBold; color: win.ink }
        Text { text: s.weatherDesc.charAt(0).toUpperCase() + s.weatherDesc.slice(1); font.family: s.sansFont; font.pixelSize: 11; color: s.colOnSurfaceVariant }
      }
    }
  }

  // ------------------------------------------------------------ centre
  Row {
    id: center
    anchors.centerIn: parent
    spacing: 4

    TaskBtn {
      id: startBtn
      width: 40
      active: s.launcherOpen
      onClicked: s.toggleLauncher()
      WinLogo { anchors.centerIn: parent; size: 18; pressed: startBtn.down }
    }
    // Rechercher : pilule comme Windows 11 (s'ouvre sur le menu Démarrer).
    Rectangle {
      id: search
      anchors.verticalCenter: parent.verticalCenter
      width: 196; height: 34; radius: 17
      color: searchMa.containsMouse ? (win.dark ? Qt.rgba(1, 1, 1, 0.1) : "#ffffff") : (win.dark ? Qt.rgba(1, 1, 1, 0.06) : Qt.rgba(1, 1, 1, 0.75))
      border.width: 1
      border.color: win.dark ? Qt.rgba(1, 1, 1, 0.08) : Qt.rgba(0, 0, 0, 0.07)
      Row {
        anchors.verticalCenter: parent.verticalCenter
        x: 12
        spacing: 8
        MIcon { anchors.verticalCenter: parent.verticalCenter; icon: "search"; size: 18; color: win.ink }
        Text { anchors.verticalCenter: parent.verticalCenter; text: T.t("Rechercher"); font.family: s.sansFont; font.pixelSize: 13; color: s.colOnSurfaceVariant }
      }
      MouseArea { id: searchMa; anchors.fill: parent; hoverEnabled: true; onClicked: s.toggleLauncher() }
    }
    TaskBtn {
      width: 40
      active: s.panel === "tasks"
      onClicked: s.togglePanel("tasks")
      // Vue des tâches : deux fenêtres décalées.
      Item {
        anchors.centerIn: parent
        width: 20; height: 18
        Rectangle { x: 0; y: 4; width: 13; height: 13; radius: 2; color: "transparent"; border.width: 1.6; border.color: win.ink }
        Rectangle { x: 6; y: 0; width: 13; height: 13; radius: 2; color: win.dark ? "#2a2a2a" : "#f0f1f4"; border.width: 1.6; border.color: "#0078d4" }
      }
    }
    // Claude Code, épinglé comme une appli.
    TaskBtn {
      id: claudeBtn
      width: 44
      onClicked: s.claude()
      tip: "Claude Code"
      ClaudeButton { anchors.centerIn: parent; s: win.s; size: 30; iconSize: 22; hover: "transparent"; enabled: false }
    }
    Repeater {
      model: win.tasks
      delegate: TaskBtn {
        id: task
        required property var modelData
        readonly property var wins: modelData.wins
        readonly property bool running: wins.length > 0
        readonly property bool focused: { for (var i = 0; i < wins.length; i++) if (wins[i].activated) return true; return false }
        width: 44
        active: focused
        onClicked: {
          if (!running) { s.launch(modelData.entry); return }
          // Clic sur l'appli active : fenêtre suivante ; sinon on la met au premier plan.
          var idx = 0
          for (var i = 0; i < wins.length; i++) if (wins[i].activated) idx = (i + 1) % wins.length
          wins[idx].activate()
        }
        IconImage {
          anchors.centerIn: parent
          anchors.verticalCenterOffset: task.down ? 1 : 0
          implicitSize: 24
          asynchronous: true
          source: task.modelData.entry ? s.appIcon(task.modelData.entry) : Quickshell.iconPath(String(task.modelData.appId || "").toLowerCase(), "application-x-executable")
        }
        // Indicateur : trait bleu large sous l'appli active, petit trait gris sinon.
        Rectangle {
          visible: task.running
          anchors.horizontalCenter: parent.horizontalCenter
          anchors.bottom: parent.bottom
          anchors.bottomMargin: 1
          height: 3; radius: 1.5
          width: task.focused ? 16 : 6
          color: task.focused ? s.primary : s.colOnSurfaceVariant
          Behavior on width { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
        }
        tip: task.modelData.entry ? s.appName(task.modelData.entry) : String(task.modelData.appId || "")
      }
    }
  }

  // ------------------------------------------------------------ droite
  Row {
    anchors.right: parent.right
    anchors.rightMargin: 0
    anchors.verticalCenter: parent.verticalCenter
    spacing: 2

    // Zone de notification : ^ ouvre les icônes cachées.
    TaskBtn {
      id: chevron
      width: 26
      visible: SystemTray.items.values.length > 0
      onClicked: trayPop.visible = !trayPop.visible
      MIcon { anchors.centerIn: parent; icon: "keyboard_arrow_up"; size: 18; color: win.ink; rotation: trayPop.visible ? 180 : 0; Behavior on rotation { NumberAnimation { duration: 150 } } }
    }
    // Wi-Fi · son · batterie → paramètres rapides
    TaskBtn {
      id: quickBtn
      width: qRow.implicitWidth + 18
      active: s.panel === "quick"
      onClicked: s.togglePanel("quick")
      onWheel: function(d) { Quickshell.execDetached(["wpctl", "set-volume", "-l", "1.0", "@DEFAULT_AUDIO_SINK@", "5%" + (d > 0 ? "+" : "-")]) }
      Row {
        id: qRow
        anchors.centerIn: parent
        spacing: 10
        MIcon { anchors.verticalCenter: parent.verticalCenter; size: 17; color: win.ink; icon: s.netDev === "" ? "signal_wifi_off" : (s.netWifi ? "wifi" : "lan") }
        MIcon {
          anchors.verticalCenter: parent.verticalCenter; size: 17; color: win.ink
          icon: win.muted ? "volume_off" : (win.volume < 0.34 ? "volume_mute" : (win.volume < 0.67 ? "volume_down" : "volume_up"))
        }
        MIcon {
          visible: s.batteryPct >= 0
          anchors.verticalCenter: parent.verticalCenter; size: 17; color: win.ink; rotation: 90
          icon: s.charging ? "battery_charging_full"
            : ["battery_0_bar", "battery_1_bar", "battery_2_bar", "battery_3_bar", "battery_4_bar", "battery_5_bar", "battery_6_bar", "battery_full"][Math.max(0, Math.min(7, Math.round(s.batteryPct / 100 * 7)))]
        }
      }
    }
    // Heure et date (calendrier)
    TaskBtn {
      width: clock.implicitWidth + 20
      active: s.panel === "calendar"
      onClicked: s.togglePanel("calendar")
      Column {
        id: clock
        anchors.centerIn: parent
        Text { anchors.right: parent.right; text: Qt.formatTime(win.now, "HH:mm"); font.family: s.sansFont; font.pixelSize: 12; color: win.ink }
        Text { anchors.right: parent.right; text: Qt.formatDate(win.now, "dd/MM/yyyy"); font.family: s.sansFont; font.pixelSize: 12; color: win.ink }
      }
    }
    // Cloche des notifications
    TaskBtn {
      width: 30
      onClicked: Quickshell.execDetached(["sh", "-c", "omarchy-shell notifications showHistory"])
      MIcon { anchors.centerIn: parent; icon: "notifications"; size: 17; color: win.ink }
    }
    // Afficher le bureau : fine bande tout à droite.
    Item {
      width: 8; height: win.barH
      Rectangle { anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter; width: 1; height: 16; color: win.dark ? Qt.rgba(1, 1, 1, 0.2) : Qt.rgba(0, 0, 0, 0.18) }
      MouseArea { anchors.fill: parent; onClicked: Quickshell.execDetached(["liquid-glass", "show-desktop"]) }
    }
  }

  // Icônes cachées de la zone de notification (petite fenêtre au-dessus du ^).
  PopupWindow {
    id: trayPop
    visible: false
    anchor.window: win
    anchor.rect.x: chevron.mapToItem(null, 0, 0).x - (implicitWidth - chevron.width) / 2
    anchor.rect.y: -implicitHeight - 8
    implicitWidth: Math.max(1, Math.min(4, SystemTray.items.values.length)) * 36 + 12
    implicitHeight: Math.ceil(SystemTray.items.values.length / 4) * 36 + 12
    color: "transparent"
    Rectangle {
      anchors.fill: parent
      radius: 8
      color: win.dark ? "#2b2b2b" : "#f9f9f9"
      border.width: 1
      border.color: win.dark ? Qt.rgba(1, 1, 1, 0.1) : Qt.rgba(0, 0, 0, 0.1)
      Grid {
        anchors.centerIn: parent
        columns: 4
        Repeater {
          model: SystemTray.items
          delegate: Item {
            id: ti
            required property var modelData
            width: 36; height: 36
            Rectangle { anchors.fill: parent; anchors.margins: 2; radius: 4; color: tma.containsMouse ? win.hoverFill : "transparent" }
            IconImage { anchors.centerIn: parent; implicitSize: 18; source: ti.modelData.icon; asynchronous: true }
            MouseArea {
              id: tma
              anchors.fill: parent
              hoverEnabled: true
              acceptedButtons: Qt.LeftButton | Qt.RightButton
              onClicked: function(m) {
                if (m.button === Qt.RightButton || ti.modelData.onlyMenu) {
                  if (ti.modelData.hasMenu) { var p = ti.mapToItem(null, 0, 0); ti.modelData.display(trayPop, p.x, p.y) }
                } else { ti.modelData.activate(); trayPop.visible = false }
              }
            }
          }
        }
      }
    }
  }

  // ------------------------------------------------------------ briques
  component TaskBtn: Item {
    id: tb
    property bool active: false
    property string tip: ""
    readonly property bool down: ma.pressed
    signal clicked()
    signal wheel(int delta)
    height: 40
    anchors.verticalCenter: parent ? parent.verticalCenter : undefined
    Rectangle {
      anchors.fill: parent
      radius: 4
      color: tb.down ? win.pressFill : ((ma.containsMouse || tb.active) ? win.hoverFill : "transparent")
      border.width: (ma.containsMouse || tb.active) && !win.dark ? 1 : 0
      border.color: Qt.rgba(0, 0, 0, 0.05)
      Behavior on color { ColorAnimation { duration: 90 } }
    }
    MouseArea {
      id: ma
      anchors.fill: parent
      hoverEnabled: true
      onClicked: tb.clicked()
      onWheel: function(w) { tb.wheel(w.angleDelta.y) }
    }
  }
}
