import QtQuick
import "Mac.js" as Mac
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.Mpris
import Quickshell.Services.UPower
import Quickshell.Services.Pipewire
import Quickshell.Bluetooth
import Quickshell.Widgets
import qs.Commons
import "T.js" as T

// Liquid Glass — île dynamique dans une fausse encoche, façon Alcove / NotchNook.
//
//  · repos      : invisible (ou petite encoche noire si [island] idle = "notch")
//  · musique    : pochette à gauche, égaliseur animé aux couleurs de la pochette
//  · survol     : l'île s'élargit (titre et artiste)
//  · clic       : panneau ouvert (grande pochette, progression, commandes)
//  · événements : branchement secteur, casque Bluetooth, Concentration,
//                 volume (si [island] hud = true) — 2,5 s puis retour
//  · gestes     : molette = volume ; balayage horizontal = morceau suivant/précédent
//
// Réglages : [island] de config.toml (Réglages → Barre des menus → Île dynamique).
Item {
  id: root
  property var shell: null
  property var manifest: null

  // ------------------------------------------------------------ réglages
  property var cfg: ({})
  readonly property var ic: cfg.island || ({})
  readonly property bool enabled: ic.enabled !== false
  readonly property bool idleNotch: String(ic.idle || "hidden") === "notch"
  readonly property bool showMusic: ic.music !== false
  readonly property bool showHud: ic.hud === true
  readonly property bool showPower: ic.battery !== false
  readonly property bool showBluetooth: ic.bluetooth !== false
  readonly property bool showFocus: ic.focus !== false
  // Paroles sous l'île (remplacent la ligne de paroles de la barre).
  readonly property bool showLyrics: ic.lyrics !== false

  FileView {
    path: Quickshell.env("HOME") + "/.config/liquid-glass/config.json"
    watchChanges: true
    onFileChanged: reload()
    onLoaded: { try { root.cfg = JSON.parse(text()) } catch (e) {} }
  }

  // ------------------------------------------------------------ musique
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
    return playing || spotify || (ps.length ? ps[0] : null)
  }
  readonly property bool hasTrack: !!player && String(player.trackTitle || "") !== ""
  readonly property bool playing: hasTrack && player.isPlaying
  // La musique reste dans l'île 20 s après la pause, puis l'île se replie.
  property bool musicLinger: false
  onPlayingChanged: { if (playing) musicLinger = true; else lingerTimer.restart() }
  Timer { id: lingerTimer; interval: 20000; onTriggered: root.musicLinger = root.playing }
  readonly property bool musicActive: showMusic && hasTrack && (playing || musicLinger)

  property var np: ({})
  FileView {
    path: Quickshell.env("HOME") + "/.cache/liquid-glass/now-playing.json"
    watchChanges: true
    onFileChanged: reload()
    onLoaded: { try { root.np = JSON.parse(text()) } catch (e) {} }
  }
  // Pochette locale uniquement (jamais d'URL réseau dans une Image).
  readonly property string cover: {
    if (!hasTrack) return ""
    if (np.title === player.trackTitle && np.cover) return "file://" + np.cover
    var a = String(player.trackArtUrl || "")
    return a.indexOf("file://") === 0 ? a : ""
  }
  readonly property color accent: {
    var pal = hasTrack && np.title === player.trackTitle ? np.palette : null
    return pal && pal.accent ? pal.accent : "#ff375f"
  }

  property real pos: 0
  readonly property real len: player && player.lengthSupported ? player.length : 0
  Timer {
    interval: 1000; repeat: true; triggeredOnStart: true
    running: root.expanded && root.hasTrack
    onTriggered: { if (root.player) { root.player.positionChanged(); root.pos = root.player.position } }
  }
  // ---- paroles synchronisées (now-playing.json de liquid-glass.spotify)
  readonly property var lyrics: hasTrack && np.title === player.trackTitle && Array.isArray(np.lyrics) ? np.lyrics : []
  property int lineIndex: -1
  readonly property string lyricLine: lineIndex >= 0 && lineIndex < lyrics.length ? String(lyrics[lineIndex].text || "") : ""
  // Les paroles s'affichent DANS l'île (qui s'élargit, comme une activité en direct) :
  // rien ne déborde sur les fenêtres.
  readonly property bool lyricsShown: showLyrics && playing && lyrics.length > 0 && lyricLine !== "" && state_ === "music"
  TextMetrics { id: lyricMetrics; font.family: "Inter"; font.pixelSize: 12; font.weight: Font.DemiBold; text: root.lyricLine }
  Timer {
    interval: 250; repeat: true; triggeredOnStart: true
    running: root.showLyrics && root.playing && root.lyrics.length > 0
    onTriggered: {
      if (!root.player) return
      root.player.positionChanged()
      var t = root.player.position + 0.25, i = -1
      while (i + 1 < root.lyrics.length && root.lyrics[i + 1].t <= t) i++
      root.lineIndex = i
    }
  }
  function fmt(s) {
    s = Math.max(0, Math.floor(s || 0))
    return Math.floor(s / 60) + ":" + ("0" + (s % 60)).slice(-2)
  }

  // ------------------------------------------------------------ événements
  // { kind, icon (codepoint), title, detail, color, value (0..1 ou -1) }
  property var event: null
  function flash(ev) { event = ev; eventTimer.restart() }
  Timer { id: eventTimer; interval: 2600; onTriggered: root.event = null }

  // Secteur
  property bool lastOnBattery: UPower.onBattery
  readonly property var bat: UPower.displayDevice
  Connections {
    target: UPower
    function onOnBatteryChanged() {
      if (!root.showPower || UPower.onBattery === root.lastOnBattery) return
      root.lastOnBattery = UPower.onBattery
      var pct = root.bat && root.bat.ready ? Math.round(root.bat.percentage * 100) : -1
      root.flash({ kind: "power", icon: UPower.onBattery ? 0xF0079 : 0xF0084,
                   title: UPower.onBattery ? T.t("Sur batterie") : T.t("En charge"),
                   detail: pct >= 0 ? pct + " %" : "", color: UPower.onBattery ? "#ffffff" : "#30d158",
                   value: pct >= 0 ? pct / 100 : -1 })
    }
  }

  // Casque / appareil Bluetooth connecté
  readonly property var btDevices: Bluetooth.defaultAdapter && Bluetooth.defaultAdapter.devices ? Bluetooth.defaultAdapter.devices.values : []
  property var btSeen: ({})
  onBtDevicesChanged: btScan()
  Timer { interval: 2000; repeat: true; running: root.showBluetooth; onTriggered: root.btScan() }
  property bool btPrimed: false
  function btScan() {
    var now = ({})
    for (var i = 0; i < btDevices.length; i++) {
      var d = btDevices[i]
      if (!d || !d.connected) continue
      var key = String(d.address || d.name || i)
      now[key] = true
      if (btPrimed && !btSeen[key] && showBluetooth) {
        var b = d.batteryAvailable ? Math.round(d.battery * 100) : -1
        flash({ kind: "bt", icon: 0xF02CB, title: String(d.name || T.t("Appareil")).slice(0, 40),
                detail: b >= 0 ? b + " %" : "Connecté", color: "#0a84ff", value: b >= 0 ? b / 100 : -1 })
      }
    }
    btSeen = now
    btPrimed = true
  }

  // Concentration (fichier écrit par `liquid-glass focus`)
  property string focusMode: ""
  readonly property var focusNames: ({ "off": "Concentration désactivée", "dnd": "Ne pas déranger", "work": "Travail", "personal": "Personnel", "sleep": "Sommeil" })
  FileView {
    path: Quickshell.env("HOME") + "/.cache/liquid-glass/focus"
    printErrors: false
    watchChanges: true
    onFileChanged: reload()
    onLoaded: {
      var m = String(text() || "").trim()
      if (root.focusMode !== "" && m !== root.focusMode && root.showFocus && root.focusNames[m])
        root.flash({ kind: "focus", icon: m === "off" ? 0xF0594 : 0xF0594, title: root.focusNames[m],
                     detail: m === "off" ? "" : "Activé", color: m === "off" ? "#8e8e93" : "#5e5ce6", value: -1 })
      root.focusMode = m
    }
  }

  // Volume (option : l'OSD Liquid Glass s'en occupe par défaut)
  readonly property var sink: Pipewire.defaultAudioSink
  PwObjectTracker { objects: root.sink ? [root.sink] : [] }
  property real lastVol: -1
  readonly property real vol: sink && sink.audio ? sink.audio.volume : -1
  readonly property bool muted: sink && sink.audio ? sink.audio.muted : false
  onVolChanged: volEvent()
  onMutedChanged: volEvent()
  function volEvent() {
    if (vol < 0) return
    if (lastVol < 0) { lastVol = vol; return }
    lastVol = vol
    if (!showHud) return
    flash({ kind: "volume", icon: muted || vol === 0 ? 0xF075F : (vol < 0.4 ? 0xF057F : 0xF057E),
            title: "Volume", detail: muted ? T.t("Muet") : Math.round(vol * 100) + " %", color: "#ffffff", value: muted ? 0 : Math.min(1, vol) })
  }

  // ------------------------------------------------------------ état de l'île
  property bool hovered: false
  property bool expanded: false        // panneau ouvert (clic)
  readonly property bool hasEvent: event !== null
  readonly property bool visibleIsland: enabled && (expanded || hasEvent || musicActive || idleNotch || hovered)
  readonly property string state_: expanded ? "open" : (hasEvent ? "event" : (hovered && musicActive ? "hover" : (musicActive ? "music" : "idle")))

  readonly property real barH: Mac.menuBar.height
  readonly property real targetW: state_ === "open" ? 400 : state_ === "event" ? 300 : state_ === "hover" ? 320 : state_ === "music" ? (lyricsShown ? Math.min(460, Math.max(236, lyricMetrics.advanceWidth + 100)) : 236) : 190
  readonly property real targetH: state_ === "open" ? 150 : state_ === "event" ? 40 : state_ === "hover" ? 40 : barH
  readonly property real targetR: state_ === "open" ? 30 : (targetH > barH ? 20 : 11)

  Timer { id: closeTimer; interval: 600; onTriggered: if (!root.hovered) root.expanded = false }

  // omarchy-shell liquid-glass.island toggle | close | test
  ShellIpc {
    target: "liquid-glass.island"
    function toggle(): void { if (root.hasTrack) root.expanded = !root.expanded }
    function close(): void { root.expanded = false }
    function test(): void { root.flash({ kind: "power", icon: 0xF0084, title: T.t("En charge"), detail: "72 %", color: "#30d158", value: 0.72 }) }
  }

  // ------------------------------------------------------------ fenêtre
  Variants {
    model: Quickshell.screens.length ? [Quickshell.screens[0]] : []
    delegate: Component {
      PanelWindow {
        id: win
        required property var modelData
        screen: modelData
        anchors { top: true }
        implicitWidth: 440
        implicitHeight: 170
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "liquid-glass-island"
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
        // Seule l'île reçoit la souris ; le reste de la fenêtre laisse passer les clics.
        mask: Region { item: island }

        Rectangle {
          id: island
          anchors.horizontalCenter: parent.horizontalCenter
          y: 0
          width: root.visibleIsland ? root.targetW : 120
          height: root.visibleIsland ? root.targetH : 0
          radius: root.targetR
          color: "#000000"
          opacity: root.visibleIsland ? 1 : 0
          // Coins du haut carrés (l'île sort du bord de l'écran, comme l'encoche).
          Rectangle { anchors.top: parent.top; width: parent.width; height: Math.min(parent.radius, parent.height); color: "#000000"; visible: parent.height > 0 }

          Behavior on width { SpringAnimation { spring: 3.4; damping: 0.26; epsilon: 0.3 } }
          Behavior on height { SpringAnimation { spring: 3.4; damping: 0.28; epsilon: 0.3 } }
          Behavior on radius { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
          Behavior on opacity { NumberAnimation { duration: 180 } }

          layer.enabled: true
          layer.effect: MultiEffect { shadowEnabled: root.expanded; shadowBlur: 0.8; shadowOpacity: 0.35; shadowVerticalOffset: 4 }

          MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            onEntered: { root.hovered = true; closeTimer.stop() }
            onExited: { root.hovered = false; if (root.expanded) closeTimer.restart() }
            onClicked: function(m) {
              if (m.button === Qt.RightButton) { Quickshell.execDetached(["omarchy-shell", "liquid-glass.settings", "openPage", "menubar"]); return }
              if (root.hasTrack) root.expanded = !root.expanded
            }
            onWheel: function(w) {
              // Balayage horizontal : morceau suivant / précédent ; molette : volume.
              if (Math.abs(w.angleDelta.x) > Math.abs(w.angleDelta.y) && Math.abs(w.angleDelta.x) > 40 && root.player) {
                if (!swipeLock.running) { swipeLock.start(); if (w.angleDelta.x < 0) root.player.next(); else root.player.previous() }
              } else if (root.sink && root.sink.audio && w.angleDelta.y !== 0) {
                root.sink.audio.volume = Math.max(0, Math.min(1, root.sink.audio.volume + (w.angleDelta.y > 0 ? 0.05 : -0.05)))
              }
            }
            Timer { id: swipeLock; interval: 600 }
          }

          // ---- Contenu compact : pochette + égaliseur (musique) ou événement
          Item {
            id: compact
            anchors.fill: parent
            anchors.leftMargin: 10; anchors.rightMargin: 12
            opacity: root.state_ === "music" || root.state_ === "hover" || root.state_ === "event" ? 1 : 0
            visible: opacity > 0
            Behavior on opacity { NumberAnimation { duration: 160 } }

            // Pochette ou icône d'événement
            Item {
              id: lead
              anchors.left: parent.left
              anchors.verticalCenter: parent.verticalCenter
              width: root.state_ === "event" ? 26 : (root.state_ === "hover" ? 28 : 18)
              height: width
              Behavior on width { SpringAnimation { spring: 4; damping: 0.3 } }
              ClippingRectangle {
                anchors.fill: parent
                radius: width * 0.25
                color: "transparent"
                visible: root.state_ !== "event" && root.cover !== ""
                Image {
                  anchors.fill: parent
                  source: root.cover
                  sourceSize: Qt.size(64, 64)
                  fillMode: Image.PreserveAspectCrop
                  smooth: true; mipmap: true
                }
              }
              Text {
                anchors.centerIn: parent
                visible: root.state_ === "event"
                textFormat: Text.PlainText
                text: root.event ? String.fromCodePoint(root.event.icon) : ""
                font.family: Style.font.family; font.pixelSize: 18
                color: root.event ? root.event.color : "white"
              }
            }

            // Titre (survol) ou texte de l'événement
            Column {
              anchors.left: lead.right; anchors.leftMargin: 9
              anchors.right: tail.left; anchors.rightMargin: 8
              anchors.verticalCenter: parent.verticalCenter
              visible: root.state_ === "hover" || root.state_ === "event"
              spacing: 0
              Text {
                width: parent.width; elide: Text.ElideRight
                textFormat: Text.PlainText
                text: root.state_ === "event" ? (root.event ? root.event.title : "") : (root.hasTrack ? root.player.trackTitle : "")
                font.family: "Inter"; font.pixelSize: 12; font.weight: Font.DemiBold
                color: "white"
              }
              Text {
                width: parent.width; elide: Text.ElideRight
                visible: text !== ""
                textFormat: Text.PlainText
                text: root.state_ === "event" ? (root.event ? root.event.detail : "") : (root.hasTrack ? (root.player.trackArtist || "") : "")
                font.family: "Inter"; font.pixelSize: 11
                color: Qt.rgba(1, 1, 1, 0.6)
              }
            }

            // Ligne de paroles (musique) : chaque nouvelle ligne monte en place.
            Item {
              id: lyricBox
              anchors.left: lead.right; anchors.leftMargin: 10
              anchors.right: tail.left; anchors.rightMargin: 10
              anchors.verticalCenter: parent.verticalCenter
              height: parent.height
              clip: true
              opacity: root.lyricsShown ? 1 : 0
              visible: opacity > 0.01
              Behavior on opacity { NumberAnimation { duration: 220 } }
              readonly property string line: root.lyricLine
              property real shift: 0
              onLineChanged: lineAnim.restart()
              SequentialAnimation {
                id: lineAnim
                PropertyAction { target: lyricBox; property: "shift"; value: 12 }
                NumberAnimation { target: lyricBox; property: "shift"; to: 0; duration: 380; easing.type: Easing.OutBack; easing.overshoot: 1.6 }
              }
              Text {
                width: parent.width
                y: (parent.height - height) / 2 + lyricBox.shift
                horizontalAlignment: Text.AlignHCenter
                elide: Text.ElideRight
                textFormat: Text.PlainText
                text: lyricBox.line
                font.family: "Inter"; font.pixelSize: 12; font.weight: Font.DemiBold
                color: "white"
                opacity: 1 - Math.abs(lyricBox.shift) / 12
              }
            }

            // Égaliseur (musique) ou jauge (événement chiffré)
            Item {
              id: tail
              anchors.right: parent.right
              anchors.verticalCenter: parent.verticalCenter
              width: root.state_ === "event" ? (root.event && root.event.value >= 0 ? 60 : 0) : 22
              height: 16

              Row {
                anchors.centerIn: parent
                visible: root.state_ !== "event"
                spacing: 2.5
                Repeater {
                  model: 4
                  delegate: Rectangle {
                    id: eqBar
                    required property int index
                    property real level: 0.3
                    width: 3; radius: 1.5
                    height: Math.max(3, 16 * level)
                    anchors.verticalCenter: parent.verticalCenter
                    color: root.accent
                    Behavior on height { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
                    Timer {
                      interval: 150 + index * 23; repeat: true
                      running: root.playing && compact.visible
                      onTriggered: eqBar.level = 0.25 + Math.random() * 0.75
                    }
                    Connections { target: root; function onPlayingChanged() { if (!root.playing) eqBar.level = 0.2 } }
                  }
                }
              }
              Rectangle {
                visible: root.state_ === "event" && root.event && root.event.value >= 0
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width; height: 5; radius: 2.5
                color: Qt.rgba(1, 1, 1, 0.22)
                Rectangle {
                  width: parent.width * (root.event && root.event.value >= 0 ? root.event.value : 0)
                  height: parent.height; radius: parent.radius
                  color: root.event ? root.event.color : "white"
                  Behavior on width { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
                }
              }
            }
          }

          // ---- Panneau ouvert : grande pochette, titre, progression, commandes
          Item {
            id: openView
            anchors.fill: parent
            anchors.margins: 16
            anchors.topMargin: 14
            opacity: root.state_ === "open" ? 1 : 0
            visible: opacity > 0
            Behavior on opacity { NumberAnimation { duration: 200 } }

            Item {
              id: bigArtBox
              width: 84; height: 84
              anchors.verticalCenter: parent.verticalCenter
              Image {
                id: bigArt
                anchors.fill: parent; visible: false
                source: root.cover
                sourceSize: Qt.size(256, 256)
                fillMode: Image.PreserveAspectCrop
              }
              Rectangle { id: bigMask; anchors.fill: parent; radius: 16; visible: false; layer.enabled: true }
              MultiEffect { anchors.fill: parent; source: bigArt; maskEnabled: true; maskSource: bigMask
                            shadowEnabled: true; shadowColor: root.accent; shadowBlur: 1.0; shadowOpacity: 0.55 }
            }

            Column {
              anchors.left: bigArtBox.right; anchors.leftMargin: 16
              anchors.right: parent.right
              anchors.verticalCenter: parent.verticalCenter
              spacing: 6

              Text {
                width: parent.width; elide: Text.ElideRight
                textFormat: Text.PlainText
                text: root.hasTrack ? root.player.trackTitle : ""
                font.family: "Inter"; font.pixelSize: 15; font.weight: Font.Bold
                color: "white"
              }
              Text {
                width: parent.width; elide: Text.ElideRight
                textFormat: Text.PlainText
                text: root.hasTrack ? [root.player.trackArtist, root.player.trackAlbum].filter(function(s) { return !!s }).join(" — ") : ""
                font.family: "Inter"; font.pixelSize: 12
                color: Qt.rgba(1, 1, 1, 0.6)
              }

              // Progression (cliquable si le lecteur sait avancer)
              Item {
                width: parent.width; height: 16
                Rectangle {
                  id: track
                  anchors.verticalCenter: parent.verticalCenter
                  width: parent.width; height: 4; radius: 2
                  color: Qt.rgba(1, 1, 1, 0.2)
                  Rectangle {
                    width: root.len > 0 ? parent.width * Math.min(1, root.pos / root.len) : 0
                    height: parent.height; radius: 2; color: "white"
                  }
                }
                MouseArea {
                  anchors.fill: parent
                  enabled: !!root.player && root.player.canSeek && root.len > 0
                  cursorShape: Qt.PointingHandCursor
                  onClicked: function(m) { root.player.position = (m.x / width) * root.len; root.pos = root.player.position }
                }
              }
              Item {
                width: parent.width; height: 12
                Text { textFormat: Text.PlainText; text: root.fmt(root.pos); font.family: "Inter"; font.pixelSize: 10; font.features: { "tnum": 1 }; color: Qt.rgba(1, 1, 1, 0.5) }
                Text { anchors.right: parent.right; textFormat: Text.PlainText; text: "-" + root.fmt(root.len - root.pos); font.family: "Inter"; font.pixelSize: 10; font.features: { "tnum": 1 }; color: Qt.rgba(1, 1, 1, 0.5) }
              }

              Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 26
                Repeater {
                  model: [[0xF04AE, "prev"], [root.playing ? 0xF03E4 : 0xF040A, "play"], [0xF04AD, "next"]]
                  delegate: Text {
                    required property var modelData
                    textFormat: Text.PlainText
                    text: String.fromCodePoint(modelData[0])
                    font.family: Style.font.family; font.pixelSize: modelData[1] === "play" ? 24 : 20
                    color: "white"
                    scale: ctl.pressed ? 0.82 : 1
                    Behavior on scale { SpringAnimation { spring: 5; damping: 0.25 } }
                    MouseArea {
                      id: ctl
                      anchors.fill: parent; anchors.margins: -6
                      cursorShape: Qt.PointingHandCursor
                      onClicked: {
                        if (!root.player) return
                        if (modelData[1] === "prev") root.player.previous()
                        else if (modelData[1] === "next") root.player.next()
                        else root.player.togglePlaying()
                      }
                    }
                  }
                }
              }
            }
          }
        }
      }
    }
  }
}
