import QtQuick
import QtQuick.Effects
import "T.js" as T

// Réglages Île : l'encoche noire du haut s'ouvre et grandit en un grand
// panneau noir arrondi (comme l'île dynamique), pages en petites gélules dans
// une capsule, titres en Michroma espacé, groupes en boîtes gris anthracite.
SetWin {
  id: w
  veil: Qt.rgba(0, 0, 0, 0.2)
  readonly property color ink: "#f2eef4"
  readonly property color acc: s.primary
  readonly property string font: s.userFont || "Inter"
  readonly property string display: s.userDisplay || "Michroma"
  readonly property var look: ({ font: w.font, head: w.display, px: 13, ink: w.ink, sub: "#8a8490", acc: s.tertiary, accInk: "#ffffff",
    tile: "#232127", bcol: "#3a3640", radius: 12, border: 0, toggle: "switch", slider: "bar", chip: "pill", button: "pill",
    headColor: "#8a8490", headPx: 10, headSpacing: 3, upper: false, rowPad: 10, listBg: true })

  Item {
    id: isl
    readonly property real fullW: Math.min(w.width - 80, 760)
    readonly property real fullH: Math.min(w.height - 60, 640)
    width: w.revealed ? fullW : 190
    height: w.revealed ? fullH : 34
    anchors.horizontalCenter: parent.horizontalCenter
    y: 6
    Behavior on width { NumberAnimation { duration: 520; easing.type: Easing.OutBack; easing.overshoot: 0.9 } }
    Behavior on height { NumberAnimation { duration: 560; easing.type: Easing.OutBack; easing.overshoot: 0.8 } }
    MouseArea { anchors.fill: parent }
    RectangularShadow { anchors.fill: bg; radius: bg.radius; blur: 50; offset.y: 18; color: Qt.rgba(0, 0, 0, 0.55) }
    Rectangle { id: bg; anchors.fill: parent; radius: Math.min(40, height / 2); color: "#000000" }
    Item {
      anchors.fill: parent
      opacity: isl.height > isl.fullH * 0.8 ? 1 : 0
      Behavior on opacity { NumberAnimation { duration: 200 } }
      clip: true
      // haut : heure + gélules
      Text { x: 30; y: 22; text: Qt.formatTime(new Date(), "HH:mm"); font.family: w.display; font.pixelSize: 22; color: w.ink }
      Text { anchors.right: parent.right; anchors.rightMargin: 30; y: 28; text: w.core.batteryText; font.family: w.font; font.pixelSize: 12; color: "#8a8490" }
      Rectangle {
        id: caps
        anchors.horizontalCenter: parent.horizontalCenter; y: 64
        width: capRow.implicitWidth + 10; height: 38; radius: 19; color: "#1b191f"
        Row {
          id: capRow
          anchors.centerIn: parent; spacing: 2
          Repeater {
            model: w.core.pages
            delegate: Rectangle {
              id: cap
              required property var modelData
              readonly property bool cur: w.core.page === modelData[0]
              width: cur ? capT.implicitWidth + 44 : 32; height: 30; radius: 15
              color: cur ? "#ffffff" : (cm.containsMouse ? "#2e2b33" : "transparent")
              Behavior on width { NumberAnimation { duration: 300; easing.type: Easing.OutBack } }
              Row {
                anchors.centerIn: parent; spacing: 5
                MIcon { anchors.verticalCenter: parent.verticalCenter; icon: cap.modelData[2]; size: 16; fill: cap.cur ? 1 : 0; color: cap.cur ? "#000000" : "#c9c2cc" }
                Text { id: capT; visible: cap.cur; anchors.verticalCenter: parent.verticalCenter; text: cap.modelData[1]; font.family: w.font; font.pixelSize: 12; font.weight: Font.DemiBold; color: "#000000" }
              }
              MouseArea { id: cm; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: w.core.page = cap.modelData[0] }
            }
          }
        }
      }
      Text {
        x: 30; y: 118
        text: w.core.pageInfo[1].toUpperCase()
        font.family: w.display; font.pixelSize: 20; font.letterSpacing: 6; color: w.ink
      }
      SetList {
        x: 26; y: 156; width: parent.width - 52; height: parent.height - y - 22
        core: w.core; look: w.look
        mode: "boxed"; gap: 6; boxPad: 14
        boxColor: "#151418"; boxRadius: 22; sepColor: "#26232b"
      }
    }
  }
}
