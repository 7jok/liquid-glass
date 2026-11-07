import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris
import Quickshell.Services.UPower
import qs.Commons
import qs.Commons as Commons
import qs.Ui

// ============================================================================
// Liquid Glass — vue de l'écran de verrouillage façon macOS Tahoe.
// Clone visuel de omarchy.lock/LockView.qml : la saisie et l'authentification
// (propriétés, signaux, TextInput et ses gestionnaires, empreinte) sont celles
// d'Omarchy, inchangées ; Service.qml (PAM) n'est pas modifié.
//
// De haut en bas, au centre : la date, la grande horloge en verre, puis en bas
// le widget musique (LockMusic), l'avatar, le nom et le petit champ du mot de
// passe avec son indication. Fond d'écran net.
// En haut à droite : batterie, puis les notifications récentes (aperçu réglable).
// Bulle des paroles du widget : il s'agrandit (grande pochette + commandes),
// la pochette floutée devient le fond et les paroles défilent à côté.
// Le widget se déplace librement, avec inertie.
// Réglages : section [lock] de ~/.config/liquid-glass/config.toml.
// ============================================================================
Item {
  id: root

  property string backgroundPath: ""
  property string videoPosterPath: ""
  property int backgroundVersion: 0
  property bool fingerprintConfigured: false
  property bool fingerprintUnavailable: false
  property bool authenticatingPassword: false
  property string failureMessage: ""
  property int failedAttempts: 0
  property bool inputEnabled: true
  property bool loadBackground: true
  property string passwordText: ""
  property bool syncingPasswordText: false

  readonly property string placeholderText: "Mot de passe"
  // Champ du vrai macOS : petite capsule de verre tout en bas (≈ 132 × 22 pt).
  readonly property int fieldWidth: 132
  readonly property int fieldHeight: 22
  readonly property int fieldFontSize: 11
  readonly property int passwordDotFontSize: 10
  readonly property int passwordDotLetterSpacing: 3
  readonly property real fingerprintReserve: fingerprintConfigured ? Math.round(fingerprintIcon.implicitWidth + 8) : 0
  readonly property real passwordDotScale: dotMetrics.advanceWidth > 0
    ? Math.min(1, (passwordInput.width - 4) / dotMetrics.advanceWidth)
    : 1
  readonly property bool showPasswordCursor: inputEnabled && !authenticatingPassword && failureMessage.length === 0
  readonly property bool errorState: failureMessage.length > 0

  // A video wallpaper shows its still poster: nothing plays behind the lock.
  readonly property bool video: Util.isVideoPath(root.backgroundPath)

  signal submitPassword(string password)
  signal passwordTextEdited(string password)
  signal clearFailureRequested()
  signal wakeRequested()

  function forcePasswordFocus() {
    passwordInput.forceActiveFocus()
  }

  function clearPassword() {
    passwordTextEdited("")
  }

  function dropsAutoRepeat(key) {
    return key !== Qt.Key_Backspace && key !== Qt.Key_Delete
  }

  function syncPasswordText() {
    if (passwordInput.text === passwordText) return
    syncingPasswordText = true
    passwordInput.text = passwordText
    syncingPasswordText = false
  }

  function restorePasswordFocus() {
    if (inputEnabled && passwordInput.enabled && !passwordInput.activeFocus) forcePasswordFocus()
  }

  onPasswordTextChanged: syncPasswordText()
  onInputEnabledChanged: {
    if (inputEnabled) Qt.callLater(forcePasswordFocus)
  }
  // Mot de passe refusé : le champ « secoue la tête », comme sur macOS.
  onFailedAttemptsChanged: if (failedAttempts > 0) shake.restart()

  Window.onActiveFocusItemChanged: Qt.callLater(restorePasswordFocus)
  Component.onCompleted: {
    syncPasswordText()
    if (inputEnabled) Qt.callLater(forcePasswordFocus)
  }

  TextMetrics {
    id: dotMetrics
    font.family: Style.font.family
    font.pixelSize: root.passwordDotFontSize
    font.letterSpacing: root.passwordDotLetterSpacing
    text: "●".repeat(passwordInput.text.length)
  }

  // ------------------------------------------------------------ réglages
  readonly property string home: Quickshell.env("HOME")
  property var cfg: ({})
  FileView {
    path: root.home + "/.config/liquid-glass/config.json"
    watchChanges: true
    printErrors: false
    onFileChanged: reload()
    onLoaded: { try { root.cfg = JSON.parse(text()) } catch (e) {} }
  }
  readonly property var lockCfg: cfg.lock || ({})
  function lopt(k, d) { return lockCfg.hasOwnProperty(k) ? lockCfg[k] : d }
  // full (titre + texte) | summary (appli + titre) | count (nombre seulement) | off
  readonly property string notifMode: String(lopt("notifications", "summary"))
  // art (pochette nette + fond flou) | wallpaper (fond Spotify) | blur | off
  readonly property string musicBackground: String(lopt("music_background", "art"))
  readonly property bool showLyrics: lopt("lyrics", true) !== false
  readonly property bool showMusicCard: lopt("music_card", true) !== false
  readonly property bool showStatus: lopt("status", true) !== false
  // Fond d'écran net (comme macOS) ou flouté.
  readonly property bool wallpaperBlur: lopt("wallpaper_blur", false) === true
  // glass (verre dégradé) | bold (classique) | serif | liquid (verre liquide : contour lumineux) | light (fine)
  readonly property string clockStyle: String(lopt("clock_style", "glass"))
  // Graisse 100…900 (0 = celle du style), luminosité 0,4…1, teinte, chiffres hauts, format de date.
  readonly property int clockWeight: {
    var w = Number(lopt("clock_weight", 0)) || 0
    if (w >= 100) return Math.max(100, Math.min(900, Math.round(w / 100) * 100))
    return clockStyle === "light" ? Font.Thin : (clockStyle === "glass" || clockStyle === "liquid" ? Font.DemiBold : (clockStyle === "serif" ? Font.Medium : Font.Bold))
  }
  readonly property real clockBrightness: Math.max(0.4, Math.min(1, Number(lopt("clock_brightness", 1)) || 1))
  readonly property color clockColor: { var c = String(lopt("clock_color", "#ffffff")); return /^#[0-9a-fA-F]{6}$/.test(c) ? c : "#ffffff" }
  readonly property bool tallDigits: lopt("clock_tall", false) === true
  readonly property string dateFormat: String(lopt("date_format", "long"))
  readonly property bool clock24: lopt("clock_24h", true) !== false
  readonly property string uiFont: (cfg.appearance && cfg.appearance.font_ui) || "Inter"
  readonly property string clockFont: String(lopt("clock_font", "")) || uiFont

  // ------------------------------------------------------------ musique
  readonly property var player: {
    var ps = Mpris.players ? Mpris.players.values : []
    var spotify = null, playing = null
    for (var i = 0; i < ps.length; i++) {
      var id = String((ps[i].identity || "") + " " + (ps[i].desktopEntry || "")).toLowerCase()
      if (!spotify && id.indexOf("spotify") !== -1) spotify = ps[i]
      if (!playing && ps[i].isPlaying) playing = ps[i]
    }
    return playing || spotify
  }
  readonly property bool musicActive: !!player && (player.trackTitle || "") !== ""
  readonly property bool musicPlaying: musicActive && player.isPlaying
  property var nowPlaying: ({})
  FileView {
    path: root.home + "/.cache/liquid-glass/now-playing.json"
    watchChanges: true
    printErrors: false
    onFileChanged: reload()
    onLoaded: { try { root.nowPlaying = JSON.parse(text()) } catch (e) { root.nowPlaying = ({}) } }
  }
  // Dernier morceau écouté (écrit par liquid-glass.spotify) : quand Spotify est
  // fermé, la carte reste là avec sa pochette, et ▶ relance la chanson.
  property var lastTrack: ({})
  FileView {
    path: root.home + "/.cache/liquid-glass/last-track.json"
    watchChanges: true
    printErrors: false
    onFileChanged: reload()
    onLoaded: { try { root.lastTrack = JSON.parse(text()) } catch (e) { root.lastTrack = ({}) } }
  }
  readonly property bool resumeMode: !musicActive && lopt("music_last", true) !== false
    && String(lastTrack.title || "") !== "" && String(lastTrack.cover || "") !== ""
  readonly property bool musicShown: musicActive || resumeMode
  readonly property string trackTitle: musicActive ? (player.trackTitle || "") : (resumeMode ? String(lastTrack.title) : "")
  readonly property string trackArtist: musicActive ? (player.trackArtist || "") : (resumeMode ? String(lastTrack.artist || "") : "")
  // ▶ pressé : Spotify démarre en arrière-plan (quelques secondes), la carte patiente.
  property bool resuming: false
  onMusicActiveChanged: if (musicActive) resuming = false
  Timer { id: resumeTimeout; interval: 30000; onTriggered: root.resuming = false }
  function resumeMusic() {
    if (resuming) return
    resuming = true
    resumeTimeout.restart()
    Quickshell.execDetached(["liquid-glass", "resume-music"])
  }
  // Les données en cache ne valent que pour le morceau affiché.
  readonly property bool npMatches: musicActive && nowPlaying.title === player.trackTitle
  readonly property string coverSource: {
    if (!musicActive) return resumeMode ? "file://" + lastTrack.cover : ""
    if (npMatches && nowPlaying.cover) return "file://" + nowPlaying.cover
    var art = String(player.trackArtUrl || "")
    return art.indexOf("file://") === 0 ? art : ""
  }
  readonly property var palette: npMatches ? (nowPlaying.palette || null) : (resumeMode ? (lastTrack.palette || null) : null)
  readonly property color tintA: palette && palette.colors && palette.colors.length > 1 ? palette.colors[1] : "#1c1c1e"
  readonly property color tintB: palette && palette.accent ? palette.accent : "#3a3a3c"
  // Le fond « musique » ne remplace le fond d'écran que pendant la lecture.
  // Widget agrandi (bulle des paroles) : la pochette floutée devient le fond.
  property bool musicExpanded: false
  readonly property bool musicScene: musicShown && musicExpanded && musicBackground !== "off" && coverSource !== ""
  readonly property bool artMode: musicScene && musicBackground === "art"

  // Position extrapolée (MPRIS ne pousse pas la position) et ligne de paroles.
  property real position: 0
  readonly property real trackLength: player && player.lengthSupported ? player.length : 0
  readonly property var lyricLines: npMatches && Array.isArray(nowPlaying.lyrics) ? nowPlaying.lyrics : []
  readonly property bool lyricsShown: showLyrics && musicExpanded && lyricLines.length > 0
  property int lineIndex: -1
  function updatePosition() {
    if (!player) return
    if (player.positionSupported) player.positionChanged()
    position = player.position || 0
    var t = position + 0.25, lines = lyricLines, i = -1
    while (i + 1 < lines.length && lines[i + 1].t <= t) i++
    if (i !== lineIndex) lineIndex = i
  }
  Timer {
    interval: root.lyricsShown ? 250 : 1000
    repeat: true
    triggeredOnStart: true
    running: root.loadBackground && root.musicActive
    onTriggered: root.updatePosition()
  }
  function fmt(s) { s = Math.max(0, Math.floor(s)); return Math.floor(s / 60) + ":" + ("0" + s % 60).slice(-2) }
  readonly property var lyricsModelRef: lyricsModel
  QtObject {
    id: lyricsModel
    readonly property var lyricLines: root.lyricLines
    readonly property int lineIndex: root.lineIndex
  }

  // ------------------------------------------------------------ notifications
  // Lues dans l'état du service de notifications d'Omarchy (live + historique),
  // les plus récentes d'abord, sur les 12 dernières heures.
  property var liveNotifs: []
  property var pastNotifs: []
  FileView {
    path: root.home + "/.local/state/omarchy/notifications/live.json"
    watchChanges: true
    printErrors: false
    onFileChanged: reload()
    onLoaded: { try { root.liveNotifs = JSON.parse(text()) || [] } catch (e) { root.liveNotifs = [] } }
  }
  FileView {
    path: root.home + "/.local/state/omarchy/notifications/history.json"
    watchChanges: true
    printErrors: false
    onFileChanged: reload()
    onLoaded: { try { root.pastNotifs = JSON.parse(text()) || [] } catch (e) { root.pastNotifs = [] } }
  }
  property real nowSec: Date.now() / 1000
  readonly property var notifications: {
    if (notifMode === "off") return []
    var all = [].concat(liveNotifs || [], pastNotifs || [])
    var seen = {}, out = []
    for (var i = 0; i < all.length; i++) {
      var n = all[i]
      if (!n || !n.ts || seen[n.key]) continue
      seen[n.key] = true
      if (nowSec - n.ts > 12 * 3600 || n.transient) continue
      out.push(n)
    }
    out.sort(function(a, b) { return b.ts - a.ts })
    return out
  }
  function ago(ts) {
    var d = Math.max(0, nowSec - ts)
    if (d < 60) return "maintenant"
    if (d < 3600) return "il y a " + Math.floor(d / 60) + " min"
    return "il y a " + Math.floor(d / 3600) + " h"
  }
  function appLabel(n) {
    var a = String(n.app || n.source || "")
    if (a === "omarchy-action" || a === "") return "Système"
    if (a === "omasnap") return "Capture d'écran"
    return a.charAt(0).toUpperCase() + a.slice(1)
  }

  // Avatar : ~/.face s'il existe (sinon l'initiale). Test d'existence sans avertissement.
  property bool hasFace: false
  Process {
    command: ["test", "-f", root.home + "/.face"]
    running: true
    onExited: function(code) { root.hasFace = code === 0 }
  }
  // Nom complet (champ GECOS), sinon l'identifiant avec une majuscule.
  property string fullName: ""
  Process {
    command: ["sh", "-c", "getent passwd \"$USER\" | cut -d: -f5 | cut -d, -f1"]
    running: true
    stdout: StdioCollector { onStreamFinished: root.fullName = text.trim() }
  }
  readonly property string displayName: {
    if (fullName !== "") return fullName
    var u = String(Quickshell.env("USER") || "")
    return u.charAt(0).toUpperCase() + u.slice(1)
  }

  // ------------------------------------------------------------ fond
  Rectangle {
    anchors.fill: parent
    color: Commons.Color.background

    BackgroundMedia {
      id: wallpaper
      objectName: "lockWallpaper"
      anchors.fill: parent
      path: root.loadBackground ? (root.video ? root.videoPosterPath : root.backgroundPath) : ""
      version: root.backgroundVersion
      cached: true
      constrainDecode: true
      decodeSize: Qt.size(width, height)
    }

    MultiEffect {
      anchors.fill: wallpaper
      source: wallpaper
      autoPaddingEnabled: false
      blurEnabled: root.loadBackground && wallpaper.ready && root.wallpaperBlur
      blur: 1.0
      blurMax: 128
      blurMultiplier: 1.25
      contrast: -0.08
    }

    // ---- Scène musique : pochette floutée plein écran (modes art et blur).
    Image {
      id: coverBg
      anchors.fill: parent
      source: root.loadBackground ? root.coverSource : ""
      sourceSize: Qt.size(512, 512)
      fillMode: Image.PreserveAspectCrop
      visible: false
      asynchronous: true
    }
    MultiEffect {
      anchors.fill: parent
      source: coverBg
      autoPaddingEnabled: false
      blurEnabled: true
      blur: 1.0
      blurMax: 96
      saturation: 0.35
      brightness: -0.14
      opacity: root.musicScene && root.musicBackground !== "wallpaper" && coverBg.status === Image.Ready ? 1 : 0
      Behavior on opacity { NumberAnimation { duration: 700; easing.type: Easing.OutCubic } }
    }
    // Mode « wallpaper » : le fond généré par le service Spotify, net.
    Image {
      anchors.fill: parent
      source: root.loadBackground && root.npMatches && root.nowPlaying.wallpaper ? "file://" + root.nowPlaying.wallpaper : ""
      fillMode: Image.PreserveAspectCrop
      asynchronous: true
      opacity: root.musicScene && root.musicBackground === "wallpaper" && status === Image.Ready ? 1 : 0
      Behavior on opacity { NumberAnimation { duration: 700; easing.type: Easing.OutCubic } }
    }
    // Dégradé des couleurs de la pochette, très léger, pour lier le tout.
    Rectangle {
      anchors.fill: parent
      opacity: root.artMode ? 0.35 : 0
      Behavior on opacity { NumberAnimation { duration: 700 } }
      gradient: Gradient {
        orientation: Gradient.Horizontal
        GradientStop { position: 0.0; color: root.tintA }
        GradientStop { position: 1.0; color: Qt.rgba(root.tintB.r, root.tintB.g, root.tintB.b, 0.2) }
      }
    }
    // Léger voile pour que le texte blanc reste lisible sur les fonds clairs.
    Rectangle {
      anchors.fill: parent
      gradient: Gradient {
        GradientStop { position: 0.0; color: Qt.rgba(0, 0, 0, 0.14) }
        GradientStop { position: 0.4; color: Qt.rgba(0, 0, 0, 0.0) }
        GradientStop { position: 1.0; color: Qt.rgba(0, 0, 0, 0.18) }
      }
    }

    MouseArea {
      anchors.fill: parent
      hoverEnabled: true
      onClicked: { root.wakeRequested(); root.forcePasswordFocus() }
      onPositionChanged: root.wakeRequested()
    }

    // ---------------------------------------------------------- horloge
    SystemClock { id: clock; precision: SystemClock.Minutes; onDateChanged: root.nowSec = Date.now() / 1000 }

    Column {
      id: clockColumn
      anchors.horizontalCenter: parent.horizontalCenter
      y: Math.round(parent.height * 0.065)
      spacing: -Math.round(root.height * 0.004)

      Text {
        anchors.horizontalCenter: parent.horizontalCenter
        textFormat: Text.PlainText
        text: {
          var s = Qt.locale("fr_FR").toString(clock.date, root.dateFormat === "short" ? "ddd d MMM" : "dddd d MMMM")
          return s.charAt(0).toUpperCase() + s.slice(1)
        }
        font.family: root.uiFont; font.pixelSize: Math.round(root.height * 0.028); font.weight: Font.DemiBold
        color: "white"; opacity: 0.9
        layer.enabled: true
        layer.effect: MultiEffect { shadowEnabled: true; shadowBlur: 0.6; shadowColor: "#40000000"; shadowVerticalOffset: 1 }
      }

      // Grande horloge. Style « glass » : remplissage blanc dégradé, comme du
      // verre dépoli éclairé par le haut, avec une ombre douce.
      // Chiffres hauts (comme iOS 26) : l'horloge s'étire en hauteur et se resserre.
      Item {
        anchors.horizontalCenter: parent.horizontalCenter
        width: bigClock.width * bigClock.sx
        height: bigClock.height * bigClock.sy
        Behavior on height { NumberAnimation { duration: 520; easing.type: Easing.OutBack; easing.overshoot: 1.6 } }
      Item {
        id: bigClock
        readonly property real sx: root.tallDigits ? 0.86 : 1
        readonly property real sy: root.tallDigits ? 1.45 : 1
        transform: Scale { origin.x: bigClock.width / 2; origin.y: 0; xScale: bigClock.sx; yScale: bigClock.sy
          Behavior on yScale { NumberAnimation { duration: 520; easing.type: Easing.OutBack; easing.overshoot: 1.6 } }
          Behavior on xScale { NumberAnimation { duration: 520; easing.type: Easing.OutBack; easing.overshoot: 1.6 } } }
        opacity: root.clockBrightness
        // Marge autour du texte : les chiffres débordent de leur boîte (approche
        // négative), et le masque ne doit pas les rogner.
        readonly property real pad: Math.round(root.height * 0.03)
        anchors.horizontalCenter: parent.horizontalCenter
        width: clockText.implicitWidth
        height: clockText.implicitHeight
        Text {
          id: clockText
          textFormat: Text.PlainText
          text: Qt.formatTime(clock.date, root.clock24 ? "HH:mm" : "h:mm")
          font.family: root.clockStyle === "serif" ? "Noto Serif" : root.clockFont
          font.pixelSize: Math.round(root.height * 0.13)
          font.weight: root.clockWeight
          font.letterSpacing: -Math.round(root.height * 0.003)
          font.features: { "tnum": 1 }
          // Verre liquide : chiffres presque transparents cernés d'un liseré lumineux.
          color: root.clockStyle === "liquid" ? Qt.rgba(root.clockColor.r, root.clockColor.g, root.clockColor.b, 0.22) : root.clockColor
          style: root.clockStyle === "liquid" ? Text.Outline : Text.Normal
          styleColor: Qt.rgba(root.clockColor.r, root.clockColor.g, root.clockColor.b, 0.9)
          opacity: root.clockStyle === "glass" ? 0 : 0.92
          layer.enabled: root.clockStyle !== "glass"
          layer.effect: MultiEffect { shadowEnabled: true; shadowBlur: 0.8; shadowColor: "#38000000"; shadowVerticalOffset: 2 }
        }
        Item {
          id: clockMask
          x: -bigClock.pad; y: -bigClock.pad
          width: bigClock.width + 2 * bigClock.pad; height: bigClock.height + 2 * bigClock.pad
          visible: false
          layer.enabled: true
          layer.smooth: true
          Text {
            x: bigClock.pad; y: bigClock.pad
            textFormat: Text.PlainText
            text: clockText.text
            font: clockText.font
            color: "black"
          }
        }
        Rectangle {
          id: clockFill
          anchors.fill: clockMask
          visible: false
          layer.enabled: true
          gradient: Gradient {
            GradientStop { position: 0.15; color: Qt.rgba(root.clockColor.r, root.clockColor.g, root.clockColor.b, 0.97) }
            GradientStop { position: 0.6; color: Qt.rgba(root.clockColor.r, root.clockColor.g, root.clockColor.b, 0.80) }
            GradientStop { position: 0.9; color: Qt.rgba(root.clockColor.r, root.clockColor.g, root.clockColor.b, 0.60) }
          }
        }
        MultiEffect {
          anchors.fill: clockMask
          visible: root.clockStyle === "glass"
          source: clockFill
          maskEnabled: true
          maskSource: clockMask
          // Bords lissés : fondu autour du seuil (sinon le masque est binaire).
          maskThresholdMin: 0.5
          maskSpreadAtMin: 1.0
          shadowEnabled: true
          shadowBlur: 0.7
          shadowOpacity: 0.3
          shadowVerticalOffset: 3
        }
      }
      }
    }

    // ---------------------------------------------------------- lecture en cours
    LockMusic {
      anchors.fill: parent
      view: root
      topLimit: clockColumn.y + clockColumn.height
      bottomLimit: userColumn.y
      expanded: root.musicExpanded
      onToggled: root.musicExpanded = !root.musicExpanded
    }

    // ---------------------------------------------------------- état (en haut à droite)
    Row {
      id: statusRow
      visible: root.showStatus
      anchors.right: parent.right; anchors.rightMargin: 22
      y: 14
      spacing: 10
      readonly property var bat: UPower.displayDevice
      readonly property bool hasBat: !!(bat && bat.isPresent)
      Text {
        visible: statusRow.hasBat
        anchors.verticalCenter: parent.verticalCenter
        textFormat: Text.PlainText
        text: statusRow.hasBat ? Math.round(statusRow.bat.percentage * 100) + " %" : ""
        font.family: root.uiFont; font.pixelSize: 13; font.weight: Font.Medium
        color: "white"
      }
      Text {
        visible: statusRow.hasBat
        anchors.verticalCenter: parent.verticalCenter
        textFormat: Text.PlainText
        text: {
          if (!statusRow.hasBat) return ""
          if (!UPower.onBattery) return String.fromCodePoint(0xF0084)
          var p = statusRow.bat.percentage
          var steps = [0xF008E, 0xF007A, 0xF007B, 0xF007C, 0xF007D, 0xF007E, 0xF007F, 0xF0080, 0xF0081, 0xF0082, 0xF0079]
          return String.fromCodePoint(steps[Math.max(0, Math.min(10, Math.round(p * 10)))])
        }
        font.family: Style.font.family; font.pixelSize: 18
        color: statusRow.hasBat && UPower.onBattery && statusRow.bat.percentage <= 0.2 ? "#ff6961" : "white"
      }
    }

    // ---------------------------------------------------------- notifications (en haut à droite)
    Column {
      id: notifColumn
      anchors.right: parent.right; anchors.rightMargin: 18
      y: statusRow.visible ? 44 : 18
      // Liste compacte comme sur la vidéo : rangées de verre serrées, 4 au plus.
      width: 252
      spacing: 4
      visible: root.notifMode !== "off" && root.notifications.length > 0

      // Mode « count » : une seule pastille.
      Rectangle {
        visible: root.notifMode === "count"
        width: parent.width; height: 44; radius: 16
        color: Qt.rgba(1, 1, 1, 0.16)
        border.width: 1; border.color: Qt.rgba(1, 1, 1, 0.28)
        Text {
          anchors.centerIn: parent
          textFormat: Text.PlainText
          text: root.notifications.length + (root.notifications.length > 1 ? " notifications" : " notification")
          font.family: root.uiFont; font.pixelSize: 13; font.weight: Font.DemiBold
          color: "white"
        }
      }

      Repeater {
        model: root.notifMode === "count" ? [] : root.notifications.slice(0, 4)
        delegate: Rectangle {
          id: card
          required property var modelData
          required property int index
          width: notifColumn.width
          height: Math.max(40, cardCol.implicitHeight + 14)
          radius: 12
          color: Qt.rgba(1, 1, 1, 0.14)
          border.width: 1
          border.color: Qt.rgba(1, 1, 1, 0.22)
          // Apparition en cascade.
          opacity: 0
          Component.onCompleted: appear.start()
          SequentialAnimation {
            id: appear
            PauseAnimation { duration: card.index * 60 }
            NumberAnimation { target: card; property: "opacity"; to: 1; duration: 320; easing.type: Easing.OutCubic }
          }

          Item {
            id: icon
            x: 9; anchors.verticalCenter: parent.verticalCenter
            width: 22; height: 22
            readonly property string iconPath: card.modelData.appIcon ? Quickshell.iconPath(card.modelData.appIcon, true) : ""
            Rectangle {
              anchors.fill: parent; radius: 6
              visible: iconImg.status !== Image.Ready
              gradient: Gradient {
                GradientStop { position: 0; color: "#5ac8fa" }
                GradientStop { position: 1; color: "#007aff" }
              }
              Text {
                anchors.centerIn: parent
                textFormat: Text.PlainText
                text: card.modelData.glyph || String.fromCodePoint(0xF009A)
                font.family: Style.font.family; font.pixelSize: 12
                color: "white"
              }
            }
            Image { id: iconImg; anchors.fill: parent; source: icon.iconPath; sourceSize: Qt.size(48, 48); asynchronous: true; visible: status === Image.Ready }
          }
          Column {
            id: cardCol
            anchors.left: icon.right; anchors.leftMargin: 8
            anchors.right: parent.right; anchors.rightMargin: 10
            anchors.verticalCenter: parent.verticalCenter
            spacing: 0
            // Comme la vidéo : nom de l'app en gras, l'heure à droite, le titre dessous.
            Item {
              width: parent.width; height: appText.implicitHeight
              Text { id: appText; anchors.left: parent.left; anchors.right: when.left; anchors.rightMargin: 6; textFormat: Text.PlainText; elide: Text.ElideRight; text: root.appLabel(card.modelData); font.family: root.uiFont; font.pixelSize: 12; font.weight: Font.DemiBold; color: "white" }
              Text { id: when; anchors.right: parent.right; anchors.verticalCenter: appText.verticalCenter; textFormat: Text.PlainText; text: root.ago(card.modelData.ts); font.family: root.uiFont; font.pixelSize: 10; color: "white"; opacity: 0.55 }
            }
            Text { width: parent.width; textFormat: Text.PlainText; elide: Text.ElideRight; text: card.modelData.summary || ""; font.family: root.uiFont; font.pixelSize: 11; color: "white"; opacity: 0.72 }
            Text {
              width: parent.width
              visible: root.notifMode === "full" && text !== ""
              textFormat: Text.PlainText
              text: String(card.modelData.body || "").replace(/<[^>]*>/g, "")
              wrapMode: Text.WordWrap; maximumLineCount: 2; elide: Text.ElideRight
              font.family: root.uiFont; font.pixelSize: 12
              color: "white"; opacity: 0.82
            }
          }
        }
      }
      Text {
        visible: root.notifMode !== "count" && root.notifications.length > 4
        anchors.horizontalCenter: parent.horizontalCenter
        topPadding: 2
        textFormat: Text.PlainText
        text: (root.notifications.length - 4) + (root.notifications.length - 4 > 1 ? " autres notifications" : " autre notification")
        font.family: root.uiFont; font.pixelSize: 10; font.weight: Font.Medium
        color: "white"; opacity: 0.7
      }
    }

    // ---------------------------------------------------------- utilisateur + mot de passe
    Column {
      id: userColumn
      anchors.horizontalCenter: parent.horizontalCenter
      anchors.bottom: parent.bottom
      anchors.bottomMargin: Math.round(parent.height * 0.035)
      spacing: 7

      Item {
        anchors.horizontalCenter: parent.horizontalCenter
        width: 40; height: 40
        Image {
          id: face
          anchors.fill: parent
          source: root.hasFace ? "file://" + root.home + "/.face" : ""
          sourceSize: Qt.size(128, 128)
          fillMode: Image.PreserveAspectCrop
          visible: false
          cache: false
        }
        Rectangle { id: faceMask; anchors.fill: parent; radius: width / 2; visible: false; layer.enabled: true }
        MultiEffect { anchors.fill: parent; source: face; maskEnabled: true; maskSource: faceMask; visible: face.status === Image.Ready; shadowEnabled: true; shadowOpacity: 0.3; shadowBlur: 0.6 }
        Rectangle {
          anchors.fill: parent
          radius: width / 2
          visible: face.status !== Image.Ready
          // Bulle de verre discrète avec l'initiale, comme la vidéo.
          color: Qt.rgba(1, 1, 1, 0.14)
          border.width: 1; border.color: Qt.rgba(1, 1, 1, 0.3)
          Text {
            anchors.centerIn: parent
            textFormat: Text.PlainText
            text: root.displayName.charAt(0).toUpperCase()
            font.family: root.uiFont; font.pixelSize: 18; font.weight: Font.DemiBold
            color: "white"
          }
        }
      }

      Text {
        anchors.horizontalCenter: parent.horizontalCenter
        textFormat: Text.PlainText
        text: root.displayName
        font.family: root.uiFont; font.pixelSize: 13; font.weight: Font.DemiBold
        color: "white"
        layer.enabled: true
        layer.effect: MultiEffect { shadowEnabled: true; shadowBlur: 0.5; shadowColor: "#40000000"; shadowVerticalOffset: 1 }
      }

      Item {
        id: fieldSlot
        anchors.horizontalCenter: parent.horizontalCenter
        width: root.fieldWidth; height: root.fieldHeight

        Rectangle {
          id: inputField
          // Mêmes noms que la BorderSurface d'origine, utilisés par les marges du champ.
          readonly property int borderTop: 1
          readonly property int borderRight: 1
          readonly property int borderBottom: 1
          readonly property int borderLeft: 1
          width: parent.width; height: parent.height
          radius: height / 2
          color: Qt.rgba(1, 1, 1, passwordInput.activeFocus ? 0.2 : 0.14)
          border.width: 1
          border.color: root.errorState ? Qt.rgba(1, 0.35, 0.33, 0.85) : Qt.rgba(1, 1, 1, 0.36)
          clip: true
          Behavior on color { ColorAnimation { duration: 150 } }

          SequentialAnimation {
            id: shake
            loops: 1
            NumberAnimation { target: inputField; property: "x"; to: -14; duration: 50 }
            NumberAnimation { target: inputField; property: "x"; to: 12; duration: 60 }
            NumberAnimation { target: inputField; property: "x"; to: -8; duration: 60 }
            NumberAnimation { target: inputField; property: "x"; to: 5; duration: 60 }
            NumberAnimation { target: inputField; property: "x"; to: 0; duration: 60 }
          }

          TextInput {
            id: passwordInput
            anchors.fill: parent
            anchors.topMargin: inputField.borderTop
            anchors.rightMargin: inputField.borderRight + 14 + root.fingerprintReserve
            anchors.bottomMargin: inputField.borderBottom
            anchors.leftMargin: inputField.borderLeft + 14 + root.fingerprintReserve
            verticalAlignment: TextInput.AlignVCenter
            horizontalAlignment: TextInput.AlignHCenter
            activeFocusOnPress: true
            clip: true
            enabled: root.inputEnabled && !root.authenticatingPassword
            readOnly: root.authenticatingPassword
            echoMode: TextInput.Password
            passwordCharacter: "●"
            passwordMaskDelay: 0
            color: "white"
            selectionColor: Qt.rgba(1, 1, 1, 0.35)
            selectedTextColor: "white"
            font.family: Style.font.family
            font.pixelSize: text.length > 0 ? Math.max(1, Math.floor(root.passwordDotFontSize * root.passwordDotScale)) : root.fieldFontSize
            font.letterSpacing: text.length > 0 ? root.passwordDotLetterSpacing * root.passwordDotScale : 0
            cursorVisible: activeFocus && root.showPasswordCursor && text.length > 0
            cursorDelegate: Rectangle {
              width: 2
              color: "white"
              visible: passwordInput.cursorVisible
            }

            onTextChanged: {
              if (!root.syncingPasswordText) root.passwordTextEdited(text)
              if (text.length > 0) {
                root.wakeRequested()
              }
              if (text.length > 0 && root.failureMessage.length > 0) root.clearFailureRequested()
            }

            onAccepted: {
              var submitted = root.passwordText
              root.passwordTextEdited("")
              if (submitted.length > 0) root.submitPassword(submitted)
            }

            Keys.onPressed: function(event) {
              root.wakeRequested()
              if (event.isAutoRepeat && root.dropsAutoRepeat(event.key)) {
                event.accepted = true
                return
              }
              if (event.key === Qt.Key_Escape || (event.modifiers & Qt.ControlModifier && event.key === Qt.Key_U)) {
                root.passwordTextEdited("")
                event.accepted = true
              }
            }
          }

          Text {
            textFormat: Text.PlainText
            anchors.fill: passwordInput
            text: root.authenticatingPassword ? "Vérification…" : (root.failureMessage.length > 0 ? root.failureMessage : root.placeholderText)
            visible: passwordInput.text.length === 0
            color: root.failureMessage.length > 0 && !root.authenticatingPassword ? "#ffd2d0" : Qt.rgba(1, 1, 1, 0.68)
            font.family: root.uiFont
            font.pixelSize: root.fieldFontSize
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            elide: Text.ElideRight
          }

          // Flèche « valider » à droite, comme sur macOS, dès qu'on tape.
          Rectangle {
            visible: passwordInput.text.length > 0 && !root.fingerprintConfigured
            anchors.right: parent.right; anchors.rightMargin: 4
            anchors.verticalCenter: parent.verticalCenter
            width: parent.height - 8; height: width; radius: width / 2
            color: Qt.rgba(1, 1, 1, 0.28)
            Text {
              anchors.centerIn: parent
              textFormat: Text.PlainText
              text: String.fromCodePoint(0xF0054)
              font.family: Style.font.family; font.pixelSize: 14
              color: "white"
            }
            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: passwordInput.accepted() }
          }

          Text {
            id: fingerprintIcon
            objectName: "fingerprintIndicator"
            textFormat: Text.PlainText
            anchors.right: parent.right
            anchors.rightMargin: inputField.borderRight + 12
            anchors.verticalCenter: parent.verticalCenter
            visible: root.fingerprintConfigured
            text: root.fingerprintUnavailable ? "󰺱" : "󰈷"
            color: root.fingerprintUnavailable ? "#ffd2d0" : Qt.rgba(1, 1, 1, 0.7)
            font.family: Style.font.family
            font.pixelSize: 18
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
          }
        }
      }

      Text {
        objectName: "fingerprintUnavailableNotice"
        anchors.horizontalCenter: parent.horizontalCenter
        textFormat: Text.PlainText
        visible: root.fingerprintConfigured && root.fingerprintUnavailable
        text: Commons.I18n.t("lock.fingerprintUnavailable")
        color: "#ffd2d0"
        font.family: root.uiFont
        font.pixelSize: 12
        horizontalAlignment: Text.AlignHCenter
      }

      // Petite indication sous le champ.
      Text {
        anchors.horizontalCenter: parent.horizontalCenter
        textFormat: Text.PlainText
        visible: !(root.fingerprintConfigured && root.fingerprintUnavailable)
        text: root.fingerprintConfigured
          ? "Touchez le lecteur d'empreintes ou saisissez le mot de passe"
          : "Saisissez votre mot de passe pour déverrouiller"
        font.family: root.uiFont; font.pixelSize: 10
        color: "white"; opacity: 0.55
      }
    }
  }
}
