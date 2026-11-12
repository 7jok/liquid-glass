import QtQuick

// Liste défilante des lignes d'une page, regroupées par titre (type h).
//   mode  plain : lignes à la suite, séparateur fin
//         boxed : chaque groupe dans une boîte arrondie (GNOME, Plasma, Cinnamon…)
//         tiles : chaque ligne dans sa tuile, tuiles en grille (Sombre, Jouet…)
//         band  : chaque ligne sur une bande penchée (Rubans)
//         cards : chaque groupe sur sa carte, cartes l'une sous l'autre
// Les couleurs des boîtes : boxColor, boxBorder, boxRadius, sepColor ; tileW la
// largeur des tuiles ; hard le décalage d'une ombre dure.
Flickable {
  id: fl
  property var core: null
  property var look: ({})
  property string page: core ? core.page : "home"
  property string mode: "plain"
  property color boxColor: "transparent"
  property color boxBorder: "transparent"
  property int boxBorderW: 0
  property int boxRadius: 10
  property int boxPad: 14
  property color sepColor: Qt.rgba(1, 1, 1, 0.08)
  property int tileW: 220
  property int gap: 10
  property int hard: 0
  property color hardColor: "black"
  property color bandColor: Qt.rgba(1, 1, 1, 0.06)
  property color bandAlt: Qt.rgba(1, 1, 1, 0.1)
  property real bandSkew: -0.3
  property int bottomPad: 20

  clip: true
  contentWidth: width
  contentHeight: col.implicitHeight + bottomPad
  boundsBehavior: Flickable.StopAtBounds
  onPageChanged: contentY = 0

  // [{ title, rows }] : un groupe par titre ; le premier peut ne pas en avoir.
  readonly property var groups: {
    var out = [], cur = { title: "", rows: [] }, rs = core ? core.rows(page) : []
    for (var i = 0; i < rs.length; i++) {
      if (rs[i][0] === "h") { if (cur.rows.length || cur.title) out.push(cur); cur = { title: rs[i][2], rows: [] } }
      else cur.rows.push(rs[i])
    }
    if (cur.rows.length || cur.title) out.push(cur)
    return out
  }

  Column {
    id: col
    width: fl.width
    spacing: fl.mode === "plain" ? 4 : fl.gap + 4
    Repeater {
      model: fl.groups
      delegate: Column {
        id: grp
        required property var modelData
        required property int index
        width: col.width
        spacing: 6
        SetRow {
          visible: grp.modelData.title !== ""
          width: parent.width
          core: fl.core; look: fl.look
          row: ["h", "", grp.modelData.title]
        }
        Item {
          width: parent.width
          height: fl.mode === "tiles" ? tileFlow.implicitHeight : boxCol.implicitHeight + (fl.mode === "boxed" || fl.mode === "cards" ? fl.boxPad * 2 - 8 : 0)
          // ombre dure + boîte
          Rectangle {
            visible: (fl.mode === "boxed" || fl.mode === "cards") && fl.hard > 0
            x: fl.hard; y: fl.hard; width: parent.width; height: parent.height
            radius: fl.boxRadius; color: fl.hardColor
          }
          Rectangle {
            visible: fl.mode === "boxed" || fl.mode === "cards"
            anchors.fill: parent
            radius: fl.boxRadius; color: fl.boxColor
            border.width: fl.boxBorderW; border.color: fl.boxBorder
          }
          Column {
            id: boxCol
            visible: fl.mode !== "tiles"
            readonly property int pad: fl.mode === "boxed" || fl.mode === "cards" ? fl.boxPad : (fl.mode === "band" ? 22 : 0)
            x: pad; y: fl.mode === "boxed" || fl.mode === "cards" ? fl.boxPad - 4 : 0
            width: parent.width - pad * 2
            spacing: fl.mode === "band" ? 6 : 0
            Repeater {
              model: fl.mode !== "tiles" ? grp.modelData.rows : []
              delegate: Item {
                id: rw
                required property var modelData
                required property int index
                width: boxCol.width
                height: sr.height
                // bande penchée (Rubans)
                Rectangle {
                  visible: fl.mode === "band" && sr.controlRow
                  x: -14; width: parent.width + 28; height: parent.height
                  color: rw.index % 2 ? fl.bandAlt : fl.bandColor
                  transform: Matrix4x4 { matrix: Qt.matrix4x4(1, fl.bandSkew, 0, -fl.bandSkew * rw.height / 2, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1) }
                }
                Rectangle {
                  visible: fl.mode !== "band" && rw.index > 0 && sr.controlRow
                  width: parent.width; height: 1; color: fl.sepColor
                }
                SetRow { id: sr; x: fl.mode === "band" ? 6 : 0; width: parent.width - x * 2; core: fl.core; look: fl.look; row: rw.modelData }
              }
            }
          }
          Flow {
            id: tileFlow
            visible: fl.mode === "tiles"
            width: parent.width
            spacing: fl.gap
            Repeater {
              model: fl.mode === "tiles" ? grp.modelData.rows : []
              delegate: Item {
                id: tl
                required property var modelData
                readonly property bool wide: !tr.controlRow || modelData[0] === "S" || modelData[0] === "s" || modelData[0] === "f" || modelData[0] === "c"
                readonly property int cols: Math.max(1, Math.floor((tileFlow.width + fl.gap) / (fl.tileW + fl.gap)))
                readonly property real unit: (tileFlow.width - (cols - 1) * fl.gap) / cols
                width: wide ? tileFlow.width : unit
                height: tr.height + 24
                Rectangle { visible: fl.hard > 0; x: fl.hard; y: fl.hard; width: parent.width; height: parent.height; radius: fl.boxRadius; color: fl.hardColor }
                Rectangle { anchors.fill: parent; radius: fl.boxRadius; color: fl.boxColor; border.width: fl.boxBorderW; border.color: fl.boxBorder }
                SetRow { id: tr; x: 12; y: 12; width: parent.width - 24; core: fl.core; look: fl.look; row: tl.modelData }
              }
            }
          }
        }
      }
    }
  }
}
