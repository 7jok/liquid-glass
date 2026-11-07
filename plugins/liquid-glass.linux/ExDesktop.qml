import QtQuick
import QtQuick.Effects
import QtQuick.Shapes
import Quickshell
import Quickshell.Services.UPower
import Quickshell.Wayland
import Quickshell.Widgets

// Widgets du bureau façon end4-pC (Material 3 Expressive), posés sur le fond,
// sous les fenêtres. Chacun se déplace à la souris : il glisse sur son élan,
// puis s'aimante à la grille de 8 px avec un rebond (positions gardées dans
// ~/.config/liquid-glass/linux-layout.json ; `omarchy-shell liquid-glass.linux
// resetLayout` les remet en place).
// Le jeu de widgets et leur place par défaut dépendent du style :
//   expressive : horloge « cookie », musique + paroles, météo, système, utilisateur, semaine, à faire
//   blanc      : jour en capitales larges, horloge pixel, musique vinyle, météo, système, à faire
//   sombre     : horloge pixel, jour (kanji), musique vinyle, système
//   jouet      : horloge pixel arc-en-ciel, musique, météo, système, à faire (cartes penchées)
//   violet     : grosse horloge « bonbon » empilée, anneau de batterie ondulé, musique, météo, système, à faire
// Chaque widget peut être masqué : [linux] w_<nom> = false (Réglages → Bureau Linux).
PanelWindow {
  id: win
  property var service: null
  readonly property var s: service

  color: "transparent"
  anchors { top: true; bottom: true; left: true; right: true }
  exclusionMode: ExclusionMode.Normal
  WlrLayershell.layer: WlrLayer.Bottom
  WlrLayershell.namespace: "liquid-glass-linux-desktop"
  // OnDemand : la saisie d'une tâche reçoit le clavier après un clic.
  WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
  mask: Region {
    Region { item: clockW.visible ? clockW : null }
    Region { item: musicW.visible ? musicW : null }
    Region { item: weatherW.visible ? weatherW : null }
    Region { item: sysW.visible ? sysW : null }
    Region { item: userW.visible ? userW : null }
    Region { item: weekW.visible ? weekW : null }
    Region { item: todoW.visible ? todoW : null }
    Region { item: stackW.visible ? stackW : null }
    Region { item: pixW.visible ? pixW : null }
    Region { item: dayW.visible ? dayW : null }
    Region { item: ringW.visible ? ringW : null }
  }

  // ------------------------------------------------------------ par style
  readonly property string st: s.style
  readonly property var sets: ({
    expressive: ["clock", "music", "weather", "system", "user", "week", "todo"],
    blanc:      ["day", "pixclock", "music", "weather", "system", "todo"],
    sombre:     ["pixclock", "day", "music", "system"],
    jouet:      ["pixclock", "music", "weather", "system", "todo"],
    violet:     ["stack", "ring", "music", "weather", "system", "todo"],
    gouts:      ["stack", "music", "weather", "system", "todo"]
  })
  function shown(k) { var l = sets[st] || sets.blanc; return l.indexOf(k) >= 0 && s.opt("w_" + k, true) !== false }
  // Places par défaut (x, y) : négatif = depuis la droite / le bas, "c" = centré.
  readonly property var layouts: ({
    expressive: { clock: [28, 20], music: [16, 262], weather: [-16, 16], system: [-16, 114], user: [-16, 210], week: [-16, 368], todo: [-16, 466] },
    blanc:      { day: [40, 36], pixclock: [-32, 28], music: [24, -24], weather: [-32, 176], system: [-32, 276], todo: [-32, 372] },
    sombre:     { pixclock: [40, 40], day: [46, 196], music: [24, -24], system: [-28, -28] },
    jouet:      { pixclock: [40, 36], music: [28, -28], weather: [-28, 28], system: [-28, 130], todo: [-28, 232] },
    gouts:      { stack: ["c", 30], music: [24, 24], weather: [-24, 24], system: [-24, 124], todo: [-24, 220] },
    violet:     { stack: ["c", 30], ring: ["c", 350], music: [24, 24], weather: [-24, 24], system: [-24, 124], todo: [-24, 220] }
  })
  function defPos(k) { var l = layouts[st] || layouts.blanc; return l[k] || [24, 24] }
  // Musique : disque vinyle (+ anneau cava) sauf en expressive ; paroles dans la carte en mode « card ».
  readonly property bool vinyl: st !== "expressive"
  readonly property bool cardLyrics: s.lyricsMode === "card"
  readonly property color ink: st === "jouet" ? "#1b1030" : s.colOnSurface
  readonly property bool charging: !!s.battery && s.battery.state === UPowerDeviceState.Charging

  property date now: new Date()
  Timer { interval: 1000; repeat: true; running: true; onTriggered: win.now = new Date() }

  function run(cmd) { Quickshell.execDetached(["sh", "-c", cmd]) }
  function cap(t) { t = String(t); return t.charAt(0).toUpperCase() + t.slice(1) }

  Item {
    id: desk
    anchors.fill: parent
    property int topZ: 1

    // ====================================================== horloge cookie
    DeskItem {
      id: clockW
      key: "clock"
      width: 184; height: 222
      Item {
        id: clock
        width: 184; height: 184
        readonly property real r: width / 2
        readonly property int secs: win.now.getHours() * 3600 + win.now.getMinutes() * 60 + win.now.getSeconds()
        Cookie {
          anchors.fill: parent
          lobes: 10; depth: 0.06
          color: win.s.secondaryContainer
        }
        Repeater {
          model: [[12, 0], [3, 90], [6, 180], [9, 270]]
          delegate: Text {
            required property var modelData
            readonly property real a: modelData[1] * Math.PI / 180
            x: clock.r + Math.sin(a) * clock.r * 0.6 - width / 2
            y: clock.r - Math.cos(a) * clock.r * 0.6 - height / 2
            text: String(modelData[0])
            font.family: win.s.numFont
            font.pixelSize: 34
            font.weight: Font.Bold
            color: win.s.alpha(win.s.colOnSecondaryContainer, 0.22)
          }
        }
        Hand { len: clock.r * 0.42; thick: 13; color: win.s.tertiary; angle: (clock.secs / 120) % 360 }
        Hand { len: clock.r * 0.66; thick: 10; color: win.s.primary; angle: (clock.secs / 10) % 360 }
        // Trotteuse : un point qui fait le tour, chaque seconde avec un petit rebond.
        Item {
          anchors.fill: parent
          property real ang: clock.secs * 6
          Behavior on ang { NumberAnimation { duration: 380; easing.type: Easing.OutBack; easing.overshoot: 2 } }
          rotation: ang
          Rectangle {
            width: 10; height: 10; radius: 5
            x: clock.r - 5
            y: clock.r - clock.r * 0.8 - 5
            color: win.s.primary
          }
        }
        Rectangle {
          anchors.centerIn: parent
          width: 8; height: 8; radius: 4
          color: win.s.colOnSecondaryContainer
        }
        // Jour (pentagone doux) et mois (cercle), comme end4.
        Cookie {
          x: -6; y: 4
          width: 50; height: 50
          lobes: 5; depth: 0.1; spin: Math.PI
          color: win.s.tertiaryContainer
          Text {
            anchors.centerIn: parent
            text: Qt.formatDate(win.now, "dd")
            font.family: win.s.numFont
            font.pixelSize: 18
            font.weight: Font.Bold
            color: win.s.colOnTertiaryContainer
          }
        }
        Rectangle {
          x: clock.width - 38; y: clock.height - 40
          width: 42; height: 42; radius: 21
          color: win.s.surfaceHighest
          Text {
            anchors.centerIn: parent
            text: Qt.formatDate(win.now, "MM")
            font.family: win.s.numFont
            font.pixelSize: 16
            font.weight: Font.DemiBold
            color: win.s.colOnSurface
          }
        }
      }
      // Citation du jour
      Rectangle {
        readonly property var quotes: ["Tiens bon !", "Un pas après l'autre.", "Reste curieux.", "Fais simple.", "Respire un coup.",
          "Ça compile ? On y va.", "Le café d'abord.", "Garde le cap.", "Petit à petit.", "Sois fier de toi."]
        anchors.horizontalCenter: parent.horizontalCenter
        y: clock.height + 12
        height: 26
        width: qRow.implicitWidth + 20
        radius: 9
        color: win.s.surfaceHigh
        Row {
          id: qRow
          anchors.centerIn: parent
          spacing: 5
          MIcon { icon: "format_quote"; size: 14; fill: 1; color: win.s.primary; anchors.verticalCenter: parent.verticalCenter }
          Text {
            anchors.verticalCenter: parent.verticalCenter
            text: parent.parent.quotes[Math.floor(win.now.getTime() / 86400000) % parent.parent.quotes.length]
            font.family: win.s.sansFont
            font.pixelSize: 12
            font.weight: Font.Medium
            color: win.s.colOnSurface
          }
        }
      }
    }

    // ====================================================== musique + paroles
    DeskItem {
      id: musicW
      key: "music"
      bumpy: true
      width: 290; height: win.cardLyrics ? 250 : 206
      Card {
        anchors.fill: parent
        color: win.s.surfaceMid

        // Fond : la pochette très floutée, en filigrane.
        ClippingRectangle {
          anchors.fill: parent
          radius: parent.radius
          color: "transparent"
          visible: win.s.cover !== ""
          Image {
            anchors.fill: parent
            source: win.s.cover
            fillMode: Image.PreserveAspectCrop
            sourceSize.width: 64
            opacity: 0.22
            layer.enabled: true
            layer.effect: MultiEffect { blurEnabled: true; blur: 1.0; blurMax: 32 }
          }
        }

        // Vinyle : disque qui tourne, pochette au centre, anneau cava autour.
        Item {
          id: disc
          visible: win.vinyl
          x: 6; y: 6
          width: 104; height: 104
          readonly property real r: 36
          Repeater {
            model: disc.visible ? 40 : 0
            delegate: Rectangle {
              required property int index
              readonly property int n: win.s.cavaValues.length
              readonly property real v: n > 0 ? win.s.cavaValues[Math.floor(index / 40 * n)] / 100 : 0
              readonly property real len: 2 + v * 13
              width: 2.5; height: len; radius: 1.25
              x: disc.width / 2 - width / 2
              y: disc.height / 2 - disc.r - 3 - len
              color: win.s.vizColor(index, 40)
              opacity: 0.35 + v * 0.65
              transform: Rotation { origin.x: 1.25; origin.y: disc.r + 3 + len; angle: index * 9 }
            }
          }
          Rectangle {
            id: record
            anchors.centerIn: parent
            width: disc.r * 2; height: width; radius: width / 2
            color: "#141016"
            border.width: win.st === "jouet" ? 2 : 0
            border.color: "#1b1030"
            RotationAnimation on rotation { from: 0; to: 360; duration: 6000; loops: Animation.Infinite; running: win.s.playing && disc.visible }
            // Sillons
            Repeater {
              model: 4
              delegate: Rectangle {
                required property int index
                anchors.centerIn: parent
                width: parent.width - 8 - index * 7; height: width; radius: width / 2
                color: "transparent"
                border.width: 1
                border.color: Qt.rgba(1, 1, 1, 0.07)
              }
            }
            ClippingRectangle {
              anchors.centerIn: parent
              width: 34; height: 34; radius: 17
              color: win.s.primary
              Image {
                anchors.fill: parent
                source: win.s.cover
                fillMode: Image.PreserveAspectCrop
                sourceSize.width: 96
                asynchronous: true
              }
            }
            Rectangle { anchors.centerIn: parent; width: 5; height: 5; radius: 2.5; color: "#141016" }
            // Reflet
            Rectangle {
              x: 8; y: 6; width: parent.width * 0.4; height: 3; radius: 1.5; rotation: -35
              color: Qt.rgba(1, 1, 1, 0.12)
            }
          }
        }

        ClippingRectangle {
          id: art
          visible: !win.vinyl
          x: 10; y: 10
          width: win.vinyl ? 100 : 84; height: win.vinyl ? 100 : 84
          radius: 18
          color: win.s.surfaceHighest
          Image {
            anchors.fill: parent
            source: win.s.cover
            fillMode: Image.PreserveAspectCrop
            sourceSize.width: 168
            asynchronous: true
          }
          MIcon {
            anchors.centerIn: parent
            visible: win.s.cover === ""
            icon: "music_note"; size: 34; fill: 1
            color: win.s.colOnSurfaceVariant
          }
        }
        Column {
          x: (win.vinyl ? disc.x + disc.width : art.x + art.width) + 12
          y: 14
          width: parent.width - x - 12
          spacing: 1
          Text {
            width: parent.width
            text: win.s.trackTitle !== "" ? win.s.trackTitle : "Rien en lecture"
            elide: Text.ElideRight
            font.family: win.s.sansFont
            font.pixelSize: 15
            font.weight: Font.DemiBold
            color: win.s.colOnSurface
          }
          Text {
            width: parent.width
            text: win.s.resumeMode ? "Reprendre · " + win.s.trackArtist : (win.s.trackArtist !== "" ? win.s.trackArtist : "Lance Spotify ♪")
            elide: Text.ElideRight
            font.family: win.s.sansFont
            font.pixelSize: 12
            color: win.s.colOnSurfaceVariant
          }
        }
        // Commandes : précédent · lecture dans une fleur qui tourne · suivant
        Row {
          x: (win.vinyl ? disc.x + disc.width : art.x + art.width) + 8
          y: win.vinyl ? disc.y + disc.height - 46 : art.y + art.height - 40
          spacing: 4
          RoundBtn { icon: "skip_previous"; enabled: win.s.hasTrack; onClicked: win.s.player.previous() }
          Item {
            width: 40; height: 40
            anchors.verticalCenter: parent.verticalCenter
            Cookie {
              id: playCookie
              anchors.fill: parent
              lobes: 8; depth: 0.1
              color: win.s.primary
              scale: playMouse.pressed ? 0.86 : (playMouse.containsMouse ? 1.08 : 1)
              Behavior on scale { NumberAnimation { duration: 320; easing.type: Easing.OutBack; easing.overshoot: 3 } }
              RotationAnimation on rotation { from: 0; to: 360; duration: 12000; loops: Animation.Infinite; running: win.s.playing }
            }
            MIcon { anchors.centerIn: parent; icon: win.s.playing ? "pause" : "play_arrow"; size: 22; fill: 1; color: win.s.colOnPrimary }
            MouseArea { id: playMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: win.s.playPause() }
          }
          RoundBtn { icon: "skip_next"; enabled: win.s.hasTrack; onClicked: win.s.player.next() }
        }

        // Progression ondulée (M3 Expressive) : la partie écoutée ondule pendant la lecture.
        Item {
          id: prog
          x: 14; y: (win.vinyl ? disc.y + disc.height : art.y + art.height) + 10
          width: parent.width - 28
          height: 14
          visible: win.s.hasTrack && win.s.length > 0
          property real phase: 0
          NumberAnimation on phase { from: 0; to: Math.PI * 2; duration: 1600; loops: Animation.Infinite; running: win.s.playing && prog.visible }
          readonly property real split: width * win.s.progress
          Shape {
            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer
            ShapePath {
              strokeColor: win.s.primary
              strokeWidth: 3
              capStyle: ShapePath.RoundCap
              fillColor: "transparent"
              PathPolyline {
                path: {
                  var pts = [], amp = win.s.playing ? 2.6 : 0.4, w = Math.max(2, prog.split - 4)
                  for (var x = 0; x <= w; x += 2) pts.push(Qt.point(x + 1.5, prog.height / 2 + Math.sin(x / 5 + prog.phase) * amp))
                  if (pts.length < 2) pts.push(Qt.point(2, prog.height / 2))
                  return pts
                }
              }
            }
          }
          Rectangle {
            x: prog.split + 4
            width: Math.max(0, prog.width - x)
            height: 3; radius: 1.5
            anchors.verticalCenter: parent.verticalCenter
            color: win.s.alpha(win.s.colOnSurface, 0.18)
          }
          Rectangle {
            x: prog.split - 2
            width: 4; height: 14; radius: 2
            color: win.s.primary
          }
        }

        // Paroles synchronisées : ligne chantée au centre, les autres en fondu.
        // Égaliseur (barres cava) quand les paroles ne sont pas dans la carte.
        Row {
          id: eq
          visible: !win.cardLyrics
          x: 14; y: prog.y + 22
          width: parent.width - 28
          height: parent.height - y - 14
          spacing: 3
          readonly property int count: 24
          Repeater {
            model: eq.visible ? eq.count : 0
            delegate: Item {
              required property int index
              readonly property int n: win.s.cavaValues.length
              readonly property real v: n > 0 ? win.s.cavaValues[Math.floor(index / eq.count * n)] / 100 : 0
              width: (eq.width - (eq.count - 1) * eq.spacing) / eq.count
              height: eq.height
              Rectangle {
                anchors.bottom: parent.bottom
                width: parent.width
                height: Math.max(3, parent.height * parent.v)
                radius: win.st === "blanc" || win.st === "sombre" ? 0 : width / 2
                color: win.s.vizColor(index, eq.count)
                Behavior on height { NumberAnimation { duration: 70 } }
              }
            }
          }
        }

        Item {
          id: lyr
          visible: win.cardLyrics
          x: 12; y: prog.y + 22
          width: parent.width - 24
          height: parent.height - y - 10
          clip: true
          ListView {
            id: lyrList
            anchors.fill: parent
            interactive: false
            model: win.s.lyrics
            currentIndex: Math.max(0, win.s.lineIndex)
            highlightRangeMode: ListView.StrictlyEnforceRange
            preferredHighlightBegin: height / 2 - 11
            preferredHighlightEnd: height / 2 + 11
            highlightMoveDuration: 420
            delegate: Text {
              required property var modelData
              required property int index
              readonly property bool cur: index === win.s.lineIndex
              width: lyrList.width
              height: 22
              text: String(modelData.text || "") || "♪"
              horizontalAlignment: Text.AlignHCenter
              verticalAlignment: Text.AlignVCenter
              elide: Text.ElideRight
              font.family: win.s.sansFont
              font.pixelSize: cur ? 14 : 12
              font.weight: cur ? Font.DemiBold : Font.Normal
              color: cur ? win.s.colOnSurface : win.s.alpha(win.s.colOnSurfaceVariant, Math.max(0.15, 0.6 - Math.abs(index - win.s.lineIndex) * 0.14))
              Behavior on color { ColorAnimation { duration: 260 } }
            }
          }
          Text {
            anchors.centerIn: parent
            visible: win.s.lyrics.length === 0
            text: win.s.hasTrack ? "Pas de paroles pour ce morceau" : "Les paroles s'afficheront ici"
            font.family: win.s.sansFont
            font.pixelSize: 12
            color: win.s.alpha(win.s.colOnSurfaceVariant, 0.6)
          }
        }
      }
    }

    // ====================================================== météo
    DeskItem {
      id: weatherW
      key: "weather"
      width: 284; height: 88
      Card {
        anchors.fill: parent
        color: win.s.primaryContainer
        Row {
          x: 16; y: 10
          spacing: 10
          Text {
            text: win.s.weather ? win.s.weather.temp + "°C" : "--°"
            font.family: win.s.numFont
            font.pixelSize: 32
            font.weight: Font.DemiBold
            color: win.s.colOnPrimaryContainer
          }
          Column {
            anchors.verticalCenter: parent.verticalCenter
            Text {
              text: win.s.weather ? win.cap(win.s.weatherDesc) : "Météo…"
              font.family: win.s.sansFont
              font.pixelSize: 13
              font.weight: Font.Medium
              color: win.s.colOnPrimaryContainer
            }
            Text {
              text: win.s.weather ? win.s.weather.city + " · " + win.s.weather.min + "° / " + win.s.weather.max + "°" : win.s.city
              font.family: win.s.sansFont
              font.pixelSize: 11
              color: win.s.alpha(win.s.colOnPrimaryContainer, 0.7)
            }
          }
        }
        Cookie {
          x: parent.width - 52; y: 8
          width: 42; height: 42
          lobes: 12; depth: 0.07
          color: win.s.primary
          RotationAnimation on rotation { from: 0; to: 360; duration: 30000; loops: Animation.Infinite; running: true }
        }
        MIcon { x: parent.width - 52; y: 8; width: 42; height: 42; icon: win.s.weatherIcon; size: 22; fill: 1; color: win.s.colOnPrimary }
        Row {
          x: 16; y: parent.height - 24
          spacing: 12
          Repeater {
            model: win.s.weather ? [["humidity_percentage", win.s.weather.humidity + "%"], ["umbrella", win.s.weather.rain + "%"],
                                    ["air", win.s.weather.wind + " km/h"], ["wb_twilight", win.s.weather.sunrise], ["bedtime", win.s.weather.sunset]] : []
            delegate: Row {
              required property var modelData
              spacing: 3
              MIcon { icon: parent.modelData[0]; size: 12; color: win.s.alpha(win.s.colOnPrimaryContainer, 0.75); anchors.verticalCenter: parent.verticalCenter }
              Text {
                text: parent.modelData[1]
                font.family: win.s.sansFont
                font.pixelSize: 10
                color: win.s.alpha(win.s.colOnPrimaryContainer, 0.75)
                anchors.verticalCenter: parent.verticalCenter
              }
            }
          }
        }
      }
    }

    // ====================================================== CPU / RAM / disque
    DeskItem {
      id: sysW
      key: "system"
      width: 284; height: 84
      Row {
        spacing: 8
        SysTile { label: "CPU"; value: win.s.cpu; icon: "memory"; bg: win.s.primaryContainer; fg: win.s.colOnPrimaryContainer; badge: win.s.primary; badgeFg: win.s.colOnPrimary }
        SysTile { label: "RAM"; value: win.s.memPct; icon: "memory_alt"; bg: win.s.secondaryContainer; fg: win.s.colOnSecondaryContainer; badge: win.s.secondary; badgeFg: win.s.surface }
        SysTile { label: "Disque"; value: win.s.diskPct; icon: "hard_drive"; bg: win.s.tertiaryContainer; fg: win.s.colOnTertiaryContainer; badge: win.s.tertiary; badgeFg: win.s.surface }
      }
    }

    // ====================================================== utilisateur
    DeskItem {
      id: userW
      key: "user"
      width: 226; height: 146
      Card {
        anchors.fill: parent
        color: win.s.surfaceMid
        ClippingRectangle {
          id: avatar
          x: 14; y: 14
          width: 46; height: 46
          radius: 23
          color: win.s.primaryContainer
          Image {
            anchors.fill: parent
            source: "file://" + win.s.home + "/.face"
            fillMode: Image.PreserveAspectCrop
            sourceSize.width: 92
            asynchronous: true
          }
        }
        Column {
          x: avatar.x + avatar.width + 10
          anchors.verticalCenter: avatar.verticalCenter
          width: parent.width - x - 12
          Text {
            width: parent.width
            text: win.s.user + "@" + (win.s.hostname || "linux")
            elide: Text.ElideRight
            font.family: win.s.sansFont
            font.pixelSize: 13
            font.weight: Font.DemiBold
            color: win.s.colOnSurface
          }
          Text {
            text: "Allumé · " + win.s.uptimeText
            font.family: win.s.sansFont
            font.pixelSize: 11
            color: win.s.colOnSurfaceVariant
          }
        }
        Row {
          x: 14; y: avatar.y + avatar.height + 10
          spacing: 5
          MIcon { icon: win.s.weatherIcon; size: 14; color: win.s.colOnSurfaceVariant; anchors.verticalCenter: parent.verticalCenter }
          Text {
            anchors.verticalCenter: parent.verticalCenter
            text: win.s.weather ? "• " + win.s.weatherDesc + " aujourd'hui" : "• " + win.cap(win.now.toLocaleDateString(Qt.locale("fr_FR"), "dddd d MMMM"))
            font.family: win.s.sansFont
            font.pixelSize: 11
            color: win.s.colOnSurfaceVariant
          }
        }
        Row {
          x: 14; y: parent.height - height - 12
          spacing: 6
          Rectangle {
            width: 112; height: 32; radius: 16
            color: lockMouse.containsMouse ? win.s.primary : win.s.primaryContainer
            Behavior on color { ColorAnimation { duration: 160 } }
            Row {
              anchors.centerIn: parent
              spacing: 5
              MIcon { icon: "lock"; size: 15; fill: 1; color: lockMouse.containsMouse ? win.s.colOnPrimary : win.s.colOnPrimaryContainer; anchors.verticalCenter: parent.verticalCenter }
              Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "Verrouiller"
                font.family: win.s.sansFont
                font.pixelSize: 12
                font.weight: Font.Medium
                color: lockMouse.containsMouse ? win.s.colOnPrimary : win.s.colOnPrimaryContainer
              }
            }
            MouseArea { id: lockMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: win.run("omarchy-system-lock") }
          }
          RoundBtn { size: 32; outlined: true; icon: "settings"; onClicked: win.run("omarchy-shell shell toggle liquid-glass.settings") }
          RoundBtn { size: 32; outlined: true; icon: "power_settings_new"; onClicked: s.toggleMenu("power") }
        }
      }
    }

    // ====================================================== semaine
    DeskItem {
      id: weekW
      key: "week"
      width: 226; height: 86
      Card {
        anchors.fill: parent
        color: win.s.surfaceMid
        Rectangle {
          x: 12; y: 10
          height: 22
          width: monthText.implicitWidth + 18
          radius: 11
          color: win.s.secondaryContainer
          Text {
            id: monthText
            anchors.centerIn: parent
            text: win.cap(win.now.toLocaleDateString(Qt.locale("fr_FR"), "MMMM yyyy"))
            font.family: win.s.sansFont
            font.pixelSize: 11
            font.weight: Font.DemiBold
            color: win.s.colOnSecondaryContainer
          }
        }
        Row {
          x: 8; y: 36
          Repeater {
            model: 7
            delegate: Column {
              required property int index
              readonly property date day: {
                var d = new Date(win.now.getFullYear(), win.now.getMonth(), win.now.getDate())
                var monday = (d.getDay() + 6) % 7
                d.setDate(d.getDate() - monday + index)
                return d
              }
              readonly property bool today: day.getDate() === win.now.getDate() && day.getMonth() === win.now.getMonth()
              width: 30
              spacing: 2
              Text {
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                text: ["Lu", "Ma", "Me", "Je", "Ve", "Sa", "Di"][parent.index]
                font.family: win.s.sansFont
                font.pixelSize: 10
                color: win.s.colOnSurfaceVariant
              }
              Item {
                width: parent.width; height: 24
                Rectangle {
                  anchors.centerIn: parent
                  width: 24; height: 24; radius: 12
                  color: win.s.primary
                  visible: parent.parent.today
                }
                Text {
                  anchors.centerIn: parent
                  text: String(parent.parent.day.getDate())
                  font.family: win.s.numFont
                  font.pixelSize: 12
                  font.weight: parent.parent.today ? Font.Bold : Font.Normal
                  color: parent.parent.today ? win.s.colOnPrimary : win.s.colOnSurface
                }
              }
            }
          }
        }
      }
    }

    // ====================================================== à faire
    DeskItem {
      id: todoW
      key: "todo"
      width: 226
      height: 48 + Math.max(1, Math.min(5, win.s.todos.length)) * 34 + (adding ? 36 : 0)
      property bool adding: false
      Behavior on height { NumberAnimation { duration: 320; easing.type: Easing.OutBack; easing.overshoot: 1.6 } }
      Card {
        anchors.fill: parent
        color: win.s.surfaceMid
        Text {
          x: 14; y: 12
          text: "À faire"
          font.family: win.s.sansFont
          font.pixelSize: 16
          font.weight: Font.Medium
          color: win.s.colOnSurface
        }
        Rectangle {
          x: parent.width - 40; y: 8
          width: 30; height: 30; radius: 10
          color: addMouse.containsMouse ? win.s.primary : win.s.primaryContainer
          rotation: todoW.adding ? 45 : 0
          Behavior on rotation { NumberAnimation { duration: 320; easing.type: Easing.OutBack; easing.overshoot: 2.5 } }
          Behavior on color { ColorAnimation { duration: 150 } }
          MIcon { anchors.centerIn: parent; icon: "add"; size: 18; color: addMouse.containsMouse ? win.s.colOnPrimary : win.s.colOnPrimaryContainer }
          MouseArea {
            id: addMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: { todoW.adding = !todoW.adding; if (todoW.adding) todoInput.forceActiveFocus(); else todoInput.text = "" }
          }
        }
        Column {
          x: 8; y: 44
          width: parent.width - 16
          spacing: 4
          Rectangle {
            visible: todoW.adding
            width: parent.width; height: 32; radius: 16
            color: win.s.surfaceHighest
            border.width: 1
            border.color: win.s.primary
            TextInput {
              id: todoInput
              anchors.fill: parent
              anchors.leftMargin: 14; anchors.rightMargin: 14
              verticalAlignment: TextInput.AlignVCenter
              font.family: win.s.sansFont
              font.pixelSize: 12
              color: win.s.colOnSurface
              selectionColor: win.s.primary
              clip: true
              Keys.onReturnPressed: { win.s.addTodo(text); text = ""; todoW.adding = false }
              Keys.onEscapePressed: { text = ""; todoW.adding = false }
              Text {
                anchors.verticalCenter: parent.verticalCenter
                visible: parent.text === ""
                text: "Nouvelle tâche…"
                font: parent.font
                color: win.s.alpha(win.s.colOnSurfaceVariant, 0.6)
              }
            }
          }
          Text {
            visible: win.s.todos.length === 0 && !todoW.adding
            width: parent.width; height: 30
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            text: "Rien à faire, profite ✨"
            font.family: win.s.sansFont
            font.pixelSize: 12
            color: win.s.colOnSurfaceVariant
          }
          Repeater {
            model: win.s.todos.slice(0, 5)
            delegate: Rectangle {
              id: todoItem
              required property var modelData
              required property int index
              readonly property var pal: [[win.s.secondaryContainer, win.s.colOnSecondaryContainer], [win.s.tertiaryContainer, win.s.colOnTertiaryContainer],
                                          [win.s.primaryContainer, win.s.colOnPrimaryContainer]][index % 3]
              width: parent.width; height: 30; radius: 15
              color: pal[0]
              opacity: modelData.done ? 0.55 : 1
              Behavior on opacity { NumberAnimation { duration: 200 } }
              MIcon {
                x: 8
                anchors.verticalCenter: parent.verticalCenter
                icon: todoItem.modelData.done ? "check_circle" : "radio_button_unchecked"
                size: 17
                fill: todoItem.modelData.done ? 1 : 0
                color: todoItem.pal[1]
              }
              Text {
                x: 32
                width: parent.width - 60
                anchors.verticalCenter: parent.verticalCenter
                text: String(todoItem.modelData.text)
                elide: Text.ElideRight
                font.family: win.s.sansFont
                font.pixelSize: 12
                font.strikeout: !!todoItem.modelData.done
                color: todoItem.pal[1]
              }
              MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                onClicked: function(m) { if (m.button === Qt.RightButton) win.s.removeTodo(todoItem.index); else win.s.toggleTodo(todoItem.index) }
                MIcon {
                  anchors.right: parent.right
                  anchors.rightMargin: 8
                  anchors.verticalCenter: parent.verticalCenter
                  visible: parent.containsMouse
                  icon: "close"; size: 14
                  color: todoItem.pal[1]
                  MouseArea { anchors.fill: parent; anchors.margins: -4; onClicked: win.s.removeTodo(todoItem.index) }
                }
              }
            }
          }
        }
      }
    }

    // ====================================================== horloge « bonbon » empilée (violet)
    // Heures sur minutes, chiffres alternés en deux tons, police Google Sans
    // Flex en graisse 1000 et arrondi 100 ; chaque chiffre rebondit quand il change.
    DeskItem {
      id: stackW
      key: "stack"
      bumpy: true
      width: stackCol.width
      height: stackCol.height
      readonly property int size: Math.round(Number(win.s.opt("stack_size", 132)))
      readonly property color ca: win.s.colOnSurface
      readonly property color cb: win.s.secondary
      Column {
        id: stackCol
        spacing: -Math.round(stackW.size * 0.5)
        layer.enabled: true
        layer.effect: MultiEffect { shadowEnabled: true; shadowBlur: 0.7; shadowVerticalOffset: 3; shadowOpacity: win.s.darkSkin ? 0.35 : 0.18 }
        Row {
          anchors.horizontalCenter: parent.horizontalCenter
          spacing: Math.round(stackW.size * 0.02)
          BigDigit { size: stackW.size; text: Qt.formatTime(win.now, "HH").charAt(0); color: stackW.ca }
          BigDigit { size: stackW.size; text: Qt.formatTime(win.now, "HH").charAt(1); color: stackW.cb }
        }
        Row {
          anchors.horizontalCenter: parent.horizontalCenter
          spacing: Math.round(stackW.size * 0.02)
          BigDigit { size: stackW.size; text: Qt.formatTime(win.now, "mm").charAt(0); color: stackW.cb }
          BigDigit { size: stackW.size; text: Qt.formatTime(win.now, "mm").charAt(1); color: stackW.ca }
        }
      }
      Rectangle {
        anchors.horizontalCenter: parent.horizontalCenter
        y: parent.height - Math.round(stackW.size * 0.1)
        height: 26
        width: stackDate.implicitWidth + 22
        radius: 9
        color: win.s.alpha(win.s.surfaceHigh, 0.75)
        Text {
          id: stackDate
          anchors.centerIn: parent
          text: win.cap(win.now.toLocaleDateString(Qt.locale("fr_FR"), "dddd d MMMM"))
          font.family: win.s.sansFont
          font.pixelSize: 12
          font.weight: Font.Medium
          color: win.s.colOnSurface
        }
      }
    }

    // ====================================================== horloge pixel (blanc / sombre / jouet)
    DeskItem {
      id: pixW
      key: "pixclock"
      bumpy: true
      width: pixRow.implicitWidth + 44
      height: 132
      Card {
        anchors.fill: parent
        color: win.st === "jouet" ? win.s.surfaceMid : win.s.alpha(win.s.surfaceMid, win.s.darkSkin ? 0.82 : 0.9)
        Row {
          id: pixRow
          x: 22; y: 12
          spacing: 2
          Repeater {
            model: Qt.formatTime(win.now, "HH:mm").split("")
            delegate: Text {
              required property string modelData
              required property int index
              text: modelData
              font.family: win.s.pixelFont
              font.pixelSize: 78
              font.weight: Font.Bold
              color: win.st === "jouet" ? win.s.rainbow[index % win.s.rainbow.length] : win.ink
              style: win.st === "jouet" ? Text.Outline : Text.Normal
              styleColor: "#1b1030"
              // Les deux-points clignotent.
              opacity: modelData === ":" ? (win.now.getSeconds() % 2 === 0 ? 1 : 0.15) : 1
              Behavior on opacity { NumberAnimation { duration: 180 } }
            }
          }
          Text {
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 14
            text: Qt.formatTime(win.now, "ss")
            font.family: win.s.pixelFont
            font.pixelSize: 22
            color: win.s.alpha(win.ink, 0.45)
          }
        }
        Text {
          x: 24
          anchors.bottom: parent.bottom
          anchors.bottomMargin: 14
          text: win.now.toLocaleDateString(Qt.locale("fr_FR"), "ddd dd MMM yyyy").toUpperCase().replace(/\./g, "")
          font.family: win.s.pixelFont
          font.pixelSize: 13
          font.letterSpacing: 2
          color: win.s.colOnSurfaceVariant
        }
      }
    }

    // ====================================================== jour en grandes capitales (blanc / sombre)
    DeskItem {
      id: dayW
      key: "day"
      width: dayCol.implicitWidth
      height: dayCol.implicitHeight
      readonly property bool kana: win.st === "sombre" && win.s.opt("day_kanji", true) !== false
      Column {
        id: dayCol
        spacing: 2
        Text {
          visible: dayW.kana
          text: ["日曜日", "月曜日", "火曜日", "水曜日", "木曜日", "金曜日", "土曜日"][win.now.getDay()]
          font.family: "Noto Sans CJK JP"
          font.pixelSize: 44
          font.weight: Font.Black
          color: win.ink
        }
        Text {
          text: win.now.toLocaleDateString(Qt.locale("fr_FR"), "dddd").toUpperCase()
          font.family: win.s.displayFont
          font.pixelSize: dayW.kana ? 16 : 46
          font.weight: Font.Bold
          font.letterSpacing: dayW.kana ? 6 : 4
          color: dayW.kana ? win.s.colOnSurfaceVariant : win.ink
        }
        Row {
          spacing: 10
          Rectangle { width: 26; height: 1; color: win.s.colOnSurfaceVariant; anchors.verticalCenter: parent.verticalCenter }
          Text {
            text: win.now.toLocaleDateString(Qt.locale("fr_FR"), "d MMMM yyyy").toUpperCase()
            font.family: win.s.sansFont
            font.pixelSize: 13
            font.letterSpacing: 3
            color: win.s.colOnSurfaceVariant
          }
          Text {
            text: "· " + Qt.formatTime(win.now, "HH:mm")
            font.family: win.s.numFont
            font.pixelSize: 13
            color: win.s.colOnSurfaceVariant
          }
        }
      }
    }

    // ====================================================== anneau ondulé : batterie (ou CPU sur un fixe)
    DeskItem {
      id: ringW
      key: "ring"
      width: 96; height: 96
      readonly property bool batt: win.s.batteryPct >= 0
      readonly property real val: batt ? win.s.batteryPct / 100 : win.s.cpu
      property real phase: 0
      NumberAnimation on phase {
        from: 0; to: Math.PI * 2; duration: ringW.batt && !win.charging ? 9000 : 2600
        loops: Animation.Infinite; running: ringW.visible
      }
      function wavy(r, amp, lobes, upTo) {
        var pts = [], steps = Math.max(2, Math.round(160 * upTo))
        for (var i = 0; i <= steps; i++) {
          var a = -Math.PI / 2 + i / 160 * Math.PI * 2
          var rr = r + Math.sin(a * lobes + phase) * amp
          pts.push(Qt.point(48 + Math.cos(a) * rr, 48 + Math.sin(a) * rr))
        }
        return pts
      }
      Rectangle {
        anchors.centerIn: parent
        width: 74; height: 74; radius: 37
        color: win.s.alpha(win.s.surfaceHigh, 0.7)
      }
      Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
          strokeColor: win.s.alpha(win.s.colOnSurface, 0.22)
          strokeWidth: 3
          fillColor: "transparent"
          capStyle: ShapePath.RoundCap
          PathPolyline { path: ringW.wavy(41, 2.2, 12, 1) }
        }
        ShapePath {
          strokeColor: ringW.batt && ringW.val < 0.2 && !win.charging ? win.s.errorColor : win.s.primary
          strokeWidth: 4
          fillColor: "transparent"
          capStyle: ShapePath.RoundCap
          PathPolyline { path: ringW.wavy(41, 2.2, 12, Math.max(0.01, ringW.val)) }
        }
      }
      Column {
        anchors.centerIn: parent
        MIcon {
          anchors.horizontalCenter: parent.horizontalCenter
          icon: ringW.batt ? (win.charging ? "bolt" : "battery_full") : "memory"
          size: 14; fill: 1
          color: win.s.colOnSurfaceVariant
        }
        Text {
          anchors.horizontalCenter: parent.horizontalCenter
          text: Math.round(ringW.val * 100) + "%"
          font.family: win.s.numFont
          font.pixelSize: 18
          font.weight: Font.Bold
          color: win.s.colOnSurface
        }
        Text {
          anchors.horizontalCenter: parent.horizontalCenter
          text: !ringW.batt ? "CPU" : win.charging ? "en charge"
              : (win.s.battery.timeToEmpty > 0 ? Math.floor(win.s.battery.timeToEmpty / 3600) + " h " + Math.floor(win.s.battery.timeToEmpty % 3600 / 60) : "batterie")
          font.family: win.s.sansFont
          font.pixelSize: 9
          color: win.s.colOnSurfaceVariant
        }
      }
    }
  }

  // ====================================================== briques
  // Un widget déplaçable : glisse sur son élan, s'aimante à la grille, rebondit.
  component DeskItem: Item {
    id: di
    property string key: ""
    property bool bumpy: false
    readonly property var def: win.defPos(key)
    readonly property var defX: def[0]
    readonly property var defY: def[1]
    default property alias content: holder.data
    visible: win.shown(key)
    // Positions gardées par style (« blanc/music »…) ; l'expressive relit les anciennes clés.
    readonly property string posKey: win.st + "/" + key
    readonly property var saved: win.s.layoutPos[posKey] || (win.st === "expressive" ? win.s.layoutPos[key] : null) || null
    function clampX(v) { return Math.max(8, Math.min(desk.width - width - 8, v)) }
    function clampY(v) { return Math.max(8, Math.min(desk.height - height - 8, v)) }
    function place(d, size, total) { return d === "c" ? (total - size) / 2 : (d >= 0 ? d : total + d - size) }
    readonly property real homeX: clampX(saved ? saved.x : place(defX, width, desk.width))
    readonly property real homeY: clampY(saved ? saved.y : place(defY, height, desk.height))
    // Jouet : chaque carte légèrement penchée.
    rotation: win.st === "jouet" ? ((key.length * 7 + key.charCodeAt(0)) % 5 - 2) * 0.9 : 0
    Behavior on rotation { NumberAnimation { duration: 400; easing.type: Easing.OutBack } }
    property bool dragging: false
    x: homeX
    y: homeY
    Behavior on x { enabled: !di.dragging; SpringAnimation { spring: 2.4; damping: 0.2; epsilon: 0.25 } }
    Behavior on y { enabled: !di.dragging; SpringAnimation { spring: 2.4; damping: 0.2; epsilon: 0.25 } }

    // Apparition en cascade au chargement.
    opacity: 0
    scale: 0.9
    Component.onCompleted: appear.start()
    ParallelAnimation {
      id: appear
      NumberAnimation { target: di; property: "opacity"; to: 1; duration: 420; easing.type: Easing.OutCubic }
      NumberAnimation { target: di; property: "scale"; to: 1; duration: 620; easing.type: Easing.OutBack; easing.overshoot: 2.2 }
    }

    MouseArea {
      id: dragArea
      anchors.fill: parent
      cursorShape: pressed && di.dragging ? Qt.ClosedHandCursor : Qt.ArrowCursor
      property point grab: Qt.point(0, 0)
      property point lastP: Qt.point(0, 0)
      property point startP: Qt.point(0, 0)
      property real lastT: 0
      property real vx: 0
      property real vy: 0
      onPressed: function(m) {
        var p = mapToItem(desk, m.x, m.y)
        grab = Qt.point(p.x - di.x, p.y - di.y)
        lastP = p; startP = p
        lastT = Date.now(); vx = 0; vy = 0
        di.z = ++desk.topZ
      }
      onPositionChanged: function(m) {
        var p = mapToItem(desk, m.x, m.y)
        if (!di.dragging && Math.abs(p.x - startP.x) + Math.abs(p.y - startP.y) < 4) return
        di.dragging = true
        var t = Date.now(), dt = Math.max(1, t - lastT)
        vx = 0.5 * vx + 0.5 * (p.x - lastP.x) / dt
        vy = 0.5 * vy + 0.5 * (p.y - lastP.y) / dt
        lastP = p; lastT = t
        di.x = p.x - grab.x
        di.y = p.y - grab.y
      }
      onReleased: {
        if (!di.dragging) return
        if (Date.now() - lastT > 90) { vx = 0; vy = 0 }
        var tx = di.clampX(Math.round((di.x + vx * 220) / 8) * 8)
        var ty = di.clampY(Math.round((di.y + vy * 220) / 8) * 8)
        di.dragging = false
        win.s.savePos(di.posKey, tx, ty)
        di.x = Qt.binding(function() { return di.homeX })
        di.y = Qt.binding(function() { return di.homeY })
      }
    }
    Item {
      id: holder
      anchors.fill: parent
      property real lift: di.dragging ? 1.04 : 1
      Behavior on lift { NumberAnimation { duration: 260; easing.type: Easing.OutBack; easing.overshoot: 2 } }
      // Saute un peu sur les basses (Réglages → Musique → « Rebond »).
      scale: lift + (di.bumpy && win.s.bump ? win.s.beat * 0.035 : 0)
    }
  }

  // Carte habillée par la peau du style : arrondi, bordure, ombre douce / dure / aucune.
  // Carte habillée par la peau du style : arrondi, bordure, ombre douce / dure / aucune.
  // L'ombre est une sœur placée avant le corps (un enfant à z négatif ne passe pas
  // sous un Rectangle) ; le contenu va dans le corps, `parent.radius` y reste valable.
  component Card: Item {
    id: cd
    property color color: win.s.surfaceMid
    property real radius: win.s.radius
    default property alias content: body.data
    RectangularShadow {
      visible: win.s.shadowMode === "soft"
      anchors.fill: body
      radius: cd.radius
      blur: 18
      spread: -2
      offset.y: 4
      color: Qt.rgba(0, 0, 0, win.s.darkSkin ? 0.32 : 0.12)
    }
    Rectangle {
      visible: win.s.shadowMode === "hard"
      x: 6; y: 6
      width: body.width; height: body.height
      radius: cd.radius
      color: "#1b1030"
    }
    Rectangle {
      id: body
      anchors.fill: parent
      radius: cd.radius
      color: cd.color
      border.width: win.s.borderW
      border.color: win.st === "jouet" ? "#1b1030" : win.s.alpha(win.s.outlineVariant, win.s.darkSkin ? 0.9 : 1)
    }
  }

  component BigDigit: Text {
    id: bd
    property int size: 120
    property real pop: 1
    font.family: win.s.roundFont
    font.pixelSize: size
    font.variableAxes: win.s.roundAxes
    scale: pop
    onTextChanged: { pop = 0.8; bdAnim.restart() }
    NumberAnimation { id: bdAnim; target: bd; property: "pop"; to: 1; duration: 560; easing.type: Easing.OutBack; easing.overshoot: 2.4 }
    Behavior on color { ColorAnimation { duration: 600 } }
  }

  component Hand: Rectangle {
    id: hand
    property real len: 50
    property real thick: 10
    property real angle: 0
    x: clock.r - thick / 2
    y: clock.r - len + thick / 2
    width: thick
    height: len
    radius: thick / 2
    antialiasing: true
    transform: Rotation { origin.x: hand.thick / 2; origin.y: hand.len - hand.thick / 2; angle: hand.angle }
  }

  component RoundBtn: Item {
    id: rb
    property string icon: ""
    property real size: 30
    property bool outlined: false
    signal clicked()
    width: size; height: size
    opacity: enabled ? 1 : 0.4
    Rectangle {
      anchors.fill: parent
      radius: width / 2
      color: rbm.containsMouse ? win.s.alpha(win.s.colOnSurface, 0.12) : "transparent"
      border.width: rb.outlined ? 1 : 0
      border.color: win.s.outlineVariant
      scale: rbm.pressed ? 0.85 : 1
      Behavior on scale { NumberAnimation { duration: 280; easing.type: Easing.OutBack; easing.overshoot: 3 } }
    }
    MIcon { anchors.centerIn: parent; icon: rb.icon; size: rb.size * 0.55; fill: 1; color: win.s.colOnSurface }
    MouseArea { id: rbm; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: rb.clicked() }
  }

  component SysTile: Item {
    id: tile
    property string label: ""
    property real value: 0
    property string icon: ""
    property color bg
    property color fg
    property color badge
    property color badgeFg
    default property alias content: tileBody.data
    width: 89; height: 84
    readonly property real radius: Math.max(6, win.s.radius - 2)
    RectangularShadow { visible: win.s.shadowMode === "soft"; anchors.fill: tileBody; radius: tile.radius; blur: 14; spread: -2; offset.y: 3; color: Qt.rgba(0, 0, 0, win.s.darkSkin ? 0.28 : 0.1) }
    Rectangle { visible: win.s.shadowMode === "hard"; x: 5; y: 5; width: tile.width; height: tile.height; radius: tile.radius; color: "#1b1030" }
    Rectangle {
      id: tileBody
      anchors.fill: parent
      radius: tile.radius
      color: tile.bg
      border.width: win.s.borderW
      border.color: win.st === "jouet" ? "#1b1030" : win.s.outlineVariant
    }
    Cookie {
      x: parent.width - 36; y: 8
      width: 28; height: 28
      lobes: 8; depth: 0.12
      color: tile.badge
      MIcon { anchors.centerIn: parent; icon: tile.icon; size: 15; fill: 1; color: tile.badgeFg }
    }
    Column {
      x: 12; y: parent.height - height - 10
      Text {
        text: Math.round(tile.value * 100) + "%"
        font.family: win.s.numFont
        font.pixelSize: 21
        font.weight: Font.DemiBold
        color: tile.fg
      }
      Text {
        text: tile.label
        font.family: win.s.sansFont
        font.pixelSize: 11
        color: win.s.alpha(tile.fg, 0.75)
      }
    }
  }
}
