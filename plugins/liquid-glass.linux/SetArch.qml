import QtQuick
import QtQuick.Effects
import "T.js" as T

// Réglages Arch : la « Configuration du système » de KDE Plasma. Barre latérale
// avec champ de recherche et entrées rangées sous des en-têtes gris, page en
// formulaire (libellés alignés à droite, contrôles à gauche), cases Breeze,
// listes déroulantes, et en bas « Aide · Par défaut · Réinitialiser · Appliquer ».
// Breeze sombre, accent bleu Arch.
SetWin {
  id: w
  veil: Qt.rgba(0, 0, 0, 0.3)
  readonly property color winBg: "#202326"
  readonly property color side: "#292c30"
  readonly property color ink: "#fcfcfc"
  readonly property color dim: "#a1a9b1"
  readonly property color acc: s.primary
  readonly property string font: s.userFont || "Noto Sans"
  property string query: ""
  readonly property var look: ({ font: w.font, head: w.font, px: 13, ink: w.ink, sub: w.dim, acc: w.acc, accInk: "#ffffff",
    tile: "#31363b", bcol: "#4d4d4d", radius: 3, border: 1, toggle: "breeze", slider: "line", chip: "combo", button: "box",
    headColor: w.ink, headPx: 14, headWeight: Font.DemiBold, rowPad: 6, labelW: 230, popBg: "#31363b" })
  readonly property var sections: [[T.t("Général"), ["home", "style", "look"]], [T.t("Matériel"), ["net", "bt", "sound", "screen", "power"]], [T.t("Système"), ["system"]]]
  function pageOf(id) { for (var i = 0; i < w.core.pages.length; i++) if (w.core.pages[i][0] === id) return w.core.pages[i]; return null }
  function matches(id) { var p = pageOf(id); return p && (w.query === "" || p[1].toLowerCase().indexOf(w.query.toLowerCase()) >= 0) }

  component KBtn: Rectangle {
    id: kb
    property string text: ""
    property string icon: ""
    property bool primary: false
    signal clicked()
    width: kr.implicitWidth + 22; height: 30; radius: 3
    color: km.pressed ? "#1d2023" : (kb.primary ? s.alpha(w.acc, km.containsMouse ? 0.4 : 0.25) : (km.containsMouse ? "#3a4046" : "#31363b"))
    border.width: 1; border.color: kb.primary || km.containsMouse ? w.acc : "#4d4d4d"
    Row { id: kr; anchors.centerIn: parent; spacing: 6
      MIcon { visible: kb.icon !== ""; anchors.verticalCenter: parent.verticalCenter; icon: kb.icon; size: 16; color: w.ink }
      Text { anchors.verticalCenter: parent.verticalCenter; text: kb.text; font.family: w.font; font.pixelSize: 13; color: w.ink } }
    MouseArea { id: km; anchors.fill: parent; hoverEnabled: true; onClicked: kb.clicked() }
  }

  Item {
    id: win
    width: Math.min(parent.width - 80, 1040); height: Math.min(parent.height - 80, 700)
    anchors.centerIn: parent
    opacity: w.revealed ? 1 : 0
    scale: w.revealed ? 1 : 0.97
    Behavior on opacity { NumberAnimation { duration: 150 } }
    Behavior on scale { NumberAnimation { duration: 200 } }
    MouseArea { anchors.fill: parent }
    RectangularShadow { anchors.fill: frame; radius: 5; blur: 24; offset.y: 5; color: Qt.rgba(0, 0, 0, 0.55) }
    Rectangle {
      id: frame; anchors.fill: parent; radius: 5; color: w.winBg; border.width: 1; border.color: "#3b4045"; clip: true
      // barre de titre Breeze
      Rectangle {
        width: parent.width; height: 32; color: "#2a2e32"; radius: 5
        Rectangle { y: 20; width: parent.width; height: 12; color: "#2a2e32" }
        MIcon { x: 10; anchors.verticalCenter: parent.verticalCenter; icon: "settings"; size: 16; color: w.acc }
        Text { anchors.centerIn: parent; text: w.core.pageInfo[1] + " — " + T.t("Configuration du système"); font.family: w.font; font.pixelSize: 13; color: w.ink }
        Row {
          anchors.right: parent.right; anchors.rightMargin: 8; anchors.verticalCenter: parent.verticalCenter; spacing: 8
          Repeater {
            model: ["keyboard_arrow_down", "keyboard_arrow_up", "close"]
            delegate: Rectangle {
              required property string modelData
              required property int index
              width: 18; height: 18; radius: 9
              color: bx.containsMouse ? (index === 2 ? "#da4453" : "#4d5359") : "transparent"
              MIcon { anchors.centerIn: parent; icon: parent.modelData; size: 14; color: w.ink }
              MouseArea { id: bx; anchors.fill: parent; hoverEnabled: true; onClicked: if (parent.index === 2) w.core.close() }
            }
          }
        }
      }
      // barre latérale
      Rectangle {
        y: 32; width: 260; height: parent.height - 32; color: w.side
        Rectangle { anchors.right: parent.right; width: 1; height: parent.height; color: "#3b4045" }
        Rectangle {
          x: 8; y: 8; width: parent.width - 17; height: 32; radius: 3; color: "#1b1e20"; border.width: 1; border.color: srch.activeFocus ? w.acc : "#4d4d4d"
          MIcon { x: 8; anchors.verticalCenter: parent.verticalCenter; icon: "search"; size: 16; color: w.dim }
          TextInput {
            id: srch
            x: 30; width: parent.width - 38; anchors.verticalCenter: parent.verticalCenter
            font.family: w.font; font.pixelSize: 13; color: w.ink
            onTextChanged: w.query = text
            Text { visible: !parent.text; text: T.t("Rechercher…"); font: parent.font; color: w.dim }
          }
        }
        Flickable {
          y: 48; width: parent.width - 1; height: parent.height - 48; clip: true
          contentHeight: sideCol.implicitHeight + 10
          Column {
            id: sideCol
            width: parent.width
            Repeater {
              model: w.sections
              delegate: Column {
                id: sec
                required property var modelData
                width: sideCol.width
                Text { x: 12; height: 30; verticalAlignment: Text.AlignBottom; bottomPadding: 4; text: sec.modelData[0]; font.family: w.font; font.pixelSize: 12; color: w.dim }
                Repeater {
                  model: sec.modelData[1].filter(function(id) { return w.matches(id) })
                  delegate: Rectangle {
                    id: ke
                    required property string modelData
                    readonly property var pg: w.pageOf(modelData)
                    readonly property bool cur: w.core.page === modelData
                    width: sec.width; height: 36
                    color: cur ? s.alpha(w.acc, 0.3) : (em.containsMouse ? s.alpha(w.acc, 0.12) : "transparent")
                    Rectangle { visible: ke.cur; width: parent.width; height: 1; color: w.acc }
                    Rectangle { visible: ke.cur; y: parent.height - 1; width: parent.width; height: 1; color: w.acc }
                    Row { x: 14; anchors.verticalCenter: parent.verticalCenter; spacing: 10
                      MIcon { anchors.verticalCenter: parent.verticalCenter; icon: ke.pg ? ke.pg[2] : "settings"; size: 20; color: w.ink }
                      Text { anchors.verticalCenter: parent.verticalCenter; text: ke.pg ? ke.pg[1] : ""; font.family: w.font; font.pixelSize: 13; color: w.ink } }
                    MIcon { anchors.right: parent.right; anchors.rightMargin: 10; anchors.verticalCenter: parent.verticalCenter; icon: "chevron_right"; size: 16; color: w.dim }
                    MouseArea { id: em; anchors.fill: parent; hoverEnabled: true; onClicked: w.core.page = ke.modelData }
                  }
                }
              }
            }
          }
        }
      }
      // page en formulaire
      Text { x: 284; y: 48; text: w.core.pageInfo[1]; font.family: w.font; font.pixelSize: 20; color: w.ink }
      Rectangle { x: 260; y: 88; width: parent.width - 260; height: 1; color: "#3b4045" }
      SetList {
        x: 290; y: 102; width: parent.width - 290 - 30; height: parent.height - y - 60
        core: w.core; look: w.look
        mode: "plain"; sepColor: "transparent"
      }
      // pied : Aide · Par défaut · Réinitialiser · Appliquer
      Rectangle {
        x: 260; y: parent.height - 52; width: parent.width - 260; height: 52; color: "#2a2e32"
        Rectangle { width: parent.width; height: 1; color: "#3b4045" }
        Row {
          x: 12; anchors.verticalCenter: parent.verticalCenter; spacing: 6
          KBtn { icon: "help"; text: T.t("Aide"); onClicked: w.core.run(["xdg-open", "https://wiki.archlinux.org"]) }
          KBtn { icon: "restart_alt"; text: T.t("Par défaut"); onClicked: w.core.run(["liquid-glass", "profile", w.core.st + ":" + (w.core.tones.length ? w.core.tones[0][0] : "")]) }
        }
        Row {
          anchors.right: parent.right; anchors.rightMargin: 12; anchors.verticalCenter: parent.verticalCenter; spacing: 6
          KBtn { icon: "undo"; text: T.t("Réinitialiser"); onClicked: w.core.pending = ({}) }
          KBtn { icon: "check"; text: T.t("Appliquer"); primary: true; onClicked: w.core.close() }
        }
      }
    }
  }
}
