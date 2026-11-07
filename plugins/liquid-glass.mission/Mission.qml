import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Wayland
import qs.Commons
import qs.Commons as Commons
import qs.Ui
import "T.js" as T

// ============================================================================
// Liquid Glass — Mission Control / Exposé (SUPER+↑, geste 4 doigts vers le haut).
//   • Les fenêtres du bureau courant glissent de leur position réelle vers une
//     grille (aperçus en direct via screencopy), puis y retournent à la fermeture.
//   • Bandeau des bureaux en haut : clic = aller au bureau ; glisser une fenêtre
//     sur un bureau = l'y déplacer.
//   • Tab : toutes les fenêtres / bureau courant. Flèches + Entrée, Échap.
//   • Survol : bouton ✕ pour fermer la fenêtre (ou clic milieu, ou Ctrl+W).
// ============================================================================
Item {
  id: root

  property var shell: null
  property var manifest: null
  property bool opened: false     // état demandé par le shell
  property bool arranged: false   // fenêtres en grille (sinon à leur place réelle)
  property bool allWindows: false
  // App Exposé (⌃↓) : seulement les fenêtres d'une app, tous bureaux confondus,
  // plus ses documents récents en bas. "" = Mission Control normal.
  property string appClass: ""
  property bool appRequested: false
  property var recentFiles: []

  readonly property string uiFont: "Inter"
  readonly property string iconFont: Style.font.family
  function g(cp) { return String.fromCodePoint(cp) }

  property var clients: []        // résultat de hyprctl clients -j
  property var workspaces: []
  property var monitor: ({ x: 0, y: 0, width: 1280, height: 720, activeWorkspace: { id: 1 } })
  property int selected: 0
  property string dragAddress: ""
  property int dropWorkspace: -1

  readonly property int currentWs: monitor && monitor.activeWorkspace ? monitor.activeWorkspace.id : 1

  readonly property var windows: {
    var out = []
    for (var i = 0; i < clients.length; i++) {
      var c = clients[i]
      if (!c.mapped || !c.workspace) continue
      if (appClass !== "") {
        if (String(c.class).toLowerCase() !== appClass) continue
        if (c.workspace.id < 0 && c.workspace.name !== "special:minimized") continue
        out.push(c)
        continue
      }
      if (c.hidden || c.workspace.id < 0) continue
      if (!allWindows && c.workspace.id !== currentWs) continue
      if (c.monitor !== undefined && monitor.id !== undefined && c.monitor !== monitor.id && !allWindows) continue
      out.push(c)
    }
    // Ordre stable : bureau, puis position à l'écran (lecture naturelle).
    out.sort(function(a, b) {
      if (a.workspace.id !== b.workspace.id) return a.workspace.id - b.workspace.id
      if (Math.abs(a.at[1] - b.at[1]) > 40) return a.at[1] - b.at[1]
      return a.at[0] - b.at[0]
    })
    return out
  }

  function norm(a) { return String(a || "").replace(/^0x/, "") }
  function toplevelFor(address) {
    var list = Hyprland.toplevels ? Hyprland.toplevels.values : []
    var key = norm(address)
    for (var i = 0; i < list.length; i++) if (norm(list[i].address) === key) return list[i]
    return null
  }

  // --------------------------------------------------------------- grille
  // Choisit le nombre de lignes qui maximise la taille des aperçus.
  function layout(W, H) {
    var n = windows.length
    var best = { slots: [], scale: 0 }
    if (n === 0) return best
    var gap = Style.space(28)
    for (var rows = 1; rows <= n; rows++) {
      var cols = Math.ceil(n / rows)
      var cw = (W - gap * (cols - 1)) / cols
      var ch = (H - gap * (rows - 1)) / rows
      var slots = []
      var minScale = 1e9
      for (var i = 0; i < n; i++) {
        var w = windows[i].size[0], h = windows[i].size[1]
        var s = Math.min(cw / w, ch / h, 0.9)
        minScale = Math.min(minScale, s)
        slots.push({ w: w * s, h: h * s })
      }
      if (minScale <= best.scale) continue
      // Placement : chaque ligne centrée horizontalement, cellules centrées.
      var out = []
      var totalH = rows * ch + (rows - 1) * gap
      for (var r = 0; r < rows; r++) {
        var start = r * cols
        var count = Math.min(cols, n - start)
        if (count <= 0) break
        var rowW = count * cw + (count - 1) * gap
        var x0 = (W - rowW) / 2
        for (var k = 0; k < count; k++) {
          var sl = slots[start + k]
          out.push({
            x: x0 + k * (cw + gap) + (cw - sl.w) / 2,
            y: (H - totalH) / 2 + r * (ch + gap) + (ch - sl.h) / 2,
            w: sl.w, h: sl.h
          })
        }
      }
      best = { slots: out, scale: minScale }
    }
    return best
  }

  // --------------------------------------------------------------- données
  Process {
    id: query
    command: ["sh", "-c", "printf '{\"clients\":%s,\"workspaces\":%s,\"monitors\":%s}' \"$(hyprctl -j clients)\" \"$(hyprctl -j workspaces)\" \"$(hyprctl -j monitors)\""]
    stdout: StdioCollector {
      onStreamFinished: {
        var d = null
        try { d = JSON.parse(text) } catch (e) { d = null }
        if (!d) { root.dismiss(); return }
        var mons = d.monitors || []
        var mon = mons[0]
        for (var i = 0; i < mons.length; i++) if (mons[i].focused) mon = mons[i]
        // Coordonnées logiques (écran mis à l'échelle).
        root.monitor = {
          id: mon.id, x: mon.x, y: mon.y,
          width: Math.round(mon.width / mon.scale), height: Math.round(mon.height / mon.scale),
          activeWorkspace: mon.activeWorkspace
        }
        root.clients = d.clients || []
        if (root.appRequested && root.appClass === "") {
          var cl = root.clients
          for (var a = 0; a < cl.length; a++) if (cl[a].focusHistoryID === 0) root.appClass = String(cl[a].class).toLowerCase()
          if (root.appClass === "") { root.dismiss(); return }
        }
        if (root.appClass !== "") { recentQuery.running = false; recentQuery.running = true }
        root.workspaces = (d.workspaces || []).filter(function(w) { return w.id > 0 }).sort(function(a, b) { return a.id - b.id })
        root.selected = 0
        var act = -1
        for (var j = 0; j < root.windows.length; j++) if (root.windows[j].focusHistoryID === 0) act = j
        if (act >= 0) root.selected = act
        win.shown = true
        if (win.contentRevealed) arrangeTimer.restart()
      }
    }
  }
  // Laisser une image à la position réelle avant de lancer l'animation vers la grille.
  Timer { id: arrangeTimer; interval: 40; onTriggered: root.arranged = true }
  Timer { id: hideTimer; interval: 260; onTriggered: { win.shown = false; root.clients = [] } }

  function dispatch(lua) { Util.execArgv(["hyprctl", "dispatch", lua]) }
  function focusWindow(c) {
    if (!c) return
    dismiss()
    dispatch('hl.dsp.focus({ window = "address:' + c.address + '" })')
  }
  function closeWindow(c) {
    if (!c) return
    dispatch('hl.dsp.window.close({ window = "address:' + c.address + '" })')
    var next = []
    for (var i = 0; i < clients.length; i++) if (clients[i].address !== c.address) next.push(clients[i])
    clients = next
    if (selected >= windows.length) selected = Math.max(0, windows.length - 1)
    if (windows.length === 0 && !allWindows) dismiss()
  }
  function gotoWorkspace(id) {
    dismiss()
    dispatch('hl.dsp.focus({ workspace = "' + id + '" })')
  }
  function moveToWorkspace(c, id) {
    if (!c || id === c.workspace.id) return
    dispatch('hl.dsp.window.move({ workspace = "' + id + '", follow = false, window = "address:' + c.address + '" })')
    var next = []
    for (var i = 0; i < clients.length; i++) {
      var k = clients[i]
      if (k.address === c.address) k = Object.assign({}, k, { workspace: { id: id, name: String(id) } })
      next.push(k)
    }
    clients = next
  }

  // --------------------------------------------------------------- cycle de vie
  function open(payloadJson) {
    var p = {}
    try { p = payloadJson ? JSON.parse(payloadJson) : {} } catch (e) { p = {} }
    var wantApp = !!(p && p.app)
    if (opened && win.shown) {
      if (wantApp === appRequested) return
      // Balayage vers le bas pendant Mission Control = fermer (comme macOS) ;
      // vers le haut pendant App Exposé = passer à Mission Control sur place.
      if (wantApp) { dismiss(); return }
      appRequested = wantApp
      appClass = wantApp && p.app !== "active" ? String(p.app).toLowerCase() : ""
      arranged = false
      query.running = true
      return
    }
    opened = true
    arranged = false
    allWindows = false
    appRequested = wantApp
    appClass = wantApp && p.app !== "active" ? String(p.app).toLowerCase() : ""
    recentFiles = []
    hideTimer.stop()
    query.running = true
  }
  function close() {
    if (!opened) return
    opened = false
    arranged = false
    hideTimer.restart()
  }
  function dismiss() {
    close()
    if (shell && typeof shell.hide === "function") shell.hide((manifest && manifest.id) || "liquid-glass.mission")
  }
  function toggle() { if (opened) dismiss(); else open("") }

  readonly property var appEntry: appClass !== "" ? DesktopEntries.heuristicLookup(appClass) : null
  readonly property string appName: appEntry && appEntry.name ? appEntry.name : appClass

  // Documents récents de l'app (recently-used.xbel), pour la rangée du bas.
  Process {
    id: recentQuery
    command: ["python3", "-I", "-c",
      "import sys,re,html,urllib.parse,os\n" +
      "keys=[k.lower() for k in sys.argv[1:] if k]\n" +
      "p=os.path.expanduser('~/.local/share/recently-used.xbel')\n" +
      "try: t=open(p,encoding='utf-8').read()\n" +
      "except Exception: sys.exit(0)\n" +
      "out=[]\n" +
      "for m in re.finditer(r'<bookmark href=\"([^\"]+)\"[^>]*modified=\"([^\"]+)\"(.*?)</bookmark>',t,re.S):\n" +
      "  apps=str(re.findall(r'application name=\"([^\"]+)\"[^>]*exec=\"([^\"]*)\"',m.group(3))).lower()\n" +
      "  if not any(k in apps for k in keys): continue\n" +
      "  u=html.unescape(m.group(1))\n" +
      "  if not u.startswith('file://'): continue\n" +
      "  f=urllib.parse.unquote(u[7:])\n" +
      "  if os.path.exists(f): out.append((m.group(2),f))\n" +
      "out.sort(reverse=True)\n" +
      "print('\\n'.join(f for _,f in out[:8]))\n",
      root.appClass, root.appName, (root.appEntry && root.appEntry.id) ? String(root.appEntry.id).replace(/\.desktop$/, "") : ""]
    stdout: StdioCollector {
      onStreamFinished: root.recentFiles = text.split("\n").filter(function(l) { return l.length > 0 })
    }
  }

  function move(dx, dy) {
    var n = windows.length
    if (n === 0) return
    var cur = slotsFor.slots[selected]
    if (!cur) { selected = 0; return }
    if (dy === 0) { selected = (selected + dx + n) % n; return }
    // Haut/bas : la fenêtre la plus proche horizontalement dans la ligne visée.
    var best = -1, bestD = 1e9
    for (var i = 0; i < n; i++) {
      var s = slotsFor.slots[i]
      var vy = (s.y + s.h / 2) - (cur.y + cur.h / 2)
      if ((dy > 0 && vy <= 10) || (dy < 0 && vy >= -10)) continue
      var d = Math.abs(vy) * 2 + Math.abs((s.x + s.w / 2) - (cur.x + cur.w / 2))
      if (d < bestD) { bestD = d; best = i }
    }
    if (best >= 0) selected = best
  }

  readonly property real stripH: Style.space(92)
  readonly property real gridTop: appClass !== "" ? Style.space(84) : stripH + Style.space(40)
  readonly property real gridBottom: appClass !== "" ? (recentFiles.length > 0 ? Style.space(150) : Style.space(40)) : Style.space(110)
  readonly property var slotsFor: layout(win.width - Style.space(120), win.height - gridTop - gridBottom)

  // --------------------------------------------------------------- fenêtre
  OverlayWindow {
    id: win
    WlrLayershell.namespace: "liquid-glass-mission"

    Item {
      id: stage
      anchors.fill: parent
      focus: true

      Keys.onPressed: function(ev) {
        if (ev.key === Qt.Key_Escape) root.dismiss()
        else if (ev.key === Qt.Key_Tab) { root.allWindows = !root.allWindows; root.selected = 0 }
        else if (ev.key === Qt.Key_Left) root.move(-1, 0)
        else if (ev.key === Qt.Key_Right) root.move(1, 0)
        else if (ev.key === Qt.Key_Up) root.move(0, -1)
        else if (ev.key === Qt.Key_Down) root.move(0, 1)
        else if (ev.key === Qt.Key_Return || ev.key === Qt.Key_Enter || ev.key === Qt.Key_Space) root.focusWindow(root.windows[root.selected])
        else if ((ev.key === Qt.Key_W && (ev.modifiers & Qt.ControlModifier)) || ev.key === Qt.Key_Delete) root.closeWindow(root.windows[root.selected])
        else if (ev.key >= Qt.Key_1 && ev.key <= Qt.Key_9) root.gotoWorkspace(ev.key - Qt.Key_0)
        else return
        ev.accepted = true
      }

      // Voile : assombrit et (règle de calque) floute le bureau.
      Rectangle {
        anchors.fill: parent
        color: "#000000"
        opacity: root.arranged ? 0.32 : 0
        Behavior on opacity { NumberAnimation { duration: 240; easing.type: Easing.OutCubic } }
      }
      MouseArea { anchors.fill: parent; onClicked: root.dismiss() }

      // ---- Bandeau des bureaux
      Row {
        id: strip
        anchors.horizontalCenter: parent.horizontalCenter
        y: root.arranged && root.appClass === "" ? Style.space(22) : -root.stripH
        Behavior on y { SpringAnimation { spring: 3.2; damping: 0.36; epsilon: 0.25 } }
        spacing: Style.space(12)

        Repeater {
          model: root.workspaces
          delegate: Rectangle {
            id: wsPill
            required property var modelData
            readonly property bool current: modelData.id === root.currentWs
            readonly property bool dropHot: root.dragAddress !== "" && root.dropWorkspace === modelData.id
            width: Style.space(132)
            height: Style.space(64)
            radius: Style.space(12)
            color: dropHot ? Qt.rgba(1, 1, 1, 0.42) : Qt.rgba(1, 1, 1, current ? 0.26 : (wsMouse.containsMouse ? 0.18 : 0.10))
            border.width: current ? 2 : 1
            border.color: current ? Commons.Color.accent : Qt.rgba(1, 1, 1, 0.22)
            Behavior on color { ColorAnimation { duration: 120 } }
            scale: dropHot ? 1.06 : 1
            Behavior on scale { NumberAnimation { duration: 120 } }

            Column {
              anchors.centerIn: parent
              spacing: 2
              Text {
                anchors.horizontalCenter: parent.horizontalCenter
                textFormat: Text.PlainText
                text: T.t("Bureau ") + wsPill.modelData.id
                font.family: root.uiFont; font.pixelSize: Style.space(13); font.weight: Font.DemiBold
                color: "white"
              }
              Text {
                anchors.horizontalCenter: parent.horizontalCenter
                textFormat: Text.PlainText
                text: wsPill.modelData.windows + (wsPill.modelData.windows > 1 ? T.t(" fenêtres") : T.t(" fenêtre"))
                font.family: root.uiFont; font.pixelSize: Style.space(11)
                color: "white"; opacity: 0.65
              }
            }
            MouseArea { id: wsMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.gotoWorkspace(wsPill.modelData.id) }
          }
        }
      }

      Text {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: Style.space(22)
        textFormat: Text.PlainText
        visible: root.appClass === ""
        text: (root.allWindows ? T.t("Toutes les fenêtres") : T.t("Bureau ") + root.currentWs) + T.t("   ·   Tab : basculer   ·   ↵ : ouvrir   ·   ⌃W : fermer   ·   glisser sur un bureau : déplacer")
        font.family: root.uiFont; font.pixelSize: Style.space(12)
        color: "white"
        opacity: root.arranged ? 0.6 : 0
        Behavior on opacity { NumberAnimation { duration: 200 } }
      }

      Text {
        anchors.centerIn: parent
        visible: root.windows.length === 0 && root.arranged
        textFormat: Text.PlainText
        text: root.appClass !== "" ? T.t("Aucune fenêtre ouverte pour ") + root.appName : T.t("Aucune fenêtre sur ce bureau")
        font.family: root.uiFont; font.pixelSize: Style.space(20); font.weight: Font.Medium
        color: "white"; opacity: 0.7
      }

      // ---- App Exposé : nom de l'app en haut, documents récents en bas
      Rectangle {
        id: appTitle
        visible: root.appClass !== ""
        anchors.horizontalCenter: parent.horizontalCenter
        y: root.arranged ? Style.space(28) : -height
        Behavior on y { SpringAnimation { spring: 3.2; damping: 0.4; epsilon: 0.25 } }
        width: appTitleRow.implicitWidth + Style.space(28)
        height: Style.space(36)
        radius: height / 2
        color: Qt.rgba(0, 0, 0, 0.32)
        border.width: 1
        border.color: Qt.rgba(1, 1, 1, 0.18)
        Row {
          id: appTitleRow
          anchors.centerIn: parent
          spacing: Style.space(8)
          Image {
            anchors.verticalCenter: parent.verticalCenter
            width: Style.space(22); height: width
            sourceSize: Qt.size(64, 64)
            source: Quickshell.iconPath(root.appEntry && root.appEntry.icon ? root.appEntry.icon : "application-x-executable", true)
          }
          Text {
            anchors.verticalCenter: parent.verticalCenter
            textFormat: Text.PlainText
            text: root.appName + "  ·  " + root.windows.length + (root.windows.length > 1 ? T.t(" fenêtres") : T.t(" fenêtre"))
            font.family: root.uiFont; font.pixelSize: 13; font.weight: Font.DemiBold
            color: "white"
          }
        }
      }

      Row {
        id: recentRow
        visible: root.appClass !== "" && root.recentFiles.length > 0
        anchors.horizontalCenter: parent.horizontalCenter
        y: root.arranged ? win.height - height - Style.space(24) : win.height + Style.space(10)
        Behavior on y { SpringAnimation { spring: 3.0; damping: 0.42; epsilon: 0.25 } }
        spacing: Style.space(14)
        Repeater {
          model: root.recentFiles
          delegate: Rectangle {
            id: doc
            required property string modelData
            readonly property string base: modelData.substring(modelData.lastIndexOf("/") + 1)
            readonly property bool isImage: /\.(png|jpe?g|webp|gif|bmp|svg)$/i.test(base)
            width: Style.space(96); height: Style.space(104)
            radius: Style.space(12)
            color: docMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.22) : Qt.rgba(1, 1, 1, 0.10)
            border.width: 1
            border.color: Qt.rgba(1, 1, 1, 0.16)
            scale: docMouse.pressed ? 0.94 : (docMouse.containsMouse ? 1.05 : 1)
            Behavior on scale { SpringAnimation { spring: 4; damping: 0.4 } }
            Image {
              anchors.horizontalCenter: parent.horizontalCenter
              y: Style.space(10)
              width: Style.space(56); height: width
              fillMode: Image.PreserveAspectFit
              asynchronous: true
              sourceSize: Qt.size(128, 128)
              source: doc.isImage ? "file://" + doc.modelData : Quickshell.iconPath("text-x-generic", true)
            }
            Text {
              anchors.horizontalCenter: parent.horizontalCenter
              anchors.bottom: parent.bottom
              anchors.bottomMargin: Style.space(8)
              width: parent.width - Style.space(10)
              horizontalAlignment: Text.AlignHCenter
              textFormat: Text.PlainText
              text: doc.base
              elide: Text.ElideMiddle
              font.family: root.uiFont; font.pixelSize: 11
              color: "white"
            }
            MouseArea {
              id: docMouse
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: { root.dismiss(); Quickshell.execDetached(["xdg-open", doc.modelData]) }
            }
          }
        }
      }

      // ---- Aperçus des fenêtres
      Item {
        id: grid
        x: Style.space(60)
        y: root.gridTop
        width: win.width - Style.space(120)
        height: win.height - root.gridTop - root.gridBottom

        Repeater {
          model: root.windows
          delegate: Item {
            id: tile
            required property var modelData
            required property int index
            readonly property var slot: root.slotsFor.slots[index] || { x: 0, y: 0, w: 10, h: 10 }
            readonly property bool hot: index === root.selected
            readonly property bool dragging: tileDrag.drag.active
            // Position réelle de la fenêtre, exprimée dans le repère de la grille.
            readonly property real realX: modelData.at[0] - root.monitor.x - grid.x
            readonly property real realY: modelData.at[1] - root.monitor.y - grid.y
            readonly property bool sameWs: modelData.workspace.id === root.currentWs

            x: root.arranged ? slot.x : realX
            y: root.arranged ? slot.y : realY
            width: root.arranged ? slot.w : modelData.size[0]
            height: root.arranged ? slot.h : modelData.size[1]
            opacity: root.arranged || (sameWs && modelData.workspace.id > 0) ? 1 : 0
            z: dragging ? 10 : (hot ? 2 : 1)
            Behavior on x { enabled: !tile.dragging; SpringAnimation { spring: 3.4; damping: 0.38; epsilon: 0.3 } }
            Behavior on y { enabled: !tile.dragging; SpringAnimation { spring: 3.4; damping: 0.38; epsilon: 0.3 } }
            Behavior on width { SpringAnimation { spring: 3.4; damping: 0.38; epsilon: 0.3 } }
            Behavior on height { SpringAnimation { spring: 3.4; damping: 0.38; epsilon: 0.3 } }
            Behavior on opacity { NumberAnimation { duration: 180 } }

            Rectangle {
              id: frame
              anchors.fill: parent
              anchors.margins: -4
              radius: Style.space(14)
              color: "transparent"
              border.width: 3
              border.color: Commons.Color.accent
              opacity: tile.hot && root.arranged ? 1 : 0
              Behavior on opacity { NumberAnimation { duration: 120 } }
            }

            ScreencopyView {
              id: shot
              anchors.fill: parent
              captureSource: root.opened ? (root.toplevelFor(tile.modelData.address) ? root.toplevelFor(tile.modelData.address).wayland : null) : null
              live: true
              // Coins arrondis : l'aperçu est masqué par un rectangle arrondi.
              layer.enabled: true
              layer.smooth: true
              layer.effect: MultiEffect {
                maskEnabled: true
                maskSource: shotMask
                maskThresholdMin: 0.5
                maskSpreadAtMin: 1.0
              }
            }
            Rectangle {
              id: shotMask
              width: shot.width; height: shot.height
              radius: Style.space(12)
              visible: false
              layer.enabled: true
              layer.smooth: true
            }
            // Repli si l'aperçu n'est pas disponible : icône de l'app.
            Rectangle {
              anchors.fill: parent
              visible: !shot.hasContent
              radius: Style.space(12)
              color: Qt.rgba(1, 1, 1, 0.14)
              border.width: 1
              border.color: Qt.rgba(1, 1, 1, 0.2)
              Image {
                anchors.centerIn: parent
                width: Math.min(parent.width, parent.height) * 0.35
                height: width
                source: {
                  var e = DesktopEntries.heuristicLookup(tile.modelData.class)
                  return Quickshell.iconPath(e && e.icon ? e.icon : "application-x-executable", true)
                }
                sourceSize: Qt.size(128, 128)
              }
            }

            // Libellé : app + titre, sous l'aperçu au survol / à la sélection.
            Rectangle {
              anchors.horizontalCenter: parent.horizontalCenter
              anchors.top: parent.bottom
              anchors.topMargin: Style.space(10)
              width: Math.min(label.implicitWidth + Style.space(22), Math.max(parent.width, Style.space(220)))
              height: Style.space(26)
              radius: height / 2
              color: Qt.rgba(0, 0, 0, 0.45)
              opacity: (tile.hot || tileDrag.containsMouse) && root.arranged && !tile.dragging ? 1 : 0
              Behavior on opacity { NumberAnimation { duration: 120 } }
              Text {
                id: label
                anchors.centerIn: parent
                width: Math.min(implicitWidth, parent.width - Style.space(22))
                textFormat: Text.PlainText
                text: {
                  var e = DesktopEntries.heuristicLookup(tile.modelData.class)
                  var app = e && e.name ? e.name : tile.modelData.class
                  return tile.modelData.title && tile.modelData.title !== app ? app + " — " + tile.modelData.title : app
                }
                elide: Text.ElideRight
                font.family: root.uiFont; font.pixelSize: Style.space(12); font.weight: Font.Medium
                color: "white"
              }
            }

            MouseArea {
              id: tileDrag
              anchors.fill: parent
              hoverEnabled: true
              acceptedButtons: Qt.LeftButton | Qt.MiddleButton
              cursorShape: Qt.PointingHandCursor
              drag.target: root.arranged ? tile : null
              drag.threshold: 8
              onEntered: root.selected = tile.index
              onClicked: function(m) {
                if (m.button === Qt.MiddleButton) root.closeWindow(tile.modelData)
                else root.focusWindow(tile.modelData)
              }
              onPositionChanged: function(m) {
                if (!drag.active) return
                root.dragAddress = tile.modelData.address
                var p = mapToItem(strip, m.x, m.y)
                var hit = -1
                if (p.y >= 0 && p.y <= strip.height) {
                  var w = Style.space(132) + strip.spacing
                  var i = Math.floor(p.x / w)
                  if (i >= 0 && i < root.workspaces.length && p.x - i * w <= Style.space(132)) hit = root.workspaces[i].id
                }
                root.dropWorkspace = hit
              }
              onReleased: {
                if (root.dragAddress !== "" && root.dropWorkspace > 0) root.moveToWorkspace(tile.modelData, root.dropWorkspace)
                root.dragAddress = ""
                root.dropWorkspace = -1
                // Retour à l'emplacement de grille (le binding x/y a été cassé par le glisser).
                tile.x = Qt.binding(function() { return root.arranged ? tile.slot.x : tile.realX })
                tile.y = Qt.binding(function() { return root.arranged ? tile.slot.y : tile.realY })
              }
            }

            // Bouton fermer façon macOS.
            Rectangle {
              x: -Style.space(9); y: -Style.space(9)
              width: Style.space(22); height: width; radius: width / 2
              color: closeMouse.containsMouse ? "#ff5f57" : Qt.rgba(0.15, 0.15, 0.15, 0.85)
              border.width: 1
              border.color: Qt.rgba(1, 1, 1, 0.3)
              visible: root.arranged
              opacity: (tileDrag.containsMouse || closeMouse.containsMouse) && !tile.dragging ? 1 : 0
              Behavior on opacity { NumberAnimation { duration: 100 } }
              Text {
                anchors.centerIn: parent
                textFormat: Text.PlainText
                text: "✕"
                font.pixelSize: Style.space(11); font.weight: Font.Bold
                color: "white"
              }
              MouseArea { id: closeMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.closeWindow(tile.modelData) }
            }
          }
        }
      }
    }
  }

  Connections {
    target: win
    function onContentRevealedChanged() {
      if (!win.contentRevealed) return
      stage.forceActiveFocus()
      if (root.opened) arrangeTimer.restart()
    }
  }
}
