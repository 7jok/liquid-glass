import QtQuick
import "T.js" as T

// Réglages 7JOKS : un terminal de science-fiction plein écran, noir, crochets
// aux angles, lignes de balayage, touches de fonction F1…F9 en haut, lignes
// « > WI-FI ......... [ ACTIF ] », curseurs en blocs, choix < valeur >, texte
// qui s'écrit au démarrage.
SetWin {
  id: w
  veil: Qt.rgba(0, 0, 0, 0.93)
  readonly property color acc: s.primary
  readonly property color ink: s.primary
  readonly property string font: s.userFont || "Share Tech Mono"
  readonly property string display: s.userDisplay || "Michroma"
  readonly property var look: ({ font: w.font, head: w.display, px: 14, ink: w.ink, sub: "#7a7a7a", acc: w.acc, accInk: "#000000",
    tile: s.alpha(w.acc, 0.08), bcol: s.alpha(w.acc, 0.6), radius: 0, border: 1, toggle: "bracket", slider: "blocks", chip: "text", button: "text",
    leader: true, icons: false, upper: true, labelSuffix: "", headPrefix: "// ", headColor: "#7a7a7a", headPx: 11, headSpacing: 3,
    activeMark: "▶", infoSep: "", swatch: "square", rowPad: 5, spacing: 1 })
  property int typed: 0
  readonly property string banner: "> SYS.CONFIG // 7JOKS // " + T.t("RÉGLAGES DU TERMINAL") + " // " + s.user.toUpperCase() + "@" + String(s.info.host || "node").toUpperCase()
  Timer { running: w.typed < w.banner.length; interval: 18; repeat: true; onTriggered: w.typed += 2 }

  // crochets aux angles
  Repeater {
    model: 4
    delegate: Item {
      required property int index
      width: 40; height: 40
      x: index % 2 ? w.width - 60 : 20; y: index < 2 ? 20 : w.height - 60
      Rectangle { width: 40; height: 2; color: w.acc; y: index < 2 ? 0 : 38 }
      Rectangle { width: 2; height: 40; color: w.acc; x: index % 2 ? 38 : 0 }
    }
  }
  // lignes de balayage
  Repeater {
    model: Math.ceil(w.height / 4)
    delegate: Rectangle { required property int index; y: index * 4; width: w.width; height: 1; color: "white"; opacity: 0.025 }
  }
  Rectangle {
    width: w.width; height: 80; opacity: 0.05
    gradient: Gradient { GradientStop { position: 0; color: "transparent" } GradientStop { position: 0.5; color: w.acc } GradientStop { position: 1; color: "transparent" } }
    NumberAnimation on y { from: -80; to: w.height; duration: 5200; loops: Animation.Infinite }
  }
  Item {
    id: term
    x: 70; y: 56; width: parent.width - 140; height: parent.height - 112
    MouseArea { anchors.fill: parent }
    Text { text: w.banner.slice(0, w.typed) + (w.typed < w.banner.length ? "█" : ""); font.family: w.font; font.pixelSize: 15; color: w.acc }
    // touches de fonction
    Row {
      y: 34; spacing: 6
      Repeater {
        model: w.core.pages
        delegate: Rectangle {
          id: fk
          required property var modelData
          required property int index
          readonly property bool cur: w.core.page === modelData[0]
          width: fkt.implicitWidth + 20; height: 26
          color: cur ? w.acc : "transparent"; border.width: 1; border.color: cur ? w.acc : s.alpha(w.acc, 0.45)
          Text { id: fkt; anchors.centerIn: parent; text: "F" + (fk.index + 1) + " " + fk.modelData[1].toUpperCase(); font.family: w.font; font.pixelSize: 12; color: fk.cur ? "#000000" : w.acc }
          MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: w.core.page = fk.modelData[0] }
        }
      }
    }
    Rectangle { y: 70; width: parent.width; height: 1; color: s.alpha(w.acc, 0.4) }
    Text {
      y: 84
      text: "[" + (w.core.pageIndex + 1) + "] " + w.core.pageInfo[1].toUpperCase()
      font.family: w.display; font.pixelSize: 26; font.letterSpacing: 6; color: w.acc
    }
    SetList {
      y: 130; width: parent.width * 0.62; height: parent.height - y - 34
      core: w.core; look: w.look
      mode: "plain"; sepColor: s.alpha(w.acc, 0.1)
    }
    // colonne de télémétrie
    Column {
      x: parent.width * 0.68; y: 134; width: parent.width * 0.32
      spacing: 6
      Text { text: "// " + T.t("TÉLÉMÉTRIE"); font.family: w.font; font.pixelSize: 11; font.letterSpacing: 3; color: "#7a7a7a" }
      Repeater {
        model: [["CPU", s.info.cpu || "?"], ["RAM", (s.info.ram || "?") + " GO"], ["GPU", s.info.gpu || "?"], ["DISK", s.info.disk || "?"],
                ["KERNEL", s.info.kernel || "?"], ["UPTIME", s.uptimeText], ["BATT", w.core.batteryText], ["NET", w.core.sysSub("wifi")]]
        delegate: Row {
          required property var modelData
          spacing: 8
          Text { width: 70; text: modelData[0]; font.family: w.font; font.pixelSize: 12; color: "#7a7a7a" }
          Text { width: term.width * 0.32 - 80; elide: Text.ElideRight; text: String(modelData[1]).toUpperCase(); font.family: w.font; font.pixelSize: 12; color: w.acc }
        }
      }
    }
    Text {
      anchors.bottom: parent.bottom
      text: "> TAB " + T.t("SUIVANT") + "  ·  ⇧TAB " + T.t("PRÉCÉDENT") + "  ·  ESC " + T.t("QUITTER") + "  ·  " + Qt.formatTime(new Date(), "HH:mm:ss")
      font.family: w.font; font.pixelSize: 12; color: "#7a7a7a"
    }
  }
}
