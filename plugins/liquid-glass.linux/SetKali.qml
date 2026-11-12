import QtQuick
import QtQuick.Effects
import "T.js" as T

// Réglages Kali : le « Gestionnaire de paramètres » de Xfce. L'accueil est une
// grille compacte de petites icônes avec leur nom, en catégories ; chaque page
// s'ouvre comme une boîte de dialogue Xfce : onglets rectangulaires en
// « classeur », cases à cocher, et en bas « Aide », « Tous les paramètres »,
// « Fermer ». Gris bleuté sombre de Kali, accent bleu dragon.
SetWin {
  id: w
  veil: Qt.rgba(0, 0, 0, 0.25)
  readonly property color winBg: "#23252e"
  readonly property color panel: "#1b1d24"
  readonly property color ink: "#e6e8ee"
  readonly property color dim: "#9aa0ad"
  readonly property color acc: s.primary
  readonly property string font: s.userFont || "Cantarell"
  readonly property bool grid: w.core.page === "home"
  readonly property var look: ({ font: w.font, head: w.font, px: 12, ink: w.ink, sub: w.dim, acc: w.acc, accInk: "#ffffff",
    tile: "#2c2f3a", bcol: "#3c4050", radius: 3, border: 1, toggle: "xfce", slider: "bar", chip: "box", button: "box",
    headColor: w.ink, headPx: 12, headWeight: Font.Bold, rowPad: 5 })
  readonly property var cats: [[T.t("Personnel"), ["style", "look"]], [T.t("Matériel"), ["net", "bt", "sound", "screen", "power"]], [T.t("Système"), ["system"]]]
  function pageOf(id) { for (var i = 0; i < w.core.pages.length; i++) if (w.core.pages[i][0] === id) return w.core.pages[i]; return null }

  component XBtn: Rectangle {
    id: xb
    property string text: ""
    property string icon: ""
    signal clicked()
    width: xr.implicitWidth + 24; height: 28; radius: 3
    color: xm.pressed ? "#1a1c22" : (xm.containsMouse ? "#363a47" : "#2c2f3a"); border.width: 1; border.color: "#3c4050"
    Row { id: xr; anchors.centerIn: parent; spacing: 5
      MIcon { visible: xb.icon !== ""; anchors.verticalCenter: parent.verticalCenter; icon: xb.icon; size: 15; color: w.ink }
      Text { anchors.verticalCenter: parent.verticalCenter; text: xb.text; font.family: w.font; font.pixelSize: 12; color: w.ink } }
    MouseArea { id: xm; anchors.fill: parent; hoverEnabled: true; onClicked: xb.clicked() }
  }

  Item {
    id: win
    width: w.grid ? Math.min(parent.width - 80, 760) : Math.min(parent.width - 80, 680)
    height: Math.min(parent.height - 80, w.grid ? 520 : 600)
    anchors.centerIn: parent
    opacity: w.revealed ? 1 : 0
    Behavior on opacity { NumberAnimation { duration: 120 } }
    MouseArea { anchors.fill: parent }
    RectangularShadow { anchors.fill: frame; radius: 4; blur: 18; offset.y: 4; color: Qt.rgba(0, 0, 0, 0.6) }
    Rectangle {
      id: frame; anchors.fill: parent; radius: 4; color: w.winBg; border.width: 1; border.color: "#3c4050"; clip: true
      // barre de titre Xfwm : icône + titre à gauche, boutons à droite
      Rectangle {
        width: parent.width; height: 28; color: w.panel
        MIcon { x: 8; anchors.verticalCenter: parent.verticalCenter; icon: w.grid ? "settings" : w.core.pageInfo[2]; size: 15; color: w.acc }
        Text { x: 30; anchors.verticalCenter: parent.verticalCenter; text: w.grid ? T.t("Gestionnaire de paramètres") : w.core.pageInfo[1]; font.family: w.font; font.pixelSize: 12; font.weight: Font.Bold; color: w.ink }
        Row {
          anchors.right: parent.right; anchors.rightMargin: 4; anchors.verticalCenter: parent.verticalCenter; spacing: 0
          Repeater {
            model: ["remove", "crop_square", "close"]
            delegate: Rectangle {
              required property string modelData
              required property int index
              width: 26; height: 22; color: tx.containsMouse ? (index === 2 ? "#c0392b" : "#363a47") : "transparent"
              MIcon { anchors.centerIn: parent; icon: parent.modelData; size: 13; color: w.ink }
              MouseArea { id: tx; anchors.fill: parent; hoverEnabled: true; onClicked: if (parent.index === 2) w.core.close() }
            }
          }
        }
      }
      // ---- accueil : grille compacte
      Item {
        visible: w.grid
        y: 28; width: parent.width; height: parent.height - 28
        Rectangle {
          x: 10; y: 10; width: 240; height: 26; radius: 3; color: w.panel; border.width: 1; border.color: "#3c4050"
          MIcon { x: 6; anchors.verticalCenter: parent.verticalCenter; icon: "search"; size: 14; color: w.dim }
          Text { x: 26; anchors.verticalCenter: parent.verticalCenter; text: T.t("Rechercher…"); font.family: w.font; font.pixelSize: 12; color: w.dim }
        }
        Column {
          x: 14; y: 48; width: parent.width - 28; spacing: 12
          Repeater {
            model: w.cats
            delegate: Column {
              id: kc
              required property var modelData
              width: parent.width; spacing: 4
              Text { text: kc.modelData[0]; font.family: w.font; font.pixelSize: 13; font.weight: Font.Bold; color: w.ink }
              Rectangle { width: parent.width; height: 1; color: "#3c4050" }
              Flow {
                width: parent.width; spacing: 2
                Repeater {
                  model: kc.modelData[1]
                  delegate: Rectangle {
                    id: ki
                    required property string modelData
                    readonly property var pg: w.pageOf(modelData)
                    width: 170; height: 36; radius: 2
                    color: km.containsMouse ? s.alpha(w.acc, 0.25) : "transparent"
                    border.width: km.containsMouse ? 1 : 0; border.color: w.acc
                    Row { x: 6; anchors.verticalCenter: parent.verticalCenter; spacing: 8
                      MIcon { anchors.verticalCenter: parent.verticalCenter; icon: ki.pg ? ki.pg[2] : "settings"; size: 22; color: w.acc }
                      Text { anchors.verticalCenter: parent.verticalCenter; text: ki.pg ? ki.pg[1] : ""; font.family: w.font; font.pixelSize: 12; color: w.ink } }
                    MouseArea { id: km; anchors.fill: parent; hoverEnabled: true; onClicked: w.core.page = ki.modelData }
                  }
                }
              }
            }
          }
        }
        Row {
          anchors.right: parent.right; anchors.bottom: parent.bottom; anchors.margins: 10; spacing: 6
          XBtn { icon: "help"; text: T.t("Aide"); onClicked: w.core.run(["xdg-open", "https://docs.kali.org"]) }
          XBtn { icon: "close"; text: T.t("Fermer"); onClicked: w.core.close() }
        }
      }
      // ---- boîte de dialogue : classeur à onglets
      Item {
        visible: !w.grid
        y: 28; width: parent.width; height: parent.height - 28
        Flickable {
          id: tabsF
          x: 8; y: 8; width: parent.width - 16; height: 26; clip: true
          contentWidth: tabRow.implicitWidth; flickableDirection: Flickable.HorizontalFlick
          Row {
            id: tabRow
            spacing: -1
            Repeater {
              model: w.core.pages.filter(function(p) { return p[0] !== "home" })
              delegate: Rectangle {
                id: kt
                required property var modelData
                readonly property bool cur: w.core.page === modelData[0]
                width: ktt.implicitWidth + 20; height: cur ? 26 : 24; y: cur ? 0 : 2
                color: cur ? w.winBg : w.panel; border.width: 1; border.color: "#3c4050"
                Rectangle { visible: kt.cur; y: 0; width: parent.width; height: 2; color: w.acc }
                Rectangle { visible: kt.cur; y: parent.height - 1; x: 1; width: parent.width - 2; height: 1; color: w.winBg }
                Text { id: ktt; anchors.centerIn: parent; text: kt.modelData[1]; font.family: w.font; font.pixelSize: 12; color: kt.cur ? w.ink : w.dim }
                MouseArea { anchors.fill: parent; onClicked: w.core.page = kt.modelData[0] }
              }
            }
          }
        }
        Rectangle {
          x: 8; y: 33; width: parent.width - 16; height: parent.height - y - 48
          color: "transparent"; border.width: 1; border.color: "#3c4050"
          SetList {
            anchors.fill: parent; anchors.margins: 12
            core: w.core; look: w.look
            mode: "plain"; sepColor: "transparent"
          }
        }
        Row {
          x: 8; anchors.bottom: parent.bottom; anchors.bottomMargin: 10
          XBtn { icon: "help"; text: T.t("Aide"); onClicked: w.core.run(["xdg-open", "https://docs.kali.org"]) }
        }
        Row {
          anchors.right: parent.right; anchors.rightMargin: 8; anchors.bottom: parent.bottom; anchors.bottomMargin: 10; spacing: 6
          XBtn { icon: "apps"; text: T.t("Tous les paramètres"); onClicked: w.core.page = "home" }
          XBtn { icon: "close"; text: T.t("Fermer"); onClicked: w.core.close() }
        }
      }
    }
  }
}
