import QtQuick
import QtQuick.Effects
import "T.js" as T

// Réglages Debian / Fedora : l'app Paramètres de GNOME (libadwaita).
//   Debian : barre latérale à gauche (recherche + liste), listes en boîtes.
//   Fedora : sélecteur de vues en haut (icône au-dessus du nom), colonne centrée.
// Barre de titre avec un seul ×, coins de 12 px, interrupteurs et listes
// déroulantes Adwaita, accent de la distribution.
SetWin {
  id: w
  veil: Qt.rgba(0, 0, 0, 0.35)
  readonly property bool fedora: s.style === "fedora"
  readonly property color winBg: "#1e1e1e"
  readonly property color side: "#2a2a2a"
  readonly property color card: "#2e2e32"
  readonly property color ink: "#ffffff"
  readonly property color dim: "#b8b8b8"
  readonly property color acc: s.primary
  readonly property string font: s.userFont || "Adwaita Sans"
  property string query: ""
  readonly property var look: ({ font: w.font, head: w.font, px: 14, ink: w.ink, sub: w.dim, acc: w.acc, accInk: "#ffffff",
    tile: "#3a3a3e", bcol: "#4a4a4e", radius: 8, border: 0, toggle: "adw", slider: "line", chip: "combo", button: "pill",
    headColor: w.ink, headPx: 14, headWeight: Font.Bold, rowPad: 12, popBg: "#38383c", listBg: false })
  readonly property var shownPages: w.core.pages.filter(function(p) { return w.query === "" || p[1].toLowerCase().indexOf(w.query.toLowerCase()) >= 0 })

  Item {
    id: win
    width: Math.min(parent.width - 80, 1000); height: Math.min(parent.height - 80, 680)
    anchors.centerIn: parent
    opacity: w.revealed ? 1 : 0
    scale: w.revealed ? 1 : 0.94
    Behavior on opacity { NumberAnimation { duration: 180 } }
    Behavior on scale { NumberAnimation { duration: 240; easing.type: Easing.OutCubic } }
    MouseArea { anchors.fill: parent }
    RectangularShadow { anchors.fill: frame; radius: 12; blur: 30; offset.y: 8; color: Qt.rgba(0, 0, 0, 0.5) }
    Rectangle { id: frame; anchors.fill: parent; radius: 12; color: w.winBg; border.width: 1; border.color: "#3a3a3a"; clip: true

      // ---- Debian : barre latérale
      Rectangle {
        visible: !w.fedora
        width: 270; height: parent.height; color: w.side; radius: 12
        Rectangle { anchors.right: parent.right; width: 12; height: parent.height; color: w.side }
        Text { x: 0; width: parent.width; y: 15; horizontalAlignment: Text.AlignHCenter; text: T.t("Paramètres"); font.family: w.font; font.pixelSize: 14; font.weight: Font.Bold; color: w.ink }
        Rectangle {
          x: 12; y: 52; width: parent.width - 24; height: 34; radius: 8; color: "#383838"
          MIcon { x: 10; anchors.verticalCenter: parent.verticalCenter; icon: "search"; size: 16; color: w.dim }
          TextInput {
            id: search
            x: 34; width: parent.width - 44; anchors.verticalCenter: parent.verticalCenter
            font.family: w.font; font.pixelSize: 14; color: w.ink
            onTextChanged: w.query = text
            Text { visible: !parent.text; text: T.t("Rechercher"); font: parent.font; color: w.dim }
          }
        }
        Column {
          x: 8; y: 96; width: parent.width - 16; spacing: 2
          Repeater {
            model: w.shownPages
            delegate: Rectangle {
              id: si
              required property var modelData
              readonly property bool cur: w.core.page === modelData[0]
              width: parent.width; height: 42; radius: 8
              color: cur ? "#454549" : (sm.containsMouse ? "#363639" : "transparent")
              Row {
                x: 12; anchors.verticalCenter: parent.verticalCenter; spacing: 12
                MIcon { anchors.verticalCenter: parent.verticalCenter; icon: si.modelData[2]; size: 18; color: w.ink }
                Text { anchors.verticalCenter: parent.verticalCenter; text: si.modelData[1]; font.family: w.font; font.pixelSize: 14; color: w.ink }
              }
              MouseArea { id: sm; anchors.fill: parent; hoverEnabled: true; onClicked: w.core.page = si.modelData[0] }
            }
          }
        }
      }
      // ---- barre de titre
      Item {
        x: w.fedora ? 0 : 270; width: parent.width - x; height: w.fedora ? 64 : 48
        Text {
          visible: !w.fedora
          anchors.centerIn: parent
          text: w.core.pageInfo[1]; font.family: w.font; font.pixelSize: 14; font.weight: Font.Bold; color: w.ink
        }
        // Fedora : sélecteur de vues
        Row {
          visible: w.fedora
          anchors.centerIn: parent; spacing: 2
          Repeater {
            model: w.core.pages
            delegate: Rectangle {
              id: vs
              required property var modelData
              readonly property bool cur: w.core.page === modelData[0]
              width: 78; height: 50; radius: 8
              color: cur ? "#454549" : (vm.containsMouse ? "#333336" : "transparent")
              Column {
                anchors.centerIn: parent; spacing: 2
                MIcon { anchors.horizontalCenter: parent.horizontalCenter; icon: vs.modelData[2]; size: 18; fill: vs.cur ? 1 : 0; color: vs.cur ? w.acc : w.ink }
                Text { anchors.horizontalCenter: parent.horizontalCenter; width: 74; horizontalAlignment: Text.AlignHCenter; elide: Text.ElideRight; text: vs.modelData[1]; font.family: w.font; font.pixelSize: 11; font.weight: vs.cur ? Font.Bold : Font.Normal; color: w.ink }
              }
              MouseArea { id: vm; anchors.fill: parent; hoverEnabled: true; onClicked: w.core.page = vs.modelData[0] }
            }
          }
        }
        Rectangle {
          anchors.right: parent.right; anchors.rightMargin: 12; anchors.verticalCenter: parent.verticalCenter
          width: 26; height: 26; radius: 13; color: xm.containsMouse ? "#4a4a4e" : "#3a3a3e"
          MIcon { anchors.centerIn: parent; icon: "close"; size: 16; color: w.ink }
          MouseArea { id: xm; anchors.fill: parent; hoverEnabled: true; onClicked: w.core.close() }
        }
      }
      // ---- contenu (Fedora : colonne centrée façon AdwClamp)
      SetList {
        readonly property int clampW: 620
        x: w.fedora ? (parent.width - Math.min(clampW, parent.width - 60)) / 2 : 270 + 36
        y: w.fedora ? 80 : 60
        width: w.fedora ? Math.min(clampW, parent.width - 60) : parent.width - 270 - 72
        height: parent.height - y - 12
        core: w.core; look: w.look
        mode: "boxed"; gap: 10; boxPad: 12
        boxColor: w.card; boxRadius: 12; sepColor: "#3c3c40"
      }
    }
  }
}
