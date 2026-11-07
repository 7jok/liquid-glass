import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.Commons
import qs.Commons as Commons
import "T.js" as T

// Fenêtre des widgets : couche « Bottom » (sur le fond d'écran, sous les fenêtres),
// ancrée en haut à gauche (ou à droite), sous la barre. Seule la zone des widgets
// existe : le reste du bureau reste cliquable normalement.
PanelWindow {
  id: win
  property var service: null

  readonly property real unit: Style.space(150)       // côté d'un petit widget
  readonly property real gap: Style.space(14)
  // Masqués quand la pochette sert de fond d'écran (elle prend alors cette place).
  readonly property bool shown: !!service && !(service.hideOnCover && service.coverWallpaper)

  color: "transparent"
  anchors { top: true; left: service ? service.side !== "right" : true; right: service ? service.side === "right" : false }
  // Marge intérieure « pad » : place pour les « − » qui débordent des coins en édition.
  readonly property real pad: Style.space(9)
  margins { top: Style.space(14) - pad; left: Style.space(22) - pad; right: Style.space(22) - pad }
  implicitWidth: flow.width + 2 * pad
  implicitHeight: Math.max(1, flow.implicitHeight) + 2 * pad + (editBar.visible ? editBar.height + Style.space(12) : 0)
  exclusionMode: ExclusionMode.Normal
  exclusiveZone: 0
  WlrLayershell.layer: WlrLayer.Bottom
  WlrLayershell.namespace: "liquid-glass-widgets"
  WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
  visible: flow.opacity > 0.01
  // Hors des cartes (coins arrondis, trous du Flow), les clics traversent.
  mask: Region { item: hit; Region { item: editBar } }
  Item { id: hit; x: flow.x - win.pad; y: flow.y - win.pad; width: flow.width + 2 * win.pad; height: flow.implicitHeight + 2 * win.pad }

  Binding {
    target: win.service
    property: "flowRect"
    value: !win.shown || flow.implicitHeight <= 1 ? Qt.rect(0, 0, 0, 0)
      : Qt.rect(win.service.side === "right" ? (win.screen ? win.screen.width : 1280) - Style.space(22) - flow.width : Style.space(22),
                Style.space(14), flow.width, flow.implicitHeight)
  }
  // La carte musique (MusicWindow) se place sous cette colonne si on la met en haut du même côté.
  Binding {
    target: win.service
    property: "flowBottom"
    value: win.shown && flow.implicitHeight > 1 ? Style.space(14) + flow.implicitHeight : 0
  }

  FileView {
    path: Quickshell.env("HOME") + "/.cache/liquid-glass/unlocked"
    watchChanges: true
    printErrors: false
    property bool primed: false
    onLoaded: { if (primed) arriveAnim.restart(); primed = true }
    onLoadFailed: primed = true
    onFileChanged: reload()
  }

  Flow {
    id: flow
    x: win.pad; y: win.pad
    // Assez large pour le plus grand widget visible (2 colonnes, 4 avec un XL).
    width: {
      var cols = 2
      if (win.service) {
        var keys = ["clock", "calendar", "weather", "battery"]
        for (var i = 0; i < keys.length; i++) if (win.service.sizeOf(keys[i]) === "xl") cols = 4
      }
      return win.unit * cols + win.gap * (cols - 1)
    }
    Behavior on width { NumberAnimation { duration: 380; easing.type: Easing.OutBack; easing.overshoot: 1.2 } }
    spacing: win.gap
    move: Transition { NumberAnimation { properties: "x,y"; duration: 420; easing.type: Easing.OutBack; easing.overshoot: 1.3 } }
    opacity: win.shown ? 1 : 0
    scale: win.shown ? 1 : 0.96
    transformOrigin: Item.TopLeft
    Behavior on opacity { NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }
    Behavior on scale { NumberAnimation { duration: 320; easing.type: Easing.OutBack; easing.overshoot: 1.2 } }
    // Après le déverrouillage, la colonne arrive du bord de l'écran (comme sur la vidéo).
    property real arrive: 1
    transform: Translate { x: (1 - flow.arrive) * (win.service && win.service.side === "right" ? 1 : -1) * (flow.width + Style.space(40)) }
    SequentialAnimation {
      id: arriveAnim
      PropertyAction { target: flow; property: "arrive"; value: 0 }
      PauseAnimation { duration: 280 }
      NumberAnimation { target: flow; property: "arrive"; to: 1; duration: 760; easing.type: Easing.OutBack; easing.overshoot: 1.3 }
    }

    ClockWidget { removeKey: "clock"; visible: !!win.service && win.service.showClock; svc: win.service; digital: !win.service || win.service.clockStyle !== "analog"; unit: win.unit; gap: win.gap }
    CalendarWidget { removeKey: "calendar"; visible: !!win.service && win.service.showCalendar; svc: win.service; unit: win.unit; gap: win.gap }
    WeatherWidget { removeKey: "weather"; visible: !!win.service && win.service.showWeather; svc: win.service; wide: width > height * 1.4; unit: win.unit; gap: win.gap }
    BatteryWidget { removeKey: "battery"; id: bat; visible: !!win.service && win.service.showBattery && bat.present; svc: win.service; unit: win.unit; gap: win.gap }
  }

  // Barre du mode édition : ajouter (Réglages → Bureau et Dock) et « Terminé ».
  Row {
    id: editBar
    x: win.pad
    y: flow.y + flow.implicitHeight + Style.space(12)
    spacing: Style.space(8)
    visible: !!win.service && win.service.editing
    opacity: visible ? 1 : 0
    Behavior on opacity { NumberAnimation { duration: 200 } }
    Repeater {
      model: [["add", T.t("＋  Modifier les widgets…")], ["done", T.t("Terminé")]]
      delegate: Rectangle {
        id: eb
        required property var modelData
        width: ebText.implicitWidth + Style.space(26); height: Style.space(28); radius: height / 2
        color: eb.modelData[0] === "done" ? Commons.Color.accent : (win.service && win.service.dark ? Qt.rgba(0.2, 0.2, 0.22, 0.85) : Qt.rgba(1, 1, 1, 0.8))
        border.width: 1; border.color: Qt.rgba(1, 1, 1, 0.4)
        scale: ebMouse.pressed ? 0.9 : 1
        Behavior on scale { NumberAnimation { duration: 300; easing.type: Easing.OutBack; easing.overshoot: 3 } }
        Text {
          id: ebText
          anchors.centerIn: parent
          textFormat: Text.PlainText
          text: eb.modelData[1]
          font.family: win.service ? win.service.uiFont : "Inter"; font.pixelSize: Style.space(12); font.weight: Font.DemiBold
          color: eb.modelData[0] === "done" ? "white" : (win.service && win.service.dark ? "#f5f5f7" : "#1d1d1f")
        }
        MouseArea {
          id: ebMouse
          anchors.fill: parent
          cursorShape: Qt.PointingHandCursor
          onClicked: {
            if (!win.service) return
            win.service.stopEditing()
            if (eb.modelData[0] === "add")
              Quickshell.execDetached(["omarchy-shell", "shell", "summon", "liquid-glass.settings", "{\"page\":\"desktop\"}"])
          }
        }
      }
    }
  }
}
