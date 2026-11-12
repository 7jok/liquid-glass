import QtQuick
import Quickshell
import "T.js" as T

// Réglages Blanc : une feuille de terminal posée au-dessus de la barre de texte,
// pleine largeur, angles vifs, ombre dure décalée. Onglets = étiquettes dwm
// « 1:accueil 2:blanc… » (celle en cours en négatif), lignes avec points de
// conduite, [x], [####----], < valeur >, [ ok ] ; ligne d'état façon vim en bas.
SetWin {
  id: w
  readonly property color paper: s.tone === "creme" ? "#f3ead6" : "#fbfbfa"
  readonly property color ink: "#111111"
  readonly property string font: s.userFont || "JetBrainsMono Nerd Font"
  readonly property bool atTop: s.barAt("bottom") === "top"
  readonly property var look: ({ font: w.font, head: w.font, px: 13, ink: w.ink, sub: "#6b6b6b", acc: w.ink, accInk: w.paper,
    tile: Qt.rgba(0, 0, 0, 0.05), bcol: w.ink, radius: 0, border: 1, toggle: "check", slider: "ascii", chip: "text", button: "text",
    leader: true, icons: false, headPrefix: "## ", headColor: w.ink, headPx: 13, headGap: 14, labelWeight: Font.Normal,
    activeMark: ">", infoSep: " :", swatch: "square", rowPad: 5 })

  Item {
    id: sheet
    x: 12; width: parent.width - 24
    height: Math.min(parent.height * 0.66, 560)
    readonly property real restY: w.atTop ? 40 : parent.height - height - 40
    y: w.revealed ? restY : (w.atTop ? -height - 20 : parent.height + 20)
    Behavior on y { NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }
    MouseArea { anchors.fill: parent }
    Rectangle { x: 7; y: 7; width: parent.width; height: parent.height; color: w.ink }
    Rectangle { anchors.fill: parent; color: w.paper; border.width: 2; border.color: w.ink }

    // invite
    Text {
      x: 18; y: 12
      text: s.user + "@" + (s.info.host || "linux") + ":~/réglages$ ls --" + w.core.page
      font.family: w.font; font.pixelSize: 13; color: w.ink
    }
    Text {
      anchors.right: parent.right; anchors.rightMargin: 18; y: 12
      text: "up " + s.uptimeText + " · " + Qt.formatTime(new Date(), "HH:mm")
      font.family: w.font; font.pixelSize: 13; color: "#6b6b6b"
    }
    // étiquettes dwm
    Row {
      x: 18; y: 38
      spacing: 0
      Repeater {
        model: w.core.pages
        delegate: Rectangle {
          id: tag
          required property var modelData
          required property int index
          readonly property bool cur: w.core.page === modelData[0]
          width: tt.implicitWidth + 16; height: 24
          color: cur ? w.ink : (tm.containsMouse ? Qt.rgba(0, 0, 0, 0.08) : "transparent")
          Text {
            id: tt
            anchors.centerIn: parent
            text: (tag.index + 1) + ":" + tag.modelData[1].toLowerCase()
            font.family: w.font; font.pixelSize: 13; font.weight: tag.cur ? Font.Bold : Font.Normal
            color: tag.cur ? w.paper : w.ink
          }
          MouseArea { id: tm; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: w.core.page = tag.modelData[0] }
        }
      }
    }
    Rectangle { x: 18; y: 66; width: parent.width - 36; height: 2; color: w.ink }
    // deux colonnes : la page, et un mémo des commandes à droite
    SetList {
      x: 18; y: 74
      width: parent.width * 0.64 - 18
      height: parent.height - y - 34
      core: w.core; look: w.look
      mode: "plain"; sepColor: Qt.rgba(0, 0, 0, 0.07)
    }
    Rectangle { x: parent.width * 0.64 + 12; y: 82; width: 1; height: parent.height - 124; color: Qt.rgba(0, 0, 0, 0.25) }
    Column {
      x: parent.width * 0.64 + 30; y: 84
      width: parent.width * 0.36 - 48
      spacing: 4
      Text { text: "## " + T.t("mémo"); font.family: w.font; font.pixelSize: 13; font.weight: Font.Bold; color: w.ink }
      Repeater {
        model: [["tab", T.t("page suivante")], ["⇧tab", T.t("page précédente")], ["alt+1…9", T.t("aller à la page")], ["clic", T.t("[x] cocher, < > changer")],
                ["clic droit", T.t("< > en arrière")], ["molette", T.t("curseurs et choix")], ["échap", T.t("fermer")]]
        delegate: Text {
          required property var modelData
          width: parent.width; elide: Text.ElideRight
          text: modelData[0].padEnd(11, " ") + modelData[1]
          font.family: w.font; font.pixelSize: 12; color: "#6b6b6b"
        }
      }
      Item { width: 1; height: 14 }
      Text { text: "## " + T.t("fiche"); font.family: w.font; font.pixelSize: 13; font.weight: Font.Bold; color: w.ink }
      Repeater {
        model: [["os", s.info.os || ""], ["wm", "Hyprland"], ["noyau", s.info.kernel || ""], ["mémoire", (s.info.ram || "?") + " Go"],
                ["batterie", w.core.batteryText], ["fond", w.core.bgName]]
        delegate: Text {
          required property var modelData
          width: parent.width; elide: Text.ElideRight
          text: modelData[0].padEnd(11, " ") + modelData[1]
          font.family: w.font; font.pixelSize: 12; color: w.ink
        }
      }
    }
    // ligne d'état
    Rectangle {
      x: 2; width: parent.width - 4; height: 24; y: parent.height - 26
      color: w.ink
      Text { x: 12; anchors.verticalCenter: parent.verticalCenter; text: "-- " + T.t("RÉGLAGES") + " --  " + w.core.pageInfo[1].toLowerCase() + "  [" + (w.core.pageIndex + 1) + "/" + w.core.pages.length + "]"; font.family: w.font; font.pixelSize: 12; font.weight: Font.Bold; color: w.paper }
      Text { anchors.right: parent.right; anchors.rightMargin: 12; anchors.verticalCenter: parent.verticalCenter; text: T.t("tab:page  esc:quitter"); font.family: w.font; font.pixelSize: 12; color: w.paper }
    }
  }
}
