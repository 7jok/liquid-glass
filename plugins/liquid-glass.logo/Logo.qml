import QtQuick
import "Mac.js" as Mac
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Commons as Commons
import qs.Ui
import "T.js" as T

// Liquid Glass — logo de la barre et menu système façon macOS.
// Logo choisi par [appearance] logo dans config.toml (Réglages → Apparence) :
//   pomme | arch | tux | omarchy  → glyphes de police, teinte de la barre
//   orb | goutte                  → images SVG originales (assets/)
//   custom                        → image de [appearance] logo_path
// Clic : ouvre le menu. Raccourci : omarchy-shell liquid-glass.logo toggle
Panel {
  id: root
  moduleName: "liquid-glass.logo"
  ipcTarget: "liquid-glass.logo"

  // Police de l'interface (Inter si installée ; sinon la sans-serif système).
  readonly property string uiFont: "Inter"
  property int cursor: -1

  // ---- choix du logo (config.json régénéré par `liquid-glass set`)
  property var cfg: ({})
  readonly property string logo: (cfg.appearance && cfg.appearance.logo) || "pomme"
  readonly property string logoPath: (cfg.appearance && cfg.appearance.logo_path) || ""
  // [police, glyphe, taille relative]
  readonly property var glyphs: ({
    "pomme": [Style.font.family, "\uf179", 1.0],
    "arch": [Style.font.family, "\uf303", 0.95],
    "tux": [Style.font.family, "\uf31a", 1.0],
    "omarchy": ["omarchy", "\ue900", 0.85]
  })
  readonly property bool isGlyph: glyphs.hasOwnProperty(logo)
  readonly property string imageSource: logo === "custom" && logoPath !== "" ? "file://" + logoPath
                                      : (logo === "goutte" || logo === "orb") ? Qt.resolvedUrl("assets/" + logo + ".svg")
                                      : ""
  readonly property color tint: root.bar ? root.bar.barForeground : Commons.Color.foreground

  FileView {
    path: Quickshell.env("HOME") + "/.config/liquid-glass/config.json"
    watchChanges: true
    onFileChanged: reload()
    onLoaded: { try { root.cfg = JSON.parse(text()) } catch (e) {} }
  }

  // [libellé, commande, raccourci affiché] — "" = séparateur.
  readonly property string userName: Quickshell.env("USER") || "moi"
  // [libellé, commande, raccourci affiché] — "" = séparateur. Ordre du menu Pomme de macOS.
  readonly property var entries: [
    [T.t("À propos de ce Mac"), "omarchy-shell shell toggle liquid-glass.about", ""],
    "",
    [T.t("Réglages Système…"), "omarchy-shell liquid-glass.settings toggle", ""],
    ["App Store…", "omarchy-launch-floating-terminal-with-presentation omarchy-pkg-install", ""],
    "",
    [T.t("Forcer à quitter…"), "omarchy-shell shell toggle liquid-glass.forcequit", "⌥⌘⎋"],
    "",
    [T.t("Suspendre"), "systemctl suspend", ""],
    [T.t("Redémarrer…"), "omarchy system reboot", ""],
    [T.t("Éteindre…"), "omarchy system shutdown", ""],
    "",
    [T.t("Verrouiller l'écran"), "omarchy-shell lock lock", "⌃⌘Q"],
    [T.t("Fermer la session de « ") + userName + " »…", "omarchy system logout", "⇧⌘Q"]
  ]

  function activate(index) {
    var e = entries[index]
    if (!e || e === "") return
    root.close()
    Util.execDetached(e[1])
  }

  function step(delta) {
    var n = entries.length
    var i = cursor
    for (var k = 0; k < n; k++) {
      i = (i + delta + n) % n
      if (entries[i] !== "") { cursor = i; return }
    }
  }

  onOpenedChanged: if (opened) cursor = -1

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  // Logo dessiné à la main (le BarIconButton d'Omarchy le réduirait à la taille d'un glyphe).
  Item {
    id: button
    anchors.fill: parent
    implicitWidth: Style.space(30)
    implicitHeight: root.bar ? root.bar.barSize : Style.space(28)

    Rectangle {
      anchors.centerIn: parent
      width: Style.space(26)
      height: Style.space(22)
      radius: Style.space(6)
      color: root.bar ? root.bar.barForeground : Commons.Color.foreground
      opacity: root.opened ? 0.14 : (mouse.containsMouse ? 0.08 : 0)
      Behavior on opacity { NumberAnimation { duration: Style.duration(100) } }
    }

    Item {
      id: mark
      anchors.centerIn: parent
      width: Style.space(16); height: Style.space(17)
      scale: mouse.pressed ? 0.9 : 1
      Behavior on scale { NumberAnimation { duration: Style.duration(90); easing.type: Easing.OutCubic } }

      Text {
        visible: root.isGlyph
        anchors.centerIn: parent
        anchors.verticalCenterOffset: root.logo === "pomme" ? -Style.space(1) : 0
        textFormat: Text.PlainText
        text: root.isGlyph ? root.glyphs[root.logo][1] : ""
        font.family: root.isGlyph ? root.glyphs[root.logo][0] : Style.font.family
        font.pixelSize: Style.space(17) * (root.isGlyph ? root.glyphs[root.logo][2] : 1)
        color: root.tint
      }

      Image {
        id: img
        visible: !root.isGlyph && status === Image.Ready
        anchors.centerIn: parent
        source: root.isGlyph ? "" : root.imageSource
        sourceSize: Qt.size(64, 64)
        width: root.logo === "goutte" ? Style.space(14) : Style.space(16)
        height: root.logo === "goutte" ? Style.space(16.5) : Style.space(16)
        fillMode: Image.PreserveAspectFit
        smooth: true
        mipmap: true
      }
    }

    MouseArea {
      id: mouse
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onClicked: root.toggle()
    }
  }

  KeyboardPanel {
    id: panel
    anchorItem: button
    owner: root
    bar: root.bar
    open: root.opened
    padding: Style.spacing.sm
    focusTarget: panel.loadedContent
    contentWidth: Style.space(Mac.menu.minWidth + 70)
    contentHeight: panel.fittedContentHeight(panel.loadedContentHeight)

    content: PanelKeyCatcher {
      anchors.fill: parent
      implicitHeight: list.implicitHeight
      onCloseRequested: root.close()
      onTabRequested: function(d) { root.switchPanel(d) }
      onMoveRequested: function(dx, dy) { if (dy !== 0) root.step(dy) }
      onActivateRequested: root.activate(root.cursor)

      Column {
        id: list
        width: parent.width

        Repeater {
          model: root.entries

          delegate: Item {
            id: row
            required property var modelData
            required property int index
            readonly property bool separator: modelData === ""
            readonly property bool hot: !separator && (mouse.containsMouse || root.cursor === index)
            width: list.width
            height: separator ? Style.space(Mac.menu.separatorMargin * 2 + 1) : Style.space(Mac.menu.row)

            Rectangle {
              visible: row.separator
              anchors.verticalCenter: parent.verticalCenter
              x: Style.space(10)
              width: parent.width - Style.space(20)
              height: 1
              color: Commons.Color.popups.text
              opacity: 0.12
            }

            Rectangle {
              visible: !row.separator
              anchors.fill: parent
              radius: Style.space(Mac.menu.selRadius)
              color: Commons.Color.accent
              opacity: row.hot ? 0.9 : 0
              Behavior on opacity { NumberAnimation { duration: Style.duration(80) } }
            }

            Text {
              visible: !row.separator
              textFormat: Text.PlainText
              anchors.verticalCenter: parent.verticalCenter
              x: Style.space(Mac.menu.padRight - Mac.menu.inset + 6)
              text: row.separator ? "" : row.modelData[0]
              font.family: root.uiFont
              font.pixelSize: Style.font.subtitle
              color: row.hot ? "#ffffff" : Commons.Color.popups.text
            }

            Text {
              visible: !row.separator && row.modelData[2] !== ""
              textFormat: Text.PlainText
              anchors.verticalCenter: parent.verticalCenter
              anchors.right: parent.right
              anchors.rightMargin: Style.space(10)
              text: row.separator ? "" : row.modelData[2]
              font.family: root.uiFont
              font.pixelSize: Style.space(Mac.font.body)
              color: row.hot ? "#ffffff" : Commons.Color.popups.text
              opacity: row.hot ? 0.9 : Mac.label.secondary
            }

            MouseArea {
              id: mouse
              anchors.fill: parent
              enabled: !row.separator
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onEntered: root.cursor = row.index
              onClicked: root.activate(row.index)
            }
          }
        }
      }
    }
  }
}
