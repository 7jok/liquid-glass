import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Widgets
import "T.js" as T

// Verrouillage du style Mono, d'après la vidéo de sergioqtz (shell « caelestia ») :
// fond flouté, un grand panneau au centre en trois colonnes.
//   gauche : météo, fiche système (logo, WM, utilisateur, durée, batterie, pastilles),
//            morceau en cours sur sa pochette floutée ;
//   centre : horloge haute et étroite, date, avatar dans un hexagone arrondi,
//            champ « Entrez votre mot de passe », message d'erreur en rouge ;
//   droite : trois jauges en formes (processeur, mémoire, batterie), notifications.
// Teintes : noir (la vidéo), papier (clair), sakura (rose).
Item {
  id: f
  property var lock: null
  readonly property var lk: lock
  readonly property real ww: width
  readonly property real hh: height

  readonly property string tone: f.lk ? f.lk.tone("mono_tone", "noir") : "noir"
  readonly property var pal: ({
    noir:   { bg: "#121212", card: "#1e1e1e", card2: "#262626", ink: "#f2f2f2", sub: "#9a9a9a", dim: "#5e5e5e", acc: "#f2f2f2", accInk: "#111111", err: "#ff6b6b", badge: "#f4a6b8", veil: 0.45 },
    papier: { bg: "#f3f2ef", card: "#e7e5e1", card2: "#dcd9d4", ink: "#151515", sub: "#5f5d59", dim: "#a3a09a", acc: "#151515", accInk: "#f5f5f5", err: "#c0392b", badge: "#151515", veil: -0.05 },
    sakura: { bg: "#fcf0f2", card: "#f8e2e7", card2: "#f2d0d9", ink: "#5a2a38", sub: "#9b6f7c", dim: "#a59a9d", acc: "#7a3d4f", accInk: "#fff3f6", err: "#c8435f", badge: "#e994ab", veil: -0.08, shapes: ["#f2a9bc", "#d9cbe6", "#f6c4cf"] }
  })
  readonly property var p: pal[tone] || pal.noir

  // Boîte du champ, en coordonnées de l'écran : le vrai champ de saisie s'y pose.
  readonly property rect fieldBox: {
    var c = field.mapToItem(f, 0, 0)
    return Qt.rect(c.x, c.y, field.width, field.height)
  }

  LockData { id: data; running: f.visible }

  component Icon: Text {
    property string icon: ""
    property int size: 18
    property real fill: 1
    text: icon
    font.family: "Material Symbols Rounded"
    font.pixelSize: size
    font.variableAxes: ({ "FILL": fill, "wght": 500 })
    color: f.p.ink
  }
  component Card: Rectangle { radius: 18 * f.k; color: f.p.card }

  readonly property real k: Math.min(f.ww / 1280, f.hh / 720)       // échelle : 1 sur un écran de 1280 × 720

  // ---- fond : le même fond d'écran, flou et assombri
  Image {
    id: wall
    anchors.fill: parent
    source: f.lk && f.lk.backgroundPath && !f.lk.video ? "file://" + f.lk.backgroundPath : (f.lk && f.lk.videoPosterPath ? "file://" + f.lk.videoPosterPath : "")
    fillMode: Image.PreserveAspectCrop
    sourceSize: Qt.size(f.ww / 2, f.hh / 2)
    visible: false
  }
  MultiEffect {
    anchors.fill: parent
    source: wall
    blurEnabled: true; blurMax: 64; blur: 1
    brightness: -f.p.veil
    saturation: f.tone === "sakura" ? 0.1 : -0.6
  }

  // ---- le panneau
  Rectangle {
    id: panel
    width: Math.round(Math.min(f.ww * 0.7, 900 * f.k))
    height: Math.round(Math.min(f.hh * 0.72, 500 * f.k))
    anchors.horizontalCenter: parent.horizontalCenter
    y: Math.round(f.hh * 0.15)
    radius: 26 * f.k
    color: Qt.rgba(Qt.color(f.p.bg).r, Qt.color(f.p.bg).g, Qt.color(f.p.bg).b, 0.94)
    border.color: Qt.rgba(1, 1, 1, f.tone === "papier" ? 0 : 0.05)
    // Entrée : le panneau s'ouvre depuis le centre, les colonnes glissent vers leur place.
    property real t: 0
    Component.onCompleted: t = 1
    Behavior on t { NumberAnimation { duration: 650; easing.type: Easing.OutCubic } }
    opacity: t
    scale: 0.94 + 0.06 * t
    readonly property real pad: 10 * f.k
    readonly property real colW: Math.round(width * 0.29)

    // ======== colonne de gauche
    Column {
      id: left
      x: panel.pad - (1 - panel.t) * 30
      y: panel.pad
      width: panel.colW
      spacing: panel.pad
      readonly property real h3: (panel.height - panel.pad * 4) / 3

      Card {
        width: parent.width; height: left.h3 * 0.92
        Column {
          anchors.centerIn: parent
          spacing: 3 * f.k
          Text { anchors.horizontalCenter: parent.horizontalCenter; text: data.weather ? T.t(data.wDesc) : T.t("Météo"); color: f.p.sub; font.family: "Google Sans Flex"; font.pixelSize: 12 * f.k }
          Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 8 * f.k
            Text { text: data.weather ? data.weather.temp + "°C" : "--"; color: f.p.ink; font.family: "Google Sans Flex"; font.pixelSize: 30 * f.k; font.weight: Font.Bold }
            Icon { anchors.verticalCenter: parent.verticalCenter; icon: data.wIcon; size: 30 * f.k; fill: 0 }
          }
          Text { anchors.horizontalCenter: parent.horizontalCenter; text: data.weather ? T.t("Ressenti") + " " + data.weather.feels + "°C" : ""; color: f.p.ink; font.family: "Google Sans Flex"; font.pixelSize: 12 * f.k }
          Text { anchors.horizontalCenter: parent.horizontalCenter; text: data.weather ? T.t("Max") + " " + data.weather.max + "°C • " + T.t("Min") + " " + data.weather.min + "°C" : ""; color: f.p.sub; font.family: "Google Sans Flex"; font.pixelSize: 11 * f.k }
        }
      }
      Card {
        width: parent.width; height: left.h3 * 1.12
        Row {
          x: 12 * f.k; y: 12 * f.k
          spacing: 8 * f.k
          Rectangle {
            width: 22 * f.k; height: width; radius: 7 * f.k; color: f.p.card2
            Text { anchors.centerIn: parent; text: ">"; color: f.p.ink; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 12 * f.k; font.bold: true }
          }
          Text { anchors.verticalCenter: parent.verticalCenter; text: "liquidfetch.sh"; color: f.p.ink; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 11 * f.k }
        }
        Row {
          x: 14 * f.k; y: 44 * f.k
          spacing: 14 * f.k
          Text { anchors.verticalCenter: parent.verticalCenter; text: ""; color: f.p.ink; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 52 * f.k }
          Column {
            spacing: 2 * f.k
            Repeater {
              model: [["WM", "Hyprland"], ["USER", f.lk ? f.lk.userName : ""], ["UP", data.uptime],
                      ["BATT", data.battery < 0 ? "—" : (data.charging ? "(+) " : "") + data.battery + "%"]]
              Text {
                required property var modelData
                width: panel.colW - 100 * f.k; elide: Text.ElideRight
                text: (modelData[0] + "    ").slice(0, 4) + " : " + modelData[1]
                color: f.p.ink; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 10.5 * f.k
              }
            }
          }
        }
        Row {
          anchors.horizontalCenter: parent.horizontalCenter
          anchors.bottom: parent.bottom; anchors.bottomMargin: 12 * f.k
          spacing: 9 * f.k
          Repeater {
            model: f.tone === "sakura" ? [f.p.dim, "#b0285c", "#d9663c", "#c0476a", "#e06a6a", "#d9487a", "#9a6ad0"]
                                       : [f.p.dim, "#9d8cff", "#6ee0c0", "#7fe3c8", "#9aa8a0", "#8a9cff", "#8ed8e0", "#f2b8c6"]
            Rectangle { required property var modelData; width: 13 * f.k; height: width; radius: width / 2; color: modelData }
          }
        }
      }
      ClippingRectangle {
        width: parent.width; height: left.h3 * 0.96
        radius: 18 * f.k; color: f.p.card
        Image {
          id: cover
          anchors.fill: parent
          source: f.lk && f.lk.hasTrack ? f.lk.localCover : ""
          fillMode: Image.PreserveAspectCrop
          sourceSize: Qt.size(160, 160)
          visible: false
        }
        MultiEffect { anchors.fill: parent; source: cover; visible: cover.status === Image.Ready; blurEnabled: true; blurMax: 32; blur: 0.8; brightness: f.tone !== "noir" ? 0.3 : -0.45; saturation: -0.5 }
        Column {
          anchors.centerIn: parent
          width: parent.width - 24 * f.k
          spacing: 2 * f.k
          Text { width: parent.width; horizontalAlignment: Text.AlignHCenter; elide: Text.ElideRight; text: f.lk && f.lk.hasTrack ? f.lk.player.trackTitle : T.t("Aucune musique"); color: f.p.ink; font.family: "Google Sans Flex"; font.pixelSize: 14 * f.k; font.weight: Font.DemiBold }
          Text { width: parent.width; horizontalAlignment: Text.AlignHCenter; elide: Text.ElideRight; text: f.lk && f.lk.hasTrack ? String(f.lk.player.trackArtist || "").toUpperCase() : ""; color: f.p.sub; font.family: "Google Sans Flex"; font.pixelSize: 10 * f.k; font.letterSpacing: 1 }
          Item { width: 1; height: 6 * f.k }
          Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 8 * f.k
            Repeater {
              model: [["skip_previous", 0], [f.lk && f.lk.hasTrack && f.lk.player.isPlaying ? "pause" : "play_arrow", 1], ["skip_next", 2]]
              Rectangle {
                required property var modelData
                width: modelData[1] === 1 ? 48 * f.k : 28 * f.k; height: 28 * f.k; radius: height / 2
                color: modelData[1] === 1 ? f.p.acc : Qt.rgba(0.5, 0.5, 0.5, 0.25)
                Icon { anchors.centerIn: parent; icon: parent.modelData[0]; size: 16 * f.k; color: parent.modelData[1] === 1 ? f.p.accInk : f.p.ink }
                MouseArea {
                  anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                  onClicked: {
                    var pl = f.lk ? f.lk.player : null
                    if (pl) { if (parent.modelData[1] === 0) pl.previous(); else if (parent.modelData[1] === 1) pl.togglePlaying(); else pl.next() }
                    if (f.lk) f.lk.forcePasswordFocus()
                  }
                }
              }
            }
          }
        }
      }
    }

    // ======== colonne centrale
    Item {
      id: mid
      x: panel.colW + panel.pad * 2
      width: panel.width - (panel.colW + panel.pad * 2) * 2
      height: panel.height

      Row {
        id: clock
        anchors.horizontalCenter: parent.horizontalCenter
        y: panel.height * 0.04
        spacing: 12 * f.k
        Text {
          text: f.lk ? f.lk.hh : ""
          color: f.p.ink
          font.family: "Google Sans Flex"; font.pixelSize: 122 * f.k
          font.variableAxes: ({ "wdth": 25, "wght": 700, "opsz": 144 })
        }
        Text {
          text: f.lk ? f.lk.mm : ""
          color: f.p.ink; opacity: 0.72
          font.family: "Google Sans Flex"; font.pixelSize: 122 * f.k
          font.variableAxes: ({ "wdth": 25, "wght": 700, "opsz": 144 })
        }
      }
      Text {
        id: date
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: clock.bottom; anchors.topMargin: -16 * f.k
        text: f.lk ? f.lk.now.toLocaleDateString(Qt.locale(T.loc), "dddd • d MMM").toUpperCase().replace(".", "") : ""
        color: f.p.ink; font.family: "Google Sans Flex"; font.pixelSize: 12 * f.k; font.weight: Font.Bold; font.letterSpacing: 0.5
      }

      // Avatar dans un hexagone aux coins arrondis.
      Item {
        id: avatar
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: date.bottom; anchors.topMargin: 20 * f.k
        width: 140 * f.k; height: width
        Image {
          id: face
          anchors.fill: parent
          source: "file://" + Quickshell.env("HOME") + "/.face"
          fillMode: Image.PreserveAspectCrop
          sourceSize: Qt.size(300, 300)
          visible: false
        }
        Canvas {
          id: hexMask
          anchors.fill: parent
          visible: false
          layer.enabled: true
          onPaint: f.roundPoly(getContext("2d"), width / 2, height / 2, width / 2, 6, 0, 0.35, "black")
        }
        Canvas { anchors.fill: parent; onPaint: f.roundPoly(getContext("2d"), width / 2, height / 2, width / 2, 6, 0, 0.35, "#000000") }
        MultiEffect {
          anchors.fill: parent
          source: face
          maskEnabled: true
          maskSource: hexMask
          maskThresholdMin: 0.5
          maskSpreadAtMin: 1
        }
      }

      // Champ du mot de passe.
      Rectangle {
        id: field
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.horizontalCenterOffset: f.lk ? f.lk.shakeX : 0
        anchors.top: avatar.bottom; anchors.topMargin: 26 * f.k
        width: Math.min(mid.width - 20 * f.k, 290 * f.k); height: 38 * f.k
        radius: height / 2
        color: f.p.card
        border.width: f.lk && f.lk.errorState ? 1 : 0
        border.color: f.p.err
        Icon { x: 14 * f.k; anchors.verticalCenter: parent.verticalCenter; icon: "lock"; size: 15 * f.k; color: f.p.sub }
        Text {
          anchors.centerIn: parent
          visible: f.lk && f.lk.passwordText.length === 0
          text: f.lk && f.lk.authenticatingPassword ? T.t("Vérification…") : T.t("Entrez votre mot de passe")
          color: f.p.sub; font.family: "Google Sans Flex"; font.pixelSize: 12 * f.k
        }
        Row {
          anchors.centerIn: parent
          spacing: 5 * f.k
          Repeater {
            model: f.lk ? Math.min(18, f.lk.passwordText.length) : 0
            Rectangle {
              width: 8 * f.k; height: width; radius: width / 2; color: f.p.ink
              scale: 0; Component.onCompleted: scale = 1
              Behavior on scale { NumberAnimation { duration: 220; easing.type: Easing.OutBack } }
            }
          }
        }
        Icon {
          anchors.right: parent.right; anchors.rightMargin: 12 * f.k; anchors.verticalCenter: parent.verticalCenter
          icon: "arrow_forward"; size: 17 * f.k; color: f.p.ink
          MouseArea { anchors.fill: parent; anchors.margins: -6; cursorShape: Qt.PointingHandCursor; onClicked: if (f.lk) f.lk.accept() }
        }
      }
      Text {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: field.bottom; anchors.topMargin: 14 * f.k
        width: mid.width; horizontalAlignment: Text.AlignHCenter; elide: Text.ElideRight
        text: f.lk && f.lk.errorState ? f.lk.failureMessage.toUpperCase() : (f.lk && f.lk.fingerprintUnavailable ? T.t("EMPREINTE INDISPONIBLE") : "")
        color: f.p.err; font.family: "Google Sans Flex"; font.pixelSize: 11 * f.k; font.weight: Font.DemiBold; font.letterSpacing: 0.6
      }
    }

    // ======== colonne de droite
    Column {
      id: right
      x: panel.width - panel.colW - panel.pad + (1 - panel.t) * 30
      y: panel.pad
      width: panel.colW
      spacing: panel.pad

      Card {
        width: parent.width; height: 92 * f.k
        Row {
          anchors.centerIn: parent
          spacing: 10 * f.k
          Repeater {
            // [icône, valeur 0..1, sommets, rotation, ligne du haut]
            model: [["memory", data.cpu, 6, 0, data.temp ? data.temp + "°C" : ""],
                    ["memory_alt", data.memPct, 4, 45, ""],
                    [data.charging ? "battery_charging_full" : "battery_full", data.battery < 0 ? 1 : data.battery / 100, 8, 22.5, ""]]
            Item {
              id: gauge
              required property var modelData
              required property int index
              width: 66 * f.k; height: width
              Canvas {
                id: g
                anchors.fill: parent
                property real v: Math.max(0, Math.min(1, Number(gauge.modelData[1]) || 0))
                onVChanged: requestPaint()
                onPaint: {
                  var c = getContext("2d")
                  c.reset()
                  f.roundPoly(c, width / 2, height / 2, width / 2, gauge.modelData[2], gauge.modelData[3], 0.3, f.p.shapes ? f.p.shapes[gauge.index] : f.p.card2)
                  c.save()
                  c.beginPath(); c.rect(0, height * (1 - v), width, height * v); c.clip()
                  f.roundPoly(c, width / 2, height / 2, width / 2, gauge.modelData[2], gauge.modelData[3], 0.3, Qt.rgba(Qt.color(f.p.ink).r, Qt.color(f.p.ink).g, Qt.color(f.p.ink).b, 0.22))
                  c.restore()
                }
              }
              Column {
                anchors.centerIn: parent
                Row {
                  anchors.horizontalCenter: parent.horizontalCenter
                  spacing: 2
                  Icon { icon: gauge.modelData[0]; size: 11 * f.k; color: f.p.sub }
                  Text { visible: text !== ""; text: gauge.modelData[4]; color: f.p.sub; font.family: "Google Sans Flex"; font.pixelSize: 9 * f.k }
                }
                Text {
                  anchors.horizontalCenter: parent.horizontalCenter
                  text: Math.round(g.v * 100) + "%"
                  color: f.p.ink; font.family: "Google Sans Flex"; font.pixelSize: 20 * f.k
                  font.variableAxes: ({ "wdth": 60, "wght": 700 })
                }
              }
            }
          }
        }
      }
      Card {
        width: parent.width
        height: panel.height - panel.pad * 3 - 92 * f.k
        Text { x: 12 * f.k; y: 10 * f.k; text: data.notifs.length + T.t(" notifications"); color: f.p.sub; font.family: "Google Sans Flex"; font.pixelSize: 11 * f.k }
        Column {
          x: 8 * f.k; y: 30 * f.k
          width: parent.width - 16 * f.k
          spacing: 6 * f.k
          Repeater {
            model: f.groups(data.notifs).slice(0, 4)
            Rectangle {
              id: grp
              required property var modelData
              width: parent.width; height: gcol.implicitHeight + 14 * f.k
              radius: 14 * f.k; color: f.p.card2
              Rectangle {
                x: 8 * f.k; y: 8 * f.k
                width: 24 * f.k; height: width; radius: width / 2
                color: f.p.badge
                Text { anchors.centerIn: parent; text: String(grp.modelData.app || "?").charAt(0).toUpperCase(); color: f.p.accInk; font.family: "Google Sans Flex"; font.pixelSize: 12 * f.k; font.bold: true }
              }
              Column {
                id: gcol
                x: 40 * f.k; y: 7 * f.k
                width: parent.width - 48 * f.k
                spacing: 1
                Row {
                  width: parent.width
                  spacing: 6 * f.k
                  Text { text: grp.modelData.app; color: f.p.ink; font.family: "Google Sans Flex"; font.pixelSize: 11 * f.k; width: Math.min(implicitWidth, parent.width * 0.6); elide: Text.ElideRight }
                  Text { text: grp.modelData.ago; color: f.p.sub; font.family: "Google Sans Flex"; font.pixelSize: 10 * f.k }
                  Rectangle {
                    visible: grp.modelData.count > 1
                    width: 22 * f.k; height: 14 * f.k; radius: 7 * f.k; color: f.p.badge
                    Text { anchors.centerIn: parent; text: grp.modelData.count; color: f.p.accInk; font.family: "Google Sans Flex"; font.pixelSize: 9 * f.k; font.bold: true }
                  }
                }
                Repeater {
                  model: grp.modelData.items.slice(0, 3)
                  Text {
                    required property var modelData
                    width: gcol.width; elide: Text.ElideRight; textFormat: Text.PlainText
                    text: modelData.summary + "  " + String(modelData.body || "").replace(/\n/g, " ")
                    color: f.p.ink; opacity: 0.85; font.family: "Google Sans Flex"; font.pixelSize: 10.5 * f.k
                  }
                }
              }
            }
          }
        }
      }
    }
  }

  // Notifications regroupées par application, les plus récentes d'abord.
  function groups(list) {
    var out = [], by = {}
    for (var i = 0; i < list.length; i++) {
      var n = list[i], a = String(n.app || n.source || "?")
      if (!by[a]) { by[a] = { app: a, ago: data.ago(n.ts || n.time || n.timestamp), count: 0, items: [] }; out.push(by[a]) }
      by[a].count++; by[a].items.push({ summary: String(n.summary || ""), body: String(n.body || "") })
    }
    return out
  }

  // Polygone régulier aux coins arrondis (formes « Material » de caelestia).
  function roundPoly(c, cx, cy, r, n, rot, round, color) {
    var pts = []
    for (var i = 0; i < n; i++) {
      var a = (rot - 90) * Math.PI / 180 + i * 2 * Math.PI / n
      pts.push([cx + r * Math.cos(a), cy + r * Math.sin(a)])
    }
    c.beginPath()
    for (var j = 0; j < n; j++) {
      var p0 = pts[(j + n - 1) % n], p1 = pts[j], p2 = pts[(j + 1) % n]
      var ax = p1[0] + (p0[0] - p1[0]) * round / 2, ay = p1[1] + (p0[1] - p1[1]) * round / 2
      var bx = p1[0] + (p2[0] - p1[0]) * round / 2, by = p1[1] + (p2[1] - p1[1]) * round / 2
      if (j === 0) c.moveTo(ax, ay); else c.lineTo(ax, ay)
      c.quadraticCurveTo(p1[0], p1[1], bx, by)
    }
    c.closePath()
    c.fillStyle = color
    c.fill()
  }
}
