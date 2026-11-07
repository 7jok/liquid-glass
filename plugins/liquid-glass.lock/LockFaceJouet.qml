import QtQuick
import "T.js" as T

// Verrouillage du style Jouet : chaque chiffre de l'heure est un cube de couleur au
// contour épais et à l'ombre dure, qui rebondit quand il change ; la date sur une
// étiquette, un champ épais en forme de pilule, des confettis qui tombent doucement.
// Couleurs : jouet_tone (bonbon, menthe, pêche, lagon, lilas).
Item {
  id: f
  property var lock: null
  readonly property var lk: lock
  readonly property real k: Math.min(width / 1280, height / 720)
  readonly property string tone: lk ? lk.tone("jouet_tone", "bonbon") : "bonbon"
  readonly property var tones: ({ bonbon: ["#ff5fa2", "#ffd23f", "#3ddbb4", "#6ec6ff", "#fff8ee"],
                                  menthe: ["#18b98f", "#ff7aa8", "#6ec6ff", "#ffd23f", "#f2fffa"],
                                  peche: ["#ff7a45", "#ff5fa2", "#7c6cff", "#ffd23f", "#fff6ef"],
                                  lagon: ["#1aa7ec", "#ffcf3f", "#ff6f91", "#3ddbb4", "#f0faff"],
                                  lilas: ["#9b6bff", "#ffb347", "#3ddbb4", "#ff5fa2", "#faf6ff"] })
  readonly property var c: tones[tone] || tones.bonbon
  readonly property color ink: "#1b1030"
  readonly property int typed: lk ? lk.passwordText.length : 0
  readonly property rect fieldBox: {
    var c = field.mapToItem(f, 0, 0)
    return Qt.rect(c.x, c.y, field.width, field.height)
  }

  FaceWall { anchors.fill: parent; lk: f.lk; blur: 0.5; brightness: 0.1; tint: Qt.rgba(1, 1, 1, 0.25) }

  // Confettis
  Repeater {
    model: 26
    Rectangle {
      required property int index
      width: (6 + index % 5 * 2) * f.k; height: width; radius: index % 3 === 0 ? width / 2 : 2
      color: f.c[index % 4]
      x: (index * 97 % 100) / 100 * f.width
      property real fall: 0
      y: -40 + ((index * 37 % 100) / 100 + fall) % 1 * (f.height + 80)
      rotation: fall * 720
      NumberAnimation on fall { from: 0; to: 1; duration: 9000 + index * 410; loops: Animation.Infinite }
    }
  }

  component Block: Item {
    id: b
    property string ch: ""
    property color col: "white"
    property real s: 1
    width: 120 * f.k; height: 140 * f.k
    onChChanged: { s = 0.7; pop.restart() }
    NumberAnimation { id: pop; target: b; property: "s"; to: 1; duration: 600; easing.type: Easing.OutElastic; easing.amplitude: 1.2; easing.period: 0.4 }
    scale: s
    Rectangle { x: 8 * f.k; y: 8 * f.k; width: parent.width; height: parent.height; radius: 26 * f.k; color: f.ink }
    Rectangle {
      anchors.fill: parent; radius: 26 * f.k; color: b.col; border.color: f.ink; border.width: 4 * f.k
      Rectangle { x: 14 * f.k; y: 12 * f.k; width: 26 * f.k; height: 10 * f.k; radius: 5 * f.k; color: "white"; opacity: 0.55 }
      Text { anchors.centerIn: parent; anchors.verticalCenterOffset: 4 * f.k; text: b.ch; color: f.ink
             font.family: "Google Sans Flex"; font.pixelSize: 110 * f.k; font.variableAxes: ({ "wght": 1000, "ROND": 100 }) }
    }
  }

  Row {
    id: clock
    anchors.horizontalCenter: parent.horizontalCenter
    y: f.height * 0.16
    spacing: 14 * f.k
    Block { ch: f.lk ? f.lk.hh.charAt(0) : ""; col: f.c[0]; rotation: -5 }
    Block { ch: f.lk ? f.lk.hh.charAt(1) : ""; col: f.c[1]; rotation: 3 }
    Item { width: 24 * f.k; height: 140 * f.k
      Column { anchors.centerIn: parent; spacing: 22 * f.k
        Repeater { model: 2; Rectangle { width: 18 * f.k; height: width; radius: width / 2; color: f.ink } } } }
    Block { ch: f.lk ? f.lk.mm.charAt(0) : ""; col: f.c[2]; rotation: -3 }
    Block { ch: f.lk ? f.lk.mm.charAt(1) : ""; col: f.c[3]; rotation: 5 }
  }
  Item {
    anchors.horizontalCenter: parent.horizontalCenter
    anchors.top: clock.bottom; anchors.topMargin: 30 * f.k
    width: dateT.implicitWidth + 36 * f.k; height: 40 * f.k
    rotation: -2
    Rectangle { x: 5 * f.k; y: 5 * f.k; width: parent.width; height: parent.height; radius: 20 * f.k; color: f.ink }
    Rectangle { anchors.fill: parent; radius: 20 * f.k; color: f.c[4]; border.color: f.ink; border.width: 3 * f.k
      Text { id: dateT; anchors.centerIn: parent; text: f.lk ? f.lk.now.toLocaleDateString(Qt.locale(T.loc), "dddd d MMMM") : ""
             font.family: "Rubik"; font.pixelSize: 18 * f.k; font.weight: Font.Bold; color: f.ink } }
  }

  Item {
    id: field
    anchors.horizontalCenter: parent.horizontalCenter
    anchors.horizontalCenterOffset: f.lk ? f.lk.shakeX : 0
    y: f.height * 0.7
    width: 380 * f.k; height: 56 * f.k
    Rectangle { x: 6 * f.k; y: 6 * f.k; width: parent.width; height: parent.height; radius: height / 2; color: f.ink }
    Rectangle {
      anchors.fill: parent; radius: height / 2; color: f.lk && f.lk.errorState ? "#ffd0d0" : "white"
      border.color: f.ink; border.width: 4 * f.k
      Text {
        anchors.centerIn: parent; visible: f.typed === 0
        text: f.lk && f.lk.authenticatingPassword ? T.t("Une seconde…") : f.lk && f.lk.errorState ? f.lk.failureMessage : "🔑 " + (f.lk ? f.lk.userName : "")
        font.family: "Rubik"; font.pixelSize: 17 * f.k; font.weight: Font.Bold; color: f.ink
      }
      Row {
        anchors.centerIn: parent; spacing: 6 * f.k
        Repeater {
          model: Math.min(16, f.typed)
          Rectangle {
            required property int index
            width: 16 * f.k; height: width; radius: index % 2 ? 4 : width / 2; color: f.c[index % 4]; border.color: f.ink; border.width: 2
            scale: 0; Component.onCompleted: scale = 1
            Behavior on scale { NumberAnimation { duration: 300; easing.type: Easing.OutBack; easing.overshoot: 3 } }
          }
        }
      }
    }
  }
  Item {
    anchors.right: parent.right; anchors.bottom: parent.bottom; anchors.margins: 22 * f.k
    width: 46 * f.k; height: width
    Rectangle { x: 4 * f.k; y: 4 * f.k; width: parent.width; height: parent.height; radius: 14 * f.k; color: f.ink }
    Rectangle { anchors.fill: parent; radius: 14 * f.k; color: f.c[0]; border.color: f.ink; border.width: 3 * f.k
      Text { anchors.centerIn: parent; text: "power_settings_new"; font.family: "Material Symbols Rounded"; font.pixelSize: 22 * f.k; color: f.ink } }
    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: if (f.lk) { f.lk.powerOpen = !f.lk.powerOpen; f.lk.forcePasswordFocus() } }
  }
}
