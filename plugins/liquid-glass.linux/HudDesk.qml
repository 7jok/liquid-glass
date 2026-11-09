import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import "T.js" as T
import "HudLand.js" as Land

// Style 7JOKS : bureau de terminal de science-fiction, tout en traits fins sur fond noir.
//   centre : cadre du terminal, onglets = bureaux (les fenêtres restent dedans)
//   gauche : horloge, système, processeur, mémoire, processus
//   droite : barre plate (clavier, réseau, batterie, heure), réseau, globe, trafic
//   bas    : dossiers du dossier personnel, clavier
// Démarrage (HudBoot) à l'ouverture de la session, puis les panneaux arrivent de haut
// en bas. Teinte : hud_tone (blanc, cyan, ambre, vert, rouge).
Scope {
  id: root
  property var service: null
  property var screen: null
  readonly property var s: service

  readonly property string tone: String(s ? s.opt("hud_tone", "blanc") : "blanc")
  readonly property var tones: ({ blanc: "#e6e6e6", cyan: "#aacfd1", ambre: "#ffb43c", vert: "#5cff8a", rouge: "#ff5a5a" })
  readonly property color acc: s && s.colorMode === "perso" && s.accentHex !== "" ? s.accentHex : (tones[tone] || tones.blanc)
  readonly property color dim: Qt.rgba(acc.r, acc.g, acc.b, 0.5)
  readonly property color faint: Qt.rgba(acc.r, acc.g, acc.b, 0.16)
  readonly property string mono: "Share Tech Mono"
  readonly property string head: "Michroma"

  // Géométrie (écran de 1280 × 720 de référence)
  readonly property real sw: screen ? screen.width : 1280
  readonly property real sh: screen ? screen.height : 720
  readonly property real k: Math.min(sw / 1280, sh / 720)
  readonly property real pad: Math.round(10 * k)
  readonly property real colW: Math.round(232 * k)
  readonly property real bottomH: Math.round(200 * k)
  readonly property real topH: Math.round(30 * k)
  readonly property real tabH: Math.round(20 * k)
  readonly property rect frame: Qt.rect(pad + colW + pad, topH, sw - 2 * (pad + colW + pad), sh - topH - bottomH - pad)

  // ------------------------------------------------------------ démarrage et arrivée
  readonly property string bootMode: String(s ? s.opt("hud_boot", "session") : "session")
  property bool booting: false
  property real t: Quickshell.env("LG_HUD_T") !== "" && Quickshell.env("LG_HUD_T") !== undefined && Quickshell.env("LG_HUD_T") !== null ? Number(Quickshell.env("LG_HUD_T")) : 0
  NumberAnimation { id: intro; target: root; property: "t"; from: 0; to: 1; duration: 3400; easing.type: Easing.Linear }
  function reveal(delay, dur) { return Math.max(0, Math.min(1, (t * 3400 - delay) / dur)) }
  function startIntro() { if (String(Quickshell.env("LG_HUD_T") || "") === "") intro.restart(); afterBoot.restart() }
  readonly property string sig: String(Quickshell.env("HYPRLAND_INSTANCE_SIGNATURE") || "test")
  FileView {
    id: bootMark
    path: "/run/user/" + (Quickshell.env("UID") || "1000") + "/liquid-glass-hud-boot"
    printErrors: false
    onLoaded: root.decide(text().trim())
    onLoadFailed: root.decide("")
  }
  property bool decided: false
  function decide(mark) {
    if (decided) return
    decided = true
    var forced = String(Quickshell.env("LG_HUD_BOOT") || "") !== ""
    if (s && s.testing && !forced) { if (String(Quickshell.env("LG_HUD_T") || "") === "") t = 1; return }
    var play = forced || bootMode === "toujours" || (bootMode === "session" && mark !== sig)
    if (play) { booting = true; if (!(s && s.testing)) bootMark.setText(sig) }
    else startIntro()
  }
  // Toucher ce fichier (touch ~/.cache/liquid-glass/hud-boot-now) rejoue le démarrage.
  FileView {
    path: Quickshell.env("HOME") + "/.cache/liquid-glass/hud-boot-now"
    printErrors: false
    watchChanges: true
    onFileChanged: { root.t = 0; root.booting = true }
  }
  LazyLoader {
    active: root.booting
    HudBoot {
      screen: root.screen
      service: root.s
      acc: root.acc
      font: root.mono
      onFinished: { root.booting = false; root.startIntro() }
    }
  }
  // Après le démarrage : un terminal s'ouvre dans le cadre si le bureau est vide.
  Timer {
    id: afterBoot
    interval: 2600
    onTriggered: {
      if (!root.s || root.s.testing || root.s.opt("hud_terminal", true) === false) return
      var mon = Hyprland.monitorFor(root.screen), ws = mon && mon.activeWorkspace ? mon.activeWorkspace.id : -1
      var tl = Hyprland.toplevels.values
      for (var i = 0; i < tl.length; i++) if (tl[i].workspace && tl[i].workspace.id === ws) return
      var fetch = Quickshell.env("HOME") + "/Work/liquid-glass/bin/liquid-glass-fetch"
      Quickshell.execDetached(["xdg-terminal-exec", "sh", "-c", "'" + fetch + "' --style hud --mode text; exec \"${SHELL:-bash}\""])
    }
  }

  // ------------------------------------------------------------ données
  property var cores: []          // % par cœur
  property var prevStat: []
  property var histA: []          // moyenne de la première moitié des cœurs
  property var histB: []
  property real memTotal: 0
  property real memAvail: 0
  property real swapTotal: 0
  property real swapFree: 0
  property int tasks: 0
  property real rx: 0
  property real tx: 0
  property real rxTotal: 0
  property real txTotal: 0
  property var prevNet: null
  property var histRx: []
  property var histTx: []
  property var procs: []
  property var info: ({ vendor: "", model: "", chassis: "", kernel: "", cpu: "", freqMin: 0, freqMax: 0 })
  property string iface: ""
  property string ipv4: ""
  property string gateway: ""
  property int ping: -1
  property var files: []
  readonly property bool live: !!s && root.screen !== null

  function push(arr, v, n) { var a = arr.slice(); a.push(v); while (a.length > n) a.shift(); return a }
  function human(b) {
    if (b > 1073741824) return (b / 1073741824).toFixed(1) + " Gio"
    if (b > 1048576) return (b / 1048576).toFixed(1) + " Mio"
    if (b > 1024) return (b / 1024).toFixed(0) + " Kio"
    return Math.round(b) + " o"
  }

  Process {
    id: statP
    command: ["sh", "-c", "cat /proc/stat; echo @@; cat /proc/meminfo; echo @@; cat /proc/net/dev; echo @@; ls /proc | grep -c '^[0-9]'; echo @@; grep MHz /proc/cpuinfo"]
    stdout: StdioCollector {
      onStreamFinished: {
        var p = text.split("@@")
        if (p.length < 5) return
        // Processeur, cœur par cœur.
        var lines = p[0].split("\n"), cur = [], use = []
        for (var i = 0; i < lines.length; i++) {
          var m = lines[i].match(/^cpu(\d+)\s+(.*)$/)
          if (!m) continue
          var f = m[2].trim().split(/\s+/).map(Number)
          var idle = f[3] + (f[4] || 0), tot = 0
          for (var j = 0; j < f.length; j++) tot += f[j]
          cur.push([idle, tot])
        }
        for (var c = 0; c < cur.length; c++) {
          var pv = root.prevStat[c]
          use.push(pv ? Math.max(0, Math.min(100, 100 * (1 - (cur[c][0] - pv[0]) / Math.max(1, cur[c][1] - pv[1])))) : 0)
        }
        root.prevStat = cur
        root.cores = use
        var half = Math.max(1, Math.ceil(use.length / 2)), a = 0, b = 0
        for (var u = 0; u < use.length; u++) { if (u < half) a += use[u]; else b += use[u] }
        root.histA = root.push(root.histA, a / half, 60)
        root.histB = root.push(root.histB, use.length > half ? b / (use.length - half) : 0, 60)
        // Mémoire.
        var mi = {}
        p[1].split("\n").forEach(function(l) { var q = l.match(/^(\w+):\s+(\d+)/); if (q) mi[q[1]] = Number(q[2]) * 1024 })
        root.memTotal = mi.MemTotal || 0; root.memAvail = mi.MemAvailable || 0
        root.swapTotal = mi.SwapTotal || 0; root.swapFree = mi.SwapFree || 0
        // Réseau : l'interface de la route par défaut.
        var net = null
        p[2].split("\n").forEach(function(l) {
          var q = l.match(/^\s*([\w.-]+):\s*(\d+)\s+\d+\s+\d+\s+\d+\s+\d+\s+\d+\s+\d+\s+\d+\s+(\d+)/)
          if (q && q[1] === root.iface) net = [Number(q[2]), Number(q[3])]
        })
        if (net && root.prevNet) {
          root.rx = Math.max(0, net[0] - root.prevNet[0]); root.tx = Math.max(0, net[1] - root.prevNet[1])
          root.histRx = root.push(root.histRx, root.rx, 60); root.histTx = root.push(root.histTx, root.tx, 60)
        }
        if (net) { root.prevNet = net; root.rxTotal = net[0]; root.txTotal = net[1] }
        root.tasks = Number(p[3].trim()) || 0
        var mhz = p[4].split("\n").map(function(l) { var q = l.match(/([\d.]+)\s*$/); return q ? Number(q[1]) : 0 }).filter(function(x) { return x > 0 })
        if (mhz.length) {
          var inf = Object.assign({}, root.info)
          inf.freqMin = Math.min.apply(null, mhz) / 1000; inf.freqMax = Math.max.apply(null, mhz) / 1000
          root.info = inf
        }
      }
    }
  }
  Timer { interval: 1000; repeat: true; running: root.live; triggeredOnStart: true; onTriggered: if (!statP.running) statP.running = true }

  Process {
    id: psP
    command: ["ps", "-eo", "pid,comm,%cpu,%mem", "--sort=-%cpu", "--no-headers"]
    stdout: StdioCollector {
      onStreamFinished: {
        var out = []
        text.split("\n").slice(0, 5).forEach(function(l) {
          var q = l.trim().match(/^(\d+)\s+(.+?)\s+([\d.]+)\s+([\d.]+)$/)
          if (q) out.push({ pid: q[1], name: q[2], cpu: q[3], mem: q[4] })
        })
        root.procs = out
      }
    }
  }
  Timer { interval: 2500; repeat: true; running: root.live; triggeredOnStart: true; onTriggered: if (!psP.running) psP.running = true }

  Process {
    id: infoP
    running: root.live
    command: ["sh", "-c", "cat /sys/class/dmi/id/sys_vendor /sys/class/dmi/id/product_version /sys/class/dmi/id/chassis_type 2>/dev/null; echo @@; uname -r; grep -m1 'model name' /proc/cpuinfo | cut -d: -f2"]
    stdout: StdioCollector {
      onStreamFinished: {
        var p = text.split("@@"), a = (p[0] || "").split("\n"), b = (p[1] || "").split("\n")
        var ch = Number(a[2]), kinds = { 3: "desktop", 8: "portable", 9: "laptop", 10: "notebook", 13: "all-in-one", 31: "convertible", 32: "detachable" }
        var inf = Object.assign({}, root.info)
        inf.vendor = (a[0] || "").trim(); inf.model = (a[1] || "").trim(); inf.chassis = kinds[ch] || (ch ? "type " + ch : "")
        inf.kernel = (b[0] || "").trim(); inf.cpu = (b[1] || "").replace(/\(R\)|\(TM\)|CPU|Processor/g, "").replace(/\s+/g, " ").trim()
        root.info = inf
      }
    }
  }

  Process {
    id: netP
    command: ["sh", "-c", "ip -4 route show default | head -1; echo @@; ip -4 -o addr show"]
    stdout: StdioCollector {
      onStreamFinished: {
        var p = text.split("@@"), r = (p[0] || "").match(/via\s+([\d.]+)\s+dev\s+(\S+)/)
        root.gateway = r ? r[1] : ""
        root.iface = r ? r[2] : ""
        var ip = ""
        ;(p[1] || "").split("\n").forEach(function(l) { var q = l.match(/^\d+:\s+(\S+)\s+inet\s+([\d.]+)/); if (q && q[1] === root.iface) ip = q[2] })
        root.ipv4 = ip
        if (root.gateway !== "" && !pingP.running) pingP.running = true
        if (root.gateway === "") root.ping = -1
      }
    }
  }
  Timer { interval: 8000; repeat: true; running: root.live; triggeredOnStart: true; onTriggered: if (!netP.running) netP.running = true }
  // Latence vers la box (réseau local), pas vers Internet.
  Process {
    id: pingP
    command: ["ping", "-c", "1", "-W", "1", root.gateway || "127.0.0.1"]
    stdout: StdioCollector { onStreamFinished: { var q = text.match(/time=([\d.]+)/); root.ping = q ? Math.round(Number(q[1])) : -1 } }
  }

  Process {
    id: lsP
    command: ["sh", "-c", "cd \"$HOME\" && ls -1Ap --group-directories-first | grep -v '^\\.' | head -60"]
    stdout: StdioCollector { onStreamFinished: root.files = text.split("\n").filter(function(x) { return x !== "" }) }
  }
  Timer { interval: 15000; repeat: true; running: root.live; triggeredOnStart: true; onTriggered: if (!lsP.running) lsP.running = true }

  // ------------------------------------------------------------ zones réservées
  // Les fenêtres se rangent dans le cadre central, onglets compris.
  PanelWindow {
    screen: root.screen; color: "transparent"
    anchors { top: true; left: true; right: true }
    implicitHeight: 1; exclusiveZone: root.topH + root.tabH + 2
    WlrLayershell.namespace: "liquid-glass-hud-edge"; mask: Region {}
  }
  PanelWindow {
    screen: root.screen; color: "transparent"
    anchors { bottom: true; left: true; right: true }
    implicitHeight: 1; exclusiveZone: root.bottomH + root.pad + 2
    WlrLayershell.namespace: "liquid-glass-hud-edge"; mask: Region {}
  }
  PanelWindow {
    screen: root.screen; color: "transparent"
    anchors { top: true; bottom: true; left: true }
    implicitWidth: 1; exclusiveZone: root.frame.x + 2
    WlrLayershell.namespace: "liquid-glass-hud-edge"; mask: Region {}
  }
  PanelWindow {
    screen: root.screen; color: "transparent"
    anchors { top: true; bottom: true; right: true }
    implicitWidth: 1; exclusiveZone: root.frame.x + 2
    WlrLayershell.namespace: "liquid-glass-hud-edge"; mask: Region {}
  }

  // ------------------------------------------------------------ éléments communs
  component Label: Text {
    font.family: root.mono; font.pixelSize: Math.max(8, Math.round(9 * root.k)); color: root.acc
    elide: Text.ElideRight
  }
  // En-tête de panneau : trait fin, petits taquets aux bouts, titre et sous-titre.
  component Head: Item {
    id: hd
    property string title: ""
    property string sub: ""
    width: parent ? parent.width : 100; height: Math.round(16 * root.k)
    Rectangle { y: 0; width: parent.width; height: 1; color: root.dim }
    Rectangle { y: -1; width: Math.round(14 * root.k); height: 3; color: root.acc }
    Rectangle { anchors.right: parent.right; y: -1; width: Math.round(14 * root.k); height: 3; color: root.acc }
    Label { y: Math.round(3 * root.k); text: hd.title; font.letterSpacing: 1 }
    Label { y: Math.round(3 * root.k); anchors.right: parent.right; width: Math.min(implicitWidth, parent.width * 0.6); horizontalAlignment: Text.AlignRight; text: hd.sub; color: root.dim }
  }
  // Petite colonne « TITRE / valeur ».
  component Stat: Column {
    property string key: ""
    property string val: ""
    spacing: 0
    Label { text: parent.key; color: root.dim; font.pixelSize: Math.max(7, Math.round(8 * root.k)) }
    Label { text: parent.val; font.pixelSize: Math.max(8, Math.round(10 * root.k)) }
  }
  // Courbe sur 60 valeurs.
  component Graph: Canvas {
    id: gr
    property var vals: []
    property var vals2: []
    property real maxV: 100
    property bool grid: true
    onValsChanged: requestPaint()
    onVals2Changed: requestPaint()
    onAvailableChanged: requestPaint()
    onWidthChanged: requestPaint()
    onPaint: {
      var c = getContext("2d"), w = width, h = height
      c.reset()
      if (grid) {
        c.strokeStyle = root.faint; c.lineWidth = 1
        c.beginPath()
        for (var gx = 0; gx <= 6; gx++) { var xx = Math.round(gx * (w - 1) / 6) + 0.5; c.moveTo(xx, 0); c.lineTo(xx, h) }
        c.moveTo(0, Math.round(h / 2) + 0.5); c.lineTo(w, Math.round(h / 2) + 0.5)
        c.stroke()
      }
      var top = maxV
      if (top <= 0) { for (var i = 0; i < vals.length; i++) top = Math.max(top, vals[i]); for (var i2 = 0; i2 < vals2.length; i2++) top = Math.max(top, vals2[i2]); top = Math.max(top, 1) }
      function line(arr, col, lw) {
        if (arr.length < 2) return
        c.strokeStyle = col; c.lineWidth = lw; c.beginPath()
        for (var q = 0; q < arr.length; q++) {
          var px = w - (arr.length - 1 - q) * (w / 59), py = h - 2 - (arr[q] / top) * (h - 4)
          if (q === 0) c.moveTo(px, py); else c.lineTo(px, py)
        }
        c.stroke()
      }
      line(vals2, root.dim, 1)
      line(vals, root.acc, 1.5)
    }
  }
  // Panneau qui se déplie de haut en bas à son tour.
  component Reveal: Item {
    id: rv
    property real at: 0
    property real dur: 420
    readonly property real r: root.reveal(at, dur)
    clip: true
    opacity: r > 0 ? 1 : 0
    // Le contenu garde sa taille ; seul le cadre de découpe grandit.
    default property alias content: inner.data
    Item { id: inner; width: rv.width; height: rv.height; y: 0 }
    layer.enabled: r < 1
    Rectangle { visible: rv.r > 0 && rv.r < 1; y: rv.height * rv.r - 1; width: rv.width; height: 1; color: root.acc }
    // On masque ce qui n'est pas encore déplié.
    Rectangle { y: rv.height * rv.r; width: rv.width; height: rv.height * (1 - rv.r); color: "black" }
  }

  // ------------------------------------------------------------ bureau
  PanelWindow {
    id: desk
    screen: root.screen
    color: "black"
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Bottom
    WlrLayershell.namespace: "liquid-glass-hud-desktop"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    mask: Region { regions: [ r1, r2, r3, r4 ] }
    Region { id: r1; item: tabsRow }
    Region { id: r2; item: fsPanel }
    Region { id: r3; item: strip }
    Region { id: r4; item: kbPanel }

    readonly property var monitor: root.screen ? Hyprland.monitorFor(root.screen) : Hyprland.focusedMonitor
    readonly property int activeWs: monitor && monitor.activeWorkspace ? monitor.activeWorkspace.id : 1
    property date now: new Date()
    Timer { interval: 1000; repeat: true; running: true; triggeredOnStart: true; onTriggered: desk.now = new Date() }

    // Grille très légère sur tout le fond.
    Canvas {
      anchors.fill: parent
      opacity: 0.5 * root.reveal(0, 900)
      onWidthChanged: requestPaint()
      onPaint: {
        var c = getContext("2d"); c.reset(); c.fillStyle = root.faint
        var step = Math.round(32 * root.k)
        for (var x = step; x < width; x += step) for (var y = step; y < height; y += step) c.fillRect(x, y, 1, 1)
      }
    }

    // ---------------- cadre du terminal : un trait au centre, qui s'ouvre en rectangle
    Item {
      id: frameBox
      readonly property real a: root.reveal(0, 420)        // le trait s'allonge
      readonly property real b: root.reveal(380, 520)      // puis il s'ouvre en hauteur
      readonly property real fullH: root.frame.height
      x: root.frame.x + root.frame.width * (1 - a) / 2
      width: root.frame.width * a
      y: root.frame.y + fullH / 2 - (fullH / 2) * b
      height: Math.max(2, fullH * b)
      visible: a > 0
      Rectangle {
        anchors.fill: parent; anchors.topMargin: frameBox.b > 0.95 ? root.tabH : 0
        color: "transparent"; border.color: root.acc; border.width: 1; radius: Math.round(4 * root.k)
      }
      // Coins plus épais, comme sur les vieux écrans militaires.
      Repeater {
        model: 4
        Rectangle {
          required property int index
          visible: frameBox.b > 0.95
          width: Math.round(16 * root.k); height: 3; color: root.acc
          x: index % 2 ? frameBox.width - width : 0
          y: index < 2 ? root.tabH - 1 : frameBox.height - 2
        }
      }
    }
    // Onglets : un par bureau. Le bureau actif est plein ; les autres disent ce qu'ils contiennent.
    Row {
      id: tabsRow
      x: root.frame.x; y: root.frame.y
      width: root.frame.width; height: root.tabH
      opacity: root.reveal(900, 300)
      spacing: Math.round(3 * root.k)
      Repeater {
        model: 5
        Item {
          id: tab
          required property int index
          readonly property int num: index + 1
          readonly property bool on: desk.activeWs === num
          readonly property string what: {
            var tl = Hyprland.toplevels.values
            for (var i = 0; i < tl.length; i++) {
              var w = tl[i]
              if (w.workspace && w.workspace.id === tab.num) {
                var ipc = w.lastIpcObject
                return String(ipc && ipc.class ? ipc.class : (w.title || "")).split(".").pop().toUpperCase()
              }
            }
            return T.t("VIDE")
          }
          width: (tabsRow.width - 4 * tabsRow.spacing) / 5; height: root.tabH
          Canvas {
            anchors.fill: parent
            property bool on: tab.on
            onOnChanged: requestPaint()
            onWidthChanged: requestPaint()
            onPaint: {
              var c = getContext("2d"), w = width, h = height, sl = h * 0.6
              c.reset()
              c.beginPath(); c.moveTo(0, h); c.lineTo(0, 0); c.lineTo(w - sl, 0); c.lineTo(w, h)
              if (on) { c.closePath(); c.fillStyle = root.acc; c.fill() }
              else { c.strokeStyle = root.dim; c.lineWidth = 1; c.stroke() }
            }
          }
          Label {
            anchors.centerIn: parent; anchors.horizontalCenterOffset: -root.tabH * 0.2
            width: parent.width - root.tabH; horizontalAlignment: Text.AlignHCenter
            text: (tab.on && tab.what === T.t("VIDE") ? T.t("PRINCIPAL") : tab.what)
            color: tab.on ? "black" : root.acc
          }
          MouseArea {
            anchors.fill: parent; cursorShape: Qt.PointingHandCursor
            onClicked: Quickshell.execDetached(["hyprctl", "dispatch", "hl.dsp.focus({ workspace = \"" + tab.num + "\" })"])
          }
        }
      }
    }

    // ---------------- colonne gauche
    Column {
      id: leftCol
      x: root.pad; y: root.pad
      width: root.colW
      spacing: Math.round(8 * root.k)

      Reveal {
        at: 1200; width: leftCol.width; height: clockCol.implicitHeight
        Column {
          id: clockCol
          width: leftCol.width; spacing: Math.round(4 * root.k)
          Head { title: T.t("PANNEAU"); sub: T.t("SYSTÈME") }
          Text {
            text: Qt.formatTime(desk.now, "HH:mm:ss").split("").join(" ")
            font.family: root.head; font.pixelSize: Math.round(26 * root.k); color: root.acc
            width: leftCol.width; horizontalAlignment: Text.AlignHCenter
          }
          Row {
            width: leftCol.width; spacing: Math.round(10 * root.k)
            Stat { key: Qt.formatDate(desk.now, "yyyy"); val: desk.now.toLocaleDateString(Qt.locale("en_US"), "MMM d").toUpperCase() }
            Stat { key: T.t("EN MARCHE"); val: root.s ? root.s.uptimeText : "" }
            Stat { key: "TYPE"; val: "linux" }
            Stat { key: T.t("ÉNERGIE"); val: root.s && root.s.batteryPct >= 0 ? root.s.batteryPct + "%" + (root.s.charging ? " ⚡" : "") : "SECTEUR" }
          }
          Row {
            width: leftCol.width; spacing: Math.round(10 * root.k)
            Stat { key: T.t("FABRICANT"); val: root.info.vendor || "—"; width: leftCol.width * 0.3 }
            Stat { key: T.t("MODÈLE"); val: root.info.model || "—"; width: leftCol.width * 0.4 }
            Stat { key: T.t("CHÂSSIS"); val: root.info.chassis || "—" }
          }
        }
      }

      Reveal {
        at: 1450; width: leftCol.width; height: cpuCol.implicitHeight
        Column {
          id: cpuCol
          width: leftCol.width; spacing: Math.round(3 * root.k)
          Head { title: T.t("PROCESSEUR"); sub: root.info.cpu }
          Repeater {
            model: 2
            Row {
              required property int index
              width: leftCol.width; spacing: Math.round(6 * root.k)
              readonly property int half: Math.ceil(root.cores.length / 2)
              readonly property var hist: index === 0 ? root.histA : root.histB
              Column {
                width: Math.round(46 * root.k); anchors.verticalCenter: parent.verticalCenter
                Label { text: "#" + (parent.parent.index === 0 ? "1-" + parent.parent.half : (parent.parent.half + 1) + "-" + root.cores.length) }
                Label { text: T.t("moy. ") + Math.round(parent.parent.hist.length ? parent.parent.hist[parent.parent.hist.length - 1] : 0) + "%"; color: root.dim }
              }
              Graph { width: leftCol.width - Math.round(52 * root.k); height: Math.round(32 * root.k); vals: parent.hist }
            }
          }
          Row {
            width: leftCol.width; spacing: Math.round(14 * root.k)
            Stat { key: T.t("TEMP."); val: (root.s ? root.s.temp : 0) + "°C" }
            Stat { key: "MIN"; val: root.info.freqMin ? root.info.freqMin.toFixed(1) + "GHz" : "—" }
            Stat { key: "MAX"; val: root.info.freqMax ? root.info.freqMax.toFixed(1) + "GHz" : "—" }
            Stat { key: T.t("TÂCHES"); val: String(root.tasks) }
          }
        }
      }

      Reveal {
        at: 1700; width: leftCol.width; height: memCol.implicitHeight
        Column {
          id: memCol
          width: leftCol.width; spacing: Math.round(4 * root.k)
          Head { title: T.t("MÉMOIRE"); sub: T.t("UTILISÉE ") + root.human(root.memTotal - root.memAvail) + T.t(" SUR ") + root.human(root.memTotal) }
          // Grille de points : pleins = utilisés.
          Grid {
            id: dots
            columns: 40
            readonly property real cell: leftCol.width / 40
            readonly property int used: root.memTotal > 0 ? Math.round(160 * (1 - root.memAvail / root.memTotal)) : 0
            Repeater {
              model: 160
              Item {
                required property int index
                width: dots.cell; height: dots.cell
                Rectangle { anchors.centerIn: parent; width: Math.max(2, dots.cell * 0.45); height: width; color: index < dots.used ? root.acc : root.faint }
              }
            }
          }
          Row {
            width: leftCol.width; spacing: Math.round(6 * root.k)
            Label { text: "SWAP"; width: Math.round(34 * root.k) }
            Rectangle {
              anchors.verticalCenter: parent.verticalCenter
              width: leftCol.width - Math.round(100 * root.k); height: Math.round(5 * root.k); color: "transparent"; border.color: root.dim; border.width: 1
              Rectangle { width: parent.width * (root.swapTotal > 0 ? 1 - root.swapFree / root.swapTotal : 0); height: parent.height; color: root.acc }
            }
            Label { text: root.human(root.swapTotal - root.swapFree); color: root.dim }
          }
        }
      }

      Reveal {
        at: 1950; width: leftCol.width; height: procCol.implicitHeight
        Column {
          id: procCol
          width: leftCol.width; spacing: 1
          Head { title: T.t("PROCESSUS"); sub: "PID  NOM  CPU  MEM" }
          Repeater {
            model: root.procs
            Row {
              required property var modelData
              width: leftCol.width
              Label { width: leftCol.width * 0.18; text: modelData.pid; color: root.dim }
              Label { width: leftCol.width * 0.5; text: modelData.name }
              Label { width: leftCol.width * 0.16; text: modelData.cpu + "%"; horizontalAlignment: Text.AlignRight }
              Label { width: leftCol.width * 0.16; text: modelData.mem + "%"; horizontalAlignment: Text.AlignRight; color: root.dim }
            }
          }
        }
      }
    }

    // ---------------- colonne droite
    Column {
      id: rightCol
      x: root.sw - root.pad - root.colW; y: root.pad
      width: root.colW
      spacing: Math.round(8 * root.k)

      // Barre plate : disposition du clavier, réseau, batterie, heure, applications, alimentation.
      Reveal {
        at: 1100; width: rightCol.width; height: Math.round(22 * root.k)
        Rectangle {
          id: strip
          width: rightCol.width; height: Math.round(22 * root.k)
          color: "transparent"; border.color: root.dim; border.width: 1
          Row {
            anchors.verticalCenter: parent.verticalCenter; x: Math.round(6 * root.k)
            spacing: Math.round(9 * root.k)
            Label { text: "⌨ " + String(root.s ? (root.s.layout || "fr") : "fr").slice(0, 2).toUpperCase() }
            Label { text: root.iface !== "" ? "◉ " + T.t("EN LIGNE") : "○ " + T.t("HORS LIGNE"); color: root.iface !== "" ? root.acc : root.dim }
            Label { visible: !!root.s && root.s.batteryPct >= 0; text: (root.s && root.s.charging ? "⚡" : "▮") + (root.s ? root.s.batteryPct : 0) + "%" }
            Label { text: Qt.formatTime(desk.now, "HH:mm") }
          }
          Row {
            anchors.right: parent.right; anchors.rightMargin: Math.round(4 * root.k); anchors.verticalCenter: parent.verticalCenter
            spacing: Math.round(4 * root.k)
            Repeater {
              model: [["▦", "apps"], ["⏻", "power"]]
              Rectangle {
                required property var modelData
                width: Math.round(16 * root.k); height: width; color: btn.containsMouse ? root.acc : "transparent"; border.color: root.dim; border.width: 1
                Label { anchors.centerIn: parent; text: modelData[0]; color: btn.containsMouse ? "black" : root.acc }
                MouseArea { id: btn; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                            onClicked: modelData[1] === "apps" ? root.s.toggleLauncher() : root.s.powerMenu() }
              }
            }
          }
        }
      }

      Reveal {
        at: 1350; width: rightCol.width; height: netCol.implicitHeight
        Column {
          id: netCol
          width: rightCol.width; spacing: Math.round(4 * root.k)
          Head { title: T.t("ÉTAT DU RÉSEAU"); sub: root.iface !== "" ? T.t("Interface : ") + root.iface : "" }
          Row {
            spacing: Math.round(16 * root.k)
            Stat { key: T.t("ÉTAT"); val: root.iface !== "" ? T.t("EN LIGNE") : T.t("HORS LIGNE") }
            Stat { key: "IPv4"; val: root.ipv4 || "—" }
            Stat { key: "PING"; val: root.ping >= 0 ? root.ping + "ms" : "—" }
          }
        }
      }

      Reveal {
        visible: !root.s || root.s.opt("hud_globe", true) !== false
        at: 1600; width: rightCol.width; height: Math.round(150 * root.k)
        Column {
          width: rightCol.width; spacing: Math.round(2 * root.k)
          Head { title: T.t("VUE DU MONDE"); sub: T.t("CONNEXIONS") }
          // Globe en fil de fer, terres en points ; il tourne lentement.
          Canvas {
            id: globe
            width: rightCol.width; height: Math.round(130 * root.k)
            property real spin: 0
            // 1437 points redessinés : 8 images/s au lieu de 60 (le globe tourne lentement).
            Timer { interval: 125; repeat: true; running: root.live && globe.visible; onTriggered: globe.spin = (globe.spin + 0.75) % 360 }
            onSpinChanged: requestPaint()
            readonly property var here: root.s && root.s.coords ? [Number(root.s.coords.lon), Number(root.s.coords.lat)] : [2.35, 48.85]
            onPaint: {
              var c = getContext("2d"), w = width, h = height, R = Math.min(w, h) / 2 - 3, cx = w / 2, cy = h / 2
              var tilt = 0.35, rad = Math.PI / 180, lon0 = -spin
              c.reset()
              c.strokeStyle = root.dim; c.lineWidth = 1
              c.beginPath(); c.arc(cx, cy, R, 0, 2 * Math.PI); c.stroke()
              function proj(lon, lat) {
                var l = (lon - lon0) * rad, p = lat * rad
                var x = Math.cos(p) * Math.sin(l), y = Math.sin(p), z = Math.cos(p) * Math.cos(l)
                var y2 = y * Math.cos(tilt) - z * Math.sin(tilt), z2 = y * Math.sin(tilt) + z * Math.cos(tilt)
                return [cx + R * x, cy - R * y2, z2]
              }
              // Méridiens et parallèles (face visible).
              c.strokeStyle = root.faint
              for (var m = -180; m < 180; m += 30) {
                c.beginPath(); var st = false
                for (var la = -90; la <= 90; la += 6) { var q = proj(m, la); if (q[2] > 0) { if (!st) { c.moveTo(q[0], q[1]); st = true } else c.lineTo(q[0], q[1]) } else st = false }
                c.stroke()
              }
              for (var pa = -60; pa <= 60; pa += 30) {
                c.beginPath(); var st2 = false
                for (var lo = -180; lo <= 180; lo += 6) { var q2 = proj(lo, pa); if (q2[2] > 0) { if (!st2) { c.moveTo(q2[0], q2[1]); st2 = true } else c.lineTo(q2[0], q2[1]) } else st2 = false }
                c.stroke()
              }
              // Terres.
              c.fillStyle = root.acc
              var pts = Land.points, sz = Math.max(1.4, R / 42)
              for (var i = 0; i < pts.length; i++) {
                var g = proj(pts[i][0], pts[i][1])
                if (g[2] > 0.05) { c.globalAlpha = 0.25 + 0.6 * g[2]; c.fillRect(g[0] - sz / 2, g[1] - sz / 2, sz, sz) }
              }
              c.globalAlpha = 1
              // Ici : point qui pulse.
              var me = proj(here[0], here[1])
              if (me[2] > 0) {
                var pulse = (spin * 6) % 1
                c.strokeStyle = root.acc; c.globalAlpha = 1 - pulse
                c.beginPath(); c.arc(me[0], me[1], 3 + 9 * pulse, 0, 2 * Math.PI); c.stroke()
                c.globalAlpha = 1; c.fillStyle = root.acc; c.beginPath(); c.arc(me[0], me[1], 2.5, 0, 2 * Math.PI); c.fill()
              }
            }
          }
        }
      }

      Reveal {
        at: 1850; width: rightCol.width; height: trafCol.implicitHeight
        Column {
          id: trafCol
          width: rightCol.width; spacing: Math.round(3 * root.k)
          Head { title: T.t("TRAFIC RÉSEAU"); sub: "↓ " + root.human(root.rx) + "/s  ↑ " + root.human(root.tx) + "/s" }
          Graph { width: rightCol.width; height: Math.round(58 * root.k); vals: root.histRx; vals2: root.histTx; maxV: 0 }
          Label { text: T.t("TOTAL  ↓ ") + root.human(root.rxTotal) + "  ↑ " + root.human(root.txTotal); color: root.dim }
        }
      }
    }

    // ---------------- en bas à gauche : dossiers
    Reveal {
      visible: !root.s || root.s.opt("hud_files", true) !== false
      at: 2300; dur: 500
      x: root.pad; y: root.sh - root.bottomH - root.pad + Math.round(8 * root.k)
      width: Math.round((root.sw - 3 * root.pad) * 0.44); height: root.bottomH
      Item {
        id: fsPanel
        width: parent.width; height: parent.height
        property int scroll: 0
        readonly property int cols: 7
        readonly property real cellW: width / cols
        readonly property real cellH: Math.round(52 * root.k)
        readonly property int rows: Math.max(1, Math.floor((height - Math.round(22 * root.k)) / cellH))
        Head { title: T.t("FICHIERS"); sub: Quickshell.env("HOME") || "~" }
        Grid {
          y: Math.round(20 * root.k)
          columns: fsPanel.cols
          Repeater {
            model: root.files.slice(fsPanel.scroll * fsPanel.cols, (fsPanel.scroll + fsPanel.rows) * fsPanel.cols)
            Item {
              id: fi
              required property var modelData
              readonly property bool dir: String(modelData).slice(-1) === "/"
              readonly property string nm: dir ? String(modelData).slice(0, -1) : String(modelData)
              readonly property string ext: nm.indexOf(".") > 0 ? nm.split(".").pop().toLowerCase() : ""
              width: fsPanel.cellW; height: fsPanel.cellH
              Rectangle { anchors.fill: parent; anchors.margins: 1; color: fma.containsMouse ? root.faint : "transparent" }
              Text {
                anchors.horizontalCenter: parent.horizontalCenter; y: Math.round(4 * root.k)
                text: fi.dir ? "folder" : (["png", "jpg", "jpeg", "webp", "gif"].indexOf(fi.ext) >= 0 ? "image"
                      : ["mp4", "mkv", "webm", "mov"].indexOf(fi.ext) >= 0 ? "movie" : ["mp3", "flac", "ogg", "wav"].indexOf(fi.ext) >= 0 ? "music_note"
                      : ["sh", "py", "js", "qml", "lua", "c", "rs"].indexOf(fi.ext) >= 0 ? "code" : "description")
                font.family: "Material Symbols Rounded"; font.pixelSize: Math.round(24 * root.k); color: root.acc
              }
              Label {
                anchors.horizontalCenter: parent.horizontalCenter; y: Math.round(32 * root.k)
                width: parent.width - 4; horizontalAlignment: Text.AlignHCenter
                text: fi.nm; font.pixelSize: Math.max(7, Math.round(8 * root.k))
              }
              MouseArea { id: fma; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                          onClicked: Quickshell.execDetached(["xdg-open", (Quickshell.env("HOME") || "") + "/" + fi.nm]) }
            }
          }
        }
        WheelHandler {
          onWheel: function(e) {
            var maxS = Math.max(0, Math.ceil(root.files.length / fsPanel.cols) - fsPanel.rows)
            fsPanel.scroll = Math.max(0, Math.min(maxS, fsPanel.scroll + (e.angleDelta.y < 0 ? 1 : -1)))
          }
        }
      }
    }

    // ---------------- en bas à droite : clavier
    Reveal {
      visible: !root.s || root.s.opt("hud_keyboard", true) !== false
      at: 700; dur: 600
      x: root.pad * 2 + Math.round((root.sw - 3 * root.pad) * 0.44); y: root.sh - root.bottomH - root.pad + Math.round(8 * root.k)
      width: root.sw - x - root.pad; height: root.bottomH
      Item {
        id: kbPanel
        width: parent.width; height: parent.height
        readonly property string lay: String(root.s ? root.s.layout : "fr").toLowerCase()
        // Suisse romande (ch) et allemand : QWERTZ ; français : AZERTY ; sinon QWERTY.
        readonly property string kind: lay.indexOf("ch") === 0 || lay.indexOf("de") === 0 || lay.indexOf("swiss") >= 0 ? "qwertz"
                                     : lay.indexOf("fr") === 0 ? "azerty" : "qwerty"
        readonly property var rows: kind === "qwertz"
          ? [["ESC", "§", "1", "2", "3", "4", "5", "6", "7", "8", "9", "0", "'", "^", "⌫"],
             ["TAB", "Q", "W", "E", "R", "T", "Z", "U", "I", "O", "P", "è", "¨", "↵"],
             ["CAPS", "A", "S", "D", "F", "G", "H", "J", "K", "L", "é", "à", "$"],
             ["SHIFT", "<", "Y", "X", "C", "V", "B", "N", "M", ",", ".", "-", "SHIFT"],
             ["CTRL", "FN", "⌘", "ALT", " ", "ALT GR", "CTRL", "←", "↓", "→"]]
          : kind === "azerty"
          ? [["ESC", "²", "&", "é", "\"", "'", "(", "-", "è", "_", "ç", "à", ")", "=", "⌫"],
             ["TAB", "A", "Z", "E", "R", "T", "Y", "U", "I", "O", "P", "^", "$", "↵"],
             ["CAPS", "Q", "S", "D", "F", "G", "H", "J", "K", "L", "M", "ù", "*"],
             ["SHIFT", "<", "W", "X", "C", "V", "B", "N", ",", ";", ":", "!", "SHIFT"],
             ["CTRL", "FN", "⌘", "ALT", " ", "ALT GR", "CTRL", "←", "↓", "→"]]
          : [["ESC", "`", "1", "2", "3", "4", "5", "6", "7", "8", "9", "0", "-", "=", "⌫"],
             ["TAB", "Q", "W", "E", "R", "T", "Y", "U", "I", "O", "P", "[", "]", "↵"],
             ["CAPS", "A", "S", "D", "F", "G", "H", "J", "K", "L", ";", "'", "\\"],
             ["SHIFT", "\\", "Z", "X", "C", "V", "B", "N", "M", ",", ".", "/", "SHIFT"],
             ["CTRL", "FN", "⌘", "ALT", " ", "ALT GR", "CTRL", "←", "↓", "→"]]
        // Chaque rangée remplit toute la largeur, quelles que soient ses touches.
        function unitFor(row) { var u = 0; for (var i = 0; i < row.length; i++) u += wide(row[i]); return (width - 2 * (row.length - 1)) / u }
        readonly property real keyH: (height - Math.round(26 * root.k)) / 5
        function wide(lbl) { return ({ "ESC": 1.2, "⌫": 1.6, "TAB": 1.5, "↵": 1.3, "CAPS": 1.8, "SHIFT": 2.1, "CTRL": 1.3, " ": 5.4, "ALT GR": 1.4 })[lbl] || 1 }
        Head { title: T.t("CLAVIER"); sub: kbPanel.kind.toUpperCase() + " · " + kbPanel.lay.slice(0, 2).toUpperCase() }
        Column {
          y: Math.round(20 * root.k)
          spacing: 2
          Repeater {
            model: kbPanel.rows
            Row {
              id: krow
              required property var modelData
              required property int index
              readonly property real unit: kbPanel.unitFor(modelData)
              spacing: 2
              Repeater {
                model: krow.modelData
                Rectangle {
                  id: key
                  required property var modelData
                  width: krow.unit * kbPanel.wide(modelData); height: kbPanel.keyH - 2
                  radius: Math.round(2 * root.k)
                  color: kma.pressed ? root.acc : (kma.containsMouse ? root.faint : "transparent")
                  border.color: modelData.length > 1 || modelData === " " ? root.dim : Qt.rgba(root.acc.r, root.acc.g, root.acc.b, 0.3); border.width: 1
                  Label {
                    anchors.centerIn: parent
                    text: key.modelData; color: kma.pressed ? "black" : root.acc
                    font.pixelSize: key.modelData.length > 1 ? Math.max(7, Math.round(8 * root.k)) : Math.max(8, Math.round(11 * root.k))
                  }
                  MouseArea { id: kma; anchors.fill: parent; hoverEnabled: true }
                }
              }
            }
          }
        }
      }
    }
  }
}
