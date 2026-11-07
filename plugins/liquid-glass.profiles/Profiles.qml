import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Widgets
import qs.Commons
import qs.Ui
import "T.js" as T

// Liquid Glass — sélecteur de bureaux (⌘⇧Espace), à la place de la liste de
// thèmes d'Omarchy : le Mac, l'Omarchy d'origine et les styles du bureau Linux
// en cartes d'aperçu (fond du thème + mini-maquette du style).
// Un style = une allure ; ses couleurs sont des « teintes » (pastilles sous la
// carte) : Violet nuit/aube/rose, Windows clair/sombre, Forêt mousse/cendre…
//   ←/→/↑/↓ ou 1…0 : choisir · T / ⇧T : teinte suivante/précédente
//   Entrée ou clic : appliquer · Échap : fermer
// Applique avec `liquid-glass profile <style>[:<teinte>]`.
Item {
  id: root

  property var shell: null
  property var manifest: null
  property bool opened: false
  property int selected: 0
  readonly property int cols: 6

  readonly property string home: Quickshell.env("HOME")
  readonly property string themes: home + "/.config/omarchy/themes/"
  readonly property string pluginId: (manifest && manifest.id) || "liquid-glass.profiles"

  // État courant (profil, style, teintes) lu dans la config.
  property var cfg: ({})
  FileView {
    path: root.home + "/.config/liquid-glass/config.json"
    watchChanges: true
    printErrors: false
    onFileChanged: reload()
    onLoaded: { try { root.cfg = JSON.parse(text()) } catch (e) {} }
  }
  readonly property string profile: {
    var p = cfg.profile && cfg.profile.active
    return p === "linux" || p === "omarchy" ? p : "mac"
  }
  readonly property string currentId: {
    if (profile !== "linux") return profile
    var st = (cfg.linux && cfg.linux.style) || "blanc"
    return st === "lain" ? "blanc" : st
  }

  // Fond de l'Omarchy d'origine (thème gardé à part), lu une fois par ouverture.
  property string stockBg: ""
  Process {
    id: statusProc
    command: ["liquid-glass", "profile", "status"]
    stdout: StdioCollector {
      onStreamFinished: { try { root.stockBg = JSON.parse(text).stock_bg || "" } catch (e) {} }
    }
  }

  //   id : argument de `liquid-glass profile` ; bg : fond d'aperçu ;
  //   ink/sub2/acc : couleurs de la maquette ; font : police du nom ; mock : type de maquette ;
  //   key/tones : clé [linux] et teintes (chaque teinte peut remplacer bg/ink/sub2/acc).
  readonly property var items: [
    { id: "mac", name: "Mac", sub: T.t("Liquid Glass, Dock, menus"), bg: themes + "liquid-glass/backgrounds/01-tahoe-day.jpg",
      ink: "#ffffff", sub2: "#e8eef8", acc: "#0a84ff", font: "Inter", mock: "mac" },
    { id: "omarchy", name: "Omarchy", sub: T.t("Tel qu'à l'installation"), bg: "",
      ink: "#e8e8e8", sub2: "#9a9a9a", acc: "#e8e8e8", font: "JetBrainsMono Nerd Font", mock: "omarchy" },
    { id: "windows", name: "Windows", sub: T.t("Démarrer, Paramètres"), bg: themes + "windows/backgrounds/01-windows-bloom.jpg",
      ink: "#1a1a1a", sub2: "#5d5d5d", acc: "#005fb8", font: "Noto Sans", mock: "win", key: "windows_tone",
      tones: [
        { id: "clair", name: T.t("Clair"), acc: "#005fb8" },
        { id: "sombre", name: T.t("Sombre"), bg: themes + "windows-sombre/backgrounds/01-windows-nuit.jpg", ink: "#f3f3f3", sub2: "#a8a8a8", acc: "#4cc2ff" }
      ] },
    { id: "mono", name: "Mono", sub: T.t("Caelestia : cadre, tableau de bord"), bg: themes + "mono/backgrounds/01-mono-trame.jpg",
      ink: "#f2f2f2", sub2: "#8d8d8d", acc: "#f2f2f2", font: "Rubik", mock: "mono", key: "mono_tone",
      tones: [
        { id: "noir", name: T.t("Noir"), acc: "#f2f2f2" },
        { id: "papier", name: T.t("Papier"), bg: themes + "mono-papier/backgrounds/01-papier.jpg", ink: "#161616", sub2: "#6a6a6a", acc: "#1a1a1a", frame: "#ffffff" },
        { id: "sakura", name: "Sakura", bg: themes + "mono-sakura/backgrounds/01-sakura.jpg", ink: "#fbe6ee", sub2: "#c9a3b3", acc: "#f7a8c4", frame: "#160d12" }
      ] },
    { id: "foret", name: T.t("Forêt"), sub: T.t("Puces, météo en orbite"), bg: themes + "foret/backgrounds/01-foret-lac.jpg",
      ink: "#e9eedd", sub2: "#9fa88a", acc: "#cfe89a", font: "JetBrainsMono Nerd Font", mock: "chips", key: "foret_tone",
      tones: [
        { id: "mousse", name: T.t("Mousse"), acc: "#cfe89a" },
        { id: "cendre", name: T.t("Cendre"), bg: themes + "foret/backgrounds/03-foret-nuit.jpg", acc: "#f4b6c8", sub2: "#b7a0a8" }
      ] },
    { id: "blanc", name: T.t("Blanc"), sub: T.t("Barre texte, bords durs"), bg: themes + "blanc/backgrounds/01-blanc-ondes.jpg",
      ink: "#141414", sub2: "#6e6e6e", acc: "#141414", font: "JetBrainsMono Nerd Font", mock: "paper", key: "blanc_tone",
      tones: [
        { id: "pur", name: T.t("Pur"), acc: "#141414" },
        { id: "creme", name: T.t("Crème"), bg: themes + "blanc/backgrounds/02-creme-ondes.jpg", ink: "#2b2418", sub2: "#7d705c", acc: "#8a6a3c" }
      ] },
    { id: "sombre", name: T.t("Sombre"), sub: T.t("Mur de tuiles, mot géant"), bg: themes + "sombre/backgrounds/01-sombre-crêtes.jpg",
      ink: "#ededed", sub2: "#8c8c8c", acc: "#f2f2f2", font: "Silkscreen", mock: "wall", key: "sombre_tone",
      tones: [
        { id: "encre", name: T.t("Encre"), acc: "#f2f2f2" },
        { id: "ambre", name: T.t("Ambre"), acc: "#ffb454", sub2: "#c9a77c" },
        { id: "glace", name: T.t("Glace"), acc: "#9fd8ff", sub2: "#9cb4c8" },
        { id: "sang", name: T.t("Sang"), acc: "#ff5a6e", sub2: "#d99aa2" },
        { id: "indigo", name: "Indigo", acc: "#a6b1ff", sub2: "#a0a6d8" }
      ] },
    { id: "jouet", name: T.t("Jouet"), sub: T.t("Gros dock, autocollants"), bg: themes + "jouet/backgrounds/01-jouet-bonbon.jpg",
      ink: "#1b1030", sub2: "#5b4a7a", acc: "#ff5fa2", font: "Rubik", mock: "dock", key: "jouet_tone",
      tones: [
        { id: "bonbon", name: T.t("Bonbon"), acc: "#ff5fa2" },
        { id: "menthe", name: T.t("Menthe"), acc: "#18b98f", bg: themes + "jouet/backgrounds/02-jouet-menthe.jpg" },
        { id: "peche", name: T.t("Pêche"), acc: "#ff7a45" }
      ] },
    { id: "violet", name: "Violet", sub: T.t("Horloge empilée, brume"), bg: themes + "violet/backgrounds/01-violet-nuit.jpg",
      ink: "#ece4ff", sub2: "#b79ce8", acc: "#cdb6ff", font: "Google Sans Flex", mock: "stack", key: "violet_tone",
      tones: [
        { id: "nuit", name: T.t("Nuit"), acc: "#9b7bdc" },
        { id: "aube", name: T.t("Aube"), bg: themes + "violet-aube/backgrounds/01-violet-aube.jpg", ink: "#2c1b4d", sub2: "#8a63c9", acc: "#c8b2f0" },
        { id: "rose", name: "Rose", bg: themes + "rose/backgrounds/01-rose-pastel.jpg", ink: "#4a2533", sub2: "#c06a8c", acc: "#f2a7c3" }
      ] },
    { id: "expressive", name: "Expressive", sub: T.t("Material 3, couleurs du fond"), bg: themes + "lain/backgrounds/08-lain.png",
      ink: "#e2e2e9", sub2: "#adc6ff", acc: "#adc6ff", font: "Rubik", mock: "cookie", key: "scheme",
      tones: [
        { id: "tonal-spot", name: "Tonal", acc: "#adc6ff" },
        { id: "expressive", name: T.t("Expressif"), acc: "#f0b8e8", sub2: "#f0b8e8" },
        { id: "vibrant", name: T.t("Vif"), acc: "#7fd8ff", sub2: "#7fd8ff" },
        { id: "fruit-salad", name: T.t("Fruité"), acc: "#ffb59c", sub2: "#ffb59c" },
        { id: "monochrome", name: "Monochrome", acc: "#c6c6c6", sub2: "#c6c6c6" }
      ] },
    { id: "ruban", name: T.t("Rubans"), sub: T.t("Bandes en biais, grande date"), bg: themes + "ruban/backgrounds/01-ruban.jpg",
      ink: "#ffffff", sub2: "#a8dfff", acc: "#19d3ff", font: "Rubik", mock: "ruban", key: "ruban_tone",
      tones: [
        { id: "bleu", name: T.t("Bleu"), acc: "#19d3ff" },
        { id: "rouge", name: T.t("Rouge"), acc: "#ff3b3b", sub2: "#ffb8b8" },
        { id: "or", name: T.t("Or"), acc: "#ffc800", sub2: "#ffe6a8" }
      ] },
    { id: "espace", name: T.t("Espace"), sub: T.t("Paroles, horloge à planètes"), bg: themes + "espace/backgrounds/01-espace.jpg",
      ink: "#eef3fa", sub2: "#9aa9bd", acc: "#8fc7ff", font: "Inter", mock: "space", key: "espace_tone",
      tones: [
        { id: "bleu", name: T.t("Bleu"), acc: "#8fc7ff" },
        { id: "mars", name: "Mars", acc: "#ff8a6b", sub2: "#bda69c" },
        { id: "nebuleuse", name: T.t("Nébuleuse"), acc: "#c58bff", sub2: "#a99dc2" }
      ] },
    { id: "cosmos", name: "Cosmos", sub: T.t("Terre, Lune et satellites"), bg: themes + "cosmos/backgrounds/01-cosmos.jpg",
      ink: "#e4eef2", sub2: "#92a6af", acc: "#9fdcf5", font: "JetBrainsMono Nerd Font", mock: "space", key: "cosmos_tone",
      tones: [
        { id: "orbite", name: T.t("Orbite"), acc: "#9fdcf5" },
        { id: "mousse", name: T.t("Mousse"), acc: "#a8e0a4" },
        { id: "corail", name: T.t("Corail"), acc: "#ffb09c" }
      ] },
    { id: "gouts", name: T.t("Mes goûts"), sub: T.t("Tout, aux couleurs d'un thème"), bg: "/usr/share/omarchy/themes/tokyo-night/backgrounds/1-winding-road.webp",
      ink: "#c0caf5", sub2: "#a9b1d6", acc: "#7aa2f7", font: "Google Sans Flex", mock: "stack" },
    { id: "debian", name: "Debian", sub: T.t("GNOME, Activités"), bg: themes + "debian/backgrounds/01-debian.jpg",
      ink: "#ffffff", sub2: "#cfcfcf", acc: "#d70a53", font: "Adwaita Sans", mock: "distro", glyph: "\uf306", barPos: "top" },
    { id: "fedora", name: "Fedora", sub: T.t("GNOME, bleu Fedora"), bg: themes + "fedora/backgrounds/01-fedora.jpg",
      ink: "#ffffff", sub2: "#cfd8e6", acc: "#3c6eb4", font: "Adwaita Sans", mock: "distro", glyph: "\uf30a", barPos: "top" },
    { id: "mint", name: "Mint", sub: T.t("Cinnamon, panneau en bas"), bg: themes + "mint/backgrounds/01-mint.jpg",
      ink: "#ffffff", sub2: "#d0e6d6", acc: "#35a854", font: "Noto Sans", mock: "distro", glyph: "\uf30e", barPos: "bottom", logo: true },
    { id: "kali", name: "Kali", sub: T.t("Xfce, menu des outils"), bg: themes + "kali/backgrounds/01-kali.jpg",
      ink: "#ffffff", sub2: "#c6d4f0", acc: "#367bf0", font: "Noto Sans", mock: "distro", glyph: "\uf327", barPos: "top" },
    { id: "arch", name: "Arch", sub: T.t("Plasma, Kickoff"), bg: themes + "arch/backgrounds/01-arch.jpg",
      ink: "#ffffff", sub2: "#c6e0f0", acc: "#1793d1", font: "Noto Sans", mock: "distro", glyph: "\uf303", barPos: "bottom", logo: true }
  ]

  // Teinte choisie par carte (aperçu avant d'appliquer) : { id: index }.
  property var toneSel: ({})
  function savedTone(it) {
    if (!it.tones) return 0
    var v = cfg.linux ? cfg.linux[it.key] : undefined
    for (var i = 0; i < it.tones.length; i++) if (it.tones[i].id === v) return i
    return 0
  }
  function toneIndex(it, sel) { return it.tones ? (sel[it.id] !== undefined ? sel[it.id] : savedTone(it)) : -1 }
  function setTone(i, t) {
    var it = items[i]
    if (!it || !it.tones) return
    var o = Object.assign({}, toneSel)
    o[it.id] = (t + it.tones.length) % it.tones.length
    toneSel = o
  }
  // Numéro au clavier : un ou deux chiffres (« 1 » puis « 4 » = carte 14).
  property string typed: ""
  Timer { id: digitTimer; interval: 420; onTriggered: { var n = parseInt(root.typed); root.typed = ""; if (n > 0) root.apply(n - 1) } }
  function digit(d) {
    typed += String(d)
    if (typed.length >= 2) { digitTimer.stop(); var n = parseInt(typed); typed = ""; if (n > 0) apply(n - 1) }
    else digitTimer.restart()
  }
  function cycleTone(d) { var it = items[selected]; if (it && it.tones) setTone(selected, toneIndex(it, toneSel) + d) }
  // Carte vue avec sa teinte : les champs de la teinte remplacent ceux du style.
  function effective(it, sel) {
    var e = Object.assign({}, it)
    if (it.id === "omarchy") e.bg = stockBg
    var t = toneIndex(it, sel)
    if (t >= 0) {
      var tn = it.tones[t]
      for (var k in tn) if (k !== "id" && k !== "name") e[k] = tn[k]
      e.tone = tn.id
      e.toneName = tn.name
    }
    return e
  }

  function indexOfId(id) { for (var i = 0; i < items.length; i++) if (items[i].id === id) return i; return 0 }
  function open(payloadJson) {
    toneSel = ({})
    selected = indexOfId(currentId)
    statusProc.running = true
    opened = true
  }
  function close() { opened = false }
  function dismiss() {
    opened = false
    if (shell && typeof shell.hide === "function") shell.hide(pluginId)
  }
  function apply(i) {
    var it = items[i]
    if (!it) return
    dismiss()
    var t = toneIndex(it, toneSel)
    var same = it.id === currentId && (t < 0 || t === savedTone(it))
    if (!same) Quickshell.execDetached(["liquid-glass", "profile", t >= 0 ? it.id + ":" + it.tones[t].id : it.id])
  }
  function move(dx, dy) {
    var rows = Math.ceil(items.length / cols)
    var c = selected % cols, r = Math.floor(selected / cols)
    c = (c + dx + cols) % cols
    r = (r + dy + rows) % rows
    selected = Math.min(items.length - 1, r * cols + c)
  }

  ShellIpc {
    target: "liquid-glass.profiles"
    function toggle(): void { if (root.opened) root.dismiss(); else if (root.shell) root.shell.summon(root.pluginId, "") }
    function open(): void { if (!root.opened && root.shell) root.shell.summon(root.pluginId, "") }
  }

  OverlayWindow {
    id: win
    shown: root.opened
    WlrLayershell.namespace: "liquid-glass-profiles"

    Rectangle {
      anchors.fill: parent
      color: Qt.rgba(0.02, 0.01, 0.05, 0.8)
      opacity: win.contentRevealed ? 1 : 0
      Behavior on opacity { NumberAnimation { duration: 200 } }
    }
    Item {
      anchors.fill: parent
      focus: true
      Keys.onPressed: function(ev) {
        if (ev.key === Qt.Key_Escape) root.dismiss()
        else if (ev.key === Qt.Key_Left || ev.key === Qt.Key_H) root.move(-1, 0)
        else if (ev.key === Qt.Key_Right || ev.key === Qt.Key_L || ev.key === Qt.Key_Tab) root.move(1, 0)
        else if (ev.key === Qt.Key_Up || ev.key === Qt.Key_K) root.move(0, -1)
        else if (ev.key === Qt.Key_Down || ev.key === Qt.Key_J) root.move(0, 1)
        else if (ev.key === Qt.Key_T) root.cycleTone(ev.modifiers & Qt.ShiftModifier ? -1 : 1)
        else if (ev.key === Qt.Key_Return || ev.key === Qt.Key_Enter || ev.key === Qt.Key_Space) root.apply(root.selected)
        else if (ev.key >= Qt.Key_0 && ev.key <= Qt.Key_9) root.digit(ev.key - Qt.Key_0)
        else return
        ev.accepted = true
      }
    }
    MouseArea { anchors.fill: parent; onClicked: root.dismiss() }

    Column {
      id: stage
      anchors.centerIn: parent
      spacing: 16
      opacity: win.contentRevealed ? 1 : 0
      property real lift: win.contentRevealed ? 0 : 40
      transform: Translate { y: stage.lift }
      Behavior on opacity { NumberAnimation { duration: 220 } }
      Behavior on lift { NumberAnimation { duration: 520; easing.type: Easing.OutBack; easing.overshoot: 1.6 } }

      Row {
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: 10
        Text {
          id: title
          text: T.t("Bureaux")
          font.family: "Google Sans Flex"
          font.pixelSize: 26
          font.variableAxes: ({ "wght": 800, "ROND": 100 })
          color: "white"
        }
        Text {
          anchors.baseline: title.baseline
          text: T.t("flèches ou 1–0 · T teinte · Entrée · Échap")
          font.family: "Google Sans Flex"
          font.pixelSize: 12
          color: Qt.rgba(1, 1, 1, 0.55)
        }
      }

      Grid {
        id: grid
        columns: root.cols
        columnSpacing: 14
        rowSpacing: 10
        Repeater {
          model: root.items
          delegate: Item {
            id: cell
            required property var modelData
            required property int index
            readonly property var eff: root.effective(modelData, root.toneSel)
            readonly property bool sel: root.selected === index
            readonly property bool cur: root.currentId === modelData.id
            readonly property int curTone: root.toneIndex(modelData, root.toneSel)
            width: Math.min(190, (win.width - 160) / root.cols)
            height: width * 0.62 + 64

            // Apparition en cascade.
            opacity: win.contentRevealed ? 1 : 0
            Behavior on opacity { SequentialAnimation { PauseAnimation { duration: cell.index * 24 } NumberAnimation { duration: 240 } } }

            MouseArea {
              id: hov
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onEntered: root.selected = cell.index
              onClicked: root.apply(cell.index)
            }

            Item {
              id: frame
              width: parent.width
              height: parent.width * 0.62
              scale: cell.sel ? 1.06 : (hov.containsMouse ? 1.02 : 1)
              Behavior on scale { SpringAnimation { spring: 4; damping: 0.32; epsilon: 0.002 } }
              RectangularShadow {
                anchors.fill: thumb
                radius: 16
                blur: cell.sel ? 26 : 12
                spread: -2
                offset.y: cell.sel ? 8 : 4
                color: Qt.rgba(0, 0, 0, cell.sel ? 0.5 : 0.35)
              }
              ClippingRectangle {
                id: thumb
                anchors.fill: parent
                radius: 16
                color: "#2a2a2e"
                Image {
                  anchors.fill: parent
                  source: cell.eff.bg ? "file://" + cell.eff.bg : ""
                  sourceSize.width: 480
                  fillMode: Image.PreserveAspectCrop
                  asynchronous: true
                  cache: true
                }
                Mock { anchors.fill: parent; it: cell.eff }
              }
              Rectangle {
                anchors.fill: parent
                radius: 16
                color: "transparent"
                border.width: cell.sel ? 3 : 1
                border.color: cell.sel ? "white" : Qt.rgba(1, 1, 1, 0.18)
                Behavior on border.width { NumberAnimation { duration: 140 } }
              }
              // Badge « actuel »
              Rectangle {
                visible: cell.cur
                anchors.right: parent.right; anchors.top: parent.top; anchors.margins: 8
                height: 20; width: curText.implicitWidth + 14; radius: 10
                color: "white"
                Text { id: curText; anchors.centerIn: parent; text: T.t("actuel"); font.family: "Google Sans Flex"; font.pixelSize: 10; font.weight: Font.Bold; color: "#111" }
              }
            }
            Column {
              anchors.top: frame.bottom
              anchors.topMargin: 8
              x: 4
              width: parent.width - 8
              spacing: 1
              // Nom + touche du clavier (1…0)
              Item {
                width: parent.width
                height: nameText.implicitHeight
                Rectangle {
                  anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                  width: cell.index < 9 ? 20 : 26; height: 20; radius: 6
                  color: cell.sel ? "white" : Qt.rgba(1, 1, 1, 0.12)
                  Text { anchors.centerIn: parent; text: String(cell.index + 1); font.family: "Google Sans Flex"; font.pixelSize: 11; font.weight: Font.Bold; color: cell.sel ? "#111" : Qt.rgba(1, 1, 1, 0.7) }
                }
              Text {
                id: nameText
                text: cell.modelData.name
                font.family: cell.modelData.font
                font.pixelSize: 15
                font.weight: Font.Bold
                font.variableAxes: cell.modelData.font === "Google Sans Flex" ? { "wght": 800, "ROND": 100 } : ({})
                color: "white"
              }
              }
              Text {
                width: parent.width
                elide: Text.ElideRight
                text: cell.modelData.sub
                font.family: "Google Sans Flex"
                font.pixelSize: 11
                color: Qt.rgba(1, 1, 1, cell.sel ? 0.8 : 0.55)
              }
              // Teintes : pastilles cliquables + nom de la teinte vue.
              Row {
                visible: !!cell.modelData.tones
                spacing: 5
                topPadding: 4
                Repeater {
                  model: cell.modelData.tones || []
                  delegate: Rectangle {
                    id: dot
                    required property var modelData
                    required property int index
                    readonly property bool on: cell.curTone === index
                    anchors.verticalCenter: parent.verticalCenter
                    width: on ? 14 : 11; height: width; radius: width / 2
                    color: dot.modelData.acc
                    border.width: on ? 2 : 1
                    border.color: on ? "white" : Qt.rgba(1, 1, 1, 0.35)
                    Behavior on width { NumberAnimation { duration: 140; easing.type: Easing.OutBack } }
                    MouseArea {
                      anchors.fill: parent
                      anchors.margins: -3
                      hoverEnabled: true
                      cursorShape: Qt.PointingHandCursor
                      onEntered: root.selected = cell.index
                      onClicked: root.setTone(cell.index, dot.index)
                    }
                  }
                }
                Text {
                  anchors.verticalCenter: parent.verticalCenter
                  leftPadding: 3
                  text: cell.eff.toneName || ""
                  font.family: "Google Sans Flex"
                  font.pixelSize: 10
                  font.weight: Font.Bold
                  color: Qt.rgba(1, 1, 1, cell.sel ? 0.85 : 0.5)
                }
              }
            }
          }
        }
      }
    }
  }

  // Mini-maquette du bureau de chaque style, posée sur son fond.
  component Mock: Item {
    id: mk
    property var it: ({})
    readonly property real u: width / 236
    readonly property string m: it.mock || ""
    // Barre en haut (styles Linux à barre haute)
    Rectangle {
      visible: ["pixel", "kanji", "toy", "stack", "cookie"].indexOf(mk.m) >= 0
      // Blanc : ligne de texte en bas ; Jouet : dock centré en bas ; les autres : barre en haut.
      x: mk.m === "pixel" ? 0 : (mk.m === "toy" ? parent.width * 0.16 : 8 * mk.u)
      y: mk.m === "pixel" ? parent.height - 6 * mk.u : (mk.m === "toy" ? parent.height - 20 * mk.u : 6 * mk.u)
      width: mk.m === "pixel" ? parent.width : (mk.m === "toy" ? parent.width * 0.68 : parent.width - 16 * mk.u)
      height: mk.m === "pixel" ? 6 * mk.u : (mk.m === "toy" ? 15 * mk.u : 9 * mk.u)
      radius: mk.m === "toy" ? 3 * mk.u : (mk.m === "pixel" || mk.m === "kanji" ? 1 : 4.5 * mk.u)
      color: Qt.rgba(1, 1, 1, mk.it.ink === "#141414" || mk.it.ink === "#1b1030" || mk.it.ink === "#2b2418" ? 0.85 : 0.14)
      border.width: mk.m === "toy" ? 1.5 : (mk.m === "pixel" ? 1 : 0)
      border.color: mk.it.ink
    }
    // Omarchy : barre fine sur toute la largeur, bureaux à gauche, heure au centre.
    Rectangle {
      visible: mk.m === "omarchy"
      width: parent.width; height: 10 * mk.u
      color: Qt.rgba(0, 0, 0, 0.72)
      Row {
        x: 6 * mk.u; anchors.verticalCenter: parent.verticalCenter; spacing: 4 * mk.u
        Repeater {
          model: 5
          delegate: Text { required property int index; text: index + 1; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: Math.max(6, Math.round(7 * mk.u)); color: index === 0 ? "white" : "#8a8a8a" }
        }
      }
      Text { anchors.centerIn: parent; text: "samedi 12:34"; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: Math.max(6, Math.round(7 * mk.u)); color: "white" }
    }
    Rectangle {
      visible: mk.m === "omarchy"
      anchors.centerIn: parent
      width: 96 * mk.u; height: 50 * mk.u; radius: 0
      color: Qt.rgba(0, 0, 0, 0.6)
      border.width: 1; border.color: Qt.rgba(1, 1, 1, 0.5)
      Text { x: 6 * mk.u; y: 5 * mk.u; text: "Go…"; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: Math.round(8 * mk.u); color: "white" }
      Column {
        x: 6 * mk.u; y: 17 * mk.u; spacing: 3 * mk.u
        Repeater { model: 4; delegate: Rectangle { required property int index; width: (60 - index * 9) * mk.u; height: 3 * mk.u; color: Qt.rgba(1, 1, 1, index === 0 ? 0.8 : 0.35) } }
      }
    }
    // Mac : barre de menus + Dock
    Rectangle {
      visible: mk.m === "mac"
      width: parent.width; height: 8 * mk.u
      color: Qt.rgba(1, 1, 1, 0.35)
    }
    Rectangle {
      visible: mk.m === "mac"
      anchors.horizontalCenter: parent.horizontalCenter
      anchors.bottom: parent.bottom; anchors.bottomMargin: 7 * mk.u
      width: 110 * mk.u; height: 18 * mk.u; radius: 7 * mk.u
      color: Qt.rgba(1, 1, 1, 0.35)
      border.width: 1; border.color: Qt.rgba(1, 1, 1, 0.6)
      Row {
        anchors.centerIn: parent
        spacing: 4 * mk.u
        Repeater {
          model: ["#0a84ff", "#34c759", "#ff9f0a", "#ff375f", "#bf5af2", "#64d2ff"]
          delegate: Rectangle { required property string modelData; width: 12 * mk.u; height: width; radius: 3.5 * mk.u; color: modelData }
        }
      }
    }
    // Windows : fenêtre + barre des tâches centrée avec le bouton Démarrer.
    Rectangle {
      visible: mk.m === "win"
      x: 46 * mk.u; y: 20 * mk.u
      width: 120 * mk.u; height: 74 * mk.u; radius: 4 * mk.u
      color: mk.it.ink === "#1a1a1a" ? Qt.rgba(0.96, 0.96, 0.97, 0.92) : Qt.rgba(0.13, 0.13, 0.14, 0.92)
      border.width: 1; border.color: Qt.rgba(0.5, 0.5, 0.5, 0.35)
      Rectangle { x: 6 * mk.u; y: 14 * mk.u; width: 26 * mk.u; height: parent.height - 20 * mk.u; radius: 2 * mk.u; color: Qt.rgba(0.5, 0.5, 0.5, 0.15) }
      Column {
        x: 38 * mk.u; y: 14 * mk.u; spacing: 4 * mk.u
        Repeater { model: 4; delegate: Rectangle { required property int index; width: (70 - index * 8) * mk.u; height: 7 * mk.u; radius: 2 * mk.u; color: index === 0 ? mk.it.acc : Qt.rgba(0.5, 0.5, 0.5, 0.22) } }
      }
    }
    Rectangle {
      visible: mk.m === "win"
      anchors.bottom: parent.bottom
      width: parent.width; height: 14 * mk.u
      color: mk.it.ink === "#1a1a1a" ? Qt.rgba(0.95, 0.95, 0.96, 0.9) : Qt.rgba(0.1, 0.1, 0.11, 0.9)
      Row {
        anchors.centerIn: parent
        spacing: 4 * mk.u
        Grid {
          anchors.verticalCenter: parent.verticalCenter
          columns: 2; spacing: 0.8 * mk.u
          Repeater { model: 4; delegate: Rectangle { width: 3.6 * mk.u; height: width; color: mk.it.acc } }
        }
        Repeater {
          model: ["#f4c430", "#0a84ff", "#34c759", "#e05050"]
          delegate: Rectangle { required property string modelData; anchors.verticalCenter: parent.verticalCenter; width: 7.5 * mk.u; height: width; radius: 1.5 * mk.u; color: modelData }
        }
      }
    }
    // Sombre : mur de tuiles.
    Repeater {
      model: mk.m === "wall" ? [[0, 0, 2, 2], [2, 0, 3, 2], [5, 0, 3, 2], [8, 0, 4, 3], [0, 2, 5, 1], [5, 2, 3, 2], [8, 3, 2, 1], [10, 3, 2, 1], [0, 3, 5, 3], [5, 4, 7, 2]] : []
      delegate: Rectangle {
        required property var modelData
        required property int index
        readonly property real cw: (mk.width - 8 * mk.u) / 12
        readonly property real ch: (mk.height - 8 * mk.u) / 6
        x: 4 * mk.u + modelData[0] * cw; y: 4 * mk.u + modelData[1] * ch
        width: modelData[2] * cw - 2 * mk.u; height: modelData[3] * ch - 2 * mk.u
        color: Qt.rgba(0, 0, 0, 0.72); border.width: 1; border.color: mk.it.acc
        Text {
          visible: index === 8
          anchors.centerIn: parent; text: "12:34"
          font.family: "Silkscreen"; font.pixelSize: Math.round(19 * mk.u); font.bold: true; color: mk.it.acc
        }
        Row {
          visible: index === 9
          anchors.bottom: parent.bottom; anchors.bottomMargin: 2 * mk.u; x: 3 * mk.u; spacing: 1.5 * mk.u
          Repeater {
            model: 26
            delegate: Rectangle {
              required property int index
              anchors.bottom: parent.bottom
              width: 3 * mk.u; height: (4 + 12 * Math.abs(Math.sin(index * 0.9))) * mk.u; color: mk.it.acc
            }
          }
        }
      }
    }
    // Blanc : ligne de texte en bas, fiche à ombre dure, grande heure.
    Rectangle { visible: mk.m === "paper"; y: parent.height - height; width: parent.width; height: 7 * mk.u; color: "white"; Rectangle { width: parent.width; height: 1; color: mk.it.ink } }
    Rectangle { visible: mk.m === "paper"; x: 15 * mk.u; y: parent.height - 62 * mk.u; width: 66 * mk.u; height: 44 * mk.u; color: mk.it.ink }
    Rectangle {
      visible: mk.m === "paper"
      x: 11 * mk.u; y: parent.height - 66 * mk.u; width: 66 * mk.u; height: 44 * mk.u
      color: "white"; border.width: 1.5; border.color: mk.it.ink
      Column {
        x: 6 * mk.u; y: 6 * mk.u; spacing: 4 * mk.u
        Repeater { model: 5; delegate: Rectangle { required property int index; width: (index ? 44 - index * 4 : 34) * mk.u; height: 2.5 * mk.u; color: mk.it.ink; opacity: index ? 0.55 : 1 } }
      }
    }
    Text {
      visible: mk.m === "paper"
      anchors.right: parent.right; anchors.rightMargin: 8 * mk.u; anchors.bottom: parent.bottom; anchors.bottomMargin: 10 * mk.u
      text: "12:34"; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: Math.round(34 * mk.u); font.weight: Font.ExtraBold; color: mk.it.ink
    }
    // Jouet : gros dock en bas, autocollants.
    Rectangle {
      visible: mk.m === "dock"
      x: 42 * mk.u; y: parent.height - 26 * mk.u; width: parent.width - 80 * mk.u; height: 20 * mk.u
      radius: 7 * mk.u; color: mk.it.ink
    }
    Rectangle {
      visible: mk.m === "dock"
      x: 40 * mk.u; y: parent.height - 28 * mk.u; width: parent.width - 80 * mk.u; height: 20 * mk.u
      radius: 7 * mk.u; color: "#fffdf7"; border.width: 1.5; border.color: mk.it.ink
      Row {
        anchors.centerIn: parent; spacing: 3 * mk.u
        Repeater {
          model: ["#ff5fa2", "#ffd23f", "#3ddbb4", "#6ec6ff", "#b9a2ff", "#ff9f43", "#ff5fa2", "#3ddbb4"]
          delegate: Rectangle {
            required property string modelData
            required property int index
            width: 13 * mk.u; height: 13 * mk.u; radius: 4 * mk.u; rotation: index % 2 ? 6 : -6
            color: modelData; border.width: 1; border.color: mk.it.ink
          }
        }
      }
    }
    Rectangle {
      visible: mk.m === "dock"
      x: 12 * mk.u; y: 12 * mk.u; width: 92 * mk.u; height: 40 * mk.u; radius: 8 * mk.u; rotation: -3
      color: "#fffdf7"; border.width: 1.5; border.color: mk.it.ink
      Text { anchors.centerIn: parent; text: "12:34"; font.family: "Rubik"; font.pixelSize: Math.round(24 * mk.u); font.weight: Font.Black; color: mk.it.acc }
    }
    // Espace : barre fine, lignes de paroles, orbites.
    Rectangle { visible: mk.m === "space"; width: parent.width; height: 7 * mk.u; color: Qt.rgba(0, 0, 0, 0.6) }
    Column {
      visible: mk.m === "space"
      anchors.centerIn: parent; spacing: 5 * mk.u
      Repeater {
        model: [40, 70, 96, 60, 34]
        delegate: Rectangle {
          required property int modelData
          required property int index
          anchors.horizontalCenter: parent.horizontalCenter
          width: modelData * mk.u; height: (index === 2 ? 4 : 2.5) * mk.u; radius: 2 * mk.u
          color: "white"; opacity: index === 2 ? 1 : 0.4
        }
      }
    }
    Repeater {
      model: mk.m === "space" ? [24, 38, 52] : []
      delegate: Rectangle {
        required property int modelData
        x: mk.width - 34 * mk.u - width / 2; y: mk.height - 34 * mk.u - height / 2
        width: modelData * mk.u; height: width; radius: width / 2
        color: "transparent"; border.width: 1; border.color: mk.it.acc
      }
    }
    // Rubans : deux bandes en biais et la date.
    Repeater {
      model: mk.m === "ruban" ? [[0, 96, 18, -4], [0, 150, 15, -4]] : []
      delegate: Rectangle {
        required property var modelData
        required property int index
        x: -8 * mk.u; y: modelData[1] * mk.u * 0.72; width: (index ? 90 : 130) * mk.u; height: modelData[2] * mk.u
        rotation: modelData[3]; color: index ? mk.it.acc : "#06102e"; border.width: index ? 0 : 1.5; border.color: mk.it.acc
      }
    }
    Text {
      visible: mk.m === "ruban"
      anchors.right: parent.right; anchors.rightMargin: 8 * mk.u; y: 12 * mk.u
      text: "07"; font.family: "Rubik"; font.pixelSize: Math.round(48 * mk.u); font.weight: Font.Black; font.italic: true; color: "white"; opacity: 0.85
    }
    // Distributions : leur panneau, en haut ou en bas, et leur logo.
    Rectangle {
      visible: mk.m === "distro"
      y: mk.it.barPos === "bottom" ? parent.height - height : 0
      width: parent.width; height: 11 * mk.u
      color: mk.it.id === "debian" || mk.it.id === "fedora" ? "black" : "#242628"
      Text {
        x: 4 * mk.u; anchors.verticalCenter: parent.verticalCenter; text: mk.it.glyph || ""
        font.family: "JetBrainsMono Nerd Font"; font.pixelSize: Math.round(8 * mk.u); color: mk.it.acc
      }
    }
    Text {
      visible: mk.m === "distro" && mk.it.logo === true
      anchors.centerIn: parent; text: mk.it.glyph || ""
      font.family: "JetBrainsMono Nerd Font"; font.pixelSize: Math.round(46 * mk.u); color: "white"; opacity: 0.9
    }
    // Mono : cadre noir arrondi + barre latérale noire.
    Rectangle {
      visible: mk.m === "mono"
      anchors.fill: parent
      color: "transparent"
      border.width: 5 * mk.u; border.color: mk.it.frame || "black"
    }
    Rectangle {
      visible: mk.m === "mono"
      width: 15 * mk.u; height: parent.height
      color: mk.it.frame || "black"
      Column {
        anchors.horizontalCenter: parent.horizontalCenter; y: 8 * mk.u; spacing: 4 * mk.u
        Repeater { model: 5; delegate: Rectangle { required property int index; width: 4 * mk.u; height: index === 1 ? 10 * mk.u : 4 * mk.u; radius: 2 * mk.u; color: index === 1 ? mk.it.acc : "#555" } }
      }
      Rectangle { anchors.horizontalCenter: parent.horizontalCenter; anchors.bottom: parent.bottom; anchors.bottomMargin: 6 * mk.u; width: 8 * mk.u; height: width; radius: width / 2; color: "#e05555" }
    }
    Rectangle {
      visible: mk.m === "mono"
      anchors.horizontalCenter: parent.horizontalCenter; anchors.horizontalCenterOffset: 7 * mk.u
      y: 5 * mk.u
      width: 110 * mk.u; height: 34 * mk.u
      bottomLeftRadius: 12 * mk.u; bottomRightRadius: 12 * mk.u
      color: mk.it.frame || "black"
      Text { x: 10 * mk.u; anchors.verticalCenter: parent.verticalCenter; text: "12\n34"; lineHeight: 0.8; font.family: "Rubik"; font.pixelSize: Math.round(11 * mk.u); font.weight: Font.Black; color: mk.it.acc }
      Row {
        anchors.right: parent.right; anchors.rightMargin: 10 * mk.u; anchors.verticalCenter: parent.verticalCenter; spacing: 5 * mk.u
        Repeater { model: 3; delegate: Rectangle { width: 14 * mk.u; height: width; radius: width / 2; color: "transparent"; border.width: 2 * mk.u; border.color: mk.it.sub2 } }
      }
    }
    // Forêt : puces flottantes en haut, horloge au centre, puce musique.
    Row {
      visible: mk.m === "chips"
      x: 6 * mk.u; y: 6 * mk.u; spacing: 3 * mk.u
      Repeater {
        model: [10, 10, 34, 46]
        delegate: Rectangle {
          required property int modelData
          required property int index
          width: modelData * mk.u; height: 10 * mk.u; radius: 3 * mk.u
          color: Qt.rgba(0.1, 0.11, 0.08, 0.9)
          Rectangle { visible: index === 2; x: 2 * mk.u; anchors.verticalCenter: parent.verticalCenter; width: 6 * mk.u; height: width; radius: 1.5 * mk.u; color: mk.it.acc }
        }
      }
    }
    Rectangle {
      visible: mk.m === "chips"
      anchors.horizontalCenter: parent.horizontalCenter; y: 6 * mk.u
      width: 44 * mk.u; height: 10 * mk.u; radius: 3 * mk.u
      color: Qt.rgba(0.1, 0.11, 0.08, 0.9)
      Text { anchors.centerIn: parent; text: "12:34:56"; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: Math.max(6, Math.round(6.5 * mk.u)); font.weight: Font.Bold; color: mk.it.acc }
    }
    Row {
      visible: mk.m === "chips"
      anchors.right: parent.right; anchors.rightMargin: 6 * mk.u; y: 6 * mk.u; spacing: 2 * mk.u
      Repeater {
        model: 4
        delegate: Rectangle { required property int index; width: 12 * mk.u; height: 10 * mk.u; radius: 3 * mk.u; color: index === 2 ? mk.it.sub2 : (index === 1 ? mk.it.acc : Qt.rgba(0.1, 0.11, 0.08, 0.9)) }
      }
    }
    Rectangle {
      visible: mk.m === "chips"
      anchors.horizontalCenter: parent.horizontalCenter; y: 26 * mk.u
      width: 104 * mk.u; height: 72 * mk.u; radius: 10 * mk.u
      color: Qt.rgba(0.1, 0.11, 0.08, 0.88)
      Rectangle {
        x: 12 * mk.u; anchors.verticalCenter: parent.verticalCenter
        width: 40 * mk.u; height: width; radius: width / 2
        color: "transparent"; border.width: 2 * mk.u; border.color: mk.it.acc
        Rectangle { anchors.centerIn: parent; width: 26 * mk.u; height: width; radius: width / 2; color: mk.it.sub2; opacity: 0.6 }
      }
      Row {
        x: 60 * mk.u; anchors.verticalCenter: parent.verticalCenter; spacing: 2.5 * mk.u
        Repeater {
          model: 8
          delegate: Rectangle {
            required property int index
            anchors.verticalCenter: parent.verticalCenter
            width: 2 * mk.u; height: (10 + Math.abs(Math.sin(index * 1.3)) * 22) * mk.u; radius: 1 * mk.u
            color: index % 3 === 0 ? mk.it.acc : Qt.rgba(1, 1, 1, 0.35)
          }
        }
      }
    }
    // Horloge empilée (violet)
    Column {
      visible: mk.m === "stack"
      anchors.horizontalCenter: parent.horizontalCenter
      y: 16 * mk.u
      spacing: -24 * mk.u
      Repeater {
        model: [["1", "2"], ["3", "4"]]
        delegate: Row {
          required property var modelData
          required property int index
          anchors.horizontalCenter: parent.horizontalCenter
          Text { text: modelData[0]; font.family: "Google Sans Flex"; font.pixelSize: Math.round(50 * mk.u); font.variableAxes: ({ "wght": 1000, "ROND": 100 }); color: index === 0 ? mk.it.ink : mk.it.sub2 }
          Text { text: modelData[1]; font.family: "Google Sans Flex"; font.pixelSize: Math.round(50 * mk.u); font.variableAxes: ({ "wght": 1000, "ROND": 100 }); color: index === 0 ? mk.it.sub2 : mk.it.ink }
        }
      }
    }
    // Horloge pixel (blanc / jouet)
    Rectangle {
      visible: mk.m === "pixel" || mk.m === "toy"
      x: parent.width - width - 12 * mk.u; y: 22 * mk.u
      width: pxText.implicitWidth + 14 * mk.u; height: pxText.implicitHeight + 6 * mk.u
      radius: mk.m === "toy" ? 6 * mk.u : 4 * mk.u
      color: mk.m === "toy" ? "#fffdf7" : Qt.rgba(1, 1, 1, 0.9)
      border.width: mk.m === "toy" ? 1.5 : 1
      border.color: mk.m === "toy" ? "#1b1030" : "#d6d6d6"
      Text {
        id: pxText
        anchors.centerIn: parent
        text: "12:34"
        font.family: "Silkscreen"; font.pixelSize: Math.round(20 * mk.u); font.weight: Font.Bold
        color: mk.m === "toy" ? mk.it.acc : mk.it.ink
      }
    }
    Text {
      visible: mk.m === "pixel"
      x: 14 * mk.u; y: 24 * mk.u
      text: "SAMEDI"
      font.family: "Syncopate"; font.pixelSize: Math.round(15 * mk.u); font.weight: Font.Bold
      color: mk.it.ink
    }
    // Kanji + jour (sombre)
    Column {
      visible: mk.m === "kanji"
      x: 14 * mk.u; y: 24 * mk.u
      Text { text: "土曜日"; font.family: "Noto Sans CJK JP"; font.pixelSize: Math.round(22 * mk.u); font.weight: Font.Black; color: mk.it.ink }
      Text { text: "SAMEDI"; font.family: "Syncopate"; font.pixelSize: Math.round(8 * mk.u); font.letterSpacing: 3; color: mk.it.sub2 }
    }
    // Cookie (expressive)
    Rectangle {
      visible: mk.m === "cookie"
      x: 14 * mk.u; y: 22 * mk.u
      width: 56 * mk.u; height: width; radius: width / 2
      color: "#3f4759"
      Rectangle { x: parent.width / 2 - 2 * mk.u; y: 10 * mk.u; width: 4 * mk.u; height: parent.height / 2 - 8 * mk.u; radius: 2 * mk.u; color: mk.it.acc }
    }
    // Barres de cava en bas (styles Linux « musique »)
    Row {
      visible: ["pixel", "kanji", "toy", "stack", "cookie"].indexOf(mk.m) >= 0
      anchors.bottom: parent.bottom
      anchors.horizontalCenter: parent.horizontalCenter
      spacing: 2 * mk.u
      Repeater {
        model: 30
        delegate: Rectangle {
          required property int index
          width: 4.6 * mk.u
          height: (4 + Math.abs(Math.sin(index * 0.7) * 14 + Math.sin(index * 0.23) * 8)) * mk.u
          anchors.bottom: parent.bottom
          radius: mk.m === "pixel" || mk.m === "kanji" ? 0 : width / 2
          color: mk.m === "toy" ? ["#ff5fa2", "#ff9f43", "#ffd23f", "#3ddbb4", "#6ec6ff", "#b9a2ff"][Math.floor(index / 5)] : mk.it.acc
          opacity: 0.85
        }
      }
    }
  }
}
