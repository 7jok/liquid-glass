import QtQuick
import QtQuick.Effects
import "T.js" as T

// Réglages Mint : les « Paramètres système » de Cinnamon. L'accueil est une
// grille de grosses icônes rangées par catégories (Apparence, Préférences,
// Matériel, Administration) ; un clic ouvre la page avec un bouton ← retour
// dans la barre d'outils. Thème Mint-Y sombre, accent vert menthe.
SetWin {
  id: w
  veil: Qt.rgba(0, 0, 0, 0.3)
  readonly property color winBg: "#2f2f2f"
  readonly property color bar: "#262626"
  readonly property color ink: "#dadada"
  readonly property color dim: "#9a9a9a"
  readonly property color acc: s.primary
  readonly property string font: s.userFont || "Ubuntu"
  readonly property bool grid: w.core.page === "home"
  readonly property var cats: [[T.t("Apparence"), ["style", "look"]], [T.t("Préférences"), ["home", "sound"]],
    [T.t("Matériel"), ["net", "bt", "screen", "power"]], [T.t("Administration"), ["system"]]]
  property bool showHome: false     // l'accueil « vrai » (raccourcis) ouvert depuis la grille
  readonly property var look: ({ font: w.font, head: w.font, px: 13, ink: w.ink, sub: w.dim, acc: w.acc, accInk: "#ffffff",
    tile: "#3a3a3a", bcol: "#4a4a4a", radius: 4, border: 1, toggle: "switch", slider: "bar", chip: "box", button: "box",
    headColor: w.acc, headPx: 13, headWeight: Font.Bold, rowPad: 9 })
  function pageOf(id) { for (var i = 0; i < w.core.pages.length; i++) if (w.core.pages[i][0] === id) return w.core.pages[i]; return null }

  Item {
    id: win
    width: Math.min(parent.width - 80, 900); height: Math.min(parent.height - 80, 640)
    anchors.centerIn: parent
    opacity: w.revealed ? 1 : 0
    Behavior on opacity { NumberAnimation { duration: 160 } }
    MouseArea { anchors.fill: parent }
    RectangularShadow { anchors.fill: frame; radius: 6; blur: 26; offset.y: 6; color: Qt.rgba(0, 0, 0, 0.55) }
    Rectangle {
      id: frame; anchors.fill: parent; radius: 6; color: w.winBg; border.width: 1; border.color: "#1c1c1c"; clip: true
      // barre de titre Cinnamon : titre centré, boutons à droite
      Rectangle {
        width: parent.width; height: 34; color: w.bar; radius: 6
        Rectangle { y: 20; width: parent.width; height: 14; color: w.bar }
        Text { anchors.centerIn: parent; text: T.t("Paramètres système"); font.family: w.font; font.pixelSize: 13; font.weight: Font.Bold; color: w.ink }
        Row {
          anchors.right: parent.right; anchors.rightMargin: 10; anchors.verticalCenter: parent.verticalCenter; spacing: 6
          Repeater {
            model: ["remove", "crop_square", "close"]
            delegate: Rectangle {
              required property string modelData
              required property int index
              width: 20; height: 20; radius: 10
              color: index === 2 ? (cx.containsMouse ? "#e0553b" : "#4a4a4a") : "transparent"
              MIcon { anchors.centerIn: parent; icon: parent.modelData; size: 13; color: w.ink }
              MouseArea { id: cx; anchors.fill: parent; hoverEnabled: true; onClicked: if (parent.index === 2) w.core.close() }
            }
          }
        }
      }
      // barre d'outils : retour + recherche
      Item {
        y: 34; width: parent.width; height: 46
        Rectangle {
          visible: !w.grid || w.showHome
          x: 10; anchors.verticalCenter: parent.verticalCenter; width: 92; height: 30; radius: 4
          color: bk.containsMouse ? "#454545" : "#3a3a3a"; border.width: 1; border.color: "#1f1f1f"
          Row { anchors.centerIn: parent; spacing: 4
            MIcon { anchors.verticalCenter: parent.verticalCenter; icon: "arrow_back"; size: 16; color: w.ink }
            Text { anchors.verticalCenter: parent.verticalCenter; text: T.t("Tout"); font.family: w.font; font.pixelSize: 13; color: w.ink } }
          MouseArea { id: bk; anchors.fill: parent; hoverEnabled: true; onClicked: { w.showHome = false; w.core.page = "home" } }
        }
        Text {
          visible: !w.grid || w.showHome
          anchors.centerIn: parent
          text: w.core.pageInfo[1]; font.family: w.font; font.pixelSize: 15; font.weight: Font.Bold; color: w.ink
        }
        Rectangle {
          visible: w.grid && !w.showHome
          anchors.right: parent.right; anchors.rightMargin: 12; anchors.verticalCenter: parent.verticalCenter
          width: 220; height: 28; radius: 4; color: "#242424"; border.width: 1; border.color: "#4a4a4a"
          MIcon { x: 8; anchors.verticalCenter: parent.verticalCenter; icon: "search"; size: 15; color: w.dim }
          Text { x: 30; anchors.verticalCenter: parent.verticalCenter; text: T.t("Rechercher"); font.family: w.font; font.pixelSize: 13; color: w.dim }
        }
        Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 1; color: "#1f1f1f" }
      }
      // grille d'icônes par catégorie
      Flickable {
        visible: w.grid && !w.showHome
        x: 0; y: 82; width: parent.width; height: parent.height - y
        contentHeight: catCol.implicitHeight + 30; clip: true
        Column {
          id: catCol
          x: 26; y: 14; width: parent.width - 52; spacing: 18
          Repeater {
            model: w.cats
            delegate: Column {
              id: cat
              required property var modelData
              width: catCol.width; spacing: 10
              Row { spacing: 10; width: parent.width
                Text { id: ct; text: cat.modelData[0]; font.family: w.font; font.pixelSize: 14; font.weight: Font.Bold; color: w.ink }
                Rectangle { anchors.verticalCenter: ct.verticalCenter; width: parent.width - ct.width - 10; height: 1; color: "#454545" } }
              Flow {
                width: parent.width; spacing: 6
                Repeater {
                  model: cat.modelData[1]
                  delegate: Rectangle {
                    id: ic
                    required property string modelData
                    readonly property var pg: w.pageOf(modelData)
                    width: 118; height: 96; radius: 6
                    color: im.containsMouse ? "#3d3d3d" : "transparent"
                    Rectangle {
                      anchors.horizontalCenter: parent.horizontalCenter; y: 8; width: 50; height: 50; radius: 12
                      gradient: Gradient { GradientStop { position: 0; color: Qt.lighter(w.acc, 1.25) } GradientStop { position: 1; color: Qt.darker(w.acc, 1.3) } }
                      MIcon { anchors.centerIn: parent; icon: ic.pg ? ic.pg[2] : "settings"; size: 28; fill: 1; color: "#ffffff" }
                    }
                    Text { anchors.horizontalCenter: parent.horizontalCenter; y: 64; width: parent.width - 8; horizontalAlignment: Text.AlignHCenter; wrapMode: Text.WordWrap
                      text: ic.pg ? ic.pg[1] : ""; font.family: w.font; font.pixelSize: 12; color: w.ink }
                    MouseArea { id: im; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                      onClicked: { if (ic.modelData === "home") w.showHome = true; w.core.page = ic.modelData } }
                  }
                }
              }
            }
          }
        }
      }
      SetList {
        visible: !w.grid || w.showHome
        x: 40; y: 96; width: parent.width - 80; height: parent.height - y - 10
        core: w.core; look: w.look
        mode: "boxed"; gap: 14; boxPad: 14
        boxColor: "#363636"; boxRadius: 4; boxBorder: "#262626"; boxBorderW: 1; sepColor: "#2c2c2c"
      }
    }
  }
}
