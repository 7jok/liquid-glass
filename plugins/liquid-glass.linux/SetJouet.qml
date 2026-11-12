import QtQuick
import "T.js" as T

// Réglages Jouet : une grosse boîte à bonbons qui rebondit au-dessus du dock.
// Les pages sont des autocollants ronds de toutes les couleurs collés sur le haut
// de la boîte (penchés, celui en cours plus gros), contours épais, ombres dures,
// interrupteurs « OUI ! / non » en autocollants, tuiles blanches.
SetWin {
  id: w
  veil: Qt.rgba(0.1, 0.05, 0.2, 0.25)
  readonly property color line: "#1b1030"
  readonly property color acc: s.primary
  readonly property string font: s.userFont || "Pixelify Sans"
  readonly property string display: s.userDisplay || "Unbounded"
  readonly property bool atTop: s.barAt("bottom") === "top"
  readonly property var rainbow: ["#ff5fa2", "#ff7a45", "#ffc83d", "#7bd389", "#18b98f", "#26c6da", "#4c9aff", "#9b7bff", "#ff8fd8"]
  readonly property var look: ({ font: w.font, head: w.display, px: 14, ink: w.line, sub: "#6d5a8a", acc: w.acc, accInk: s.colOnPrimary,
    tile: "#ffffff", bcol: w.line, radius: 14, border: 2, hard: 3, toggle: "sticker", slider: "dots", chip: "sticker", button: "sticker",
    headColor: w.line, headPx: 15, headWeight: Font.Black, swatch: "soft", tallActs: true, listBg: true })

  Item {
    id: box
    width: Math.min(parent.width - 60, 860)
    height: Math.min(parent.height - 190, 600)
    anchors.horizontalCenter: parent.horizontalCenter
    y: w.atTop ? 120 : parent.height - height - 120
    scale: w.revealed ? 1 : 0.4
    opacity: w.revealed ? 1 : 0
    transformOrigin: w.atTop ? Item.Top : Item.Bottom
    Behavior on scale { NumberAnimation { duration: 480; easing.type: Easing.OutBack; easing.overshoot: 2.2 } }
    Behavior on opacity { NumberAnimation { duration: 160 } }
    MouseArea { anchors.fill: parent }
    Rectangle { x: 9; y: 9; width: parent.width; height: parent.height; radius: 30; color: w.line }
    Rectangle {
      anchors.fill: parent; radius: 30
      color: Qt.tint(s.surfaceMid, Qt.rgba(1, 1, 1, 0.55))
      border.width: 3.5; border.color: w.line
    }
    // titre en bulle
    Text {
      x: 30; y: 58
      text: w.core.pageInfo[1] + " !"
      font.family: w.display; font.pixelSize: 30; font.weight: Font.Black; color: w.line
      rotation: -2
    }
    Text {
      anchors.right: parent.right; anchors.rightMargin: 30; y: 70
      text: "☺ " + s.user + " · " + w.core.batteryText
      font.family: w.font; font.pixelSize: 14; color: "#6d5a8a"
    }
    SetList {
      x: 26; y: 112
      width: parent.width - 52; height: parent.height - y - 22
      core: w.core; look: w.look
      mode: "tiles"; tileW: 240; gap: 12
      boxColor: "#ffffff"; boxRadius: 18; boxBorder: w.line; boxBorderW: 3; hard: 4; hardColor: w.line
    }
  }
  // autocollants des pages, à cheval sur le haut de la boîte
  Row {
    anchors.horizontalCenter: box.horizontalCenter
    y: box.y - 34
    spacing: 10
    opacity: box.opacity
    Repeater {
      model: w.core.pages
      delegate: Item {
        id: st
        required property var modelData
        required property int index
        readonly property bool cur: w.core.page === modelData[0]
        width: 64; height: 64
        scale: cur ? 1.22 : (sm.containsMouse ? 1.1 : 1)
        rotation: (index % 3 - 1) * 7 + (cur ? 0 : 0)
        Behavior on scale { NumberAnimation { duration: 260; easing.type: Easing.OutBack; easing.overshoot: 3 } }
        Rectangle { x: 4; y: 4; width: 60; height: 60; radius: 30; color: w.line }
        Rectangle {
          width: 60; height: 60; radius: 30
          color: w.rainbow[st.index % w.rainbow.length]
          border.width: 3; border.color: w.line
          MIcon { anchors.centerIn: parent; anchors.verticalCenterOffset: -5; icon: st.modelData[2]; size: 24; fill: 1; color: w.line }
          Text {
            anchors.bottom: parent.bottom; anchors.bottomMargin: 7; anchors.horizontalCenter: parent.horizontalCenter
            width: 54; horizontalAlignment: Text.AlignHCenter; elide: Text.ElideRight
            text: st.modelData[1]; font.family: w.font; font.pixelSize: 9; color: w.line
          }
        }
        MouseArea { id: sm; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: w.core.page = st.modelData[0] }
      }
    }
  }
}
