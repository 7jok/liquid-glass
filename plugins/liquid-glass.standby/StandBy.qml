import QtQuick
import QtQuick.Shapes
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris
import Quickshell.Services.UPower
import Quickshell.Wayland
import qs.Commons
import qs.Ui

// Liquid Glass — « En veille » (StandBy, ⌘⌥B ou Spotlight).
// Plein écran noir : à gauche une grande horloge (3 styles, ← →), à droite un
// widget (calendrier, lecture en cours, batterie ; molette ou ↑ ↓ pour changer).
// La nuit (22 h – 7 h) tout passe en rouge sombre, comme sur iPhone.
// Échap, clic ou n'importe quelle touche (sauf flèches) : sortir.
Item {
  id: root

  property var shell: null
  property var manifest: null
  property bool opened: false

  readonly property string home: Quickshell.env("HOME")
  readonly property string uiFont: "Inter"
  property date now: new Date()
  Timer { interval: 1000; repeat: true; running: root.opened; triggeredOnStart: true; onTriggered: root.now = new Date() }

  readonly property bool night: now.getHours() >= 22 || now.getHours() < 7
  readonly property color ink: night ? "#ff3b30" : "#ffffff"
  readonly property color inkDim: night ? Qt.rgba(1, 0.23, 0.19, 0.55) : Qt.rgba(1, 1, 1, 0.55)

  // Styles d'horloge (←/→) et panneaux de droite (↑/↓, molette), mémorisés.
  readonly property var clockStyles: ["bold", "analog", "light"]
  property int clockIndex: 0
  property int panelIndex: 0
  readonly property var player: {
    var list = Mpris.players.values
    for (var i = 0; i < list.length; i++) if (list[i].identity && String(list[i].identity).toLowerCase().indexOf("spotify") >= 0) return list[i]
    return list.length ? list[0] : null
  }
  readonly property var panels: player ? ["music", "calendar", "battery"] : ["calendar", "battery"]
  readonly property string panel: panels[((panelIndex % panels.length) + panels.length) % panels.length]

  FileView {
    id: state
    path: root.home + "/.cache/liquid-glass/standby.json"
    printErrors: false
    onLoaded: { try { var o = JSON.parse(text()); root.clockIndex = o.clock || 0; root.panelIndex = o.panel || 0 } catch (e) {} }
  }
  function save() { state.setText(JSON.stringify({ clock: root.clockIndex, panel: root.panelIndex })) }

  property var np: ({})
  FileView {
    path: root.home + "/.cache/liquid-glass/now-playing.json"
    watchChanges: true
    printErrors: false
    onFileChanged: reload()
    onLoaded: { try { root.np = JSON.parse(text()) || ({}) } catch (e) { root.np = ({}) } }
  }

  function open(payloadJson) { opened = true }
  function close() { opened = false }
  function dismiss() {
    opened = false
    if (shell && typeof shell.hide === "function") shell.hide((manifest && manifest.id) || "liquid-glass.standby")
  }

  ShellIpc {
    target: "liquid-glass.standby"
    function toggle(): void { if (root.opened) root.dismiss(); else if (root.shell) root.shell.summon((root.manifest && root.manifest.id) || "liquid-glass.standby", "") }
  }

  OverlayWindow {
    id: win
    shown: root.opened
    WlrLayershell.namespace: "liquid-glass-standby"

    Rectangle {
      anchors.fill: parent
      color: "black"
      opacity: win.contentRevealed ? 1 : 0
      Behavior on opacity { NumberAnimation { duration: 450; easing.type: Easing.OutCubic } }
    }

    Item {
      id: keys
      anchors.fill: parent
      focus: true
      Keys.onPressed: function(ev) {
        if (ev.key === Qt.Key_Left) { root.clockIndex = (root.clockIndex + root.clockStyles.length - 1) % root.clockStyles.length; root.save() }
        else if (ev.key === Qt.Key_Right) { root.clockIndex = (root.clockIndex + 1) % root.clockStyles.length; root.save() }
        else if (ev.key === Qt.Key_Up) { root.panelIndex--; root.save() }
        else if (ev.key === Qt.Key_Down) { root.panelIndex++; root.save() }
        else root.dismiss()
        ev.accepted = true
      }
    }
    MouseArea {
      anchors.fill: parent
      onClicked: root.dismiss()
      onWheel: function(w) { root.panelIndex += w.angleDelta.y < 0 ? 1 : -1; root.save() }
    }

    // Les deux moitiés, avec un léger glissement à l'ouverture.
    Item {
      id: stage
      anchors.fill: parent
      anchors.margins: Math.round(parent.height * 0.07)
      opacity: win.contentRevealed ? 1 : 0
      scale: win.contentRevealed ? 1 : 0.94
      Behavior on opacity { NumberAnimation { duration: 600; easing.type: Easing.OutCubic } }
      Behavior on scale { NumberAnimation { duration: 700; easing.type: Easing.OutBack; easing.overshoot: 1.1 } }
      readonly property real half: (width - spacing) / 2
      readonly property real spacing: Math.round(height * 0.06)

      // -------------------------------------------------------------- horloge
      Item {
        id: clockPane
        width: stage.half; height: stage.height
        readonly property string style: root.clockStyles[root.clockIndex]

        // Gros chiffres (styles « bold » et « light »).
        Text {
          visible: clockPane.style !== "analog"
          anchors.fill: parent
          horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
          fontSizeMode: Text.Fit; minimumPixelSize: 20
          textFormat: Text.PlainText
          text: Qt.formatTime(root.now, "H:mm")
          font.family: root.uiFont
          font.pixelSize: 600
          font.weight: clockPane.style === "light" ? Font.ExtraLight : Font.Black
          font.features: { "tnum": 1 }
          color: root.ink
          Behavior on color { ColorAnimation { duration: 800 } }
        }
        Text {
          visible: clockPane.style === "light"
          anchors.horizontalCenter: parent.horizontalCenter
          anchors.bottom: parent.bottom
          textFormat: Text.PlainText
          text: Qt.locale("fr_FR").toString(root.now, "dddd d MMMM")
          font.family: root.uiFont; font.pixelSize: Math.round(stage.height * 0.06); font.weight: Font.Medium
          color: root.inkDim
        }

        // Cadran (style « analog ») : fond sombre, aiguilles, trotteuse orange/rouge.
        Item {
          id: dial
          visible: clockPane.style === "analog"
          anchors.centerIn: parent
          width: Math.min(parent.width, parent.height); height: width
          Rectangle { anchors.fill: parent; radius: width / 2; color: root.night ? "#1a0503" : "#1c1c1e" }
          Repeater {
            model: 60
            Item {
              required property int index
              anchors.fill: parent
              rotation: index * 6
              Rectangle {
                x: dial.width / 2 - width / 2; y: dial.width * 0.035
                width: index % 5 === 0 ? dial.width * 0.012 : dial.width * 0.005
                height: index % 5 === 0 ? dial.width * 0.05 : dial.width * 0.025
                color: index % 5 === 0 ? root.ink : root.inkDim
              }
            }
          }
          Repeater {
            model: 12
            Text {
              required property int index
              readonly property real a: (index + 1) * Math.PI / 6
              readonly property real r: dial.width * 0.36
              x: dial.width / 2 + Math.sin(a) * r - width / 2
              y: dial.height / 2 - Math.cos(a) * r - height / 2
              text: index + 1
              font.family: root.uiFont; font.pixelSize: Math.round(dial.width * 0.09); font.weight: Font.DemiBold
              color: root.ink
            }
          }
          Item {
            anchors.fill: parent
            rotation: (root.now.getHours() % 12 + root.now.getMinutes() / 60) * 30
            Rectangle { width: dial.width * 0.03; height: dial.width * 0.26; radius: width / 2; color: root.ink; x: parent.width / 2 - width / 2; y: parent.height / 2 - height + width / 2 }
          }
          Item {
            anchors.fill: parent
            rotation: (root.now.getMinutes() + root.now.getSeconds() / 60) * 6
            Rectangle { width: dial.width * 0.022; height: dial.width * 0.4; radius: width / 2; color: root.ink; x: parent.width / 2 - width / 2; y: parent.height / 2 - height + width / 2 }
          }
          Item {
            anchors.fill: parent
            rotation: root.now.getSeconds() * 6
            Behavior on rotation { RotationAnimation { duration: 220; direction: RotationAnimation.Clockwise; easing.type: Easing.OutBack } }
            Rectangle { width: Math.max(1.5, dial.width * 0.006); height: dial.width * 0.5; color: root.night ? "#ff3b30" : "#ff9500"; x: parent.width / 2 - width / 2; y: parent.height / 2 - dial.width * 0.4 }
          }
          Rectangle { anchors.centerIn: parent; width: dial.width * 0.035; height: width; radius: width / 2; color: root.night ? "#ff3b30" : "#ff9500" }
        }
      }

      // ------------------------------------------------------------- widget
      Rectangle {
        id: panelCard
        x: stage.half + stage.spacing
        width: stage.half; height: stage.height
        radius: Math.round(height * 0.09)
        color: root.night ? "#120302" : "#1c1c1e"
        clip: true

        // Changement de panneau : glisse verticalement comme la pile StandBy.
        property string shownPanel: root.panel
        onShownPanelChanged: swap.restart()
        property real slide: 0
        SequentialAnimation {
          id: swap
          NumberAnimation { target: panelCard; property: "slide"; from: 0.35; to: 0; duration: 520; easing.type: Easing.OutBack; easing.overshoot: 1.4 }
        }

        Item {
          anchors.fill: parent
          anchors.margins: Math.round(panelCard.height * 0.08)
          transform: Translate { y: panelCard.slide * panelCard.height }
          opacity: 1 - panelCard.slide * 2

          // Calendrier
          Item {
            id: cal
            anchors.fill: parent
            visible: panelCard.shownPanel === "calendar"
            readonly property int year: root.now.getFullYear()
            readonly property int month: root.now.getMonth()
            readonly property int offset: (new Date(year, month, 1).getDay() + 6) % 7
            readonly property int days: new Date(year, month + 1, 0).getDate()
            readonly property int rows: Math.ceil((offset + days) / 7)
            Text {
              id: calTitle
              textFormat: Text.PlainText
              text: Qt.locale("fr_FR").toString(root.now, "MMMM").toUpperCase()
              font.family: root.uiFont; font.pixelSize: Math.round(cal.height * 0.075); font.weight: Font.Bold
              color: root.night ? root.ink : "#ff453a"
            }
            Grid {
              id: calGrid
              anchors.top: calTitle.bottom; anchors.topMargin: cal.height * 0.04
              width: parent.width
              columns: 7
              readonly property real cw: width / 7
              readonly property real ch: (cal.height - calTitle.height - cal.height * 0.04) / (cal.rows + 1)
              Repeater {
                model: ["L", "M", "M", "J", "V", "S", "D"]
                Text { required property string modelData; width: calGrid.cw; height: calGrid.ch; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter; text: modelData; font.family: root.uiFont; font.pixelSize: Math.round(calGrid.ch * 0.4); font.weight: Font.Bold; color: root.inkDim }
              }
              Repeater {
                model: cal.rows * 7
                Item {
                  required property int index
                  readonly property int day: index - cal.offset + 1
                  readonly property bool valid: day >= 1 && day <= cal.days
                  readonly property bool today: day === root.now.getDate()
                  width: calGrid.cw; height: calGrid.ch
                  Rectangle { visible: parent.valid && parent.today; anchors.centerIn: parent; width: Math.min(parent.width, parent.height) * 0.9; height: width; radius: width / 2; color: root.night ? "#ff3b30" : "#ff453a" }
                  Text { visible: parent.valid; anchors.centerIn: parent; text: parent.day; font.family: root.uiFont; font.pixelSize: Math.round(calGrid.ch * 0.46); font.weight: parent.today ? Font.Bold : Font.Medium; color: parent.today ? (root.night ? "black" : "white") : ((index % 7) >= 5 ? root.inkDim : root.ink) }
                }
              }
            }
          }

          // Lecture en cours
          Item {
            id: music
            anchors.fill: parent
            visible: panelCard.shownPanel === "music"
            Image {
              id: art
              width: Math.min(parent.width, parent.height * 0.62); height: width
              anchors.horizontalCenter: parent.horizontalCenter
              source: root.np.cover ? "file://" + root.np.cover : ""
              sourceSize: Qt.size(640, 640)
              fillMode: Image.PreserveAspectCrop
              asynchronous: true
              opacity: root.night ? 0.55 : 1
              Rectangle { anchors.fill: parent; color: "transparent"; radius: width * 0.06; border.width: 1; border.color: Qt.rgba(1, 1, 1, 0.08) }
            }
            Column {
              anchors.top: art.bottom; anchors.topMargin: music.height * 0.04
              width: parent.width
              spacing: 2
              Text { width: parent.width; horizontalAlignment: Text.AlignHCenter; elide: Text.ElideRight; textFormat: Text.PlainText; text: root.player ? (root.player.trackTitle || root.np.title || "") : ""; font.family: root.uiFont; font.pixelSize: Math.round(music.height * 0.065); font.weight: Font.Bold; color: root.ink }
              Text { width: parent.width; horizontalAlignment: Text.AlignHCenter; elide: Text.ElideRight; textFormat: Text.PlainText; text: root.player ? (root.player.trackArtist || root.np.artist || "") : ""; font.family: root.uiFont; font.pixelSize: Math.round(music.height * 0.05); color: root.inkDim }
            }
            Row {
              anchors.bottom: parent.bottom
              anchors.horizontalCenter: parent.horizontalCenter
              spacing: music.width * 0.12
              Repeater {
                model: [[0xF04AE, "prev"], [-1, "toggle"], [0xF04AD, "next"]]
                Text {
                  id: ctl
                  required property var modelData
                  textFormat: Text.PlainText
                  text: modelData[0] < 0 ? String.fromCodePoint(root.player && root.player.isPlaying ? 0xF03E4 : 0xF040A) : String.fromCodePoint(modelData[0])
                  font.family: Style.font.family; font.pixelSize: Math.round(music.height * 0.1)
                  color: root.ink
                  scale: ctlMouse.pressed ? 0.8 : 1
                  Behavior on scale { NumberAnimation { duration: 260; easing.type: Easing.OutBack; easing.overshoot: 3 } }
                  MouseArea {
                    id: ctlMouse
                    anchors.fill: parent; anchors.margins: -12
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                      if (!root.player) return
                      if (ctl.modelData[1] === "prev") root.player.previous()
                      else if (ctl.modelData[1] === "next") root.player.next()
                      else root.player.togglePlaying()
                    }
                  }
                }
              }
            }
          }

          // Batterie
          Item {
            id: batt
            anchors.fill: parent
            visible: panelCard.shownPanel === "battery"
            readonly property var dev: UPower.displayDevice
            readonly property real frac: dev && dev.isPresent ? Math.max(0, Math.min(1, dev.percentage)) : 0
            readonly property bool charging: !!dev && dev.isPresent && !UPower.onBattery
            readonly property color ring: root.night ? "#ff3b30" : (frac <= 0.2 && !charging ? "#ff3b30" : "#30d158")
            Item {
              id: ringBox
              width: Math.min(parent.width, parent.height) * 0.72; height: width
              anchors.centerIn: parent
              anchors.verticalCenterOffset: -parent.height * 0.06
              Shape {
                anchors.fill: parent
                preferredRendererType: Shape.CurveRenderer
                ShapePath {
                  strokeColor: Qt.rgba(batt.ring.r, batt.ring.g, batt.ring.b, 0.2); strokeWidth: ringBox.width * 0.08; fillColor: "transparent"; capStyle: ShapePath.RoundCap
                  PathAngleArc { centerX: ringBox.width / 2; centerY: ringBox.height / 2; radiusX: ringBox.width * 0.46; radiusY: radiusX; startAngle: -90; sweepAngle: 360 }
                }
                ShapePath {
                  strokeColor: batt.ring; strokeWidth: ringBox.width * 0.08; fillColor: "transparent"; capStyle: ShapePath.RoundCap
                  PathAngleArc { centerX: ringBox.width / 2; centerY: ringBox.height / 2; radiusX: ringBox.width * 0.46; radiusY: radiusX; startAngle: -90; sweepAngle: 360 * batt.frac }
                }
              }
              Text {
                anchors.centerIn: parent
                textFormat: Text.PlainText
                text: Math.round(batt.frac * 100) + " %"
                font.family: root.uiFont; font.pixelSize: Math.round(ringBox.width * 0.2); font.weight: Font.Bold
                color: root.ink
              }
            }
            Text {
              anchors.horizontalCenter: parent.horizontalCenter
              anchors.bottom: parent.bottom
              textFormat: Text.PlainText
              text: batt.charging ? (batt.frac >= 0.99 ? "Chargé" : "En charge") : "Sur batterie"
              font.family: root.uiFont; font.pixelSize: Math.round(parent.height * 0.065); font.weight: Font.DemiBold
              color: root.inkDim
            }
          }
        }

        // Points de la pile (comme StandBy) à droite du panneau.
        Column {
          anchors.right: parent.right; anchors.rightMargin: Math.round(panelCard.height * 0.03)
          anchors.verticalCenter: parent.verticalCenter
          spacing: 6
          Repeater {
            model: root.panels.length
            Rectangle {
              required property int index
              width: 6; height: root.panels[index] === root.panel ? 16 : 6; radius: 3
              color: root.panels[index] === root.panel ? root.ink : root.inkDim
              Behavior on height { NumberAnimation { duration: 260; easing.type: Easing.OutBack } }
            }
          }
        }
      }
    }
  }
}
