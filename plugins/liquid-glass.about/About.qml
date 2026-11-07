import QtQuick
import "Mac.js" as Mac
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.Commons
import qs.Commons as Commons
import qs.Ui
import "T.js" as T

// Liquid Glass — « À propos de ce Mac » (menu Pomme), façon macOS Tahoe :
// petite fenêtre de verre, portable dessiné avec le fond d'écran actuel,
// nom du modèle, puce, mémoire, stockage, version et « Plus d'infos… ».
// Données : info.sh (lecture de /proc, /sys, df, hyprctl ; rien n'est exécuté).
Item {
  id: root

  property var shell: null
  property var manifest: null
  property bool opened: false
  property var info: ({})

  readonly property string uiFont: "Inter"
  readonly property bool dark: Commons.Color.menu.background.hslLightness < 0.5
  readonly property color fg: Commons.Color.menu.text
  readonly property string wallpaper: "file://" + Quickshell.env("HOME") + "/.local/state/omarchy/current/background"

  function open(payloadJson) { opened = true; if (!infoProc.running) infoProc.running = true; wallImg.reload() }
  function close() { opened = false }
  function dismiss() {
    opened = false
    if (shell && typeof shell.hide === "function") shell.hide((manifest && manifest.id) || "liquid-glass.about")
  }

  function bytes(n) {
    var v = Number(n) || 0
    if (v >= 1e12) return (v / 1e12).toLocaleString(Qt.locale(T.loc), "f", 2) + " To"
    return Math.round(v / 1e9) + " Go"
  }

  ShellIpc {
    target: "liquid-glass.about"
    function toggle(): void { if (root.opened) root.dismiss(); else if (root.shell) root.shell.summon((root.manifest && root.manifest.id) || "liquid-glass.about", "") }
  }

  Process {
    id: infoProc
    // Lancé au chargement puis à chaque ouverture ; jamais interrompu par la
    // fermeture (les infos restent en cache d'une ouverture à l'autre).
    Component.onCompleted: running = true
    command: ["bash", Qt.resolvedUrl("info.sh").toString().replace(/^file:\/\//, "")]
    stdout: StdioCollector {
      onStreamFinished: {
        var out = ({})
        var lines = text.split("\n")
        for (var i = 0; i < lines.length && i < 40; i++) {
          var k = lines[i].indexOf("=")
          if (k > 0) out[lines[i].slice(0, k)] = lines[i].slice(k + 1, k + 1 + 160)
        }
        root.info = out
      }
    }
  }

  OverlayWindow {
    id: win
    shown: root.opened
    WlrLayershell.namespace: "liquid-glass-about"

    Item {
      id: keys
      anchors.fill: parent
      focus: true
      Keys.onPressed: function(ev) {
        if (ev.key === Qt.Key_Escape || (ev.key === Qt.Key_W && (ev.modifiers & Qt.MetaModifier))) { root.dismiss(); ev.accepted = true }
      }
    }
    // Pas de voile (macOS n'en met pas) : clic à côté = fermer.
    MouseArea { anchors.fill: parent; onClicked: root.dismiss() }

    Rectangle {
      id: card
      anchors.centerIn: parent
      width: Style.space(290)
      height: body.implicitHeight + Style.space(40)
      radius: Style.space(Mac.window.radius + 6)
      color: Qt.rgba(Commons.Color.menu.background.r, Commons.Color.menu.background.g, Commons.Color.menu.background.b, root.dark ? 0.78 : 0.74)
      border.width: 1
      border.color: Qt.rgba(1, 1, 1, root.dark ? 0.14 : 0.6)
      scale: win.contentRevealed ? 1 : 0.9
      opacity: win.contentRevealed ? 1 : 0
      Behavior on scale { SpringAnimation { spring: Mac.motion.springLG.spring; damping: Mac.motion.springLG.damping; epsilon: 0.002 } }
      Behavior on opacity { NumberAnimation { duration: Style.duration(160) } }
      MouseArea { anchors.fill: parent }

      // Feux tricolores (seul le rouge agit, comme sur une fenêtre non redimensionnable).
      Row {
        id: lights
        x: Style.space(Mac.window.lightInset + 4); y: Style.space(Mac.window.lightInset + 4)
        spacing: Style.space(Mac.window.lightGap)
        property bool hover: lightsMouse.containsMouse
        Repeater {
          model: [[Mac.window.red, "×"], [Mac.window.inactive, ""], [Mac.window.inactive, ""]]
          delegate: Rectangle {
            required property var modelData
            required property int index
            width: Style.space(Mac.window.light); height: width; radius: width / 2
            color: index === 0 ? modelData[0] : (root.dark ? Mac.window.inactiveDark : Mac.window.inactive)
            border.width: 1; border.color: Qt.rgba(0, 0, 0, 0.12)
            Text {
              anchors.centerIn: parent; anchors.verticalCenterOffset: -1
              visible: lights.hover && index === 0
              textFormat: Text.PlainText; text: "×"
              font.family: root.uiFont; font.pixelSize: Style.space(11); font.weight: Font.Bold
              color: Qt.rgba(0, 0, 0, 0.55)
            }
          }
        }
      }
      MouseArea {
        id: lightsMouse
        x: lights.x; y: lights.y; width: lights.width; height: lights.height
        hoverEnabled: true; cursorShape: Qt.PointingHandCursor
        onClicked: function(m) { if (m.x < Style.space(Mac.window.light + 2)) root.dismiss() }
      }

      Column {
        id: body
        y: Style.space(34)
        width: parent.width
        spacing: 0

        // ---- Portable dessiné : écran avec le fond actuel, base en aluminium.
        Item {
          anchors.horizontalCenter: parent.horizontalCenter
          width: Style.space(168); height: Style.space(112)
          Rectangle {
            id: lid
            anchors.horizontalCenter: parent.horizontalCenter
            width: Style.space(150); height: Style.space(100)
            radius: Style.space(7)
            color: "#1d1d1f"
            border.width: 1; border.color: root.dark ? "#5a5a5e" : "#b8b8bd"
            Item {
              id: screenArea
              anchors.fill: parent; anchors.margins: Style.space(4)
              Image {
                id: wallImg
                anchors.fill: parent
                source: root.wallpaper
                sourceSize: Qt.size(300, 200)
                fillMode: Image.PreserveAspectCrop
                cache: false
                asynchronous: true
                visible: false
                function reload() { source = ""; source = root.wallpaper }
              }
              Rectangle { id: screenMask; anchors.fill: parent; radius: Style.space(3); visible: false; layer.enabled: true }
              MultiEffect { anchors.fill: parent; source: wallImg; maskEnabled: true; maskSource: screenMask }
              // Fausse encoche.
              Rectangle { anchors.horizontalCenter: parent.horizontalCenter; y: -1; width: Style.space(22); height: Style.space(4); radius: 2; color: "#1d1d1f" }
            }
          }
          Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: lid.bottom; anchors.topMargin: -1
            width: Style.space(168); height: Style.space(7)
            radius: Style.space(3)
            gradient: Gradient {
              GradientStop { position: 0; color: root.dark ? "#9a9aa0" : "#d9d9de" }
              GradientStop { position: 1; color: root.dark ? "#5c5c62" : "#a9a9b0" }
            }
            Rectangle { anchors.horizontalCenter: parent.horizontalCenter; width: Style.space(28); height: Style.space(2.5); radius: 1.5; color: Qt.rgba(0, 0, 0, 0.18) }
          }
        }

        Item { width: 1; height: Style.space(16) }

        Text {
          anchors.horizontalCenter: parent.horizontalCenter
          textFormat: Text.PlainText
          text: root.info.name || T.t("Ordinateur")
          font.family: Mac.family(Mac.font.title1); font.pixelSize: Style.space(Mac.font.title1); font.weight: Font.Bold
          font.letterSpacing: Mac.tracking(Mac.font.title1)
          color: root.fg
        }
        Text {
          anchors.horizontalCenter: parent.horizontalCenter
          textFormat: Text.PlainText
          text: (root.info.vendor ? root.info.vendor.charAt(0) + root.info.vendor.slice(1).toLowerCase() + " · " : "") + (root.info.host || "")
          font.family: root.uiFont; font.pixelSize: Style.space(Mac.font.subheadline)
          color: root.fg; opacity: Mac.label.secondary
        }

        Item { width: 1; height: Style.space(18) }

        // ---- Caractéristiques : libellé à droite (gris), valeur à gauche.
        Column {
          anchors.horizontalCenter: parent.horizontalCenter
          spacing: Style.space(5)
          Repeater {
            model: [
              [T.t("Puce"), root.info.cpu || "—"],
              [T.t("Graphisme"), root.info.gpu || "—"],
              [T.t("Mémoire"), root.info.memory || "—"],
              [T.t("Stockage"), root.info.disk_size ? root.bytes(root.info.disk_avail) + T.t(" disponibles sur ") + root.bytes(root.info.disk_size) : "—"],
              [T.t("Écran"), root.info.display || "—"],
              [T.t("Système"), "Omarchy " + (root.info.omarchy || "") + " Tahoe"],
              [T.t("Noyau"), root.info.kernel || "—"]
            ]
            delegate: Row {
              required property var modelData
              spacing: Style.space(8)
              Text {
                width: Style.space(76); horizontalAlignment: Text.AlignRight
                textFormat: Text.PlainText; text: modelData[0]
                font.family: root.uiFont; font.pixelSize: Style.space(Mac.font.subheadline); font.weight: Font.DemiBold
                color: root.fg; opacity: 0.85
              }
              Text {
                width: Style.space(170)
                textFormat: Text.PlainText; text: modelData[1]
                wrapMode: Text.WordWrap; maximumLineCount: 2
                font.family: root.uiFont; font.pixelSize: Style.space(Mac.font.subheadline)
                color: root.fg; opacity: Mac.label.secondary + 0.1
              }
            }
          }
        }

        Item { width: 1; height: Style.space(18) }

        Rectangle {
          id: moreBtn
          anchors.horizontalCenter: parent.horizontalCenter
          width: moreText.implicitWidth + Style.space(Mac.control.padH * 2)
          height: Style.space(Mac.control.regular + 2)
          radius: height / 2
          color: moreMouse.pressed ? Qt.rgba(root.fg.r, root.fg.g, root.fg.b, 0.2) : Qt.rgba(root.fg.r, root.fg.g, root.fg.b, root.dark ? 0.14 : 0.08)
          scale: moreMouse.pressed ? 0.94 : 1
          Behavior on scale { SpringAnimation { spring: 5; damping: 0.3 } }
          Text {
            id: moreText
            anchors.centerIn: parent
            textFormat: Text.PlainText; text: T.t("Plus d'infos…")
            font.family: root.uiFont; font.pixelSize: Style.space(Mac.font.body)
            color: root.fg
          }
          MouseArea {
            id: moreMouse
            anchors.fill: parent; cursorShape: Qt.PointingHandCursor
            onClicked: { root.dismiss(); Util.execArgv(["omarchy-shell", "liquid-glass.settings", "openPage", "about"]) }
          }
        }

        Item { width: 1; height: Style.space(14) }

        Text {
          anchors.horizontalCenter: parent.horizontalCenter
          textFormat: Text.PlainText
          text: T.t("Liquid Glass pour Omarchy · Arch Linux")
          font.family: root.uiFont; font.pixelSize: Style.space(Mac.font.caption1)
          color: root.fg; opacity: Mac.label.tertiary + 0.1
        }
      }
    }
  }

  Connections {
    target: win
    function onContentRevealedChanged() { if (win.contentRevealed) keys.forceActiveFocus() }
  }
}
