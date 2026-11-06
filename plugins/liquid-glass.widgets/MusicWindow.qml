import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.Commons

// Widget « lecture en cours » libre sur le bureau.
// Fenêtre « Bottom » de tout l'écran utile, mais seule la carte reçoit les clics
// (masque) : le reste du bureau fonctionne normalement.
//   • glisser la carte : elle s'aimante à la position la plus proche parmi 9
//     (haut / milieu / bas × gauche / centre / droite), enregistrée dans
//     widgets.music_position ;
//   • au survol, une pastille S · M · L change la taille (widgets.music_size).
PanelWindow {
  id: win
  property var service: null

  readonly property real unit: Style.space(150)
  readonly property real gap: Style.space(14)
  readonly property real margin: Style.space(22)
  // En bas, on laisse la place du dock.
  readonly property real bottomMargin: Style.space(96)

  readonly property string size: service ? service.musicSize : "medium"
  readonly property real cardW: size === "small" ? unit : unit * 2 + gap
  readonly property real cardH: size === "large" ? unit * 2 + gap : unit

  // Reste visible quand la pochette sert de fond : c'est pendant la lecture
  // qu'on veut la voir (seuls les widgets fixes s'effacent alors).
  readonly property bool shown: !!service && service.showMusic && service.hasTrack

  color: "transparent"
  anchors { top: true; bottom: true; left: true; right: true }
  exclusionMode: ExclusionMode.Normal
  exclusiveZone: 0
  WlrLayershell.layer: WlrLayer.Bottom
  WlrLayershell.namespace: "liquid-glass-widgets"
  WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
  visible: holder.opacity > 0.01
  mask: Region {
    item: holder
    Region { item: sizePill }
  }

  // Position enregistrée, ou celle choisie à l'instant (en attendant que la
  // config relue confirme).
  property string pending: ""
  readonly property string anchorName: pending !== "" ? pending : (service ? service.musicPosition : "bottom-left")
  onAnchorNameChanged: if (service && pending === service.musicPosition) pending = ""

  // Les widgets fixes occupent le haut d'un côté : on se place dessous.
  readonly property real flowBottom: service ? service.flowBottom : 0
  function anchorX(name, w) {
    if (name.indexOf("left") !== -1) return margin
    if (name.indexOf("right") !== -1) return width - w - margin
    return Math.round((width - w) / 2)
  }
  function anchorY(name, h, w) {
    var x = anchorX(name, w)
    if (name.indexOf("top") === 0) {
      var side = service ? service.side : "left"
      var underFlow = flowBottom > 0 && ((side === "left" && name.indexOf("left") !== -1) || (side === "right" && name.indexOf("right") !== -1))
      return underFlow ? flowBottom + gap : Style.space(14)
    }
    if (name.indexOf("bottom") === 0) return height - h - bottomMargin
    return Math.round((height - h) / 2)
  }
  readonly property var anchorNames: ["top-left", "top-center", "top-right", "middle-left", "center", "middle-right",
                                      "bottom-left", "bottom-center", "bottom-right"]
  function nearest(cx, cy) {
    var best = anchorNames[0], bd = 1e12
    for (var i = 0; i < anchorNames.length; i++) {
      var n = anchorNames[i]
      var ax = anchorX(n, cardW) + cardW / 2, ay = anchorY(n, cardH, cardW) + cardH / 2
      var d = (ax - cx) * (ax - cx) + (ay - cy) * (ay - cy)
      if (d < bd) { bd = d; best = n }
    }
    return best
  }

  // Repères des 9 positions, visibles pendant le glissement.
  Repeater {
    model: drag.active ? win.anchorNames : []
    delegate: Rectangle {
      required property string modelData
      x: win.anchorX(modelData, win.cardW); y: win.anchorY(modelData, win.cardH, win.cardW)
      width: win.cardW; height: win.cardH
      radius: Style.space(24)
      color: Qt.rgba(1, 1, 1, win.nearest(holder.x + holder.width / 2, holder.y + holder.height / 2) === modelData ? 0.18 : 0.06)
      border.width: 1.5
      border.color: Qt.rgba(1, 1, 1, 0.35)
      Behavior on color { ColorAnimation { duration: 120 } }
    }
  }

  Item {
    id: holder
    width: win.cardW; height: win.cardH
    x: win.anchorX(win.anchorName, width)
    y: win.anchorY(win.anchorName, height, width)
    opacity: win.shown ? 1 : 0
    scale: drag.active ? 1.04 : (win.shown ? 1 : 0.96)
    z: 2
    Behavior on opacity { NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }
    Behavior on scale { NumberAnimation { duration: 220; easing.type: Easing.OutBack; easing.overshoot: 1.4 } }
    Behavior on x { enabled: !drag.active; SpringAnimation { spring: 3.2; damping: 0.36; epsilon: 0.3 } }
    Behavior on y { enabled: !drag.active; SpringAnimation { spring: 3.2; damping: 0.36; epsilon: 0.3 } }
    Behavior on width { NumberAnimation { duration: 280; easing.type: Easing.OutCubic } }
    Behavior on height { NumberAnimation { duration: 280; easing.type: Easing.OutCubic } }

    MusicWidget {
      id: card
      anchors.fill: parent
      svc: win.service
      size: win.size
    }

    // Glisser : sur toute la carte, mais les boutons de la carte gardent leurs clics
    // (cette zone est sous eux et ne prend que l'appui maintenu).
    DragHandler {
      id: drag
      target: holder
      cursorShape: Qt.ClosedHandCursor
      onActiveChanged: {
        if (active) return
        var n = win.nearest(holder.x + holder.width / 2, holder.y + holder.height / 2)
        win.pending = n
        // Repart vers l'ancre (le Behavior se réactive à la fin du glissement).
        holder.x = Qt.binding(function() { return win.anchorX(win.anchorName, holder.width) })
        holder.y = Qt.binding(function() { return win.anchorY(win.anchorName, holder.height, holder.width) })
        if (win.service) win.service.setOption("music_position", n)
      }
    }
    HoverHandler { id: hover }

    // Pastille de taille, au survol.
    Rectangle {
      id: sizePill
      // À cheval sur le bord bas : pas de trou entre la carte et la pastille.
      anchors.horizontalCenter: parent.horizontalCenter
      anchors.verticalCenter: parent.bottom
      width: pillRow.implicitWidth + 8; height: Style.space(24); radius: height / 2
      color: Qt.rgba(0, 0, 0, 0.45)
      border.width: 1; border.color: Qt.rgba(1, 1, 1, 0.25)
      opacity: (hover.hovered || pillHover.hovered) && !drag.active ? 1 : 0
      visible: opacity > 0.01
      Behavior on opacity { NumberAnimation { duration: 160 } }
      HoverHandler { id: pillHover }
      Row {
        id: pillRow
        anchors.centerIn: parent
        spacing: 2
        Repeater {
          model: [["small", "S"], ["medium", "M"], ["large", "L"]]
          delegate: Rectangle {
            required property var modelData
            readonly property bool on: win.size === modelData[0]
            width: Style.space(26); height: sizePill.height - 6; radius: height / 2
            color: on ? Qt.rgba(1, 1, 1, 0.85) : "transparent"
            Text {
              anchors.centerIn: parent
              textFormat: Text.PlainText
              text: parent.modelData[1]
              font.family: card.font; font.pixelSize: Style.space(11); font.weight: Font.DemiBold
              color: parent.on ? "#1d1d1f" : "white"
            }
            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: if (win.service) win.service.setOption("music_size", parent.modelData[0]) }
          }
        }
      }
    }
  }
}
