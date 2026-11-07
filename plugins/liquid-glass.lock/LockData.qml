import QtQuick
import Quickshell
import Quickshell.Io

// Mesures pour les écrans de verrouillage qui en affichent (processeur, mémoire,
// température, disque, batterie, réseau), la météo copiée par le bureau Linux et
// les dernières notifications. Une seule commande fixe, toutes les 2 s.
Item {
  id: d
  property bool running: true
  readonly property string home: Quickshell.env("HOME")

  property real cpu: 0
  property real memPct: 0
  property real memUsed: 0          // Gio
  property real memTotal: 0
  property int temp: 0
  property real diskPct: 0
  property real diskUsed: 0         // Gio
  property real diskTotal: 0
  property int battery: -1
  property bool charging: false
  property real up: 0               // octets/s
  property real down: 0
  property string uptime: ""
  property var weather: null
  property var notifs: []

  property var _cpuPrev: null
  property var _netPrev: null

  function human(b) {
    if (b > 1048576) return (b / 1048576).toFixed(1) + " M/s"
    if (b > 1024) return Math.round(b / 1024) + " K/s"
    return Math.round(b) + " B/s"
  }

  Process {
    id: probe
    command: ["sh", "-c", "head -1 /proc/stat; grep -E '^(MemTotal|MemAvailable):' /proc/meminfo;"
      + " echo T $(cat /sys/class/thermal/thermal_zone*/temp 2>/dev/null | sort -n | tail -1);"
      + " echo D $(df -B1 / | tail -1);"
      + " echo B $(cat /sys/class/power_supply/BAT*/capacity 2>/dev/null | head -1) $(cat /sys/class/power_supply/BAT*/status 2>/dev/null | head -1);"
      + " echo N $(awk 'NR>2 && $1 !~ /^lo:/ {r+=$2; t+=$10} END {print r, t}' /proc/net/dev);"
      + " echo U $(cut -d. -f1 /proc/uptime)"]
    stdout: StdioCollector {
      onStreamFinished: {
        var memT = 0, memA = 0
        text.split("\n").forEach(function(l) {
          var f = l.trim().split(/\s+/)
          if (f[0] === "cpu") {
            var n = f.slice(1).map(Number), idle = n[3] + (n[4] || 0), tot = n.reduce(function(a, b) { return a + b }, 0)
            if (d._cpuPrev) { var dt = tot - d._cpuPrev[1]; if (dt > 0) d.cpu = 1 - (idle - d._cpuPrev[0]) / dt }
            d._cpuPrev = [idle, tot]
          } else if (f[0] === "MemTotal:") memT = Number(f[1])
          else if (f[0] === "MemAvailable:") memA = Number(f[1])
          else if (f[0] === "T" && f[1]) d.temp = Math.round(Number(f[1]) / 1000)
          else if (f[0] === "D" && f.length > 4) {
            d.diskTotal = Number(f[2]) / 1073741824; d.diskUsed = Number(f[3]) / 1073741824
            d.diskPct = d.diskTotal > 0 ? d.diskUsed / d.diskTotal : 0
          } else if (f[0] === "B") {
            d.battery = f[1] !== undefined && f[1] !== "" ? Number(f[1]) : -1
            d.charging = f[2] === "Charging" || f[2] === "Full"
          } else if (f[0] === "N" && f.length > 2) {
            var now = Date.now(), rx = Number(f[1]), tx = Number(f[2])
            if (d._netPrev) { var s = (now - d._netPrev[2]) / 1000; if (s > 0) { d.down = Math.max(0, (rx - d._netPrev[0]) / s); d.up = Math.max(0, (tx - d._netPrev[1]) / s) } }
            d._netPrev = [rx, tx, now]
          } else if (f[0] === "U") {
            var u = Number(f[1]), h = Math.floor(u / 3600), m = Math.floor(u % 3600 / 60)
            d.uptime = h > 0 ? h + " h " + m + " min" : m + " min"
          }
        })
        if (memT > 0) { d.memTotal = memT / 1048576; d.memUsed = (memT - memA) / 1048576; d.memPct = (memT - memA) / memT }
      }
    }
  }
  Timer { interval: 2000; repeat: true; running: d.running; triggeredOnStart: true; onTriggered: probe.running = true }

  FileView {
    path: d.home + "/.cache/liquid-glass/weather.json"
    watchChanges: true; printErrors: false
    onFileChanged: reload()
    onLoaded: { try { d.weather = JSON.parse(text()) } catch (e) {} }
  }
  FileView {
    path: d.home + "/.local/state/omarchy/notifications/history.json"
    watchChanges: true; printErrors: false
    onFileChanged: reload()
    onLoaded: { try { var j = JSON.parse(text()); d.notifs = (Array.isArray(j) ? j : (j.notifications || [])).slice(0, 12) } catch (e) {} }
  }

  // Code WMO → [libellé, icône (jour), icône (nuit)], comme sur le bureau.
  function weatherInfo(code) {
    var c = Number(code)
    if (c === 0) return ["ciel dégagé", "clear_day", "clear_night"]
    if (c <= 2) return ["quelques nuages", "partly_cloudy_day", "partly_cloudy_night"]
    if (c === 3) return ["couvert", "cloud", "cloud"]
    if (c <= 48) return ["brouillard", "foggy", "foggy"]
    if (c <= 57) return ["bruine", "rainy_light", "rainy_light"]
    if (c <= 67) return ["pluie", "rainy", "rainy"]
    if (c <= 77) return ["neige", "weather_snowy", "weather_snowy"]
    if (c <= 82) return ["averses", "rainy_heavy", "rainy_heavy"]
    if (c <= 86) return ["averses de neige", "weather_snowy", "weather_snowy"]
    return ["orages", "thunderstorm", "thunderstorm"]
  }
  readonly property string wDesc: weather ? weatherInfo(weather.code)[0] : ""
  readonly property string wIcon: weather ? weatherInfo(weather.code)[weather.isDay ? 1 : 2] : "cloud_off"
  function ago(ts) {
    var t = typeof ts === "number" ? (ts > 1e12 ? ts : ts * 1000) : Date.parse(ts)
    if (!t) return ""
    var m = Math.round((Date.now() - t) / 60000)
    return m < 1 ? "now" : m < 60 ? m + "m" : m < 1440 ? Math.round(m / 60) + "h" : Math.round(m / 1440) + "d"
  }
}
