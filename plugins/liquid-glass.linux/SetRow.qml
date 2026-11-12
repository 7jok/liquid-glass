import QtQuick
import Quickshell
import Quickshell.Widgets
import "T.js" as T

// Une ligne de réglage (voir SetData.js pour les types), dessinée selon `look`,
// l'habillage du thème :
//   font head px ink sub acc accInk tile line radius border bcol hard upper
//   toggle  switch | m3 | adw | breeze | xfce | check | bracket | led | sticker | ribbon | dot | seg
//   slider  bar | m3 | line | ascii | blocks | ribbon | dots
//   chip    pill | box | text | ribbon | sticker | combo
//   stack (libellé au-dessus) · labelW (formulaire façon KDE) · leader (points de conduite) · icons
Item {
  id: r
  property var core: null
  property var row: []
  property var look: ({})
  readonly property var lk: look
  readonly property var s: core ? core.s : null
  readonly property string type: row.length ? row[0] : ""
  readonly property string key: row.length > 1 ? row[1] : ""
  readonly property string label: row.length > 2 ? up(row[2]) : ""
  readonly property string subText: row.length > 3 ? String(row[3] || "") : ""
  readonly property bool controlRow: ["t", "s", "c", "f", "b", "T", "S"].indexOf(type) >= 0
  readonly property int px: lk.px || 13
  readonly property color ink: lk.ink || "white"
  readonly property color sub: lk.sub || "#aaaaaa"
  readonly property color acc: lk.acc || "#4c9aff"
  readonly property color accInk: lk.accInk || "white"
  readonly property color tile: lk.tile || Qt.rgba(1, 1, 1, 0.08)
  readonly property color bcol: lk.bcol || Qt.rgba(1, 1, 1, 0.2)
  readonly property int rad: lk.radius !== undefined ? lk.radius : 10
  readonly property int bw: lk.border || 0
  readonly property int hard: lk.hard || 0
  function up(t) { return lk.upper ? String(t).toUpperCase() : String(t) }
  function a(c, x) { return Qt.rgba(c.r, c.g, c.b, x) }

  implicitHeight: body.item && body.item.visible ? body.item.implicitHeight + (controlRow || type === "h" ? 0 : 6) : 0
  height: implicitHeight

  Loader {
    id: body
    width: r.width
    sourceComponent: {
      switch (r.type) {
      case "h": return cHead
      case "t": case "s": case "c": case "f": case "b": case "T": case "S": return cControl
      case "tone": return cTone
      case "colors": return cColors
      case "walls": return cWalls
      case "styles": return cStyles
      case "wifi": return cWifi
      case "btdev": return cBt
      case "sinks": return cSinks
      case "battery": return cBattery
      case "profile": return cProfile
      case "power": return cPower
      case "info": return cInfo
      case "acts": return cActs
      }
      return null
    }
  }

  // ================================================================ titres
  Component {
    id: cHead
    Item {
      implicitHeight: ht.implicitHeight + (r.lk.headGap !== undefined ? r.lk.headGap : 10)
      Text {
        id: ht
        y: r.lk.headGap !== undefined ? r.lk.headGap : 10
        width: parent.width
        text: (r.lk.headPrefix || "") + r.up(r.row[2]) + (r.lk.headSuffix || "")
        font.family: r.lk.head || r.lk.font; font.pixelSize: r.lk.headPx || r.px + 1; font.weight: r.lk.headWeight || Font.Bold
        font.letterSpacing: r.lk.headSpacing || 0; font.italic: !!r.lk.headItalic
        color: r.lk.headColor || r.sub
        elide: Text.ElideRight
      }
    }
  }

  // ================================================================ ligne + commande
  Component {
    id: cControl
    Item {
      id: cr
      readonly property bool stack: !!r.lk.stack || r.type === "f" || (r.type === "c" && (r.row[5] || []).length > 3 && r.lk.chip !== "combo" && r.lk.chip !== "text")
      readonly property int lw: r.lk.labelW || 0
      readonly property int padV: r.lk.rowPad !== undefined ? r.lk.rowPad : 9
      readonly property int ctlW: ctl.item ? ctl.item.implicitWidth : 0
      implicitHeight: stack ? lab.implicitHeight + 8 + (ctl.item ? ctl.item.implicitHeight : 0) + padV * 2
                            : Math.max(lab.implicitHeight, ctl.item ? ctl.item.implicitHeight : 0) + padV * 2
      Column {
        id: lab
        x: cr.lw > 0 ? 0 : 0
        y: cr.stack ? cr.padV : (cr.height - implicitHeight) / 2
        width: cr.lw > 0 ? cr.lw : (cr.stack ? cr.width : cr.width - cr.ctlW - 16)
        spacing: 2
        Text {
          width: parent.width
          text: r.label + (r.lk.labelSuffix || "")
          font.family: r.lk.font; font.pixelSize: r.px; font.weight: r.lk.labelWeight || Font.Medium
          font.letterSpacing: r.lk.spacing || 0; font.italic: !!r.lk.italic
          color: r.ink; wrapMode: Text.Wrap
          horizontalAlignment: cr.lw > 0 ? Text.AlignRight : Text.AlignLeft
        }
        Text {
          visible: r.subText !== "" || (r.type === "T" && r.core.sysSub(r.key) !== "")
          width: parent.width
          text: r.type === "T" && r.core.sysSub(r.key) !== "" ? r.core.sysSub(r.key) : r.subText
          font.family: r.lk.font; font.pixelSize: r.px - 2; color: r.sub; wrapMode: Text.Wrap
          horizontalAlignment: cr.lw > 0 ? Text.AlignRight : Text.AlignLeft
        }
      }
      // Points de conduite entre le libellé et la commande (Blanc, 7JOKS).
      Text {
        visible: !!r.lk.leader && !cr.stack && cr.lw === 0
        x: lab.x + Math.min(lab.width, labMetrics.advanceWidth) + 6
        width: Math.max(0, cr.width - cr.ctlW - 12 - x)
        anchors.verticalCenter: parent.verticalCenter
        clip: true
        text: ". . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . ."
        font.family: r.lk.font; font.pixelSize: r.px - 1; color: r.a(r.sub, 0.6)
      }
      TextMetrics { id: labMetrics; font.family: r.lk.font; font.pixelSize: r.px; text: r.label }
      Loader {
        id: ctl
        x: cr.lw > 0 ? cr.lw + 16 : (cr.stack ? 0 : cr.width - cr.ctlW)
        y: cr.stack ? lab.y + lab.implicitHeight + 8 : (cr.height - (item ? item.implicitHeight : 0)) / 2
        width: cr.stack ? cr.width : (cr.lw > 0 && r.type !== "t" && r.type !== "T" ? cr.width - cr.lw - 16 : implicitWidth)
        sourceComponent: r.type === "t" || r.type === "T" ? cTog : r.type === "s" || r.type === "S" ? cSld
                       : r.type === "c" || r.type === "f" ? cChoice : cButton
      }
    }
  }

  // ---- interrupteur
  Component {
    id: cTog
    Tog {
      on: r.type === "T" ? r.core.sysOn(r.key) : r.core.asBool(r.core.val(r.key, r.row[4]), r.row[4] === true)
      onFlip: r.type === "T" ? r.core.sysToggle(r.key) : r.core.set(r.key, !on)
    }
  }
  // ---- curseur
  Component {
    id: cSld
    Sld {
      readonly property var ex: r.type === "s" ? r.row[5] : [0, 1, 0.01, "pct100"]
      from: ex[0]; to: ex[1]; stepSize: ex[2]
      value: r.type === "S" ? r.core.sysVal(r.key) : Number(r.core.val(r.key, r.row[4]))
      shown: r.type === "S" ? Math.round(value * 100) + " %" : r.core.fmt(ex[3], value)
      live: r.type === "S"
      onCommit: function(v) { if (r.type === "S") r.core.sysSet(r.key, v); else r.core.set(r.key, Math.round(v / stepSize) * stepSize) }
    }
  }
  // ---- choix
  Component {
    id: cChoice
    Chips {
      options: r.row[5] || []
      value: String(r.core.val(r.key, r.row[4]))
      fontPreview: r.type === "f"
      onPick: function(v) { r.core.set(r.key, v) }
    }
  }
  // ---- bouton
  Component {
    id: cButton
    Btn { text: r.row[5] || T.t("Ouvrir"); onClick: { r.core.close(); r.core.run(r.row[6]) } }
  }

  // ================================================================ blocs
  Component {
    id: cTone
    Column {
      visible: r.core.tones.length > 0
      spacing: 8
      Text { visible: !!r.lk.blockLabels; text: r.label; font.family: r.lk.font; font.pixelSize: r.px; color: r.ink }
      Chips {
        width: parent.width
        options: r.core.tones.map(function(t) { return [t[0], t[1], t[2]] })
        value: r.core.tone
        onPick: function(v) { r.core.setTone(v) }
      }
    }
  }
  Component {
    id: cColors
    Column {
      visible: r.s.style !== "mono"
      spacing: 10
      Chips {
        width: parent.width
        options: r.core.colorModes.map(function(m) { return [m[0], m[2]] })
        value: r.s.colorMode
        onPick: function(v) { r.core.setColors(v) }
      }
      Flow {
        visible: r.s.colorMode === "perso"
        width: parent.width; spacing: 7
        Repeater {
          model: r.s.accentSwatches
          delegate: Rectangle {
            required property string modelData
            readonly property bool cur: r.s.accentHex.toLowerCase() === modelData
            width: 24; height: 24
            radius: r.lk.swatch === "square" ? 0 : (r.lk.swatch === "soft" ? 6 : 12)
            color: modelData
            border.width: cur ? 3 : 1; border.color: cur ? r.ink : r.a(r.ink, 0.25)
            scale: swm.containsMouse ? 1.15 : 1
            Behavior on scale { NumberAnimation { duration: 160; easing.type: Easing.OutBack } }
            MouseArea { id: swm; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: r.core.setAccent(modelData) }
          }
        }
      }
      Rectangle {
        visible: r.s.colorMode === "perso"
        width: parent.width; height: 12; radius: r.lk.swatch === "square" ? 0 : 6
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
        MouseArea { anchors.fill: parent; anchors.margins: -6; onReleased: function(m) { r.core.setAccent(r.core.hueHex(m.x / width)) } }
      }
    }
  }
  Component {
    id: cWalls
    Column {
      spacing: 8
      Text {
        width: parent.width; elide: Text.ElideMiddle
        text: (r.lk.upper ? T.t("ACTUEL : ") : T.t("Actuel : ")) + (r.core.bgName || "—")
        font.family: r.lk.font; font.pixelSize: r.px - 1; color: r.sub
      }
      Flow {
        width: parent.width; spacing: 8
        Btn { text: T.t("Carrousel"); icon: "view_carousel"; onClick: r.core.walls() }
        Btn { text: T.t("Suivant"); icon: "skip_next"; onClick: r.core.nextWall() }
        Btn { visible: r.core.liveCount > 0; text: T.t("Animé au hasard") + " (" + r.core.liveCount + ")"; icon: "animation"; onClick: r.core.randomLive() }
      }
    }
  }
  Component {
    id: cStyles
    Chips {
      implicitHeight: implicitHeightOf + 4
      options: r.core.styleList
      value: r.s.style
      onPick: function(v) { r.core.pickStyle(v) }
    }
  }

  // ---- listes : réseaux, appareils, sorties
  component ListLine: Item {
    id: ll
    property string icon: ""
    property string text: ""
    property string detail: ""
    property bool active: false
    signal click()
    width: parent ? parent.width : 0
    implicitHeight: Math.max(32, llc.implicitHeight + 12)
    Rectangle {
      anchors.fill: parent
      radius: r.rad
      color: ll.active ? r.a(r.acc, 0.18) : (llm.containsMouse ? r.a(r.ink, 0.06) : (r.lk.listBg ? r.tile : "transparent"))
      border.width: ll.active && r.bw > 0 ? r.bw : 0; border.color: r.acc
    }
    Row {
      id: llc
      x: 10; anchors.verticalCenter: parent.verticalCenter
      spacing: 10
      MIcon { visible: r.lk.icons !== false && ll.icon !== ""; anchors.verticalCenter: parent.verticalCenter; icon: ll.icon; size: r.px + 4; color: ll.active ? r.acc : r.ink; fill: ll.active ? 1 : 0 }
      Text {
        visible: r.lk.icons === false
        anchors.verticalCenter: parent.verticalCenter
        text: ll.active ? (r.lk.activeMark || "*") : " "
        font.family: r.lk.font; font.pixelSize: r.px; color: r.acc
      }
      Text { anchors.verticalCenter: parent.verticalCenter; width: ll.width - 110; elide: Text.ElideRight; text: r.up(ll.text); font.family: r.lk.font; font.pixelSize: r.px; color: r.ink; font.weight: ll.active ? Font.Bold : Font.Normal }
    }
    Text { anchors.right: parent.right; anchors.rightMargin: 10; anchors.verticalCenter: parent.verticalCenter; text: r.up(ll.detail); font.family: r.lk.font; font.pixelSize: r.px - 2; color: r.sub }
    MouseArea { id: llm; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: ll.click() }
  }
  Component {
    id: cWifi
    Column {
      spacing: 2
      Text {
        visible: r.s.wifiList.length === 0
        text: r.s.wifiOn ? (r.s.wifiBusy ? T.t("Recherche…") : T.t("Aucun réseau")) : T.t("Wi-Fi coupé")
        font.family: r.lk.font; font.pixelSize: r.px - 1; color: r.sub
      }
      Repeater {
        model: r.s.wifiOn ? r.s.wifiList.slice(0, 8) : []
        delegate: ListLine {
          required property var modelData
          icon: modelData.signal > 66 ? "network_wifi" : (modelData.signal > 33 ? "network_wifi_2_bar" : "network_wifi_1_bar")
          text: modelData.ssid
          detail: (modelData.secure ? "🔒 " : "") + modelData.signal + " %"
          active: modelData.active
          onClick: r.s.connectWifi(modelData.ssid)
        }
      }
    }
  }
  Component {
    id: cBt
    Column {
      spacing: 2
      Text {
        visible: r.core.btDevices.length === 0
        text: r.core.bt && r.core.bt.enabled ? T.t("Aucun appareil associé") : T.t("Bluetooth coupé")
        font.family: r.lk.font; font.pixelSize: r.px - 1; color: r.sub
      }
      Repeater {
        model: r.core.btDevices
        delegate: ListLine {
          required property var modelData
          icon: r.core.btIcon(modelData)
          text: modelData.name || modelData.address
          detail: modelData.connected ? (modelData.batteryAvailable ? Math.round(modelData.battery * 100) + " %" : T.t("connecté")) : T.t("connecter")
          active: modelData.connected
          onClick: r.core.btToggle(modelData)
        }
      }
    }
  }
  Component {
    id: cSinks
    Column {
      spacing: 2
      Repeater {
        model: r.core.sinks
        delegate: ListLine {
          required property var modelData
          icon: "speaker"
          text: r.core.sinkName(modelData)
          active: r.core.sink === modelData
          onClick: r.core.setSink(modelData)
        }
      }
    }
  }
  Component {
    id: cBattery
    Column {
      spacing: 8
      Row {
        spacing: 12
        Text { text: r.core.batteryPct < 0 ? "⚡" : r.core.batteryPct + "%"; font.family: r.lk.head || r.lk.font; font.pixelSize: r.px * 2.6; font.weight: Font.Bold; color: r.ink }
        Column {
          anchors.verticalCenter: parent.verticalCenter
          Text { text: r.up(r.core.charging ? T.t("En charge") : (r.core.batteryPct < 0 ? T.t("Sur secteur") : T.t("Sur batterie"))); font.family: r.lk.font; font.pixelSize: r.px; color: r.ink }
          Text { text: r.core.batteryTime; font.family: r.lk.font; font.pixelSize: r.px - 2; color: r.sub }
        }
      }
      Sld { visible: r.core.batteryPct >= 0; width: parent.width; from: 0; to: 100; value: Math.max(0, r.core.batteryPct); shown: ""; readOnly: true }
    }
  }
  Component {
    id: cProfile
    Chips {
      implicitHeight: implicitHeightOf + 4
      options: r.core.profiles.map(function(p) { return [p[0], p[1]] })
      value: r.core.profile
      onPick: function(v) { r.core.setProfile(v) }
    }
  }
  Component {
    id: cPower
    Flow {
      spacing: 8
      Repeater {
        model: r.core.powerActs
        delegate: Btn {
          required property var modelData
          required property int index
          text: modelData[2]; icon: modelData[1]; danger: index === 4
          onClick: r.core.power(modelData[0])
        }
      }
    }
  }
  Component {
    id: cInfo
    Column {
      spacing: 5
      Repeater {
        model: r.core.infoRows
        delegate: Item {
          required property var modelData
          width: parent.width; height: Math.max(ik.implicitHeight, iv.implicitHeight)
          Text { id: ik; width: parent.width * 0.32; text: r.up(modelData[0]) + (r.lk.infoSep || ""); font.family: r.lk.font; font.pixelSize: r.px - 1; color: r.sub; elide: Text.ElideRight }
          Text { id: iv; x: parent.width * 0.34; width: parent.width * 0.66; text: modelData[1]; font.family: r.lk.font; font.pixelSize: r.px - 1; color: r.ink; wrapMode: Text.Wrap }
        }
      }
    }
  }
  Component {
    id: cActs
    Flow {
      spacing: 8
      Repeater {
        model: r.core.acts
        delegate: Btn {
          required property var modelData
          text: modelData[1]; icon: modelData[0]; tall: !!r.lk.tallActs
          width: r.lk.tallActs ? (r.width - 24) / 4 : implicitWidth
          onClick: r.core.doAct(modelData[2])
        }
      }
    }
  }

  // ================================================================ briques
  // Interrupteur.
  component Tog: Item {
    id: tg
    property bool on: false
    signal flip()
    readonly property string v: r.lk.toggle || "switch"
    implicitWidth: v === "m3" ? 52 : v === "adw" ? 46 : v === "breeze" || v === "xfce" ? 20 : v === "check" ? tgt.implicitWidth
                 : v === "bracket" ? 86 : v === "led" ? 58 : v === "sticker" ? 66 : v === "ribbon" ? 70 : v === "dot" ? 26 : v === "seg" ? 92 : 42
    implicitHeight: v === "m3" ? 32 : v === "adw" ? 26 : v === "breeze" || v === "xfce" ? 20 : v === "check" || v === "bracket" ? tgt.implicitHeight
                  : v === "led" ? 22 : v === "sticker" ? 32 : v === "ribbon" ? 26 : v === "dot" ? 26 : v === "seg" ? 28 : 24
    // pilule (switch, m3, adw)
    Rectangle {
      visible: tg.v === "switch" || tg.v === "m3" || tg.v === "adw"
      anchors.fill: parent; radius: height / 2
      color: tg.on ? r.acc : (tg.v === "m3" ? r.a(r.ink, 0.1) : r.a(r.ink, 0.18))
      border.width: tg.v === "m3" && !tg.on ? 2 : 0; border.color: r.a(r.ink, 0.45)
      Behavior on color { ColorAnimation { duration: 150 } }
      Rectangle {
        readonly property real d: tg.v === "m3" ? (tg.on ? 24 : 16) : parent.height - 6
        width: d; height: d; radius: d / 2
        x: tg.on ? parent.width - d - (parent.height - d) / 2 : (parent.height - d) / 2
        anchors.verticalCenter: parent.verticalCenter
        color: tg.v === "m3" ? (tg.on ? r.accInk : r.a(r.ink, 0.55)) : (tg.on && r.lk.knob ? r.lk.knob : "white")
        Behavior on x { NumberAnimation { duration: 220; easing.type: Easing.OutBack } }
        Behavior on width { NumberAnimation { duration: 160 } }
        MIcon { visible: tg.v === "m3" && tg.on; anchors.centerIn: parent; icon: "check"; size: 15; color: r.acc }
      }
    }
    // case à cocher (breeze, xfce)
    Rectangle {
      visible: tg.v === "breeze" || tg.v === "xfce"
      anchors.fill: parent; radius: tg.v === "breeze" ? 3 : 2
      color: tg.on && tg.v === "breeze" ? r.acc : (tg.v === "xfce" ? r.a(r.ink, 0.06) : "transparent")
      border.width: 1; border.color: tg.on ? r.acc : r.a(r.ink, 0.5)
      MIcon { visible: tg.on; anchors.centerIn: parent; icon: "check"; size: 16; weight: 700; color: tg.v === "breeze" ? "white" : r.acc }
    }
    // texte : [x] / [ONLINE]
    Text {
      id: tgt
      visible: tg.v === "check" || tg.v === "bracket"
      anchors.right: parent.right
      text: tg.v === "check" ? (tg.on ? "[x]" : "[ ]") : (tg.on ? "[ ACTIF ]" : "[ ---- ]")
      font.family: r.lk.font; font.pixelSize: r.px; font.weight: Font.Bold
      color: tg.on ? r.acc : r.sub
    }
    // voyant
    Row {
      visible: tg.v === "led"
      anchors.verticalCenter: parent.verticalCenter; anchors.right: parent.right
      spacing: 7
      Rectangle {
        width: 12; height: 12; anchors.verticalCenter: parent.verticalCenter
        radius: r.rad > 6 ? 6 : 1
        color: tg.on ? r.acc : r.a(r.ink, 0.12)
        border.width: 1; border.color: tg.on ? r.acc : r.a(r.ink, 0.3)
        Rectangle { visible: tg.on; anchors.centerIn: parent; width: 22; height: 22; radius: 11; color: r.a(r.acc, 0.22); z: -1 }
      }
      Text { text: tg.on ? "ON" : "OFF"; font.family: r.lk.font; font.pixelSize: r.px - 2; font.weight: Font.Bold; color: tg.on ? r.acc : r.sub; width: 26 }
    }
    // autocollant (Jouet)
    Item {
      visible: tg.v === "sticker"
      anchors.fill: parent
      rotation: tg.on ? -4 : 3
      Behavior on rotation { NumberAnimation { duration: 260; easing.type: Easing.OutBack } }
      Rectangle { x: 3; y: 3; width: parent.width; height: parent.height; radius: 12; color: r.bcol }
      Rectangle {
        anchors.fill: parent; radius: 12
        color: tg.on ? r.acc : "white"
        border.width: 2.5; border.color: r.bcol
        Text { anchors.centerIn: parent; text: tg.on ? T.t("OUI !") : T.t("non"); font.family: r.lk.head || r.lk.font; font.pixelSize: r.px; font.weight: Font.Black; color: tg.on ? r.accInk : r.bcol }
      }
    }
    // ruban (Rubans) : parallélogramme
    Item {
      visible: tg.v === "ribbon"
      anchors.fill: parent
      Rectangle {
        x: 4; y: 4; width: parent.width; height: parent.height; color: "black"; opacity: 0.6
        transform: Matrix4x4 { matrix: Qt.matrix4x4(1, -0.35, 0, 4.5, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1) }
      }
      Rectangle {
        anchors.fill: parent
        color: tg.on ? r.acc : r.a(r.ink, 0.12)
        border.width: tg.on ? 0 : 2; border.color: r.a(r.ink, 0.5)
        transform: Matrix4x4 { matrix: Qt.matrix4x4(1, -0.35, 0, 4.5, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1) }
        Behavior on color { ColorAnimation { duration: 140 } }
      }
      Text { anchors.centerIn: parent; text: tg.on ? "ON" : "OFF"; font.family: r.lk.head || r.lk.font; font.pixelSize: r.px; font.weight: Font.Black; font.italic: true; color: tg.on ? r.accInk : r.ink }
    }
    // point lumineux (Violet)
    Rectangle {
      visible: tg.v === "dot"
      anchors.centerIn: parent; width: 22; height: 22; radius: 11
      color: tg.on ? r.acc : "transparent"
      border.width: 2; border.color: tg.on ? r.acc : r.a(r.ink, 0.4)
      Behavior on color { ColorAnimation { duration: 200 } }
      Rectangle { visible: tg.on; anchors.centerIn: parent; width: 36; height: 36; radius: 18; color: r.a(r.acc, 0.18); z: -1 }
      Rectangle { visible: tg.on; anchors.centerIn: parent; width: 8; height: 8; radius: 4; color: r.accInk }
    }
    // OUI | NON
    Rectangle {
      visible: tg.v === "seg"
      anchors.fill: parent; radius: r.rad
      color: "transparent"; border.width: Math.max(1, r.bw); border.color: r.bcol
      Rectangle { x: tg.on ? 0 : parent.width / 2; width: parent.width / 2; height: parent.height; radius: r.rad; color: r.acc
        Behavior on x { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } } }
      Row {
        anchors.fill: parent
        Text { width: parent.width / 2; height: parent.height; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter; text: T.t("OUI"); font.family: r.lk.font; font.pixelSize: r.px - 2; font.weight: Font.Bold; color: tg.on ? r.accInk : r.sub }
        Text { width: parent.width / 2; height: parent.height; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter; text: T.t("NON"); font.family: r.lk.font; font.pixelSize: r.px - 2; font.weight: Font.Bold; color: tg.on ? r.sub : r.accInk }
      }
    }
    MouseArea { anchors.fill: parent; anchors.margins: -4; cursorShape: Qt.PointingHandCursor; onClicked: tg.flip() }
  }

  // Curseur : valeur affichée en direct, envoyée au relâcher (sauf live : volume, luminosité).
  component Sld: Item {
    id: sd
    property real from: 0
    property real to: 1
    property real stepSize: 0.01
    property real value: 0
    property string shown: ""
    property bool live: false
    property bool readOnly: false
    signal commit(real v)
    property real dragV: -1
    readonly property real cur: dragV >= 0 ? dragV : value
    readonly property real f: to > from ? Math.max(0, Math.min(1, (cur - from) / (to - from))) : 0
    readonly property string v: r.lk.slider || "bar"
    implicitWidth: 230
    implicitHeight: v === "m3" ? 40 : v === "ascii" ? at.implicitHeight + 2 : v === "blocks" ? 22 : 24
    readonly property int valW: shown === "" ? 0 : 58
    readonly property real tw: width - valW
    function setFrom(x) {
      var k = Math.max(0, Math.min(1, x / tw)), val = from + k * (to - from)
      dragV = val
      if (live) commit(val)
    }
    // piste + remplissage (bar, line, m3)
    Item {
      visible: sd.v === "bar" || sd.v === "line" || sd.v === "m3"
      width: sd.tw; height: parent.height
      readonly property int th: sd.v === "m3" ? 16 : (sd.v === "line" ? 4 : 8)
      Rectangle {
        anchors.verticalCenter: parent.verticalCenter
        x: sd.v === "m3" ? Math.max(0, sd.f * parent.width) + 6 : 0
        width: sd.v === "m3" ? Math.max(0, parent.width - x) : parent.width
        height: parent.th; radius: sd.v === "m3" ? 6 : parent.th / 2
        color: sd.v === "m3" ? r.a(r.acc, 0.25) : r.a(r.ink, 0.16)
      }
      Rectangle {
        anchors.verticalCenter: parent.verticalCenter
        width: Math.max(sd.v === "m3" ? 4 : 0, sd.f * parent.width - (sd.v === "m3" ? 6 : 0)); height: parent.th
        radius: sd.v === "m3" ? 6 : parent.th / 2
        color: r.acc
      }
      Rectangle {
        visible: !sd.readOnly
        width: sd.v === "m3" ? 4 : (sd.v === "line" ? 18 : 16); height: sd.v === "m3" ? 40 : width
        radius: sd.v === "m3" ? 2 : width / 2
        x: sd.f * parent.width - width / 2; anchors.verticalCenter: parent.verticalCenter
        color: sd.v === "m3" ? r.acc : "white"
        border.width: sd.v === "m3" ? 0 : 1; border.color: r.a("#000000", 0.2)
      }
    }
    // [######----]
    Text {
      id: at
      visible: sd.v === "ascii"
      width: sd.tw; anchors.verticalCenter: parent.verticalCenter
      readonly property int n: Math.max(6, Math.floor(sd.tw / (r.px * 0.62)) - 2)
      text: "[" + "#".repeat(Math.round(sd.f * n)) + "-".repeat(n - Math.round(sd.f * n)) + "]"
      font.family: r.lk.font; font.pixelSize: r.px; color: r.acc
    }
    // blocs
    Row {
      visible: sd.v === "blocks" || sd.v === "dots" || sd.v === "ribbon"
      anchors.verticalCenter: parent.verticalCenter
      spacing: sd.v === "ribbon" ? 2 : 3
      readonly property int n: sd.v === "dots" ? 12 : (sd.v === "ribbon" ? 14 : 10)
      Repeater {
        model: parent.n
        delegate: Rectangle {
          required property int index
          readonly property bool lit: (index + 0.5) / parent.n <= sd.f
          width: (sd.tw - (parent.n - 1) * parent.spacing) / parent.n
          height: sd.v === "dots" ? width : (sd.v === "ribbon" ? 18 : 16)
          radius: sd.v === "dots" ? width / 2 : (sd.v === "ribbon" ? 0 : Math.min(3, r.rad))
          color: lit ? r.acc : r.a(r.ink, 0.12)
          border.width: sd.v === "blocks" && !lit ? 1 : 0; border.color: r.a(r.ink, 0.25)
          transform: Matrix4x4 { matrix: sd.v === "ribbon" ? Qt.matrix4x4(1, -0.35, 0, 3, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1) : Qt.matrix4x4() }
        }
      }
    }
    Text {
      visible: sd.valW > 0
      x: sd.tw + 8; width: sd.valW - 8; anchors.verticalCenter: parent.verticalCenter
      horizontalAlignment: Text.AlignRight
      text: sd.shown
      font.family: r.lk.font; font.pixelSize: r.px - 1; color: r.sub
    }
    MouseArea {
      enabled: !sd.readOnly
      width: sd.tw; height: parent.height
      anchors.verticalCenter: parent.verticalCenter
      cursorShape: Qt.PointingHandCursor
      onPressed: function(m) { sd.setFrom(m.x) }
      onPositionChanged: function(m) { if (pressed) sd.setFrom(m.x) }
      onReleased: { if (!sd.live && sd.dragV >= 0) sd.commit(sd.dragV); releaseTimer.restart() }
      onWheel: function(w) { var nv = Math.max(sd.from, Math.min(sd.to, sd.cur + (w.angleDelta.y > 0 ? 1 : -1) * Math.max(sd.stepSize, (sd.to - sd.from) / 20))); sd.dragV = nv; sd.commit(nv); releaseTimer.restart() }
    }
    Timer { id: releaseTimer; interval: 2600; onTriggered: sd.dragV = -1 }
  }

  // Choix parmi des options [valeur, nom, couleur?].
  component Chips: Item {
    id: ch
    property var options: []
    property string value: ""
    property bool fontPreview: false
    property bool expanded: false
    signal pick(string v)
    readonly property string v: r.lk.chip || "pill"
    readonly property int curIdx: { for (var i = 0; i < options.length; i++) if (String(options[i][0]) === value) return i; return 0 }
    readonly property real implicitHeightOf: v === "combo" ? cb.height + (expanded ? cl.height + 4 : 0) : (v === "text" ? tx.implicitHeight : fl.implicitHeight)
    implicitWidth: v === "combo" ? 200 : v === "text" ? tx.implicitWidth : Math.min(fl.implicitW, 420)
    implicitHeight: implicitHeightOf
    // puces
    Flow {
      id: fl
      visible: ch.v !== "combo" && ch.v !== "text"
      width: parent.width > 0 ? parent.width : 420
      spacing: ch.v === "ribbon" ? 10 : 6
      property real implicitW: { var w = 0; for (var i = 0; i < children.length; i++) w += children[i].width + spacing; return w }
      Repeater {
        model: ch.options
        delegate: Item {
          id: chip
          required property var modelData
          required property int index
          readonly property bool cur: ch.curIdx === index
          width: ct.implicitWidth + (modelData.length > 2 ? 30 : 20) + (ch.v === "ribbon" ? 10 : 0)
          height: ch.v === "sticker" ? 32 : (ch.v === "ribbon" ? 28 : 30)
          Rectangle {
            visible: ch.v === "sticker"
            x: 3; y: 3; width: parent.width; height: parent.height; radius: 14; color: r.bcol
          }
          Rectangle {
            anchors.fill: parent
            radius: ch.v === "pill" ? height / 2 : (ch.v === "sticker" ? 14 : (ch.v === "ribbon" ? 0 : r.rad))
            color: chip.cur ? r.acc : (cm.containsMouse ? r.a(r.ink, 0.12) : (ch.v === "sticker" ? "white" : r.tile))
            border.width: ch.v === "sticker" ? 2.5 : (ch.v === "box" ? Math.max(1, r.bw) : 0)
            border.color: ch.v === "sticker" ? r.bcol : (chip.cur ? r.acc : r.bcol)
            transform: Matrix4x4 { matrix: ch.v === "ribbon" ? Qt.matrix4x4(1, -0.35, 0, 5, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1) : Qt.matrix4x4() }
            rotation: ch.v === "sticker" ? (chip.index % 2 ? 2 : -2) : 0
          }
          Row {
            anchors.centerIn: parent; spacing: 6
            Rectangle { visible: chip.modelData.length > 2; anchors.verticalCenter: parent.verticalCenter; width: 12; height: 12; radius: ch.v === "box" || ch.v === "ribbon" ? 0 : 6; color: chip.modelData.length > 2 ? chip.modelData[2] : "transparent"; border.width: 1; border.color: r.a(r.ink, 0.35) }
            Text {
              id: ct
              anchors.verticalCenter: parent.verticalCenter
              text: r.up(chip.modelData[1])
              font.family: ch.fontPreview && chip.modelData[0] !== "" ? chip.modelData[0] : r.lk.font
              font.pixelSize: r.px - 1; font.weight: chip.cur ? Font.Bold : Font.Normal; font.italic: ch.v === "ribbon"
              color: chip.cur ? r.accInk : (ch.v === "sticker" ? r.bcol : r.ink)
            }
          }
          MouseArea { id: cm; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: ch.pick(String(chip.modelData[0])) }
        }
      }
    }
    // texte : < valeur >  (Blanc, 7JOKS)
    Text {
      id: tx
      visible: ch.v === "text"
      anchors.right: parent.right
      text: "< " + r.up(ch.options.length ? ch.options[ch.curIdx][1] : "") + " >"
      font.family: ch.fontPreview && ch.value !== "" ? ch.value : r.lk.font
      font.pixelSize: r.px; font.weight: Font.Bold; color: r.acc
      MouseArea {
        anchors.fill: parent; cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: function(m) { var n = ch.options.length; if (n) ch.pick(String(ch.options[(ch.curIdx + (m.button === Qt.RightButton ? n - 1 : 1)) % n][0])) }
        onWheel: function(w) { var n = ch.options.length; if (n) ch.pick(String(ch.options[(ch.curIdx + (w.angleDelta.y < 0 ? 1 : n - 1)) % n][0])) }
      }
    }
    // liste déroulante (GNOME, Plasma, Xfce, Cinnamon)
    Rectangle {
      id: cb
      visible: ch.v === "combo"
      width: Math.max(160, Math.min(parent.width > 0 ? parent.width : 200, 240)); height: 30
      anchors.right: parent.right
      radius: r.rad; color: cbm.containsMouse ? r.a(r.ink, 0.14) : r.tile
      border.width: r.bw; border.color: r.bcol
      Text { x: 10; width: parent.width - 34; anchors.verticalCenter: parent.verticalCenter; elide: Text.ElideRight
        text: ch.options.length ? ch.options[ch.curIdx][1] : ""; font.family: ch.fontPreview && ch.value !== "" ? ch.value : r.lk.font; font.pixelSize: r.px - 1; color: r.ink }
      MIcon { anchors.right: parent.right; anchors.rightMargin: 6; anchors.verticalCenter: parent.verticalCenter; icon: ch.expanded ? "expand_less" : "expand_more"; size: 18; color: r.sub }
      MouseArea { id: cbm; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: ch.expanded = !ch.expanded }
    }
    Rectangle {
      id: cl
      visible: ch.v === "combo" && ch.expanded
      y: cb.height + 4; width: cb.width; anchors.right: parent.right
      height: clc.implicitHeight + 8
      radius: r.rad; color: r.lk.popBg || r.tile; border.width: 1; border.color: r.bcol
      Column {
        id: clc
        x: 4; y: 4; width: parent.width - 8
        Repeater {
          model: ch.options
          delegate: Rectangle {
            required property var modelData
            required property int index
            width: clc.width; height: 26; radius: Math.max(0, r.rad - 2)
            color: ch.curIdx === index ? r.acc : (olm.containsMouse ? r.a(r.ink, 0.1) : "transparent")
            Text { x: 8; anchors.verticalCenter: parent.verticalCenter; text: modelData[1]; font.family: ch.fontPreview && modelData[0] !== "" ? modelData[0] : r.lk.font; font.pixelSize: r.px - 1; color: ch.curIdx === index ? r.accInk : r.ink }
            MouseArea { id: olm; anchors.fill: parent; hoverEnabled: true; onClicked: { ch.expanded = false; ch.pick(String(modelData[0])) } }
          }
        }
      }
    }
  }

  // Bouton.
  component Btn: Item {
    id: bt
    property string text: ""
    property string icon: ""
    property bool danger: false
    property bool tall: false
    signal click()
    readonly property string v: r.lk.button || "pill"
    readonly property color bc: danger ? (r.lk.danger || "#e5484d") : r.acc
    implicitWidth: tall ? 76 : bRow.implicitWidth + (v === "text" ? 4 : 22)
    implicitHeight: tall ? 60 : (v === "text" ? bTxt.implicitHeight + 4 : 30)
    Rectangle {
      visible: (v === "sticker" || r.hard > 0) && v !== "text"
      x: r.hard || 3; y: r.hard || 3; width: parent.width; height: parent.height
      radius: v === "pill" ? height / 2 : r.rad; color: r.bcol
    }
    Rectangle {
      visible: bt.v !== "text"
      anchors.fill: parent
      radius: bt.v === "pill" && !bt.tall ? height / 2 : r.rad
      color: bm.pressed ? Qt.darker(bt.bc, 1.2) : (bm.containsMouse ? bt.bc : (bt.v === "solid" ? r.a(bt.bc, 0.85) : r.tile))
      border.width: bt.v === "sticker" ? 2.5 : r.bw; border.color: bt.v === "sticker" ? r.bcol : (bt.danger ? bt.bc : r.bcol)
      transform: Matrix4x4 { matrix: bt.v === "ribbon" ? Qt.matrix4x4(1, -0.3, 0, 0.15 * bt.height, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1) : Qt.matrix4x4() }
      Behavior on color { ColorAnimation { duration: 120 } }
    }
    Column {
      visible: bt.tall
      anchors.centerIn: parent; spacing: 4
      MIcon { anchors.horizontalCenter: parent.horizontalCenter; icon: bt.icon; size: 20; color: bm.containsMouse ? r.accInk : (bt.danger ? bt.bc : r.ink) }
      Text { anchors.horizontalCenter: parent.horizontalCenter; text: r.up(bt.text); font.family: r.lk.font; font.pixelSize: r.px - 3; color: bm.containsMouse ? r.accInk : r.ink }
    }
    Row {
      id: bRow
      visible: !bt.tall
      anchors.centerIn: parent; spacing: 6
      MIcon { visible: bt.icon !== "" && r.lk.icons !== false && bt.v !== "text"; anchors.verticalCenter: parent.verticalCenter; icon: bt.icon; size: r.px + 2; color: bm.containsMouse || bt.v === "solid" ? r.accInk : (bt.danger ? bt.bc : r.ink) }
      Text {
        id: bTxt
        anchors.verticalCenter: parent.verticalCenter
        text: bt.v === "text" ? "[ " + r.up(bt.text) + " ]" : r.up(bt.text)
        font.family: r.lk.font; font.pixelSize: r.px - 1; font.weight: Font.Bold; font.italic: bt.v === "ribbon"
        color: bt.v === "text" ? (bm.containsMouse ? r.ink : (bt.danger ? bt.bc : r.acc)) : (bm.containsMouse || bt.v === "solid" ? r.accInk : (bt.danger ? bt.bc : r.ink))
      }
    }
    MouseArea { id: bm; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: bt.click() }
  }
}
