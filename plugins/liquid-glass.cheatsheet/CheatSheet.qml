import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.Commons
import qs.Commons as Commons
import qs.Ui

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
    ["Essentiels", [
      ["⌘ Espace", "Spotlight"],
      ["⌘ Tab", "Changer d'application"],
      ["⌘ Q", "Quitter l'application"],
      ["⌘ W", "Fermer la fenêtre"],
      ["⌘ C · V · X", "Copier · Coller · Couper"],
      ["⌘ A", "Tout sélectionner"],
      ["⌘ ↵", "Terminal"],
      ["⌘ K", "Cet aide-mémoire"]
    ]],
    ["Fenêtres & bureaux", [
      ["⌘ ↑", "Mission Control"],
      ["4 doigts ↑", "Mission Control (pavé)"],
      ["⌘ F3", "Afficher le bureau"],
      ["⌘ ← · →", "Bureau précédent · suivant"],
      ["⌘ 1…0", "Aller au bureau"],
      ["⌘ ⌃ ⇧ 1…0", "Envoyer la fenêtre au bureau"],
      ["⌘ M", "Réduire dans le dock"],
      ["⌘ F", "Plein écran"],
      ["⌘ T", "Flottante / en mosaïque"]
    ]],
    ["Système", [
      ["⌘ ⇧ 3", "Capture plein écran"],
      ["⌘ ⇧ 4", "Capture d'une zone"],
      ["⌘ ⇧ 5", "Menu de capture"],
      ["⌃ ⌘ Q", "Verrouiller"],
      ["⌘ ⇧ L", "Clair / sombre"],
      ["⌘ ⌥ Espace", "Menu Omarchy"],
      ["⌘ Échap", "Menu système"],
      ["⌘ ,", "Agir sur la notification"]
    ]],
    ["Musique & mosaïque", [
      ["⌘ ⌥ M", "Paroles en karaoké"],
      ["⌘ ⇧ M", "Ouvrir Spotify"],
      ["Clic milieu barre", "Lecture / pause"],
      ["Molette barre", "Changer de piste"],
      ["⌘ ⌃ ↑ · ↓", "Focus haut · bas"],
      ["⌘ ⇧ ← → ↑ ↓", "Échanger les fenêtres"],
      ["⌘ ⇧ K", "Tous les raccourcis Omarchy"]
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
    Rectangle { anchors.fill: parent; color: Qt.rgba(0, 0, 0, 0.18) }
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
        text: "Raccourcis clavier"
        font.family: root.uiFont; font.pixelSize: Style.space(20); font.weight: Font.Bold
        color: root.fg
      }
      Text {
        anchors.right: parent.right; anchors.rightMargin: Style.space(28)
        anchors.verticalCenter: title.verticalCenter
        textFormat: Text.PlainText
        text: "⌘ = touche Super"
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
