import QtQuick
import "T.js" as T

// Verrouillage du style Île : fond prune assombri, l'encoche noire en haut (cadenas, puis
// points du mot de passe quand elle s'élargit), l'heure large en Michroma avec A et M en
// chevrons, la date « SAMEDI 07 | 11 | 2026 », le nom et un champ souligné.
Item {
  id: f
  property var lock: null
  readonly property var lk: lock
  readonly property real k: Math.min(width / 1280, height / 720)
  readonly property color ink: "#c9c2cc"
  readonly property color sub: "#8a8490"
  readonly property rect fieldBox: {
    var c = field.mapToItem(f, 0, 0)
    return Qt.rect(c.x, c.y - 10, field.width, field.height + 14)
  }
  readonly property int typed: lk ? lk.passwordText.length : 0

  FaceWall { anchors.fill: parent; lk: f.lk; brightness: -0.25; saturation: -0.4; tint: Qt.rgba(0.09, 0.08, 0.11, 0.35) }

  // Encoche : fermée avec un cadenas, s'élargit pendant la saisie.
  Item {
    id: notch
    anchors.horizontalCenter: parent.horizontalCenter
    width: f.typed > 0 || (f.lk && f.lk.errorState) ? 300 * f.k : 180 * f.k
    height: f.typed > 0 || (f.lk && f.lk.errorState) ? 40 * f.k : 30 * f.k
    Behavior on width { SpringAnimation { spring: 3.5; damping: 0.32 } }
    Behavior on height { SpringAnimation { spring: 3.5; damping: 0.32 } }
    Rectangle { anchors.fill: parent; anchors.topMargin: -20; radius: 16 * f.k; color: "black" }
    // épaules concaves
    Canvas {
      x: -10 * f.k; width: 10 * f.k; height: 10 * f.k
      onPaint: { var c = getContext("2d"); c.reset(); c.fillStyle = "black"; c.beginPath(); c.moveTo(0, 0); c.lineTo(width, 0); c.lineTo(width, height); c.arc(0, height, width, 0, -Math.PI / 2, true); c.fill() }
    }
    Canvas {
      x: notch.width; width: 10 * f.k; height: 10 * f.k
      onPaint: { var c = getContext("2d"); c.reset(); c.fillStyle = "black"; c.beginPath(); c.moveTo(width, 0); c.lineTo(0, 0); c.lineTo(0, height); c.arc(width, height, width, Math.PI, -Math.PI / 2, false); c.fill() }
    }
    Text {
      anchors.centerIn: parent
      visible: f.typed === 0 && !(f.lk && f.lk.errorState)
      text: f.lk && f.lk.authenticatingPassword ? "progress_activity" : "lock"
      font.family: "Material Symbols Rounded"; font.pixelSize: 15 * f.k; color: f.ink
    }
    FaceDots { anchors.centerIn: parent; count: f.typed; size: 7 * f.k; color: f.ink; max: 22; visible: f.typed > 0 }
    Text {
      anchors.centerIn: parent
      visible: f.typed === 0 && f.lk && f.lk.errorState
      text: f.lk ? f.lk.failureMessage.toUpperCase() : ""
      font.family: "Michroma"; font.pixelSize: 9 * f.k; color: "#e8857c"
    }
  }

  Column {
    anchors.horizontalCenter: parent.horizontalCenter
    y: f.height * 0.24
    spacing: 22 * f.k
    IleWord {
      anchors.horizontalCenter: parent.horizontalCenter
      text: !f.lk ? "" : (f.lk.kcfg.clock_24h === false ? Qt.locale("en_US").toString(f.lk.now, "hh:mm AP").toUpperCase() : f.lk.hh + ":" + f.lk.mm)
      px: Math.round(78 * f.k); color: f.ink
    }
    IleWord {
      anchors.horizontalCenter: parent.horizontalCenter
      text: f.lk ? (f.lk.now.toLocaleDateString(Qt.locale(T.loc), "dddd") + "  " + Qt.formatDate(f.lk.now, "dd | MM | yyyy")).toUpperCase() : ""
      px: Math.round(16 * f.k); color: f.sub
    }
  }

  Column {
    anchors.horizontalCenter: parent.horizontalCenter
    y: f.height * 0.7
    spacing: 14 * f.k
    IleWord { anchors.horizontalCenter: parent.horizontalCenter; text: f.lk ? f.lk.userName.toUpperCase() : ""; px: Math.round(13 * f.k); color: f.ink }
    Item {
      id: field
      anchors.horizontalCenter: parent.horizontalCenter
      anchors.horizontalCenterOffset: f.lk ? f.lk.shakeX : 0
      width: 260 * f.k; height: 26 * f.k
      Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 1; color: f.lk && f.lk.errorState ? "#e8857c" : f.sub }
      Text {
        anchors.centerIn: parent
        visible: f.typed === 0
        text: f.lk && f.lk.authenticatingPassword ? T.t("VÉRIFICATION") : T.t("MOT DE PASSE")
        font.family: "Michroma"; font.pixelSize: 9 * f.k; font.letterSpacing: 3; color: f.sub
      }
      FaceDots { anchors.centerIn: parent; count: f.typed; size: 6 * f.k; color: f.ink; max: 24 }
    }
  }
}
