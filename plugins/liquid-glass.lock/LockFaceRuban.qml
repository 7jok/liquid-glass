import QtQuick
import "T.js" as T

// Verrouillage du style Rubans : bandes en biais sur le fond, date géante en italique,
// le jour dans un bloc noir penché, l'heure dans une étiquette blanche à ombre dure,
// le champ en parallélogramme. Les couleurs suivent ruban_tone.
Item {
  id: f
  property var lock: null
  readonly property var lk: lock
  readonly property real k: Math.min(width / 1280, height / 720)
  readonly property string tone: lk ? lk.tone("ruban_tone", "bleu") : "bleu"
  readonly property var tones: ({ bleu: ["#19d3ff", "#06102e"], rouge: ["#ff3b3b", "#16040a"], or: ["#ffc800", "#151003"],
                                  vert: ["#2ee88a", "#03140b"], violet: ["#c06bff", "#10041c"] })
  readonly property color acc: (tones[tone] || tones.bleu)[0]
  readonly property color deep: (tones[tone] || tones.bleu)[1]
  readonly property int typed: lk ? lk.passwordText.length : 0
  readonly property rect fieldBox: {
    var c = field.mapToItem(f, 0, 0)
    return Qt.rect(c.x, c.y, field.width, field.height)
  }
  readonly property string heavy: "Rubik"

  FaceWall { anchors.fill: parent; lk: f.lk; brightness: -0.35; saturation: -0.2 }

  // Bandes : elles entrent en glissant.
  property real t: 0
  Component.onCompleted: t = 1
  Behavior on t { NumberAnimation { duration: 700; easing.type: Easing.OutCubic } }
  Item {
    anchors.fill: parent
    rotation: -14
    Rectangle { x: -f.width * 0.3 + (1 - f.t) * -f.width; y: f.height * 0.58; width: f.width * 1.6; height: f.height * 0.2; color: f.deep; opacity: 0.92 }
    Rectangle { x: -f.width * 0.3 + (1 - f.t) * f.width; y: f.height * 0.53; width: f.width * 1.6; height: f.height * 0.05; color: f.acc }
    Rectangle { x: -f.width * 0.3 + (1 - f.t) * -f.width; y: f.height * 0.82; width: f.width * 1.6; height: 6 * f.k; color: "white" }
  }

  // Date géante.
  Text {
    x: f.width * 0.05; y: f.height * 0.02
    text: f.lk ? Qt.formatDate(f.lk.now, "dd") : ""
    font.family: f.heavy; font.pixelSize: 300 * f.k; font.weight: Font.Black; font.italic: true
    color: "transparent"; style: Text.Outline; styleColor: f.acc
    opacity: 0.9
  }
  Text {
    x: f.width * 0.05 + 210 * f.k; y: f.height * 0.17
    text: f.lk ? Qt.formatDate(f.lk.now, "MM") : ""
    font.family: f.heavy; font.pixelSize: 150 * f.k; font.weight: Font.Black; font.italic: true
    color: f.acc
  }
  // Jour
  Rectangle {
    x: f.width * 0.42; y: f.height * 0.18
    rotation: -8
    width: dayT.implicitWidth + 40 * f.k; height: 58 * f.k
    color: "black"
    Text { id: dayT; anchors.centerIn: parent; text: f.lk ? f.lk.now.toLocaleDateString(Qt.locale(T.loc), "dddd").toUpperCase() : ""
           font.family: f.heavy; font.pixelSize: 38 * f.k; font.weight: Font.Black; font.italic: true; color: f.acc }
  }
  // Heure
  Item {
    x: f.width * 0.5; y: f.height * 0.33
    rotation: -8
    width: timeT.implicitWidth + 50 * f.k; height: 96 * f.k
    Rectangle { x: 10 * f.k; y: 10 * f.k; width: parent.width; height: parent.height; color: "black" }
    Rectangle { anchors.fill: parent; color: "white"
      Text { id: timeT; anchors.centerIn: parent; text: f.lk ? f.lk.hh + ":" + f.lk.mm : ""
             font.family: f.heavy; font.pixelSize: 80 * f.k; font.weight: Font.Black; font.italic: true; color: f.deep } }
  }

  // Nom et champ, posés sur la bande sombre.
  Text {
    x: f.width * 0.1; y: f.height * 0.66
    rotation: -14
    text: (f.lk ? f.lk.userName : "").toUpperCase()
    font.family: f.heavy; font.pixelSize: 30 * f.k; font.weight: Font.Black; font.italic: true; color: "white"
  }
  Item {
    id: field
    x: f.width * 0.36 + (f.lk ? f.lk.shakeX : 0); y: f.height * 0.68
    width: 360 * f.k; height: 44 * f.k
    rotation: -14
    Rectangle { x: 7 * f.k; y: 7 * f.k; width: parent.width; height: parent.height; color: "black" }
    Rectangle {
      anchors.fill: parent; color: f.lk && f.lk.errorState ? "#ff3b3b" : "white"
      Text {
        anchors.centerIn: parent; visible: f.typed === 0
        text: f.lk && f.lk.authenticatingPassword ? T.t("VÉRIFICATION…") : f.lk && f.lk.errorState ? f.lk.failureMessage.toUpperCase() : T.t("MOT DE PASSE")
        font.family: f.heavy; font.pixelSize: 16 * f.k; font.weight: Font.Black; font.italic: true; color: f.deep
      }
      FaceDots { anchors.centerIn: parent; count: f.typed; size: 12 * f.k; radius: 0; color: f.deep }
    }
    Rectangle {
      anchors.left: parent.right; anchors.leftMargin: 10 * f.k; anchors.verticalCenter: parent.verticalCenter
      width: 44 * f.k; height: 44 * f.k; color: f.acc
      Text { anchors.centerIn: parent; text: "arrow_forward"; font.family: "Material Symbols Rounded"; font.pixelSize: 26 * f.k; color: f.deep }
      MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: if (f.lk) f.lk.accept() }
    }
  }
  // Alimentation
  Rectangle {
    anchors.right: parent.right; anchors.bottom: parent.bottom; anchors.margins: 18 * f.k
    width: 40 * f.k; height: width; color: "black"; rotation: -14
    Text { anchors.centerIn: parent; text: "power_settings_new"; font.family: "Material Symbols Rounded"; font.pixelSize: 22 * f.k; color: f.acc }
    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: if (f.lk) { f.lk.powerOpen = !f.lk.powerOpen; f.lk.forcePasswordFocus() } }
  }
}
