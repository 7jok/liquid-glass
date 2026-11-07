import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets
import "T.js" as T

// Widgets en plus pour les bureaux qui en manquaient (Espace, Forêt, Rubans, Violet) :
// météo, calendrier, jauges, phase de la Lune, citation, musique, à faire, horloge.
// Chaque carte prend la peau du style et se glisse où l'on veut ; la place est gardée
// par style dans ~/.config/liquid-glass/linux-layout.json.
PanelWindow {
  id: win
  property var service: null
  readonly property var s: service
  property var cards: []          // [[id, x, y], …] en fractions de l'écran

  color: "transparent"
  anchors { top: true; bottom: true; left: true; right: true }
  exclusionMode: ExclusionMode.Normal
  WlrLayershell.layer: WlrLayer.Bottom
  WlrLayershell.namespace: "liquid-glass-linux-extras"
  WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
  mask: Region { id: hits }

  readonly property color ink: s.colOnSurface
  readonly property color sub: s.colOnSurfaceVariant
  readonly property color acc: s.primary
  readonly property color face: s.alpha(s.surfaceMid, 0.82)
  readonly property bool hard: s.shadowMode === "hard"
  readonly property string font: s.sansFont
  readonly property string num: s.numFont
  property date now: new Date()
  Timer { interval: 30000; repeat: true; running: true; triggeredOnStart: true; onTriggered: win.now = new Date() }

  readonly property var quotes: [T.t("Respire un coup."), T.t("Petit à petit."), T.t("Garde le cap."), T.t("Reste curieux."),
                                 T.t("Un pas après l'autre."), T.t("Fais simple."), T.t("Le café d'abord."), T.t("Sois fier de toi.")]

  // Phase de la Lune : âge en jours depuis une nouvelle lune connue (6 janvier 2000).
  readonly property real moonAge: ((now.getTime() / 86400000 - 10962.75) % 29.530588 + 29.530588) % 29.530588
  readonly property string moonName: {
    var a = moonAge
    if (a < 1.85) return T.t("Nouvelle lune")
    if (a < 5.54) return T.t("Premier croissant")
    if (a < 9.23) return T.t("Premier quartier")
    if (a < 12.92) return T.t("Gibbeuse croissante")
    if (a < 16.61) return T.t("Pleine lune")
    if (a < 20.3) return T.t("Gibbeuse décroissante")
    if (a < 23.99) return T.t("Dernier quartier")
    if (a < 27.68) return T.t("Dernier croissant")
    return T.t("Nouvelle lune")
  }

  Repeater {
    model: win.cards
    Item {
      id: slot
      required property var modelData
      readonly property string kind: modelData[0]
      readonly property string key: win.s.style + ":" + kind
      width: card.width; height: card.height
      Component.onCompleted: { hits.regions = hits.regions.concat([reg]); place() }
      Region { id: reg; item: slot }
      function place() {
        var p = win.s.layoutPos[key]
        x = p ? Math.min(p.x, win.width - width) : Math.round(win.width * modelData[1])
        y = p ? Math.min(p.y, win.height - height) : Math.round(win.height * modelData[2])
      }
      Connections { target: win; function onWidthChanged() { slot.place() } }
      DragHandler { target: slot; onActiveChanged: if (!active) win.s.savePos(slot.key, slot.x, slot.y) }

      Rectangle { visible: win.hard; x: 6; y: 6; width: card.width; height: card.height; color: win.s.colOnSurface; radius: card.radius }
      Rectangle {
        id: card
        width: body.item ? body.item.implicitWidth + 32 : 0
        height: body.item ? body.item.implicitHeight + 28 : 0
        radius: win.s.radius
        color: win.face
        border.color: win.s.outlineVariant; border.width: win.s.borderW
        Loader {
          id: body
          x: 16; y: 14
          sourceComponent: ({ weather: weatherC, calendar: calC, gauges: gaugeC, moon: moonC, quote: quoteC,
                              music: musicC, todo: todoC, clock: clockC })[slot.kind] || null
        }
      }
    }
  }

  component Label_: Text {
    color: win.sub; font.family: win.font; font.pixelSize: 11; font.weight: Font.DemiBold
    font.capitalization: Font.AllUppercase; font.letterSpacing: 1
  }

  Component {
    id: clockC
    Column {
      spacing: 0
      Text { text: Qt.formatTime(win.now, "HH:mm"); color: win.ink; font.family: win.s.displayFont; font.pixelSize: 64; font.weight: Font.Bold }
      Text { text: win.now.toLocaleDateString(Qt.locale(T.loc), "dddd d MMMM"); color: win.sub; font.family: win.font; font.pixelSize: 15 }
    }
  }
  Component {
    id: weatherC
    Column {
      spacing: 8
      Label_ { text: win.s.weather ? win.s.weather.city : T.t("Météo") }
      Row {
        spacing: 12
        MIcon { anchors.verticalCenter: parent.verticalCenter; icon: win.s.weatherIcon; size: 40; fill: 1; color: win.acc }
        Column {
          Text { text: win.s.weather ? win.s.weather.temp + "°" : "--"; color: win.ink; font.family: win.num; font.pixelSize: 34; font.weight: Font.DemiBold }
          Text { text: win.s.weatherDesc; color: win.sub; font.family: win.font; font.pixelSize: 12 }
        }
      }
      Row {
        spacing: 10
        Repeater {
          model: win.s.weather && win.s.weather.hourly ? win.s.weather.hourly.filter(function(h, i) { return i % 2 === 0 }).slice(0, 5) : []
          Column {
            id: hr
            required property var modelData
            spacing: 2
            Text { anchors.horizontalCenter: parent.horizontalCenter; text: hr.modelData.h.slice(0, 2) + "h"; color: win.sub; font.family: win.font; font.pixelSize: 10 }
            MIcon { anchors.horizontalCenter: parent.horizontalCenter; icon: win.s.weatherInfo(hr.modelData.code)[1]; size: 16; color: win.ink }
            Text { anchors.horizontalCenter: parent.horizontalCenter; text: hr.modelData.temp + "°"; color: win.ink; font.family: win.num; font.pixelSize: 11 }
          }
        }
      }
    }
  }
  Component {
    id: calC
    Column {
      spacing: 6
      readonly property int first: (new Date(win.now.getFullYear(), win.now.getMonth(), 1).getDay() + 6) % 7
      readonly property int days: new Date(win.now.getFullYear(), win.now.getMonth() + 1, 0).getDate()
      Label_ { text: win.now.toLocaleDateString(Qt.locale(T.loc), "MMMM yyyy") }
      Grid {
        id: g
        columns: 7; spacing: 2
        Repeater {
          model: 7
          Text { required property int index; width: 26; horizontalAlignment: Text.AlignHCenter; text: Qt.locale(T.loc).dayName((index + 1) % 7, Locale.NarrowFormat); color: win.sub; font.family: win.font; font.pixelSize: 10 }
        }
        Repeater {
          model: g.parent.first + g.parent.days
          Rectangle {
            required property int index
            readonly property int d: index - g.parent.first + 1
            readonly property bool today: d === win.now.getDate()
            width: 26; height: 22; radius: win.hard ? 0 : 11
            color: today ? win.acc : "transparent"
            Text { anchors.centerIn: parent; visible: parent.d > 0; text: parent.d; color: parent.today ? win.s.colOnPrimary : win.ink; font.family: win.num; font.pixelSize: 11 }
          }
        }
      }
    }
  }
  Component {
    id: gaugeC
    Row {
      spacing: 14
      Repeater {
        model: [[T.t("Proc."), win.s.cpu], ["RAM", win.s.memPct / 100], [T.t("Disque"), win.s.diskPct / 100]]
        Column {
          id: gg
          required property var modelData
          spacing: 4
          Canvas {
            width: 58; height: 58
            property real v: Math.max(0, Math.min(1, Number(gg.modelData[1]) || 0))
            onVChanged: requestPaint()
            onPaint: {
              var c = getContext("2d")
              c.reset(); c.lineWidth = 6; c.lineCap = win.hard ? "butt" : "round"
              c.strokeStyle = win.s.surfaceHighest; c.beginPath(); c.arc(29, 29, 24, 0, Math.PI * 2); c.stroke()
              c.strokeStyle = win.acc; c.beginPath(); c.arc(29, 29, 24, -Math.PI / 2, -Math.PI / 2 + Math.PI * 2 * v); c.stroke()
            }
            Text { anchors.centerIn: parent; text: Math.round(parent.v * 100); color: win.ink; font.family: win.num; font.pixelSize: 14; font.weight: Font.DemiBold }
          }
          Text { anchors.horizontalCenter: parent.horizontalCenter; text: gg.modelData[0]; color: win.sub; font.family: win.font; font.pixelSize: 10 }
        }
      }
    }
  }
  Component {
    id: moonC
    Row {
      spacing: 14
      Canvas {
        width: 56; height: 56
        property real a: win.moonAge
        onAChanged: requestPaint()
        onPaint: {
          var c = getContext("2d"), r = 26, ph = a / 29.530588, k = Math.cos(ph * 2 * Math.PI)
          c.reset()
          c.fillStyle = win.s.surfaceHighest; c.beginPath(); c.arc(28, 28, r, 0, Math.PI * 2); c.fill()
          c.fillStyle = win.ink; c.beginPath()
          var waxing = ph < 0.5
          c.arc(28, 28, r, -Math.PI / 2, Math.PI / 2, !waxing)
          c.ellipse(28 - Math.abs(k) * r, 2, Math.abs(k) * r * 2, r * 2)
          c.beginPath()
          c.arc(28, 28, r, -Math.PI / 2, Math.PI / 2, !waxing)
          for (var t = 0; t <= 40; t++) {
            var ang = Math.PI / 2 - t / 40 * Math.PI
            c.lineTo(28 + (waxing ? -1 : 1) * k * r * Math.cos(ang), 28 + r * Math.sin(ang))
          }
          c.fill()
        }
      }
      Column {
        anchors.verticalCenter: parent.verticalCenter
        Label_ { text: T.t("Lune") }
        Text { text: win.moonName; color: win.ink; font.family: win.font; font.pixelSize: 15; font.weight: Font.DemiBold }
        Text { text: Math.round(win.moonAge) + T.t(" jours"); color: win.sub; font.family: win.font; font.pixelSize: 11 }
      }
    }
  }
  Component {
    id: quoteC
    Column {
      spacing: 4
      Label_ { text: T.t("Pense du jour") }
      Text {
        width: 220; wrapMode: Text.WordWrap
        text: win.quotes[(win.now.getDate() + win.now.getMonth()) % win.quotes.length]
        color: win.ink; font.family: win.s.displayFont; font.pixelSize: 20; font.weight: Font.DemiBold
      }
    }
  }
  Component {
    id: musicC
    Row {
      spacing: 12
      ClippingRectangle {
        width: 54; height: 54; radius: win.hard ? 0 : 10; color: win.s.surfaceHighest
        Image { anchors.fill: parent; source: win.s.cover; fillMode: Image.PreserveAspectCrop; asynchronous: true }
      }
      Column {
        anchors.verticalCenter: parent.verticalCenter
        width: 170; spacing: 2
        Text { width: parent.width; text: win.s.trackTitle || T.t("Aucune musique"); color: win.ink; font.family: win.font; font.pixelSize: 13; font.weight: Font.DemiBold; elide: Text.ElideRight; textFormat: Text.PlainText }
        Text { width: parent.width; text: win.s.trackArtist; color: win.sub; font.family: win.font; font.pixelSize: 11; elide: Text.ElideRight; textFormat: Text.PlainText }
        Row {
          spacing: 10
          MIcon { icon: "skip_previous"; size: 20; fill: 1; color: win.ink; TapHandler { onTapped: if (win.s.player) win.s.player.previous() } }
          MIcon { icon: win.s.playing ? "pause" : "play_arrow"; size: 20; fill: 1; color: win.acc; TapHandler { onTapped: win.s.playPause() } }
          MIcon { icon: "skip_next"; size: 20; fill: 1; color: win.ink; TapHandler { onTapped: if (win.s.player) win.s.player.next() } }
        }
      }
    }
  }
  Component {
    id: todoC
    Column {
      spacing: 5
      width: 210
      Label_ { text: T.t("À faire") }
      Text { visible: win.s.todos.length === 0; text: T.t("Rien pour l'instant"); color: win.sub; font.family: win.font; font.pixelSize: 12 }
      Repeater {
        model: win.s.todos.slice(0, 6)
        Row {
          id: td
          required property var modelData
          required property int index
          spacing: 8
          MIcon { icon: td.modelData.done ? "check_circle" : "radio_button_unchecked"; size: 16; fill: td.modelData.done ? 1 : 0; color: win.acc; TapHandler { onTapped: win.s.toggleTodo(td.index) } }
          Text { width: 180; text: td.modelData.text; color: td.modelData.done ? win.sub : win.ink; font.strikeout: td.modelData.done; font.family: win.font; font.pixelSize: 12; elide: Text.ElideRight; textFormat: Text.PlainText }
        }
      }
    }
  }
}
