import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Widgets
import "T.js" as T

// Verrouillage du style Forêt, d'après la vidéo d'ilyamiro :
//  • au repos : le fond net, l'heure « 22 : 31 » au centre et la date en petites capitales ;
//  • au moindre geste : le fond se floute, une carte s'ouvre au centre (avatar, « jok • Entrez
//    le code », champ à carrés, bouton rose, langue et batterie), puis s'élargit des deux côtés :
//    météo, jauges en colonnes (processeur, mémoire, température), disque et réseau à gauche ;
//    notifications (Effacer, Silencieux) et lecteur avec spectre à droite.
// Teintes : mousse (vert tilleul) ou cendre (rose, comme la vidéo).
Item {
  id: f
  property var lock: null
  readonly property var lk: lock
  readonly property real k: Math.min(width / 1280, height / 720)
  readonly property string tone: lk ? lk.tone("foret_tone", "mousse") : "mousse"
  readonly property var p: tone === "cendre"
    ? { card: "#2b2324", tile: "#3a3031", tile2: "#463a3b", ink: "#efe4e4", sub: "#a8999a", acc: "#f4a7a7", accInk: "#3a1a1a", err: "#ff8a8a" }
    : { card: "#1f231a", tile: "#2c3224", tile2: "#384030", ink: "#e9eedb", sub: "#a3ab8e", acc: "#cfe89a", accInk: "#22300a", err: "#ffb4a8" }
  readonly property string mono: "JetBrainsMono Nerd Font"

  readonly property rect fieldBox: {
    var c = field.mapToItem(f, 0, 0)
    return Qt.rect(c.x, c.y, field.width, field.height)
  }

  LockData { id: data; running: f.awake }

  // Réveil : une touche ou la souris ; retour au repos après 12 s sans rien.
  property bool awake: false
  property bool wide: false
  function poke() { awake = true; idle.restart() }
  onLockChanged: if (lock && lock.passwordText.length > 0) poke()
  Timer { id: idle; interval: 12000; onTriggered: if (f.lk && f.lk.passwordText.length === 0) { f.awake = false; f.wide = false } }
  Timer { interval: 420; running: f.awake && !f.wide; onTriggered: f.wide = true }
  Connections { target: f.lk; function onPasswordTextChanged() { f.poke() } }
  MouseArea {
    anchors.fill: parent; hoverEnabled: true
    property point last
    onPositionChanged: function(m) { if (Math.abs(m.x - last.x) + Math.abs(m.y - last.y) > 6) f.poke(); last = Qt.point(m.x, m.y) }
    onClicked: { f.poke(); if (f.lk) f.lk.forcePasswordFocus() }
  }

  component Icon: Text {
    property string icon: ""
    property real size: 16
    text: icon
    font.family: "Material Symbols Rounded"; font.pixelSize: size
    font.variableAxes: ({ "FILL": 1, "wght": 500 })
    color: f.p.ink
  }
  component Mono: Text { font.family: f.mono; color: f.p.ink }

  // ---- fond, net au repos, flou et assombri au réveil
  Image {
    id: wall
    anchors.fill: parent
    source: f.lk && f.lk.backgroundPath && !f.lk.video ? "file://" + f.lk.backgroundPath : (f.lk && f.lk.videoPosterPath ? "file://" + f.lk.videoPosterPath : "")
    fillMode: Image.PreserveAspectCrop
    sourceSize: Qt.size(f.width, f.height)
    visible: false
  }
  property real blurT: awake ? 1 : 0
  Behavior on blurT { NumberAnimation { duration: 450; easing.type: Easing.OutCubic } }
  MultiEffect { anchors.fill: parent; source: wall; blurEnabled: true; blurMax: 48; blur: f.blurT; brightness: -0.28 * f.blurT }

  // ---- heure de repos
  Column {
    anchors.horizontalCenter: parent.horizontalCenter
    y: f.height * 0.13
    opacity: 1 - f.blurT
    visible: opacity > 0
    spacing: 6 * f.k
    Row {
      anchors.horizontalCenter: parent.horizontalCenter
      spacing: 12 * f.k
      Mono { text: f.lk ? f.lk.hh : ""; font.pixelSize: 56 * f.k; font.weight: Font.Light }
      Mono { text: ":"; font.pixelSize: 46 * f.k; font.weight: Font.Light; opacity: 0.7; anchors.verticalCenter: parent.verticalCenter }
      Mono { text: f.lk ? f.lk.mm : ""; font.pixelSize: 56 * f.k; font.weight: Font.Light }
    }
    Mono {
      anchors.horizontalCenter: parent.horizontalCenter
      text: f.lk ? f.lk.now.toLocaleDateString(Qt.locale(T.loc), "dddd, d MMMM").toUpperCase() : ""
      font.pixelSize: 9 * f.k; font.letterSpacing: 2; opacity: 0.85
    }
  }

  // ---- la carte
  Rectangle {
    id: card
    readonly property real narrowW: 230 * f.k
    readonly property real fullW: 600 * f.k
    width: f.wide ? fullW : narrowW
    height: 268 * f.k
    anchors.horizontalCenter: parent.horizontalCenter
    y: f.height * 0.26
    radius: 14 * f.k
    color: f.p.card
    border.color: Qt.rgba(1, 1, 1, 0.06)
    clip: true
    opacity: f.awake ? 1 : 0
    scale: f.awake ? 1 : 0.92
    visible: opacity > 0
    Behavior on width { NumberAnimation { duration: 520; easing.type: Easing.OutCubic } }
    Behavior on opacity { NumberAnimation { duration: 260 } }
    Behavior on scale { NumberAnimation { duration: 320; easing.type: Easing.OutBack } }
    readonly property real colW: 180 * f.k
    readonly property real side: (width - narrowW) / 2

    // ======== centre
    Item {
      id: mid
      x: card.side; width: card.narrowW; height: card.height
      ClippingRectangle {
        id: avatar
        anchors.horizontalCenter: parent.horizontalCenter
        y: 30 * f.k
        width: 92 * f.k; height: width; radius: width / 2
        color: f.p.tile
        Image { anchors.fill: parent; source: "file://" + Quickshell.env("HOME") + "/.face"; fillMode: Image.PreserveAspectCrop; sourceSize: Qt.size(200, 200) }
      }
      Rectangle {
        id: who
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: avatar.bottom; anchors.topMargin: 14 * f.k
        width: whoT.implicitWidth + 18 * f.k; height: 20 * f.k; radius: 6 * f.k; color: f.p.tile
        Mono {
          id: whoT; anchors.centerIn: parent; font.pixelSize: 9 * f.k
          text: (f.lk ? f.lk.userName : "") + " • " + (f.lk && f.lk.authenticatingPassword ? T.t("Vérification") : f.lk && f.lk.errorState ? T.t("Code incorrect") : T.t("Entrez le code"))
          color: f.lk && f.lk.errorState ? f.p.err : f.p.ink
        }
      }
      Rectangle {
        id: field
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.horizontalCenterOffset: f.lk ? f.lk.shakeX : 0
        anchors.top: who.bottom; anchors.topMargin: 12 * f.k
        width: 196 * f.k; height: 26 * f.k; radius: 6 * f.k; color: f.p.tile
        Icon { x: 8 * f.k; anchors.verticalCenter: parent.verticalCenter; icon: "lock"; size: 12 * f.k; color: f.p.sub }
        Row {
          anchors.centerIn: parent
          spacing: 3 * f.k
          Repeater {
            model: f.lk ? Math.min(14, f.lk.passwordText.length) : 0
            Rectangle {
              required property int index
              width: 9 * f.k; height: width; radius: 2 * f.k
              color: index === (f.lk.passwordText.length - 1) ? f.p.sub : f.p.ink
              scale: 0; Component.onCompleted: scale = 1
              Behavior on scale { NumberAnimation { duration: 180; easing.type: Easing.OutBack } }
            }
          }
        }
        Rectangle {
          anchors.right: parent.right; anchors.rightMargin: -32 * f.k; anchors.verticalCenter: parent.verticalCenter
          width: 22 * f.k; height: width; radius: 5 * f.k
          color: f.lk && f.lk.authenticatingPassword ? f.p.tile2 : f.p.acc
          Icon { anchors.centerIn: parent; icon: "chevron_right"; size: 15 * f.k; color: f.p.accInk }
          MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: if (f.lk) f.lk.accept() }
        }
      }
      Row {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: field.bottom; anchors.topMargin: 12 * f.k
        spacing: 14 * f.k
        Row { spacing: 4; Icon { icon: "keyboard"; size: 11 * f.k; color: f.p.sub } Mono { text: "FR"; font.pixelSize: 8 * f.k } }
        Row { spacing: 4; Icon { icon: data.charging ? "battery_charging_full" : "battery_full"; size: 11 * f.k; color: f.p.sub }
              Mono { text: (data.battery < 0 ? "--" : data.battery) + "%"; font.pixelSize: 8 * f.k } }
      }
    }

    // ======== gauche : météo, jauges, disque, réseau
    Item {
      x: card.side - card.colW - 6 * f.k; y: 8 * f.k
      width: card.colW; height: card.height - 16 * f.k
      opacity: f.wide ? 1 : 0
      Behavior on opacity { NumberAnimation { duration: 300 } }
      Rectangle {
        id: wcard
        width: parent.width; height: 84 * f.k; radius: 10 * f.k; color: f.p.tile
        Icon { x: 10 * f.k; y: 8 * f.k; icon: data.wIcon; size: 26 * f.k; color: "#c8d4ff" }
        Column {
          anchors.right: parent.right; anchors.rightMargin: 10 * f.k; y: 8 * f.k
          Mono { anchors.right: parent.right; text: data.weather ? data.weather.city : ""; font.pixelSize: 9 * f.k; font.bold: true }
          Mono { anchors.right: parent.right; text: T.t(data.wDesc); font.pixelSize: 7 * f.k; color: f.p.sub }
        }
        Column {
          x: 10 * f.k; anchors.bottom: parent.bottom; anchors.bottomMargin: 8 * f.k
          Mono { text: data.weather ? data.weather.temp + "°" : "--"; font.pixelSize: 20 * f.k; font.bold: true }
          Mono { text: data.weather ? T.t("Ressenti") + " " + data.weather.feels + "°" : ""; font.pixelSize: 7 * f.k; color: f.p.sub }
        }
        Row {
          anchors.right: parent.right; anchors.rightMargin: 8 * f.k; anchors.bottom: parent.bottom; anchors.bottomMargin: 8 * f.k
          spacing: 6 * f.k
          Repeater {
            model: data.weather && data.weather.hourly ? f.nextHours(data.weather.hourly) : []
            Column {
              required property var modelData
              Mono { anchors.horizontalCenter: parent.horizontalCenter; text: parent.modelData.temp + "°"; font.pixelSize: 7 * f.k }
              Icon { anchors.horizontalCenter: parent.horizontalCenter; icon: data.weatherInfo(parent.modelData.code)[1]; size: 10 * f.k; color: f.p.sub }
              Mono { anchors.horizontalCenter: parent.horizontalCenter; text: parent.modelData.h; font.pixelSize: 6 * f.k; color: f.p.sub }
            }
          }
        }
      }
      Row {
        id: bars
        anchors.top: wcard.bottom; anchors.topMargin: 6 * f.k
        spacing: 6 * f.k
        Repeater {
          model: [["memory", "CPU", data.cpu, Math.round(data.cpu * 100) + "%"],
                  ["memory_alt", "RAM", data.memPct, data.memUsed.toFixed(1) + "G"],
                  ["device_thermostat", "Temp", Math.min(1, data.temp / 100), data.temp + "°"]]
          ClippingRectangle {
            id: bar
            required property var modelData
            required property int index
            width: (card.colW - 12 * f.k) / 3; height: 70 * f.k; radius: 8 * f.k; color: f.p.tile
            Rectangle {
              anchors.bottom: parent.bottom; width: parent.width
              height: bar.height * Math.max(0.04, bar.modelData[2])
              color: bar.index === 0 ? f.p.ink : f.p.acc
              opacity: bar.index === 0 ? 0.9 : 0.75
              Behavior on height { NumberAnimation { duration: 500 } }
            }
            Icon { x: 6 * f.k; y: 6 * f.k; icon: bar.modelData[0]; size: 9 * f.k; color: f.p.sub }
            Mono { anchors.right: parent.right; anchors.rightMargin: 6 * f.k; y: 5 * f.k; text: bar.modelData[1]; font.pixelSize: 7 * f.k; color: f.p.sub }
            Mono { anchors.right: parent.right; anchors.rightMargin: 6 * f.k; anchors.bottom: parent.bottom; anchors.bottomMargin: 4 * f.k
                   text: bar.modelData[3]; font.pixelSize: 11 * f.k; font.bold: true; color: bar.modelData[2] > 0.25 ? f.p.accInk : f.p.ink }
          }
        }
      }
      Row {
        anchors.top: bars.bottom; anchors.topMargin: 6 * f.k
        spacing: 6 * f.k
        ClippingRectangle {
          width: card.colW * 0.6; height: 64 * f.k; radius: 8 * f.k; color: f.p.tile
          Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: parent.height * data.diskPct; color: f.p.acc; opacity: 0.75 }
          Icon { x: 6 * f.k; y: 6 * f.k; icon: "hard_drive"; size: 9 * f.k; color: f.p.sub }
          Mono { anchors.right: parent.right; anchors.rightMargin: 6 * f.k; y: 5 * f.k; text: data.diskTotal.toFixed(0) + "G"; font.pixelSize: 7 * f.k; color: f.p.sub }
          Mono { x: 6 * f.k; anchors.bottom: parent.bottom; anchors.bottomMargin: 4 * f.k; text: data.diskUsed.toFixed(0) + "G"; font.pixelSize: 7 * f.k; color: f.p.accInk }
          Mono { anchors.right: parent.right; anchors.rightMargin: 6 * f.k; anchors.bottom: parent.bottom; anchors.bottomMargin: 4 * f.k; text: Math.round(data.diskPct * 100) + "%"; font.pixelSize: 11 * f.k; font.bold: true; color: f.p.accInk }
        }
        Rectangle {
          width: card.colW * 0.4 - 6 * f.k; height: 64 * f.k; radius: 8 * f.k; color: f.p.tile
          Icon { x: 6 * f.k; y: 6 * f.k; icon: "wifi"; size: 9 * f.k; color: f.p.sub }
          Mono { anchors.right: parent.right; anchors.rightMargin: 6 * f.k; y: 5 * f.k; text: T.t("Réseau"); font.pixelSize: 7 * f.k; color: f.p.sub }
          Column {
            x: 6 * f.k; anchors.bottom: parent.bottom; anchors.bottomMargin: 6 * f.k; spacing: 2
            Mono { text: "↑ " + data.human(data.up); font.pixelSize: 7 * f.k }
            Mono { text: "↓ " + data.human(data.down); font.pixelSize: 7 * f.k }
          }
        }
      }
    }

    // ======== droite : notifications et lecteur
    Item {
      x: card.side + card.narrowW + 6 * f.k; y: 8 * f.k
      width: card.colW; height: card.height - 16 * f.k
      opacity: f.wide ? 1 : 0
      Behavior on opacity { NumberAnimation { duration: 300 } }
      Rectangle {
        width: parent.width; height: parent.height - 52 * f.k; radius: 10 * f.k; color: f.p.tile
        Mono { x: 8 * f.k; y: 9 * f.k; text: "Notifications"; font.pixelSize: 8 * f.k; font.bold: true }
        Row {
          anchors.right: parent.right; anchors.rightMargin: 6 * f.k; y: 6 * f.k; spacing: 4 * f.k
          Row { anchors.verticalCenter: parent.verticalCenter; spacing: 2; Icon { icon: "close"; size: 9 * f.k } Mono { text: T.t("Effacer"); font.pixelSize: 7 * f.k } }
          Rectangle { width: sil.implicitWidth + 16 * f.k; height: 15 * f.k; radius: 4 * f.k; color: f.p.acc
            Row { id: sil; anchors.centerIn: parent; spacing: 2; Icon { icon: "notifications_off"; size: 8 * f.k; color: f.p.accInk } Mono { text: T.t("Silence"); font.pixelSize: 7 * f.k; color: f.p.accInk } } }
        }
        Column {
          x: 6 * f.k; y: 28 * f.k; width: parent.width - 12 * f.k; spacing: 4 * f.k
          Repeater {
            model: data.notifs.slice(0, 4)
            Rectangle {
              required property var modelData
              width: parent.width; height: 30 * f.k; radius: 6 * f.k; color: f.p.tile2
              Icon { x: 6 * f.k; anchors.verticalCenter: parent.verticalCenter; icon: "notifications"; size: 11 * f.k; color: f.p.acc }
              Column {
                x: 22 * f.k; anchors.verticalCenter: parent.verticalCenter; width: parent.width - 28 * f.k
                Mono { width: parent.width; elide: Text.ElideRight; textFormat: Text.PlainText; text: parent.parent.modelData.summary + "  · " + data.ago(parent.parent.modelData.ts); font.pixelSize: 7 * f.k; font.bold: true }
                Mono { width: parent.width; elide: Text.ElideRight; textFormat: Text.PlainText; text: String(parent.parent.modelData.body || "").replace(/\n/g, " "); font.pixelSize: 6.5 * f.k; color: f.p.sub }
              }
            }
          }
        }
      }
      ClippingRectangle {
        anchors.bottom: parent.bottom
        width: parent.width; height: 46 * f.k; radius: 10 * f.k; color: f.p.tile
        Row {
          anchors.bottom: parent.bottom; anchors.right: parent.right; anchors.rightMargin: 4 * f.k
          spacing: 2 * f.k; opacity: 0.5
          Repeater {
            model: 22
            Rectangle {
              required property int index
              anchors.bottom: parent.bottom; width: 3 * f.k; radius: 1; color: f.p.acc
              height: 6 * f.k
              SequentialAnimation on height {
                running: f.wide && f.lk && f.lk.hasTrack && f.lk.player.isPlaying; loops: Animation.Infinite
                NumberAnimation { to: (8 + (index * 13) % 22) * f.k; duration: 240 + (index * 37) % 200 }
                NumberAnimation { to: (4 + (index * 7) % 9) * f.k; duration: 260 + (index * 53) % 180 }
              }
            }
          }
        }
        ClippingRectangle {
          x: 6 * f.k; anchors.verticalCenter: parent.verticalCenter; width: 32 * f.k; height: width; radius: 5 * f.k; color: f.p.tile2
          Image { anchors.fill: parent; source: f.lk && f.lk.hasTrack ? f.lk.localCover : ""; fillMode: Image.PreserveAspectCrop; sourceSize: Qt.size(80, 80) }
        }
        Column {
          x: 44 * f.k; anchors.verticalCenter: parent.verticalCenter; width: parent.width - 100 * f.k
          Mono { width: parent.width; elide: Text.ElideRight; text: f.lk && f.lk.hasTrack ? f.lk.player.trackTitle : T.t("Aucune musique"); font.pixelSize: 8 * f.k; font.bold: true }
          Mono { width: parent.width; elide: Text.ElideRight; text: f.lk && f.lk.hasTrack ? (f.lk.player.trackArtist || "") : ""; font.pixelSize: 6.5 * f.k; color: f.p.sub }
        }
        Row {
          anchors.right: parent.right; anchors.rightMargin: 6 * f.k; y: 8 * f.k; spacing: 3 * f.k
          Repeater {
            model: [["skip_previous", 0], [f.lk && f.lk.hasTrack && f.lk.player.isPlaying ? "pause" : "play_arrow", 1], ["skip_next", 2]]
            Icon {
              required property var modelData
              icon: modelData[0]; size: 12 * f.k
              MouseArea {
                anchors.fill: parent; anchors.margins: -3; cursorShape: Qt.PointingHandCursor
                onClicked: { var pl = f.lk ? f.lk.player : null; if (pl) { if (parent.modelData[1] === 0) pl.previous(); else if (parent.modelData[1] === 1) pl.togglePlaying(); else pl.next() } f.poke() }
              }
            }
          }
        }
      }
    }
  }

  // ---- alimentation, en bas à droite
  Rectangle {
    anchors.right: parent.right; anchors.bottom: parent.bottom; anchors.margins: 16 * f.k
    width: 28 * f.k; height: width; radius: 7 * f.k; color: f.p.card
    opacity: f.awake ? 1 : 0
    Behavior on opacity { NumberAnimation { duration: 260 } }
    Icon { anchors.centerIn: parent; icon: "power_settings_new"; size: 14 * f.k; color: f.p.err }
    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: if (f.lk) { f.lk.powerOpen = !f.lk.powerOpen; f.lk.forcePasswordFocus() } }
  }

  function nextHours(list) {
    var h = new Date().getHours(), out = []
    for (var i = 0; i < list.length && out.length < 4; i++) {
      var hh = Number(String(list[i].h).slice(0, 2))
      if (i >= h && (i - h) % 3 === 0) out.push({ h: String(list[i].h).slice(0, 5), temp: list[i].temp, code: list[i].code })
    }
    return out
  }
}
