import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.Commons

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
  margins { top: Style.space(14); left: Style.space(22); right: Style.space(22) }
  implicitWidth: flow.width
  implicitHeight: Math.max(1, flow.implicitHeight)
  exclusionMode: ExclusionMode.Normal
  exclusiveZone: 0
  WlrLayershell.layer: WlrLayer.Bottom
  WlrLayershell.namespace: "liquid-glass-widgets"
  WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
  visible: flow.opacity > 0.01
  // Hors des cartes (coins arrondis, trous du Flow), les clics traversent.
  mask: Region { item: flow }

  // La carte musique (MusicWindow) se place sous cette colonne si on la met en haut du même côté.
  Binding {
    target: win.service
    property: "flowBottom"
    value: win.shown && flow.implicitHeight > 1 ? Style.space(14) + flow.implicitHeight : 0
  }

  Flow {
    id: flow
    width: win.unit * 2 + win.gap
    spacing: win.gap
    opacity: win.shown ? 1 : 0
    scale: win.shown ? 1 : 0.96
    transformOrigin: Item.TopLeft
    Behavior on opacity { NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }
    Behavior on scale { NumberAnimation { duration: 320; easing.type: Easing.OutBack; easing.overshoot: 1.2 } }

    ClockWidget { visible: !!win.service && win.service.showClock; svc: win.service; width: win.unit; height: win.unit }
    CalendarWidget { visible: !!win.service && win.service.showCalendar; svc: win.service; width: win.unit; height: win.unit }
    WeatherWidget { visible: !!win.service && win.service.showWeather; svc: win.service; width: win.unit; height: win.unit }
    BatteryWidget { id: bat; visible: !!win.service && win.service.showBattery && bat.present; svc: win.service; width: win.unit; height: win.unit }
  }
}
