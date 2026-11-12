import QtQuick
import "T.js" as T

// Réglages Mono : le volet sort de la barre latérale de gauche, de la même
// couleur que le cadre (noir, papier ou prune), raccordé par des coins rentrants
// comme caelestia. Les pages sont des icônes rondes dans une colonne, la page
// s'affiche en lignes nues, blanc sur noir, police Rubik.
SetWin {
  id: w
  readonly property color frame: s.monoFrame
  readonly property color ink: s.colOnSurface
  readonly property color acc: s.primary
  readonly property int edge: 44
  readonly property string font: s.userFont || "Rubik"
  readonly property var look: ({ font: w.font, head: w.font, px: 14, ink: w.ink, sub: s.colOnSurfaceVariant, acc: w.ink, accInk: w.frame,
    tile: s.alpha(w.ink, 0.08), bcol: s.alpha(w.ink, 0.3), radius: 12, border: 0, toggle: "switch", knob: w.frame, slider: "line", chip: "pill", button: "pill",
    headColor: s.colOnSurfaceVariant, headPx: 12, headSpacing: 2, rowPad: 9 })

  Item {
    id: panel
    readonly property int r: Math.max(12, Number(s.opt("mono_corner", 18)))
    width: 600
    height: Math.min(parent.height - 40, 720)
    y: parent.height - height - 20
    x: w.revealed ? w.edge - 1 : w.edge - width - 2
    Behavior on x { NumberAnimation { duration: 380; easing.type: Easing.OutCubic } }
    MouseArea { anchors.fill: parent }
    Rectangle { anchors.fill: parent; radius: panel.r; color: w.frame }
    Rectangle { width: panel.r; height: parent.height; color: w.frame }
    // coins rentrants (haut et bas) : un carré du cadre moins un quart de disque
    Repeater {
      model: [0, 1]
      delegate: Item {
        required property int modelData
        x: 0; y: modelData === 0 ? -panel.r : panel.height
        width: panel.r; height: panel.r
        clip: true
        Canvas {
          anchors.fill: parent
          onPaint: {
            var c = getContext("2d"), R = panel.r
            c.reset(); c.fillStyle = w.frame
            c.beginPath()
            if (parent.modelData === 0) { c.moveTo(0, 0); c.lineTo(0, R); c.lineTo(R, R); c.arc(R, 0, R, Math.PI / 2, Math.PI, false) }
            else { c.moveTo(0, R); c.lineTo(0, 0); c.lineTo(R, 0); c.arc(R, R, R, -Math.PI / 2, Math.PI, true) }
            c.closePath(); c.fill()
          }
        }
      }
    }
    // colonne des pages
    Column {
      x: 18; y: 24; spacing: 8
      Repeater {
        model: w.core.pages
        delegate: Rectangle {
          id: pb
          required property var modelData
          readonly property bool cur: w.core.page === modelData[0]
          width: 44; height: 44; radius: 22
          color: cur ? w.ink : (pm.containsMouse ? s.alpha(w.ink, 0.12) : "transparent")
          Behavior on color { ColorAnimation { duration: 140 } }
          MIcon { anchors.centerIn: parent; icon: pb.modelData[2]; size: 21; fill: pb.cur ? 1 : 0; color: pb.cur ? w.frame : w.ink }
          MouseArea { id: pm; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: w.core.page = pb.modelData[0] }
        }
      }
    }
    Rectangle { x: 78; y: 24; width: 1; height: parent.height - 48; color: s.alpha(w.ink, 0.12) }
    Text {
      x: 100; y: 22
      text: w.core.pageInfo[1]
      font.family: s.userDisplay || "Rubik"; font.pixelSize: 34; font.weight: Font.Medium; color: w.ink
    }
    Text {
      x: 102; y: 64
      text: s.user + " — " + new Date().toLocaleDateString(Qt.locale("fr_FR"), "dddd d MMMM") + " — up " + s.uptimeText
      font.family: w.font; font.pixelSize: 12; color: s.colOnSurfaceVariant
    }
    SetList {
      x: 100; y: 96
      width: parent.width - x - 26; height: parent.height - y - 18
      core: w.core; look: w.look
      mode: "plain"; sepColor: s.alpha(w.ink, 0.08)
    }
  }
}
