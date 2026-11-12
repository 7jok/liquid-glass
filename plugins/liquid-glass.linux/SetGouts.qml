import QtQuick
import QtQuick.Effects
import "T.js" as T

// Réglages Mes goûts : une palette de commandes qui descend du haut, aux
// couleurs du thème Omarchy choisi. Onglets texte soulignés en haut, réglages
// en grille de petites cartes, pastilles des couleurs du thème dans l'en-tête.
SetWin {
  id: w
  veil: Qt.rgba(0, 0, 0, 0.25)
  readonly property color ink: s.colOnSurface
  readonly property color acc: s.primary
  readonly property string font: s.userFont || s.sansFont
  readonly property var look: ({ font: w.font, head: w.font, px: 13, ink: w.ink, sub: s.colOnSurfaceVariant, acc: w.acc, accInk: s.colOnPrimary,
    tile: s.alpha(w.ink, 0.07), bcol: s.alpha(w.ink, 0.25), radius: 8, border: 1, toggle: "switch", slider: "bar", chip: "box", button: "box",
    headColor: s.colOnSurfaceVariant, headPx: 12, headSpacing: 1.5, upperHead: true, rowPad: 6 })

  Item {
    id: pal
    width: Math.min(parent.width - 80, 1040); height: Math.min(parent.height - 120, 620)
    anchors.horizontalCenter: parent.horizontalCenter
    y: w.revealed ? 60 : -height
    Behavior on y { NumberAnimation { duration: 420; easing.type: Easing.OutQuint } }
    MouseArea { anchors.fill: parent }
    RectangularShadow { anchors.fill: bg; radius: 16; blur: 36; offset.y: 14; color: Qt.rgba(0, 0, 0, 0.4) }
    Rectangle { id: bg; anchors.fill: parent; radius: 16; color: s.surface; border.width: 1; border.color: s.alpha(w.acc, 0.45) }
    // en-tête : thème et couleurs
    Row {
      x: 24; y: 18; spacing: 10
      MIcon { anchors.verticalCenter: parent.verticalCenter; icon: "favorite"; fill: 1; size: 20; color: w.acc }
      Text { anchors.verticalCenter: parent.verticalCenter; text: T.t("Mes goûts"); font.family: w.font; font.pixelSize: 18; font.weight: Font.Bold; color: w.ink }
      Text { anchors.verticalCenter: parent.verticalCenter; text: "· " + (s.goutsTheme || T.t("thème Omarchy")); font.family: w.font; font.pixelSize: 14; color: s.colOnSurfaceVariant }
    }
    Row {
      anchors.right: parent.right; anchors.rightMargin: 24; y: 22; spacing: 5
      Repeater {
        model: ["color1", "color2", "color3", "color4", "color5", "color6"]
        delegate: Rectangle { required property string modelData; width: 14; height: 14; radius: 4; color: s.themeColors[modelData] || w.acc }
      }
    }
    // onglets
    Row {
      id: tabs
      x: 16; y: 54; spacing: 2
      Repeater {
        model: w.core.pages
        delegate: Item {
          id: tb
          required property var modelData
          readonly property bool cur: w.core.page === modelData[0]
          width: tl.implicitWidth + 24; height: 36
          Row {
            id: tl
            anchors.centerIn: parent; spacing: 6
            MIcon { anchors.verticalCenter: parent.verticalCenter; icon: tb.modelData[2]; size: 16; fill: tb.cur ? 1 : 0; color: tb.cur ? w.acc : s.colOnSurfaceVariant }
            Text { anchors.verticalCenter: parent.verticalCenter; text: tb.modelData[1]; font.family: w.font; font.pixelSize: 13; font.weight: tb.cur ? Font.Bold : Font.Normal; color: tb.cur ? w.ink : s.colOnSurfaceVariant }
          }
          Rectangle { anchors.bottom: parent.bottom; anchors.horizontalCenter: parent.horizontalCenter; width: tb.cur ? parent.width - 12 : 0; height: 3; radius: 2; color: w.acc
            Behavior on width { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } } }
          MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: w.core.page = tb.modelData[0] }
        }
      }
    }
    Rectangle { x: 0; y: 90; width: parent.width; height: 1; color: s.alpha(w.ink, 0.1) }
    SetList {
      x: 22; y: 104
      width: parent.width - 44; height: parent.height - y - 36
      core: w.core; look: w.look
      mode: "tiles"; tileW: 300; gap: 10
      boxColor: s.surfaceMid; boxRadius: 10; boxBorder: s.alpha(w.ink, 0.08); boxBorderW: 1
    }
    Text {
      x: 24; anchors.bottom: parent.bottom; anchors.bottomMargin: 10
      text: T.t("⌃⌘T thème suivant · Tab page · Échap fermer")
      font.family: w.font; font.pixelSize: 11; color: s.alpha(w.ink, 0.45)
    }
  }
}
