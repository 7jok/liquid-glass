import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets
import "T.js" as T

// Lanceur d'applications (⌘Espace) de chaque bureau Linux, à la place de celui
// d'Omarchy. Même moteur, allure propre au style :
//   blanc  : fiche blanche, liseré d'encre, liste en mono avec « › »
//   sombre : invite de terminal « ❯ », ligne choisie en vidéo inverse
//   jouet  : gros contour, ombre dure, tuiles bonbon en grille
//   violet / expressive : pilule de recherche Material, grille d'icônes rondes
//   mono   : liste qui monte du bas, soudée au cadre noir (caelestia)
//   foret  : panneau olive, grille, police mono, accent tilleul
// Taper pour filtrer, ↑↓←→ pour choisir, Entrée pour lancer, Échap pour fermer.
PanelWindow {
  id: win
  property var service: null
  readonly property var s: service

  color: "transparent"
  anchors { top: true; bottom: true; left: true; right: true }
  exclusionMode: ExclusionMode.Ignore
  WlrLayershell.layer: WlrLayer.Overlay
  WlrLayershell.namespace: "liquid-glass-linux-launcher"
  WlrLayershell.keyboardFocus: s.kbd(true)

  readonly property string st: s.style
  readonly property bool grid: ["jouet", "violet", "expressive", "foret"].indexOf(st) >= 0
  readonly property bool term: st === "sombre"
  readonly property bool toy: st === "jouet"
  readonly property bool monoStyle: st === "mono"
  readonly property int cols: st === "foret" ? 6 : 5
  readonly property string font: st === "foret" || st === "blanc" || st === "sombre" ? "JetBrainsMono Nerd Font" : s.sansFont
  readonly property color panelBg: monoStyle ? s.monoFrame : (toy ? s.surfaceMid : s.alpha(s.surfaceMid, st === "violet" || st === "expressive" ? 0.94 : 0.98))
  readonly property color ink: monoStyle ? s.colOnSurface : s.colOnSurface
  readonly property color sub: monoStyle ? s.colOnSurfaceVariant : s.colOnSurfaceVariant
  readonly property color acc: monoStyle ? s.primary : s.primary
  readonly property color accInk: s.colOnPrimary
  readonly property int radius: monoStyle ? 22 : (toy ? 20 : (st === "blanc" ? 10 : (st === "sombre" ? 4 : 26)))

  property string query: ""
  readonly property var results: s.apps(query).slice(0, grid ? cols * 4 : 9)
  property int sel: 0
  onQueryChanged: sel = 0
  property bool revealed: false
  Component.onCompleted: { revealed = true; input.forceActiveFocus() }

  function move(d) { if (results.length) sel = Math.max(0, Math.min(results.length - 1, sel + d)) }
  MouseArea { anchors.fill: parent; onClicked: s.closeAll() }

  Item {
    id: box
    width: grid ? cols * 104 + 40 : 520
    height: (grid ? 70 + Math.max(1, Math.ceil(results.length / cols)) * 104 + 20 : 70 + Math.max(1, results.length) * (term ? 30 : 44) + 18)
    x: (win.width - width) / 2 + (monoStyle ? 22 : 0)
    // Mono : monte du bas (soudé au cadre) ; autres : centré un peu haut, petit rebond.
    y: monoStyle ? win.height - 7 - (win.revealed ? height : 0) : win.height * 0.2 + (win.revealed ? 0 : 24)
    opacity: monoStyle || win.revealed ? 1 : 0
    Behavior on y { NumberAnimation { duration: monoStyle ? 340 : 420; easing.type: monoStyle ? Easing.OutCubic : Easing.OutBack } }
    Behavior on opacity { NumberAnimation { duration: 160 } }
    Behavior on height { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }

    // ombre (dure pour Jouet, douce sinon, aucune pour Mono)
    Rectangle { visible: toy || st === "blanc"; x: 7; y: 7; width: parent.width; height: parent.height; radius: win.radius; color: toy ? "#1b1030" : s.colOnSurface }
    RectangularShadow { visible: !toy && !monoStyle && st !== "blanc"; anchors.fill: body; radius: win.radius; blur: 36; offset.y: 12; color: Qt.rgba(0, 0, 0, s.darkSkin ? 0.55 : 0.18) }
    Rectangle {
      id: body
      anchors.fill: parent
      radius: win.radius
      color: win.panelBg
      border.width: toy ? 3 : (st === "blanc" || st === "sombre" ? 1 : 0)
      border.color: toy ? "#1b1030" : s.alpha(win.ink, st === "blanc" ? 0.9 : 0.35)
      // Mono : bas carré, collé au cadre
      Rectangle { visible: monoStyle; anchors.bottom: parent.bottom; width: parent.width; height: win.radius; color: win.panelBg }
      MouseArea { anchors.fill: parent }
    }

    // ---------------------------------------------------- recherche
    Rectangle {
      id: field
      x: 18; y: monoStyle ? parent.height - 60 : 16
      width: parent.width - 36; height: 40
      radius: term ? 2 : (st === "blanc" ? 6 : (toy ? 14 : 20))
      color: term ? "transparent" : (monoStyle ? s.surfaceMid : (toy ? s.surfaceHighest : s.alpha(win.ink, 0.07)))
      border.width: toy ? 2.5 : (st === "blanc" ? 1 : 0)
      border.color: toy ? "#1b1030" : s.alpha(win.ink, 0.5)
      Text {
        id: prompt
        x: 14; anchors.verticalCenter: parent.verticalCenter
        text: term ? "❯" : (st === "blanc" ? "›" : "")
        visible: text !== ""
        font.family: win.font; font.pixelSize: 18; font.weight: Font.Bold; color: win.acc
      }
      MIcon { visible: !prompt.visible; x: 14; anchors.verticalCenter: parent.verticalCenter; icon: "search"; size: 20; color: win.sub }
      TextInput {
        id: input
        x: 42; anchors.verticalCenter: parent.verticalCenter; width: parent.width - 56
        font.family: win.font; font.pixelSize: 15
        font.weight: toy ? Font.Bold : Font.Normal
        color: win.ink; selectionColor: win.acc; clip: true
        cursorDelegate: Rectangle { width: term ? 9 : 2; color: win.acc; opacity: input.cursorVisible ? (term ? 0.8 : 1) : 0 }
        onTextChanged: win.query = text
        Text {
          visible: parent.text === ""
          text: term ? T.t("lancer…") : (monoStyle ? T.t("Tapez « > » pour les commandes") : (st === "foret" ? T.t("Rechercher une appli…") : T.t("Rechercher")))
          font: parent.font; color: win.sub
        }
        Keys.onEscapePressed: { if (text !== "") text = ""; else s.closeAll() }
        Keys.onDownPressed: win.move(win.grid ? win.cols : 1)
        Keys.onUpPressed: win.move(win.grid ? -win.cols : -1)
        Keys.onLeftPressed: function(e) { if (win.grid) win.move(-1); else e.accepted = false }
        Keys.onRightPressed: function(e) { if (win.grid) win.move(1); else e.accepted = false }
        Keys.onTabPressed: win.move(1)
        Keys.onReturnPressed: {
          var t = text.trim()
          if (t.charAt(0) === ">" && t.length > 1) { Quickshell.execDetached(["sh", "-c", t.slice(1)]); s.closeAll(); return }
          if (win.results.length) s.launch(win.results[win.sel])
        }
      }
    }

    // ---------------------------------------------------- liste
    Column {
      visible: !win.grid
      x: 12; y: monoStyle ? 12 : 66
      width: parent.width - 24
      spacing: term ? 0 : 2
      Repeater {
        model: win.grid ? [] : win.results
        delegate: Rectangle {
          id: row
          required property var modelData
          required property int index
          readonly property bool cur: win.sel === index
          width: parent.width; height: term ? 30 : 42
          radius: term ? 0 : (st === "blanc" ? 6 : 14)
          color: cur ? (term ? win.ink : (monoStyle ? s.surfaceHigh : s.alpha(win.acc, st === "blanc" ? 0.08 : 0.16))) : (rma.containsMouse ? s.alpha(win.ink, 0.05) : "transparent")
          Text {
            visible: st === "blanc" || term
            x: 10; anchors.verticalCenter: parent.verticalCenter
            text: row.cur ? (term ? "▶" : "›") : " "
            font.family: win.font; font.pixelSize: 13; font.weight: Font.Bold
            color: term && row.cur ? s.surface : win.acc
          }
          IconImage {
            visible: !term
            x: st === "blanc" ? 30 : 12; anchors.verticalCenter: parent.verticalCenter
            implicitSize: 26; source: s.appIcon(row.modelData); asynchronous: true
            layer.enabled: monoStyle || st === "blanc"
            layer.effect: MultiEffect { saturation: -1 }
          }
          Text {
            x: term ? 30 : (st === "blanc" ? 68 : 50); anchors.verticalCenter: parent.verticalCenter
            width: parent.width - x - 12; elide: Text.ElideRight
            text: term ? s.appName(row.modelData).toLowerCase().replace(/\s+/g, "-") : s.appName(row.modelData)
            font.family: win.font; font.pixelSize: term ? 13 : 14
            font.weight: row.cur ? Font.Bold : Font.Normal
            color: term && row.cur ? s.surface : win.ink
          }
          Text {
            visible: !term && row.cur
            anchors.right: parent.right; anchors.rightMargin: 14; anchors.verticalCenter: parent.verticalCenter
            text: "↵"; font.family: win.font; font.pixelSize: 13; color: win.sub
          }
          MouseArea { id: rma; anchors.fill: parent; hoverEnabled: true; onEntered: win.sel = row.index; onClicked: s.launch(row.modelData) }
        }
      }
    }

    // ---------------------------------------------------- grille
    Grid {
      visible: win.grid
      x: 20; y: 72
      columns: win.cols
      Repeater {
        model: win.grid ? win.results : []
        delegate: Item {
          id: tile
          required property var modelData
          required property int index
          readonly property bool cur: win.sel === index
          width: 104; height: 104
          Rectangle {
            anchors.centerIn: parent
            width: 92; height: 92
            radius: toy ? 18 : (st === "foret" ? 14 : 28)
            color: tile.cur ? (toy ? s.rainbow[tile.index % 6] : s.alpha(win.acc, 0.18)) : (gma.containsMouse ? s.alpha(win.ink, 0.06) : "transparent")
            border.width: toy && tile.cur ? 2.5 : 0
            border.color: "#1b1030"
            scale: tile.cur ? 1.04 : 1
            Behavior on scale { NumberAnimation { duration: 160; easing.type: Easing.OutBack } }
          }
          Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter; y: 12
            width: 50; height: 50; radius: st === "violet" || st === "expressive" ? 25 : (toy ? 14 : 12)
            color: st === "violet" || st === "expressive" ? s.alpha(win.acc, 0.14) : "transparent"
            IconImage { anchors.centerIn: parent; implicitSize: 38; source: s.appIcon(tile.modelData); asynchronous: true }
          }
          Text {
            anchors.horizontalCenter: parent.horizontalCenter; y: 68
            width: 96; horizontalAlignment: Text.AlignHCenter; elide: Text.ElideRight
            text: s.appName(tile.modelData)
            font.family: win.font; font.pixelSize: st === "foret" ? 10 : 11
            font.weight: tile.cur || toy ? Font.Bold : Font.Normal
            color: toy && tile.cur ? "#1b1030" : win.ink
          }
          MouseArea { id: gma; anchors.fill: parent; hoverEnabled: true; onEntered: win.sel = tile.index; onClicked: s.launch(tile.modelData) }
        }
      }
    }
    Text {
      visible: win.results.length === 0
      anchors.horizontalCenter: parent.horizontalCenter
      y: monoStyle ? 24 : 80
      text: win.query.charAt(0) === ">" ? T.t("Entrée pour lancer la commande") : T.t("Aucune application")
      font.family: win.font; font.pixelSize: 13; color: win.sub
    }
  }
}
