import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Widgets
import Quickshell.Hyprland
import Quickshell.Bluetooth
import Quickshell.Services.Pipewire
import "T.js" as T

// Style « windows » : tous les volets qui sortent de la barre des tâches.
//   menu Démarrer (⌘Espace)  : recherche, Épinglé, Toutes les applications, Recommandé, compte, marche/arrêt
//   quick    : paramètres rapides (Wi-Fi, Bluetooth, nuit, concentration…), luminosité, volume, batterie
//   calendar : notifications + calendrier du mois
//   widgets  : panneau de widgets à gauche (météo, musique, système)
//   tasks    : vue des tâches (bureaux virtuels = espaces Hyprland)
// Clic à côté ou Échap pour fermer.
PanelWindow {
  id: win
  property var service: null
  readonly property var s: service

  color: "transparent"
  anchors { top: true; bottom: true; left: true; right: true }
  exclusionMode: ExclusionMode.Ignore
  WlrLayershell.layer: WlrLayer.Overlay
  WlrLayershell.namespace: "liquid-glass-win-flyout"
  WlrLayershell.keyboardFocus: s.kbd(s.launcherOpen)

  readonly property bool dark: s.darkSkin
  readonly property color ink: s.colOnSurface
  readonly property color sub: s.colOnSurfaceVariant
  readonly property color panelBg: dark ? Qt.rgba(0.17, 0.17, 0.17, 0.97) : Qt.rgba(0.95, 0.95, 0.96, 0.97)
  readonly property color cardBg: dark ? Qt.rgba(1, 1, 1, 0.05) : Qt.rgba(1, 1, 1, 0.7)
  readonly property color line: dark ? Qt.rgba(1, 1, 1, 0.08) : Qt.rgba(0, 0, 0, 0.07)
  readonly property color hover: dark ? Qt.rgba(1, 1, 1, 0.07) : Qt.rgba(0, 0, 0, 0.04)
  readonly property int taskbarH: 48
  readonly property string font: s.sansFont
  function cap(t) { t = String(t); return t.charAt(0).toUpperCase() + t.slice(1) }

  property date now: new Date()
  Timer { interval: 1000; repeat: true; running: true; onTriggered: win.now = new Date() }

  readonly property string mode: s.launcherOpen ? "start" : s.panel
  property bool revealed: false
  Component.onCompleted: { revealed = true; if (s.launcherOpen) searchInput.forceActiveFocus(); else keys.forceActiveFocus(); s.readBrightness(); s.scanWifi() }
  onModeChanged: { if (mode === "start") { query = ""; showAll = false; searchInput.forceActiveFocus() } }

  function close() { s.closeAll() }

  MouseArea { anchors.fill: parent; onClicked: win.close() }
  Item {
    id: keys
    focus: !s.launcherOpen
    Keys.onEscapePressed: win.close()
  }

  // ================================================================ menu Démarrer
  property string query: ""
  property bool showAll: false
  readonly property var results: query.trim() === "" ? [] : s.apps(query).slice(0, 8)
  property int sel: 0
  onQueryChanged: sel = 0
  property var recent: []
  Process {
    running: true
    command: ["sh", "-c", "f=\"$HOME/.local/share/recently-used.xbel\"; [ -f \"$f\" ] && grep -o 'href=\"file://[^\"]*\"' \"$f\" | sed 's/^href=\"file:\\/\\///;s/\"$//' | tail -n 30 | tac | awk '!seen[$0]++' | head -n 6"]
    stdout: StdioCollector {
      onStreamFinished: {
        var out = [], l = text.split("\n")
        for (var i = 0; i < l.length; i++) if (l[i].trim() !== "") out.push(decodeURIComponent(l[i].trim()))
        win.recent = out
      }
    }
  }
  function fileIcon(p) {
    var e = String(p).split(".").pop().toLowerCase()
    if (["png", "jpg", "jpeg", "webp", "gif", "svg"].indexOf(e) >= 0) return "image"
    if (["mp4", "mkv", "webm", "mov"].indexOf(e) >= 0) return "movie"
    if (["mp3", "flac", "ogg", "wav"].indexOf(e) >= 0) return "music_note"
    if (["pdf"].indexOf(e) >= 0) return "picture_as_pdf"
    if (["md", "txt", "toml", "json", "lua", "qml", "py", "sh"].indexOf(e) >= 0) return "description"
    return "draft"
  }

  Panel {
    id: start
    shown: win.mode === "start"
    width: 640; height: Math.min(660, win.height - win.taskbarH - 24)
    anchors.horizontalCenter: parent.horizontalCenter
    anchors.bottom: parent.bottom
    anchors.bottomMargin: win.taskbarH + 12

    // Recherche
    Rectangle {
      id: searchBox
      x: 32; y: 28
      width: parent.width - 64; height: 36; radius: 18
      color: win.dark ? Qt.rgba(1, 1, 1, 0.06) : "#ffffff"
      border.width: 1
      border.color: searchInput.activeFocus ? s.primary : win.line
      Rectangle { visible: searchInput.activeFocus; anchors.bottom: parent.bottom; anchors.horizontalCenter: parent.horizontalCenter; width: parent.width - 30; height: 2; radius: 1; color: s.primary }
      MIcon { x: 14; anchors.verticalCenter: parent.verticalCenter; icon: "search"; size: 18; color: win.sub }
      TextInput {
        id: searchInput
        x: 42; anchors.verticalCenter: parent.verticalCenter
        width: parent.width - 56
        font.family: win.font; font.pixelSize: 13
        color: win.ink
        selectionColor: s.primary
        clip: true
        onTextChanged: win.query = text
        Text { visible: parent.text === ""; text: T.t("Rechercher des applications, des paramètres et des documents"); font: parent.font; color: win.sub }
        Keys.onEscapePressed: { if (text !== "") text = ""; else win.close() }
        Keys.onDownPressed: win.sel = Math.min(win.sel + 1, Math.max(0, win.results.length - 1))
        Keys.onUpPressed: win.sel = Math.max(0, win.sel - 1)
        Keys.onReturnPressed: {
          if (win.results.length) s.launch(win.results[win.sel])
          else if (text.trim() !== "") { Quickshell.execDetached(["xdg-open", "https://duckduckgo.com/?q=" + encodeURIComponent(text)]); win.close() }
        }
      }
    }

    // ---- Résultats de recherche
    Item {
      visible: win.query.trim() !== ""
      x: 32; y: 84
      width: parent.width - 64; height: parent.height - 84 - 70
      Text { text: T.t("Meilleur résultat"); font.family: win.font; font.pixelSize: 13; font.weight: Font.DemiBold; color: win.ink }
      Column {
        y: 28
        width: parent.width
        spacing: 2
        Repeater {
          model: win.results
          delegate: Rectangle {
            id: res
            required property var modelData
            required property int index
            width: parent.width; height: index === 0 ? 64 : 40; radius: 4
            color: win.sel === index ? win.hover : (rma.containsMouse ? win.hover : "transparent")
            border.width: win.sel === index ? 1 : 0
            border.color: win.line
            IconImage { x: 12; anchors.verticalCenter: parent.verticalCenter; implicitSize: res.index === 0 ? 40 : 24; source: s.appIcon(res.modelData); asynchronous: true }
            Column {
              x: res.index === 0 ? 64 : 48; anchors.verticalCenter: parent.verticalCenter
              Text { text: s.appName(res.modelData); font.family: win.font; font.pixelSize: res.index === 0 ? 15 : 13; color: win.ink }
              Text { text: "Application"; font.family: win.font; font.pixelSize: 11; color: win.sub }
            }
            MouseArea { id: rma; anchors.fill: parent; hoverEnabled: true; onEntered: win.sel = res.index; onClicked: s.launch(res.modelData) }
          }
        }
        Rectangle {
          visible: win.results.length === 0
          width: parent.width; height: 40; radius: 4; color: wma.containsMouse ? win.hover : "transparent"
          Row {
            x: 12; anchors.verticalCenter: parent.verticalCenter; spacing: 12
            MIcon { icon: "travel_explore"; size: 20; color: win.ink }
            Text { text: T.t("Rechercher « ") + win.query + T.t(" » sur le Web"); font.family: win.font; font.pixelSize: 13; color: win.ink }
          }
          MouseArea { id: wma; anchors.fill: parent; hoverEnabled: true; onClicked: { Quickshell.execDetached(["xdg-open", "https://duckduckgo.com/?q=" + encodeURIComponent(win.query)]); win.close() } }
        }
      }
    }

    // ---- Épinglé / Recommandé
    Item {
      visible: win.query.trim() === "" && !win.showAll
      x: 32; y: 84
      width: parent.width - 64; height: parent.height - 84 - 70
      Text { text: T.t("Épinglé"); font.family: win.font; font.pixelSize: 14; font.weight: Font.DemiBold; color: win.ink }
      SmallBtn { anchors.right: parent.right; y: -4; label: T.t("Toutes les applications"); trailing: "chevron_right"; onClicked: win.showAll = true }
      Grid {
        id: pinGrid
        y: 34
        columns: 6
        width: parent.width
        Repeater {
          model: s.pinned(18)
          delegate: Rectangle {
            id: pin
            required property var modelData
            width: pinGrid.width / 6; height: 78; radius: 4
            color: pma.containsMouse ? win.hover : "transparent"
            IconImage { anchors.horizontalCenter: parent.horizontalCenter; y: 12; implicitSize: 32; source: s.appIcon(pin.modelData); asynchronous: true }
            Text {
              anchors.horizontalCenter: parent.horizontalCenter; y: 52
              width: parent.width - 8; horizontalAlignment: Text.AlignHCenter; elide: Text.ElideRight
              text: s.appName(pin.modelData); font.family: win.font; font.pixelSize: 11; color: win.ink
            }
            MouseArea { id: pma; anchors.fill: parent; hoverEnabled: true; onClicked: s.launch(pin.modelData) }
          }
        }
      }
      Text { id: recTitle; y: pinGrid.y + pinGrid.height + 18; text: T.t("Recommandé"); font.family: win.font; font.pixelSize: 14; font.weight: Font.DemiBold; color: win.ink }
      Grid {
        y: recTitle.y + 32
        columns: 2
        width: parent.width
        Repeater {
          model: win.recent
          delegate: Rectangle {
            id: rec
            required property string modelData
            width: parent.width / 2; height: 50; radius: 4
            color: recMa.containsMouse ? win.hover : "transparent"
            MIcon { x: 12; anchors.verticalCenter: parent.verticalCenter; icon: win.fileIcon(rec.modelData); size: 26; fill: 1; color: s.primary }
            Column {
              x: 50; anchors.verticalCenter: parent.verticalCenter; width: parent.width - 60
              Text { width: parent.width; elide: Text.ElideMiddle; text: rec.modelData.split("/").pop(); font.family: win.font; font.pixelSize: 12; color: win.ink }
              Text { width: parent.width; elide: Text.ElideMiddle; text: rec.modelData.replace(Quickshell.env("HOME"), "~").split("/").slice(0, -1).join("/"); font.family: win.font; font.pixelSize: 11; color: win.sub }
            }
            MouseArea { id: recMa; anchors.fill: parent; hoverEnabled: true; onClicked: { Quickshell.execDetached(["xdg-open", rec.modelData]); win.close() } }
          }
        }
      }
      Text {
        visible: win.recent.length === 0
        y: recTitle.y + 40; width: parent.width; horizontalAlignment: Text.AlignHCenter
        text: T.t("Vos fichiers récents apparaîtront ici."); font.family: win.font; font.pixelSize: 12; color: win.sub
      }
    }

    // ---- Toutes les applications
    Item {
      visible: win.query.trim() === "" && win.showAll
      x: 32; y: 84
      width: parent.width - 64; height: parent.height - 84 - 70
      Text { text: T.t("Toutes les applications"); font.family: win.font; font.pixelSize: 14; font.weight: Font.DemiBold; color: win.ink }
      SmallBtn { anchors.right: parent.right; y: -4; label: T.t("Retour"); leading: "chevron_left"; onClicked: win.showAll = false }
      ListView {
        y: 34
        width: parent.width; height: parent.height - 34
        clip: true
        // Liste alphabétique avec une lettre en tête de chaque groupe.
        model: {
          if (!win.showAll) return []
          var all = s.apps("").slice().sort(function(x, y) { return s.appName(x).localeCompare(s.appName(y)) }), out = [], last = ""
          for (var i = 0; i < all.length; i++) {
            var c = s.appName(all[i]).charAt(0).toUpperCase()
            if (!/[A-Z]/.test(c)) c = "#"
            if (c !== last) { out.push({ header: c }); last = c }
            out.push({ entry: all[i] })
          }
          return out
        }
        boundsBehavior: Flickable.StopAtBounds
        delegate: Rectangle {
          id: al
          required property var modelData
          readonly property bool head: modelData.header !== undefined
          width: ListView.view.width - 12; height: head ? 34 : 38; radius: 4
          color: !head && ama.containsMouse ? win.hover : "transparent"
          Text { visible: al.head; x: 12; anchors.verticalCenter: parent.verticalCenter; text: al.head ? al.modelData.header : ""; font.family: win.font; font.pixelSize: 13; font.weight: Font.DemiBold; color: win.ink }
          IconImage { visible: !al.head; x: 12; anchors.verticalCenter: parent.verticalCenter; implicitSize: 24; source: al.head ? "" : s.appIcon(al.modelData.entry); asynchronous: true }
          Text { visible: !al.head; x: 48; anchors.verticalCenter: parent.verticalCenter; text: al.head ? "" : s.appName(al.modelData.entry); font.family: win.font; font.pixelSize: 13; color: win.ink }
          MouseArea { id: ama; anchors.fill: parent; enabled: !al.head; hoverEnabled: true; onClicked: s.launch(al.modelData.entry) }
        }
      }
    }

    // ---- Pied : compte et marche/arrêt
    Rectangle {
      anchors.bottom: parent.bottom
      width: parent.width; height: 64
      color: win.dark ? Qt.rgba(0, 0, 0, 0.18) : Qt.rgba(0, 0, 0, 0.025)
      radius: 8
      Rectangle { width: parent.width; height: 1; color: win.line }
      Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 8; color: parent.color; visible: false }
      Rectangle {
        id: userBtn
        x: 40; anchors.verticalCenter: parent.verticalCenter
        width: userRow.implicitWidth + 24; height: 40; radius: 4
        color: uma.containsMouse ? win.hover : "transparent"
        Row {
          id: userRow
          x: 12; anchors.verticalCenter: parent.verticalCenter; spacing: 12
          Avatar { size: 30; anchors.verticalCenter: parent.verticalCenter }
          Text { anchors.verticalCenter: parent.verticalCenter; text: s.user.charAt(0).toUpperCase() + s.user.slice(1); font.family: win.font; font.pixelSize: 12; color: win.ink }
        }
        MouseArea { id: uma; anchors.fill: parent; hoverEnabled: true; onClicked: userMenu.visible = !userMenu.visible }
      }
      Rectangle {
        id: powerBtn
        anchors.right: parent.right; anchors.rightMargin: 40; anchors.verticalCenter: parent.verticalCenter
        width: 40; height: 40; radius: 4
        color: pwma.containsMouse ? win.hover : "transparent"
        MIcon { anchors.centerIn: parent; icon: "power_settings_new"; size: 20; color: win.ink }
        MouseArea { id: pwma; anchors.fill: parent; hoverEnabled: true; onClicked: powerMenu.visible = !powerMenu.visible }
      }
    }
    Menu {
      id: powerMenu
      anchors.right: parent.right; anchors.rightMargin: 24
      anchors.bottom: parent.bottom; anchors.bottomMargin: 58
      items: [["lock", T.t("Verrouiller"), "lock"], ["suspend", T.t("Mettre en veille"), "bedtime"], ["poweroff", T.t("Arrêter"), "power_settings_new"], ["reboot", T.t("Redémarrer"), "restart_alt"]]
      onPicked: function(id) { s.power(id) }
    }
    Menu {
      id: userMenu
      x: 32
      anchors.bottom: parent.bottom; anchors.bottomMargin: 58
      items: [["settings", T.t("Modifier les paramètres du compte"), "manage_accounts"], ["lock", T.t("Verrouiller"), "lock"], ["logout", T.t("Se déconnecter"), "logout"]]
      onPicked: function(id) { if (id === "settings") { s.closeAll(); s.toggleMenu("accounts") } else s.power(id) }
    }
  }

  // ================================================================ paramètres rapides
  PwObjectTracker { objects: [Pipewire.defaultAudioSink] }
  readonly property var sink: Pipewire.defaultAudioSink
  readonly property var bt: Bluetooth.defaultAdapter
  property bool nightOn: false
  property bool dndOn: false
  property string quickPage: ""
  Process {
    running: true
    command: ["sh", "-c", "pgrep -x hyprsunset >/dev/null && echo n; [ -f \"$HOME/.local/state/omarchy/toggles/notification-silencing\" ] && echo d; makoctl mode 2>/dev/null | grep -q do-not-disturb && echo d; true"]
    stdout: StdioCollector { onStreamFinished: { win.nightOn = text.indexOf("n") >= 0; win.dndOn = text.indexOf("d") >= 0 } }
  }

  Panel {
    id: quick
    shown: win.mode === "quick"
    width: 360; height: quickCol.implicitHeight + 92
    anchors.right: parent.right; anchors.rightMargin: 12
    anchors.bottom: parent.bottom; anchors.bottomMargin: win.taskbarH + 12

    Column {
      id: quickCol
      visible: win.quickPage === ""
      x: 20; y: 20
      width: parent.width - 40
      spacing: 18
      Grid {
        columns: 3
        columnSpacing: 12
        rowSpacing: 14
        QuickTile {
          icon: s.wifiOn ? "wifi" : "wifi_off"; label: s.netWifi && s.wifiList.length && s.wifiList[0].active ? s.wifiList[0].ssid : "Wi-Fi"
          on: s.wifiOn; split: true
          onToggled: s.setWifi(!s.wifiOn)
          onMore: { s.scanWifi(); win.quickPage = "wifi" }
        }
        QuickTile {
          icon: win.bt && win.bt.enabled ? "bluetooth" : "bluetooth_disabled"; label: "Bluetooth"
          on: !!win.bt && win.bt.enabled; split: true
          onToggled: if (win.bt) win.bt.enabled = !win.bt.enabled
          onMore: win.quickPage = "bt"
        }
        QuickTile {
          icon: "nightlight"; label: T.t("Éclairage nocturne"); on: win.nightOn
          onToggled: { win.nightOn = !win.nightOn; Quickshell.execDetached(["omarchy-toggle-nightlight"]) }
        }
        QuickTile {
          icon: "do_not_disturb_on"; label: T.t("Ne pas déranger"); on: win.dndOn
          onToggled: { win.dndOn = !win.dndOn; Quickshell.execDetached(["omarchy-toggle-notification-silencing"]) }
        }
        QuickTile {
          icon: "screenshot_region"; label: T.t("Capture"); on: false
          onToggled: { win.close(); Quickshell.execDetached(["sh", "-c", "sleep 0.3; omarchy-capture-screenshot"]) }
        }
        QuickTile {
          icon: "wallpaper"; label: T.t("Fond d'écran"); on: false
          onToggled: { win.close(); s.wallsOpen = true }
        }
      }
      // Luminosité
      SliderRow {
        visible: s.brightness >= 0
        icon: "light_mode"
        value: s.brightness
        onMoved: function(v) { s.setBrightness(v) }
      }
      // Volume
      SliderRow {
        icon: !win.sink || !win.sink.audio || win.sink.audio.muted ? "volume_off" : "volume_up"
        value: win.sink && win.sink.audio ? win.sink.audio.volume : 0
        onMoved: function(v) { if (win.sink && win.sink.audio) win.sink.audio.volume = v }
        onIconClicked: if (win.sink && win.sink.audio) win.sink.audio.muted = !win.sink.audio.muted
      }
    }
    // Sous-page Wi-Fi / Bluetooth
    Item {
      visible: win.quickPage !== ""
      x: 20; y: 16
      width: parent.width - 40; height: quickCol.implicitHeight
      Row {
        spacing: 8
        Rectangle {
          width: 32; height: 32; radius: 4; color: bkma.containsMouse ? win.hover : "transparent"
          MIcon { anchors.centerIn: parent; icon: "arrow_back"; size: 18; color: win.ink }
          MouseArea { id: bkma; anchors.fill: parent; hoverEnabled: true; onClicked: win.quickPage = "" }
        }
        Text { anchors.verticalCenter: parent.verticalCenter; text: win.quickPage === "wifi" ? "Wi-Fi" : "Bluetooth"; font.family: win.font; font.pixelSize: 15; font.weight: Font.DemiBold; color: win.ink }
      }
      ListView {
        y: 44
        width: parent.width; height: parent.height - 44
        clip: true
        spacing: 2
        model: win.quickPage === "wifi" ? s.wifiList : (win.bt && win.bt.devices ? win.bt.devices.values : [])
        delegate: Rectangle {
          id: net
          required property var modelData
          readonly property bool isWifi: win.quickPage === "wifi"
          readonly property bool connected: isWifi ? modelData.active : modelData.connected
          width: ListView.view.width; height: 44; radius: 4
          color: nma.containsMouse || connected ? win.hover : "transparent"
          MIcon {
            x: 10; anchors.verticalCenter: parent.verticalCenter; size: 20; color: net.connected ? s.primary : win.ink
            icon: net.isWifi ? (net.modelData.signal > 66 ? "network_wifi" : net.modelData.signal > 33 ? "network_wifi_2_bar" : "network_wifi_1_bar")
                             : (String(net.modelData.icon || "").indexOf("audio") >= 0 ? "headphones" : "bluetooth")
          }
          Column {
            x: 44; anchors.verticalCenter: parent.verticalCenter; width: parent.width - 54
            Text { width: parent.width; elide: Text.ElideRight; text: net.isWifi ? net.modelData.ssid : (net.modelData.name || net.modelData.deviceName || ""); font.family: win.font; font.pixelSize: 13; color: win.ink }
            Text {
              text: net.connected ? T.t("Connecté") + (net.isWifi && net.modelData.secure ? T.t(", sécurisé") : "") : (net.isWifi ? (net.modelData.secure ? T.t("Sécurisé") : T.t("Ouvert")) : (net.modelData.paired ? T.t("Associé") : ""))
              font.family: win.font; font.pixelSize: 11; color: win.sub
            }
          }
          MouseArea {
            id: nma; anchors.fill: parent; hoverEnabled: true
            onClicked: {
              if (net.isWifi) { if (!net.connected) s.connectWifi(net.modelData.ssid) }
              else net.modelData.connected = !net.modelData.connected
            }
          }
        }
      }
    }
    // Pied : batterie, paramètres
    Rectangle {
      anchors.bottom: parent.bottom
      width: parent.width; height: 48; radius: 8
      color: win.dark ? Qt.rgba(0, 0, 0, 0.18) : Qt.rgba(0, 0, 0, 0.025)
      Rectangle { width: parent.width; height: 1; color: win.line }
      Row {
        x: 20; anchors.verticalCenter: parent.verticalCenter; spacing: 6
        visible: s.batteryPct >= 0
        MIcon { anchors.verticalCenter: parent.verticalCenter; rotation: 90; size: 18; color: win.ink; icon: s.charging ? "battery_charging_full" : "battery_5_bar" }
        Text { anchors.verticalCenter: parent.verticalCenter; text: s.batteryPct + " %"; font.family: win.font; font.pixelSize: 12; color: win.ink }
      }
      Rectangle {
        anchors.right: parent.right; anchors.rightMargin: 12; anchors.verticalCenter: parent.verticalCenter
        width: 32; height: 32; radius: 4; color: gma.containsMouse ? win.hover : "transparent"
        MIcon { anchors.centerIn: parent; icon: "settings"; size: 18; color: win.ink }
        MouseArea { id: gma; anchors.fill: parent; hoverEnabled: true; onClicked: { s.closeAll(); s.toggleMenu("system") } }
      }
    }
  }

  // ================================================================ calendrier + notifications
  property date month: new Date(now.getFullYear(), now.getMonth(), 1)
  Panel {
    id: cal
    shown: win.mode === "calendar"
    width: 360; height: 470
    anchors.right: parent.right; anchors.rightMargin: 12
    anchors.bottom: parent.bottom; anchors.bottomMargin: win.taskbarH + 12
    Column {
      x: 20; y: 18
      width: parent.width - 40
      spacing: 14
      Item {
        width: parent.width; height: 24
        Text { text: "Notifications"; font.family: win.font; font.pixelSize: 14; font.weight: Font.DemiBold; color: win.ink }
        SmallBtn { anchors.right: parent.right; label: T.t("Historique"); onClicked: { win.close(); Quickshell.execDetached(["sh", "-c", "omarchy-shell notifications showHistory"]) } }
      }
      Text { width: parent.width; horizontalAlignment: Text.AlignHCenter; text: T.t("Aucune nouvelle notification"); font.family: win.font; font.pixelSize: 12; color: win.sub }
      Rectangle { width: parent.width; height: 1; color: win.line }
      Item {
        width: parent.width; height: 28
        Text {
          anchors.verticalCenter: parent.verticalCenter
          text: win.cap(win.now.toLocaleDateString(Qt.locale(T.loc), "dddd d MMMM"))
          font.family: win.font; font.pixelSize: 14; font.weight: Font.DemiBold; color: win.ink
        }
      }
      Item {
        width: parent.width; height: 28
        Text { anchors.verticalCenter: parent.verticalCenter; text: win.cap(win.month.toLocaleDateString(Qt.locale(T.loc), "MMMM yyyy")); font.family: win.font; font.pixelSize: 13; color: win.ink }
        Row {
          anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; spacing: 4
          SmallBtn { leading: "keyboard_arrow_up"; onClicked: win.month = new Date(win.month.getFullYear(), win.month.getMonth() - 1, 1) }
          SmallBtn { leading: "keyboard_arrow_down"; onClicked: win.month = new Date(win.month.getFullYear(), win.month.getMonth() + 1, 1) }
        }
      }
      Grid {
        columns: 7
        Repeater {
          model: ["lu", "ma", "me", "je", "ve", "sa", "di"]
          delegate: Text { required property string modelData; width: 320 / 7; height: 30; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter; text: modelData; font.family: win.font; font.pixelSize: 12; color: win.ink }
        }
        Repeater {
          model: 42
          delegate: Item {
            id: day
            required property int index
            readonly property int lead: (win.month.getDay() + 6) % 7
            readonly property date d: new Date(win.month.getFullYear(), win.month.getMonth(), index - lead + 1)
            readonly property bool inMonth: d.getMonth() === win.month.getMonth()
            readonly property bool today: d.toDateString() === win.now.toDateString()
            width: 320 / 7; height: 40
            Rectangle { anchors.centerIn: parent; width: 36; height: 36; radius: 18; color: day.today ? s.primary : (dma.containsMouse ? win.hover : "transparent") }
            Text { anchors.centerIn: parent; text: day.d.getDate(); font.family: win.font; font.pixelSize: 12; color: day.today ? s.colOnPrimary : (day.inMonth ? win.ink : win.sub); opacity: day.inMonth || day.today ? 1 : 0.6 }
            MouseArea { id: dma; anchors.fill: parent; hoverEnabled: true }
          }
        }
      }
    }
  }

  // ================================================================ widgets
  Panel {
    id: widgets
    shown: win.mode === "widgets"
    fromLeft: true
    width: 420; height: win.height - win.taskbarH - 24
    anchors.left: parent.left; anchors.leftMargin: 12
    anchors.bottom: parent.bottom; anchors.bottomMargin: win.taskbarH + 12
    Column {
      x: 20; y: 20
      width: parent.width - 40
      spacing: 14
      Text { text: Qt.formatTime(win.now, "HH:mm"); font.family: win.font; font.pixelSize: 26; color: win.ink }
      Grid {
        columns: 2; spacing: 12
        // Météo
        Card {
          width: 184; height: 184
          Column {
            x: 16; y: 14; spacing: 4
            Text { text: T.t("Météo"); font.family: win.font; font.pixelSize: 12; color: win.sub }
            Text { text: s.weather ? s.weather.city : "—"; font.family: win.font; font.pixelSize: 13; font.weight: Font.DemiBold; color: win.ink }
            Row {
              spacing: 8
              MIcon { icon: s.weatherIcon; size: 40; fill: 1; color: "#f4b400" }
              Text { text: s.weather ? s.weather.temp + "°" : ""; font.family: win.font; font.pixelSize: 38; color: win.ink }
            }
            Text { text: s.weatherDesc; font.family: win.font; font.pixelSize: 12; color: win.ink }
            Text { text: s.weather ? "↑ " + s.weather.max + "°  ↓ " + s.weather.min + "°" : ""; font.family: win.font; font.pixelSize: 12; color: win.sub }
          }
        }
        // Système
        Card {
          width: 184; height: 184
          Column {
            x: 16; y: 14; spacing: 10; width: parent.width - 32
            Text { text: T.t("Système"); font.family: win.font; font.pixelSize: 12; color: win.sub }
            Repeater {
              model: [["Processeur", s.cpu], ["Mémoire", s.memPct], ["Disque", s.diskPct]]
              delegate: Column {
                required property var modelData
                width: parent.width; spacing: 4
                Text { text: modelData[0] + "  " + Math.round(modelData[1] * 100) + " %"; font.family: win.font; font.pixelSize: 12; color: win.ink }
                Rectangle { width: parent.width; height: 4; radius: 2; color: win.line
                  Rectangle { width: parent.width * Math.max(0, Math.min(1, modelData[1])); height: 4; radius: 2; color: s.primary } }
              }
            }
          }
        }
      }
      // Musique
      Card {
        width: 380; height: 110
        visible: s.hasTrack || s.resumeMode
        ClippingRectangle {
          x: 14; anchors.verticalCenter: parent.verticalCenter; width: 82; height: 82; radius: 6; color: win.line
          Image { anchors.fill: parent; source: s.cover; fillMode: Image.PreserveAspectCrop; asynchronous: true }
        }
        Column {
          x: 110; y: 16; width: parent.width - 124; spacing: 2
          Text { width: parent.width; elide: Text.ElideRight; text: s.trackTitle; font.family: win.font; font.pixelSize: 14; font.weight: Font.DemiBold; color: win.ink }
          Text { width: parent.width; elide: Text.ElideRight; text: s.trackArtist; font.family: win.font; font.pixelSize: 12; color: win.sub }
          Row {
            topPadding: 8; spacing: 6
            SmallBtn { leading: "skip_previous"; onClicked: if (s.player) s.player.previous() }
            SmallBtn { leading: s.playing ? "pause" : "play_arrow"; onClicked: s.playPause() }
            SmallBtn { leading: "skip_next"; onClicked: if (s.player) s.player.next() }
          }
        }
      }
    }
  }

  // ================================================================ vue des tâches
  Panel {
    id: tasks
    shown: win.mode === "tasks"
    width: Math.min(win.width - 80, 220 * deskRow.count + 40); height: 190
    anchors.horizontalCenter: parent.horizontalCenter
    anchors.bottom: parent.bottom; anchors.bottomMargin: win.taskbarH + 12
    readonly property int activeWs: Hyprland.focusedMonitor && Hyprland.focusedMonitor.activeWorkspace ? Hyprland.focusedMonitor.activeWorkspace.id : 1
    Row {
      x: 20; y: 20
      spacing: 14
      Repeater {
        id: deskRow
        model: s.wsCount
        delegate: Rectangle {
          id: desk
          required property int index
          readonly property int ws: index + 1
          readonly property var wins: {
            var all = Hyprland.toplevels.values, out = []
            for (var i = 0; i < all.length; i++) if (all[i].workspace && all[i].workspace.id === desk.ws) out.push(all[i])
            return out
          }
          width: 200; height: 150; radius: 8
          color: dkma.containsMouse ? win.hover : "transparent"
          border.width: tasks.activeWs === ws ? 2 : 1
          border.color: tasks.activeWs === ws ? s.primary : win.line
          Rectangle {
            x: 10; y: 10; width: parent.width - 20; height: 100; radius: 4
            color: win.dark ? "#1b2533" : "#dce8f6"
            Column {
              anchors.centerIn: parent; spacing: 3
              Repeater {
                model: desk.wins.slice(0, 4)
                delegate: Text { required property var modelData; width: 160; elide: Text.ElideRight; horizontalAlignment: Text.AlignHCenter; text: modelData.title; font.family: win.font; font.pixelSize: 10; color: win.ink }
              }
              Text { visible: desk.wins.length === 0; text: T.t("Vide"); font.family: win.font; font.pixelSize: 11; color: win.sub; anchors.horizontalCenter: parent.horizontalCenter }
            }
          }
          Text { x: 12; y: 118; text: T.t("Bureau ") + desk.ws; font.family: win.font; font.pixelSize: 12; color: win.ink }
          MouseArea {
            id: dkma; anchors.fill: parent; hoverEnabled: true
            onClicked: { Quickshell.execDetached(["hyprctl", "dispatch", "hl.dsp.focus({ workspace = \"" + desk.ws + "\" })"]); win.close() }
          }
        }
      }
    }
  }

  // ================================================================ briques
  // Volet : fond mica, liseré, ombre, entrée en glissant vers le haut.
  component Panel: Item {
    id: pn
    property bool shown: false
    property bool fromLeft: false
    default property alias content: body.data
    visible: opacity > 0.01
    opacity: shown && win.revealed ? 1 : 0
    property real slide: shown && win.revealed ? 0 : 1
    transform: Translate { x: pn.fromLeft ? -pn.slide * 40 : 0; y: pn.fromLeft ? 0 : pn.slide * 40 }
    Behavior on opacity { NumberAnimation { duration: 160 } }
    Behavior on slide { NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }
    RectangularShadow { anchors.fill: body; radius: 8; blur: 32; spread: 0; offset.y: 8; color: Qt.rgba(0, 0, 0, win.dark ? 0.5 : 0.22) }
    Rectangle {
      id: body
      anchors.fill: parent
      radius: 8
      color: win.panelBg
      border.width: 1
      border.color: win.dark ? Qt.rgba(1, 1, 1, 0.09) : Qt.rgba(0, 0, 0, 0.09)
      MouseArea { anchors.fill: parent; onClicked: function(m) { m.accepted = true } }
    }
  }
  component Card: Rectangle {
    radius: 8
    color: win.cardBg
    border.width: 1
    border.color: win.line
  }
  component SmallBtn: Rectangle {
    id: sb
    property string label: ""
    property string leading: ""
    property string trailing: ""
    signal clicked()
    width: sbRow.implicitWidth + 16; height: 28; radius: 4
    color: sbma.containsMouse ? win.hover : (label !== "" ? win.cardBg : "transparent")
    border.width: label !== "" ? 1 : 0
    border.color: win.line
    Row {
      id: sbRow
      anchors.centerIn: parent; spacing: 4
      MIcon { visible: sb.leading !== ""; anchors.verticalCenter: parent.verticalCenter; icon: sb.leading; size: 16; color: win.ink }
      Text { visible: sb.label !== ""; anchors.verticalCenter: parent.verticalCenter; text: sb.label; font.family: win.font; font.pixelSize: 12; color: win.ink }
      MIcon { visible: sb.trailing !== ""; anchors.verticalCenter: parent.verticalCenter; icon: sb.trailing; size: 16; color: win.ink }
    }
    MouseArea { id: sbma; anchors.fill: parent; hoverEnabled: true; onClicked: sb.clicked() }
  }
  component QuickTile: Column {
    id: qt
    property string icon: ""
    property string label: ""
    property bool on: false
    property bool split: false
    signal toggled()
    signal more()
    spacing: 6
    width: 98
    Rectangle {
      width: 98; height: 48; radius: 6
      color: qt.on ? s.primary : win.cardBg
      border.width: qt.on ? 0 : 1
      border.color: win.line
      Behavior on color { ColorAnimation { duration: 140 } }
      Rectangle { anchors.fill: parent; radius: 6; color: qma.containsMouse ? Qt.rgba(1, 1, 1, 0.08) : "transparent" }
      MIcon { x: qt.split ? 18 : (parent.width - width) / 2; anchors.verticalCenter: parent.verticalCenter; icon: qt.icon; size: 18; fill: qt.on ? 1 : 0; color: qt.on ? s.colOnPrimary : win.ink }
      MouseArea { id: qma; width: qt.split ? parent.width - 40 : parent.width; height: parent.height; hoverEnabled: true; onClicked: qt.toggled() }
      Rectangle { visible: qt.split; x: parent.width - 40; y: 10; width: 1; height: parent.height - 20; color: qt.on ? Qt.rgba(1, 1, 1, 0.35) : win.line }
      MIcon { visible: qt.split; x: parent.width - 32; anchors.verticalCenter: parent.verticalCenter; icon: "chevron_right"; size: 18; color: qt.on ? s.colOnPrimary : win.ink }
      MouseArea { visible: qt.split; x: parent.width - 40; width: 40; height: parent.height; onClicked: qt.more() }
    }
    Text { width: parent.width; horizontalAlignment: Text.AlignHCenter; elide: Text.ElideRight; text: qt.label; font.family: win.font; font.pixelSize: 11; color: win.ink }
  }
  component SliderRow: Row {
    id: sr
    property string icon: ""
    property real value: 0
    signal moved(real v)
    signal iconClicked()
    spacing: 12
    MIcon { anchors.verticalCenter: parent.verticalCenter; icon: sr.icon; size: 20; color: win.ink; MouseArea { anchors.fill: parent; onClicked: sr.iconClicked() } }
    Item {
      id: track
      width: 270; height: 24
      anchors.verticalCenter: parent.verticalCenter
      Rectangle { anchors.verticalCenter: parent.verticalCenter; width: parent.width; height: 4; radius: 2; color: win.dark ? Qt.rgba(1, 1, 1, 0.3) : Qt.rgba(0, 0, 0, 0.35) }
      Rectangle { anchors.verticalCenter: parent.verticalCenter; width: parent.width * Math.max(0, Math.min(1, sr.value)); height: 4; radius: 2; color: s.primary }
      Rectangle {
        x: parent.width * Math.max(0, Math.min(1, sr.value)) - 10; anchors.verticalCenter: parent.verticalCenter
        width: 20; height: 20; radius: 10; color: win.dark ? "#454545" : "#ffffff"
        border.width: 1; border.color: win.line
        Rectangle { anchors.centerIn: parent; width: slma.pressed ? 8 : (slma.containsMouse ? 12 : 10); height: width; radius: width / 2; color: s.primary; Behavior on width { NumberAnimation { duration: 100 } } }
      }
      MouseArea {
        id: slma
        anchors.fill: parent; hoverEnabled: true
        onPressed: function(m) { sr.moved(Math.max(0, Math.min(1, m.x / width))) }
        onPositionChanged: function(m) { if (pressed) sr.moved(Math.max(0, Math.min(1, m.x / width))) }
      }
    }
  }
  component Menu: Rectangle {
    id: mn
    property var items: []
    signal picked(string id)
    visible: false
    width: 230; height: mnCol.implicitHeight + 10; radius: 8
    color: win.dark ? "#2c2c2c" : "#f9f9f9"
    border.width: 1; border.color: win.line
    Column {
      id: mnCol
      x: 5; y: 5; width: parent.width - 10
      Repeater {
        model: mn.items
        delegate: Rectangle {
          required property var modelData
          width: parent.width; height: 36; radius: 4
          color: mima.containsMouse ? win.hover : "transparent"
          Row {
            x: 12; anchors.verticalCenter: parent.verticalCenter; spacing: 12
            MIcon { icon: modelData[2]; size: 18; color: win.ink }
            Text { anchors.verticalCenter: parent.verticalCenter; text: modelData[1]; font.family: win.font; font.pixelSize: 12; color: win.ink }
          }
          MouseArea { id: mima; anchors.fill: parent; hoverEnabled: true; onClicked: { mn.visible = false; mn.picked(modelData[0]) } }
        }
      }
    }
  }
  component Avatar: Item {
    id: av
    property real size: 30
    width: size; height: size
    readonly property string face: Quickshell.env("HOME") + "/.face"
    ClippingRectangle {
      anchors.fill: parent; radius: av.size / 2
      color: s.primaryContainer
      Text { anchors.centerIn: parent; text: s.user.charAt(0).toUpperCase(); font.family: win.font; font.pixelSize: av.size * 0.45; font.weight: Font.DemiBold; color: s.colOnPrimaryContainer }
      Image { anchors.fill: parent; source: "file://" + av.face; fillMode: Image.PreserveAspectCrop; asynchronous: true; visible: status === Image.Ready }
    }
  }
}
