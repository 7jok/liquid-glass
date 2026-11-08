import QtQuick
import "T.js" as T

// Verrouillage du style 7JOKS : noir, cadre fin, 7JOKS encadré au centre, l'heure,
// quelques lignes système, et une invite de terminal pour le mot de passe
// (« jok@7joks:~$ sudo unlock », une étoile par caractère, curseur bloc qui clignote).
Item {
  id: f
  property var lock: null
  readonly property var lk: lock
  readonly property real k: Math.min(width / 1280, height / 720)
  readonly property string tone: lk ? lk.tone("hud_tone", "blanc") : "blanc"
  readonly property color acc: ({ blanc: "#e6e6e6", cyan: "#aacfd1", ambre: "#ffb43c", vert: "#5cff8a", rouge: "#ff5a5a" })[tone] || "#e6e6e6"
  readonly property color dim: Qt.rgba(acc.r, acc.g, acc.b, 0.5)
  readonly property color faint: Qt.rgba(acc.r, acc.g, acc.b, 0.15)
  readonly property color bad: "#ff5a5a"
  readonly property string mono: "Share Tech Mono"
  readonly property int typed: lk ? lk.passwordText.length : 0
  readonly property rect fieldBox: {
    var c = prompt.mapToItem(f, 0, 0)
    return Qt.rect(c.x, c.y, prompt.width, prompt.height)
  }

  Rectangle { anchors.fill: parent; color: "black" }
  // Grille de points
  Canvas {
    anchors.fill: parent; opacity: 0.6
    onPaint: {
      var c = getContext("2d"); c.reset(); c.fillStyle = f.faint
      var st = Math.round(32 * f.k)
      for (var x = st; x < width; x += st) for (var y = st; y < height; y += st) c.fillRect(x, y, 1, 1)
    }
  }
  // Cadre de l'écran, coins épais
  Rectangle { anchors.fill: parent; anchors.margins: 14 * f.k; color: "transparent"; border.color: f.dim; border.width: 1 }
  Repeater {
    model: 4
    Item {
      required property int index
      x: index % 2 ? f.width - 14 * f.k - width : 14 * f.k
      y: index < 2 ? 14 * f.k : f.height - 14 * f.k - height
      width: 26 * f.k; height: 26 * f.k
      Rectangle { y: index < 2 ? 0 : parent.height - 3; width: parent.width; height: 3; color: f.acc }
      Rectangle { x: index % 2 ? parent.width - 3 : 0; width: 3; height: parent.height; color: f.acc }
    }
  }

  // Haut gauche : heure ; haut droite : date
  Text {
    x: 34 * f.k; y: 30 * f.k
    text: f.lk ? Qt.formatTime(f.lk.now, "HH:mm:ss").split("").join(" ") : ""
    font.family: "Michroma"; font.pixelSize: Math.round(30 * f.k); color: f.acc
  }
  Column {
    anchors.right: parent.right; anchors.rightMargin: 34 * f.k; y: 32 * f.k
    Text { anchors.right: parent.right; text: f.lk ? f.lk.now.toLocaleDateString(Qt.locale(T.loc), "dddd d MMMM yyyy").toUpperCase() : ""
           font.family: f.mono; font.pixelSize: Math.round(13 * f.k); color: f.acc; font.letterSpacing: 2 }
    Text { anchors.right: parent.right; text: T.t("SESSION VERROUILLÉE"); font.family: f.mono; font.pixelSize: Math.round(10 * f.k); color: f.dim; font.letterSpacing: 2 }
  }

  // Centre : 7JOKS encadré, lueur
  Item {
    id: logo
    anchors.horizontalCenter: parent.horizontalCenter
    y: f.height * 0.3
    width: name.implicitWidth + 60 * f.k; height: name.implicitHeight + 26 * f.k
    Rectangle { anchors.fill: parent; color: "transparent"; border.color: f.acc; border.width: 2 }
    Text {
      id: name
      anchors.centerIn: parent
      text: "7JOKS"
      font.family: "Michroma"; font.pixelSize: Math.round(54 * f.k); font.letterSpacing: 5 * f.k; color: f.acc
    }
  }
  Text {
    anchors.horizontalCenter: parent.horizontalCenter
    anchors.top: logo.bottom; anchors.topMargin: 16 * f.k
    text: T.t("Bon retour, ") + (f.lk ? f.lk.userName : "")
    font.family: f.mono; font.pixelSize: Math.round(16 * f.k); color: f.dim; font.letterSpacing: 2
  }

  // Invite du mot de passe
  property bool blink: true
  Timer { interval: 530; repeat: true; running: true; onTriggered: f.blink = !f.blink }
  Rectangle {
    id: prompt
    anchors.horizontalCenter: parent.horizontalCenter
    anchors.horizontalCenterOffset: f.lk ? f.lk.shakeX : 0
    y: f.height * 0.64
    width: 460 * f.k; height: 40 * f.k
    color: "transparent"; border.color: f.lk && f.lk.errorState ? f.bad : f.dim; border.width: 1
    Row {
      anchors.verticalCenter: parent.verticalCenter; x: 12 * f.k
      spacing: 0
      Text { text: (f.lk ? f.lk.userName : "") + "@7joks:~$ "; font.family: f.mono; font.pixelSize: Math.round(15 * f.k); color: f.dim }
      Text {
        text: f.lk && f.lk.authenticatingPassword ? T.t("vérification…")
            : (f.typed > 0 ? "*".repeat(Math.min(24, f.typed)) : "unlock")
        font.family: f.mono; font.pixelSize: Math.round(15 * f.k)
        color: f.typed > 0 ? f.acc : Qt.rgba(f.acc.r, f.acc.g, f.acc.b, 0.3)
      }
      Rectangle { anchors.verticalCenter: parent.verticalCenter; width: 9 * f.k; height: 17 * f.k; color: f.acc; visible: f.blink && f.typed > 0 }
    }
  }
  Text {
    anchors.horizontalCenter: parent.horizontalCenter
    anchors.top: prompt.bottom; anchors.topMargin: 10 * f.k
    text: f.lk && f.lk.errorState ? "[ " + T.t("ACCÈS REFUSÉ") + " ]  " + f.lk.failureMessage : T.t("Tape ton mot de passe puis Entrée")
    font.family: f.mono; font.pixelSize: Math.round(11 * f.k); font.letterSpacing: 1
    color: f.lk && f.lk.errorState ? f.bad : f.dim
  }

  // Bas : alimentation
  Rectangle {
    anchors.right: parent.right; anchors.bottom: parent.bottom; anchors.margins: 34 * f.k
    width: 34 * f.k; height: width; color: pw.containsMouse ? f.acc : "transparent"; border.color: f.dim; border.width: 1
    Text { anchors.centerIn: parent; text: "⏻"; font.family: f.mono; font.pixelSize: Math.round(16 * f.k); color: pw.containsMouse ? "black" : f.acc }
    MouseArea { id: pw; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                onClicked: if (f.lk) { f.lk.powerOpen = !f.lk.powerOpen; f.lk.forcePasswordFocus() } }
  }
}
