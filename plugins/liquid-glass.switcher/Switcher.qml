import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.Commons
import qs.Commons as Commons
import qs.Ui

// ============================================================================
// Liquid Glass — sélecteur d'applications façon ⌘Tab.
//   SUPER+Tab (maintenir SUPER) : ouvre / app suivante ; SUPER+Maj+Tab : précédente.
//   Relâcher SUPER : active l'app (sa fenêtre la plus récente). Échap : annuler.
//   Les apps sont triées par usage récent (focusHistoryID de Hyprland).
// Appel : omarchy-shell shell summon liquid-glass.switcher '{"dir":1}'
// IPC de secours : omarchy-shell liquid-glass.switcher commit|cancel
// ============================================================================
Item {
  id: root

  property var shell: null
  property var manifest: null
  property bool opened: false

  property var apps: []         // [{ cls, name, icon, windows: [client…] }]
  property int selected: 0
  property int pendingSteps: 0  // pressions de Tab reçues avant l'arrivée de la liste

  readonly property string uiFont: "Inter"
  readonly property real iconSize: Style.space(72)

  function build(clients) {
    var byClass = ({}), order = []
    clients = clients.filter(function(c) { return c.mapped && !c.hidden && c.workspace && c.workspace.id > 0 })
    clients.sort(function(a, b) { return a.focusHistoryID - b.focusHistoryID })
    for (var i = 0; i < clients.length; i++) {
      var c = clients[i]
      var key = c.class || c.initialClass || c.title
      if (!byClass[key]) {
        var e = DesktopEntries.heuristicLookup(key)
        byClass[key] = {
          cls: key,
          name: e && e.name ? e.name : root.prettyClass(key),
          icon: Quickshell.iconPath(e && e.icon ? e.icon : key, true) || Quickshell.iconPath("application-x-executable", true),
          windows: []
        }
        order.push(key)
      }
      byClass[key].windows.push(c)
    }
    return order.map(function(k) { return byClass[k] })
  }

  // « org.omarchy.agent » → « Agent » quand l'app n'a pas de fichier .desktop.
  function prettyClass(cls) {
    var last = String(cls || "").split(".").pop().replace(/[-_]+/g, " ")
    return last.charAt(0).toUpperCase() + last.slice(1)
  }

  function step(dir) {
    if (apps.length === 0) return
    selected = (selected + dir + apps.length) % apps.length
  }

  Process {
    id: fetch
    command: ["hyprctl", "-j", "clients"]
    stdout: StdioCollector {
      onStreamFinished: {
        var list = []
        try { list = JSON.parse(text) } catch (e) { list = [] }
        root.apps = root.build(list)
        if (root.apps.length === 0) { root.dismiss(); return }
        // Comme macOS : la 1re pression vise l'app précédente.
        root.selected = 0
        root.step(root.pendingSteps)
        root.pendingSteps = 0
        win.shown = true
      }
    }
  }

  function open(payloadJson) {
    var dir = 1
    try { var p = JSON.parse(payloadJson || "{}"); if (p.dir === -1) dir = -1 } catch (e) {}
    if (opened) {
      if (fetch.running) pendingSteps += dir
      else step(dir)
      return
    }
    opened = true
    apps = []
    pendingSteps = dir
    fetch.running = true
  }

  function commit() {
    if (!opened) return
    var app = apps[selected]
    dismiss()
    if (app && app.windows.length)
      Util.execArgv(["hyprctl", "dispatch", 'hl.dsp.focus({ window = "address:' + app.windows[0].address + '" })'])
  }
  function close() { opened = false; win.shown = false }
  function dismiss() {
    close()
    if (shell && typeof shell.hide === "function") shell.hide((manifest && manifest.id) || "liquid-glass.switcher")
  }

  ShellIpc {
    target: "liquid-glass.switcher"
    function commit(): void { root.commit() }
    function cancel(): void { root.dismiss() }
  }

  OverlayWindow {
    id: win
    WlrLayershell.namespace: "liquid-glass-switcher"

    Item {
      id: keys
      anchors.fill: parent
      focus: true
      // Relâcher SUPER valide la sélection (l'overlay a le focus clavier exclusif).
      Keys.onReleased: function(ev) {
        if (ev.key === Qt.Key_Super_L || ev.key === Qt.Key_Super_R || ev.key === Qt.Key_Meta) { root.commit(); ev.accepted = true }
      }
      Keys.onPressed: function(ev) {
        if (ev.key === Qt.Key_Escape) root.dismiss()
        else if (ev.key === Qt.Key_Return || ev.key === Qt.Key_Enter) root.commit()
        else if (ev.key === Qt.Key_Right || ev.key === Qt.Key_Tab) root.step(1)
        else if (ev.key === Qt.Key_Left || ev.key === Qt.Key_Backtab) root.step(-1)
        else if (ev.key === Qt.Key_Q && root.apps[root.selected]) {
          // ⌘Q pendant ⌘Tab : quitter l'app sélectionnée (toutes ses fenêtres).
          var w = root.apps[root.selected].windows
          for (var i = 0; i < w.length; i++)
            Util.execArgv(["hyprctl", "dispatch", 'hl.dsp.window.close({ window = "address:' + w[i].address + '" })'])
          var next = root.apps.slice(); next.splice(root.selected, 1); root.apps = next
          if (root.apps.length === 0) root.dismiss(); else root.selected = Math.min(root.selected, root.apps.length - 1)
        }
        else return
        ev.accepted = true
      }
    }

    MouseArea { anchors.fill: parent; onClicked: root.dismiss() }

    BorderSurface {
      id: card
      anchors.centerIn: parent
      width: Math.min(parent.width - 40, row.implicitWidth + Style.space(28))
      height: root.iconSize + Style.space(62)
      radius: Style.space(24)
      color: Commons.Color.menu.background
      borderSpec: Border.surfaceSpec("menu", "border", Commons.Color.menu.border, 1)
      scale: win.contentRevealed ? 1 : 0.94
      Behavior on scale { SpringAnimation { spring: 4.5; damping: 0.4; epsilon: 0.002 } }

      Row {
        id: row
        anchors.centerIn: parent
        anchors.verticalCenterOffset: -Style.space(8)
        spacing: Style.space(6)

        Repeater {
          model: root.apps
          delegate: Item {
            id: cell
            required property var modelData
            required property int index
            readonly property bool hot: index === root.selected
            width: root.iconSize + Style.space(16)
            height: root.iconSize + Style.space(16)

            Rectangle {
              anchors.fill: parent
              radius: Style.space(16)
              color: Commons.Color.menu.text
              opacity: cell.hot ? 0.14 : 0
              Behavior on opacity { NumberAnimation { duration: 90 } }
            }
            Image {
              anchors.centerIn: parent
              width: root.iconSize; height: width
              source: cell.modelData.icon
              sourceSize: Qt.size(144, 144)
              smooth: true
              mipmap: true
            }
            // Nombre de fenêtres de l'app.
            Rectangle {
              visible: cell.modelData.windows.length > 1
              anchors.right: parent.right; anchors.top: parent.top
              anchors.margins: Style.space(4)
              width: Math.max(height, badge.implicitWidth + Style.space(8)); height: Style.space(18); radius: height / 2
              color: Commons.Color.accent
              Text { id: badge; anchors.centerIn: parent; textFormat: Text.PlainText; text: cell.modelData.windows.length; font.family: root.uiFont; font.pixelSize: Style.space(11); font.weight: Font.Bold; color: "white" }
            }
            MouseArea {
              anchors.fill: parent
              hoverEnabled: true
              onEntered: root.selected = cell.index
              onClicked: { root.selected = cell.index; root.commit() }
            }
          }
        }
      }

      Text {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: Style.space(12)
        textFormat: Text.PlainText
        text: root.apps[root.selected] ? root.apps[root.selected].name : ""
        font.family: root.uiFont
        font.pixelSize: Style.space(13)
        font.weight: Font.Medium
        color: Commons.Color.menu.text
        opacity: 0.85
      }
    }
  }

  Connections {
    target: win
    function onContentRevealedChanged() { if (win.contentRevealed) keys.forceActiveFocus() }
  }
}
