import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.Commons
import qs.Commons as Commons
import qs.Ui
import "T.js" as T

// Liquid Glass — aide-mémoire des raccourcis (⌘K). Échap ou clic pour fermer.
// La liste reflète hypr/liquid-glass-bindings.lua ; ⌘⇧K ouvre la liste complète d'Omarchy.
Item {
  id: root

  property var shell: null
  property var manifest: null
  property bool opened: false

  readonly property string uiFont: "Inter"
  readonly property color fg: Commons.Color.menu.text

  // [groupe, [[touches, action], …]]
  readonly property var groups: [
    [T.t("Essentiels"), [
      [T.t("⌘ Espace"), "Spotlight"],
      ["⌘ Tab", T.t("Changer d'application")],
      ["⌘ Q", T.t("Quitter l'application")],
      ["⌘ W", T.t("Fermer la fenêtre")],
      ["⌘ C · V · X", T.t("Copier · Coller · Couper")],
      ["⌘ A", T.t("Tout sélectionner")],
      ["⌘ ↵", T.t("Terminal")],
      ["⌘ K", T.t("Cet aide-mémoire")]
    ]],
    [T.t("Fenêtres & bureaux"), [
      ["⌘ ↑", "Mission Control"],
      [T.t("4 doigts ↑"), "Mission Control (pavé)"],
      ["⌘ ↓", T.t("App Exposé (fenêtres de l'app)")],
      [T.t("4 doigts ↓"), T.t("App Exposé (pavé)")],
      [T.t("⌘ ⇧ Espace"), T.t("Bureau Linux ⇄ Mac (profil)")],
      ["⌘ F3", T.t("Afficher le bureau")],
      ["⌘ ← · →", T.t("Bureau précédent · suivant")],
      ["⌘ 1…0", T.t("Aller au bureau")],
      ["⌘ ⌃ ⇧ 1…0", T.t("Envoyer la fenêtre au bureau")],
      ["⌘ M", T.t("Réduire dans le dock")],
      ["⌘ F", T.t("Plein écran")],
      ["⌘ T", T.t("Flottante / en mosaïque")]
    ]],
    [T.t("Système"), [
      ["⌘ ⇧ 3", T.t("Capture plein écran")],
      ["⌘ ⇧ 4", T.t("Capture d'une zone")],
      ["⌘ ⇧ 5", T.t("Menu de capture")],
      ["⌃ ⌘ Q", T.t("Verrouiller")],
      ["⌘ ⇧ L", "Clair / sombre"],
      [T.t("⌘ ⌥ Espace"), T.t("Menu Omarchy")],
      ["⌘ Échap", T.t("Réglages")],
      ["⌘ ⇧ Échap", T.t("Menu système")],
      ["⌘ ,", T.t("Agir sur la notification")]
    ]],
    [T.t("Musique & mosaïque"), [
      ["⌘ ⌥ M", T.t("Paroles en karaoké")],
      ["⌘ ⇧ M", T.t("Ouvrir Spotify")],
      [T.t("Clic milieu barre"), "Lecture / pause"],
      [T.t("Molette barre"), T.t("Changer de piste")],
      ["⌘ ⌃ ↑ · ↓", T.t("Focus haut · bas")],
      ["⌘ ⇧ ← → ↑ ↓", T.t("Échanger les fenêtres")],
      ["⌘ ⇧ K", T.t("Tous les raccourcis Omarchy")]
    ]]
  ]

  function open(payloadJson) { opened = true }
  function close() { opened = false }
  function dismiss() {
    opened = false
    if (shell && typeof shell.hide === "function") shell.hide((manifest && manifest.id) || "liquid-glass.cheatsheet")
  }
  function toggle() { if (opened) dismiss(); else open("") }

  ShellIpc {
    target: "liquid-glass.cheatsheet"
    function toggle(): void { if (root.opened) root.dismiss(); else if (root.shell) root.shell.summon((root.manifest && root.manifest.id) || "liquid-glass.cheatsheet", "") }
  }

  OverlayWindow {
    id: win
    shown: root.opened
    WlrLayershell.namespace: "liquid-glass-cheatsheet"

    Item {
      id: keys
      anchors.fill: parent
      focus: true
      Keys.onPressed: function(ev) { root.dismiss(); ev.accepted = true }
    }
    // Pas de voile plein écran (macOS n'en met pas ; il ferait flouter tout le bureau).
    MouseArea { anchors.fill: parent; onClicked: root.dismiss() }

    BorderSurface {
      id: card
      anchors.centerIn: parent
      width: Math.min(parent.width - 48, cols.implicitWidth + Style.space(56))
      height: cols.implicitHeight + title.height + Style.space(72)
      radius: Style.space(24)
      color: Commons.Color.menu.background
      borderSpec: Border.surfaceSpec("menu", "border", Commons.Color.menu.border, 1)
      scale: win.contentRevealed ? 1 : 0.95
      Behavior on scale { SpringAnimation { spring: 4; damping: 0.42; epsilon: 0.002 } }

      Text {
        id: title
        x: Style.space(28); y: Style.space(22)
        textFormat: Text.PlainText
        text: T.t("Raccourcis clavier")
        font.family: root.uiFont; font.pixelSize: Style.space(20); font.weight: Font.Bold
        color: root.fg
      }
      Text {
        anchors.right: parent.right; anchors.rightMargin: Style.space(28)
        anchors.verticalCenter: title.verticalCenter
        textFormat: Text.PlainText
        text: T.t("⌘ = touche Super")
        font.family: root.uiFont; font.pixelSize: Style.space(12)
        color: root.fg; opacity: 0.5
      }

      Row {
        id: cols
        x: Style.space(28)
        anchors.top: title.bottom
        anchors.topMargin: Style.space(18)
        spacing: Style.space(30)

        Repeater {
          model: root.groups
          delegate: Column {
            id: group
            required property var modelData
            spacing: Style.space(7)
            width: Style.space(250)
            Text {
              textFormat: Text.PlainText
              text: group.modelData[0]
              font.family: root.uiFont; font.pixelSize: Style.space(12); font.weight: Font.DemiBold
              color: Commons.Color.accent
            }
            Repeater {
              model: group.modelData[1]
              delegate: Item {
                required property var modelData
                width: group.width
                height: Style.space(24)
                Rectangle {
                  id: keycap
                  anchors.verticalCenter: parent.verticalCenter
                  width: Math.max(Style.space(30), keyText.implicitWidth + Style.space(14))
                  height: Style.space(22)
                  radius: Style.space(6)
                  color: Qt.rgba(root.fg.r, root.fg.g, root.fg.b, 0.08)
                  border.width: 1
                  border.color: Qt.rgba(root.fg.r, root.fg.g, root.fg.b, 0.14)
                  Text {
                    id: keyText
                    anchors.centerIn: parent
                    textFormat: Text.PlainText
                    text: modelData[0]
                    font.family: root.uiFont; font.pixelSize: Style.space(11.5); font.weight: Font.Medium
                    color: root.fg
                  }
                }
                Text {
                  anchors.left: keycap.right; anchors.leftMargin: Style.space(10)
                  anchors.right: parent.right
                  anchors.verticalCenter: parent.verticalCenter
                  textFormat: Text.PlainText
                  text: modelData[1]
                  elide: Text.ElideRight
                  font.family: root.uiFont; font.pixelSize: Style.space(12.5)
                  color: root.fg; opacity: 0.85
                }
              }
            }
          }
        }
      }
    }
  }

  Connections {
    target: win
    function onContentRevealedChanged() { if (win.contentRevealed) keys.forceActiveFocus() }
  }
}
