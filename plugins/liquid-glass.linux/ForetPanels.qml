import QtQuick
import QtQuick.Shapes
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Widgets
import Quickshell.Bluetooth
import Quickshell.Services.Pipewire
import "T.js" as T

// Style « foret » : les volets qui tombent de la barre en puces.
//   music   : pochette ronde + anneau de progression, contrôles, spectre en curseurs
//   dash    : calendrier, grosse heure entourée de la météo heure par heure
//             (orbite en pointillés), température, vent / humidité / pluie / ressenti,
//             puis lever et coucher du soleil et la liste « à faire »
//   battery : anneau de batterie, luminosité, volume, verrouiller / veille /
//             redémarrer / éteindre, profils d'énergie
//   net     : Wi-Fi et appareils Bluetooth en bulles
PanelWindow {
  id: win
  property var service: null
  readonly property var s: service

  color: "transparent"
  anchors { top: true; bottom: true; left: true; right: true }
  exclusionMode: ExclusionMode.Ignore
  WlrLayershell.layer: WlrLayer.Overlay
  WlrLayershell.namespace: "liquid-glass-foret-panel"
  WlrLayershell.keyboardFocus: s.kbd(false)

  readonly property string font: s && s.userFont ? s.userFont : "JetBrainsMono Nerd Font"
  readonly property color bg: s.alpha(s.surface, 0.94)
  readonly property color card: s.alpha(s.surfaceHigh, 0.55)
  readonly property color ink: s.colOnSurface
  readonly property color sub: s.colOnSurfaceVariant
  readonly property color acc: s.primary
  readonly property color accInk: s.colOnPrimary
  readonly property int top: 42

  property bool revealed: false
  Component.onCompleted: { revealed = true; keys.forceActiveFocus(); s.readBrightness() }
  property date now: new Date()
  Timer { interval: 1000; repeat: true; running: true; onTriggered: win.now = new Date() }
  function cap(t) { t = String(t); return t.charAt(0).toUpperCase() + t.slice(1) }

  MouseArea { anchors.fill: parent; onClicked: s.closeAll() }
  Item { id: keys; focus: true; Keys.onEscapePressed: s.closeAll() }

  PwObjectTracker { objects: [Pipewire.defaultAudioSink] }
  readonly property var sink: Pipewire.defaultAudioSink
  readonly property var bt: Bluetooth.defaultAdapter

  // ================================================================ musique
  Panel {
    shown: s.panel === "music"
    x: 8; width: 300; height: 330
    ClippingRectangle {
      x: 16; y: 16; width: 92; height: 92; radius: 46; color: win.card
      Image { anchors.fill: parent; source: s.cover; fillMode: Image.PreserveAspectCrop; asynchronous: true }
      RotationAnimation on rotation { running: s.playing; from: 0; to: 360; duration: 20000; loops: Animation.Infinite }
    }
    Ring { x: 12; y: 12; width: 100; height: 100; value: s.progress; thickness: 3; color: win.acc; track: s.alpha(win.ink, 0.12) }
    Column {
      x: 124; y: 22; width: parent.width - 140; spacing: 3
      Text { width: parent.width; elide: Text.ElideRight; text: s.trackTitle || T.t("Rien en lecture"); font.family: win.font; font.pixelSize: 13; font.weight: Font.Bold; color: win.ink }
      Text { width: parent.width; elide: Text.ElideRight; text: s.trackArtist ? "par " + s.trackArtist : ""; font.family: win.font; font.pixelSize: 10; color: win.sub }
      Item { width: 1; height: 8 }
      Item {
        width: parent.width; height: 6
        Rectangle { width: parent.width; height: 4; radius: 2; color: s.alpha(win.ink, 0.12) }
        Rectangle { width: parent.width * s.progress; height: 4; radius: 2; color: win.acc }
      }
      Item {
        width: parent.width; height: 12
        Text { text: s.fmtTime(s.position); font.family: win.font; font.pixelSize: 9; color: win.sub }
        Text { anchors.right: parent.right; text: s.fmtTime(s.length); font.family: win.font; font.pixelSize: 9; color: win.sub }
      }
      Row {
        spacing: 14; topPadding: 4
        anchors.horizontalCenter: parent.horizontalCenter
        Ctl { icon: "skip_previous"; onClicked: if (s.player) s.player.previous() }
        Ctl { icon: s.playing ? "pause" : "play_arrow"; big: true; onClicked: s.playPause() }
        Ctl { icon: "skip_next"; onClicked: if (s.player) s.player.next() }
      }
    }
    Text { x: 16; y: 132; text: T.t("Spectre"); font.family: win.font; font.pixelSize: 11; font.weight: Font.Bold; color: win.acc }
    Text { anchors.right: parent.right; anchors.rightMargin: 16; y: 132; text: Math.round((win.sink && win.sink.audio ? win.sink.audio.volume : 0) * 100) + " %"; font.family: win.font; font.pixelSize: 10; color: win.sub }
    // Spectre en curseurs (comme un égaliseur) : la position suit cava en direct.
    Row {
      x: 16; y: 156; spacing: (parent.width - 32 - 10 * 10) / 9
      Repeater {
        model: 10
        delegate: Item {
          id: band
          required property int index
          readonly property real v: s.cavaValues.length ? (s.cavaValues[Math.floor(Math.pow(index / 10, 1.6) * s.cavaValues.length * 0.8)] || 0) / 100 : 0.15 + 0.1 * Math.sin(index)
          width: 10; height: 110
          Rectangle { anchors.horizontalCenter: parent.horizontalCenter; width: 3; height: parent.height; radius: 1.5; color: s.alpha(win.ink, 0.1) }
          Rectangle { anchors.horizontalCenter: parent.horizontalCenter; anchors.bottom: parent.bottom; width: 3; height: parent.height * band.v; radius: 1.5; color: s.alpha(win.acc, 0.6) }
          Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            y: (parent.height - 14) * (1 - band.v)
            width: 12; height: 14; radius: 4; color: win.acc
            Behavior on y { NumberAnimation { duration: 90 } }
          }
          Text { anchors.horizontalCenter: parent.horizontalCenter; anchors.top: parent.bottom; anchors.topMargin: 4
            text: ["31", "62", "125", "250", "500", "1k", "2k", "4k", "8k", "16k"][band.index]; font.family: win.font; font.pixelSize: 7; color: win.sub }
        }
      }
    }
    // Volume
    Item {
      x: 16; y: 296; width: parent.width - 32; height: 16
      MIcon { anchors.verticalCenter: parent.verticalCenter; icon: "volume_up"; size: 14; color: win.ink }
      Slider { x: 22; width: parent.width - 22; value: win.sink && win.sink.audio ? win.sink.audio.volume : 0
        onMoved: function(v) { if (win.sink && win.sink.audio) win.sink.audio.volume = v } }
    }
  }

  // ================================================================ tableau de bord
  Panel {
    id: dash
    shown: s.panel === "dash"
    width: Math.min(win.width - 120, 980); height: 470
    x: (win.width - width) / 2
    // calendrier
    Item {
      id: cal
      x: 26; y: 26; width: 220; height: 220
      property date month: new Date(win.now.getFullYear(), win.now.getMonth(), 1)
      Row {
        anchors.horizontalCenter: parent.horizontalCenter; spacing: 16
        Text { text: "‹"; font.family: win.font; font.pixelSize: 14; color: win.sub; MouseArea { anchors.fill: parent; onClicked: cal.month = new Date(cal.month.getFullYear(), cal.month.getMonth() - 1, 1) } }
        Text { width: 120; horizontalAlignment: Text.AlignHCenter; text: cal.month.toLocaleDateString(Qt.locale(T.loc), "MMMM yyyy").toUpperCase(); font.family: win.font; font.pixelSize: 11; font.weight: Font.Bold; color: win.ink }
        Text { text: "›"; font.family: win.font; font.pixelSize: 14; color: win.sub; MouseArea { anchors.fill: parent; onClicked: cal.month = new Date(cal.month.getFullYear(), cal.month.getMonth() + 1, 1) } }
      }
      Grid {
        y: 26; columns: 7
        Repeater {
          model: [T.t("Lu"), T.t("Ma"), T.t("Me"), T.t("Je"), T.t("Ve"), T.t("Sa"), T.t("Di")]
          delegate: Text { required property string modelData; width: 220 / 7; height: 22; horizontalAlignment: Text.AlignHCenter; text: modelData; font.family: win.font; font.pixelSize: 10; color: win.ink }
        }
        Repeater {
          model: 42
          delegate: Item {
            id: cd
            required property int index
            readonly property int lead: (cal.month.getDay() + 6) % 7
            readonly property date d: new Date(cal.month.getFullYear(), cal.month.getMonth(), index - lead + 1)
            readonly property bool inMonth: d.getMonth() === cal.month.getMonth()
            readonly property bool today: d.toDateString() === win.now.toDateString()
            width: 220 / 7; height: 26
            Rectangle { visible: cd.today; anchors.centerIn: parent; width: 22; height: 22; radius: 6; color: win.acc }
            Text { visible: cd.inMonth; anchors.centerIn: parent; text: cd.d.getDate(); font.family: win.font; font.pixelSize: 10; font.weight: cd.today ? Font.Bold : Font.Normal; color: cd.today ? win.accInk : win.ink }
          }
        }
      }
    }
    // horloge + orbite météo
    Item {
      id: orbit
      x: 270; y: 20; width: dash.width - 270 - 260; height: 250
      readonly property real rx: width * 0.46
      readonly property real ry: 90
      readonly property real cx: width / 2
      readonly property real cy: 130
      Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
          strokeColor: s.alpha(win.ink, 0.22); strokeWidth: 1; strokeStyle: ShapePath.DashLine; dashPattern: [2, 4]; fillColor: "transparent"
          PathAngleArc { centerX: orbit.cx; centerY: orbit.cy; radiusX: orbit.rx; radiusY: orbit.ry; startAngle: 0; sweepAngle: 360 }
        }
      }
      Column {
        anchors.horizontalCenter: parent.horizontalCenter; y: orbit.cy - 46
        Row {
          anchors.horizontalCenter: parent.horizontalCenter
          Text { text: Qt.formatTime(win.now, "HH:mm"); font.family: win.font; font.pixelSize: 54; font.weight: Font.Bold; color: win.ink }
          Text { anchors.baseline: parent.children[0].baseline; text: ":" + Qt.formatTime(win.now, "ss"); font.family: win.font; font.pixelSize: 20; font.weight: Font.Bold; color: win.acc }
        }
        Text { anchors.horizontalCenter: parent.horizontalCenter; text: win.cap(win.now.toLocaleDateString(Qt.locale(T.loc), "dddd d MMMM")); font.family: win.font; font.pixelSize: 11; color: win.sub }
      }
      // heures à venir, posées sur l'ellipse (la première est l'heure courante, en avant)
      Repeater {
        model: s.weather && s.weather.hourly ? s.weather.hourly.slice(0, 9) : []
        delegate: Rectangle {
          id: hr
          required property var modelData
          required property int index
          readonly property real a: Math.PI * 0.5 - index * Math.PI * 2 / 9
          readonly property bool now: index === 0
          x: orbit.cx + orbit.rx * Math.cos(a) - width / 2
          y: orbit.cy + orbit.ry * Math.sin(a) - height / 2
          width: now ? 52 : 40; height: now ? 86 : 54; radius: width / 2
          color: now ? win.acc : s.alpha(s.surfaceHigh, 0.9)
          z: now ? 2 : 1
          Column {
            anchors.centerIn: parent; spacing: 2
            Text { anchors.horizontalCenter: parent.horizontalCenter; text: hr.modelData.h; font.family: win.font; font.pixelSize: hr.now ? 10 : 7; font.weight: Font.Bold; color: hr.now ? win.accInk : win.sub }
            MIcon { anchors.horizontalCenter: parent.horizontalCenter; icon: s.weatherInfo(hr.modelData.code)[1]; size: hr.now ? 20 : 13; fill: 1; color: hr.now ? win.accInk : win.ink }
            Text { anchors.horizontalCenter: parent.horizontalCenter; text: hr.modelData.temp + "°"; font.family: win.font; font.pixelSize: hr.now ? 12 : 8; font.weight: Font.Bold; color: hr.now ? win.accInk : win.ink }
          }
        }
      }
    }
    // météo du jour
    Column {
      x: dash.width - 240; y: 30; width: 214; spacing: 6
      Text { anchors.right: parent.right; text: win.cap(win.now.toLocaleDateString(Qt.locale(T.loc), "dddd")).toUpperCase(); font.family: win.font; font.pixelSize: 11; font.weight: Font.Bold; color: win.ink }
      Text { anchors.right: parent.right; text: s.weather ? s.weather.temp + "°" : "--"; font.family: win.font; font.pixelSize: 56; font.weight: Font.Bold; color: s.tertiary }
      Text { anchors.right: parent.right; text: win.cap(s.weatherDesc); font.family: win.font; font.pixelSize: 11; color: win.sub }
      Item { width: 1; height: 16 }
      Row {
        anchors.right: parent.right; spacing: 10
        Repeater {
          model: s.weather ? [[s.weather.wind + "km", "air", "VENT", Math.min(1, s.weather.wind / 60)], [s.weather.humidity + "%", "humidity_percentage", T.t("HUMID."), s.weather.humidity / 100],
                              [s.weather.rain + "%", "rainy", "PLUIE", s.weather.rain / 100], [s.weather.feels + "°", "thermostat", "RESS.", Math.min(1, Math.max(0, (s.weather.feels + 10) / 50))]] : []
          delegate: Column {
            required property var modelData
            spacing: 4
            Item {
              width: 44; height: 44
              Ring { anchors.fill: parent; value: modelData[3]; thickness: 2.5; color: win.acc; track: s.alpha(win.ink, 0.12) }
              Text { anchors.centerIn: parent; text: modelData[0]; font.family: win.font; font.pixelSize: 9; font.weight: Font.Bold; color: win.ink }
            }
            Row { anchors.horizontalCenter: parent.horizontalCenter; spacing: 2
              MIcon { icon: modelData[1]; size: 9; color: win.sub }
              Text { text: modelData[2]; font.family: win.font; font.pixelSize: 7; color: win.sub } }
          }
        }
      }
    }
    // bas : soleil et à faire
    Rectangle { x: 26; y: 296; width: dash.width - 52; height: 1; color: s.alpha(win.ink, 0.08) }
    Row {
      x: 26; y: 310; spacing: 10
      MIcon { icon: "calendar_month"; size: 15; color: win.sub }
      Text { text: win.cap(win.now.toLocaleDateString(Qt.locale(T.loc), "dddd d MMM")) + T.t("  (aujourd'hui)"); font.family: win.font; font.pixelSize: 11; font.weight: Font.Bold; color: win.ink }
    }
    Row {
      x: 26; y: 346; width: dash.width - 52; height: 100
      Repeater {
        model: {
          var out = []
          if (s.weather) { out.push([T.t("Lever du soleil"), "wb_twilight", s.weather.sunrise, s.weather.city]); out.push([T.t("Coucher du soleil"), "wb_sunny", s.weather.sunset, "↑ " + s.weather.max + "°  ↓ " + s.weather.min + "°"]) }
          var t = s.todos.filter(function(x) { return !x.done })
          out.push([T.t("À faire"), "checklist", t.length ? t[0].text : T.t("Rien de prévu"), t.length > 1 ? "+ " + (t.length - 1) + " autres" : ""])
          return out
        }
        delegate: Item {
          required property var modelData
          required property int index
          width: (dash.width - 52) / 3; height: 90
          Rectangle { visible: index > 0; width: 1; height: 60; color: s.alpha(win.ink, 0.12) }
          Column {
            x: 14; spacing: 6
            Text { text: modelData[0]; font.family: win.font; font.pixelSize: 12; font.weight: Font.Bold; color: win.ink }
            Row { spacing: 6; MIcon { icon: modelData[1]; size: 12; color: win.sub }
              Text { text: modelData[2]; font.family: win.font; font.pixelSize: 11; color: win.ink } }
            Row { spacing: 6; MIcon { icon: "location_on"; size: 12; color: win.sub; visible: index === 0 }
              Text { text: modelData[3]; font.family: win.font; font.pixelSize: 10; color: win.sub } }
          }
        }
      }
    }
  }

  // ================================================================ batterie
  property string profile: ""
  Process { id: ppGet; running: true; command: ["sh", "-c", "powerprofilesctl get 2>/dev/null"]; stdout: StdioCollector { onStreamFinished: win.profile = text.trim() } }
  Panel {
    shown: s.panel === "battery"
    width: 300; height: 410
    x: win.width - width - 8
    Text { x: 18; y: 18; text: Qt.formatTime(win.now, "HH : mm"); font.family: win.font; font.pixelSize: 12; font.weight: Font.Bold; color: win.sub }
    Item {
      id: batRing
      anchors.horizontalCenter: parent.horizontalCenter; y: 40
      width: 170; height: 170
      Ring { anchors.fill: parent; value: Math.max(0, s.batteryPct) / 100; thickness: 10; color: win.acc; track: s.alpha(win.ink, 0.1) }
      Column {
        anchors.centerIn: parent
        Row { anchors.horizontalCenter: parent.horizontalCenter; spacing: 4
          MIcon { anchors.verticalCenter: parent.verticalCenter; icon: s.charging ? "bolt" : "battery_full"; size: 22; fill: 1; color: win.ink }
          Text { text: (s.batteryPct >= 0 ? s.batteryPct : 100) + "%"; font.family: win.font; font.pixelSize: 34; font.weight: Font.Bold; color: win.ink } }
        Text { anchors.horizontalCenter: parent.horizontalCenter; text: s.charging ? T.t("EN CHARGE") : T.t("SUR BATTERIE"); font.family: win.font; font.pixelSize: 9; color: win.sub }
      }
    }
    Column {
      x: 22; y: 234; width: parent.width - 44; spacing: 12
      Row { spacing: 10; width: parent.width
        MIcon { icon: "light_mode"; size: 14; color: win.ink }
        Slider { width: parent.width - 24; value: Math.max(0, s.brightness); onMoved: function(v) { s.setBrightness(v) } } }
      Row { spacing: 10; width: parent.width
        MIcon { icon: "volume_up"; size: 14; color: win.ink }
        Slider { width: parent.width - 24; value: win.sink && win.sink.audio ? win.sink.audio.volume : 0; tint: s.tertiary
          onMoved: function(v) { if (win.sink && win.sink.audio) win.sink.audio.volume = v } } }
      Row {
        anchors.horizontalCenter: parent.horizontalCenter; spacing: 12; topPadding: 6
        Repeater {
          model: [["lock", "lock"], ["suspend", "bedtime"], ["reboot", "restart_alt"], ["poweroff", "power_settings_new"]]
          delegate: Rectangle {
            required property var modelData
            width: 50; height: 38; radius: 10
            color: pma.containsMouse ? s.alpha(win.acc, 0.25) : win.card
            MIcon { anchors.centerIn: parent; icon: modelData[1]; size: 17; color: win.ink }
            MouseArea { id: pma; anchors.fill: parent; hoverEnabled: true; onClicked: s.power(modelData[0]) }
          }
        }
      }
      Row {
        anchors.horizontalCenter: parent.horizontalCenter; spacing: 6
        visible: win.profile !== ""
        Repeater {
          model: [["power-saver", T.t("Économie"), "eco"], ["balanced", T.t("Équilibré"), "balance"], ["performance", "Perf.", "bolt"]]
          delegate: Rectangle {
            required property var modelData
            readonly property bool cur: win.profile === modelData[0]
            width: 80; height: 26; radius: 8
            color: cur ? s.tertiary : win.card
            Row { anchors.centerIn: parent; spacing: 4
              MIcon { icon: modelData[2]; size: 12; color: cur ? s.colOnPrimary : win.ink }
              Text { text: modelData[1]; font.family: win.font; font.pixelSize: 9; font.weight: Font.Bold; color: cur ? s.colOnPrimary : win.ink } }
            MouseArea { anchors.fill: parent; onClicked: { win.profile = modelData[0]; Quickshell.execDetached(["powerprofilesctl", "set", modelData[0]]) } }
          }
        }
      }
    }
  }

  // ================================================================ réseau
  Panel {
    id: net
    shown: s.panel === "net"
    width: 420; height: 380
    x: win.width - width - 8
    Component.onCompleted: s.scanWifi()
    // bulles : Wi-Fi au centre, appareils Bluetooth autour
    Item {
      id: bubbles
      x: 0; y: 10; width: parent.width; height: 210
      Rectangle {
        id: wifiBub
        anchors.centerIn: parent
        width: 110; height: 110; radius: 55
        color: s.wifiOn ? win.acc : win.card
        Column {
          anchors.centerIn: parent; spacing: 2
          MIcon { anchors.horizontalCenter: parent.horizontalCenter; icon: s.wifiOn ? "wifi" : "wifi_off"; size: 26; color: s.wifiOn ? win.accInk : win.ink }
          Text { anchors.horizontalCenter: parent.horizontalCenter; width: 90; horizontalAlignment: Text.AlignHCenter; elide: Text.ElideRight
            text: s.wifiList.length && s.wifiList[0].active ? s.wifiList[0].ssid : (s.wifiOn ? "Wi-Fi" : T.t("Désactivé")); font.family: win.font; font.pixelSize: 10; font.weight: Font.Bold; color: s.wifiOn ? win.accInk : win.ink }
        }
        MouseArea { anchors.fill: parent; onClicked: s.setWifi(!s.wifiOn) }
      }
      Repeater {
        model: { var out = [], d = win.bt && win.bt.devices ? win.bt.devices.values : []; for (var i = 0; i < d.length && i < 6; i++) out.push(d[i]); return out }
        delegate: Rectangle {
          id: bub
          required property var modelData
          required property int index
          readonly property real a: -Math.PI / 2 + index * Math.PI / 3 + 0.4
          x: bubbles.width / 2 + 125 * Math.cos(a) - width / 2
          y: bubbles.height / 2 + 82 * Math.sin(a) - height / 2
          width: 64; height: 64; radius: 32
          color: modelData.connected ? s.tertiary : win.card
          Column {
            anchors.centerIn: parent; spacing: 1
            MIcon { anchors.horizontalCenter: parent.horizontalCenter; icon: String(bub.modelData.icon || "").indexOf("audio") >= 0 ? "headphones" : "bluetooth"; size: 18; color: bub.modelData.connected ? s.colOnPrimary : win.ink }
            Text { anchors.horizontalCenter: parent.horizontalCenter; width: 56; horizontalAlignment: Text.AlignHCenter; elide: Text.ElideRight; text: bub.modelData.name || ""; font.family: win.font; font.pixelSize: 7; color: bub.modelData.connected ? s.colOnPrimary : win.ink }
          }
          MouseArea { anchors.fill: parent; onClicked: bub.modelData.connected = !bub.modelData.connected }
        }
      }
    }
    ListView {
      x: 16; y: 226; width: parent.width - 32; height: parent.height - 270
      clip: true; spacing: 4
      model: s.wifiList
      delegate: Rectangle {
        id: wl
        required property var modelData
        width: ListView.view.width; height: 26; radius: 8
        color: wlma.containsMouse || modelData.active ? win.card : "transparent"
        Row { x: 10; anchors.verticalCenter: parent.verticalCenter; spacing: 8
          MIcon { icon: wl.modelData.signal > 60 ? "network_wifi" : "network_wifi_2_bar"; size: 13; color: wl.modelData.active ? win.acc : win.ink }
          Text { text: wl.modelData.ssid; font.family: win.font; font.pixelSize: 10; color: win.ink; width: 260; elide: Text.ElideRight } }
        Text { anchors.right: parent.right; anchors.rightMargin: 10; anchors.verticalCenter: parent.verticalCenter; text: wl.modelData.signal + "%"; font.family: win.font; font.pixelSize: 9; color: win.sub }
        MouseArea { id: wlma; anchors.fill: parent; hoverEnabled: true; onClicked: if (!wl.modelData.active) s.connectWifi(wl.modelData.ssid) }
      }
    }
    Row {
      anchors.horizontalCenter: parent.horizontalCenter; anchors.bottom: parent.bottom; anchors.bottomMargin: 12; spacing: 8
      Rectangle { width: 120; height: 26; radius: 8; color: s.wifiOn ? win.acc : win.card
        Text { anchors.centerIn: parent; text: "♥ Wi-Fi"; font.family: win.font; font.pixelSize: 10; font.weight: Font.Bold; color: s.wifiOn ? win.accInk : win.ink }
        MouseArea { anchors.fill: parent; onClicked: s.setWifi(!s.wifiOn) } }
      Rectangle { width: 120; height: 26; radius: 8; color: win.bt && win.bt.enabled ? win.acc : win.card
        Text { anchors.centerIn: parent; text: "ᛒ Bluetooth"; font.family: win.font; font.pixelSize: 10; font.weight: Font.Bold; color: win.bt && win.bt.enabled ? win.accInk : win.ink }
        MouseArea { anchors.fill: parent; onClicked: if (win.bt) win.bt.enabled = !win.bt.enabled } }
    }
  }

  // ================================================================ briques
  component Panel: Item {
    id: pn
    property bool shown: false
    default property alias content: body.data
    visible: opacity > 0.01
    y: win.top + (shown && win.revealed ? 0 : -16)
    opacity: shown && win.revealed ? 1 : 0
    Behavior on opacity { NumberAnimation { duration: 180 } }
    Behavior on y { NumberAnimation { duration: 320; easing.type: Easing.OutBack; easing.overshoot: 1.2 } }
    RectangularShadow { anchors.fill: body; radius: 18; blur: 30; spread: 0; offset.y: 8; color: Qt.rgba(0, 0, 0, 0.45) }
    Rectangle {
      id: body
      anchors.fill: parent
      radius: 18
      color: win.bg
      border.width: 1; border.color: s.alpha(win.ink, 0.07)
      MouseArea { anchors.fill: parent }
    }
  }
  component Ctl: Rectangle {
    id: c
    property string icon: ""
    property bool big: false
    signal clicked()
    width: big ? 40 : 28; height: big ? 40 : 28; radius: big ? 12 : 14
    color: big ? win.acc : (cma.containsMouse ? win.card : "transparent")
    MIcon { anchors.centerIn: parent; icon: c.icon; size: c.big ? 22 : 18; fill: 1; color: c.big ? win.accInk : win.ink }
    MouseArea { id: cma; anchors.fill: parent; hoverEnabled: true; onClicked: c.clicked() }
  }
  component Slider: Item {
    id: sl
    property real value: 0
    property color tint: win.acc
    signal moved(real v)
    height: 14
    Rectangle { anchors.verticalCenter: parent.verticalCenter; width: parent.width; height: 8; radius: 4; color: s.alpha(win.ink, 0.1) }
    Rectangle { anchors.verticalCenter: parent.verticalCenter; width: Math.max(8, parent.width * Math.max(0, Math.min(1, sl.value))); height: 8; radius: 4; color: sl.tint }
    MouseArea {
      anchors.fill: parent
      onPressed: function(m) { sl.moved(Math.max(0, Math.min(1, m.x / width))) }
      onPositionChanged: function(m) { if (pressed) sl.moved(Math.max(0, Math.min(1, m.x / width))) }
    }
  }
}
