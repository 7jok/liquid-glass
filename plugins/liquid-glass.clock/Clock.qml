import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Commons as Commons
import qs.Ui

// Liquid Glass — horloge de la barre au format macOS : « jeu. 5 nov.  20:41 »
// (jours et mois en français). Clic gauche : centre de notifications.
// Réglages shell.json : "format" (défaut "ddd d MMM  HH:mm"), "locale" (défaut "fr_FR").
BarWidget {
  id: root
  moduleName: "liquid-glass.clock"

  // Réglages Système → Barre des menus ([menubar] de config.toml) : 24 h, date, secondes.
  property var cfg: ({})
  FileView {
    path: Quickshell.env("HOME") + "/.config/liquid-glass/config.json"
    watchChanges: true
    printErrors: false
    onFileChanged: reload()
    onLoaded: { try { root.cfg = JSON.parse(text()) } catch (e) {} }
  }
  readonly property var mb: cfg.menubar || ({})
  readonly property bool h24: mb.clock_24h !== false
  readonly property bool showDate: mb.show_date !== false
  readonly property bool showSeconds: mb.show_seconds === true
  readonly property string format: {
    var custom = setting("format", "")
    if (custom !== "") return custom
    var t = (h24 ? "HH:mm" : "h:mm") + (showSeconds ? ":ss" : "") + (h24 ? "" : " AP")
    return showDate ? "ddd d MMM  " + t : t
  }
  readonly property var locale: Qt.locale(setting("locale", "fr_FR"))

  SystemClock { id: clock; precision: root.showSeconds ? SystemClock.Seconds : SystemClock.Minutes }

  visible: !vertical
  implicitWidth: label.implicitWidth + Style.space(16)
  implicitHeight: barSize

  Text {
    id: label
    textFormat: Text.PlainText
    anchors.centerIn: parent
    text: clock.date.toLocaleString(root.locale, root.format)
    color: root.bar ? root.bar.barForeground : Commons.Color.foreground
    font.family: "Inter"
    font.pixelSize: Style.font.subtitle
    font.weight: Font.Medium
    font.features: { "tnum": 1 }
  }

  MouseArea {
    anchors.fill: parent
    acceptedButtons: Qt.LeftButton | Qt.RightButton
    cursorShape: Qt.PointingHandCursor
    onClicked: function(mouse) {
      if (mouse.button === Qt.LeftButton) Util.execArgv(["omarchy-shell", "notifications", "showHistory"])
      else Util.execArgv(["omarchy-shell", "liquid-glass.control", "toggle"])
    }
  }
}
