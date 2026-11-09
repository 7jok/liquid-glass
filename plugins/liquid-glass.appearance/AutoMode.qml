import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons

// Liquid Glass — mode clair/sombre automatique.
// Vérifie chaque minute, dans le shell déjà lancé (pas de service système) :
// si appearance.mode = "auto" et que le thème courant ne correspond pas à
// l'heure, lance `liquid-glass auto-tick` (qui fait la bascule). Sinon, rien.
Item {
  id: root
  property var shell: null
  property var manifest: null

  readonly property string home: Quickshell.env("HOME")
  property var cfg: ({})
  property string theme: ""

  FileView {
    path: root.home + "/.config/liquid-glass/config.json"
    watchChanges: true
    onFileChanged: reload()
    onLoaded: { try { root.cfg = JSON.parse(text()); root.check() } catch (e) {} }
  }
  FileView {
    path: root.home + "/.local/state/omarchy/current/theme.name"
    watchChanges: true
    onFileChanged: reload()
    onLoaded: { root.theme = text().trim(); root.check() }
  }

  function minutes(hhmm, def) {
    var m = /^(\d{1,2}):(\d{2})$/.exec(String(hhmm || def))
    return m ? parseInt(m[1]) * 60 + parseInt(m[2]) : minutes(def, "07:30")
  }

  // Fond dynamique (Réglages → Fond d'écran → Bureau dynamique) : vérifié chaque minute.
  Process { id: dynTick; command: ["liquid-glass", "dynamic-wallpaper", "tick"] }
  function check() {
    if (cfg.wallpaper && cfg.wallpaper.dynamic && !dynTick.running) dynTick.running = true
    var ap = cfg.appearance || {}
    if (ap.mode !== "auto" || theme === "") return
    // Seulement nos deux thèmes : un autre thème choisi à la main est respecté.
    if (theme !== "liquid-glass" && theme !== "liquid-glass-dark") return
    var now = new Date()
    var t = now.getHours() * 60 + now.getMinutes()
    var light = minutes(ap.auto_light_at, "07:30"), dark = minutes(ap.auto_dark_at, "19:30")
    var wantLight = light <= dark ? (t >= light && t < dark) : (t >= light || t < dark)
    var want = wantLight ? "liquid-glass" : "liquid-glass-dark"
    if (want !== theme && !tick.running) tick.running = true
  }

  Process { id: tick; command: ["liquid-glass", "auto-tick"] }

  // ---------------------------------------------------------------------------
  // Barre des menus transparente (Tahoe) : la couleur du texte suit le fond
  // affiché (fond du thème, ou pochette Spotify en fond d'écran) : sombre sur
  // un fond clair, blanc sur un fond sombre. `liquid-glass bar-contrast` mesure
  // la bande du haut de l'image et recharge le thème à chaud.
  property string themeWall: ""
  property var np: ({})
  FileView {
    path: root.home + "/.cache/liquid-glass/now-playing.json"
    watchChanges: true
    printErrors: false
    onFileChanged: reload()
    onLoaded: { try { root.np = JSON.parse(text()) } catch (e) {} }
  }
  readonly property string shownWall: np.coverWallpaper === true && String(np.wallpaper || "") !== "" ? String(np.wallpaper) : themeWall
  property string measuredWall: ""
  onShownWallChanged: contrastDebounce.restart()
  Timer {
    id: contrastDebounce
    interval: 1200
    onTriggered: {
      if (root.shownWall === "" || root.shownWall === root.measuredWall || contrast.running) return
      root.measuredWall = root.shownWall
      contrast.command = ["liquid-glass", "bar-contrast", root.shownWall]
      contrast.running = true
    }
  }
  Process { id: contrast }
  Process {
    id: wallQuery
    command: ["readlink", "-f", root.home + "/.local/state/omarchy/current/background"]
    stdout: StdioCollector { onStreamFinished: { var t = text.trim(); if (t !== "") root.themeWall = t } }
  }
  Timer { interval: 4000; repeat: true; running: true; triggeredOnStart: true; onTriggered: wallQuery.running = true }

  Timer { interval: 60000; repeat: true; running: true; onTriggered: root.check() }
}
