import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import "T.js" as T

// Style Infini : le bureau est une toile sans bord. On la fait glisser à la souris
// (clic gauche sur le fond) ou à la molette (Maj pour l'horizontale) : les fenêtres
// flottantes du bureau suivent, comme posées dessus. Double-clic : retour au centre.
//   sur la toile : horloge empilée (heures sur minutes), cadre du visualiseur
//   à l'écran    : étoiles filantes, visualiseur rose sur toute la largeur du bas
// La barre du bas (InfiniBar) montre la position et ramène au centre.
Scope {
  id: root
  property var service: null
  property var screen: null
  readonly property var s: service

  readonly property string tone: String(s ? s.opt("infini_tone", "sakura") : "sakura")
  readonly property var tones: ({ sakura: "#e8a3b4", lilas: "#c9b3f0", menthe: "#9fdcc4", peche: "#f5b896" })
  readonly property color acc: s && s.colorMode === "perso" && s.accentHex !== "" ? s.accentHex : (tones[tone] || tones.sakura)
  readonly property real sw: screen ? screen.width : 1280
  readonly property real sh: screen ? screen.height : 720
  readonly property real k: Math.min(sw / 1280, sh / 720)
  readonly property bool live: !!s && root.screen !== null

  // ------------------------------------------------------------ la toile
  // Position de la vue sur la toile (px logiques) ; les fenêtres sont déplacées d'autant.
  property real px: 0
  property real py: 0
  property real sentX: 0          // ce qui a déjà été envoyé à Hyprland
  property real sentY: 0
  property var addrs: []          // fenêtres flottantes du bureau actif
  property bool listed: false     // addrs est à jour
  property bool dragging: false
  // Zoom de la toile (⌘ + molette / deux doigts, ⌘⌃Z, ⌘⌃⇧Z, ⌘⌃⌥Z) : seul le bureau
  // (horloge, cadre, visualiseur…) se rapproche ou s'éloigne autour du pointeur ;
  // les fenêtres ne bougent pas et gardent leur taille.
  property real zoom: 1
  readonly property real wheelStep: Number(s ? s.opt("infini_zoom_speed", 1.08) : 1.08)
  readonly property real zoomMin: 0.3
  readonly property real zoomMax: 2.5
  // Position affichée de la toile (glisser + zoom) ; px/py = glisser seul (fenêtres).
  property real vx: 0
  property real vy: 0
  readonly property bool atHome: Math.abs(px) < 1 && Math.abs(py) < 1 && Math.abs(vx) < 1 && Math.abs(vy) < 1 && Math.abs(zoom - 1) < 0.001

  function pan(dx, dy) {
    if (dx === 0 && dy === 0) return
    px += dx; py += dy
    vx += dx; vy += dy
    flushT.start()
  }
  // Zoom de facteur f autour du point (cx, cy) de l'écran (coordonnées locales) :
  // ne change que l'affichage de la toile, jamais les fenêtres.
  function zoomAt(f, cx, cy) {
    var z = Math.max(zoomMin, Math.min(zoomMax, zoom * f))
    if (Math.abs(z - zoom) < 0.0001) return
    var g = z / zoom
    vx = cx - (cx - vx) * g
    vy = cy - (cy - vy) * g
    zoom = z
  }
  // Zoom au clavier ou à ⌘ + molette : autour du pointeur (cursorpos), sinon du centre.
  property real zoomPending: 1
  function zoomStep(dir) {
    if (dir === "reset") { zoomAt(1 / zoom, sw / 2, sh / 2); return }
    var f = dir === "in" ? 1.25 : dir === "out" ? 0.8 : dir === "wheel-in" ? wheelStep : dir === "wheel-out" ? 1 / wheelStep : 1
    zoomPending *= f
    if (!cursorP.running) cursorP.running = true
  }
  Process {
    id: cursorP
    command: ["hyprctl", "cursorpos"]
    stdout: StdioCollector {
      onStreamFinished: {
        var p = String(text).split(","), x = Number(p[0]), y = Number(p[1])
        var ox = root.screen ? root.screen.x : 0, oy = root.screen ? root.screen.y : 0
        if (isNaN(x) || isNaN(y) || x < ox || y < oy || x > ox + root.sw || y > oy + root.sh) { x = ox + root.sw / 2; y = oy + root.sh / 2 }
        var f = root.zoomPending
        root.zoomPending = 1
        root.zoomAt(f, x - ox, y - oy)
      }
    }
  }
  function home() { zoom = 1; vx = 0; vy = 0; px = 0; py = 0; flushT.start() }
  // Bureau affiché sur l'écran de la toile (pas forcément l'écran actif).
  function wsOf(json) {
    try {
      var ms = JSON.parse(json), name = root.screen ? root.screen.name : ""
      for (var i = 0; i < ms.length; i++) if (ms[i].name === name || (name === "" && ms[i].focused)) return ms[i].activeWorkspace.id
    } catch (e) {}
    return -1
  }
  // Test : LG_ZOOM=0.6 zoome la toile 2,5 s après le démarrage (bureau de test seulement).
  Timer {
    running: !!root.s && root.s.testing === true && String(Quickshell.env("LG_ZOOM") || "") !== ""
    interval: 2500
    onTriggered: root.zoomAt(Number(Quickshell.env("LG_ZOOM")), root.sw / 2, root.sh / 2)
  }
  Component.onCompleted: if (service) service.infiniDesk = root
  Component.onDestruction: if (service && service.infiniDesk === root) service.infiniDesk = null

  // Fenêtres du bureau actif. Les fenêtres en mosaïque passent en flottant : sur une
  // toile infinie, tout bouge ensemble.
  Process {
    id: listP
    command: ["sh", "-c", "hyprctl -j monitors; echo '@@'; hyprctl -j clients"]
    stdout: StdioCollector {
      onStreamFinished: {
        var p = text.split("@@"), ws = -1, out = [], tiled = []
        ws = root.wsOf(p[0])
        var cl = []
        try { cl = JSON.parse(p[1]) } catch (e) {}
        for (var i = 0; i < cl.length; i++) {
          var c = cl[i]
          if (!c.workspace || c.workspace.id !== ws || c.workspace.id < 0 || c.pinned || (c.fullscreen || 0) > 0) continue
          out.push(c.address)
          if (!c.floating) tiled.push(c.address)
        }
        if (tiled.length && root.s && root.s.opt("infini_float", true) !== false) {
          var b = tiled.map(function(a) { return "dispatch hl.dsp.window.float({ action = \"on\", window = \"address:" + a + "\" })" })
          Quickshell.execDetached(["hyprctl", "--batch", b.join(" ; ")])
        }
        root.addrs = out
        root.listed = true
        flushT.start()
      }
    }
  }
  // Au plus ~30 envois par seconde, un seul à la fois.
  Timer { id: flushT; interval: 33; onTriggered: root.flush() }
  Process { id: moveP; onExited: if (Math.round(root.px - root.sentX) !== 0 || Math.round(root.py - root.sentY) !== 0) flushT.start() }
  function flush() {
    if (moveP.running || listP.running) { flushT.start(); return }
    if (!listed) { listP.running = true; return }
    var dx = Math.round(px - sentX), dy = Math.round(py - sentY)
    if (addrs.length === 0) { sentX = px; sentY = py; return }
    if (dx === 0 && dy === 0) return
    var b = addrs.map(function(a) { return "dispatch hl.dsp.window.move({ x = " + dx + ", y = " + dy + ", relative = true, window = \"address:" + a + "\" })" })
    sentX += dx; sentY += dy
    moveP.command = ["hyprctl", "--batch", b.join(" ; ")]
    moveP.running = true
  }
  // Un autre bureau, une nouvelle fenêtre : la liste est refaite au prochain glisser.
  Connections {
    target: Hyprland
    function onRawEvent(event) {
      var n = event.name
      if (n === "workspacev2" || n === "workspace" || n === "closewindow" || n === "movewindowv2" || n === "changefloatingmode") root.listed = false
      else if (n === "openwindow") {
        root.listed = false
        // Les nouvelles fenêtres s'ouvrent flottantes, au centre de la vue.
        if (root.s && root.s.opt("infini_float", true) !== false && !(root.s.testing)) {
          var a = "0x" + String(event.data).split(",")[0]
          Quickshell.execDetached(["hyprctl", "dispatch", "hl.dsp.window.float({ action = \"on\", window = \"address:" + a + "\" })"])
        }
      }
    }
  }

  // ------------------------------------------------------------ bureau
  PanelWindow {
    id: desk
    screen: root.screen
    color: "transparent"
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Bottom
    WlrLayershell.namespace: "liquid-glass-infini-desktop"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    property date now: new Date()
    Timer { interval: 1000; repeat: true; running: true; triggeredOnStart: true; onTriggered: desk.now = new Date() }

    // Glisser le fond = déplacer la vue ; double-clic = retour au centre.
    MouseArea {
      anchors.fill: parent
      acceptedButtons: Qt.LeftButton | Qt.MiddleButton
      cursorShape: root.dragging ? Qt.ClosedHandCursor : Qt.ArrowCursor
      property real lx: 0
      property real ly: 0
      onPressed: function(m) { lx = m.x; ly = m.y; root.dragging = true; root.listed = false }
      onPositionChanged: function(m) { if (!pressed) return; root.pan(m.x - lx, m.y - ly); lx = m.x; ly = m.y }
      onReleased: root.dragging = false
      onDoubleClicked: if (!root.s || root.s.opt("infini_dblclick", true) !== false) root.home()
      onWheel: function(w) {
        // Ctrl + molette sur le fond : zoom au pointeur (⌘ + molette passe par Hyprland).
        if (w.modifiers & Qt.ControlModifier) { root.zoomAt(Math.pow(1.0015, w.angleDelta.y), w.x, w.y); return }
        var dx = w.angleDelta.x, dy = w.angleDelta.y
        if (w.modifiers & Qt.ShiftModifier) { dx = dy; dy = 0 }
        if (w.pixelDelta.x !== 0 || w.pixelDelta.y !== 0) root.pan(w.pixelDelta.x, w.pixelDelta.y)
        else root.pan(dx * 0.6, dy * 0.6)
      }
    }

    // ---------------- étoiles filantes (fixes à l'écran)
    Repeater {
      model: root.s && root.s.opt("infini_stars", true) === false ? 0 : 3
      Item {
        id: star
        required property int index
        property real t: 0
        property real x0: 0
        property real y0: 0
        readonly property real len: Math.round(140 * root.k)
        x: x0 + t * root.sw * 0.45; y: y0 + t * root.sh * 0.35
        rotation: 38
        opacity: t < 0.15 ? t / 0.15 : (t > 0.8 ? (1 - t) / 0.2 : 1)
        width: len; height: 2
        Rectangle {
          anchors.fill: parent; radius: 1
          gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0; color: "transparent" }
            GradientStop { position: 1; color: Qt.rgba(1, 1, 1, 0.85) }
          }
        }
        SequentialAnimation {
          running: root.live; loops: Animation.Infinite
          PauseAnimation { duration: 3000 + star.index * 4200 }
          ScriptAction { script: { star.x0 = Math.random() * root.sw * 0.7 - root.sw * 0.1; star.y0 = Math.random() * root.sh * 0.3 - root.sh * 0.1 } }
          NumberAnimation { target: star; property: "t"; from: 0; to: 1; duration: 1300; easing.type: Easing.InQuad }
          PauseAnimation { duration: 6000 + Math.random() * 6000 }
        }
      }
    }

    // ---------------- la toile : tout ce qui suit le glisser
    Item {
      id: world
      x: root.vx; y: root.vy
      width: root.sw; height: root.sh
      scale: root.zoom
      transformOrigin: Item.TopLeft

      // Horloge empilée
      Column {
        visible: !root.s || root.s.opt("infini_clock", true) !== false
        anchors.centerIn: parent
        anchors.verticalCenterOffset: -root.sh * 0.04
        spacing: -Math.round(92 * root.k)
        Text {
          anchors.horizontalCenter: parent.horizontalCenter
          text: Qt.formatTime(desk.now, "HH")
          font.family: root.s ? root.s.displayFont : "Bebas Neue"; font.pixelSize: Math.round(190 * root.k)
          color: Qt.rgba(1, 1, 1, 0.9)
        }
        Text {
          anchors.horizontalCenter: parent.horizontalCenter
          text: Qt.formatTime(desk.now, "mm")
          font.family: root.s ? root.s.displayFont : "Bebas Neue"; font.pixelSize: Math.round(190 * root.k)
          color: Qt.rgba(1, 1, 1, 0.42)
        }
      }

      // Cadre du visualiseur
      Rectangle {
        visible: !root.s || (root.s.showCava && root.s.opt("infini_frame", true) !== false)
        x: Math.round(root.sw * 0.04); y: Math.round(root.sh * 0.5)
        width: Math.round(root.sw * 0.34); height: Math.round(root.sh * 0.17)
        radius: Math.round(10 * root.k)
        color: Qt.rgba(0.12, 0.09, 0.1, 0.55)
        border.color: Qt.rgba(root.acc.r, root.acc.g, root.acc.b, 0.75); border.width: 1
        Row {
          anchors.bottom: parent.bottom; anchors.bottomMargin: Math.round(12 * root.k)
          anchors.horizontalCenter: parent.horizontalCenter
          spacing: Math.round(5 * root.k)
          Repeater {
            model: 40
            Rectangle {
              required property int index
              readonly property var vals: root.s ? root.s.cavaValues : []
              readonly property real v: vals.length ? vals[Math.floor(index * vals.length / 40)] / 100 : 0.08 + 0.06 * Math.abs(Math.sin(index * 0.7 + wave.phase))
              anchors.bottom: parent.bottom
              width: Math.round(7 * root.k); radius: 1
              height: Math.max(3, v * (root.sh * 0.17 - 30 * root.k))
              Behavior on height { enabled: !wave.idle; NumberAnimation { duration: 60 } }
              gradient: Gradient {
                GradientStop { position: 0; color: Qt.lighter(root.acc, 1.12) }
                GradientStop { position: 1; color: Qt.rgba(root.acc.r * 0.55, root.acc.g * 0.4, root.acc.b * 0.45, 0.9) }
              }
            }
          }
        }
      }
    }

    // ---------------- visualiseur sur toute la largeur (fixe), sous la barre
    QtObject {
      id: wave
      property real phase: 0
      // Vague au repos : 10 images/s suffisent (mouvement lent), au lieu de 60.
      readonly property bool idle: root.live && !(root.s && root.s.playing)
      property Timer tick: Timer { interval: 100; repeat: true; running: wave.idle; onTriggered: wave.phase = (wave.phase + Math.PI / 30) % (Math.PI * 2) }
    }
    Row {
      visible: !root.s || (root.s.showCava && root.s.opt("infini_viz", true) !== false)
      anchors.bottom: parent.bottom
      x: 0; width: parent.width
      readonly property int n: 64
      readonly property real bw: width / n
      Repeater {
        model: parent.n
        Item {
          required property int index
          readonly property var vals: root.s ? root.s.cavaValues : []
          readonly property real v: vals.length ? vals[Math.floor(index * vals.length / 64)] / 100
                                                : 0.18 + 0.1 * Math.sin(index * 0.45 + wave.phase) + 0.05 * Math.sin(index * 1.7 - wave.phase * 2)
          width: parent.bw; height: root.sh * 0.2
          anchors.bottom: parent.bottom
          Rectangle {
            anchors.bottom: parent.bottom; anchors.horizontalCenter: parent.horizontalCenter
            width: parent.width - Math.max(2, Math.round(4 * root.k))
            height: Math.max(4, parent.v * parent.height)
            radius: Math.round(3 * root.k)
            Behavior on height { enabled: !wave.idle; NumberAnimation { duration: 70 } }
            gradient: Gradient {
              GradientStop { position: 0; color: Qt.rgba(root.acc.r, root.acc.g, root.acc.b, 0.85) }
              GradientStop { position: 1; color: Qt.rgba(root.acc.r, root.acc.g, root.acc.b, 0.35) }
            }
          }
        }
      }
    }
  }

  // ------------------------------------------------------------ barre du bas
  InfiniBar { screen: root.screen; service: root.s; desk: root }
}
