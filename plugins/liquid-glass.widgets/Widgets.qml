import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris
import qs.Commons
import qs.Commons as Commons
import qs.Ui

// Liquid Glass — widgets du bureau façon macOS (Sonoma/Tahoe).
//
// Un service qui tient les données (config, météo, lecture en cours) et pose une
// fenêtre « Bottom » (au-dessus du fond, sous les fenêtres) sur l'écran principal.
// Réglages : [widgets] dans config.toml (Réglages → Widgets).
// Météo : Open-Meteo (gratuit, sans clé), HTTPS, ville géocodée une fois.
Item {
  id: svc
  property var shell: null
  property var manifest: null

  readonly property string home: Quickshell.env("HOME")
  property var cfg: ({})
  readonly property var wcfg: cfg.widgets || ({})
  function opt(k, d) { return wcfg.hasOwnProperty(k) ? wcfg[k] : d }

  readonly property bool enabled: opt("enabled", true) !== false
  readonly property string side: opt("position", "left")
  readonly property bool showClock: opt("clock", true) !== false
  readonly property bool showCalendar: opt("calendar", true) !== false
  readonly property bool showWeather: opt("weather", true) !== false
  readonly property bool showBattery: opt("battery", true) !== false
  readonly property bool showMusic: opt("music", true) !== false
  readonly property bool hideOnCover: opt("hide_on_cover", true) !== false
  // Widget musique libre : position (9 ancres) et taille (small | medium | large).
  readonly property string musicPosition: String(opt("music_position", "bottom-left"))
  readonly property string musicSize: String(opt("music_size", "medium"))
  // Bas de la colonne des widgets fixes (posé par DesktopWidgets), pour ne pas la chevaucher.
  property real flowBottom: 0

  // Écrit une option [widgets] (relue à chaud via config.json).
  function setOption(key, value) {
    Quickshell.execDetached(["liquid-glass", "set", "widgets." + key, String(value)])
  }
  readonly property string uiFont: (cfg.appearance && cfg.appearance.font_ui) || "Inter"
  readonly property bool dark: Commons.Color.background.hslLightness < 0.5

  FileView {
    path: svc.home + "/.config/liquid-glass/config.json"
    watchChanges: true
    onFileChanged: reload()
    onLoaded: { try { svc.cfg = JSON.parse(text()) } catch (e) {} }
  }

  // ---------------------------------------------------------- lecture en cours
  // Données de pochette/palette publiées par liquid-glass.spotify.
  property var np: ({})
  FileView {
    path: svc.home + "/.cache/liquid-glass/now-playing.json"
    watchChanges: true
    printErrors: false
    onFileChanged: reload()
    onLoaded: { try { svc.np = JSON.parse(text()) } catch (e) {} }
  }
  readonly property bool coverWallpaper: np.coverWallpaper === true

  function isSpotify(p) {
    var id = String((p.identity || "") + " " + (p.desktopEntry || "") + " " + (p.dbusName || "")).toLowerCase()
    return id.indexOf("spotify") !== -1
  }
  readonly property var player: {
    var ps = Mpris.players ? Mpris.players.values : []
    var spotify = null, playing = null
    for (var i = 0; i < ps.length; i++) {
      if (!spotify && isSpotify(ps[i])) spotify = ps[i]
      if (!playing && ps[i].isPlaying) playing = ps[i]
    }
    return spotify || playing || (ps.length ? ps[0] : null)
  }
  readonly property bool hasTrack: !!player && (player.trackTitle || "") !== ""
  // La pochette en cache n'est valable que si elle correspond au morceau affiché.
  readonly property string coverSource: {
    if (!hasTrack) return ""
    if (np.title === player.trackTitle && np.cover) return "file://" + np.cover
    return player.trackArtUrl || ""
  }
  readonly property var palette: hasTrack && np.title === player.trackTitle ? (np.palette || null) : null

  // ------------------------------------------------------------------ météo
  property var weather: null        // { temp, code, isDay, max, min, city }
  property string weatherError: ""
  property var coords: null
  readonly property string city: {
    var c = String(opt("weather_city", "")).trim()
    if (c !== "") return c
    // Par défaut : la ville du fuseau horaire (Europe/Paris → Paris).
    var tz = String(svc.timezone || "")
    return tz.indexOf("/") !== -1 ? tz.split("/").pop().replace(/_/g, " ") : "Paris"
  }
  property string timezone: ""
  Process {
    command: ["timedatectl", "show", "-p", "Timezone", "--value"]
    running: true
    stdout: StdioCollector { onStreamFinished: svc.timezone = text.trim() }
  }
  onCityChanged: { coords = null; weatherDebounce.restart() }
  onShowWeatherChanged: if (showWeather) weatherDebounce.restart()

  Timer { id: weatherDebounce; interval: 1500; onTriggered: svc.refreshWeather() }
  Timer { interval: 30 * 60 * 1000; repeat: true; running: svc.enabled && svc.showWeather; onTriggered: svc.refreshWeather() }

  function refreshWeather() {
    if (!enabled || !showWeather || city === "" || geo.running || forecast.running) return
    if (!coords) {
      geo.command = ["curl", "-fsS", "--proto", "=https", "--max-time", "10", "--max-filesize", "200000",
                     "https://geocoding-api.open-meteo.com/v1/search?count=1&language=fr&format=json&name=" + encodeURIComponent(city)]
      geo.running = true
      return
    }
    forecast.command = ["curl", "-fsS", "--proto", "=https", "--max-time", "10", "--max-filesize", "200000",
                        "https://api.open-meteo.com/v1/forecast?latitude=" + coords.lat + "&longitude=" + coords.lon
                        + "&current=temperature_2m,weather_code,is_day&daily=temperature_2m_max,temperature_2m_min&forecast_days=1&timezone=auto"]
    forecast.running = true
  }
  Process {
    id: geo
    stdout: StdioCollector {
      onStreamFinished: {
        try {
          var r = JSON.parse(text).results[0]
          svc.coords = { lat: Number(r.latitude).toFixed(3), lon: Number(r.longitude).toFixed(3), name: String(r.name) }
          svc.refreshWeather()
        } catch (e) { svc.weatherError = "Ville introuvable" }
      }
    }
  }
  Process {
    id: forecast
    stdout: StdioCollector {
      onStreamFinished: {
        try {
          var j = JSON.parse(text)
          svc.weather = {
            temp: Math.round(j.current.temperature_2m), code: j.current.weather_code, isDay: j.current.is_day === 1,
            max: Math.round(j.daily.temperature_2m_max[0]), min: Math.round(j.daily.temperature_2m_min[0]),
            city: svc.coords ? svc.coords.name : svc.city
          }
          svc.weatherError = ""
        } catch (e) { svc.weatherError = "Météo indisponible" }
      }
    }
  }
  Component.onCompleted: weatherDebounce.restart()

  // Écran principal seulement (comme les widgets de macOS).
  Variants {
    model: svc.enabled && Quickshell.screens.length ? [Quickshell.screens[0]] : []
    delegate: Component {
      DesktopWidgets {
        required property var modelData
        screen: modelData
        service: svc
      }
    }
  }
  Variants {
    model: svc.enabled && Quickshell.screens.length ? [Quickshell.screens[0]] : []
    delegate: Component {
      MusicWindow {
        required property var modelData
        screen: modelData
        service: svc
      }
    }
  }

  ShellIpc {
    target: "liquid-glass.widgets"
    function status(): string { return JSON.stringify({ enabled: svc.enabled, city: svc.city, weather: svc.weather, error: svc.weatherError, hasTrack: svc.hasTrack, coverWallpaper: svc.coverWallpaper }) }
    function refresh(): void { svc.coords = null; svc.refreshWeather() }
  }
}
