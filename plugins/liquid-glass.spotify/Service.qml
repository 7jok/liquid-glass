import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.Mpris
import qs.Commons
import qs.Commons as Commons

// ============================================================================
// Liquid Glass — service Spotify.
//
// Écoute MPRIS par événements (aucun polling D-Bus) :
//   • changement de morceau → liquid-glass-spotify track (pochette HD, fond,
//     palette, paroles LRCLIB) — une seule fois par morceau, avec cache ;
//   • lecture → fond d'écran pochette + couleurs dynamiques ;
//   • pause prolongée (spotify.restore_after_minutes) → retour au fond du thème.
// La position de lecture est extrapolée localement par Quickshell (pas d'appel
// D-Bus) et rafraîchie 4×/s seulement quand des paroles synchronisées sont affichées.
//
// Fenêtres : paroles sur le bureau (couche Bottom, derrière les fenêtres),
// widget flottant déplaçable, karaoké plein écran, visualiseur cava.
// IPC : omarchy-shell liquid-glass.spotify status|karaoke|widget|desktop|refresh|restore
// ============================================================================
Item {
  id: svc

  property var shell: null
  property var manifest: null

  readonly property string home: Quickshell.env("HOME")

  // ------------------------------------------------------------------ config
  property var cfg: ({})
  FileView {
    id: cfgFile
    path: svc.home + "/.config/liquid-glass/config.json"
    watchChanges: true
    onFileChanged: reload()
    onLoaded: { try { svc.cfg = JSON.parse(text()) } catch (e) { console.warn("liquid-glass: config.json illisible") } }
  }
  readonly property var spCfg: cfg.spotify || ({})
  readonly property var lyCfg: cfg.lyrics || ({})
  readonly property var vzCfg: cfg.visualizer || ({})
  readonly property string wallMode: spCfg.wallpaper || "cover"
  readonly property real restoreMinutes: spCfg.restore_after_minutes !== undefined ? Number(spCfg.restore_after_minutes) : 5
  readonly property bool dynamicColors: spCfg.dynamic_colors !== false
  readonly property bool lyricsDesktop: lyCfg.desktop !== false
  readonly property bool lyricsWidget: lyCfg.widget === true
  readonly property bool lyricsBar: lyCfg.bar !== false
  readonly property bool visualizer: vzCfg.enabled === true
  readonly property int visualizerBars: Math.max(16, Math.min(128, Number(vzCfg.bars) || 64))

  // ------------------------------------------------------------------ thème
  property string themeName: ""
  FileView {
    id: themeFile
    path: svc.home + "/.local/state/omarchy/current/theme.name"
    watchChanges: true
    onFileChanged: reload()
    onLoaded: {
      var name = text().trim()
      var changed = svc.themeName !== "" && name !== svc.themeName
      svc.themeName = name
      // Un changement de thème remet le fond et les couleurs du thème :
      // on régénère la variante claire/sombre du fond si la musique joue.
      if (changed) {
        svc.showingCover = false
        svc.colorsActive = false
        themeRefetch.restart()
      }
    }
  }
  readonly property bool dark: Commons.Color.background.hslLightness < 0.5
  Timer { id: themeRefetch; interval: 1800; onTriggered: if (svc.hasTrack) svc.fetch(true) }

  // ------------------------------------------------------------------ lecteur
  function isSpotify(p) {
    var id = String((p.identity || "") + " " + (p.desktopEntry || "") + " " + (p.dbusName || "")).toLowerCase()
    return id.indexOf("spotify") !== -1
  }
  // Spotify en priorité (client officiel, spotify-player, spotifyd), sinon le lecteur actif.
  readonly property var player: {
    var ps = Mpris.players ? Mpris.players.values : []
    var spotify = null, playing = null
    for (var i = 0; i < ps.length; i++) {
      if (!spotify && isSpotify(ps[i])) spotify = ps[i]
      if (!playing && ps[i].isPlaying) playing = ps[i]
    }
    return spotify || playing
  }
  readonly property bool playing: !!player && player.isPlaying
  readonly property string title: player ? (player.trackTitle || "") : ""
  readonly property string artist: player ? (player.trackArtist || "") : ""
  readonly property string album: player ? (player.trackAlbum || "") : ""
  readonly property string artUrl: player ? (player.trackArtUrl || "") : ""
  readonly property real length: player && player.lengthSupported ? player.length : 0
  readonly property bool hasTrack: title !== ""
  readonly property string trackKey: title + "\u001f" + artist + "\u001f" + album

  // Résultats du moteur pour le morceau courant.
  property string coverPath: ""
  property string wallpaperPath: ""
  property var palette: null
  property var lyricLines: []
  property bool lyricsSynced: false
  property string lyricsPlain: ""
  property bool lyricsLoading: false
  property int lineIndex: -1
  property real position: 0

  readonly property string currentLine: lineIndex >= 0 && lineIndex < lyricLines.length ? lyricLines[lineIndex].text : ""
  readonly property string nextLine: lineIndex + 1 < lyricLines.length ? lyricLines[lineIndex + 1].text : ""
  readonly property color accent: palette && palette.accent ? palette.accent : Commons.Color.accent
  readonly property color accent2: palette && palette.accent2 ? palette.accent2 : Commons.Color.accent

  onTrackKeyChanged: {
    lineIndex = -1
    lyricLines = []
    lyricsSynced = false
    lyricsPlain = ""
    if (hasTrack) fetchDebounce.restart()
  }
  onPlayingChanged: {
    if (playing) {
      restoreTimer.stop()
      if (wallpaperPath !== "" && !showingCover) showCover()
      if (dynamicColors && palette && !colorsActive) applyColors()
      syncPosition()
    }
  }
  onPlayerChanged: if (!player && (showingCover || colorsActive)) restoreAll()
  onDynamicColorsChanged: { if (!dynamicColors && colorsActive) resetColors(); else if (dynamicColors && playing && palette) applyColors() }
  onWallModeChanged: if (hasTrack) fetch(true)
  onLyricsDesktopChanged: if (hasTrack && wallMode === "cover") fetch(true)

  // Changements de morceau rapprochés (on zappe) : on attend que ça se stabilise.
  Timer { id: fetchDebounce; interval: 450; onTriggered: svc.fetch(false) }

  property string requestedKey: ""
  property bool fetchPending: false

  function fetch(force) {
    if (!hasTrack) return
    if (helper.running) { fetchPending = true; return }
    requestedKey = trackKey
    lyricsLoading = true
    helper.command = [
      "liquid-glass-spotify", "track",
      "--art", artUrl, "--artist", artist, "--title", title, "--album", album,
      "--length", String(Math.round(length)),
      "--mode", wallMode === "off" ? "off" : wallMode,
      "--layout", (lyricsDesktop && wallMode === "cover") ? "left" : "center",
      "--theme", dark ? "dark" : "light"
    ]
    helper.running = true
  }

  Process {
    id: helper
    stdout: StdioCollector {
      onStreamFinished: {
        var res = null
        try { res = JSON.parse(text) } catch (e) { res = null }
        svc.lyricsLoading = false
        if (!res || res.error) { if (res) console.warn("liquid-glass-spotify:", res.error); return }
        if (svc.requestedKey !== svc.trackKey) return   // morceau déjà changé
        svc.coverPath = res.cover || ""
        svc.palette = res.palette || null
        var ly = res.lyrics || {}
        svc.lyricLines = Array.isArray(ly.lines) ? ly.lines : []
        svc.lyricsSynced = ly.synced === true && svc.lyricLines.length > 0
        svc.lyricsPlain = ly.plain || ""
        var newWall = res.wallpaper || ""
        var wallChanged = newWall !== svc.wallpaperPath
        svc.wallpaperPath = newWall
        svc.syncPosition()
        if (svc.playing) {
          if (svc.wallMode !== "off" && newWall !== "" && (wallChanged || !svc.showingCover)) svc.showCover()
          if (svc.wallMode === "off" && svc.showingCover) svc.restoreWallpaper()
          if (svc.dynamicColors && svc.palette) svc.applyColors()
        }
      }
    }
    onExited: if (svc.fetchPending) { svc.fetchPending = false; Qt.callLater(function() { svc.fetch(false) }) }
  }

  // ------------------------------------------------------------------ fond
  property bool showingCover: false

  function showCover() {
    if (wallpaperPath === "") return
    Util.execArgv(["omarchy-shell", "-q", "background", "transition", "", wallpaperPath])
    showingCover = true
  }

  // Retour au fond du thème : le lien symbolique d'Omarchy n'a jamais été modifié.
  function restoreWallpaper() {
    if (!showingCover) return
    restoreProc.running = true
    showingCover = false
  }
  Process {
    id: restoreProc
    command: ["sh", "-c", "omarchy-shell -q background transition '' \"$(readlink -f \"$HOME/.local/state/omarchy/current/background\")\""]
  }

  // ------------------------------------------------------------------ couleurs
  property bool colorsActive: false
  function applyColors() {
    if (!palette || !palette.accent) return
    Util.execArgv(["liquid-glass-spotify", "colors", "--accent", String(palette.accent), "--accent2", String(palette.accent2 || palette.accent)])
    colorsActive = true
  }
  function resetColors() {
    Util.execArgv(["liquid-glass-spotify", "colors", "--reset"])
    colorsActive = false
  }

  function restoreAll() {
    restoreWallpaper()
    if (colorsActive) resetColors()
  }

  // Pause prolongée → fond et couleurs du thème.
  Timer {
    id: restoreTimer
    interval: Math.max(1, svc.restoreMinutes) * 60000
    running: !svc.playing && (svc.showingCover || svc.colorsActive) && svc.restoreMinutes > 0
    onTriggered: svc.restoreAll()
  }

  // ------------------------------------------------------------------ position & paroles
  property bool karaokeOpen: false
  property int barConsumers: 0   // widgets de barre qui affichent les paroles
  readonly property bool needsPosition: playing && (lyricsSynced || popupOpen || karaokeOpen)
  property bool popupOpen: false

  function syncPosition() {
    if (!player) return
    if (player.positionSupported) player.positionChanged()
    position = player.position || 0
    updateLine()
  }

  function updateLine() {
    if (!lyricsSynced) { lineIndex = -1; return }
    // Légère avance : la ligne s'affiche au moment où elle est chantée.
    var t = position + 0.25
    var lines = lyricLines
    var i = lineIndex
    if (i < 0 || i >= lines.length || lines[i].t > t) i = 0
    while (i + 1 < lines.length && lines[i + 1].t <= t) i++
    if (lines.length && lines[0].t > t) i = -1
    if (i !== lineIndex) lineIndex = i
  }

  Timer {
    interval: 250
    repeat: true
    running: svc.needsPosition
    onTriggered: svc.syncPosition()
  }
  Connections {
    target: svc.player
    ignoreUnknownSignals: true
    function onPostTrackChanged() { svc.syncPosition() }
    function onSeeked() { svc.syncPosition() }
  }

  // ------------------------------------------------------------------ actions
  function seek(seconds) {
    if (!player || !player.canSeek) return
    player.position = Math.max(0, Math.min(length, seconds))
    syncPosition()
  }

  // Le « j'aime » n'existe pas dans MPRIS : on passe par spotify_player s'il est installé.
  property bool canLike: false
  Process {
    id: likeProbe
    command: ["sh", "-c", "command -v spotify_player >/dev/null && echo yes"]
    running: true
    stdout: StdioCollector { onStreamFinished: svc.canLike = text.trim() === "yes" }
  }
  function like() {
    if (canLike) Util.execArgv(["spotify_player", "like"])
  }

  function setConfig(key, value) {
    Util.execArgv(["liquid-glass", "set", key, String(value)])
  }

  ShellIpc {
    target: "liquid-glass.spotify"

    function status(): string {
      return JSON.stringify({
        player: svc.player ? (svc.player.identity || "") : "",
        playing: svc.playing, title: svc.title, artist: svc.artist,
        cover: svc.coverPath, wallpaper: svc.wallpaperPath, showingCover: svc.showingCover,
        colorsActive: svc.colorsActive, lyrics: svc.lyricLines.length, synced: svc.lyricsSynced,
        line: svc.currentLine, position: svc.position
      })
    }
    function karaoke(): void { svc.karaokeOpen = !svc.karaokeOpen }
    function widget(): void { svc.setConfig("lyrics.widget", !svc.lyricsWidget) }
    function desktop(): void { svc.setConfig("lyrics.desktop", !svc.lyricsDesktop) }
    function refresh(): void { svc.fetch(true) }
    function restore(): void { svc.restoreAll() }
    function playPause(): void { if (svc.player) svc.player.togglePlaying() }
    function next(): void { if (svc.player) svc.player.next() }
    function previous(): void { if (svc.player) svc.player.previous() }
  }

  // ------------------------------------------------------------------ fenêtres
  // Paroles sur le bureau, derrière les fenêtres (un par écran).
  Variants {
    model: Quickshell.screens
    delegate: Component {
      DesktopLyrics {
        required property var modelData
        screen: modelData
        service: svc
      }
    }
  }

  FloatingLyrics { service: svc }
  Karaoke { service: svc }

  // ------------------------------------------------------------------ visualiseur
  // cava en sortie « raw ascii » sur stdout : une ligne « v1;v2;…; » par image.
  // Ne tourne que si activé ET en lecture (aucun coût sinon).
  property var cavaValues: []
  readonly property bool cavaRunning: cava.running
  Process {
    id: cava
    running: svc.visualizer && svc.playing
    command: ["sh", "-c",
      "d=\"$HOME/.cache/liquid-glass\"; mkdir -p \"$d\"; c=\"$d/cava.conf\"; " +
      "printf '[general]\\nbars = %s\\nframerate = 30\\n[input]\\nmethod = pipewire\\n" +
      "[output]\\nmethod = raw\\nraw_target = /dev/stdout\\ndata_format = ascii\\n" +
      "ascii_max_range = 100\\nbar_delimiter = 59\\nframe_delimiter = 10\\n" +
      "[smoothing]\\nnoise_reduction = 70\\n' \"$1\" > \"$c\"; exec cava -p \"$c\"",
      "sh", String(svc.visualizerBars)]
    stdout: SplitParser {
      onRead: function(line) {
        var parts = line.split(";")
        var out = []
        for (var i = 0; i < parts.length; i++) if (parts[i] !== "") out.push(Number(parts[i]))
        svc.cavaValues = out
      }
    }
    onExited: svc.cavaValues = []
  }

  Variants {
    model: svc.visualizer ? Quickshell.screens : []
    delegate: Component {
      Visualizer {
        required property var modelData
        screen: modelData
        service: svc
      }
    }
  }
}
