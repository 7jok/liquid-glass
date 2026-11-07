import QtQuick
import Quickshell.Io
import "T.js" as T

// Verrouillage du style Lain : un vieux moniteur. Fond presque noir, lignes de balayage,
// léger tremblement, texte en chasse fixe qui s'écrit tout seul ; l'heure en grand,
// une invite de connexion et un curseur bloc qui clignote.
Item {
  id: f
  property var lock: null
  readonly property var lk: lock
  readonly property real k: Math.min(width / 1280, height / 720)
  readonly property color ink: "#e6e6e6"
  readonly property color red: "#d64545"
  readonly property string mono: "JetBrainsMono Nerd Font"
  readonly property int typed: lk ? lk.passwordText.length : 0
  readonly property rect fieldBox: {
    var c = field.mapToItem(f, 0, 0)
    return Qt.rect(c.x, c.y, field.width, field.height)
  }
  property string host: "linux"
  FileView { path: "/etc/hostname"; printErrors: false; onLoaded: f.host = text().trim() || "linux" }

  FaceWall { anchors.fill: parent; lk: f.lk; saturation: -1; brightness: -0.72; blur: 0.15 }

  // Lignes qui s'écrivent
  readonly property var lines: ["> " + T.t("session verrouillée"), "> " + T.t("noeud") + " : " + host, "> " + T.t("utilisateur") + " : " + (lk ? lk.userName : ""),
                                "> " + T.t("liaison") + " ............ OK", "> " + T.t("en attente d'identification_")]
  property int shown: 0
  Timer { interval: 70; repeat: true; running: f.shown < 400; onTriggered: f.shown++ }
  Column {
    x: 60 * f.k; y: 60 * f.k
    spacing: 6 * f.k
    Repeater {
      model: f.lines
      Text {
        required property var modelData
        required property int index
        readonly property int before: f.lines.slice(0, index).join("").length
        text: modelData.slice(0, Math.max(0, f.shown - before))
        font.family: f.mono; font.pixelSize: 14 * f.k; color: index === 0 ? f.red : f.ink
      }
    }
  }

  Item {
    id: big
    anchors.centerIn: parent
    anchors.verticalCenterOffset: -30 * f.k
    width: t1.implicitWidth; height: t1.implicitHeight
    property real jx: 0
    Timer { interval: 1800; repeat: true; running: true; onTriggered: { big.jx = (Math.random() - 0.5) * 10 * f.k; jit.restart() } }
    Timer { id: jit; interval: 90; onTriggered: big.jx = 0 }
    Text { x: big.jx * 1.6; text: t1.text; font: t1.font; color: f.red; opacity: big.jx !== 0 ? 0.7 : 0 }
    Text { id: t1; x: big.jx; text: f.lk ? f.lk.hh + ":" + f.lk.mm : ""; font.family: f.mono; font.pixelSize: 150 * f.k; font.weight: Font.Bold; color: f.ink }
  }
  Text {
    anchors.horizontalCenter: parent.horizontalCenter
    anchors.top: big.bottom
    text: f.lk ? f.lk.now.toLocaleDateString(Qt.locale(T.loc), "yyyy.MM.dd  dddd").toUpperCase() : ""
    font.family: f.mono; font.pixelSize: 14 * f.k; font.letterSpacing: 4; color: f.ink; opacity: 0.7
  }

  Item {
    id: field
    anchors.horizontalCenter: parent.horizontalCenter
    anchors.horizontalCenterOffset: f.lk ? f.lk.shakeX : 0
    y: f.height * 0.72
    width: 460 * f.k; height: 32 * f.k
    Row {
      anchors.verticalCenter: parent.verticalCenter
      spacing: 0
      Text {
        text: (f.lk && f.lk.errorState && f.typed === 0 ? "! " + f.lk.failureMessage.toLowerCase() + " — " : "") + (f.lk ? f.lk.userName : "") + "@" + f.host + " " + T.t("mot de passe") + ": " + "#".repeat(Math.min(24, f.typed))
        font.family: f.mono; font.pixelSize: 15 * f.k; color: f.lk && f.lk.errorState ? f.red : f.ink
      }
      Rectangle {
        width: 10 * f.k; height: 18 * f.k; color: f.ink; anchors.verticalCenter: parent.verticalCenter
        SequentialAnimation on opacity { loops: Animation.Infinite; NumberAnimation { to: 0; duration: 1 } PauseAnimation { duration: 480 } NumberAnimation { to: 1; duration: 1 } PauseAnimation { duration: 480 } }
      }
    }
  }

  // Lignes de balayage et vignette
  Canvas {
    anchors.fill: parent
    onPaint: { var c = getContext("2d"); c.fillStyle = "rgba(0,0,0,0.28)"; for (var y = 0; y < height; y += 3) c.fillRect(0, y, width, 1) }
  }
  Rectangle {
    anchors.fill: parent
    gradient: Gradient { GradientStop { position: 0; color: Qt.rgba(0, 0, 0, 0.35) } GradientStop { position: 0.2; color: "transparent" }
                         GradientStop { position: 0.8; color: "transparent" } GradientStop { position: 1; color: Qt.rgba(0, 0, 0, 0.45) } }
  }
  Rectangle {
    anchors.fill: parent; color: "white"; opacity: 0
    SequentialAnimation on opacity { loops: Animation.Infinite; PauseAnimation { duration: 5200 } NumberAnimation { to: 0.04; duration: 40 } NumberAnimation { to: 0; duration: 120 } }
  }
  Text {
    anchors.right: parent.right; anchors.bottom: parent.bottom; anchors.margins: 22 * f.k
    text: "[" + T.t("éteindre") + "]"; font.family: f.mono; font.pixelSize: 12 * f.k; color: f.ink; opacity: 0.7
    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: if (f.lk) { f.lk.powerOpen = !f.lk.powerOpen; f.lk.forcePasswordFocus() } }
  }
}
