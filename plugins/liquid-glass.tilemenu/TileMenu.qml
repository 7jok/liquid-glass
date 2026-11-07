import QtQuick
import "Mac.js" as Mac
import Quickshell
import Quickshell.Wayland
import qs.Commons
import qs.Commons as Commons
import qs.Ui
import "T.js" as T

// Liquid Glass — menu du bouton vert (barres de titre hyprbars), façon Tahoe :
// Plein écran, Agrandir, « Déplacer et redimensionner » (moitiés et quarts en
// mini-écrans), Remplir, Centrer, Toujours au-dessus, bureau suivant, Réduire.
// Ouvert par `liquid-glass tile-menu <adresse>` (payload { addr, x, y } en px
// logiques), il apparaît sous le curseur et se ferme au clic à côté ou sur Échap.
Item {
  id: root

  property var shell: null
  property var manifest: null
  property bool opened: false
  property string addr: ""
  property real px: 0
  property real py: 0
  property string hint: ""

  readonly property bool dark: Commons.Color.menu.background.hslLightness < 0.5
  readonly property color fg: Commons.Color.menu.text

  function open(payloadJson) {
    var p = {}
    try { p = JSON.parse(payloadJson || "{}") } catch (e) { p = {} }
    if (!/^0x[0-9a-fA-F]+$/.test(String(p.addr || ""))) return
    addr = p.addr
    px = Number(p.x) || 0
    py = Number(p.y) || 0
    hint = ""
    opened = true
  }
  function close() { opened = false }
  function dismiss() {
    opened = false
    if (shell && typeof shell.hide === "function") shell.hide((manifest && manifest.id) || "liquid-glass.tilemenu")
  }
  function act(action) {
    var a = root.addr
    dismiss()
    if (a !== "") Quickshell.execDetached(["liquid-glass", "window", action, a])
  }

  // Moitiés puis quarts : [action, libellé, x, y, w, h] en fractions de l'écran.
  readonly property var tiles: [
    ["left", "Moitié gauche", 0, 0, 0.5, 1], ["right", "Moitié droite", 0.5, 0, 0.5, 1],
    ["top", "Moitié haute", 0, 0, 1, 0.5], ["bottom", "Moitié basse", 0, 0.5, 1, 0.5],
    ["top-left", "Quart haut gauche", 0, 0, 0.5, 0.5], ["top-right", "Quart haut droit", 0.5, 0, 0.5, 0.5],
    ["bottom-left", "Quart bas gauche", 0, 0.5, 0.5, 0.5], ["bottom-right", "Quart bas droit", 0.5, 0.5, 0.5, 0.5]
  ]

  OverlayWindow {
    id: win
    shown: root.opened
    WlrLayershell.namespace: "liquid-glass-tilemenu"

    Item {
      anchors.fill: parent
      focus: true
      Keys.onEscapePressed: root.dismiss()
    }
    MouseArea { anchors.fill: parent; acceptedButtons: Qt.AllButtons; onPressed: root.dismiss() }

    Rectangle {
      id: card
      width: Mac.menu.minWidth + 40
      height: col.implicitHeight + Mac.menu.padV * 2
      x: Math.max(8, Math.min(win.width - width - 8, root.px - 16))
      y: Math.max(8, Math.min(win.height - height - 8, root.py + 12))
      radius: Mac.menu.radius
      color: Qt.rgba(Commons.Color.menu.background.r, Commons.Color.menu.background.g, Commons.Color.menu.background.b, root.dark ? 0.78 : 0.74)
      border.width: 1
      border.color: Qt.rgba(1, 1, 1, root.dark ? 0.14 : 0.6)
      // Sort du bouton vert avec un ressort exagéré.
      transformOrigin: Item.TopLeft
      scale: win.contentRevealed ? 1 : 0.6
      opacity: win.contentRevealed ? 1 : 0
      Behavior on scale { enabled: !Style.reduceMotion; SpringAnimation { spring: 4.6; damping: 0.42; epsilon: 0.003 } }
      Behavior on opacity { NumberAnimation { duration: 110 } }
      MouseArea { anchors.fill: parent; acceptedButtons: Qt.AllButtons }

      Column {
        id: col
        x: Mac.menu.padV; y: Mac.menu.padV
        width: parent.width - Mac.menu.padV * 2

        MenuItem { label: "Plein écran"; shortcut: "⌃⌘F"; onChosen: root.act("fullscreen") }
        MenuItem { label: T.t("Agrandir"); onChosen: root.act("zoom") }
        Sep {}
        Text {
          x: Mac.menu.inset + 4
          height: Mac.menu.row
          verticalAlignment: Text.AlignVCenter
          textFormat: Text.PlainText
          text: root.hint !== "" ? root.hint : "Déplacer et redimensionner"
          font.family: "Inter"; font.pixelSize: Mac.font.subheadline; font.weight: Font.DemiBold
          color: root.fg; opacity: root.hint !== "" ? 0.85 : Mac.label.secondary
        }
        Grid {
          x: Mac.menu.inset + 4
          columns: 4
          spacing: 8
          bottomPadding: 6
          Repeater {
            model: root.tiles
            delegate: Rectangle {
              id: tile
              required property var modelData
              width: 40; height: 26
              radius: 5
              color: tileMouse.containsMouse ? Commons.Color.accent : Qt.rgba(root.fg.r, root.fg.g, root.fg.b, 0.08)
              border.width: 1
              border.color: Qt.rgba(root.fg.r, root.fg.g, root.fg.b, tileMouse.containsMouse ? 0 : 0.28)
              scale: tileMouse.pressed ? 0.9 : (tileMouse.containsMouse ? 1.08 : 1)
              Behavior on scale { SpringAnimation { spring: 6; damping: 0.4 } }
              Behavior on color { ColorAnimation { duration: 90 } }
              // Zone occupée par la fenêtre, dessinée dans le mini-écran.
              Rectangle {
                x: 3 + (tile.width - 6) * tile.modelData[2]
                y: 3 + (tile.height - 6) * tile.modelData[3]
                width: (tile.width - 6) * tile.modelData[4] - 1
                height: (tile.height - 6) * tile.modelData[5] - 1
                radius: 2
                color: tileMouse.containsMouse ? "white" : root.fg
                opacity: tileMouse.containsMouse ? 0.95 : 0.55
              }
              MouseArea {
                id: tileMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onContainsMouseChanged: root.hint = containsMouse ? tile.modelData[1] : (root.hint === tile.modelData[1] ? "" : root.hint)
                onClicked: root.act(tile.modelData[0])
              }
            }
          }
        }
        Sep {}
        MenuItem { label: "Remplir"; shortcut: "⌃⌥F"; onChosen: root.act("fill") }
        MenuItem { label: "Centrer"; shortcut: "⌃⌥C"; onChosen: root.act("center") }
        MenuItem { label: "Toujours au-dessus"; onChosen: root.act("pin") }
        Sep {}
        MenuItem { label: "Déplacer vers le bureau suivant"; onChosen: root.act("next-desktop") }
        MenuItem { label: "Réduire"; shortcut: "⌘M"; onChosen: root.act("minimize") }
      }
    }
  }

  component Sep: Item {
    width: parent ? parent.width : 0
    height: Mac.menu.separatorMargin * 2 + 1
    Rectangle { anchors.verticalCenter: parent.verticalCenter; x: Mac.menu.inset + 4; width: parent.width - x * 2; height: 1; color: root.fg; opacity: 0.12 }
  }

  component MenuItem: Item {
    id: item
    property string label: ""
    property string shortcut: ""
    property bool flashing: false
    property bool flashOn: false
    signal chosen()
    width: parent ? parent.width : 0
    height: Mac.menu.row
    readonly property bool hot: flashing ? flashOn : itemMouse.containsMouse
    Rectangle { anchors.fill: parent; radius: Mac.menu.selRadius; color: Commons.Color.accent; opacity: item.hot ? 0.92 : 0 }
    Text {
      x: Mac.menu.checkColumn + 2
      anchors.verticalCenter: parent.verticalCenter
      textFormat: Text.PlainText
      text: item.label
      font.family: "Inter"; font.pixelSize: Mac.font.body; font.letterSpacing: Mac.tracking(Mac.font.body)
      color: item.hot ? "white" : root.fg
    }
    Text {
      anchors.right: parent.right; anchors.rightMargin: Mac.menu.padRight - Mac.menu.padV + 4
      anchors.verticalCenter: parent.verticalCenter
      visible: item.shortcut !== ""
      textFormat: Text.PlainText
      text: item.shortcut
      font.family: "Inter"; font.pixelSize: Mac.font.body
      color: item.hot ? "white" : root.fg
      opacity: item.hot ? 0.9 : Mac.label.secondary
    }
    // Clignotement de l'élément choisi avant la fermeture, comme macOS.
    SequentialAnimation {
      id: flash
      PropertyAction { target: item; property: "flashing"; value: true }
      PropertyAction { target: item; property: "flashOn"; value: false }
      PauseAnimation { duration: 60 }
      PropertyAction { target: item; property: "flashOn"; value: true }
      PauseAnimation { duration: 70 }
      ScriptAction { script: { item.flashing = false; item.chosen() } }
    }
    MouseArea { id: itemMouse; anchors.fill: parent; hoverEnabled: true; onClicked: flash.restart() }
  }
}
