import QtQuick
import "T.js" as T

// Verrouillage du style Sombre (mur de paroles, tacoproz) : fond presque noir, l'heure
// géante en deux lignes qui remplit la gauche, en contour, les minutes pleines ; à droite
// le mot du moment en capitales qui change, et un champ souligné en machine à écrire.
// Couleurs : sombre_tone (encre, ambre, glace, sang, indigo).
Item {
  id: f
  property var lock: null
  readonly property var lk: lock
  readonly property real k: Math.min(width / 1280, height / 720)
  readonly property string tone: lk ? lk.tone("sombre_tone", "encre") : "encre"
  readonly property var tones: ({ encre: "#e8e8e8", ambre: "#ffb35c", glace: "#9fd8ff", sang: "#ff4d5e", indigo: "#8f8bff" })
  readonly property color acc: tones[tone] || tones.encre
  readonly property int typed: lk ? lk.passwordText.length : 0
  readonly property rect fieldBox: {
    var c = field.mapToItem(f, 0, 0)
    return Qt.rect(c.x, c.y, field.width, field.height)
  }
  readonly property var words: [T.t("SILENCE"), T.t("PAUSE"), T.t("ATTENDS"), T.t("REVIENS"), T.t("RESPIRE"), T.t("ICI")]
  property int wi: 0
  Timer { interval: 2600; running: true; repeat: true; onTriggered: f.wi = (f.wi + 1) % f.words.length }

  FaceWall { anchors.fill: parent; lk: f.lk; brightness: -0.7; saturation: -0.8; blur: 0.4 }

  Column {
    x: 50 * f.k; y: f.height * 0.04
    spacing: -70 * f.k
    Text { text: f.lk ? f.lk.hh : ""; font.family: "Rubik"; font.pixelSize: 330 * f.k; font.weight: Font.Black; color: "transparent"; style: Text.Outline; styleColor: f.acc }
    Text { text: f.lk ? f.lk.mm : ""; font.family: "Rubik"; font.pixelSize: 330 * f.k; font.weight: Font.Black; color: f.acc }
  }

  Column {
    anchors.right: parent.right; anchors.rightMargin: 70 * f.k
    y: f.height * 0.22
    spacing: 10 * f.k
    Text {
      anchors.right: parent.right
      text: f.words[f.wi]
      font.family: "Rubik"; font.pixelSize: 64 * f.k; font.weight: Font.Black; color: "white"
      SequentialAnimation on opacity { running: true; loops: Animation.Infinite; PauseAnimation { duration: 2300 } NumberAnimation { to: 0.15; duration: 150 } NumberAnimation { to: 1; duration: 150 } }
    }
    Text {
      anchors.right: parent.right
      text: f.lk ? f.lk.now.toLocaleDateString(Qt.locale(T.loc), "dddd d MMMM yyyy").toUpperCase() : ""
      font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 12 * f.k; font.letterSpacing: 3; color: f.acc
    }
  }

  Column {
    anchors.right: parent.right; anchors.rightMargin: 70 * f.k
    y: f.height * 0.68
    spacing: 8 * f.k
    Text { anchors.right: parent.right; text: "~ " + (f.lk ? f.lk.userName : ""); font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 13 * f.k; color: "white"; opacity: 0.7 }
    Item {
      id: field
      anchors.right: parent.right
      anchors.rightMargin: f.lk ? -f.lk.shakeX : 0
      width: 340 * f.k; height: 34 * f.k
      Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 2; color: f.lk && f.lk.errorState ? "#ff4d5e" : f.acc }
      Text {
        anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter
        text: (f.lk && f.lk.errorState && f.typed === 0 ? f.lk.failureMessage : (f.lk && f.lk.authenticatingPassword ? T.t("vérification") : T.t("mot de passe"))) + " › " + "*".repeat(Math.min(24, f.typed))
        font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 14 * f.k; color: "white"
      }
      Rectangle {
        anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
        width: 10 * f.k; height: 18 * f.k; color: f.acc
        SequentialAnimation on opacity { loops: Animation.Infinite; NumberAnimation { to: 0; duration: 500 } NumberAnimation { to: 1; duration: 500 } }
      }
    }
  }
  Text {
    anchors.right: parent.right; anchors.bottom: parent.bottom; anchors.margins: 20 * f.k
    text: "power_settings_new"; font.family: "Material Symbols Rounded"; font.pixelSize: 22 * f.k; color: f.acc
    MouseArea { anchors.fill: parent; anchors.margins: -8; cursorShape: Qt.PointingHandCursor; onClicked: if (f.lk) { f.lk.powerOpen = !f.lk.powerOpen; f.lk.forcePasswordFocus() } }
  }
}
