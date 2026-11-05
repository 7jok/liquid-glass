import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.Commons
import qs.Commons as Commons
import qs.Ui

// ============================================================================
// Liquid Glass — Réglages (fenêtre de verre façon « Réglages Système »).
// Lit ~/.config/liquid-glass/config.json (relu à chaud) et écrit chaque
// changement via `liquid-glass set section.clé valeur`, qui l'applique :
//   appearance.mode → thème ; glass.* → Hyprland ; dock.* → shell.json ;
//   spotify/lyrics/visualizer → service Spotify ; le reste → `liquid-glass apply`.
// Les curseurs n'écrivent qu'au relâchement (pas de rafale de rechargements).
// Ouverture : menu  → Réglages, Spotlight, centre de contrôle, ou
//   omarchy-shell liquid-glass.settings toggle
// ============================================================================
Item {
  id: root

  property var shell: null
  property var manifest: null
  property bool opened: false
  property int page: 0

  readonly property string uiFont: "Inter"
  readonly property string iconFont: Style.font.family
  readonly property color fg: Commons.Color.menu.text
  readonly property color accent: Commons.Color.accent
  readonly property bool dark: Commons.Color.background.hslLightness < 0.5
  function g(cp) { return String.fromCodePoint(cp) }

  // ------------------------------------------------------------- config
  property var cfg: ({})
  FileView {
    path: Quickshell.env("HOME") + "/.config/liquid-glass/config.json"
    watchChanges: true
    onFileChanged: reload()
    onLoaded: { try { root.cfg = JSON.parse(text()) } catch (e) {} }
  }
  function val(path, def) {
    var parts = path.split("."), v = cfg
    for (var i = 0; i < parts.length; i++) { if (v === undefined || v === null) return def; v = v[parts[i]] }
    return v === undefined || v === null ? def : v
  }

  // Écritures sérialisées : une seule commande à la fois, la dernière valeur gagne.
  property var queue: []
  function set(key, value) {
    var q = queue.filter(function(e) { return e[0] !== key })
    q.push([key, String(value)])
    queue = q
    // Mise à jour optimiste de l'affichage.
    var parts = key.split("."), c = JSON.parse(JSON.stringify(cfg))
    if (!c[parts[0]]) c[parts[0]] = {}
    c[parts[0]][parts[1]] = value
    cfg = c
    pump()
  }
  function pump() {
    if (writer.running || queue.length === 0) return
    var e = queue[0]
    queue = queue.slice(1)
    busy = true
    writer.command = ["liquid-glass", "set", e[0], e[1]]
    writer.running = true
  }
  property bool busy: false
  Process {
    id: writer
    onExited: { root.busy = false; root.pump() }
  }

  readonly property var pages: [
    [0xF03D8, "Apparence"], [0xF0F5A, "Verre"], [0xF0DE6, "Dock"],
    [0xF04C7, "Spotify"], [0xF0387, "Paroles"], [0xF030C, "Clavier"], [0xF02FD, "À propos"]
  ]

  // ------------------------------------------------------------- cycle de vie
  function open(payloadJson) {
    opened = true
    try { var p = JSON.parse(payloadJson || "{}"); if (p.page !== undefined) page = p.page } catch (e) {}
  }
  function close() { opened = false }
  function dismiss() {
    opened = false
    if (shell && typeof shell.hide === "function") shell.hide((manifest && manifest.id) || "liquid-glass.settings")
  }

  ShellIpc {
    target: "liquid-glass.settings"
    function toggle(): void { if (root.opened) root.dismiss(); else if (root.shell) root.shell.summon((root.manifest && root.manifest.id) || "liquid-glass.settings", "") }
    function open(): void { if (root.shell) root.shell.summon((root.manifest && root.manifest.id) || "liquid-glass.settings", "") }
  }

  OverlayWindow {
    id: win
    shown: root.opened
    WlrLayershell.namespace: "liquid-glass-settings"

    Item {
      id: keys
      anchors.fill: parent
      focus: true
      Keys.onPressed: function(ev) {
        if (ev.key === Qt.Key_Escape) root.dismiss()
        else if (ev.key === Qt.Key_Down || ev.key === Qt.Key_Tab) root.page = (root.page + 1) % root.pages.length
        else if (ev.key === Qt.Key_Up || ev.key === Qt.Key_Backtab) root.page = (root.page - 1 + root.pages.length) % root.pages.length
        else return
        ev.accepted = true
      }
    }
    Rectangle { anchors.fill: parent; color: Qt.rgba(0, 0, 0, 0.12) }
    MouseArea { anchors.fill: parent; onClicked: root.dismiss() }

    BorderSurface {
      id: card
      anchors.centerIn: parent
      width: Math.min(parent.width - 40, Style.space(780))
      height: Math.min(parent.height - 40, Style.space(540))
      radius: Style.space(22)
      color: Commons.Color.menu.background
      borderSpec: Border.surfaceSpec("menu", "border", Commons.Color.menu.border, 1)
      scale: win.contentRevealed ? 1 : 0.95
      Behavior on scale { SpringAnimation { spring: 4; damping: 0.42; epsilon: 0.002 } }
      MouseArea { anchors.fill: parent }

      // ---- Barre latérale
      Rectangle {
        id: sidebar
        width: Style.space(200)
        height: parent.height
        radius: card.radius
        color: Qt.rgba(root.fg.r, root.fg.g, root.fg.b, 0.04)
        Rectangle { anchors.right: parent.right; width: 1; height: parent.height; color: root.fg; opacity: 0.08 }

        Row {
          x: Style.space(18); y: Style.space(16)
          spacing: Style.space(8)
          Repeater {
            model: ["#ff5f57", "#febc2e", "#28c840"]
            delegate: Rectangle {
              required property var modelData
              required property int index
              width: Style.space(12); height: width; radius: width / 2
              color: modelData
              border.width: 1; border.color: Qt.rgba(0, 0, 0, 0.12)
              MouseArea { anchors.fill: parent; anchors.margins: -3; cursorShape: Qt.PointingHandCursor; onClicked: if (index === 0) root.dismiss() }
            }
          }
        }

        Column {
          x: Style.space(10)
          y: Style.space(50)
          width: parent.width - Style.space(20)
          spacing: Style.space(2)
          Repeater {
            model: root.pages
            delegate: Rectangle {
              id: navItem
              required property var modelData
              required property int index
              readonly property bool current: root.page === index
              width: parent.width
              height: Style.space(32)
              radius: Style.space(8)
              color: current ? root.accent : (navMouse.containsMouse ? Qt.rgba(root.fg.r, root.fg.g, root.fg.b, 0.07) : "transparent")
              Rectangle {
                id: navIcon
                x: Style.space(8)
                anchors.verticalCenter: parent.verticalCenter
                width: Style.space(22); height: width; radius: Style.space(6)
                color: navItem.current ? Qt.rgba(1, 1, 1, 0.22) : root.accent
                Text {
                  anchors.centerIn: parent
                  textFormat: Text.PlainText
                  text: root.g(navItem.modelData[0])
                  font.family: root.iconFont; font.pixelSize: Style.space(13)
                  color: "white"
                }
              }
              Text {
                anchors.left: navIcon.right; anchors.leftMargin: Style.space(10)
                anchors.verticalCenter: parent.verticalCenter
                textFormat: Text.PlainText
                text: navItem.modelData[1]
                font.family: root.uiFont; font.pixelSize: Style.space(13); font.weight: Font.Medium
                color: navItem.current ? "white" : root.fg
              }
              MouseArea { id: navMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.page = navItem.index }
            }
          }
        }

        Text {
          anchors.bottom: parent.bottom; anchors.bottomMargin: Style.space(14)
          x: Style.space(18)
          textFormat: Text.PlainText
          text: root.busy ? "Application…" : "Enregistré automatiquement"
          font.family: root.uiFont; font.pixelSize: Style.space(11)
          color: root.fg; opacity: 0.45
        }
      }

      // ---- Contenu
      Flickable {
        id: content
        anchors.left: sidebar.right
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.margins: Style.space(22)
        contentHeight: pageLoader.item ? pageLoader.item.implicitHeight : 0
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        Loader {
          id: pageLoader
          width: content.width
          sourceComponent: [pAppearance, pGlass, pDock, pSpotify, pLyrics, pKeys, pAbout][root.page]
        }
      }
    }
  }

  Connections {
    target: win
    function onContentRevealedChanged() { if (win.contentRevealed) keys.forceActiveFocus() }
  }

  // =============================================================== pages
  Component {
    id: pAppearance
    Column {
      spacing: Style.space(14)
      PageTitle { text: "Apparence" }
      Group {
        Row_ {
          label: "Mode"
          Seg {
            options: [["light", "Clair"], ["dark", "Sombre"], ["auto", "Auto"]]
            value: root.val("appearance.mode", "light")
            onPicked: function(v) { root.set("appearance.mode", v) }
          }
        }
        Row_ {
          label: "Passage au clair"
          visible: root.val("appearance.mode", "light") === "auto"
          Stepper { value: root.val("appearance.auto_light_at", "07:30"); onChanged_: function(v) { root.set("appearance.auto_light_at", v) } }
        }
        Row_ {
          label: "Passage au sombre"
          visible: root.val("appearance.mode", "light") === "auto"
          Stepper { value: root.val("appearance.auto_dark_at", "19:30"); onChanged_: function(v) { root.set("appearance.auto_dark_at", v) } }
        }
      }
      Group {
        Row_ {
          label: "Police de l'interface"
          Seg {
            options: [["Inter", "Inter"], ["Geist", "Geist"], ["sans-serif", "Système"]]
            value: root.val("appearance.font_ui", "Inter")
            onPicked: function(v) { root.set("appearance.font_ui", v) }
          }
        }
      }
      Hint { text: "Le mode Auto bascule à heure fixe (vérifié chaque minute par le shell). ⌘⇧L bascule à la main." }
    }
  }

  Component {
    id: pGlass
    Column {
      spacing: Style.space(14)
      PageTitle { text: "Verre" }
      Group {
        SliderRow { label: "Opacité du verre"; key: "glass.opacity"; from: 0.5; to: 1.4; step: 0.05; def: 1.0; fmt: function(v) { return Math.round(v * 100) + " %" } }
        SliderRow { label: "Intensité du flou"; key: "glass.blur_size"; from: 2; to: 14; step: 1; def: 7 }
        SliderRow { label: "Passes de flou"; key: "glass.blur_passes"; from: 1; to: 4; step: 1; def: 3 }
        SliderRow { label: "Arrondi des fenêtres"; key: "glass.rounding"; from: 0; to: 28; step: 1; def: 16; fmt: function(v) { return v + " px" } }
      }
      Group {
        SliderRow { label: "Fenêtre active"; key: "glass.window_opacity_active"; from: 0.7; to: 1.0; step: 0.01; def: 0.96; fmt: function(v) { return Math.round(v * 100) + " %" } }
        SliderRow { label: "Fenêtres inactives"; key: "glass.window_opacity_inactive"; from: 0.6; to: 1.0; step: 0.01; def: 0.9; fmt: function(v) { return Math.round(v * 100) + " %" } }
        SliderRow { label: "Terminal (clair)"; key: "terminal.opacity_light"; from: 0.5; to: 1.0; step: 0.02; def: 0.8; fmt: function(v) { return Math.round(v * 100) + " %" } }
        SliderRow { label: "Terminal (sombre)"; key: "terminal.opacity_dark"; from: 0.5; to: 1.0; step: 0.02; def: 0.76; fmt: function(v) { return Math.round(v * 100) + " %" } }
      }
      Group {
        SliderRow { label: "Espace entre fenêtres"; key: "glass.gaps_in"; from: 0; to: 20; step: 1; def: 5; fmt: function(v) { return v + " px" } }
        SliderRow { label: "Marge d'écran"; key: "glass.gaps_out"; from: 0; to: 40; step: 1; def: 10; fmt: function(v) { return v + " px" } }
        ToggleRow { label: "Animations à ressort"; key: "glass.animations"; def: true }
      }
      Hint { text: "Opacité du verre et terminal : le thème est régénéré (≈1 s). Le reste s'applique instantanément." }
    }
  }

  Component {
    id: pDock
    Column {
      spacing: Style.space(14)
      PageTitle { text: "Dock" }
      Group {
        SliderRow { label: "Taille des icônes"; key: "dock.icon_size"; from: 32; to: 72; step: 2; def: 42; fmt: function(v) { return v + " px" } }
        SliderRow { label: "Agrandissement"; key: "dock.magnification"; from: 1.0; to: 2.2; step: 0.1; def: 1.6; fmt: function(v) { return v <= 1.0 ? "Désactivé" : "×" + v.toFixed(1) } }
      }
      Group {
        ToggleRow { label: "Toujours visible"; key: "dock.always_visible"; def: true }
        ToggleRow { label: "Masquer automatiquement"; key: "dock.autohide"; def: false }
      }
    }
  }

  Component {
    id: pSpotify
    Column {
      spacing: Style.space(14)
      PageTitle { text: "Spotify" }
      Group {
        Row_ {
          label: "Fond d'écran"
          Seg {
            options: [["cover", "Pochette"], ["blur", "Flou"], ["gradient", "Dégradé"], ["off", "Thème"]]
            value: root.val("spotify.wallpaper", "cover")
            onPicked: function(v) { root.set("spotify.wallpaper", v) }
          }
        }
        SliderRow { label: "Retour au fond après pause"; key: "spotify.restore_after_minutes"; from: 0; to: 30; step: 1; def: 5; fmt: function(v) { return v === 0 ? "Jamais" : v + " min" } }
        ToggleRow { label: "Couleurs de la pochette"; key: "spotify.dynamic_colors"; def: true; sub: "Accent, bordures, barre, dock et terminal" }
      }
      Group {
        ToggleRow { label: "Visualiseur audio"; key: "visualizer.enabled"; def: false; sub: "cava en bas du fond d'écran, seulement pendant la lecture" }
        SliderRow { label: "Nombre de barres"; key: "visualizer.bars"; from: 16; to: 128; step: 8; def: 64 }
      }
    }
  }

  Component {
    id: pLyrics
    Column {
      spacing: Style.space(14)
      PageTitle { text: "Paroles" }
      Group {
        ToggleRow { label: "Sur le bureau"; key: "lyrics.desktop"; def: true; sub: "Grandes paroles derrière les fenêtres, ligne en cours nette" }
        ToggleRow { label: "Widget flottant"; key: "lyrics.widget"; def: false; sub: "Carte déplaçable ; double-clic pour le karaoké" }
        ToggleRow { label: "Dans la barre"; key: "lyrics.bar"; def: true; sub: "La ligne chantée remplace le titre" }
      }
      Group {
        Row_ {
          label: "Karaoké plein écran"
          Btn { text: "Ouvrir  ⌘⌥M"; onClicked: { root.dismiss(); Util.execArgv(["omarchy-shell", "liquid-glass.spotify", "karaoke"]) } }
        }
      }
      Hint { text: "Paroles synchronisées fournies par LRCLIB (gratuit, sans compte). Mises en cache dans ~/.cache/liquid-glass." }
    }
  }

  Component {
    id: pKeys
    Column {
      spacing: Style.space(14)
      PageTitle { text: "Clavier" }
      Group {
        ToggleRow { label: "Raccourcis façon macOS"; key: "keys.macos_shortcuts"; def: true; sub: "⌘Espace, ⌘Q, ⌘Tab, ⌘↑, ⌘⇧3/4/5… Désactivé : raccourcis Omarchy d'origine" }
        Row_ {
          label: "Aide-mémoire"
          Btn { text: "Afficher  ⌘K"; onClicked: { root.dismiss(); Util.execArgv(["omarchy-shell", "liquid-glass.cheatsheet", "toggle"]) } }
        }
      }
    }
  }

  Component {
    id: pAbout
    Column {
      spacing: Style.space(14)
      PageTitle { text: "À propos" }
      Group {
        Row_ { label: "Liquid Glass"; Label_ { text: "1.0 — pour Omarchy" } }
        Row_ { label: "Configuration"; Label_ { text: "~/.config/liquid-glass/config.toml" } }
        Row_ { label: "Thème actif"; Label_ { text: root.dark ? "Liquid Glass Dark" : "Liquid Glass" } }
      }
      Group {
        Row_ {
          label: "Réappliquer tout"
          Btn { text: "Appliquer"; onClicked: Util.execArgv(["liquid-glass", "apply"]) }
        }
        Row_ {
          label: "Modifier le fichier"
          Btn { text: "Ouvrir"; onClicked: { root.dismiss(); Util.execArgv(["xdg-open", Quickshell.env("HOME") + "/.config/liquid-glass/config.toml"]) } }
        }
      }
      Hint { text: "Pour tout annuler : ~/.config-backup-<date>/restore.sh restaure l'état d'avant l'installation." }
    }
  }

  // =============================================================== composants
  component PageTitle: Text {
    textFormat: Text.PlainText
    font.family: root.uiFont; font.pixelSize: Style.space(22); font.weight: Font.Bold
    color: root.fg
    bottomPadding: Style.space(4)
  }

  component Hint: Text {
    width: parent ? parent.width : 0
    textFormat: Text.PlainText
    wrapMode: Text.WordWrap
    font.family: root.uiFont; font.pixelSize: Style.space(11.5)
    color: root.fg; opacity: 0.5
  }

  // Groupe de lignes façon macOS : fond légèrement contrasté, séparateurs fins.
  component Group: Rectangle {
    id: grp
    default property alias rows: col.data
    width: parent ? parent.width : 0
    height: col.implicitHeight
    radius: Style.space(12)
    color: Qt.rgba(root.fg.r, root.fg.g, root.fg.b, root.dark ? 0.06 : 0.045)
    border.width: 1
    border.color: Qt.rgba(root.fg.r, root.fg.g, root.fg.b, 0.07)
    Column { id: col; width: parent.width }
  }

  component Row_: Item {
    id: r
    property string label: ""
    property string sub: ""
    default property alias control: slot.data
    width: parent ? parent.width : 0
    height: visible ? Math.max(Style.space(44), labels.implicitHeight + Style.space(18)) : 0
    Column {
      id: labels
      x: Style.space(14)
      anchors.verticalCenter: parent.verticalCenter
      width: parent.width - slot.width - Style.space(40)
      spacing: 1
      Text { width: parent.width; textFormat: Text.PlainText; text: r.label; elide: Text.ElideRight; font.family: root.uiFont; font.pixelSize: Style.space(13); color: root.fg }
      Text { width: parent.width; visible: r.sub !== ""; textFormat: Text.PlainText; text: r.sub; wrapMode: Text.WordWrap; font.family: root.uiFont; font.pixelSize: Style.space(11); color: root.fg; opacity: 0.5 }
    }
    Item {
      id: slot
      anchors.right: parent.right; anchors.rightMargin: Style.space(14)
      anchors.verticalCenter: parent.verticalCenter
      width: childrenRect.width; height: childrenRect.height
    }
  }

  component Label_: Text {
    textFormat: Text.PlainText
    font.family: root.uiFont; font.pixelSize: Style.space(12.5)
    color: root.fg; opacity: 0.6
  }

  component Btn: Rectangle {
    id: b
    property string text: ""
    signal clicked()
    width: bt.implicitWidth + Style.space(24); height: Style.space(26); radius: Style.space(7)
    color: bMouse.pressed ? Qt.darker(root.accent, 1.15) : root.accent
    Text { id: bt; anchors.centerIn: parent; textFormat: Text.PlainText; text: b.text; font.family: root.uiFont; font.pixelSize: Style.space(12); font.weight: Font.Medium; color: "white" }
    MouseArea { id: bMouse; anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: b.clicked() }
  }

  // Contrôle segmenté.
  component Seg: Rectangle {
    id: seg
    property var options: []
    property string value: ""
    signal picked(string v)
    width: segRow.implicitWidth + 4; height: Style.space(28); radius: Style.space(8)
    color: Qt.rgba(root.fg.r, root.fg.g, root.fg.b, 0.08)
    Row {
      id: segRow
      anchors.centerIn: parent
      Repeater {
        model: seg.options
        delegate: Rectangle {
          id: opt
          required property var modelData
          readonly property bool on: seg.value === modelData[0]
          width: Math.max(Style.space(64), ot.implicitWidth + Style.space(22)); height: seg.height - 4; radius: Style.space(6)
          color: on ? (root.dark ? Qt.rgba(1, 1, 1, 0.2) : "#ffffff") : "transparent"
          border.width: on ? 1 : 0
          border.color: Qt.rgba(0, 0, 0, 0.06)
          Behavior on color { ColorAnimation { duration: 120 } }
          Text { id: ot; anchors.centerIn: parent; textFormat: Text.PlainText; text: opt.modelData[1]; font.family: root.uiFont; font.pixelSize: Style.space(12); font.weight: opt.on ? Font.DemiBold : Font.Normal; color: root.fg }
          MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: seg.picked(opt.modelData[0]) }
        }
      }
    }
  }

  // Interrupteur façon macOS.
  component Switch_: Rectangle {
    id: sw
    property bool checked: false
    signal toggled(bool v)
    width: Style.space(38); height: Style.space(22); radius: height / 2
    color: checked ? root.accent : Qt.rgba(root.fg.r, root.fg.g, root.fg.b, 0.18)
    Behavior on color { ColorAnimation { duration: 140 } }
    Rectangle {
      width: parent.height - 4; height: width; radius: width / 2
      y: 2; x: sw.checked ? sw.width - width - 2 : 2
      color: "white"
      border.width: 1; border.color: Qt.rgba(0, 0, 0, 0.08)
      Behavior on x { SpringAnimation { spring: 5; damping: 0.45; epsilon: 0.2 } }
    }
    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: sw.toggled(!sw.checked) }
  }

  component ToggleRow: Row_ {
    id: tr
    property string key: ""
    property bool def: false
    Switch_ { checked: root.val(tr.key, tr.def) === true; onToggled: function(v) { root.set(tr.key, v) } }
  }

  // Curseur : aperçu pendant le glissement, écriture au relâchement.
  component SliderRow: Row_ {
    id: sr
    property string key: ""
    property real from: 0
    property real to: 1
    property real step: 1
    property real def: 0
    property var fmt: function(v) { return String(v) }
    readonly property real stored: Number(root.val(key, def))
    property real live: stored
    property bool dragging: false
    onStoredChanged: if (!dragging) live = stored
    function snap(v) {
      var s = Math.round((v - from) / step) * step + from
      s = Math.max(from, Math.min(to, s))
      return Number(s.toFixed(4))
    }
    Row {
      spacing: Style.space(10)
      Item {
        width: Style.space(170); height: Style.space(22)
        anchors.verticalCenter: parent.verticalCenter
        Rectangle {
          id: track
          anchors.verticalCenter: parent.verticalCenter
          width: parent.width; height: Style.space(4); radius: 2
          color: Qt.rgba(root.fg.r, root.fg.g, root.fg.b, 0.15)
          Rectangle { width: knob.x + knob.width / 2; height: parent.height; radius: 2; color: root.accent }
        }
        Rectangle {
          id: knob
          width: Style.space(18); height: width; radius: width / 2
          anchors.verticalCenter: parent.verticalCenter
          x: (sr.live - sr.from) / (sr.to - sr.from) * (parent.width - width)
          color: "white"
          border.width: 1; border.color: Qt.rgba(0, 0, 0, 0.12)
        }
        MouseArea {
          anchors.fill: parent
          anchors.margins: -6
          cursorShape: Qt.PointingHandCursor
          preventStealing: true
          function at(x) { return sr.snap(sr.from + Math.max(0, Math.min(1, (x - 6 - knob.width / 2) / (parent.width - knob.width))) * (sr.to - sr.from)) }
          onPressed: function(m) { sr.dragging = true; sr.live = at(m.x) }
          onPositionChanged: function(m) { if (pressed) sr.live = at(m.x) }
          onReleased: { sr.dragging = false; if (sr.live !== sr.stored) root.set(sr.key, sr.live) }
        }
      }
      Text {
        width: Style.space(62)
        anchors.verticalCenter: parent.verticalCenter
        horizontalAlignment: Text.AlignRight
        textFormat: Text.PlainText
        text: sr.fmt(sr.live)
        font.family: root.uiFont; font.pixelSize: Style.space(12); font.features: { "tnum": 1 }
        color: root.fg; opacity: 0.6
      }
    }
  }

  // Heure HH:MM par pas de 30 min.
  component Stepper: Row {
    id: st
    property string value: "07:30"
    signal changed_(string v)
    spacing: Style.space(6)
    function shift(d) {
      var p = value.split(":"), m = (parseInt(p[0]) * 60 + parseInt(p[1]) + d + 1440) % 1440
      var h = Math.floor(m / 60), mm = m % 60
      changed_((h < 10 ? "0" : "") + h + ":" + (mm < 10 ? "0" : "") + mm)
    }
    Btn { text: "−"; width: Style.space(26); onClicked: st.shift(-30) }
    Text { anchors.verticalCenter: parent.verticalCenter; width: Style.space(48); horizontalAlignment: Text.AlignHCenter; textFormat: Text.PlainText; text: st.value; font.family: root.uiFont; font.pixelSize: Style.space(13); font.features: { "tnum": 1 }; color: root.fg }
    Btn { text: "+"; width: Style.space(26); onClicked: st.shift(30) }
  }
}
