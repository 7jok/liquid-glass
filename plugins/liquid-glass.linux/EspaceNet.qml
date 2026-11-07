import QtQuick

// Réseau en système solaire : le réseau connecté est l'astre, les autres tournent
// autour, d'autant plus près que le signal est fort. Un clic s'y connecte.
EspacePanel {
  id: p
  cardW: 620; cardH: 520
  readonly property var others: {
    var out = [], l = s.wifiList
    for (var i = 0; i < l.length && out.length < 10; i++) if (!l[i].active) out.push(l[i])
    return out
  }
  readonly property var current: {
    var l = s.wifiList
    for (var i = 0; i < l.length; i++) if (l[i].active) return l[i]
    return null
  }
  Component.onCompleted: s.scanWifi()

  Text { x: 22; y: 18; text: "Réseau"; font.family: p.font; font.pixelSize: 15; font.weight: Font.Bold; color: p.ink }
  Text {
    x: 22; y: 39
    text: p.s.wifiBusy ? "Recherche…" : p.others.length + (p.others.length > 1 ? " réseaux autour de toi" : " réseau autour de toi")
    font.family: p.font; font.pixelSize: 11; color: p.sub
  }
  Rectangle {
    anchors.right: parent.right; anchors.rightMargin: 20; y: 18
    width: 92; height: 30; radius: 9
    color: p.s.wifiOn ? p.s.primary : p.s.alpha(p.ink, 0.1)
    Text {
      anchors.centerIn: parent; text: p.s.wifiOn ? "Wi-Fi activé" : "Wi-Fi coupé"
      font.family: p.font; font.pixelSize: 11; font.weight: Font.Bold
      color: p.s.wifiOn ? p.s.colOnPrimary : p.ink
    }
    MouseArea { anchors.fill: parent; onClicked: p.s.setWifi(!p.s.wifiOn) }
  }

  Item {
    id: sky
    x: 20; y: 66; width: parent.width - 40; height: parent.height - 84
    readonly property real cx: width / 2
    readonly property real cy: height / 2
    readonly property real maxR: Math.min(width, height) / 2 - 34

    Repeater {
      model: [0.45, 0.72, 1]
      delegate: Rectangle {
        required property real modelData
        x: sky.cx - width / 2; y: sky.cy - height / 2
        width: sky.maxR * 2 * modelData; height: width; radius: width / 2
        color: "transparent"; border.width: 1; border.color: p.s.alpha(p.ink, 0.12)
      }
    }
    Repeater {
      model: p.others
      delegate: Item {
        id: node
        required property var modelData
        required property int index
        readonly property real a: -Math.PI / 2 + index * 2 * Math.PI / Math.max(1, p.others.length)
        readonly property real d: sky.maxR * (modelData.signal >= 66 ? 0.45 : (modelData.signal >= 33 ? 0.72 : 1))
        x: sky.cx + d * Math.cos(a) - width / 2
        y: sky.cy + d * Math.sin(a) - height / 2
        width: 84; height: 46
        Rectangle {
          anchors.horizontalCenter: parent.horizontalCenter
          width: 22; height: 22; radius: 11
          color: nma.containsMouse ? p.s.primary : p.s.surfaceHigh
          border.width: 1; border.color: p.s.alpha(p.s.primary, 0.7)
          MIcon {
            anchors.centerIn: parent; size: 12
            icon: node.modelData.secure ? "lock" : "wifi"
            color: nma.containsMouse ? p.s.colOnPrimary : p.ink
          }
        }
        Text {
          y: 25; width: parent.width; horizontalAlignment: Text.AlignHCenter; elide: Text.ElideRight
          text: node.modelData.ssid
          font.family: p.font; font.pixelSize: 10; color: nma.containsMouse ? p.ink : p.sub
        }
        MouseArea { id: nma; anchors.fill: parent; hoverEnabled: true; onClicked: p.s.connectWifi(node.modelData.ssid) }
      }
    }
    // L'astre : le réseau connecté.
    Rectangle {
      x: sky.cx - width / 2; y: sky.cy - height / 2
      width: 92; height: 92; radius: 46
      color: p.s.primary
      Column {
        anchors.centerIn: parent; spacing: 1
        MIcon { anchors.horizontalCenter: parent.horizontalCenter; icon: p.s.netDev === "" ? "wifi_off" : (p.s.netWifi ? "wifi" : "lan"); size: 22; color: p.s.colOnPrimary }
        Text {
          anchors.horizontalCenter: parent.horizontalCenter
          width: 78; horizontalAlignment: Text.AlignHCenter; elide: Text.ElideRight
          text: p.current ? p.current.ssid : (p.s.netDev === "" ? "Hors ligne" : (p.s.netWifi ? "Wi-Fi" : "Ethernet"))
          font.family: p.font; font.pixelSize: 11; font.weight: Font.Bold; color: p.s.colOnPrimary
        }
        Text {
          visible: !!p.current
          anchors.horizontalCenter: parent.horizontalCenter
          text: p.current ? p.current.signal + " %" : ""
          font.family: p.font; font.pixelSize: 9; color: p.s.colOnPrimary
        }
      }
    }
  }
}
