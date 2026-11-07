import QtQuick

// Écran de veille de l'écran verrouillé : un feu en ASCII blanc sur fond noir, le haut
// des flammes bouge. Apparaît après un moment sans rien toucher ; une touche ou la
// souris le fait disparaître.
Item {
  id: s
  property bool shown: false
  property real cellW: 9
  property real cellH: 16
  readonly property int cols: Math.max(10, Math.floor(width / cellW))
  readonly property int rows: Math.max(10, Math.floor(height / cellH))
  readonly property string ramp: " .,:;i1tfLCG08@"
  property var heat: []
  property string frame: ""

  opacity: shown ? 1 : 0
  visible: opacity > 0
  Behavior on opacity { NumberAnimation { duration: 700 } }

  Rectangle { anchors.fill: parent; color: "black" }
  Text {
    anchors.bottom: parent.bottom
    anchors.horizontalCenter: parent.horizontalCenter
    text: s.frame
    color: "white"
    font.family: "JetBrainsMono Nerd Font"; font.pixelSize: s.cellH * 0.86
    lineHeightMode: Text.FixedHeight; lineHeight: s.cellH
    textFormat: Text.PlainText
    renderType: Text.NativeRendering
  }

  function step() {
    var w = cols, h = rows, n = w * h, a = heat
    if (a.length !== n) { a = new Array(n).fill(0) }
    // Rangée du bas : braises qui changent.
    for (var x = 0; x < w; x++) a[(h - 1) * w + x] = Math.random() < 0.62 ? 1 : 0.35 + Math.random() * 0.4
    var cool = 1.15 / Math.max(14, h * 0.55)
    for (var y = 0; y < h - 1; y++) {
      for (var x2 = 0; x2 < w; x2++) {
        var sx = Math.min(w - 1, Math.max(0, x2 + Math.floor(Math.random() * 3) - 1))
        var below = a[(y + 1) * w + sx]
        a[y * w + x2] = Math.max(0, below - Math.random() * cool * 1.6)
      }
    }
    heat = a
    var top = ramp.length - 1, out = []
    for (var y2 = 0; y2 < h; y2++) {
      var line = ""
      for (var x3 = 0; x3 < w; x3++) line += ramp.charAt(Math.min(top, Math.floor(a[y2 * w + x3] * top)))
      out.push(line)
    }
    frame = out.join("\n")
  }
  Timer { interval: 66; repeat: true; running: s.visible; onTriggered: s.step() }
}
