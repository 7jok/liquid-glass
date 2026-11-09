import QtQuick
import Quickshell
import Quickshell.Widgets
import "T.js" as T

// Verrouillage du style Infini : le fond de cerisiers assombri, l'horloge empilée
// (heures sur minutes, Bebas Neue), la date, l'avatar et une pilule de verre fumé
// bordée de rose pour le mot de passe.
Item {
  id: f
  property var lock: null
  readonly property var lk: lock
  readonly property real k: Math.min(width / 1280, height / 720)
  readonly property string tone: lk ? lk.tone("infini_tone", "sakura") : "sakura"
  readonly property color acc: ({ sakura: "#e8a3b4", lilas: "#c9b3f0", menthe: "#9fdcc4", peche: "#f5b896" })[tone] || "#e8a3b4"
  readonly property color ink: "#ece2e4"
  readonly property int typed: lk ? lk.passwordText.length : 0
  readonly property rect fieldBox: {
    var c = field.mapToItem(f, 0, 0)
    return Qt.rect(c.x, c.y, field.width, field.height)
  }

  FaceWall { anchors.fill: parent; lk: f.lk; blur: 0.35; brightness: -0.35; saturation: -0.1 }

  Column {
    anchors.horizontalCenter: parent.horizontalCenter
    y: f.height * 0.06
    spacing: -Math.round(118 * f.k)
    Text {
      anchors.horizontalCenter: parent.horizontalCenter
      text: f.lk ? f.lk.hh : ""
      font.family: "Bebas Neue"; font.pixelSize: Math.round(230 * f.k); color: Qt.rgba(1, 1, 1, 0.92)
    }
    Text {
      anchors.horizontalCenter: parent.horizontalCenter
      text: f.lk ? f.lk.mm : ""
      font.family: "Bebas Neue"; font.pixelSize: Math.round(230 * f.k); color: Qt.rgba(1, 1, 1, 0.42)
    }
  }
  Text {
    anchors.horizontalCenter: parent.horizontalCenter
    y: f.height * 0.69
    text: f.lk ? f.lk.now.toLocaleDateString(Qt.locale(T.loc), "dddd d MMMM") : ""
    font.family: "Inter"; font.pixelSize: Math.round(15 * f.k); font.letterSpacing: 1; color: f.ink
  }

  Row {
    anchors.horizontalCenter: parent.horizontalCenter
    anchors.horizontalCenterOffset: f.lk ? f.lk.shakeX : 0
    y: f.height * 0.76
    spacing: Math.round(10 * f.k)
    ClippingRectangle {
      width: Math.round(40 * f.k); height: width; radius: width / 2
      color: Qt.rgba(f.acc.r, f.acc.g, f.acc.b, 0.4)
      border.color: f.acc; border.width: 1
      Image { anchors.fill: parent; source: "file://" + Quickshell.env("HOME") + "/.face"; fillMode: Image.PreserveAspectCrop; sourceSize: Qt.size(96, 96) }
    }
    Rectangle {
      id: field
      anchors.verticalCenter: parent.verticalCenter
      width: Math.round(260 * f.k); height: Math.round(40 * f.k); radius: height / 2
      color: Qt.rgba(0.11, 0.09, 0.1, 0.7)
      border.color: f.lk && f.lk.errorState ? "#ff8a8f" : Qt.rgba(f.acc.r, f.acc.g, f.acc.b, 0.8); border.width: 1
      Text {
        anchors.centerIn: parent
        visible: f.typed === 0
        text: f.lk && f.lk.authenticatingPassword ? T.t("Vérification…") : (f.lk && f.lk.errorState ? f.lk.failureMessage : T.t("Mot de passe"))
        font.family: "Inter"; font.pixelSize: Math.round(13 * f.k)
        color: f.lk && f.lk.errorState ? "#ff8a8f" : Qt.rgba(f.ink.r, f.ink.g, f.ink.b, 0.55)
      }
      Row {
        anchors.centerIn: parent; spacing: Math.round(6 * f.k)
        Repeater {
          model: Math.min(16, f.typed)
          Rectangle { required property int index; width: Math.round(8 * f.k); height: width; radius: width / 2; color: f.acc }
        }
      }
    }
  }

  Rectangle {
    anchors.right: parent.right; anchors.bottom: parent.bottom; anchors.margins: Math.round(22 * f.k)
    width: Math.round(36 * f.k); height: width; radius: width / 2
    color: Qt.rgba(0.11, 0.09, 0.1, 0.7); border.color: Qt.rgba(1, 1, 1, 0.1); border.width: 1
    Text { anchors.centerIn: parent; text: "power_settings_new"; font.family: "Material Symbols Rounded"; font.pixelSize: Math.round(18 * f.k); color: f.ink }
    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: if (f.lk) { f.lk.powerOpen = !f.lk.powerOpen; f.lk.forcePasswordFocus() } }
  }
}
