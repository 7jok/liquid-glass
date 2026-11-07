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
  // Incrémenté par l IPC musicArt : MusicWindow bascule la pochette agrandie.
  property int artRequest: 0
  property var cfg: ({})
  readonly property var wcfg: cfg.widgets || ({})
  function opt(k, d) { return wcfg.hasOwnProperty(k) ? wcfg[k] : d }

  readonly property bool enabled: opt("enabled", true) !== false
  readonly property string side: opt("position", "left")
  readonly property bool showClock: opt("clock", true) !== false
  readonly property bool showCalendar: opt("calendar", true) !== false
  readonly property bool showWeather: opt("weather", true) !== false
  // digital (chiffres en verre) | analog (cadran)
  readonly property string clockStyle: String(opt("clock_style", "digital"))
  // wide (avec prévisions heure par heure) | small
  readonly property string weatherSize: String(opt("weather_size", "wide"))
  readonly property bool showBattery: opt("battery", true) !== false
  // Tailles façon macOS : small (1×1), medium (2×1), large (2×2), xl (4×2).
  // Clé « <widget>_size » ; la météo garde son ancienne valeur « wide » = medium.
  readonly property var sizeNames: ["small", "medium", "large", "xl"]
  function sizeOf(key) {
    var def = key === "weather" ? "medium" : "small"
    var v = String(opt(key + "_size", def))
    if (v === "wide") v = "medium"
    return sizeNames.indexOf(v) >= 0 ? v : def
  }
  function setSize(key, size) { setOption(key + "_size", size); editTimer.restart() }
  readonly property bool showMusic: opt("music", true) !== false
  readonly property bool hideOnCover: opt("hide_on_cover", true) !== false
  // Widget musique libre : position en fractions de l'écran (-1 = pas encore
  // posé, on part de l'ancienne ancre music_position) et taille.
  readonly property string musicPosition: String(opt("music_position", "bottom-left"))
  readonly property real musicX: Number(opt("music_x", -1))
  readonly property real musicY: Number(opt("music_y", -1))
  readonly property string musicSize: String(opt("music_size", "medium"))
  // Bas de la colonne des widgets fixes (posé par DesktopWidgets), pour ne pas la chevaucher.
  property real flowBottom: 0
  // Rectangle occupé par la colonne de widgets (repère sous la barre), pour que
  // la pochette agrandie du widget musique ne se cache pas derrière.
  property rect flowRect: Qt.rect(0, 0, 0, 0)

  // Mode édition (appui long sur un widget) : tremblement + « − ». Se termine avec
  // « Terminé » ou tout seul après 12 s sans rien toucher.
  property bool editing: false
  function startEditing() { editing = true; editTimer.restart() }
  function stopEditing() { editing = false; editTimer.stop() }
  function removeWidget(key) { if (key) setOption(key, false); editTimer.restart() }
  Timer { id: editTimer; interval: 12000; onTriggered: svc.editing = false }

  // Écrit une option [widgets] (relue à chaud via config.json).
  function setOption(key, value) {
    Quickshell.execDetached(["liquid-glass", "set", "widgets." + key, String(value)])
  }
  // Plusieurs options d'un coup (une seule écriture de config.toml).
  function setOptions(obj) {
    var a = ["liquid-glass", "set"]
    for (var k in obj) a.push("widgets." + k, String(obj[k]))
    Quickshell.execDetached(a)
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
  // Paroles en grand sur le fond d'écran ([lyrics] desktop, liquid-glass.spotify).
  readonly property bool lyricsDesktop: !!(cfg.lyrics && cfg.lyrics.desktop === true)

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
    // Uniquement des fichiers locaux (voir ControlCenter : crash OpenSSL).
    var a = String(player.trackArtUrl || "")
    return a.indexOf("file://") === 0 ? a : ""
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
                        + "&current=temperature_2m,weather_code,is_day&daily=temperature_2m_max,temperature_2m_min&forecast_days=2"
                        + "&hourly=temperature_2m,weather_code,is_day&forecast_hours=7&timezone=auto"]
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
          var hours = [{ h: -1, temp: Math.round(j.current.temperature_2m), code: j.current.weather_code, isDay: j.current.is_day === 1 }]
          if (j.hourly && j.hourly.time) {
            for (var i = 1; i < j.hourly.time.length && hours.length < 5; i++)
              hours.push({ h: parseInt(String(j.hourly.time[i]).slice(11, 13)), temp: Math.round(j.hourly.temperature_2m[i]),
                           code: j.hourly.weather_code[i], isDay: j.hourly.is_day[i] === 1 })
          }
          svc.weather = {
            temp: Math.round(j.current.temperature_2m), code: j.current.weather_code, isDay: j.current.is_day === 1, hourly: hours,
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
    function edit(): void { svc.startEditing() }
    function done(): void { svc.stopEditing() }
    // Pochette du widget musique agrandie au-dessus de la carte (comme un clic dessus).
    function musicArt(): void { svc.artRequest++ }
  }
}
