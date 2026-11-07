import QtQuick
import Quickshell
import Quickshell.Io

// ⌃⌘M : rice. Une page = un bureau de 1 à 13 terminaux. On choisit la scène de chaque
// terminal, le temps entre deux scènes, le minuteur, la police et l'opacité.
EspacePanel {
  id: p
  cardW: 900; cardH: 636

  property var d: null          // état donné par `liquid-glass rice dump`
  property int sel: 0           // terminal sélectionné dans l'aperçu
  readonly property var page: d ? d.pages[d.page] : null
  readonly property var cells: d && page ? d.layouts[String(page.panes.length)] : []
  readonly property var others: {
    if (!d) return []
    var out = [], rec = d.recommended
    for (var k in d.scenes) if (rec.indexOf(k) < 0) out.push(k)
    return out
  }
  readonly property int rad: Math.min(s.radius, 12)

  Process {
    id: load
    running: true
    command: ["liquid-glass", "rice", "dump"]
    stdout: StdioCollector {
      onStreamFinished: {
        try { p.d = JSON.parse(text) } catch (e) { console.warn("rice:", e) }
      }
    }
  }
  function touch() { d = Object.assign({}, d); saveTimer.restart() }
  Timer { id: saveTimer; interval: 250; onTriggered: p.save() }
  function save() { Quickshell.execDetached(["liquid-glass", "rice", "save", JSON.stringify(d)]) }
  function setCount(n) {
    var l = page.panes, r = d.recommended
    n = Math.max(1, Math.min(13, n))
    while (l.length > n) l.pop()
    while (l.length < n) l.push(r[l.length % r.length])
    sel = Math.min(sel, n - 1)
    touch()
  }
  function setScene(k) { page.panes[sel] = k; touch() }
  function addPage() {
    d.pages.push({ name: "Page " + (d.pages.length + 1), panes: d.recommended.slice(0, 4), cycle: 0 })
    d.page = d.pages.length - 1; sel = 0; touch()
  }
  function dropPage() {
    if (d.pages.length < 2) return
    Quickshell.execDetached(["liquid-glass", "rice", "stop", String(d.page)])
    d.pages.splice(d.page, 1); d.page = Math.max(0, d.page - 1); sel = 0; touch()
  }
  function launch() {
    saveTimer.stop(); save()
    var n = d.page
    s.closeAll()
    Quickshell.execDetached(["sh", "-c", "sleep 0.3; liquid-glass rice launch " + n])
  }

  Column {
    x: 22; y: 16; spacing: 1
    Text { text: "Rice · " + (p.d ? p.d.label : ""); font.family: p.font; font.pixelSize: 17; font.weight: Font.Bold; color: p.ink }
    Text { text: "Une page = un bureau de terminaux, à ton goût"; font.family: p.font; font.pixelSize: 11; color: p.sub }
  }

  // Pages
  Row {
    x: 22; y: 62; spacing: 6
    Repeater {
      model: p.d ? p.d.pages : []
      delegate: Rectangle {
        id: tab
        required property var modelData
        required property int index
        readonly property bool on: p.d.page === index
        width: tabRow.implicitWidth + 22; height: 30; radius: p.rad
        color: on ? p.s.primary : p.s.alpha(p.ink, 0.08)
        Row {
          id: tabRow
          anchors.centerIn: parent; spacing: 6
          Text { text: tab.modelData.name; font.family: p.font; font.pixelSize: 12; font.weight: Font.Bold; color: tab.on ? p.s.colOnPrimary : p.ink }
          Text { text: tab.modelData.panes.length; font.family: p.font; font.pixelSize: 11; color: tab.on ? p.s.colOnPrimary : p.sub }
        }
        MouseArea { anchors.fill: parent; onClicked: { p.d.page = tab.index; p.sel = 0; p.touch() } }
      }
    }
    Tool { icon: "add"; onClicked: p.addPage() }
    Tool { icon: "delete"; visible: !!p.d && p.d.pages.length > 1; onClicked: p.dropPage() }
  }

  // Aperçu : la vraie disposition. Un clic choisit le terminal à changer.
  Item {
    id: prev
    x: 22; y: 104; width: 420; height: 236
    Repeater {
      model: p.cells
      delegate: Rectangle {
        id: cell
        required property var modelData
        required property int index
        readonly property bool on: p.sel === index
        x: modelData[0] * prev.width + 2; y: modelData[1] * prev.height + 2
        width: modelData[2] * prev.width - 4; height: modelData[3] * prev.height - 4
        radius: Math.min(p.rad, 8)
        color: on ? p.s.primary : p.s.alpha(p.ink, 0.08)
        border.width: on ? 0 : 1; border.color: p.s.alpha(p.ink, 0.1)
        Text {
          anchors.fill: parent; anchors.margins: 3
          horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
          wrapMode: Text.WordWrap; elide: Text.ElideRight
          text: p.d && p.page ? String(p.d.scenes[p.page.panes[cell.index]] || "") : ""
          font.family: p.font; font.pixelSize: 11; font.weight: cell.on ? Font.Bold : Font.Normal
          color: cell.on ? p.s.colOnPrimary : p.ink
        }
        MouseArea { anchors.fill: parent; onClicked: p.sel = cell.index }
      }
    }
  }
  Row {
    x: 22; y: 350; spacing: 8
    Text { anchors.verticalCenter: parent.verticalCenter; text: "Terminaux"; font.family: p.font; font.pixelSize: 12; color: p.sub }
    Tool { icon: "remove"; onClicked: p.setCount(p.page.panes.length - 1) }
    Text {
      anchors.verticalCenter: parent.verticalCenter; width: 26; horizontalAlignment: Text.AlignHCenter
      text: p.page ? p.page.panes.length : ""
      font.family: p.font; font.pixelSize: 16; font.weight: Font.Bold; color: p.ink
    }
    Tool { icon: "add"; onClicked: p.setCount(p.page.panes.length + 1) }
    Repeater {
      model: [2, 5, 9, 13]
      delegate: Chip {
        required property int modelData
        label: String(modelData)
        on: !!p.page && p.page.panes.length === modelData
        onClicked: p.setCount(modelData)
      }
    }
  }

  // Scènes
  Flickable {
    x: 464; y: 104; width: parent.width - 486; height: 280
    contentHeight: scenes.implicitHeight; clip: true
    boundsBehavior: Flickable.StopAtBounds
    Column {
      id: scenes
      width: parent.width; spacing: 7
      Text { text: "Pour ce thème"; font.family: p.font; font.pixelSize: 12; font.weight: Font.Bold; color: p.sub }
      Flow {
        width: parent.width; spacing: 6
        Repeater {
          model: p.d ? p.d.recommended : []
          delegate: Chip {
            required property string modelData
            label: String(p.d.scenes[modelData])
            on: !!p.page && p.page.panes[p.sel] === modelData
            onClicked: p.setScene(modelData)
          }
        }
      }
      Text { text: "Toutes les autres"; font.family: p.font; font.pixelSize: 12; font.weight: Font.Bold; color: p.sub }
      Flow {
        width: parent.width; spacing: 6
        Repeater {
          model: p.others
          delegate: Chip {
            required property string modelData
            label: String(p.d.scenes[modelData])
            on: !!p.page && p.page.panes[p.sel] === modelData
            onClicked: p.setScene(modelData)
          }
        }
      }
    }
  }

  Rectangle { x: 22; y: 392; width: parent.width - 44; height: 1; color: p.s.alpha(p.ink, 0.1) }

  // Réglages de la page
  Column {
    x: 22; y: 402; width: parent.width - 44; spacing: 8
    Row {
      spacing: 8
      Label_ { text: "Scène suivante" }
      Repeater {
        model: [[0, "Jamais"], [15, "15 s"], [30, "30 s"], [60, "1 min"], [120, "2 min"], [300, "5 min"]]
        delegate: Chip {
          required property var modelData
          label: modelData[1]
          on: !!p.page && p.page.cycle === modelData[0]
          onClicked: { p.page.cycle = modelData[0]; p.touch() }
        }
      }
    }
    Row {
      spacing: 8
      Label_ { text: "Minuteur" }
      Tool { icon: "remove"; onClicked: { p.d.minutes = Math.max(1, p.d.minutes - (p.d.minutes > 5 ? 5 : 1)); p.touch() } }
      Text {
        anchors.verticalCenter: parent.verticalCenter; width: 56; horizontalAlignment: Text.AlignHCenter
        text: p.d ? p.d.minutes + " min" : ""
        font.family: p.font; font.pixelSize: 13; font.weight: Font.Bold; color: p.ink
      }
      Tool { icon: "add"; onClicked: { p.d.minutes = Math.min(180, p.d.minutes + (p.d.minutes >= 5 ? 5 : 1)); p.touch() } }
      Item { width: 26; height: 1 }
      Text { anchors.verticalCenter: parent.verticalCenter; text: "Opacité"; font.family: p.font; font.pixelSize: 12; color: p.sub }
      Repeater {
        model: [[1, "100"], [0.9, "90"], [0.8, "80"], [0.7, "70"], [0.55, "55"]]
        delegate: Chip {
          required property var modelData
          label: modelData[1]
          on: !!p.d && Math.abs(p.d.alpha - modelData[0]) < 0.051
          onClicked: { p.d.alpha = modelData[0]; p.touch() }
        }
      }
    }
    Row {
      spacing: 8
      Label_ { text: "Police" }
      Flow {
        width: p.card.width - 44 - 118; spacing: 6
        Repeater {
          model: p.d ? p.d.fonts : []
          delegate: Chip {
            required property string modelData
            label: modelData.replace(" Nerd Font", "")
            family: modelData
            on: !!p.d && p.d.font === modelData
            onClicked: { p.d.font = modelData; p.touch() }
          }
        }
      }
    }
  }

  Row {
    anchors.right: parent.right; anchors.rightMargin: 22
    anchors.bottom: parent.bottom; anchors.bottomMargin: 14
    spacing: 8
    Chip { label: "Par défaut"; onClicked: { Quickshell.execDetached(["sh", "-c", "liquid-glass rice reset"]); reload.restart() } }
    Chip { label: "Fermer les terminaux"; onClicked: Quickshell.execDetached(["liquid-glass", "rice", "stop"]) }
    Rectangle {
      width: 150; height: 32; radius: p.rad; color: lma.containsMouse ? p.s.alpha(p.s.primary, 0.85) : p.s.primary
      Text { anchors.centerIn: parent; text: "Lancer la page"; font.family: p.font; font.pixelSize: 13; font.weight: Font.Bold; color: p.s.colOnPrimary }
      MouseArea { id: lma; anchors.fill: parent; hoverEnabled: true; onClicked: p.launch() }
    }
  }
  Timer { id: reload; interval: 250; onTriggered: { load.running = false; load.running = true; p.sel = 0 } }

  component Label_: Text {
    width: 110
    font.family: p.font; font.pixelSize: 12; color: p.sub
    height: 28; verticalAlignment: Text.AlignVCenter
  }
  component Tool: Rectangle {
    id: tl
    property string icon: ""
    signal clicked()
    width: 28; height: 28; radius: p.rad
    color: tma.containsMouse ? p.s.alpha(p.ink, 0.18) : p.s.alpha(p.ink, 0.08)
    MIcon { anchors.centerIn: parent; icon: tl.icon; size: 16; color: p.ink }
    MouseArea { id: tma; anchors.fill: parent; hoverEnabled: true; onClicked: tl.clicked() }
  }
  component Chip: Rectangle {
    id: chip
    property string label: ""
    property string family: ""
    property bool on: false
    signal clicked()
    width: chipText.implicitWidth + 18; height: 28; radius: p.rad
    color: on ? p.s.primary : (cma.containsMouse ? p.s.alpha(p.ink, 0.16) : p.s.alpha(p.ink, 0.08))
    Text {
      id: chipText
      anchors.centerIn: parent; text: chip.label
      font.family: chip.family || p.font; font.pixelSize: 12; font.weight: chip.on ? Font.Bold : Font.Normal
      color: chip.on ? p.s.colOnPrimary : p.ink
    }
    MouseArea { id: cma; anchors.fill: parent; hoverEnabled: true; onClicked: chip.clicked() }
  }
}
