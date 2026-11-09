import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets
import "T.js" as T

// Bureau du style Sombre : un mur de tuiles qui remplit l'écran (rice « tacoproz »).
// Pochette, paroles, système, labyrinthe, trame, bande de pixels, mot géant,
// spectre, blobs et anneau. Tout vit avec la musique et ralentit quand elle s'arrête.
// Seules les commandes du lecteur prennent les clics.
PanelWindow {
  id: win
  property var service: null
  readonly property var s: service

  color: "transparent"
  anchors { top: true; bottom: true; left: true; right: true }
  exclusionMode: ExclusionMode.Normal
  WlrLayershell.layer: WlrLayer.Bottom
  WlrLayershell.namespace: "liquid-glass-linux-wall"
  WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
  mask: Region { item: ctl }

  readonly property string pix: "Silkscreen"
  readonly property string code: "JetBrainsMono Nerd Font"
  readonly property color acc: s.primary
  readonly property color ink: s.colOnSurface
  readonly property color sub: s.colOnSurfaceVariant
  readonly property var vals: s.cavaValues
  function v(i) { return i < vals.length ? vals[i] / 100 : 0 }

  // Une seule horloge pour toutes les animations : 15 i/s en musique, 2 i/s sinon.
  property int tick: 0
  property date now: new Date()
  Timer {
    // Réglage « Tuiles animées » coupé : 2 i/s même en musique (moins de processeur).
    interval: win.s.playing && win.s.opt("sombre_anim", true) !== false ? 66 : 500
    running: true; repeat: true
    onTriggered: { win.tick++; if (win.tick % 8 === 0) win.now = new Date() }
  }

  // Grille 12 × 6.
  readonly property int pad: 14
  readonly property int gap: 10
  readonly property real cw: (width - 2 * pad + gap) / 12
  readonly property real ch: (height - 2 * pad + gap) / 6

  function gauge(p) {
    var n = Math.round(Math.max(0, Math.min(1, p)) * 10), b = ""
    for (var i = 0; i < 10; i++) b += i < n ? "█" : "░"
    return b
  }

  // ---------------------------------------------------------------- pochette
  Tile {
    c: 0; r: 0; w: 2; h: 2; label: ""
    ClippingRectangle {
      anchors.fill: parent; anchors.margins: 6; radius: 2; color: win.s.alpha(win.acc, 0.1)
      Text {
        anchors.centerIn: parent; text: "?"; font.family: win.pix; font.pixelSize: 48
        color: win.s.alpha(win.acc, 0.4)
      }
      Image {
        anchors.fill: parent; source: win.s.cover; fillMode: Image.PreserveAspectCrop
        asynchronous: true; cache: false; sourceSize.width: 420
      }
    }
  }

  // ---------------------------------------------------------------- lecteur
  Tile {
    c: 2; r: 0; w: 3; h: 2; label: T.t("01 LECTEUR")
    Column {
      x: 14; y: 28; width: parent.width - 28; spacing: 2
      Text {
        width: parent.width; elide: Text.ElideRight
        text: win.s.trackTitle || T.t("Rien en lecture")
        font.family: win.code; font.pixelSize: 15; font.weight: Font.Bold; color: win.ink
      }
      Text {
        width: parent.width; elide: Text.ElideRight; text: win.s.trackArtist || "—"
        font.family: win.code; font.pixelSize: 11; color: win.sub
      }
      Item { width: 1; height: 6 }
      Repeater {
        model: 4
        delegate: Text {
          required property int index
          readonly property int li: Math.max(0, win.s.lineIndex) + index - 1
          readonly property bool cur: li === win.s.lineIndex
          width: parent.width; elide: Text.ElideRight
          text: li >= 0 && li < win.s.lyrics.length ? (cur ? "> " : "  ") + String(win.s.lyrics[li].text || "") : ""
          font.family: win.code; font.pixelSize: 11; font.weight: cur ? Font.Bold : Font.Normal
          color: cur ? win.acc : win.s.alpha(win.sub, 0.7)
        }
      }
    }
    Row {
      id: ctl
      anchors.left: parent.left; anchors.leftMargin: 14
      anchors.bottom: parent.bottom; anchors.bottomMargin: 12
      spacing: 6
      Btn { icon: "skip_previous"; onClicked: { if (win.s.player) win.s.player.previous() } }
      Btn { icon: win.s.playing ? "pause" : "play_arrow"; onClicked: win.s.playPause() }
      Btn { icon: "skip_next"; onClicked: { if (win.s.player) win.s.player.next() } }
    }
    Text {
      anchors.right: parent.right; anchors.rightMargin: 14
      anchors.verticalCenter: ctl.verticalCenter
      text: win.s.fmtTime(win.s.position) + " / " + win.s.fmtTime(win.s.length)
      font.family: win.code; font.pixelSize: 10; color: win.sub
    }
    Rectangle {
      anchors.bottom: parent.bottom; anchors.left: parent.left
      height: 3; width: parent.width * win.s.progress; color: win.acc
    }
  }

  // ---------------------------------------------------------------- système
  Tile {
    c: 5; r: 0; w: 3; h: 2; label: T.t("02 SYSTEME")
    Text {
      x: 14; y: 30; width: parent.width - 28; clip: true
      lineHeight: 1.25
      font.family: win.code; font.pixelSize: 12; color: win.ink
      text: win.s.user + "@omarchy\n"
            + "cpu " + win.gauge(win.s.cpu) + " " + Math.round(win.s.cpu * 100) + "%\n"
            + "ram " + win.gauge(win.s.memPct) + " " + Math.round(win.s.memPct * 100) + "%\n"
            + "ssd " + win.gauge(win.s.diskPct) + " " + Math.round(win.s.diskPct * 100) + "%\n"
            + "tmp " + win.s.temp + "°C\n"
            + "up  " + win.s.uptimeText + "\n"
            + "ext " + (win.s.weather ? win.s.weather.temp + "°C " + win.s.weatherDesc : "--")
    }
  }

  // ---------------------------------------------------------------- labyrinthe
  Tile {
    c: 8; r: 0; w: 4; h: 3; label: T.t("03 RESEAU")
    Canvas {
      id: maze
      anchors.fill: parent; anchors.margins: 8; anchors.topMargin: 26
      property var walkers: []
      property int steps: 0
      readonly property int step: 14
      function reset(ctx) {
        ctx.clearRect(0, 0, width, height)
        steps = 0
        var w = []
        for (var i = 0; i < 7; i++)
          w.push({ x: Math.floor(Math.random() * width / step) * step, y: Math.floor(Math.random() * height / step) * step,
                   d: Math.floor(Math.random() * 4) })
        walkers = w
      }
      onPaint: {
        var ctx = getContext("2d")
        if (walkers.length === 0 || steps > 420) reset(ctx)
        steps++
        ctx.lineWidth = 1
        ctx.strokeStyle = String(win.s.alpha(win.acc, 0.55))
        var n = steps < 3 ? 40 : 1 + Math.round(win.s.beat * 3)   // part d'un tracé déjà dessiné
        for (var k = 0; k < n; k++) for (var i = 0; i < walkers.length; i++) {
          var a = walkers[i]
          if (Math.random() < 0.3) a.d = (a.d + (Math.random() < 0.5 ? 1 : 3)) % 4
          var nx = a.x + [step, 0, -step, 0][a.d], ny = a.y + [0, step, 0, -step][a.d]
          if (nx < 0 || ny < 0 || nx > width || ny > height) { a.d = (a.d + 2) % 4; continue }
          ctx.beginPath(); ctx.moveTo(a.x + 0.5, a.y + 0.5); ctx.lineTo(nx + 0.5, ny + 0.5); ctx.stroke()
          a.x = nx; a.y = ny
        }
      }
      Connections { target: win; function onTickChanged() { if (win.tick % 2 === 0) maze.requestPaint() } }
    }
  }

  // ---------------------------------------------------------------- trame
  Tile {
    c: 0; r: 2; w: 5; h: 1; label: ""
    Text {
      id: rain
      anchors.fill: parent; anchors.margins: 8; clip: true
      font.family: win.code; font.pixelSize: 9; lineHeight: 1.1
      color: win.s.alpha(win.acc, 0.5)
      function fill() {
        var cols = Math.floor(width / 5.6), rows = Math.floor(height / 11), g = "01ABCDEF:./-+<>", out = ""
        for (var y = 0; y < rows; y++) {
          for (var x = 0; x < cols; x++) out += Math.random() < 0.55 ? " " : g[Math.floor(Math.random() * g.length)]
          out += "\n"
        }
        text = out
      }
      Connections { target: win; function onTickChanged() { if (win.tick % 3 === 0) rain.fill() } }
    }
  }

  // ---------------------------------------------------------------- bande de pixels
  Tile {
    c: 5; r: 2; w: 3; h: 2; label: "04 SIGNAL"
    Canvas {
      id: band
      anchors.fill: parent; anchors.margins: 8; anchors.topMargin: 24
      onPaint: {
        var ctx = getContext("2d"), bs = 5, n = Math.floor(width * 0.8 / bs)
        ctx.clearRect(0, 0, width, height)
        ctx.save()
        ctx.translate(width / 2, height / 2)
        ctx.rotate(0.38)
        ctx.fillStyle = String(win.acc)
        for (var i = 0; i < n; i++) {
          var e = Math.sin(i / n * Math.PI)
          var val = win.vals.length ? win.v(Math.floor(i / n * win.vals.length)) : 0.14 + 0.1 * Math.sin(i * 0.5 + win.tick * 0.2)
          var hgt = Math.max(1, Math.round((0.16 + val) * e * 9))
          for (var j = -hgt; j <= hgt; j++) {
            if (Math.abs(j) === hgt && (i + j) % 2) continue
            ctx.fillRect((i - n / 2) * bs, j * bs, bs - 1, bs - 1)
          }
        }
        ctx.restore()
      }
      Connections { target: win; function onTickChanged() { band.requestPaint() } }
    }
  }

  // ---------------------------------------------------------------- blobs
  Tile {
    c: 8; r: 3; w: 2; h: 1; label: ""
    Canvas {
      id: blobs
      anchors.fill: parent; anchors.margins: 4
      onPaint: {
        var ctx = getContext("2d"), bs = 4, cols = Math.ceil(width / bs), rows = Math.ceil(height / bs), t = win.tick * 0.06
        var b = []
        for (var i = 0; i < 4; i++)
          b.push([cols * (0.5 + 0.42 * Math.sin(t * (0.7 + i * 0.23) + i * 1.7)), rows * (0.5 + 0.4 * Math.cos(t * (0.9 - i * 0.17) + i)),
                  (2.6 + i * 0.8 + win.s.beat * 2)])
        ctx.clearRect(0, 0, width, height)
        ctx.fillStyle = String(win.s.alpha(win.acc, 0.75))
        for (var y = 0; y < rows; y++) for (var x = 0; x < cols; x++) {
          var f = 0
          for (var k = 0; k < 4; k++) { var dx = x - b[k][0], dy = y - b[k][1]; f += b[k][2] * b[k][2] / (dx * dx + dy * dy + 1) }
          if (f > 1.1) ctx.fillRect(x * bs, y * bs, bs, bs)
        }
      }
      Connections { target: win; function onTickChanged() { if (win.tick % 2 === 1) blobs.requestPaint() } }
    }
  }

  // ---------------------------------------------------------------- anneau
  Tile {
    c: 10; r: 3; w: 2; h: 1; label: ""
    Item {
      id: ring
      anchors.centerIn: parent
      width: Math.min(parent.width, parent.height) - 18; height: width
      rotation: win.tick * 1.2
      Repeater {
        model: 36
        delegate: Rectangle {
          required property int index
          readonly property bool big: index % 9 === 0
          x: ring.width / 2 - width / 2; y: 0
          width: big ? 4 : 2
          height: big ? 12 + win.s.beat * 6 : 5
          color: big ? win.acc : win.s.alpha(win.acc, 0.5)
          transformOrigin: Item.Top
          transform: Rotation { origin.x: 1; origin.y: ring.height / 2; angle: index * 10 }
        }
      }
    }
    Text {
      anchors.centerIn: parent; text: Qt.formatTime(win.now, "HH:mm")
      font.family: win.pix; font.pixelSize: 15; color: win.ink
    }
  }

  // ---------------------------------------------------------------- mot géant
  Tile {
    readonly property bool lyr: win.s.word !== "" && win.s.opt("sombre_word", true) !== false
    c: 0; r: 3; w: 5; h: 3; label: lyr ? T.t("05 PAROLES") : T.t("05 HEURE")
    Text {
      id: giant
      anchors.centerIn: parent
      width: parent.width - 48; height: parent.height - 60
      horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
      text: (parent.lyr ? win.s.word : Qt.formatTime(win.now, "HH:mm")).toUpperCase()
      font.family: win.pix; font.pixelSize: 150; font.weight: Font.Bold
      fontSizeMode: Text.Fit; minimumPixelSize: 24
      color: win.acc
      onTextChanged: pop.restart()
      SequentialAnimation on scale {
        id: pop; running: false
        NumberAnimation { to: 1.07; duration: 60; easing.type: Easing.OutQuad }
        NumberAnimation { to: 1; duration: 200; easing.type: Easing.OutCubic }
      }
    }
    Text {
      anchors.horizontalCenter: parent.horizontalCenter
      anchors.bottom: parent.bottom; anchors.bottomMargin: 12
      width: parent.width - 40; horizontalAlignment: Text.AlignHCenter; elide: Text.ElideRight
      text: win.s.word !== "" ? win.s.line : win.now.toLocaleDateString(Qt.locale(T.loc), "dddd d MMMM")
      font.family: win.code; font.pixelSize: 12; color: win.sub
    }
  }

  // ---------------------------------------------------------------- spectre
  Tile {
    c: 5; r: 4; w: 7; h: 2; label: T.t("06 SPECTRE")
    Row {
      id: spec
      anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom
      anchors.margins: 12
      height: parent.height - 40
      spacing: 2
      Repeater {
        model: 64
        delegate: Item {
          required property int index
          width: (spec.width - 63 * 2) / 64; height: spec.height
          readonly property real val: win.vals.length ? win.v(Math.floor(index / 64 * win.vals.length))
                                                      : 0.04 + 0.03 * Math.sin(index * 0.4 + win.tick * 0.25)
          Rectangle {
            anchors.bottom: parent.bottom; width: parent.width
            height: Math.max(2, parent.height * parent.val)
            color: win.s.alpha(win.acc, 0.55 + 0.45 * parent.val)
          }
        }
      }
    }
  }

  // ---------------------------------------------------------------- briques
  component Tile: Rectangle {
    id: tl
    property int c: 0
    property int r: 0
    property int w: 1
    property int h: 1
    property string label: ""
    x: win.pad + c * win.cw
    y: win.pad + r * win.ch
    width: w * win.cw - win.gap
    height: h * win.ch - win.gap
    radius: 2
    clip: true
    color: win.s.alpha(win.s.surface, 0.72)
    border.width: 1
    border.color: win.s.alpha(win.acc, 0.3)
    // Liseré lumineux du haut, comme une fenêtre active.
    Rectangle { width: parent.width; height: 2; color: win.s.alpha(win.acc, 0.8) }
    Text {
      visible: tl.label !== ""
      x: 14; y: 9; text: tl.label
      font.family: win.pix; font.pixelSize: 10; color: win.s.alpha(win.acc, 0.85)
    }
  }
  component Btn: Rectangle {
    id: bt
    property string icon: ""
    signal clicked()
    width: 30; height: 24; radius: 2
    color: bma.containsMouse ? win.acc : win.s.alpha(win.acc, 0.14)
    MIcon { anchors.centerIn: parent; icon: bt.icon; size: 16; color: bma.containsMouse ? win.s.colOnPrimary : win.ink }
    MouseArea { id: bma; anchors.fill: parent; hoverEnabled: true; onClicked: bt.clicked() }
  }
}
