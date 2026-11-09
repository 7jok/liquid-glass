import QtQuick
import QtQuick.Shapes
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Widgets
import Quickshell.Services.SystemTray

// Style « mono » (caelestia, rice de sergioqtz) : barre noire verticale à gauche
// et cadre noir autour de l'écran, coins intérieurs arrondis.
//   haut : logo (lanceur) · points des bureaux · titre de la fenêtre active à la verticale
//   bas  : zone de notification · heure empilée (tableau de bord) · réseau, son,
//          batterie (réglages) · bouton rouge (session)
Scope {
  id: root
  property var service: null
  property var screen: null
  readonly property var s: service
  readonly property int barW: 44
  readonly property int frame: 8
  readonly property int cornerR: 18
  readonly property color black: s.monoFrame

  // ------------------------------------------------------------ cadre
  PanelWindow {
    screen: root.screen
    color: "transparent"
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Bottom
    WlrLayershell.namespace: "liquid-glass-mono-frame"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    mask: Region {}
    // Bord noir avec un trou aux coins arrondis.
    Shape {
      anchors.fill: parent
      preferredRendererType: Shape.CurveRenderer
      ShapePath {
        fillColor: root.black
        strokeWidth: -1
        fillRule: ShapePath.OddEvenFill
        // extérieur
        PathRectangle { x: 0; y: 0; width: frameWin.width; height: frameWin.height }
        // intérieur arrondi
        PathRectangle {
          x: root.barW; y: root.frame
          width: frameWin.width - root.barW - root.frame
          height: frameWin.height - 2 * root.frame
          radius: root.cornerR
        }
      }
    }
    Item { id: frameWin; anchors.fill: parent }
  }
  // Marges réservées (les fenêtres restent dans le cadre).
  PanelWindow {
    screen: root.screen; color: "transparent"
    anchors { top: true; left: true; right: true }
    implicitHeight: 1; exclusiveZone: root.frame
    WlrLayershell.namespace: "liquid-glass-mono-edge"; mask: Region {}
  }
  PanelWindow {
    screen: root.screen; color: "transparent"
    anchors { bottom: true; left: true; right: true }
    implicitHeight: 1; exclusiveZone: root.frame
    WlrLayershell.namespace: "liquid-glass-mono-edge"; mask: Region {}
  }
  PanelWindow {
    screen: root.screen; color: "transparent"
    anchors { top: true; bottom: true; right: true }
    implicitWidth: 1; exclusiveZone: root.frame
    WlrLayershell.namespace: "liquid-glass-mono-edge"; mask: Region {}
  }

  // ------------------------------------------------------------ barre
  PanelWindow {
    id: bar
    screen: root.screen
    color: "transparent"
    anchors { top: true; bottom: true; left: true }
    implicitWidth: root.barW
    exclusiveZone: root.barW
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.namespace: "liquid-glass-mono-bar"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    readonly property var monitor: root.screen ? Hyprland.monitorFor(root.screen) : Hyprland.focusedMonitor
    readonly property int activeWs: monitor && monitor.activeWorkspace ? monitor.activeWorkspace.id : 1
    readonly property var activeWin: Hyprland.activeToplevel
    property date now: new Date()
    Timer { interval: 1000; repeat: true; running: true; onTriggered: bar.now = new Date() }

    Rectangle { anchors.fill: parent; color: root.black }

    Column {
      id: top
      anchors.horizontalCenter: parent.horizontalCenter
      y: 10
      spacing: 14
      // Logo : un « C » épais à facettes, dessiné ici.
      Item {
        width: 26; height: 26
        anchors.horizontalCenter: parent.horizontalCenter
        Shape {
          anchors.fill: parent
          preferredRendererType: Shape.CurveRenderer
          ShapePath {
            fillColor: logoMa.containsMouse ? s.primary : s.colOnSurface
            strokeWidth: -1
            startX: 13; startY: 2
            PathLine { x: 24; y: 8 }
            PathLine { x: 19; y: 11 }
            PathLine { x: 13; y: 7.5 }
            PathLine { x: 7; y: 11 }
            PathLine { x: 7; y: 15 }
            PathLine { x: 13; y: 18.5 }
            PathLine { x: 19; y: 15 }
            PathLine { x: 24; y: 18 }
            PathLine { x: 13; y: 24 }
            PathLine { x: 2; y: 18 }
            PathLine { x: 2; y: 8 }
            PathLine { x: 13; y: 2 }
          }
        }
        Rectangle { x: 20; y: 11.5; width: 3; height: 3; radius: 1.5; color: s.primary }
        MouseArea { id: logoMa; anchors.fill: parent; hoverEnabled: true; onClicked: s.toggleLauncher() }
      }
      ClaudeButton { anchors.horizontalCenter: parent.horizontalCenter; anchors.verticalCenter: undefined; s: root.s; size: 30; iconSize: 18; mono: true; hover: s.surfaceHighest }
      // Bureaux : points, le bureau actif en pastille blanche.
      Column {
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: 6
        Repeater {
          model: Math.min(s.wsCount, 6)
          delegate: Item {
            id: ws
            required property int index
            readonly property int num: index + 1
            readonly property bool active: bar.activeWs === num
            readonly property bool used: { var w = Hyprland.workspaces.values; for (var i = 0; i < w.length; i++) if (w[i].id === num) return true; return false }
            width: 28; height: active ? 28 : 14
            Behavior on height { NumberAnimation { duration: 220; easing.type: Easing.OutBack } }
            Rectangle {
              anchors.centerIn: parent
              width: ws.active ? 24 : 5; height: ws.active ? 24 : 5; radius: width / 2
              color: ws.active ? s.primary : (ws.used ? s.colOnSurfaceVariant : s.outlineVariant)
              Behavior on width { NumberAnimation { duration: 220; easing.type: Easing.OutBack } }
              Behavior on height { NumberAnimation { duration: 220; easing.type: Easing.OutBack } }
              Text { visible: ws.active; anchors.centerIn: parent; text: ws.num; font.family: "Rubik"; font.pixelSize: 11; font.weight: Font.Bold; color: s.colOnPrimary }
            }
            MouseArea { anchors.fill: parent; onClicked: Quickshell.execDetached(["hyprctl", "dispatch", "hl.dsp.focus({ workspace = \"" + ws.num + "\" })"]) }
          }
        }
      }
    }
    // Titre de la fenêtre active, couché.
    Item {
      anchors.horizontalCenter: parent.horizontalCenter
      anchors.top: top.bottom; anchors.topMargin: 16
      anchors.bottom: bottom.top; anchors.bottomMargin: 16
      width: 20
      clip: true
      Column {
        visible: s.opt("mono_title", true) !== false
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: 8
        MIcon { anchors.horizontalCenter: parent.horizontalCenter; icon: "web_asset"; size: 15; color: s.secondary; visible: !!bar.activeWin }
        Item {
          width: 16; height: Math.min(titleTxt.implicitWidth, 260)
          anchors.horizontalCenter: parent.horizontalCenter
          Text {
            id: titleTxt
            text: bar.activeWin ? String(bar.activeWin.title || "") : ""
            rotation: 90
            transformOrigin: Item.TopLeft
            x: 14
            width: Math.min(implicitWidth, 260)
            elide: Text.ElideRight
            font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 11
            color: s.secondary
          }
        }
      }
    }

    Column {
      id: bottom
      anchors.horizontalCenter: parent.horizontalCenter
      anchors.bottom: parent.bottom
      anchors.bottomMargin: 10
      spacing: 12
      // Zone de notification
      Column {
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: 8
        Repeater {
          model: SystemTray.items
          delegate: Item {
            id: ti
            required property var modelData
            width: 18; height: 18
            anchors.horizontalCenter: parent.horizontalCenter
            IconImage { anchors.fill: parent; source: ti.modelData.icon; asynchronous: true }
            MouseArea {
              anchors.fill: parent
              acceptedButtons: Qt.LeftButton | Qt.RightButton
              onClicked: function(m) {
                if (m.button === Qt.RightButton || ti.modelData.onlyMenu) {
                  if (ti.modelData.hasMenu) { var p = ti.mapToItem(null, ti.width + 8, 0); ti.modelData.display(bar, p.x, p.y) }
                } else ti.modelData.activate()
              }
            }
          }
        }
      }
      // Heure empilée
      Column {
        anchors.horizontalCenter: parent.horizontalCenter
        Text { anchors.horizontalCenter: parent.horizontalCenter; text: Qt.formatTime(bar.now, "HH"); font.family: "Rubik"; font.pixelSize: 13; font.weight: Font.Medium; color: s.colOnSurface }
        Text { anchors.horizontalCenter: parent.horizontalCenter; text: Qt.formatTime(bar.now, "mm"); font.family: "Rubik"; font.pixelSize: 13; font.weight: Font.Medium; color: s.colOnSurface }
        MouseArea { width: 30; height: 34; x: -8; y: 0; onClicked: s.togglePanel("dashboard") }
      }
      // État
      Rectangle {
        anchors.horizontalCenter: parent.horizontalCenter
        width: 30; height: stat.implicitHeight + 16; radius: 15
        color: statMa.containsMouse ? s.surfaceHighest : s.surfaceHigh
        Column {
          id: stat
          anchors.centerIn: parent
          spacing: 8
          MIcon { anchors.horizontalCenter: parent.horizontalCenter; icon: s.netDev === "" ? "wifi_off" : (s.netWifi ? "wifi" : "lan"); size: 16; color: s.colOnSurface }
          MIcon { anchors.horizontalCenter: parent.horizontalCenter; icon: "bluetooth"; size: 16; color: s.colOnSurface }
          MIcon {
            visible: s.batteryPct >= 0
            anchors.horizontalCenter: parent.horizontalCenter; size: 16; color: s.batteryPct <= 15 && !s.charging ? s.errorColor : s.colOnSurface
            icon: s.charging ? "battery_charging_full" : ["battery_0_bar", "battery_1_bar", "battery_2_bar", "battery_3_bar", "battery_4_bar", "battery_5_bar", "battery_6_bar", "battery_full"][Math.max(0, Math.min(7, Math.round(s.batteryPct / 100 * 7)))]
          }
        }
        MouseArea { id: statMa; anchors.fill: parent; hoverEnabled: true; onClicked: s.toggleMenu("home") }
      }
      // Session
      Item {
        width: 26; height: 26
        anchors.horizontalCenter: parent.horizontalCenter
        MIcon { anchors.centerIn: parent; icon: "power_settings_new"; size: 18; weight: 600; color: pwMa.containsMouse ? Qt.lighter(s.tertiary, 1.15) : s.tertiary }
        MouseArea { id: pwMa; anchors.fill: parent; hoverEnabled: true; onClicked: s.togglePanel("session") }
      }
    }
  }
}
