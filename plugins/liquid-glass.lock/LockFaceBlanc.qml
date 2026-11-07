import QtQuick
import Quickshell.Io
import "T.js" as T

// Verrouillage du style Blanc (brutaliste, z603894) : papier, encre noire, traits épais
// et ombres décalées. Une fenêtre « verrou — jok@machine » avec sa barre de titre, l'heure
// en chasse fixe, la date, et une invite « mot de passe: **** ▌ ».
Item {
  id: f
  property var lock: null
  readonly property var lk: lock
  readonly property real k: Math.min(width / 1280, height / 720)
  readonly property bool creme: lk && lk.tone("blanc_tone", "pur") === "creme"
  readonly property color paper: creme ? "#f3ecdc" : "#f6f5f2"
  readonly property color ink: "#111111"
  readonly property string mono: "JetBrainsMono Nerd Font"
  readonly property int typed: lk ? lk.passwordText.length : 0
  property string host: "linux"
  FileView { path: "/etc/hostname"; printErrors: false; onLoaded: f.host = text().trim() || "linux" }
  readonly property rect fieldBox: {
    var c = field.mapToItem(f, 0, 0)
    return Qt.rect(c.x, c.y, field.width, field.height)
  }

  Rectangle { anchors.fill: parent; color: f.paper }
  FaceWall { anchors.fill: parent; lk: f.lk; saturation: -1; brightness: 0.15; opacity: 0.18 }
  // Trame de points
  Canvas {
    anchors.fill: parent; opacity: 0.25
    onPaint: { var c = getContext("2d"); c.fillStyle = "#111"; for (var x = 12; x < width; x += 24) for (var y = 12; y < height; y += 24) c.fillRect(x, y, 1.5, 1.5) }
  }

  component Box: Item {
    property color fill: f.paper
    default property alias content: inner.data
    Rectangle { x: 8 * f.k; y: 8 * f.k; width: parent.width; height: parent.height; color: f.ink }
    Rectangle { id: inner; anchors.fill: parent; color: parent.fill; border.color: f.ink; border.width: 3 }
  }

  Box {
    id: win
    width: 520 * f.k; height: 330 * f.k
    anchors.centerIn: parent
    anchors.verticalCenterOffset: -20 * f.k
    Rectangle {
      width: parent.width; height: 30 * f.k; color: f.ink
      Text { x: 12 * f.k; anchors.verticalCenter: parent.verticalCenter; text: T.t("verrou") + " — " + (f.lk ? f.lk.userName : "") + "@" + f.host; font.family: f.mono; font.pixelSize: 12 * f.k; font.bold: true; color: f.paper }
      Row { anchors.right: parent.right; anchors.rightMargin: 10 * f.k; anchors.verticalCenter: parent.verticalCenter; spacing: 6 * f.k
        Repeater { model: 3; Rectangle { width: 12 * f.k; height: width; color: f.paper } } }
    }
    Text {
      anchors.horizontalCenter: parent.horizontalCenter; y: 50 * f.k
      text: f.lk ? f.lk.hh + ":" + f.lk.mm : ""
      font.family: f.mono; font.pixelSize: 110 * f.k; font.weight: Font.ExtraBold; color: f.ink
    }
    Text {
      anchors.horizontalCenter: parent.horizontalCenter; y: 190 * f.k
      text: f.lk ? "[ " + f.lk.now.toLocaleDateString(Qt.locale(T.loc), "dddd dd.MM.yyyy").toLowerCase() + " ]" : ""
      font.family: f.mono; font.pixelSize: 14 * f.k; color: f.ink
    }
    Box {
      id: field
      x: 30 * f.k + (f.lk ? f.lk.shakeX : 0); y: 245 * f.k
      width: parent.width - 60 * f.k; height: 44 * f.k
      fill: f.lk && f.lk.errorState ? "#ffd6d6" : "white"
      Text {
        x: 12 * f.k; anchors.verticalCenter: parent.verticalCenter
        text: (f.lk && f.lk.errorState && f.typed === 0 ? f.lk.failureMessage.toLowerCase() : (f.lk && f.lk.authenticatingPassword ? T.t("vérification") : T.t("mot de passe"))) + ": " + "*".repeat(Math.min(26, f.typed))
        font.family: f.mono; font.pixelSize: 14 * f.k; font.bold: true; color: f.ink
        Rectangle {
          anchors.left: parent.right; anchors.leftMargin: 2; anchors.verticalCenter: parent.verticalCenter
          width: 9 * f.k; height: 17 * f.k; color: f.ink
          SequentialAnimation on visible { loops: Animation.Infinite; PropertyAction { value: true } PauseAnimation { duration: 530 } PropertyAction { value: false } PauseAnimation { duration: 530 } }
        }
      }
    }
  }
  // Étiquettes autour
  Box {
    anchors.left: win.left; anchors.top: win.bottom; anchors.topMargin: 26 * f.k
    width: lblA.implicitWidth + 24 * f.k; height: 30 * f.k; fill: "#ffe14d"
    Text { id: lblA; anchors.centerIn: parent; text: "↵ " + T.t("entrée pour ouvrir"); font.family: f.mono; font.pixelSize: 12 * f.k; font.bold: true; color: f.ink }
  }
  Box {
    anchors.right: win.right; anchors.top: win.bottom; anchors.topMargin: 26 * f.k
    width: 40 * f.k; height: 30 * f.k
    Text { anchors.centerIn: parent; text: "power_settings_new"; font.family: "Material Symbols Rounded"; font.pixelSize: 18 * f.k; color: f.ink }
    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: if (f.lk) { f.lk.powerOpen = !f.lk.powerOpen; f.lk.forcePasswordFocus() } }
  }
}
