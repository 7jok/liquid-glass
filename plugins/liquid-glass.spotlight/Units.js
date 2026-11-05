.pragma library

// Conversions d'unités de Spotlight : « 10 km en miles », « 72 f en c », « 3 go en mo ».
// Renvoie { value, from, to, text } ou null.

// Facteurs vers l'unité de base de chaque famille.
var UNITS = {
  // longueur (m)
  mm: ["len", 0.001, "mm"], cm: ["len", 0.01, "cm"], m: ["len", 1, "m"], km: ["len", 1000, "km"],
  "in": ["len", 0.0254, "po"], po: ["len", 0.0254, "po"], pouce: ["len", 0.0254, "po"], pouces: ["len", 0.0254, "po"],
  ft: ["len", 0.3048, "pi"], pied: ["len", 0.3048, "pi"], pieds: ["len", 0.3048, "pi"], yd: ["len", 0.9144, "yd"],
  mi: ["len", 1609.344, "mi"], mile: ["len", 1609.344, "mi"], miles: ["len", 1609.344, "mi"],
  // masse (kg)
  mg: ["mass", 1e-6, "mg"], g: ["mass", 0.001, "g"], kg: ["mass", 1, "kg"], t: ["mass", 1000, "t"],
  lb: ["mass", 0.45359237, "lb"], lbs: ["mass", 0.45359237, "lb"], livre: ["mass", 0.45359237, "lb"], livres: ["mass", 0.45359237, "lb"],
  oz: ["mass", 0.028349523125, "oz"], once: ["mass", 0.028349523125, "oz"], onces: ["mass", 0.028349523125, "oz"],
  // volume (l)
  ml: ["vol", 0.001, "ml"], cl: ["vol", 0.01, "cl"], dl: ["vol", 0.1, "dl"], l: ["vol", 1, "l"], litre: ["vol", 1, "l"], litres: ["vol", 1, "l"],
  gal: ["vol", 3.785411784, "gal"], gallon: ["vol", 3.785411784, "gal"], gallons: ["vol", 3.785411784, "gal"],
  floz: ["vol", 0.0295735295625, "fl oz"], cup: ["vol", 0.2365882365, "tasse"], tasse: ["vol", 0.2365882365, "tasse"], tasses: ["vol", 0.2365882365, "tasse"],
  // données (octets)
  o: ["data", 1, "o"], b: ["data", 1, "o"], ko: ["data", 1e3, "Ko"], kb: ["data", 1e3, "Ko"], mo: ["data", 1e6, "Mo"], mb: ["data", 1e6, "Mo"],
  go: ["data", 1e9, "Go"], gb: ["data", 1e9, "Go"], to: ["data", 1e12, "To"], tb: ["data", 1e12, "To"],
  kio: ["data", 1024, "Kio"], kib: ["data", 1024, "Kio"], mio: ["data", 1048576, "Mio"], mib: ["data", 1048576, "Mio"],
  gio: ["data", 1073741824, "Gio"], gib: ["data", 1073741824, "Gio"],
  // durée (s)
  ms: ["time", 0.001, "ms"], s: ["time", 1, "s"], sec: ["time", 1, "s"], min: ["time", 60, "min"], h: ["time", 3600, "h"],
  heure: ["time", 3600, "h"], heures: ["time", 3600, "h"], j: ["time", 86400, "j"], jour: ["time", 86400, "j"], jours: ["time", 86400, "j"],
  sem: ["time", 604800, "sem."], semaine: ["time", 604800, "sem."], semaines: ["time", 604800, "sem."],
  // vitesse (m/s)
  "km/h": ["speed", 1 / 3.6, "km/h"], kmh: ["speed", 1 / 3.6, "km/h"], "m/s": ["speed", 1, "m/s"], mph: ["speed", 0.44704, "mph"], noeud: ["speed", 0.514444, "nœuds"], noeuds: ["speed", 0.514444, "nœuds"], kn: ["speed", 0.514444, "nœuds"],
  // surface (m²)
  m2: ["area", 1, "m²"], "m²": ["area", 1, "m²"], km2: ["area", 1e6, "km²"], "km²": ["area", 1e6, "km²"], ha: ["area", 1e4, "ha"],
  acre: ["area", 4046.8564224, "acres"], acres: ["area", 4046.8564224, "acres"], ft2: ["area", 0.09290304, "pi²"]
}
// Températures : conversion affine, traitée à part. (« t » est la tonne, donc pas de raccourci t pour °.)
var TEMPS = { c: "C", "°c": "C", celsius: "C", f: "F", "°f": "F", fahrenheit: "F", k: "K", kelvin: "K" }

function toC(v, u) { return u === "C" ? v : (u === "F" ? (v - 32) * 5 / 9 : v - 273.15) }
function fromC(v, u) { return u === "C" ? v : (u === "F" ? v * 9 / 5 + 32 : v + 273.15) }

function convert(src) {
  var m = /^\s*(-?[\d\s]*[\d][.,]?\d*)\s*([a-zA-Zµ°²\/]+)\s+(?:en|to|in|vers|=|->|→)\s+([a-zA-Zµ°²\/]+)\s*$/.exec(String(src))
  if (!m) return null
  var v = parseFloat(m[1].replace(/\s/g, "").replace(",", "."))
  if (!isFinite(v)) return null
  var a = m[2].toLowerCase(), b = m[3].toLowerCase()
  if (TEMPS.hasOwnProperty(a) && TEMPS.hasOwnProperty(b)) {
    var r = fromC(toC(v, TEMPS[a]), TEMPS[b])
    return { value: r, unit: "°" + TEMPS[b], fromUnit: "°" + TEMPS[a], input: v }
  }
  if (!UNITS.hasOwnProperty(a) || !UNITS.hasOwnProperty(b)) return null
  var ua = UNITS[a], ub = UNITS[b]
  if (ua[0] !== ub[0]) return null
  return { value: v * ua[1] / ub[1], unit: ub[2], fromUnit: ua[2], input: v }
}
