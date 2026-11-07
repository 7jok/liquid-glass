import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Widgets
import "T.js" as T

// Menu principal des bureaux de distributions.
//   gnome    : vue d'ensemble plein écran, recherche et grille d'applications, dash en bas
//   cinnamon : barre de favoris à gauche, catégories, applications (menu de Mint)
//   xfce     : recherche, catégories d'outils numérotées puis applications (menu de Kali)
//   plasma   : Kickoff, en-tête utilisateur, catégories, pied Veille / Redémarrer / Éteindre
PanelWindow {
  id: win
  property var service: null
  readonly property var s: service
  readonly property var d: s.distro
  readonly property string lay: d.layout
  readonly property bool gnome: lay === "gnome"
  readonly property bool kali: s.style === "kali"

  color: "transparent"
  anchors { top: true; bottom: true; left: true; right: true }
  exclusionMode: ExclusionMode.Ignore
  WlrLayershell.layer: WlrLayer.Overlay
  WlrLayershell.namespace: "liquid-glass-linux-launcher"
  WlrLayershell.keyboardFocus: s.kbd(true)

  readonly property string font: s.sansFont
  readonly property color ink: gnome ? "#ffffff" : s.colOnSurface
  readonly property color sub: gnome ? "#c8c8c8" : s.colOnSurfaceVariant
  property string query: ""
  property string cat: kali ? "tools:0" : "all"
  property bool revealed: false
  Component.onCompleted: { revealed = true; input.forceActiveFocus(); if (hasTools) probe.running = true }

  // Catégories XDG → rubrique du menu.
  readonly property var cats: [
    ["all", T.t("Toutes les applications"), "apps", []],
    ["net", "Internet", "language", ["Network", "WebBrowser", "Email", "Chat"]],
    ["office", T.t("Bureautique"), "description", ["Office"]],
    ["dev", T.t("Développement"), "code", ["Development"]],
    ["media", T.t("Son et vidéo"), "movie", ["AudioVideo", "Audio", "Video"]],
    ["gfx", T.t("Graphisme"), "palette", ["Graphics"]],
    ["game", T.t("Jeux"), "sports_esports", ["Game"]],
    ["sys", T.t("Système"), "settings", ["System", "Settings"]],
    ["util", T.t("Accessoires"), "handyman", ["Utility"]]
  ]
  // Outils de Kali, rangés comme son menu. [nom, paquet Arch, commande]
  readonly property var toolDefs: ({ kali: kaliTools, debian: debianTools, fedora: fedoraTools, mint: mintTools, arch: archTools })
  readonly property var tools: toolDefs[s.style] || []
  readonly property bool hasTools: tools.length > 0
  readonly property var debianTools: [
    ["Bureautique", "description", [["LibreOffice", "libreoffice-fresh", "libreoffice"], ["Évince", "evince", "evince"], ["Éditeur de texte", "gnome-text-editor", "gnome-text-editor"]]],
    ["Système", "settings", [["Moniteur système", "gnome-system-monitor", "gnome-system-monitor"], ["Disques", "gnome-disk-utility", "gnome-disks"], ["Calculatrice", "gnome-calculator", "gnome-calculator"]]],
    ["Multimédia", "movie", [["VLC", "vlc", "vlc"], ["GIMP", "gimp", "gimp"]]]
  ]
  readonly property var fedoraTools: [
    ["Conteneurs", "deployed_code", [["Podman", "podman", "podman --help | less"], ["Distrobox", "distrobox", "distrobox --help | less"]]],
    ["Virtualisation", "computer", [["GNOME Boxes", "gnome-boxes", "gnome-boxes"], ["Cockpit", "cockpit", "cockpit-bridge --help | less"]]],
    ["Applications", "apps", [["Flatpak", "flatpak", "flatpak --help | less"], ["Moniteur système", "gnome-system-monitor", "gnome-system-monitor"]]]
  ]
  readonly property var mintTools: [
    ["Sauvegarde", "history", [["Timeshift", "timeshift", "timeshift-launcher"]]],
    ["Sécurité", "shield", [["Pare-feu Gufw", "gufw", "gufw"]]],
    ["Multimédia", "movie", [["Celluloid", "celluloid", "celluloid"], ["Transmission", "transmission-gtk", "transmission-gtk"]]]
  ]
  readonly property var archTools: [
    ["Pacman", "inventory_2", [["pacman-contrib", "pacman-contrib", "man paccache"], ["Reflector", "reflector", "reflector --help | less"]]],
    ["Terminal", "terminal", [["Neovim", "neovim", "nvim"], ["btop", "btop", "btop"], ["tmux", "tmux", "tmux"]]],
    ["Installation", "construction", [["archinstall", "archinstall", "archinstall --help | less"], ["base-devel", "base-devel", "pacman -Qg base-devel | less"]]]
  ]
  readonly property var kaliTools: [
    ["01 - Collecte d'informations", "travel_explore", [["Nmap", "nmap", "nmap --help | less"]]],
    ["02 - Analyse de vulnérabilités", "bug_report", [["Nikto", "nikto", "nikto -Help | less"]]],
    ["03 - Applications web", "public", [["sqlmap", "sqlmap", "sqlmap -h | less"], ["Gobuster", "gobuster", "gobuster --help | less"]]],
    ["04 - Mots de passe", "key", [["John the Ripper", "john", "john | less"], ["Hashcat", "hashcat", "hashcat --help | less"], ["Hydra", "hydra", "hydra -h | less"]]],
    ["05 - Sans fil", "wifi_tethering", [["Aircrack-ng", "aircrack-ng", "aircrack-ng --help | less"]]],
    ["06 - Exploitation", "terminal", [["Metasploit", "metasploit", "msfconsole"]]],
    ["07 - Écoute réseau", "lan", [["Wireshark", "wireshark-qt", "wireshark"]]]
  ]
  property var installed: ({})
  Process {
    id: probe
    command: ["pacman", "-Qq"]
    stdout: StdioCollector {
      onStreamFinished: {
        var o = {}, l = text.split("\n")
        for (var i = 0; i < l.length; i++) o[l[i]] = true
        win.installed = o
      }
    }
  }
  function runTool(t) {
    var cmd = win.installed[t[1]] ? t[2] : "echo 'Installation de " + t[0] + "' ; sudo pacman -S --needed " + t[1] + " ; echo ; read -p 'Entrée pour fermer…'"
    Quickshell.execDetached(["xdg-terminal-exec", "sh", "-c", cmd])
    s.closeAll()
  }
  function installAll() {
    var p = []
    for (var i = 0; i < tools.length; i++) for (var j = 0; j < tools[i][2].length; j++) p.push(tools[i][2][j][1])
    Quickshell.execDetached(["xdg-terminal-exec", "sh", "-c", "sudo pacman -S --needed " + p.join(" ") + " ; read -p 'Entrée pour fermer…'"])
    s.closeAll()
  }

  function inCat(e, c) {
    var want = null
    for (var i = 0; i < cats.length; i++) if (cats[i][0] === c) want = cats[i][3]
    if (!want || want.length === 0) return true
    var have = e.categories || []
    for (var k = 0; k < have.length; k++) if (want.indexOf(String(have[k])) >= 0) return true
    return false
  }
  readonly property bool toolView: cat.indexOf("tools:") === 0 && query === ""
  readonly property var results: {
    var all = s.apps(query), out = []
    if (query !== "" || gnome) return all
    if (toolView) return []
    for (var i = 0; i < all.length; i++) if (inCat(all[i], cat)) out.push(all[i])
    return out
  }
  function openFirst() { if (results.length) s.launch(results[0]) }

  MouseArea { anchors.fill: parent; onClicked: s.closeAll() }

  // ================================================================ GNOME
  Rectangle {
    visible: win.gnome
    anchors.fill: parent
    color: "#000000"
    opacity: win.revealed ? 0.72 : 0
    Behavior on opacity { NumberAnimation { duration: 220 } }
  }

  Item {
    id: panel
    readonly property int menuW: win.lay === "plasma" ? 620 : (win.hasTools ? 640 : 600)
    readonly property int menuH: Math.min(win.height - 80, 560)
    x: win.gnome ? 0 : (win.lay === "plasma" ? 8 : 4)
    y: win.gnome ? 0 : (win.d.bottom ? win.height - height - win.d.barH - (win.lay === "plasma" ? 12 : 4) : win.d.barH + (win.s.testing ? 34 : 4))
    width: win.gnome ? win.width : menuW
    height: win.gnome ? win.height : menuH
    opacity: win.revealed ? 1 : 0
    Behavior on opacity { NumberAnimation { duration: 140 } }
    transform: Translate { y: win.revealed ? 0 : (win.d.bottom ? 16 : -16); Behavior on y { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } } }

    Rectangle {
      visible: !win.gnome
      anchors.fill: parent
      radius: win.lay === "plasma" ? 10 : 4
      color: win.s.alpha(win.s.surfaceMid, 0.98)
      border.width: 1; border.color: win.s.alpha(win.ink, 0.16)
      MouseArea { anchors.fill: parent }
    }

    // ------------------------------------------------ en-tête Plasma
    Row {
      id: head
      visible: win.lay === "plasma"
      x: 14; y: 12; spacing: 10
      ClippingRectangle {
        width: 36; height: 36; radius: 18; color: win.s.primary
        Image { anchors.fill: parent; source: "file://" + Quickshell.env("HOME") + "/.face"; fillMode: Image.PreserveAspectCrop; asynchronous: true; sourceSize.width: 80 }
      }
      Text { anchors.verticalCenter: parent.verticalCenter; text: win.s.user; font.family: win.font; font.pixelSize: 15; font.weight: Font.DemiBold; color: win.ink }
    }

    // ------------------------------------------------ recherche
    Rectangle {
      id: search
      readonly property int w: win.gnome ? 360 : (win.lay === "plasma" ? panel.width - 170 : panel.width - (win.lay === "cinnamon" ? 72 : 24))
      x: win.gnome ? (panel.width - w) / 2 : (win.lay === "plasma" ? 156 : (win.lay === "cinnamon" ? 60 : 12))
      y: win.gnome ? 64 : (win.lay === "plasma" ? 14 : 12)
      width: w; height: win.gnome ? 38 : 32
      radius: win.gnome ? 19 : 4
      color: win.gnome ? win.s.alpha("#ffffff", 0.14) : win.s.alpha(win.ink, 0.07)
      border.width: input.activeFocus && !win.gnome ? 1 : 0
      border.color: win.s.primary
      MIcon { x: 10; anchors.verticalCenter: parent.verticalCenter; icon: "search"; size: 18; color: win.sub }
      TextInput {
        id: input
        x: 36; width: parent.width - 46; anchors.verticalCenter: parent.verticalCenter
        font.family: win.font; font.pixelSize: 14; color: win.ink
        selectionColor: win.s.primary; clip: true
        onTextChanged: win.query = text
        Keys.onEscapePressed: win.s.closeAll()
        Keys.onReturnPressed: win.openFirst()
        Text {
          visible: input.text === ""; anchors.verticalCenter: parent.verticalCenter
          text: win.gnome ? T.t("Rechercher des applications") : T.t("Rechercher…")
          font.family: win.font; font.pixelSize: 14; color: win.sub
        }
      }
    }

    // ------------------------------------------------ favoris de Mint
    Column {
      visible: win.lay === "cinnamon"
      x: 8; y: 12; spacing: 4
      Repeater {
        model: win.lay === "cinnamon" ? win.s.pinned(6) : []
        delegate: Rectangle {
          id: fav
          required property var modelData
          width: 40; height: 40; radius: 4
          color: fvm.containsMouse ? win.s.alpha(win.s.primary, 0.3) : "transparent"
          IconImage { anchors.centerIn: parent; width: 26; height: 26; source: win.s.appIcon(fav.modelData); asynchronous: true }
          MouseArea { id: fvm; anchors.fill: parent; hoverEnabled: true; onClicked: win.s.launch(fav.modelData) }
        }
      }
    }
    Column {
      visible: win.lay === "cinnamon"
      x: 8; anchors.bottom: parent.bottom; anchors.bottomMargin: 10; spacing: 4
      Repeater {
        model: [["lock", "lock"], ["logout", "logout"], ["poweroff", "power_settings_new"]]
        delegate: Rectangle {
          required property var modelData
          width: 40; height: 40; radius: 4
          color: pwm.containsMouse ? win.s.alpha(win.s.primary, 0.3) : "transparent"
          MIcon { anchors.centerIn: parent; icon: modelData[1]; size: 22; color: win.ink }
          MouseArea { id: pwm; anchors.fill: parent; hoverEnabled: true; onClicked: win.s.power(modelData[0]) }
        }
      }
    }

    // ------------------------------------------------ catégories
    Flickable {
      id: catList
      visible: !win.gnome
      x: win.lay === "cinnamon" ? 56 : 8
      y: 56
      width: win.hasTools ? 262 : 196
      height: parent.height - y - (win.lay === "plasma" ? 50 : 10)
      contentHeight: catCol.height
      clip: true
      Column {
        id: catCol
        width: parent.width
        spacing: 1
        Repeater {
          model: win.tools
          delegate: CatRow {
            required property var modelData
            required property int index
            key: "tools:" + index; label: modelData[0]; icon: modelData[1]
          }
        }
        Rectangle { visible: win.hasTools; width: parent.width; height: 1; color: win.s.alpha(win.ink, 0.14) }
        Repeater {
          model: win.cats
          delegate: CatRow {
            required property var modelData
            key: modelData[0]; label: modelData[1]; icon: modelData[2]
          }
        }
      }
    }

    // ------------------------------------------------ applications (liste)
    ListView {
      id: list
      visible: !win.gnome && !win.toolView
      x: catList.x + catList.width + 8
      y: 56
      width: parent.width - x - 8
      height: catList.height
      clip: true
      spacing: 1
      model: win.gnome || win.toolView ? [] : win.results
      delegate: Rectangle {
        id: row
        required property var modelData
        width: list.width; height: 36; radius: 4
        color: lma.containsMouse ? win.s.alpha(win.s.primary, 0.28) : "transparent"
        IconImage { x: 8; anchors.verticalCenter: parent.verticalCenter; width: 24; height: 24; source: win.s.appIcon(row.modelData); asynchronous: true }
        Text {
          x: 42; width: parent.width - 50; anchors.verticalCenter: parent.verticalCenter; elide: Text.ElideRight
          text: win.s.appName(row.modelData); font.family: win.font; font.pixelSize: 13; color: win.ink
        }
        MouseArea { id: lma; anchors.fill: parent; hoverEnabled: true; onClicked: win.s.launch(row.modelData) }
      }
    }

    // ------------------------------------------------ outils de Kali
    Column {
      visible: win.toolView
      x: catList.x + catList.width + 8
      y: 56
      width: parent.width - x - 8
      spacing: 1
      Repeater {
        model: win.toolView ? win.tools[Number(win.cat.split(":")[1])][2] : []
        delegate: Rectangle {
          id: tool
          required property var modelData
          readonly property bool ok: !!win.installed[modelData[1]]
          width: parent.width; height: 38; radius: 4
          color: tma.containsMouse ? win.s.alpha(win.s.primary, 0.28) : "transparent"
          MIcon { x: 8; anchors.verticalCenter: parent.verticalCenter; icon: "terminal"; size: 20; color: tool.ok ? win.s.primary : win.sub }
          Text {
            x: 38; anchors.verticalCenter: parent.verticalCenter
            text: tool.modelData[0]; font.family: win.font; font.pixelSize: 13; color: win.ink
          }
          Text {
            visible: !tool.ok
            anchors.right: parent.right; anchors.rightMargin: 8; anchors.verticalCenter: parent.verticalCenter
            text: T.t("à installer"); font.family: win.font; font.pixelSize: 11; color: win.s.primary
          }
          MouseArea { id: tma; anchors.fill: parent; hoverEnabled: true; onClicked: win.runTool(tool.modelData) }
        }
      }
      Item { width: 1; height: 8 }
      Rectangle {
        width: parent.width; height: 34; radius: 4
        color: iam.containsMouse ? win.s.primary : win.s.alpha(win.s.primary, 0.2)
        Text {
          anchors.centerIn: parent; text: T.t("Installer tous les outils")
          font.family: win.font; font.pixelSize: 12; font.weight: Font.DemiBold; color: iam.containsMouse ? "white" : win.ink
        }
        MouseArea { id: iam; anchors.fill: parent; hoverEnabled: true; onClicked: win.installAll() }
      }
    }

    // ------------------------------------------------ pied Plasma
    Row {
      visible: win.lay === "plasma"
      anchors.right: parent.right; anchors.rightMargin: 12
      anchors.bottom: parent.bottom; anchors.bottomMargin: 10
      spacing: 4
      Repeater {
        model: [["suspend", "bedtime", "Veille"], ["reboot", "restart_alt", T.t("Redémarrer")], ["poweroff", "power_settings_new", "Éteindre"]]
        delegate: Rectangle {
          required property var modelData
          width: ft.implicitWidth + 16; height: 30; radius: 4
          color: fma.containsMouse ? win.s.alpha(win.s.primary, 0.28) : "transparent"
          Row {
            id: ft
            anchors.centerIn: parent; spacing: 5
            MIcon { anchors.verticalCenter: parent.verticalCenter; icon: modelData[1]; size: 16; color: win.ink }
            Text { anchors.verticalCenter: parent.verticalCenter; text: modelData[2]; font.family: win.font; font.pixelSize: 12; color: win.ink }
          }
          MouseArea { id: fma; anchors.fill: parent; hoverEnabled: true; onClicked: win.s.power(modelData[0]) }
        }
      }
    }

    // ------------------------------------------------ grille GNOME
    GridView {
      id: grid
      visible: win.gnome
      readonly property int colsN: Math.min(7, Math.floor((panel.width - 120) / 132))
      anchors.horizontalCenter: parent.horizontalCenter
      y: 128
      width: colsN * 132
      height: parent.height - y - 110
      cellWidth: 132; cellHeight: 124
      clip: true
      model: win.gnome ? win.results : []
      delegate: Item {
        id: cell
        required property var modelData
        width: 132; height: 124
        Rectangle {
          anchors.fill: parent; anchors.margins: 6; radius: 14
          color: gma.containsMouse ? win.s.alpha("#ffffff", 0.14) : "transparent"
        }
        IconImage { anchors.horizontalCenter: parent.horizontalCenter; y: 18; width: 60; height: 60; source: win.s.appIcon(cell.modelData); asynchronous: true }
        Text {
          anchors.horizontalCenter: parent.horizontalCenter; y: 86; width: parent.width - 16
          horizontalAlignment: Text.AlignHCenter; elide: Text.ElideRight
          text: win.s.appName(cell.modelData); font.family: win.font; font.pixelSize: 13; color: "#ffffff"
        }
        MouseArea { id: gma; anchors.fill: parent; hoverEnabled: true; onClicked: win.s.launch(cell.modelData) }
      }
    }

    // ------------------------------------------------ dash GNOME
    Rectangle {
      visible: win.gnome
      anchors.horizontalCenter: parent.horizontalCenter
      anchors.bottom: parent.bottom; anchors.bottomMargin: 16
      width: dash.implicitWidth + 20; height: 72; radius: 24
      color: win.s.alpha("#ffffff", 0.14)
      Row {
        id: dash
        anchors.centerIn: parent; spacing: 6
        Repeater {
          model: win.gnome ? win.s.pinned(9) : []
          delegate: Rectangle {
            id: dk
            required property var modelData
            width: 56; height: 56; radius: 14
            color: dma.containsMouse ? win.s.alpha("#ffffff", 0.18) : "transparent"
            IconImage { anchors.centerIn: parent; width: 44; height: 44; source: win.s.appIcon(dk.modelData); asynchronous: true }
            MouseArea { id: dma; anchors.fill: parent; hoverEnabled: true; onClicked: win.s.launch(dk.modelData) }
          }
        }
      }
    }
  }

  component CatRow: Rectangle {
    id: cr
    property string key: ""
    property string label: ""
    property string icon: ""
    readonly property bool on: win.cat === key
    width: catCol.width; height: 34; radius: 4
    color: on ? win.s.alpha(win.s.primary, 0.32) : (cma.containsMouse ? win.s.alpha(win.ink, 0.08) : "transparent")
    MIcon { x: 8; anchors.verticalCenter: parent.verticalCenter; icon: cr.icon; size: 18; color: cr.on ? win.s.primary : win.sub }
    Text {
      x: 36; width: parent.width - 42; anchors.verticalCenter: parent.verticalCenter; elide: Text.ElideRight
      text: cr.label; font.family: win.font; font.pixelSize: 13; color: win.ink
    }
    // Comme Cinnamon : survoler une catégorie l'ouvre.
    MouseArea { id: cma; anchors.fill: parent; hoverEnabled: true; onEntered: win.cat = cr.key; onClicked: win.cat = cr.key }
  }
}
