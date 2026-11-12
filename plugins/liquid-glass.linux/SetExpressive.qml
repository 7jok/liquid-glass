import QtQuick
import QtQuick.Effects
import "T.js" as T

// Réglages Expressive : un volet Material 3 Expressive qui glisse depuis la
// droite sur toute la hauteur, rail de navigation à pilules (icône pleine sur la
// page en cours), en-tête avec une forme « cookie » qui tourne derrière l'icône,
// groupes de réglages en listes segmentées très arrondies, interrupteurs M3.
SetWin {
  id: w
  veil: Qt.rgba(0, 0, 0, 0.3)
  readonly property color ink: s.colOnSurface
  readonly property color acc: s.primary
  readonly property string font: s.userFont || "Google Sans Flex"
  readonly property var look: ({ font: w.font, head: w.font, px: 14, ink: w.ink, sub: s.colOnSurfaceVariant, acc: w.acc, accInk: s.colOnPrimary,
    tile: s.surfaceHighest, bcol: s.outlineVariant, radius: 14, border: 0, toggle: "m3", slider: "m3", chip: "pill", button: "solid",
    headColor: w.acc, headPx: 14, headWeight: Font.DemiBold, rowPad: 12, listBg: true })

  Item {
    id: sheet
    width: Math.min(parent.width * 0.5, 640)
    height: parent.height - 16
    y: 8
    x: w.revealed ? parent.width - width - 8 : parent.width + 20
    Behavior on x { NumberAnimation { duration: 520; easing.type: Easing.OutBack; easing.overshoot: 1.1 } }
    MouseArea { anchors.fill: parent }
    RectangularShadow { anchors.fill: bg; radius: 34; blur: 40; offset.x: -6; color: Qt.rgba(0, 0, 0, 0.35) }
    Rectangle { id: bg; anchors.fill: parent; radius: 34; color: s.surfaceLow }

    // ---- rail
    Column {
      id: rail
      x: 12; y: 22; width: 84
      spacing: 6
      Rectangle {
        width: 56; height: 56; radius: 18; anchors.horizontalCenter: parent.horizontalCenter
        color: s.tertiaryContainer
        MIcon { anchors.centerIn: parent; icon: "close"; size: 24; color: s.colOnTertiaryContainer }
        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: w.core.close() }
      }
      Item { width: 1; height: 10 }
      Repeater {
        model: w.core.pages
        delegate: Item {
          id: it
          required property var modelData
          readonly property bool cur: w.core.page === modelData[0]
          width: 84; height: 58
          Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter; y: 2
            width: it.cur ? 60 : (im.containsMouse ? 52 : 34); height: 32; radius: 16
            color: it.cur ? s.secondaryContainer : (im.containsMouse ? s.alpha(w.ink, 0.08) : "transparent")
            Behavior on width { NumberAnimation { duration: 280; easing.type: Easing.OutBack } }
            MIcon { anchors.centerIn: parent; icon: it.modelData[2]; size: 22; fill: it.cur ? 1 : 0; color: it.cur ? s.colOnSecondaryContainer : s.colOnSurfaceVariant }
          }
          Text {
            anchors.horizontalCenter: parent.horizontalCenter; y: 38
            width: 82; horizontalAlignment: Text.AlignHCenter; elide: Text.ElideRight
            text: it.modelData[1]; font.family: w.font; font.pixelSize: 11; font.weight: it.cur ? Font.Bold : Font.Medium
            color: it.cur ? w.ink : s.colOnSurfaceVariant
          }
          MouseArea { id: im; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: w.core.page = it.modelData[0] }
        }
      }
    }
    // ---- en-tête
    Item {
      id: head
      x: 108; y: 22; width: parent.width - x - 24; height: 96
      Cookie {
        id: ck
        width: 76; height: 76
        anchors.verticalCenter: parent.verticalCenter
        color: s.primaryContainer
        lobes: Number(s.opt("expressive_lobes", 10))
        RotationAnimation on rotation { from: 0; to: 360; duration: 24000; loops: Animation.Infinite; running: w.revealed }
      }
      MIcon { anchors.centerIn: ck; icon: w.core.pageInfo[2]; size: 32; fill: 1; color: s.colOnPrimaryContainer }
      Column {
        x: 96; anchors.verticalCenter: parent.verticalCenter
        Text { text: w.core.pageInfo[1]; font.family: s.userDisplay || "Unbounded"; font.pixelSize: 30; font.weight: Font.Bold; color: w.ink }
        Text { text: T.t("Réglages · ") + s.user + " · " + w.core.batteryText; font.family: w.font; font.pixelSize: 13; color: s.colOnSurfaceVariant }
      }
    }
    SetList {
      x: 108; y: 128
      width: parent.width - x - 20; height: parent.height - y - 12
      core: w.core; look: w.look
      mode: "boxed"; gap: 6; boxPad: 14
      boxColor: s.surfaceMid; boxRadius: 28; sepColor: s.alpha(w.ink, 0.06)
    }
  }
}
