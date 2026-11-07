import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import Quickshell.Widgets
import Quickshell.Bluetooth
import Quickshell.Services.Pipewire

// Style « windows » : l'appli Paramètres (⌘⌥Espace, ⚙ des paramètres rapides),
// une vraie fenêtre Hyprland (flottante, centrée) avec la barre latérale de
// Windows 11 : Accueil, Système, Bluetooth et appareils, Réseau et Internet,
// Personnalisation, Applications, Comptes, Heure et langue, Accessibilité,
// Mise à jour — et Système › Informations (caractéristiques de l'appareil).
// Contenu seul : la fenêtre est dans WinSettings.qml.
Rectangle {
  id: win
  property var service: null
  readonly property var s: service
  color: dark ? "#202020" : "#f3f3f3"

  readonly property bool dark: s.darkSkin
  readonly property color ink: s.colOnSurface
  readonly property color sub: s.colOnSurfaceVariant
  readonly property color card: dark ? "#2b2b2b" : "#fbfbfb"
  readonly property color cardHover: dark ? "#323232" : "#f6f6f6"
  readonly property color line: dark ? Qt.rgba(1, 1, 1, 0.07) : Qt.rgba(0, 0, 0, 0.07)
  readonly property color hover: dark ? Qt.rgba(1, 1, 1, 0.06) : Qt.rgba(0, 0, 0, 0.04)
  readonly property string font: s.sansFont
  function cap(t) { t = String(t); return t.charAt(0).toUpperCase() + t.slice(1) }

  readonly property var pages: [
    ["home", "Accueil", "home", "#4f8ef7"],
    ["system", "Système", "computer", "#3a8ee6"],
    ["bt", "Bluetooth et appareils", "bluetooth", "#2a7fd9"],
    ["net", "Réseau et Internet", "wifi", "#4a6bdc"],
    ["perso", "Personnalisation", "brush", "#e0803a"],
    ["apps", "Applications", "apps", "#6b6fd6"],
    ["accounts", "Comptes", "person", "#2fa36b"],
    ["time", "Heure et langue", "schedule", "#3a9ad9"],
    ["access", "Accessibilité", "accessibility_new", "#2d8cd6"],
    ["update", "Mise à jour", "sync", "#1f7ad1"]
  ]
  property string page: s.menuPage && s.menuPage !== "home" ? s.menuPage : "home"
  property var history: []
  function go(p) { if (p !== page) { history = history.concat([page]); page = p; scroller.contentY = 0 } }
  function back() { if (history.length) { page = history[history.length - 1]; history = history.slice(0, -1) } }
  Connections { target: s; function onMenuPageChanged() { if (s.menuPage && s.menuPage !== "home") win.go(s.menuPage) } }
  readonly property string pageTitle: {
    if (page === "about") return "Informations"
    if (page === "display") return "Écran"
    if (page === "sound") return "Son"
    if (page === "power") return "Alimentation et batterie"
    for (var i = 0; i < pages.length; i++) if (pages[i][0] === page) return pages[i][1]
    return ""
  }
  readonly property string crumb: ["about", "display", "sound", "power"].indexOf(page) >= 0 ? "Système" : ""

  Component.onCompleted: { s.scanWifi(); s.readBrightness(); tzP.running = true }
  property string tz: ""
  Process { id: tzP; command: ["timedatectl", "show", "-p", "Timezone", "--value"]; stdout: StdioCollector { onStreamFinished: win.tz = text.trim() } }
  property date now: new Date()
  Timer { interval: 1000; repeat: true; running: true; onTriggered: win.now = new Date() }

  PwObjectTracker { objects: [Pipewire.defaultAudioSink, Pipewire.defaultAudioSource] }
  readonly property var sink: Pipewire.defaultAudioSink
  readonly property var bt: Bluetooth.defaultAdapter

  // ------------------------------------------------------------ barre de titre
  Item {
    id: titleBar
    width: parent.width; height: 44
    Row {
      x: 14; anchors.verticalCenter: parent.verticalCenter; spacing: 12
      Rectangle {
        visible: win.history.length > 0
        width: 36; height: 30; radius: 4; color: bma.containsMouse ? win.hover : "transparent"
        MIcon { anchors.centerIn: parent; icon: "arrow_back"; size: 16; color: win.ink }
        MouseArea { id: bma; anchors.fill: parent; hoverEnabled: true; onClicked: win.back() }
      }
      WinLogo { anchors.verticalCenter: parent.verticalCenter; size: 14; visible: win.history.length === 0 }
      Text { anchors.verticalCenter: parent.verticalCenter; text: "Paramètres"; font.family: win.font; font.pixelSize: 12; color: win.ink }
    }
    Row {
      anchors.right: parent.right; anchors.top: parent.top
      Repeater {
        model: [["minimize", "remove"], ["max", "crop_square"], ["close", "close"]]
        delegate: Rectangle {
          required property var modelData
          width: 46; height: 32
          color: cma.containsMouse ? (modelData[0] === "close" ? "#c42b1c" : win.hover) : "transparent"
          MIcon { anchors.centerIn: parent; icon: modelData[1]; size: 16; weight: 300; color: cma.containsMouse && modelData[0] === "close" ? "white" : win.ink }
          MouseArea {
            id: cma; anchors.fill: parent; hoverEnabled: true
            onClicked: {
              if (modelData[0] === "close") s.menuOpen = false
              else if (modelData[0] === "max") Quickshell.execDetached(["hyprctl", "dispatch", "hl.dsp.window.fullscreen({ mode = 1 })"])
              else Quickshell.execDetached(["hyprctl", "dispatch", "hl.dsp.window.move({ workspace = \"special:minimized\" })"])
            }
          }
        }
      }
    }
  }

  // ------------------------------------------------------------ barre latérale
  Column {
    id: side
    x: 16; y: 52
    width: 280
    spacing: 4
    Row {
      spacing: 14
      bottomPadding: 12
      Avatar { size: 64 }
      Column {
        anchors.verticalCenter: parent.verticalCenter
        Text { text: s.user.charAt(0).toUpperCase() + s.user.slice(1); font.family: win.font; font.pixelSize: 14; font.weight: Font.DemiBold; color: win.ink }
        Text { text: "Compte local"; font.family: win.font; font.pixelSize: 12; color: win.sub }
      }
    }
    Rectangle {
      width: parent.width - 8; height: 34; radius: 4
      color: win.dark ? "#2d2d2d" : "#fbfbfb"
      border.width: 1; border.color: findInput.activeFocus ? s.primary : win.line
      TextInput {
        id: findInput
        x: 12; anchors.verticalCenter: parent.verticalCenter; width: parent.width - 44
        font.family: win.font; font.pixelSize: 13; color: win.ink; clip: true
        Text { visible: parent.text === ""; text: "Rechercher un paramètre"; font: parent.font; color: win.sub }
        onAccepted: {
          var q = text.toLowerCase()
          for (var i = 0; i < win.pages.length; i++) if (win.pages[i][1].toLowerCase().indexOf(q) >= 0) { win.go(win.pages[i][0]); break }
          if (q.indexOf("info") >= 0 || q.indexOf("propos") >= 0) win.go("about")
        }
      }
      MIcon { anchors.right: parent.right; anchors.rightMargin: 10; anchors.verticalCenter: parent.verticalCenter; icon: "search"; size: 16; color: win.sub }
    }
    Item { width: 1; height: 6 }
    Repeater {
      model: win.pages
      delegate: Rectangle {
        id: nav
        required property var modelData
        readonly property bool cur: win.page === modelData[0] || (modelData[0] === "system" && win.crumb === "Système")
        width: side.width - 8; height: 38; radius: 4
        color: cur ? (win.dark ? "#2d2d2d" : "#eaeaea") : (nma.containsMouse ? win.hover : "transparent")
        Rectangle { visible: nav.cur; x: 0; anchors.verticalCenter: parent.verticalCenter; width: 3; height: 16; radius: 1.5; color: s.primary }
        Row {
          x: 14; anchors.verticalCenter: parent.verticalCenter; spacing: 14
          MIcon { anchors.verticalCenter: parent.verticalCenter; icon: nav.modelData[2]; size: 18; fill: 1; color: nav.modelData[3] }
          Text { anchors.verticalCenter: parent.verticalCenter; text: nav.modelData[1]; font.family: win.font; font.pixelSize: 13; color: win.ink }
        }
        MouseArea { id: nma; anchors.fill: parent; hoverEnabled: true; onClicked: { win.history = []; win.page = nav.modelData[0]; scroller.contentY = 0 } }
      }
    }
  }

  // ------------------------------------------------------------ contenu
  Item {
    id: main
    x: side.x + side.width + 20; y: 44
    width: parent.width - x - 20; height: parent.height - y
    Row {
      id: head
      y: 8
      spacing: 10
      Text { visible: win.crumb !== ""; text: win.crumb; font.family: win.font; font.pixelSize: 28; font.weight: Font.DemiBold; color: win.sub
        MouseArea { anchors.fill: parent; onClicked: win.go("system") } }
      MIcon { visible: win.crumb !== ""; anchors.verticalCenter: parent.verticalCenter; icon: "chevron_right"; size: 22; color: win.sub }
      Text { text: win.pageTitle; font.family: win.font; font.pixelSize: 28; font.weight: Font.DemiBold; color: win.ink }
    }
    Flickable {
      id: scroller
      y: 64
      width: parent.width; height: parent.height - 64
      contentHeight: pageCol.implicitHeight + 30
      clip: true
      boundsBehavior: Flickable.StopAtBounds
      Column {
        id: pageCol
        width: scroller.width - 12
        spacing: 4

        // ======================================== Accueil
        Column {
          visible: win.page === "home"
          width: parent.width; spacing: 4
          DeviceHeader {}
          Section { text: "Paramètres recommandés" }
          SettingRow { icon: "wifi"; title: "Réseau et Internet"; sub: s.netDev === "" ? "Non connecté" : (s.netWifi && s.wifiList.length && s.wifiList[0].active ? "Connecté à " + s.wifiList[0].ssid : "Connecté"); chevron: true; onClicked: win.go("net") }
          SettingRow { icon: "bluetooth"; title: "Bluetooth et appareils"; sub: win.bt && win.bt.enabled ? "Activé" : "Désactivé"; chevron: true; onClicked: win.go("bt") }
          SettingRow { icon: "brush"; title: "Personnalisation"; sub: "Fond d'écran, mode clair ou sombre, bureaux"; chevron: true; onClicked: win.go("perso") }
          SettingRow { icon: "info"; title: "Informations"; sub: "Caractéristiques de l'appareil"; chevron: true; onClicked: win.go("about") }
        }

        // ======================================== Système
        Column {
          visible: win.page === "system"
          width: parent.width; spacing: 4
          DeviceHeader {}
          SettingRow { icon: "desktop_windows"; title: "Écran"; sub: "Luminosité, éclairage nocturne"; chevron: true; onClicked: win.go("display") }
          SettingRow { icon: "volume_up"; title: "Son"; sub: "Volume, périphériques de sortie"; chevron: true; onClicked: win.go("sound") }
          SettingRow { icon: "notifications"; title: "Notifications"; sub: "Historique des notifications"; chevron: true
            onClicked: Quickshell.execDetached(["sh", "-c", "omarchy-shell notifications showHistory"]) }
          SettingRow { icon: "battery_full"; title: "Alimentation et batterie"; sub: s.batteryPct >= 0 ? s.batteryPct + " %" + (s.charging ? ", en charge" : "") : "Secteur"; chevron: true; onClicked: win.go("power") }
          SettingRow { icon: "hard_drive"; title: "Stockage"; sub: (win.s.info.disk || "") + " utilisés"; chevron: false }
          SettingRow { icon: "content_copy"; title: "Presse-papiers"; sub: "Historique du presse-papiers"; chevron: false }
          SettingRow { icon: "info"; title: "Informations"; sub: "Caractéristiques de l'appareil, renommer le PC"; chevron: true; onClicked: win.go("about") }
        }

        // ======================================== Écran
        Column {
          visible: win.page === "display"
          width: parent.width; spacing: 4
          SettingRow { icon: "light_mode"; title: "Luminosité"; sub: "Régler la luminosité de l'écran intégré"
            Slider { value: Math.max(0, s.brightness); onMoved: function(v) { s.setBrightness(v) } } }
          SettingRow { icon: "nightlight"; title: "Éclairage nocturne"; sub: "Couleurs plus chaudes pour mieux dormir"
            Toggle { on: false; onToggled: Quickshell.execDetached(["omarchy-toggle-nightlight"]) } }
          SettingRow { icon: "aspect_ratio"; title: "Résolution d'écran"; sub: win.s.info.res || "" }
          SettingRow { icon: "zoom_in"; title: "Mise à l'échelle"; sub: "150 % (recommandé)" }
        }

        // ======================================== Son
        Column {
          visible: win.page === "sound"
          width: parent.width; spacing: 4
          Section { text: "Sortie" }
          SettingRow { icon: "speaker"; title: win.sink ? (win.sink.description || win.sink.name) : "Aucun périphérique"; sub: "Volume"
            Slider { value: win.sink && win.sink.audio ? win.sink.audio.volume : 0; onMoved: function(v) { if (win.sink && win.sink.audio) win.sink.audio.volume = v } } }
          SettingRow { icon: "volume_off"; title: "Muet"; sub: "Couper le son"
            Toggle { on: !!win.sink && !!win.sink.audio && win.sink.audio.muted; onToggled: if (win.sink && win.sink.audio) win.sink.audio.muted = !win.sink.audio.muted } }
          Section { text: "Entrée" }
          SettingRow { icon: "mic"; title: Pipewire.defaultAudioSource ? (Pipewire.defaultAudioSource.description || Pipewire.defaultAudioSource.name) : "Aucun micro"; sub: "Volume du micro"
            Slider {
              value: Pipewire.defaultAudioSource && Pipewire.defaultAudioSource.audio ? Pipewire.defaultAudioSource.audio.volume : 0
              onMoved: function(v) { if (Pipewire.defaultAudioSource && Pipewire.defaultAudioSource.audio) Pipewire.defaultAudioSource.audio.volume = v }
            } }
        }

        // ======================================== Alimentation
        Column {
          visible: win.page === "power"
          width: parent.width; spacing: 4
          SettingRow { icon: s.charging ? "battery_charging_full" : "battery_full"; title: s.batteryPct >= 0 ? "Niveau de batterie : " + s.batteryPct + " %" : "Sur secteur"; sub: s.charging ? "En charge" : "Sur batterie" }
          SettingRow { icon: "bedtime"; title: "Mettre en veille"; sub: "Suspendre maintenant"; chevron: true; onClicked: s.power("suspend") }
          SettingRow { icon: "lock"; title: "Verrouiller"; sub: "Écran de verrouillage"; chevron: true; onClicked: s.power("lock") }
        }

        // ======================================== Informations
        Column {
          visible: win.page === "about"
          width: parent.width; spacing: 4
          Rectangle {
            width: parent.width; height: 120; radius: 6; color: win.card
            border.width: 1; border.color: win.line
            Row {
              x: 22; anchors.verticalCenter: parent.verticalCenter; spacing: 22
              Item {
                width: 112; height: 76; anchors.verticalCenter: parent.verticalCenter
                // Petit portable dessiné avec le fond courant à l'écran.
                ClippingRectangle {
                  x: 10; width: 92; height: 60; radius: 3; color: "#0b1626"
                  border.width: 3; border.color: win.dark ? "#555" : "#1b1b1b"
                  Image { anchors.fill: parent; anchors.margins: 3; source: s.bgPath !== "" ? "file://" + s.bgPath : ""; sourceSize.width: 200; fillMode: Image.PreserveAspectCrop; asynchronous: true }
                }
                Rectangle { y: 60; width: 112; height: 7; radius: 2; color: win.dark ? "#666" : "#9a9a9a" }
              }
              Column {
                anchors.verticalCenter: parent.verticalCenter; spacing: 2
                Text { text: win.s.info.host || "PC"; font.family: win.font; font.pixelSize: 20; font.weight: Font.DemiBold; color: win.ink }
                Text { text: win.s.info.model || ""; font.family: win.font; font.pixelSize: 13; color: win.sub }
              }
            }
            Rectangle {
              anchors.right: parent.right; anchors.rightMargin: 20; anchors.verticalCenter: parent.verticalCenter
              width: 150; height: 32; radius: 4; color: rnma.containsMouse ? win.cardHover : (win.dark ? "#373737" : "#fdfdfd")
              border.width: 1; border.color: win.line
              Text { anchors.centerIn: parent; text: "Renommer ce PC"; font.family: win.font; font.pixelSize: 12; color: win.ink }
              MouseArea { id: rnma; anchors.fill: parent; hoverEnabled: true
                onClicked: Quickshell.execDetached(["omarchy-launch-floating-terminal-with-presentation", "sh -c 'read -p \"Nouveau nom du PC : \" n && sudo hostnamectl set-hostname \"$n\"'"]) }
            }
          }
          Expander {
            icon: "computer"; title: "Caractéristiques de l'appareil"
            copyText: "Nom de l'appareil\t" + (win.s.info.host || "") + "\nProcesseur\t" + (win.s.info.cpu || "") + "\nMémoire RAM installée\t" + (win.s.info.ram || "") + " Go\nCarte graphique\t" + (win.s.info.gpu || "") + "\nType du système\tSystème d'exploitation 64 bits, processeur x64"
            rows: [["Nom de l'appareil", win.s.info.host || ""], ["Processeur", win.s.info.cpu || ""], ["Mémoire RAM installée", (win.s.info.ram || "?") + " Go"],
                   ["Carte graphique", win.s.info.gpu || ""], ["Stockage", (win.s.info.disk || "") + " utilisés"],
                   ["Type du système", "Système d'exploitation 64 bits, processeur x64"], ["Stylet et fonctions tactiles", "La fonctionnalité d'entrée tactile ou avec un stylet n'est pas disponible sur cet écran"]]
          }
          Expander {
            icon: "grid_view"; title: "Caractéristiques du système"; logo: true
            copyText: "Édition\t" + (win.s.info.os || "") + "\nVersion\t" + (win.s.info.omarchy || "") + "\nInstallé le\t" + (win.s.info.installed || "") + "\nNoyau\t" + (win.s.info.kernel || "")
            rows: [["Édition", (win.s.info.os || "Omarchy") + " · Liquid Glass"], ["Version", win.s.info.omarchy || ""], ["Installé le", win.s.info.installed || ""],
                   ["Noyau", win.s.info.kernel || ""], ["Bureau", "Hyprland + Quickshell"], ["Expérience", "Liquid Glass — style Windows"]]
          }
          Section { text: "Paramètres associés" }
          SettingRow { icon: "key"; title: "Clé de produit et activation"; sub: "Logiciel libre, rien à activer"; chevron: false }
          SettingRow { icon: "terminal"; title: "Informations détaillées"; sub: "fastfetch dans un terminal"; chevron: true
            onClicked: Quickshell.execDetached(["omarchy-launch-floating-terminal-with-presentation", "fastfetch"]) }
        }

        // ======================================== Bluetooth
        Column {
          visible: win.page === "bt"
          width: parent.width; spacing: 4
          SettingRow { icon: "bluetooth"; title: "Bluetooth"; sub: win.bt ? (win.bt.enabled ? "Détectable sous le nom « " + (win.s.info.host || "PC") + " »" : "Désactivé") : "Pas d'adaptateur"
            Toggle { on: !!win.bt && win.bt.enabled; onToggled: if (win.bt) win.bt.enabled = !win.bt.enabled } }
          SettingRow { icon: "add"; title: "Ajouter un appareil"; sub: win.bt && win.bt.discovering ? "Recherche en cours…" : "Rechercher les appareils à proximité"; chevron: true
            onClicked: if (win.bt) win.bt.discovering = !win.bt.discovering }
          Section { text: "Appareils" }
          Repeater {
            model: win.bt && win.bt.devices ? win.bt.devices.values : []
            delegate: SettingRow {
              required property var modelData
              icon: String(modelData.icon || "").indexOf("audio") >= 0 ? "headphones" : (String(modelData.icon || "").indexOf("input") >= 0 ? "mouse" : "devices_other")
              title: modelData.name || modelData.deviceName || modelData.address
              sub: modelData.connected ? "Connecté" + (modelData.batteryAvailable ? " · " + Math.round(modelData.battery * 100) + " %" : "") : (modelData.paired ? "Associé" : "Disponible")
              Button2 { label: modelData.connected ? "Déconnecter" : "Connecter"; onClicked: modelData.connected = !modelData.connected }
            }
          }
        }

        // ======================================== Réseau
        Column {
          visible: win.page === "net"
          width: parent.width; spacing: 4
          Rectangle {
            width: parent.width; height: 90; radius: 6; color: win.card; border.width: 1; border.color: win.line
            Row {
              x: 22; anchors.verticalCenter: parent.verticalCenter; spacing: 18
              MIcon { anchors.verticalCenter: parent.verticalCenter; icon: s.netWifi ? "wifi" : (s.netDev === "" ? "wifi_off" : "lan"); size: 40; color: s.primary }
              Column {
                anchors.verticalCenter: parent.verticalCenter
                Text { text: s.netWifi && s.wifiList.length && s.wifiList[0].active ? s.wifiList[0].ssid : (s.netDev === "" ? "Non connecté" : "Ethernet"); font.family: win.font; font.pixelSize: 16; font.weight: Font.DemiBold; color: win.ink }
                Text { text: s.netDev === "" ? "Aucune connexion Internet" : "Connecté, sécurisé · " + s.netDev; font.family: win.font; font.pixelSize: 12; color: win.sub }
              }
            }
          }
          SettingRow { icon: "wifi"; title: "Wi-Fi"; sub: s.wifiOn ? "Activé" : "Désactivé"
            Toggle { on: s.wifiOn; onToggled: s.setWifi(!s.wifiOn) } }
          SettingRow { icon: "refresh"; title: "Afficher les réseaux disponibles"; sub: s.wifiBusy ? "Recherche…" : s.wifiList.length + " réseaux"; chevron: true; onClicked: s.scanWifi() }
          Repeater {
            model: s.wifiList
            delegate: SettingRow {
              required property var modelData
              icon: modelData.signal > 66 ? "network_wifi" : (modelData.signal > 33 ? "network_wifi_2_bar" : "network_wifi_1_bar")
              title: modelData.ssid
              sub: (modelData.active ? "Connecté, " : "") + (modelData.secure ? "sécurisé" : "ouvert") + " · " + modelData.signal + " %"
              Button2 { visible: !modelData.active; label: "Se connecter"; onClicked: s.connectWifi(modelData.ssid) }
            }
          }
        }

        // ======================================== Personnalisation
        Column {
          visible: win.page === "perso"
          width: parent.width; spacing: 4
          Rectangle {
            width: parent.width; height: 210; radius: 6; color: win.card; border.width: 1; border.color: win.line
            ClippingRectangle {
              x: 22; y: 20; width: 280; height: 170; radius: 6; color: "black"
              Image { anchors.fill: parent; source: s.bgPath !== "" ? "file://" + s.bgPath : ""; sourceSize.width: 600; fillMode: Image.PreserveAspectCrop; asynchronous: true }
              // mini barre des tâches
              Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 14; color: win.dark ? Qt.rgba(0.12, 0.12, 0.13, 0.9) : Qt.rgba(0.93, 0.94, 0.96, 0.9)
                Row { anchors.centerIn: parent; spacing: 4; WinLogo { size: 8 } Repeater { model: 4; delegate: Rectangle { width: 8; height: 8; radius: 2; color: s.primary; opacity: 0.6 } } } }
            }
            Column {
              x: 330; y: 24; spacing: 10; width: parent.width - 350
              Text { text: "Sélectionnez un thème à appliquer"; font.family: win.font; font.pixelSize: 14; font.weight: Font.DemiBold; color: win.ink }
              Row {
                spacing: 12
                Repeater {
                  model: [["clair", "#f3f3f3", "#005fb8"], ["sombre", "#1c1c1c", "#4cc2ff"]]
                  delegate: Rectangle {
                    required property var modelData
                    width: 92; height: 64; radius: 6
                    color: modelData[1]
                    border.width: s.wtone === modelData[0] ? 2 : 1
                    border.color: s.wtone === modelData[0] ? s.primary : win.line
                    WinLogo { anchors.centerIn: parent; size: 20; c1: modelData[2]; c2: modelData[2] }
                    Text { anchors.horizontalCenter: parent.horizontalCenter; anchors.top: parent.bottom; anchors.topMargin: 4; text: modelData[0] === "clair" ? "Clair" : "Sombre"; font.family: win.font; font.pixelSize: 11; color: win.ink }
                    MouseArea { anchors.fill: parent; onClicked: Quickshell.execDetached(["liquid-glass", "profile", "windows:" + modelData[0]]) }
                  }
                }
              }
            }
          }
          SettingRow { icon: "wallpaper"; title: "Arrière-plan"; sub: "Choisir parmi les fonds (carrousel)"; chevron: true; onClicked: { s.menuOpen = false; s.wallsOpen = true } }
          SettingRow { icon: "dashboard_customize"; title: "Changer de bureau"; sub: "Mac, Omarchy, Mono, Forêt, Violet… (⌘⇧Espace)"; chevron: true
            onClicked: { s.menuOpen = false; Quickshell.execDetached(["liquid-glass", "profile", "pick"]) } }
          // Couleurs : accent comme dans Windows 11 (Manuel / Automatique depuis l'arrière-plan).
          Rectangle {
            width: parent.width; height: accCol.implicitHeight + 32; radius: 6; color: win.card; border.width: 1; border.color: win.line
            Column {
              id: accCol
              x: 20; y: 16; width: parent.width - 40; spacing: 12
              Item {
                width: parent.width; height: 44
                MIcon { anchors.verticalCenter: parent.verticalCenter; icon: "palette"; size: 22; color: win.ink }
                Column {
                  x: 36; anchors.verticalCenter: parent.verticalCenter; width: parent.width - 36 - modeRow.width - 12
                  Text { text: "Couleur d'accentuation"; font.family: win.font; font.pixelSize: 14; color: win.ink }
                  Text { text: s.colorMode === "fond" ? "Automatique, tirée de l'arrière-plan" : (s.colorMode === "perso" ? "Manuel" : "Bleu Windows (par défaut)"); font.family: win.font; font.pixelSize: 12; color: win.sub }
                }
                Row {
                  id: modeRow
                  anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; spacing: 6
                  Repeater {
                    model: [["theme", "Par défaut"], ["fond", "Automatique"], ["perso", "Manuel"]]
                    delegate: Rectangle {
                      required property var modelData
                      readonly property bool cur: s.colorMode === modelData[0]
                      width: mText.implicitWidth + 20; height: 30; radius: 4
                      color: cur ? s.primary : (mMa.containsMouse ? win.hover : win.card)
                      border.width: 1; border.color: cur ? s.primary : win.line
                      Text { id: mText; anchors.centerIn: parent; text: modelData[1]; font.family: win.font; font.pixelSize: 12; color: cur ? s.colOnPrimary : win.ink }
                      MouseArea {
                        id: mMa; anchors.fill: parent; hoverEnabled: true
                        onClicked: {
                          s.setOpt("windows_colors", modelData[0])
                          if (modelData[0] === "perso" && s.accentHex === "") s.setOpt("windows_accent", "#0078d4")
                        }
                      }
                    }
                  }
                }
              }
              Text { text: "Couleurs Windows"; font.family: win.font; font.pixelSize: 13; font.weight: Font.DemiBold; color: win.ink }
              Grid {
                columns: 12; spacing: 6
                Repeater {
                  model: ["#ffb900", "#ff8c00", "#f7630c", "#ca5010", "#da3b01", "#ef6950", "#d13438", "#ff4343",
                          "#e74856", "#e81123", "#ea005e", "#c30052", "#e3008c", "#bf0077", "#c239b3", "#9a0089",
                          "#0078d4", "#0063b1", "#8e8cd8", "#6b69d6", "#8764b8", "#744da9", "#b146c2", "#881798",
                          "#0099bc", "#2d7d9a", "#00b7c3", "#038387", "#00b294", "#018574", "#00cc6a", "#10893e",
                          "#7a7574", "#5d5a58", "#68768a", "#515c6b", "#567c73", "#486860", "#498205", "#107c10"]
                  delegate: Rectangle {
                    required property string modelData
                    readonly property bool cur: s.colorMode === "perso" && s.accentHex.toLowerCase() === modelData
                    width: 36; height: 36; radius: 4
                    color: modelData
                    border.width: cur ? 3 : 0; border.color: win.ink
                    MIcon { visible: parent.cur; anchors.centerIn: parent; icon: "check"; size: 18; color: "white" }
                    MouseArea {
                      anchors.fill: parent
                      onClicked: { s.setOpt("windows_accent", modelData); if (s.colorMode !== "perso") s.setOpt("windows_colors", "perso") }
                    }
                  }
                }
              }
            }
          }
          SettingRow { icon: "lock"; title: "Écran de verrouillage"; sub: "Horloge, image et état de la musique"; chevron: true; onClicked: s.power("lock") }
          SettingRow { icon: "settings_applications"; title: "Réglages avancés de Liquid Glass"; sub: "Tous les réglages du bureau"; chevron: true
            onClicked: { s.menuOpen = false; Quickshell.execDetached(["sh", "-c", "omarchy-shell shell toggle liquid-glass.settings"]) } }
        }

        // ======================================== Applications
        Column {
          visible: win.page === "apps"
          width: parent.width; spacing: 4
          Section { text: "Applications installées" }
          Repeater {
            model: win.page === "apps" ? s.apps("") : []
            delegate: SettingRow {
              required property var modelData
              title: s.appName(modelData)
              sub: String(modelData.genericName || modelData.comment || "")
              appIcon: s.appIcon(modelData)
              Button2 { label: "Ouvrir"; onClicked: s.launch(modelData) }
            }
          }
        }

        // ======================================== Comptes
        Column {
          visible: win.page === "accounts"
          width: parent.width; spacing: 4
          Rectangle {
            width: parent.width; height: 110; radius: 6; color: win.card; border.width: 1; border.color: win.line
            Row {
              x: 22; anchors.verticalCenter: parent.verticalCenter; spacing: 18
              Avatar { size: 72 }
              Column {
                anchors.verticalCenter: parent.verticalCenter
                Text { text: s.user.charAt(0).toUpperCase() + s.user.slice(1); font.family: win.font; font.pixelSize: 18; font.weight: Font.DemiBold; color: win.ink }
                Text { text: "Compte local · Administrateur"; font.family: win.font; font.pixelSize: 12; color: win.sub }
              }
            }
          }
          SettingRow { icon: "lock"; title: "Verrouiller la session"; chevron: true; onClicked: s.power("lock") }
          SettingRow { icon: "logout"; title: "Se déconnecter"; chevron: true; onClicked: s.power("logout") }
          SettingRow { icon: "image"; title: "Votre photo"; sub: "Placer une image dans ~/.face" }
        }

        // ======================================== Heure et langue
        Column {
          visible: win.page === "time"
          width: parent.width; spacing: 4
          Rectangle {
            width: parent.width; height: 100; radius: 6; color: win.card; border.width: 1; border.color: win.line
            Column {
              x: 22; anchors.verticalCenter: parent.verticalCenter
              Text { text: Qt.formatTime(win.now, "HH:mm"); font.family: win.font; font.pixelSize: 34; font.weight: Font.DemiBold; color: win.ink }
              Text { text: win.cap(win.now.toLocaleDateString(Qt.locale("fr_FR"), "dddd d MMMM yyyy")); font.family: win.font; font.pixelSize: 13; color: win.sub }
            }
          }
          SettingRow { icon: "public"; title: "Fuseau horaire"; sub: win.tz }
          SettingRow { icon: "keyboard"; title: "Clavier"; sub: s.layout !== "" ? s.layout : "Français" }
          SettingRow { icon: "translate"; title: "Langue d'affichage"; sub: "Français (France)" }
        }

        // ======================================== Accessibilité
        Column {
          visible: win.page === "access"
          width: parent.width; spacing: 4
          SettingRow { icon: "animation"; title: "Effets d'animation"; sub: "Animations des fenêtres"
            Toggle { on: true; onToggled: Quickshell.execDetached(["omarchy-toggle-animations"]) } }
          SettingRow { icon: "dark_mode"; title: "Mode sombre"; sub: "Thème de contraste foncé"
            Toggle { on: s.wtone === "sombre"; onToggled: Quickshell.execDetached(["liquid-glass", "profile", "windows:" + (s.wtone === "sombre" ? "clair" : "sombre")]) } }
          SettingRow { icon: "keyboard"; title: "Son des touches"; sub: "Clavier mécanique (Mechvibes)"; chevron: true
            onClicked: Quickshell.execDetached(["sh", "-c", "mechvibes || liquid-glass keys test"]) }
        }

        // ======================================== Mise à jour
        Column {
          visible: win.page === "update"
          width: parent.width; spacing: 4
          Rectangle {
            width: parent.width; height: 110; radius: 6; color: win.card; border.width: 1; border.color: win.line
            Row {
              x: 22; anchors.verticalCenter: parent.verticalCenter; spacing: 18
              Rectangle { width: 56; height: 56; radius: 28; color: s.alpha(s.primary, 0.12); anchors.verticalCenter: parent.verticalCenter
                MIcon { anchors.centerIn: parent; icon: "sync"; size: 32; color: s.primary } }
              Column {
                anchors.verticalCenter: parent.verticalCenter
                Text { text: "Mises à jour d'Omarchy"; font.family: win.font; font.pixelSize: 18; font.weight: Font.DemiBold; color: win.ink }
                Text { text: "Version " + (win.s.info.omarchy || "?") + " · système, paquets et firmware"; font.family: win.font; font.pixelSize: 12; color: win.sub }
              }
            }
            Rectangle {
              anchors.right: parent.right; anchors.rightMargin: 20; anchors.verticalCenter: parent.verticalCenter
              width: 230; height: 32; radius: 4; color: upma.containsMouse ? Qt.lighter(s.primary, 1.1) : s.primary
              Text { anchors.centerIn: parent; text: "Rechercher des mises à jour"; font.family: win.font; font.pixelSize: 12; color: s.colOnPrimary }
              MouseArea { id: upma; anchors.fill: parent; hoverEnabled: true; onClicked: Quickshell.execDetached(["omarchy-launch-floating-terminal-with-presentation", "omarchy-update"]) }
            }
          }
        }
      }
    }
  }

  // ------------------------------------------------------------ briques
  component Section: Text {
    topPadding: 16; bottomPadding: 6
    font.family: win.font; font.pixelSize: 14; font.weight: Font.DemiBold; color: win.ink
  }
  component DeviceHeader: Rectangle {
    width: parent ? parent.width : 0; height: 104; radius: 6; color: "transparent"
    Row {
      anchors.verticalCenter: parent.verticalCenter; spacing: 20
      ClippingRectangle {
        width: 150; height: 90; radius: 6; color: "black"
        Image { anchors.fill: parent; source: s.bgPath !== "" ? "file://" + s.bgPath : ""; sourceSize.width: 320; fillMode: Image.PreserveAspectCrop; asynchronous: true }
      }
      Column {
        anchors.verticalCenter: parent.verticalCenter; spacing: 2
        Text { text: win.s.info.host || "PC"; font.family: win.font; font.pixelSize: 18; font.weight: Font.DemiBold; color: win.ink }
        Text { text: win.s.info.model || ""; font.family: win.font; font.pixelSize: 12; color: win.sub }
        Text { text: "Renommer"; font.family: win.font; font.pixelSize: 12; color: s.primary; MouseArea { anchors.fill: parent; onClicked: win.go("about") } }
      }
    }
  }
  component SettingRow: Rectangle {
    id: row
    property string icon: ""
    property string appIcon: ""
    property string title: ""
    property string sub: ""
    property bool chevron: false
    signal clicked()
    default property alias trailing: trail.data
    width: parent ? parent.width : 0; height: sub !== "" ? 68 : 54; radius: 6
    color: rma.containsMouse && chevron ? win.cardHover : win.card
    border.width: 1; border.color: win.line
    MouseArea { id: rma; anchors.fill: parent; hoverEnabled: true; onClicked: row.clicked() }
    MIcon { visible: row.appIcon === ""; x: 20; anchors.verticalCenter: parent.verticalCenter; icon: row.icon; size: 20; color: win.ink }
    IconImage { visible: row.appIcon !== ""; x: 18; anchors.verticalCenter: parent.verticalCenter; implicitSize: 24; source: row.appIcon; asynchronous: true }
    Column {
      x: 58; anchors.verticalCenter: parent.verticalCenter; width: parent.width - 58 - trail.width - 60
      Text { width: parent.width; elide: Text.ElideRight; text: row.title; font.family: win.font; font.pixelSize: 13; color: win.ink }
      Text { visible: row.sub !== ""; width: parent.width; elide: Text.ElideRight; text: row.sub; font.family: win.font; font.pixelSize: 11; color: win.sub }
    }
    Row {
      id: trail
      anchors.right: parent.right; anchors.rightMargin: row.chevron ? 48 : 20; anchors.verticalCenter: parent.verticalCenter
      spacing: 8
    }
    MIcon { visible: row.chevron; anchors.right: parent.right; anchors.rightMargin: 18; anchors.verticalCenter: parent.verticalCenter; icon: "chevron_right"; size: 18; color: win.ink }
  }
  component Toggle: Row {
    id: tg
    property bool on: false
    signal toggled()
    spacing: 12
    Text { anchors.verticalCenter: parent.verticalCenter; text: tg.on ? "Activé" : "Désactivé"; font.family: win.font; font.pixelSize: 12; color: win.ink }
    Rectangle {
      width: 40; height: 20; radius: 10
      color: tg.on ? s.primary : "transparent"
      border.width: tg.on ? 0 : 1; border.color: win.sub
      Rectangle {
        width: tgma.pressed ? 16 : 12; height: 12; radius: 6
        anchors.verticalCenter: parent.verticalCenter
        x: tg.on ? parent.width - width - 4 : 4
        color: tg.on ? s.colOnPrimary : win.sub
        Behavior on x { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
      }
      MouseArea { id: tgma; anchors.fill: parent; onClicked: { tg.on = !tg.on; tg.toggled() } }
    }
  }
  component Slider: Item {
    id: sl
    property real value: 0
    signal moved(real v)
    width: 220; height: 24
    Rectangle { anchors.verticalCenter: parent.verticalCenter; width: parent.width; height: 4; radius: 2; color: win.dark ? Qt.rgba(1, 1, 1, 0.3) : Qt.rgba(0, 0, 0, 0.35) }
    Rectangle { anchors.verticalCenter: parent.verticalCenter; width: parent.width * Math.max(0, Math.min(1, sl.value)); height: 4; radius: 2; color: s.primary }
    Rectangle {
      x: parent.width * Math.max(0, Math.min(1, sl.value)) - 10; anchors.verticalCenter: parent.verticalCenter
      width: 20; height: 20; radius: 10; color: win.dark ? "#454545" : "#ffffff"; border.width: 1; border.color: win.line
      Rectangle { anchors.centerIn: parent; width: 10; height: 10; radius: 5; color: s.primary }
    }
    MouseArea {
      anchors.fill: parent
      onPressed: function(m) { sl.moved(Math.max(0, Math.min(1, m.x / width))) }
      onPositionChanged: function(m) { if (pressed) sl.moved(Math.max(0, Math.min(1, m.x / width))) }
    }
  }
  component Button2: Rectangle {
    id: b2
    property string label: ""
    signal clicked()
    width: b2t.implicitWidth + 24; height: 30; radius: 4
    color: b2ma.containsMouse ? win.cardHover : (win.dark ? "#373737" : "#fdfdfd")
    border.width: 1; border.color: win.line
    Text { id: b2t; anchors.centerIn: parent; text: b2.label; font.family: win.font; font.pixelSize: 12; color: win.ink }
    MouseArea { id: b2ma; anchors.fill: parent; hoverEnabled: true; onClicked: b2.clicked() }
  }
  component Expander: Rectangle {
    id: ex
    property string icon: ""
    property string title: ""
    property var rows: []
    property string copyText: ""
    property bool logo: false
    property bool open: true
    width: parent ? parent.width : 0
    height: 60 + (open ? exCol.implicitHeight + 16 : 0)
    radius: 6; color: win.card; border.width: 1; border.color: win.line
    clip: true
    Behavior on height { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
    MouseArea { width: parent.width; height: 60; onClicked: ex.open = !ex.open }
    MIcon { visible: !ex.logo; x: 20; y: 20; icon: ex.icon; size: 20; color: win.ink }
    WinLogo { visible: ex.logo; x: 21; y: 21; size: 18 }
    Text { x: 58; y: 20; text: ex.title; font.family: win.font; font.pixelSize: 14; font.weight: Font.DemiBold; color: win.ink }
    Rectangle {
      anchors.right: parent.right; anchors.rightMargin: 52; y: 14
      width: 80; height: 32; radius: 4; color: cpma.containsMouse ? win.cardHover : (win.dark ? "#373737" : "#fdfdfd"); border.width: 1; border.color: win.line
      Text { id: cpTxt; anchors.centerIn: parent; text: "Copier"; font.family: win.font; font.pixelSize: 12; color: win.ink }
      MouseArea { id: cpma; anchors.fill: parent; hoverEnabled: true; onClicked: { Quickshell.execDetached(["wl-copy", ex.copyText]); cpTxt.text = "Copié" } }
    }
    MIcon { anchors.right: parent.right; anchors.rightMargin: 18; y: 20; icon: ex.open ? "keyboard_arrow_up" : "keyboard_arrow_down"; size: 18; color: win.ink }
    Column {
      id: exCol
      x: 58; y: 64; width: parent.width - 80; spacing: 8
      Repeater {
        model: ex.rows
        delegate: Row {
          required property var modelData
          width: exCol.width
          Text { width: 220; text: modelData[0]; font.family: win.font; font.pixelSize: 12; color: win.sub }
          Text { width: parent.width - 220; wrapMode: Text.Wrap; text: modelData[1]; font.family: win.font; font.pixelSize: 12; color: win.ink }
        }
      }
    }
  }
  component Avatar: Item {
    id: av
    property real size: 30
    width: size; height: size
    ClippingRectangle {
      anchors.fill: parent; radius: av.size / 2
      color: s.primaryContainer
      Text { anchors.centerIn: parent; text: s.user.charAt(0).toUpperCase(); font.family: win.font; font.pixelSize: av.size * 0.45; font.weight: Font.DemiBold; color: s.colOnPrimaryContainer }
      Image { anchors.fill: parent; source: "file://" + Quickshell.env("HOME") + "/.face"; fillMode: Image.PreserveAspectCrop; asynchronous: true; visible: status === Image.Ready }
    }
  }
}
