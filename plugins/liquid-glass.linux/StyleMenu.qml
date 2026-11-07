import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Widgets
import Quickshell.Bluetooth
import Quickshell.Services.Pipewire

// Centre de réglages (⌘⌥Espace, bouton d'alimentation de la barre) de chaque
// bureau Linux, à la place du menu « Go… » d'Omarchy :
//   compte et style · interrupteurs (Wi-Fi, Bluetooth, nuit, ne pas déranger, muet)
//   · volume et luminosité · teinte du style (nuit / aube / rose, pur / crème…)
//   · raccourcis (capture, vidéo, fonds, pipette, terminal, fichiers, mises à
//   jour, réglages avancés, bureaux) · verrouiller / veille / redémarrer / éteindre.
// Habillé comme le style : fiche blanche, terminal, bonbon, Material, mono, forêt.
PanelWindow {
  id: win
  property var service: null
  readonly property var s: service

  color: "transparent"
  anchors { top: true; bottom: true; left: true; right: true }
  exclusionMode: ExclusionMode.Ignore
  WlrLayershell.layer: WlrLayer.Overlay
  WlrLayershell.namespace: "liquid-glass-linux-menu"
  WlrLayershell.keyboardFocus: s.kbd(false)

  readonly property string st: s.style
  readonly property bool toy: st === "jouet"
  readonly property bool term: st === "sombre"
  readonly property bool monoStyle: st === "mono"
  readonly property string font: st === "foret" || st === "blanc" || st === "sombre" ? "JetBrainsMono Nerd Font" : s.sansFont
  readonly property color panelBg: monoStyle ? s.monoFrame : (toy ? s.surfaceMid : s.alpha(s.surfaceMid, 0.97))
  readonly property color ink: monoStyle ? s.colOnSurface : s.colOnSurface
  readonly property color sub: monoStyle ? s.colOnSurfaceVariant : s.colOnSurfaceVariant
  readonly property color acc: monoStyle ? s.primary : s.primary
  readonly property color accInk: s.colOnPrimary
  readonly property color tile: monoStyle ? s.surfaceMid : (toy ? "#ffffff" : s.alpha(s.colOnSurface, s.darkSkin ? 0.06 : 0.045))
  readonly property int radius: monoStyle ? 22 : (toy ? 20 : (st === "blanc" ? 10 : (term ? 4 : 24)))
  readonly property int tr: monoStyle ? 16 : (toy ? 14 : (st === "blanc" ? 6 : (term ? 2 : 18)))
  readonly property string styleName: ({ espace: "Espace", gouts: "Mes goûts", ruban: "Rubans", blanc: "Blanc", sombre: "Sombre", jouet: "Jouet", violet: "Violet", expressive: "Expressive", mono: "Mono", foret: "Forêt", windows: "Windows" })[st] || st

  // Teintes proposées pour le style courant : [clé de config, [valeur, nom, couleur]…]
  readonly property var tones: s.toneDefs[st] || null
  readonly property string curTone: tones && tones[1].length ? String(s.opt(tones[0], tones[1][0][0])) : ""

  PwObjectTracker { objects: [Pipewire.defaultAudioSink] }
  readonly property var sink: Pipewire.defaultAudioSink
  readonly property var bt: Bluetooth.defaultAdapter
  property bool nightOn: false
  property bool dndOn: false
  Process {
    running: true
    command: ["sh", "-c", "pgrep -x hyprsunset >/dev/null && echo n; makoctl mode 2>/dev/null | grep -q do-not-disturb && echo d; true"]
    stdout: StdioCollector { onStreamFinished: { win.nightOn = text.indexOf("n") >= 0; win.dndOn = text.indexOf("d") >= 0 } }
  }

  property bool revealed: false
  Component.onCompleted: { revealed = true; keys.forceActiveFocus(); s.readBrightness() }
  MouseArea { anchors.fill: parent; onClicked: s.closeAll() }
  Item { id: keys; focus: true; Keys.onEscapePressed: s.closeAll() }
  function act(cmd) { s.closeAll(); Quickshell.execDetached(["sh", "-c", "sleep 0.25; " + cmd]) }

  Item {
    id: box
    width: 380
    // Blanc et Jouet n'ont pas de barre en haut : le volet monte, et s'arrête au-dessus du dock.
    readonly property int topGap: s.testing ? (s.toyDock || s.textBar ? 40 : 80) : (s.toyDock || s.textBar ? 10 : 46)
    readonly property int bottomGap: s.toyDock ? 96 : (s.textBar ? 36 : 10)
    height: Math.min(col.implicitHeight + 36, win.height - (monoStyle ? 16 : topGap + bottomGap))
    // Mono : sort de la barre de gauche ; sinon tombe sous la barre, à droite.
    x: monoStyle ? 44 - 1 - (win.revealed ? 0 : width) : win.width - width - 10
    y: monoStyle ? win.height - height - 8 : topGap + (win.revealed ? 0 : -14)
    opacity: monoStyle || win.revealed ? 1 : 0
    Behavior on x { NumberAnimation { duration: 320; easing.type: Easing.OutCubic } }
    Behavior on y { NumberAnimation { duration: 340; easing.type: Easing.OutBack } }
    Behavior on opacity { NumberAnimation { duration: 160 } }

    Rectangle { visible: toy || st === "blanc"; x: 7; y: 7; width: parent.width; height: parent.height; radius: win.radius; color: toy ? "#1b1030" : s.colOnSurface }
    RectangularShadow { visible: !toy && !monoStyle && st !== "blanc"; anchors.fill: body; radius: win.radius; blur: 30; offset.y: 10; color: Qt.rgba(0, 0, 0, s.darkSkin ? 0.5 : 0.16) }
    Rectangle {
      id: body
      anchors.fill: parent
      radius: win.radius
      color: win.panelBg
      border.width: toy ? 3 : (st === "blanc" || term ? 1 : 0)
      border.color: toy ? "#1b1030" : s.alpha(win.ink, st === "blanc" ? 0.9 : 0.35)
      Rectangle { visible: monoStyle; width: win.radius; height: parent.height; color: win.panelBg }
      MouseArea { anchors.fill: parent }
    }

    // Contenu défilant : sur un écran de 720 px logiques le menu complet ne tient pas.
    Flickable {
      id: fl
      anchors.fill: parent
      contentHeight: col.implicitHeight + 36
      clip: true
      boundsBehavior: Flickable.StopAtBounds
      interactive: contentHeight > height
      Column {
        id: col
        x: 18; y: 18
        width: parent.width - 36
        spacing: 14

        // ---- compte + style
        Item {
          width: parent.width; height: 44
          ClippingRectangle {
            width: 44; height: 44; radius: toy ? 12 : 22; color: s.alpha(win.acc, 0.2)
            border.width: toy ? 2.5 : 0; border.color: "#1b1030"
            Text { anchors.centerIn: parent; text: s.user.charAt(0).toUpperCase(); font.family: win.font; font.pixelSize: 18; font.weight: Font.Bold; color: win.ink }
            Image { anchors.fill: parent; source: "file://" + Quickshell.env("HOME") + "/.face"; fillMode: Image.PreserveAspectCrop; asynchronous: true; visible: status === Image.Ready }
          }
          Column {
            x: 56; anchors.verticalCenter: parent.verticalCenter
            Text { text: term ? s.user + "@" + (s.info.host || "linux") : s.user.charAt(0).toUpperCase() + s.user.slice(1); font.family: win.font; font.pixelSize: 15; font.weight: Font.Bold; color: win.ink }
            Text { text: "Bureau " + win.styleName.charAt(0).toUpperCase() + win.styleName.slice(1) + " · up " + s.uptimeText; font.family: win.font; font.pixelSize: 11; color: win.sub }
          }
          Btn {
            anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
            icon: "dashboard_customize"; label: "Bureaux"
            onClicked: win.act("liquid-glass profile pick")
          }
        }

        // ---- interrupteurs
        Grid {
          columns: 5; spacing: 8
          width: parent.width
          Toggle { icon: s.wifiOn ? "wifi" : "wifi_off"; label: "Wi-Fi"; on: s.wifiOn; onClicked: s.setWifi(!s.wifiOn) }
          Toggle { icon: "bluetooth"; label: "Bluetooth"; on: !!win.bt && win.bt.enabled; onClicked: if (win.bt) win.bt.enabled = !win.bt.enabled }
          Toggle { icon: "nightlight"; label: "Nuit"; on: win.nightOn; onClicked: { win.nightOn = !win.nightOn; Quickshell.execDetached(["omarchy-toggle-nightlight"]) } }
          Toggle { icon: "do_not_disturb_on"; label: "Silence"; on: win.dndOn; onClicked: { win.dndOn = !win.dndOn; Quickshell.execDetached(["omarchy-toggle-notification-silencing"]) } }
          Toggle { icon: win.sink && win.sink.audio && win.sink.audio.muted ? "volume_off" : "volume_up"; label: "Son"; on: !!win.sink && !!win.sink.audio && !win.sink.audio.muted
                   onClicked: if (win.sink && win.sink.audio) win.sink.audio.muted = !win.sink.audio.muted }
        }

        // ---- curseurs
        Slider { icon: "volume_up"; value: win.sink && win.sink.audio ? win.sink.audio.volume : 0; onMoved: function(v) { if (win.sink && win.sink.audio) win.sink.audio.volume = v } }
        Slider { visible: s.brightness >= 0; icon: "light_mode"; value: Math.max(0, s.brightness); onMoved: function(v) { s.setBrightness(v) } }

        // ---- teinte du style
        Column {
          visible: !!win.tones
          width: parent.width; spacing: 8
          Text { text: term ? "# teinte" : "Teinte du bureau"; font.family: win.font; font.pixelSize: 12; font.weight: Font.Bold; color: win.sub }
          Flow {
            width: parent.width
            spacing: 8
            Repeater {
              model: win.tones ? win.tones[1] : []
              delegate: Rectangle {
                required property var modelData
                readonly property bool cur: win.curTone === modelData[0]
                width: toneRow.implicitWidth + 20; height: 32; radius: win.tr
                color: cur ? s.alpha(win.acc, 0.2) : win.tile
                border.width: cur ? (toy ? 2.5 : 1.5) : (toy ? 2 : 0)
                border.color: toy ? "#1b1030" : win.acc
                Row {
                  id: toneRow
                  anchors.centerIn: parent; spacing: 7
                  Rectangle { anchors.verticalCenter: parent.verticalCenter; width: 14; height: 14; radius: 7; color: modelData[2]; border.width: 1; border.color: s.alpha(win.ink, 0.3) }
                  Text { anchors.verticalCenter: parent.verticalCenter; text: modelData[1]; font.family: win.font; font.pixelSize: 12; color: win.ink }
                }
                MouseArea {
                  anchors.fill: parent
                  // Par la CLI : teinte + thème Omarchy (terminaux, bordures) d'un coup.
                  onClicked: Quickshell.execDetached(["liquid-glass", "profile", win.st + ":" + modelData[0]])
                }
              }
            }
          }
        }

        // ---- couleurs : thème du style, tirées du fond d'écran, ou accent perso
        Column {
          visible: !monoStyle
          width: parent.width; spacing: 8
          Text { text: term ? "# couleurs" : "Couleurs"; font.family: win.font; font.pixelSize: 12; font.weight: Font.Bold; color: win.sub }
          Row {
            spacing: 6
            Repeater {
              model: [["theme", "palette", "Du style"], ["fond", "wallpaper", "Du fond"], ["perso", "colorize", "Perso"]]
              delegate: Rectangle {
                required property var modelData
                readonly property bool cur: s.colorMode === modelData[0]
                width: cmRow.implicitWidth + 20; height: 32; radius: win.tr
                color: cur ? s.alpha(win.acc, 0.2) : win.tile
                border.width: cur ? (toy ? 2.5 : 1.5) : (toy ? 2 : 0)
                border.color: toy ? "#1b1030" : win.acc
                Row {
                  id: cmRow
                  anchors.centerIn: parent; spacing: 6
                  MIcon { anchors.verticalCenter: parent.verticalCenter; icon: modelData[1]; size: 15; fill: cur ? 1 : 0; color: win.ink }
                  Text { anchors.verticalCenter: parent.verticalCenter; text: modelData[2]; font.family: win.font; font.pixelSize: 12; color: win.ink }
                }
                MouseArea {
                  anchors.fill: parent
                  onClicked: {
                    s.setOpt(win.st + "_colors", modelData[0])
                    if (modelData[0] === "perso" && s.accentHex === "") s.setOpt(win.st + "_accent", s.accentSwatches[7])
                  }
                }
              }
            }
          }
          // Nuancier (mode perso) : un clic choisit l'accent.
          Flow {
            visible: s.colorMode === "perso"
            width: parent.width; spacing: 6
            Repeater {
              model: s.accentSwatches
              delegate: Rectangle {
                required property string modelData
                readonly property bool cur: s.accentHex.toLowerCase() === modelData
                width: 24; height: 24; radius: toy ? 7 : 12
                color: modelData
                border.width: cur ? 3 : (toy ? 2 : 1)
                border.color: cur ? win.ink : (toy ? "#1b1030" : s.alpha(win.ink, 0.25))
                scale: swm.containsMouse ? 1.15 : 1
                Behavior on scale { NumberAnimation { duration: 180; easing.type: Easing.OutBack } }
                MouseArea { id: swm; anchors.fill: parent; hoverEnabled: true; onClicked: s.setOpt(win.st + "_accent", modelData) }
              }
            }
          }
          // Teinte libre : glisser sur l'arc-en-ciel.
          Rectangle {
            visible: s.colorMode === "perso"
            width: parent.width; height: 14; radius: 7
            border.width: toy ? 2 : 0; border.color: "#1b1030"
            gradient: Gradient {
              orientation: Gradient.Horizontal
              GradientStop { position: 0.0; color: Qt.hsla(0.0, 0.75, 0.6, 1) }
              GradientStop { position: 0.17; color: Qt.hsla(0.17, 0.75, 0.6, 1) }
              GradientStop { position: 0.33; color: Qt.hsla(0.33, 0.75, 0.6, 1) }
              GradientStop { position: 0.5; color: Qt.hsla(0.5, 0.75, 0.6, 1) }
              GradientStop { position: 0.67; color: Qt.hsla(0.67, 0.75, 0.6, 1) }
              GradientStop { position: 0.83; color: Qt.hsla(0.83, 0.75, 0.6, 1) }
              GradientStop { position: 1.0; color: Qt.hsla(1.0, 0.75, 0.6, 1) }
            }
            Rectangle {
              readonly property real h: s.accentHex !== "" ? Math.max(0, Qt.color(s.accentHex).hslHue) : 0
              x: h * (parent.width - width); anchors.verticalCenter: parent.verticalCenter
              width: 20; height: 20; radius: 10
              color: s.accentHex !== "" ? s.accentHex : "white"
              border.width: 3; border.color: "white"
            }
            MouseArea {
              anchors.fill: parent; anchors.margins: -6
              function pick(x) {
                var c = Qt.hsla(Math.max(0, Math.min(0.999, x / width)), 0.72, s.darkSkin ? 0.66 : 0.48, 1)
                s.setOpt(win.st + "_accent", "#" + [c.r, c.g, c.b].map(function(v) { var h = Math.round(v * 255).toString(16); return h.length < 2 ? "0" + h : h }).join(""))
              }
              onReleased: function(m) { pick(m.x) }
            }
          }
        }

        // ---- raccourcis
        Grid {
          columns: 4; spacing: 8
          width: parent.width
          Repeater {
            model: [
              ["screenshot_region", "Capture", "omarchy-capture-screenshot"],
              ["videocam", "Vidéo", "omarchy-capture-screenrecording"],
              ["wallpaper", "Fonds", "@walls"],
              ["colorize", "Pipette", "hyprpicker -a"],
              ["terminal", "Terminal", "uwsm-app -- xdg-terminal-exec"],
              ["folder", "Fichiers", "uwsm-app -- nautilus --new-window"],
              ["system_update_alt", "Mises à jour", "omarchy-launch-floating-terminal-with-presentation omarchy-update"],
              ["tune", "Réglages", "omarchy-shell shell toggle liquid-glass.settings"]
            ]
            delegate: Rectangle {
              required property var modelData
              width: (col.width - 24) / 4; height: 62; radius: win.tr
              color: ama.containsMouse ? s.alpha(win.acc, 0.16) : win.tile
              border.width: toy ? 2 : (st === "blanc" ? 1 : 0)
              border.color: toy ? "#1b1030" : s.alpha(win.ink, 0.15)
              Column {
                anchors.centerIn: parent; spacing: 4
                MIcon { anchors.horizontalCenter: parent.horizontalCenter; icon: modelData[0]; size: 20; color: win.ink }
                Text { anchors.horizontalCenter: parent.horizontalCenter; text: modelData[1]; font.family: win.font; font.pixelSize: 10; color: win.ink }
              }
              MouseArea {
                id: ama; anchors.fill: parent; hoverEnabled: true
                onClicked: { if (modelData[2] === "@walls") { s.closeAll(); s.wallsOpen = true } else win.act(modelData[2]) }
              }
            }
          }
        }

        // ---- alimentation
        Row {
          spacing: 8
          anchors.horizontalCenter: parent.horizontalCenter
          Repeater {
            model: [["lock", "lock", "Verrouiller"], ["suspend", "bedtime", "Veille"], ["logout", "logout", "Quitter"], ["reboot", "restart_alt", "Redémarrer"], ["poweroff", "power_settings_new", "Éteindre"]]
            delegate: Rectangle {
              required property var modelData
              required property int index
              width: 60; height: 44; radius: win.tr
              color: pma.containsMouse ? (index === 4 ? s.errorColor : s.alpha(win.acc, 0.2)) : (index === 4 ? s.alpha(s.errorColor, 0.16) : win.tile)
              border.width: toy ? 2 : 0; border.color: "#1b1030"
              MIcon { anchors.centerIn: parent; icon: modelData[1]; size: 19; color: pma.containsMouse && index === 4 ? "white" : (index === 4 ? s.errorColor : win.ink) }
              MouseArea { id: pma; anchors.fill: parent; hoverEnabled: true; onClicked: s.power(modelData[0]) }
            }
          }
        }
      }
    }
  }

  // ================================================================ briques
  component Btn: Rectangle {
    id: b
    property string icon: ""
    property string label: ""
    signal clicked()
    width: bRow.implicitWidth + 20; height: 32; radius: win.tr
    color: bma.containsMouse ? s.alpha(win.acc, 0.25) : win.tile
    border.width: win.toy ? 2 : 0; border.color: "#1b1030"
    Row { id: bRow; anchors.centerIn: parent; spacing: 6
      MIcon { anchors.verticalCenter: parent.verticalCenter; icon: b.icon; size: 16; color: win.ink }
      Text { anchors.verticalCenter: parent.verticalCenter; text: b.label; font.family: win.font; font.pixelSize: 12; color: win.ink } }
    MouseArea { id: bma; anchors.fill: parent; hoverEnabled: true; onClicked: b.clicked() }
  }
  component Toggle: Column {
    id: t
    property string icon: ""
    property string label: ""
    property bool on: false
    signal clicked()
    spacing: 4
    width: (col.width - 32) / 5
    Rectangle {
      width: parent.width; height: 48; radius: win.tr
      color: t.on ? win.acc : win.tile
      border.width: win.toy ? 2.5 : (win.st === "blanc" ? 1 : 0)
      border.color: win.toy ? "#1b1030" : s.alpha(win.ink, 0.2)
      Behavior on color { ColorAnimation { duration: 140 } }
      MIcon { anchors.centerIn: parent; icon: t.icon; size: 20; fill: t.on ? 1 : 0; color: t.on ? win.accInk : win.ink }
      MouseArea { anchors.fill: parent; onClicked: t.clicked() }
    }
    Text { width: parent.width; horizontalAlignment: Text.AlignHCenter; elide: Text.ElideRight; text: t.label; font.family: win.font; font.pixelSize: 10; color: win.sub }
  }
  component Slider: Row {
    id: sl
    property string icon: ""
    property real value: 0
    signal moved(real v)
    spacing: 12
    MIcon { anchors.verticalCenter: parent.verticalCenter; icon: sl.icon; size: 18; color: win.ink }
    Item {
      width: col.width - 30; height: 22
      anchors.verticalCenter: parent.verticalCenter
      Rectangle { anchors.verticalCenter: parent.verticalCenter; width: parent.width; height: win.term ? 6 : 10; radius: win.term ? 0 : 5; color: win.tile
        border.width: win.toy ? 2 : 0; border.color: "#1b1030" }
      Rectangle { anchors.verticalCenter: parent.verticalCenter; width: Math.max(10, parent.width * Math.max(0, Math.min(1, sl.value))); height: win.term ? 6 : 10; radius: win.term ? 0 : 5; color: win.acc }
      MouseArea {
        anchors.fill: parent
        onPressed: function(m) { sl.moved(Math.max(0, Math.min(1, m.x / width))) }
        onPositionChanged: function(m) { if (pressed) sl.moved(Math.max(0, Math.min(1, m.x / width))) }
      }
    }
  }
}
