import QtQuick

// Météo animée par-dessus le fond : pluie (traits), neige (flocons), nuages qui passent,
// orage (éclairs). Le code WMO vient de la météo copiée par le bureau.
Canvas {
  id: fx
  property int code: -1
  property color tint: "#ffffff"
  readonly property string kind: code < 0 ? "" : code >= 95 ? "storm" : (code >= 71 && code <= 77) || code === 85 || code === 86 ? "snow"
                                   : code >= 51 ? "rain" : code >= 2 ? "cloud" : ""
  property var parts: []
  property real flash: 0
  visible: kind !== ""
  function reset() {
    var a = [], n = kind === "cloud" ? 7 : kind === "snow" ? 160 : 220
    for (var i = 0; i < n; i++) a.push({ x: Math.random(), y: Math.random(), s: 0.4 + Math.random() * 0.6, r: Math.random() })
    parts = a
  }
  onKindChanged: reset()
  Component.onCompleted: reset()
  Timer {
    interval: 33; repeat: true; running: fx.visible
    onTriggered: {
      var k = fx.kind
      for (var i = 0; i < fx.parts.length; i++) {
        var p = fx.parts[i]
        if (k === "rain" || k === "storm") { p.y += 0.022 * p.s; p.x -= 0.004 * p.s }
        else if (k === "snow") { p.y += 0.0025 * p.s; p.x += Math.sin((p.y + p.r) * 12) * 0.0008 }
        else { p.x += 0.00025 * p.s }
        if (p.y > 1.05) { p.y = -0.05; p.x = Math.random() }
        if (p.x < -0.3) p.x = 1.05
        if (p.x > 1.3) p.x = -0.3
      }
      if (k === "storm" && Math.random() < 0.006) fx.flash = 1
      fx.flash = Math.max(0, fx.flash - 0.08)
      fx.requestPaint()
    }
  }
  onPaint: {
    var c = getContext("2d"), w = width, h = height, k = kind
    c.reset()
    c.strokeStyle = tint; c.fillStyle = tint
    for (var i = 0; i < parts.length; i++) {
      var p = parts[i]
      if (k === "rain" || k === "storm") {
        c.globalAlpha = 0.18 + 0.3 * p.s; c.lineWidth = 1
        c.beginPath(); c.moveTo(p.x * w, p.y * h); c.lineTo(p.x * w - 4 * p.s, p.y * h + 22 * p.s); c.stroke()
      } else if (k === "snow") {
        c.globalAlpha = 0.35 + 0.5 * p.s
        c.beginPath(); c.arc(p.x * w, p.y * h, 1 + 2.2 * p.s, 0, 6.283); c.fill()
      } else {
        c.globalAlpha = 0.05 + 0.05 * p.s
        var cx = p.x * w, cy = (0.08 + p.r * 0.35) * h, r = (0.12 + p.s * 0.12) * w
        for (var j = 0; j < 4; j++) { c.beginPath(); c.ellipse(cx + j * r * 0.35 - r / 2, cy - r * 0.12 * (j % 2), r, r * 0.32); c.fill() }
      }
    }
    if (flash > 0) { c.globalAlpha = flash * 0.35; c.fillStyle = "#ffffff"; c.fillRect(0, 0, w, h) }
  }
}
