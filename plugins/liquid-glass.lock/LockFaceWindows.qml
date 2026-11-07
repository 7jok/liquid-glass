import QtQuick
import Quickshell
import Quickshell.Widgets
import "T.js" as T

// Verrouillage du style Windows (écran de Windows 11) :
//  • d'abord le rideau : l'heure en grand en haut, la date dessous, réseau et batterie
//    en bas à droite ;
//  • une touche ou un clic : le rideau monte, le fond se floute, l'avatar rond, le nom
//    et le champ « Mot de passe » avec sa flèche apparaissent au centre.
// Teinte : windows_tone (clair, sombre).
Item {
  id: f
  property var lock: null
  readonly property var lk: lock
  readonly property real k: Math.min(width / 1280, height / 720)
  readonly property bool dark: lk && lk.tone("windows_tone", "clair") === "sombre"
  readonly property string font: "Inter"
  readonly property int typed: lk ? lk.passwordText.length : 0
  readonly property rect fieldBox: {
    var c = field.mapToItem(f, 0, 0)
    return Qt.rect(c.x, c.y, field.width, field.height)
  }
  LockData { id: data; running: true }

  property bool up: false
  onTypedChanged: if (typed > 0) up = true
  onLockChanged: if (lock && lock.passwordText.length > 0) up = true
  Timer { interval: 30000; running: f.up && f.typed === 0; onTriggered: f.up = false }
  MouseArea { anchors.fill: parent; onClicked: { f.up = true; if (f.lk) f.lk.forcePasswordFocus() } }

  property real u: up ? 1 : 0
  Behavior on u { NumberAnimation { duration: 420; easing.type: Easing.OutCubic } }
  FaceWall { anchors.fill: parent; lk: f.lk; blur: 0.9 * f.u; brightness: -0.12 * f.u }

  // Rideau
  Column {
    anchors.horizontalCenter: parent.horizontalCenter
    y: f.height * 0.12 - f.u * 120 * f.k
    opacity: 1 - f.u
    spacing: 0
    Text { anchors.horizontalCenter: parent.horizontalCenter; text: f.lk ? Qt.formatTime(f.lk.now, "HH:mm") : ""
           font.family: f.font; font.pixelSize: 120 * f.k; font.weight: Font.DemiBold; color: "white"
           style: Text.Raised; styleColor: Qt.rgba(0, 0, 0, 0.15) }
    Text { anchors.horizontalCenter: parent.horizontalCenter; text: f.lk ? f.lk.now.toLocaleDateString(Qt.locale(T.loc), "dddd d MMMM") : ""
           font.family: f.font; font.pixelSize: 22 * f.k; font.weight: Font.Medium; color: "white" }
  }
  Row {
    anchors.right: parent.right; anchors.bottom: parent.bottom; anchors.margins: 24 * f.k
    spacing: 16 * f.k
    Repeater {
      model: ["wifi", data.charging ? "battery_charging_full" : "battery_full", "power_settings_new"]
      Text {
        required property var modelData
        required property int index
        text: modelData; font.family: "Material Symbols Rounded"; font.pixelSize: 20 * f.k; color: "white"
        MouseArea { anchors.fill: parent; enabled: parent.index === 2; cursorShape: Qt.PointingHandCursor
                    onClicked: if (f.lk) { f.lk.powerOpen = !f.lk.powerOpen; f.lk.forcePasswordFocus() } }
      }
    }
  }

  // Connexion
  Column {
    anchors.horizontalCenter: parent.horizontalCenter
    y: f.height * 0.3 + (1 - f.u) * 40 * f.k
    opacity: f.u
    visible: opacity > 0
    spacing: 14 * f.k
    ClippingRectangle {
      anchors.horizontalCenter: parent.horizontalCenter
      width: 170 * f.k; height: width; radius: width / 2; color: "#5b6b7c"
      Image { anchors.fill: parent; source: "file://" + Quickshell.env("HOME") + "/.face"; fillMode: Image.PreserveAspectCrop; sourceSize: Qt.size(340, 340) }
    }
    Text { anchors.horizontalCenter: parent.horizontalCenter; text: f.lk ? f.lk.userName : ""; font.family: f.font; font.pixelSize: 28 * f.k; font.weight: Font.DemiBold; color: "white" }
    Item { width: 1; height: 6 * f.k }
    Rectangle {
      id: field
      anchors.horizontalCenter: parent.horizontalCenter
      anchors.horizontalCenterOffset: f.lk ? f.lk.shakeX : 0
      width: 300 * f.k; height: 36 * f.k; radius: 5 * f.k
      color: f.dark ? Qt.rgba(0.12, 0.12, 0.12, 0.75) : Qt.rgba(1, 1, 1, 0.72)
      border.color: Qt.rgba(1, 1, 1, 0.25)
      Rectangle { anchors.bottom: parent.bottom; anchors.horizontalCenter: parent.horizontalCenter; width: parent.width - 2; height: 2; radius: 1; color: f.lk && f.lk.errorState ? "#e81123" : "#0067c0" }
      Text {
        x: 12 * f.k; anchors.verticalCenter: parent.verticalCenter; visible: f.typed === 0
        text: f.lk && f.lk.authenticatingPassword ? T.t("Bienvenue") : T.t("Mot de passe")
        font.family: f.font; font.pixelSize: 13 * f.k; color: f.dark ? "#bdbdbd" : "#5f5f5f"
      }
      FaceDots { x: 12 * f.k; anchors.verticalCenter: parent.verticalCenter; count: f.typed; size: 7 * f.k; color: f.dark ? "white" : "#1b1b1b"; max: 26 }
      Rectangle {
        anchors.right: parent.right; anchors.rightMargin: 4 * f.k; anchors.verticalCenter: parent.verticalCenter
        width: 28 * f.k; height: 28 * f.k; radius: 4 * f.k; color: "#0067c0"
        Text { anchors.centerIn: parent; text: "arrow_forward"; font.family: "Material Symbols Rounded"; font.pixelSize: 17 * f.k; color: "white" }
        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: if (f.lk) f.lk.accept() }
      }
    }
    Text {
      anchors.horizontalCenter: parent.horizontalCenter
      visible: f.lk && f.lk.errorState
      text: f.lk ? f.lk.failureMessage : ""
      font.family: f.font; font.pixelSize: 13 * f.k; color: "white"
    }
    Text {
      anchors.horizontalCenter: parent.horizontalCenter
      text: T.t("Options de connexion"); font.family: f.font; font.pixelSize: 12 * f.k; color: "white"; opacity: 0.85
    }
  }
}
