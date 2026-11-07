import QtQuick
import QtQuick.Shapes
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Widgets

// Style « mono » : le tableau de bord qui descend du haut de l'écran, soudé au
// cadre noir (coins concaves), en trois onglets comme caelestia :
//   Dashboard   : météo, compte + durée d'allumage, heure empilée, calendrier,
//                 jauges (processeur, mémoire, disque), lecteur avec pochette ronde
//   Media       : pochette entourée du visualiseur, progression, paroles
//   Performance : processeur, mémoire, stockage, réseau (courbe en direct)
// et le menu de session vertical, soudé au bord droit (panel « session »).
PanelWindow {
  id: win
  property var service: null
  readonly property var s: service

  color: "transparent"
  anchors { top: true; bottom: true; left: true; right: true }
  exclusionMode: ExclusionMode.Ignore
  WlrLayershell.layer: WlrLayer.Overlay
  WlrLayershell.namespace: "liquid-glass-mono-dash"
  WlrLayershell.keyboardFocus: s.kbd(false)

  readonly property color bg: s.monoFrame
  readonly property color card: s.surfaceMid
  readonly property color card2: s.surfaceHigh
  readonly property color ink: s.colOnSurface
  readonly property color sub: s.colOnSurfaceVariant
  readonly property color acc: s.primary
  readonly property color line: s.outlineVariant
  readonly property string font: "Rubik"
  readonly property string mono: "JetBrainsMono Nerd Font"
  readonly property int barW: 44
  readonly property int frame: 8

  readonly property bool dash: ["dashboard", "media", "perf"].indexOf(s.panel) >= 0
  property string tab: dash ? s.panel : "dashboard"
  property bool revealed: false
  Component.onCompleted: { revealed = true; keys.forceActiveFocus() }
  property date now: new Date()
  Timer { interval: 1000; repeat: true; running: true; onTriggered: win.now = new Date() }
  function cap(t) { t = String(t); return t.charAt(0).toUpperCase() + t.slice(1) }

  MouseArea { anchors.fill: parent; onClicked: s.closeAll() }
  Item { id: keys; focus: true; Keys.onEscapePressed: s.closeAll()
    Keys.onLeftPressed: s.panel = ["dashboard", "media", "perf"][Math.max(0, ["dashboard", "media", "perf"].indexOf(win.tab) - 1)]
    Keys.onRightPressed: s.panel = ["dashboard", "media", "perf"][Math.min(2, ["dashboard", "media", "perf"].indexOf(win.tab) + 1)] }

  // ================================================================ tableau de bord
  Item {
    id: dashBox
    visible: win.dash
    width: 640; height: 360
    x: win.barW + (win.width - win.barW - width) / 2
    y: win.frame - 1 - (win.revealed && win.dash ? 0 : height)
    Behavior on y { NumberAnimation { duration: 380; easing.type: Easing.OutCubic } }
    // Coins concaves qui soudent le volet au cadre du haut.
    Concave { x: -18; y: 0; flip: false }
    Concave { x: parent.width; y: 0; flip: true }
    Rectangle {
      anchors.fill: parent
      color: win.bg
      radius: 22
      Rectangle { width: parent.width; height: 22; color: win.bg }
      MouseArea { anchors.fill: parent }
    }

    // Onglets
    Row {
      id: tabs
      x: 18; y: 8
      width: parent.width - 36
      Repeater {
        model: [["dashboard", "Dashboard", "dashboard"], ["media", "Media", "queue_music"], ["perf", "Performance", "speed"]]
        delegate: Item {
          id: tabItem
          required property var modelData
          readonly property bool cur: win.tab === modelData[0]
          width: tabs.width / 3; height: 44
          Column {
            anchors.centerIn: parent
            spacing: 2
            MIcon { anchors.horizontalCenter: parent.horizontalCenter; icon: tabItem.modelData[2]; size: 16; fill: tabItem.cur ? 1 : 0; color: tabItem.cur ? win.ink : win.sub }
            Text { anchors.horizontalCenter: parent.horizontalCenter; text: tabItem.modelData[1]; font.family: win.font; font.pixelSize: 12; color: tabItem.cur ? win.ink : win.sub }
          }
          MouseArea { anchors.fill: parent; onClicked: s.panel = tabItem.modelData[0] }
        }
      }
    }
    Rectangle { x: 18; y: 52; width: parent.width - 36; height: 1; color: win.line }
    Rectangle {
      y: 50; height: 3; radius: 1.5; width: 70; color: win.ink
      x: 18 + (tabs.width / 3) * ["dashboard", "media", "perf"].indexOf(win.tab) + (tabs.width / 3 - width) / 2
      Behavior on x { NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }
    }

    // ---------------------------------------------------- Dashboard
    Item {
      visible: win.tab === "dashboard"
      x: 14; y: 64
      width: parent.width - 28; height: parent.height - 78
      // météo
      Card {
        x: 0; y: 0; width: 180; height: 86
        Row {
          anchors.centerIn: parent; spacing: 14
          MIcon { anchors.verticalCenter: parent.verticalCenter; icon: s.weatherIcon; size: 40; weight: 300; color: win.ink }
          Column {
            anchors.verticalCenter: parent.verticalCenter
            Text { text: s.weather ? s.weather.temp + "°C" : "--"; font.family: win.font; font.pixelSize: 24; font.weight: Font.Medium; color: win.ink }
            Text { text: win.cap(s.weatherDesc); font.family: win.font; font.pixelSize: 11; color: win.sub }
          }
        }
      }
      // compte
      Card {
        x: 188; y: 0; width: 230; height: 86
        ClippingRectangle {
          x: 12; anchors.verticalCenter: parent.verticalCenter; width: 62; height: 62; radius: 31; color: win.card2
          Text { anchors.centerIn: parent; text: s.user.charAt(0).toUpperCase(); font.family: win.font; font.pixelSize: 26; color: win.ink }
          Image { anchors.fill: parent; source: "file://" + Quickshell.env("HOME") + "/.face"; fillMode: Image.PreserveAspectCrop; asynchronous: true; visible: status === Image.Ready }
        }
        Column {
          x: 86; anchors.verticalCenter: parent.verticalCenter; spacing: 6
          Rectangle {
            width: wmTxt.implicitWidth + 22; height: 22; radius: 11; color: win.card2
            Text { id: wmTxt; anchors.centerIn: parent; text: "  Hyprland"; font.family: win.mono; font.pixelSize: 11; color: win.ink }
          }
          Row {
            spacing: 6
            MIcon { icon: "schedule"; size: 14; color: win.sub }
            Text { text: "up " + s.uptimeText; font.family: win.font; font.pixelSize: 11; color: win.ink }
          }
        }
      }
      // heure empilée
      Card {
        x: 0; y: 94; width: 70; height: 188
        Column {
          anchors.centerIn: parent; spacing: 4
          Text { anchors.horizontalCenter: parent.horizontalCenter; text: Qt.formatTime(win.now, "HH"); font.family: win.font; font.pixelSize: 26; font.weight: Font.Medium; color: win.ink }
          Row { anchors.horizontalCenter: parent.horizontalCenter; spacing: 4; Repeater { model: 3; delegate: Rectangle { width: 4; height: 4; radius: 2; color: win.sub } } }
          Text { anchors.horizontalCenter: parent.horizontalCenter; text: Qt.formatTime(win.now, "mm"); font.family: win.font; font.pixelSize: 26; font.weight: Font.Medium; color: win.ink }
        }
      }
      // calendrier
      Card {
        id: calCard
        x: 78; y: 94; width: 262; height: 188
        property date month: new Date(win.now.getFullYear(), win.now.getMonth(), 1)
        Row {
          anchors.horizontalCenter: parent.horizontalCenter; y: 8; spacing: 18
          MIcon { icon: "chevron_left"; size: 16; color: win.ink; MouseArea { anchors.fill: parent; onClicked: calCard.month = new Date(calCard.month.getFullYear(), calCard.month.getMonth() - 1, 1) } }
          Text { width: 110; horizontalAlignment: Text.AlignHCenter; text: win.cap(calCard.month.toLocaleDateString(Qt.locale("fr_FR"), "MMMM yyyy")); font.family: win.font; font.pixelSize: 12; color: win.ink }
          MIcon { icon: "chevron_right"; size: 16; color: win.ink; MouseArea { anchors.fill: parent; onClicked: calCard.month = new Date(calCard.month.getFullYear(), calCard.month.getMonth() + 1, 1) } }
        }
        Grid {
          x: 10; y: 30; columns: 7
          Repeater {
            model: ["lun.", "mar.", "mer.", "jeu.", "ven.", "sam.", "dim."]
            delegate: Text { required property string modelData; width: 242 / 7; height: 18; horizontalAlignment: Text.AlignHCenter; text: modelData; font.family: win.font; font.pixelSize: 10; color: win.ink }
          }
          Repeater {
            model: 42
            delegate: Item {
              id: cd
              required property int index
              readonly property int lead: (calCard.month.getDay() + 6) % 7
              readonly property date d: new Date(calCard.month.getFullYear(), calCard.month.getMonth(), index - lead + 1)
              readonly property bool today: d.toDateString() === win.now.toDateString()
              width: 242 / 7; height: 22
              Cookie12 { visible: cd.today; anchors.centerIn: parent; size: 22; color: win.acc }
              Text {
                anchors.centerIn: parent; text: cd.d.getDate(); font.family: win.font; font.pixelSize: 10
                font.weight: cd.today ? Font.Bold : Font.Normal
                color: cd.today ? s.colOnPrimary : (cd.d.getMonth() === calCard.month.getMonth() ? ((index % 7) >= 5 ? win.acc : win.ink) : s.outline)
              }
            }
          }
        }
      }
      // jauges
      Card {
        x: 348; y: 94; width: 70; height: 188
        Column {
          anchors.centerIn: parent; spacing: 10
          Repeater {
            model: [["memory", s.cpu], ["memory_alt", s.memPct], ["hard_drive", s.diskPct]]
            delegate: Item {
              required property var modelData
              width: 46; height: 46
              Ring { anchors.fill: parent; value: modelData[1]; thickness: 3; color: win.ink; track: win.line }
              MIcon { anchors.centerIn: parent; icon: modelData[0]; size: 18; color: win.ink }
            }
          }
        }
      }
      // lecteur
      Card {
        x: 426; y: 0; width: parent.width - 426; height: 282
        Item {
          id: disc
          anchors.horizontalCenter: parent.horizontalCenter; y: 14
          width: 120; height: 120
          Ring { anchors.fill: parent; value: s.progress; thickness: 3; color: win.ink; track: win.line }
          ClippingRectangle {
            anchors.centerIn: parent; width: 104; height: 104; radius: 52; color: win.card2
            MIcon { anchors.centerIn: parent; icon: "music_note"; size: 36; color: win.sub }
            Image { anchors.fill: parent; source: s.cover; fillMode: Image.PreserveAspectCrop; asynchronous: true;
              }
            Rectangle { anchors.fill: parent; color: "black"; opacity: s.darkSkin ? 0.08 : 0 }
          }
        }
        Column {
          anchors.horizontalCenter: parent.horizontalCenter; y: 146; width: parent.width - 20; spacing: 2
          Text { width: parent.width; horizontalAlignment: Text.AlignHCenter; elide: Text.ElideRight; text: s.trackTitle || "Rien en lecture"; font.family: win.font; font.pixelSize: 14; font.weight: Font.Medium; color: win.ink }
          Text { width: parent.width; horizontalAlignment: Text.AlignHCenter; elide: Text.ElideRight; text: s.trackArtist; font.family: win.font; font.pixelSize: 11; color: win.sub }
        }
        Row {
          anchors.horizontalCenter: parent.horizontalCenter; y: 196; spacing: 8
          CtlBtn { icon: "skip_previous"; onClicked: if (s.player) s.player.previous() }
          CtlBtn { icon: s.playing ? "pause" : "play_arrow"; wide: true; onClicked: s.playPause() }
          CtlBtn { icon: "skip_next"; onClicked: if (s.player) s.player.next() }
        }
        Row {
          anchors.horizontalCenter: parent.horizontalCenter; y: 240; spacing: 3
          Repeater {
            model: 24
            delegate: Rectangle {
              required property int index
              width: 4; radius: 2; anchors.bottom: parent.bottom
              height: 3 + (s.cavaValues.length ? (s.cavaValues[Math.floor(index * s.cavaValues.length / 24)] || 0) / 100 * 26 : 0)
              color: win.ink; opacity: 0.8
              Behavior on height { NumberAnimation { duration: 70 } }
            }
          }
        }
      }
    }

    // ---------------------------------------------------- Media
    Item {
      visible: win.tab === "media"
      x: 14; y: 64
      width: parent.width - 28; height: parent.height - 78
      Item {
        id: mdisc
        x: 10; anchors.verticalCenter: parent.verticalCenter
        width: 200; height: 200
        // visualiseur en couronne
        Repeater {
          model: 60
          delegate: Rectangle {
            required property int index
            readonly property real v: s.cavaValues.length ? (s.cavaValues[Math.floor(index * s.cavaValues.length / 60)] || 0) / 100 : 0
            width: 2.5; height: 4 + v * 26; radius: 1.2
            color: win.ink; opacity: 0.85
            x: mdisc.width / 2 - width / 2; y: mdisc.height / 2 - 70 - height
            transform: Rotation { origin.x: 1.25; origin.y: 70 + height; angle: index * 6 }
            Behavior on height { NumberAnimation { duration: 70 } }
          }
        }
        ClippingRectangle {
          anchors.centerIn: parent; width: 128; height: 128; radius: 64; color: win.card2
          MIcon { anchors.centerIn: parent; icon: "album"; size: 46; color: win.sub }
          Image { anchors.fill: parent; source: s.cover; fillMode: Image.PreserveAspectCrop; asynchronous: true }
          RotationAnimation on rotation { running: s.playing; from: 0; to: 360; duration: 16000; loops: Animation.Infinite }
        }
      }
      Column {
        x: 230; y: 20; width: 170; spacing: 4
        Text { width: parent.width; elide: Text.ElideRight; text: s.trackTitle || "Rien en lecture"; font.family: win.font; font.pixelSize: 17; font.weight: Font.Medium; color: win.ink }
        Text { width: parent.width; elide: Text.ElideRight; text: s.trackArtist; font.family: win.font; font.pixelSize: 12; color: win.sub }
        Item { width: 1; height: 50 }
        Item {
          width: parent.width; height: 14
          Rectangle { anchors.verticalCenter: parent.verticalCenter; width: parent.width; height: 3; radius: 1.5; color: win.line }
          Rectangle { anchors.verticalCenter: parent.verticalCenter; width: parent.width * s.progress; height: 3; radius: 1.5; color: win.ink }
          Rectangle { anchors.verticalCenter: parent.verticalCenter; x: parent.width * s.progress - 2; width: 4; height: 14; radius: 2; color: win.ink }
        }
        Item {
          width: parent.width; height: 14
          Text { text: s.fmtTime(s.position); font.family: win.font; font.pixelSize: 10; color: win.sub }
          Text { anchors.right: parent.right; text: s.fmtTime(s.length); font.family: win.font; font.pixelSize: 10; color: win.sub }
        }
        Row {
          spacing: 8; topPadding: 10
          CtlBtn { icon: "shuffle"; onClicked: if (s.player && s.player.shuffleSupported) s.player.shuffle = !s.player.shuffle }
          CtlBtn { icon: "skip_previous"; onClicked: if (s.player) s.player.previous() }
          CtlBtn { icon: s.playing ? "pause" : "play_arrow"; wide: true; onClicked: s.playPause() }
          CtlBtn { icon: "skip_next"; onClicked: if (s.player) s.player.next() }
        }
      }
      Card {
        x: 414; y: 0; width: parent.width - 414; height: parent.height
        Row { x: 12; y: 12; spacing: 6
          MIcon { icon: "lyrics"; size: 15; color: win.ink }
          Text { text: "Paroles"; font.family: win.font; font.pixelSize: 12; color: win.ink } }
        ListView {
          id: lyr
          x: 12; y: 38; width: parent.width - 24; height: parent.height - 48
          clip: true
          model: s.lyrics
          spacing: 6
          interactive: false
          currentIndex: Math.max(0, s.lineIndex)
          highlightRangeMode: ListView.ApplyRange
          preferredHighlightBegin: height * 0.35; preferredHighlightEnd: height * 0.45
          highlightMoveDuration: 400
          delegate: Text {
            required property var modelData
            required property int index
            width: lyr.width; wrapMode: Text.Wrap
            text: modelData.text || "♪"
            font.family: win.font; font.pixelSize: index === s.lineIndex ? 13 : 11
            font.weight: index === s.lineIndex ? Font.Medium : Font.Normal
            color: index === s.lineIndex ? win.ink : win.sub
          }
        }
        Text { visible: s.lyrics.length === 0; anchors.centerIn: parent; text: "Pas de paroles"; font.family: win.font; font.pixelSize: 11; color: win.sub }
      }
    }

    // ---------------------------------------------------- Performance
    Item {
      id: perf
      visible: win.tab === "perf"
      x: 14; y: 64
      width: parent.width - 28; height: parent.height - 78
      property var rx: []
      property var tx: []
      property real lastRx: -1
      property real lastTx: -1
      property real rxRate: 0
      property real txRate: 0
      Process {
        id: netP
        command: ["sh", "-c", "d=$(ip route show default 2>/dev/null | awk '{print $5; exit}'); [ -n \"$d\" ] && cat /sys/class/net/$d/statistics/rx_bytes /sys/class/net/$d/statistics/tx_bytes"]
        stdout: StdioCollector {
          onStreamFinished: {
            var l = text.trim().split("\n"); if (l.length < 2) return
            var r = Number(l[0]), t = Number(l[1])
            if (perf.lastRx >= 0) {
              perf.rxRate = Math.max(0, r - perf.lastRx); perf.txRate = Math.max(0, t - perf.lastTx)
              perf.rx = perf.rx.concat([perf.rxRate]).slice(-40); perf.tx = perf.tx.concat([perf.txRate]).slice(-40)
            }
            perf.lastRx = r; perf.lastTx = t
          }
        }
      }
      Timer { interval: 1000; repeat: true; running: true; triggeredOnStart: true; onTriggered: if (!netP.running) netP.running = true }
      function rate(b) { return b > 1048576 ? (b / 1048576).toFixed(1) + " Mo/s" : (b / 1024).toFixed(1) + " Ko/s" }

      Card {
        x: 0; y: 0; width: (parent.width - 8) / 2; height: 100
        Row { x: 14; y: 12; spacing: 10
          MIcon { icon: "memory"; size: 20; color: win.ink }
          Column { Text { text: "Processeur"; font.family: win.font; font.pixelSize: 13; color: win.ink }
                   Text { text: (s.info.cpu || "").replace(/\(R\)|\(TM\)|CPU|@.*$/g, "").trim(); font.family: win.font; font.pixelSize: 10; color: win.sub; width: 170; elide: Text.ElideRight } } }
        Text { x: 14; y: 62; text: s.temp > 0 ? "  " + s.temp + "°C" : ""; font.family: win.mono; font.pixelSize: 12; color: win.ink }
        Rectangle { anchors.right: parent.right; anchors.rightMargin: 14; y: 50; width: 60; height: 36; radius: 10; color: win.card2
          Text { anchors.centerIn: parent; text: Math.round(s.cpu * 100) + "%"; font.family: win.font; font.pixelSize: 16; font.weight: Font.Medium; color: win.ink } }
        Rectangle { x: 14; y: 86; width: parent.width - 100; height: 3; radius: 1.5; color: win.line
          Rectangle { width: parent.width * s.cpu; height: 3; radius: 1.5; color: win.ink } }
      }
      Card {
        x: (parent.width + 8) / 2; y: 0; width: (parent.width - 8) / 2; height: 100
        Row { x: 14; y: 12; spacing: 10
          MIcon { icon: "memory_alt"; size: 20; color: win.ink }
          Column { Text { text: "Mémoire"; font.family: win.font; font.pixelSize: 13; color: win.ink }
                   Text { text: s.memUsedGb.toFixed(1) + " / " + (s.info.ram || "?") + " Gio"; font.family: win.font; font.pixelSize: 10; color: win.sub } } }
        Item { anchors.right: parent.right; anchors.rightMargin: 14; anchors.verticalCenter: parent.verticalCenter; width: 70; height: 70
          Ring { anchors.fill: parent; value: s.memPct; thickness: 4; color: win.ink; track: win.line }
          Text { anchors.centerIn: parent; text: Math.round(s.memPct * 100) + "%"; font.family: win.font; font.pixelSize: 14; font.weight: Font.Medium; color: win.ink } }
      }
      Card {
        x: 0; y: 108; width: 170; height: parent.height - 108
        Text { x: 14; y: 12; text: "Stockage"; font.family: win.font; font.pixelSize: 13; color: win.ink }
        Item { anchors.centerIn: parent; anchors.verticalCenterOffset: 10; width: 90; height: 90
          Ring { anchors.fill: parent; value: s.diskPct; thickness: 5; color: win.ink; track: win.line }
          Column { anchors.centerIn: parent
            Text { anchors.horizontalCenter: parent.horizontalCenter; text: Math.round(s.diskPct * 100) + "%"; font.family: win.font; font.pixelSize: 16; font.weight: Font.Medium; color: win.ink }
            Text { anchors.horizontalCenter: parent.horizontalCenter; text: "utilisé"; font.family: win.font; font.pixelSize: 10; color: win.sub } } }
        Text { anchors.horizontalCenter: parent.horizontalCenter; anchors.bottom: parent.bottom; anchors.bottomMargin: 10; text: s.info.disk || ""; font.family: win.font; font.pixelSize: 10; color: win.sub }
      }
      Card {
        id: netCard
        x: 178; y: 108; width: parent.width - 178; height: parent.height - 108
        Row { x: 14; y: 12; spacing: 8
          MIcon { icon: "network_check"; size: 16; color: win.ink }
          Text { text: "Réseau"; font.family: win.font; font.pixelSize: 13; color: win.ink } }
        Shape {
          id: graph
          x: 14; y: 40; width: parent.width - 28; height: 70
          preferredRendererType: Shape.CurveRenderer
          readonly property real peak: Math.max(1024, Math.max.apply(null, perf.rx.concat(perf.tx).concat([1])))
          ShapePath {
            strokeColor: win.ink; strokeWidth: 1.5; fillColor: Qt.rgba(1, 1, 1, 0.08)
            startX: 0; startY: graph.height
            PathPolyline {
              path: {
                var pts = [Qt.point(0, graph.height)], n = perf.rx.length
                for (var i = 0; i < n; i++) pts.push(Qt.point(graph.width * (i + 40 - n) / 39, graph.height - perf.rx[i] / graph.peak * graph.height))
                pts.push(Qt.point(graph.width, graph.height))
                return pts
              }
            }
          }
          ShapePath {
            strokeColor: s.outline; strokeWidth: 1; fillColor: "transparent"
            PathPolyline {
              path: {
                var pts = [], n = perf.tx.length
                for (var i = 0; i < n; i++) pts.push(Qt.point(graph.width * (i + 40 - n) / 39, graph.height - perf.tx[i] / graph.peak * graph.height))
                return pts.length ? pts : [Qt.point(0, graph.height)]
              }
            }
          }
        }
        Column {
          x: 14; anchors.bottom: parent.bottom; anchors.bottomMargin: 10; spacing: 2
          Text { text: "↓  " + perf.rate(perf.rxRate); font.family: win.mono; font.pixelSize: 11; color: win.ink }
          Text { text: "↑  " + perf.rate(perf.txRate); font.family: win.mono; font.pixelSize: 11; color: win.sub }
        }
      }
    }
  }

  // ================================================================ session (bord droit)
  Item {
    id: session
    visible: s.panel === "session"
    width: 64; height: sesCol.implicitHeight + 28
    x: win.width - win.frame + 1 - (win.revealed && s.panel === "session" ? width : 0)
    anchors.verticalCenter: parent.verticalCenter
    Behavior on x { NumberAnimation { duration: 320; easing.type: Easing.OutCubic } }
    Concave { x: parent.width - 18; y: -18; rot: 90 }
    Concave { x: parent.width - 18; y: parent.height; rot: 0; flip: true; vflip: true }
    Rectangle {
      anchors.fill: parent; color: win.bg; radius: 22
      Rectangle { anchors.right: parent.right; width: 22; height: parent.height; color: win.bg }
      MouseArea { anchors.fill: parent }
    }
    Column {
      id: sesCol
      anchors.centerIn: parent
      spacing: 10
      Repeater {
        model: [["logout", "logout"], ["poweroff", "power_settings_new"], ["suspend", "bedtime"], ["reboot", "restart_alt"], ["lock", "lock"]]
        delegate: Rectangle {
          required property var modelData
          required property int index
          width: 44; height: 44; radius: sma.containsMouse ? 14 : 22
          color: index === 1 ? (sma.containsMouse ? s.tertiary : win.acc) : (sma.containsMouse ? win.card2 : win.card)
          Behavior on radius { NumberAnimation { duration: 160 } }
          MIcon { anchors.centerIn: parent; icon: modelData[1]; size: 20; color: index === 1 ? s.colOnPrimary : win.ink }
          MouseArea { id: sma; anchors.fill: parent; hoverEnabled: true; onClicked: s.power(modelData[0]) }
        }
      }
    }
  }

  // ================================================================ briques
  component Card: Rectangle { radius: 16; color: win.card }
  component CtlBtn: Rectangle {
    id: cb
    property string icon: ""
    property bool wide: false
    signal clicked()
    width: wide ? 52 : 32; height: 32; radius: wide ? 12 : 16
    color: wide ? (cbma.containsMouse ? Qt.lighter(win.acc, 1.1) : win.acc) : (cbma.containsMouse ? s.surfaceHighest : win.card2)
    MIcon { anchors.centerIn: parent; icon: cb.icon; size: 18; fill: 1; color: cb.wide ? s.colOnPrimary : win.ink }
    MouseArea { id: cbma; anchors.fill: parent; hoverEnabled: true; onClicked: cb.clicked() }
  }
  // Coin concave noir (18 px) pour souder un volet au cadre.
  component Concave: Shape {
    id: cc
    property bool flip: false
    property bool vflip: false
    property real rot: 0
    width: 18; height: 18
    preferredRendererType: Shape.CurveRenderer
    transform: [
      Scale { origin.x: 9; origin.y: 9; xScale: cc.flip ? -1 : 1; yScale: cc.vflip ? -1 : 1 },
      Rotation { origin.x: 9; origin.y: 9; angle: cc.rot }
    ]
    ShapePath {
      fillColor: win.bg; strokeWidth: -1
      startX: 0; startY: 0
      PathLine { x: 18; y: 0 }
      PathLine { x: 18; y: 18 }
      PathArc { x: 0; y: 0; radiusX: 18; radiusY: 18; direction: PathArc.Counterclockwise }
    }
  }
  // Pastille « biscuit » à 12 bosses (jour courant du calendrier).
  component Cookie12: Shape {
    id: ck
    property real size: 22
    property color color: "white"
    width: size; height: size
    preferredRendererType: Shape.CurveRenderer
    ShapePath {
      fillColor: ck.color; strokeWidth: -1
      PathPolyline {
        path: {
          var pts = [], n = 96, r = ck.size / 2
          for (var i = 0; i <= n; i++) {
            var a = i / n * Math.PI * 2, rr = r * (0.9 + 0.1 * Math.cos(a * 12))
            pts.push(Qt.point(r + rr * Math.cos(a), r + rr * Math.sin(a)))
          }
          return pts
        }
      }
    }
  }
}
