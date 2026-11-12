import QtQuick
import QtQuick.Effects
import "T.js" as T

// Réglages Forêt : des puces flottantes sous la barre (une par page, comme les
// puces de la barre Forêt), et la page en cartes flottantes empilées en haut à
// droite, translucides, liseré fin, police JetBrains. Interrupteurs OUI | NON,
// feuilles qui tombent doucement derrière.
SetWin {
  id: w
  veil: Qt.rgba(0, 0, 0, 0.2)
  readonly property color ink: s.colOnSurface
  readonly property color acc: s.primary
  readonly property string font: s.userFont || "JetBrainsMono Nerd Font"
  readonly property bool atTop: s.barAt("top") === "top"
  readonly property var look: ({ font: w.font, head: w.font, px: 13, ink: w.ink, sub: s.colOnSurfaceVariant, acc: w.acc, accInk: s.colOnPrimary,
    tile: s.alpha(w.ink, 0.08), bcol: s.alpha(w.acc, 0.5), radius: 12, border: 1, toggle: "seg", slider: "bar", chip: "pill", button: "pill",
    headColor: w.acc, headPx: 12, headPrefix: "󰌪 ", rowPad: 7 })

  // feuilles
  Repeater {
    model: 14
    delegate: Text {
      id: leaf
      required property int index
      text: index % 2 ? "🍂" : "🍃"
      font.pixelSize: 14 + index % 3 * 5
      x: (index * 137 % 100) / 100 * w.width
      opacity: 0.55
      NumberAnimation on y { from: -40; to: w.height + 40; duration: 9000 + leaf.index * 900; loops: Animation.Infinite }
      RotationAnimation on rotation { from: 0; to: 360; duration: 5000 + leaf.index * 400; loops: Animation.Infinite }
    }
  }
  // puces des pages
  Row {
    id: chips
    anchors.horizontalCenter: parent.horizontalCenter
    y: w.atTop ? 58 : parent.height - 100
    spacing: 8
    opacity: w.revealed ? 1 : 0
    Behavior on opacity { NumberAnimation { duration: 300 } }
    Repeater {
      model: w.core.pages
      delegate: Rectangle {
        id: cp
        required property var modelData
        required property int index
        readonly property bool cur: w.core.page === modelData[0]
        width: cpr.implicitWidth + 26; height: 36; radius: 18
        color: cur ? w.acc : s.alpha(s.surfaceMid, 0.92)
        border.width: 1; border.color: s.alpha(w.acc, cur ? 0 : 0.4)
        y: w.revealed ? 0 : -30
        Behavior on y { NumberAnimation { duration: 420 + cp.index * 45; easing.type: Easing.OutBack } }
        Row {
          id: cpr
          anchors.centerIn: parent; spacing: 7
          MIcon { anchors.verticalCenter: parent.verticalCenter; icon: cp.modelData[2]; size: 16; fill: cp.cur ? 1 : 0; color: cp.cur ? s.colOnPrimary : w.acc }
          Text { anchors.verticalCenter: parent.verticalCenter; text: cp.modelData[1].toLowerCase(); font.family: w.font; font.pixelSize: 12; color: cp.cur ? s.colOnPrimary : w.ink }
        }
        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: w.core.page = cp.modelData[0] }
      }
    }
  }
  // la page : cartes flottantes
  Item {
    id: stack
    width: 520
    x: w.revealed ? parent.width - width - 22 : parent.width + 10
    y: w.atTop ? chips.y + 54 : 40
    height: parent.height - (w.atTop ? y + 24 : 160)
    Behavior on x { NumberAnimation { duration: 460; easing.type: Easing.OutCubic } }
    MouseArea { anchors.fill: parent }
    Rectangle {
      width: parent.width; height: 54; radius: 16
      color: s.alpha(s.surfaceMid, 0.94); border.width: 1; border.color: s.alpha(w.acc, 0.35)
      Row {
        x: 16; anchors.verticalCenter: parent.verticalCenter; spacing: 10
        MIcon { anchors.verticalCenter: parent.verticalCenter; icon: w.core.pageInfo[2]; size: 22; fill: 1; color: w.acc }
        Text { anchors.verticalCenter: parent.verticalCenter; text: w.core.pageInfo[1].toLowerCase(); font.family: w.font; font.pixelSize: 17; font.weight: Font.Bold; color: w.ink }
      }
      Text { anchors.right: parent.right; anchors.rightMargin: 16; anchors.verticalCenter: parent.verticalCenter; text: Qt.formatTime(new Date(), "HH:mm") + "  " + w.core.batteryText; font.family: w.font; font.pixelSize: 12; color: s.colOnSurfaceVariant }
    }
    SetList {
      y: 64; width: parent.width; height: parent.height - y
      core: w.core; look: w.look
      mode: "cards"; gap: 6; boxPad: 14
      boxColor: s.alpha(s.surfaceMid, 0.94); boxRadius: 16; boxBorder: s.alpha(w.acc, 0.3); boxBorderW: 1
      sepColor: s.alpha(w.ink, 0.07)
    }
  }
}
