import QtQuick
import "Mac.js" as Mac
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.Commons
import qs.Commons as Commons
import qs.Ui

// Liquid Glass — « Forcer à quitter les applications » (⌥⌘Échap, menu Pomme).
// Liste des apps ouvertes (fenêtres Hyprland regroupées par classe), une ligne
// sélectionnée, bouton « Forcer à quitter » avec confirmation, comme sur macOS.
// Les PID viennent de `hyprctl clients -j` et sont vérifiés (entiers) avant kill.
Item {
  id: root

  property var shell: null
  property var manifest: null
  property bool opened: false
  property var apps: []
  property int selected: 0
  property bool confirming: false

  readonly property string uiFont: "Inter"
  readonly property bool dark: Commons.Color.menu.background.hslLightness < 0.5
  readonly property color fg: Commons.Color.menu.text
  readonly property color accent: Commons.Color.accent

  function open(payloadJson) { opened = true; confirming = false; selected = 0; listProc.running = true }
  function close() { opened = false }
  function dismiss() {
    opened = false
    if (shell && typeof shell.hide === "function") shell.hide((manifest && manifest.id) || "liquid-glass.forcequit")
  }

  function prettyClass(cls) {
    var last = String(cls || "").split(".").pop().replace(/[-_]+/g, " ")
    return last.charAt(0).toUpperCase() + last.slice(1)
  }

  function build(clients) {
    var by = ({}), order = []
    for (var i = 0; i < clients.length && i < 200; i++) {
      var c = clients[i]
      if (!c.mapped || !c.pid || c.pid <= 1) continue
      var key = String(c.class || c.initialClass || c.title || "").slice(0, 120)
      if (key === "") continue
      if (!by[key]) {
        var e = DesktopEntries.heuristicLookup(key)
        by[key] = {
          cls: key,
          name: e && e.name ? e.name : prettyClass(key),
          icon: Quickshell.iconPath(e && e.icon ? e.icon : key, true) || Quickshell.iconPath("application-x-executable", true),
          pids: []
        }
        order.push(key)
      }
      if (by[key].pids.indexOf(c.pid) < 0) by[key].pids.push(c.pid)
    }
    var list = order.map(function(k) { return by[k] })
    list.sort(function(a, b) { return a.name.localeCompare(b.name, "fr") })
    return list
  }

  function forceQuit() {
    var app = apps[selected]
    if (!app) return
    for (var i = 0; i < app.pids.length; i++) {
      var pid = Number(app.pids[i])
      if (Number.isInteger(pid) && pid > 1) Util.execArgv(["kill", "-9", String(pid)])
    }
    confirming = false
    refresh.restart()
  }

  Timer { id: refresh; interval: 400; onTriggered: listProc.running = true }

  ShellIpc {
    target: "liquid-glass.forcequit"
    function toggle(): void { if (root.opened) root.dismiss(); else if (root.shell) root.shell.summon((root.manifest && root.manifest.id) || "liquid-glass.forcequit", "") }
  }

  Process {
    id: listProc
    command: ["hyprctl", "clients", "-j"]
    stdout: StdioCollector {
      onStreamFinished: {
        try { root.apps = root.build(JSON.parse(text)) } catch (e) { root.apps = [] }
        if (root.selected >= root.apps.length) root.selected = Math.max(0, root.apps.length - 1)
      }
    }
  }

  OverlayWindow {
    id: win
    shown: root.opened
    WlrLayershell.namespace: "liquid-glass-forcequit"

    Item {
      id: keys
      anchors.fill: parent
      focus: true
      Keys.onPressed: function(ev) {
        if (ev.key === Qt.Key_Escape) { if (root.confirming) root.confirming = false; else root.dismiss() }
        else if (ev.key === Qt.Key_Down) root.selected = Math.min(root.apps.length - 1, root.selected + 1)
        else if (ev.key === Qt.Key_Up) root.selected = Math.max(0, root.selected - 1)
        else if (ev.key === Qt.Key_Return || ev.key === Qt.Key_Enter) { if (root.confirming) root.forceQuit(); else if (root.apps.length) root.confirming = true }
        else return
        ev.accepted = true
      }
    }
    MouseArea { anchors.fill: parent; onClicked: root.dismiss() }

    Rectangle {
      id: card
      anchors.centerIn: parent
      width: Style.space(360)
      height: col.implicitHeight + Style.space(28)
      radius: Style.space(Mac.window.radius + 4)
      color: Qt.rgba(Commons.Color.menu.background.r, Commons.Color.menu.background.g, Commons.Color.menu.background.b, root.dark ? 0.8 : 0.76)
      border.width: 1
      border.color: Qt.rgba(1, 1, 1, root.dark ? 0.14 : 0.6)
      scale: win.contentRevealed ? 1 : 0.92
      opacity: win.contentRevealed ? 1 : 0
      Behavior on scale { SpringAnimation { spring: Mac.motion.springLG.spring; damping: Mac.motion.springLG.damping; epsilon: 0.002 } }
      Behavior on opacity { NumberAnimation { duration: Style.duration(160) } }
      MouseArea { anchors.fill: parent }

      Column {
        id: col
        x: Style.space(16); y: Style.space(14)
        width: parent.width - Style.space(32)
        spacing: Style.space(10)

        Row {
          spacing: Style.space(Mac.window.lightGap)
          Repeater {
            model: 3
            delegate: Rectangle {
              required property int index
              width: Style.space(Mac.window.light); height: width; radius: width / 2
              color: index === 0 ? Mac.window.red : (root.dark ? Mac.window.inactiveDark : Mac.window.inactive)
              border.width: 1; border.color: Qt.rgba(0, 0, 0, 0.12)
              MouseArea { anchors.fill: parent; enabled: index === 0; cursorShape: Qt.PointingHandCursor; onClicked: root.dismiss() }
            }
          }
        }

        Text {
          width: parent.width
          textFormat: Text.PlainText
          text: "Forcer à quitter les applications"
          font.family: root.uiFont; font.pixelSize: Style.space(Mac.font.headline); font.weight: Font.Bold
          color: root.fg
        }
        Text {
          width: parent.width
          wrapMode: Text.WordWrap
          textFormat: Text.PlainText
          text: "Si une application ne répond plus, sélectionnez-la dans la liste et cliquez sur Forcer à quitter."
          font.family: root.uiFont; font.pixelSize: Style.space(Mac.font.subheadline)
          color: root.fg; opacity: Mac.label.secondary + 0.1
        }

        // Liste blanche façon NSTableView.
        Rectangle {
          width: parent.width
          height: Style.space(24) * Math.max(6, Math.min(9, root.apps.length)) + Style.space(8)
          radius: Style.space(8)
          color: root.dark ? Qt.rgba(0, 0, 0, 0.25) : Qt.rgba(1, 1, 1, 0.7)
          border.width: 1; border.color: Qt.rgba(root.fg.r, root.fg.g, root.fg.b, 0.12)
          clip: true

          ListView {
            id: list
            anchors.fill: parent; anchors.margins: Style.space(4)
            model: root.apps
            currentIndex: root.selected
            boundsBehavior: Flickable.DragOverBounds
            delegate: Rectangle {
              required property var modelData
              required property int index
              readonly property bool sel: index === root.selected
              width: list.width; height: Style.space(24)
              radius: Style.space(Mac.menu.selRadius)
              color: sel ? root.accent : "transparent"
              Image {
                id: ico
                x: Style.space(6); anchors.verticalCenter: parent.verticalCenter
                width: Style.space(18); height: width
                source: modelData.icon || ""
                sourceSize: Qt.size(36, 36)
              }
              Text {
                anchors.left: ico.right; anchors.leftMargin: Style.space(7)
                anchors.right: parent.right; anchors.rightMargin: Style.space(8)
                anchors.verticalCenter: parent.verticalCenter
                textFormat: Text.PlainText
                elide: Text.ElideRight
                text: modelData.name
                font.family: root.uiFont; font.pixelSize: Style.space(Mac.font.body)
                color: sel ? "white" : root.fg
              }
              MouseArea {
                anchors.fill: parent
                onClicked: { root.selected = index; root.confirming = false }
                onDoubleClicked: { root.selected = index; root.confirming = true }
              }
            }
          }
          Text {
            visible: root.apps.length === 0
            anchors.centerIn: parent
            textFormat: Text.PlainText; text: "Aucune application ouverte"
            font.family: root.uiFont; font.pixelSize: Style.space(Mac.font.body)
            color: root.fg; opacity: Mac.label.tertiary
          }
        }

        Text {
          width: parent.width
          textFormat: Text.PlainText
          text: "Vous pouvez ouvrir cette fenêtre en appuyant sur Option + Commande + Échap."
          wrapMode: Text.WordWrap
          font.family: root.uiFont; font.pixelSize: Style.space(Mac.font.footnote)
          color: root.fg; opacity: Mac.label.secondary
        }

        // Confirmation (comme la feuille de macOS) ou bouton principal.
        Item {
          width: parent.width
          height: root.confirming ? confirmCol.implicitHeight : Style.space(Mac.control.large)

          Column {
            id: confirmCol
            visible: root.confirming
            width: parent.width
            spacing: Style.space(8)
            Text {
              width: parent.width
              wrapMode: Text.WordWrap
              textFormat: Text.PlainText
              text: root.apps[root.selected] ? "Voulez-vous forcer « " + root.apps[root.selected].name + " » à quitter ? Les modifications non enregistrées seront perdues." : ""
              font.family: root.uiFont; font.pixelSize: Style.space(Mac.font.subheadline); font.weight: Font.DemiBold
              color: root.fg
            }
            Row {
              anchors.right: parent.right
              spacing: Style.space(8)
              PushButton { label: "Annuler"; onClicked: root.confirming = false }
              PushButton { label: "Forcer à quitter"; primary: true; destructive: true; onClicked: root.forceQuit() }
            }
          }

          PushButton {
            visible: !root.confirming
            anchors.right: parent.right
            label: "Forcer à quitter"
            primary: true
            enabled: root.apps.length > 0
            onClicked: root.confirming = true
          }
        }
      }
    }
  }

  // Bouton macOS : capsule, accent (principal) ou gris.
  component PushButton: Rectangle {
    id: pb
    property string label: ""
    property bool primary: false
    property bool destructive: false
    signal clicked()
    width: Math.max(Style.space(Mac.control.minWidth), pbText.implicitWidth + Style.space(Mac.control.padH * 2))
    height: Style.space(Mac.control.regular + 2)
    radius: height / 2
    opacity: enabled ? 1 : 0.45
    color: primary ? (destructive ? "#ff3b30" : root.accent) : Qt.rgba(root.fg.r, root.fg.g, root.fg.b, root.dark ? 0.16 : 0.09)
    scale: pbMouse.pressed ? 0.94 : 1
    Behavior on scale { SpringAnimation { spring: 5; damping: 0.3 } }
    Text {
      id: pbText
      anchors.centerIn: parent
      textFormat: Text.PlainText; text: pb.label
      font.family: root.uiFont; font.pixelSize: Style.space(Mac.font.body); font.weight: pb.primary ? Font.DemiBold : Font.Normal
      color: pb.primary ? "white" : root.fg
    }
    MouseArea { id: pbMouse; anchors.fill: parent; enabled: pb.enabled; cursorShape: Qt.PointingHandCursor; onClicked: pb.clicked() }
  }

  Connections {
    target: win
    function onContentRevealedChanged() { if (win.contentRevealed) keys.forceActiveFocus() }
  }
}
