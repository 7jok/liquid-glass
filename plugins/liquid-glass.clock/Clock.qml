import QtQuick
import Quickshell
import qs.Commons
import qs.Commons as Commons
import qs.Ui

// Liquid Glass — horloge de la barre au format macOS : « jeu. 5 nov.  20:41 »
// (jours et mois en français). Clic gauche : centre de notifications.
// Réglages shell.json : "format" (défaut "ddd d MMM  HH:mm"), "locale" (défaut "fr_FR").
BarWidget {
  id: root
  moduleName: "liquid-glass.clock"

  readonly property string format: setting("format", "ddd d MMM  HH:mm")
  readonly property var locale: Qt.locale(setting("locale", "fr_FR"))

  SystemClock { id: clock; precision: SystemClock.Minutes }

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
