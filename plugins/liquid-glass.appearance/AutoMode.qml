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
    onLoaded: root.theme = text().trim()
  }

  function minutes(hhmm, def) {
    var m = /^(\d{1,2}):(\d{2})$/.exec(String(hhmm || def))
    return m ? parseInt(m[1]) * 60 + parseInt(m[2]) : minutes(def, "07:30")
  }

  function check() {
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

  Timer { interval: 60000; repeat: true; running: true; onTriggered: root.check() }
}
