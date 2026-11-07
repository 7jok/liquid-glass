import QtQuick
import qs.Commons
import qs.Commons as Commons

// Carte de verre d'un widget : coins arrondis façon macOS, liseré clair.
// Le flou d'arrière-plan est fait par Hyprland (règle de calque liquid-glass-widgets).
// Appui long : mode édition comme sur Mac/iPhone — les widgets tremblent, un « − »
// apparaît en haut à gauche ; un clic dessus retire le widget ([widgets] <clé> = false).
Item {
  id: tile
  property string removeKey: ""
  readonly property bool editing: !!svc && svc.editing === true
  property var svc: null
  property color tint: svc && svc.dark ? Qt.rgba(0.11, 0.11, 0.13, 0.55) : Qt.rgba(1, 1, 1, 0.58)
  property alias background: bg
  readonly property color fg: svc && svc.dark ? "#f5f5f7" : "#1d1d1f"
  readonly property color dim: svc && svc.dark ? Qt.rgba(1, 1, 1, 0.55) : Qt.rgba(0, 0, 0, 0.5)
  readonly property string font: svc ? svc.uiFont : "Inter"
  readonly property real radius: Style.space(24)
  default property alias content: inner.data

  // ---- taille (small 1×1, medium 2×1, large 2×2, xl 4×2), en « unités » de la colonne
  property real unit: 150
  property real gap: 14
  // Le widget musique gère sa taille lui-même (MusicWindow).
  readonly property bool sized: removeKey !== "" && removeKey !== "music"
  readonly property string size: svc && sized ? svc.sizeOf(removeKey) : "small"
  readonly property int cols: size === "xl" ? 4 : (size === "medium" || size === "large") ? 2 : 1
  readonly property int rowsN: size === "large" || size === "xl" ? 2 : 1
  // Facteur d'échelle du contenu : 1 en petit/moyen, 2 en grand/XL.
  readonly property real k: Math.min(width, height) / unit
  width: unit * cols + gap * (cols - 1)
  height: unit * rowsN + gap * (rowsN - 1)
  Behavior on width { enabled: tile.sized; NumberAnimation { duration: 420; easing.type: Easing.OutBack; easing.overshoot: 1.2 } }
  Behavior on height { enabled: tile.sized; NumberAnimation { duration: 420; easing.type: Easing.OutBack; easing.overshoot: 1.2 } }

  Rectangle {
    id: bg
    anchors.fill: parent
    radius: tile.radius
    color: tile.tint
    border.width: 1
    border.color: svc && svc.dark ? Qt.rgba(1, 1, 1, 0.12) : Qt.rgba(1, 1, 1, 0.65)
    clip: true
  }
  Item {
    id: inner
    anchors.fill: parent
  }

  // ---- mode édition
  TapHandler {
    longPressThreshold: 0.55
    onLongPressed: if (tile.svc && tile.removeKey !== "") tile.svc.startEditing()
  }
  // Tremblement : chaque widget a son propre rythme (comme sur iPhone).
  readonly property int jitter: 110 + Math.floor(Math.random() * 45)
  property real wob: 0
  rotation: wob
  SequentialAnimation {
    running: tile.editing
    loops: Animation.Infinite
    NumberAnimation { target: tile; property: "wob"; to: 1.3; duration: tile.jitter; easing.type: Easing.InOutSine }
    NumberAnimation { target: tile; property: "wob"; to: -1.3; duration: tile.jitter; easing.type: Easing.InOutSine }
    onRunningChanged: if (!running) tile.wob = 0
  }
  // Pendant l'édition, le contenu ne réagit plus (pas de clic par erreur).
  MouseArea {
    z: 9
    anchors.fill: parent
    visible: tile.editing
    onClicked: if (tile.svc) tile.svc.startEditing()
  }
  // Choix de la taille en mode édition : S · M · L · XL, en bas du widget.
  Rectangle {
    id: sizePill
    z: 10
    anchors.horizontalCenter: parent.horizontalCenter
    anchors.bottom: parent.bottom
    anchors.bottomMargin: Style.space(8)
    visible: scale > 0.01
    scale: tile.editing && tile.sized ? 1 : 0
    Behavior on scale { NumberAnimation { duration: 380; easing.type: Easing.OutBack; easing.overshoot: 2.2 } }
    width: sizeRow.implicitWidth + Style.space(6)
    height: Style.space(24)
    radius: height / 2
    color: Qt.rgba(0.16, 0.16, 0.18, 0.86)
    border.width: 1; border.color: Qt.rgba(1, 1, 1, 0.22)
    Row {
      id: sizeRow
      anchors.centerIn: parent
      spacing: 2
      Repeater {
        model: [["small", "S"], ["medium", "M"], ["large", "L"], ["xl", "XL"]]
        delegate: Rectangle {
          id: sz
          required property var modelData
          readonly property bool on: tile.size === modelData[0]
          width: Math.max(Style.space(22), szText.implicitWidth + Style.space(10)); height: Style.space(19)
          radius: height / 2
          color: on ? "white" : (szMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.18) : "transparent")
          Text {
            id: szText
            anchors.centerIn: parent
            textFormat: Text.PlainText
            text: sz.modelData[1]
            font.family: tile.font; font.pixelSize: Style.space(10); font.weight: Font.Bold
            color: sz.on ? "#1d1d1f" : "white"
          }
          MouseArea {
            id: szMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: if (tile.svc) tile.svc.setSize(tile.removeKey, sz.modelData[0])
          }
        }
      }
    }
  }
  Rectangle {
    id: minus
    z: 10
    x: -Style.space(7); y: -Style.space(7)
    width: Style.space(22); height: width; radius: width / 2
    visible: scale > 0.01
    scale: tile.editing && tile.removeKey !== "" ? (minusMouse.pressed ? 0.8 : 1) : 0
    Behavior on scale { NumberAnimation { duration: 380; easing.type: Easing.OutBack; easing.overshoot: 2.6 } }
    color: Qt.rgba(0.32, 0.32, 0.35, 0.92)
    border.width: 1; border.color: Qt.rgba(1, 1, 1, 0.35)
    Rectangle { anchors.centerIn: parent; width: parent.width * 0.46; height: Math.max(2, Math.round(parent.width * 0.1)); radius: height / 2; color: "white" }
    MouseArea {
      id: minusMouse
      anchors.fill: parent; anchors.margins: -4
      cursorShape: Qt.PointingHandCursor
      onClicked: if (tile.svc) tile.svc.removeWidget(tile.removeKey)
    }
  }
}
