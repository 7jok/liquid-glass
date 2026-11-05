.pragma library

// Calculatrice de Spotlight : analyseur récursif descendant (pas d'eval).
// Gère + - * / % ^, parenthèses, virgule décimale française, constantes pi/e
// et fonctions sqrt, abs, sin, cos, tan, asin, acos, atan, ln, log, exp, round,
// floor, ceil. Renvoie null si la saisie n'est pas une expression complète.

var FUNCS = {
  sqrt: Math.sqrt, abs: Math.abs, sin: Math.sin, cos: Math.cos, tan: Math.tan,
  asin: Math.asin, acos: Math.acos, atan: Math.atan, ln: Math.log,
  log: function(x) { return Math.log(x) / Math.LN10 }, exp: Math.exp,
  round: Math.round, floor: Math.floor, ceil: Math.ceil
}
var CONSTS = { pi: Math.PI, "π": Math.PI, e: Math.E }

function tokenize(src) {
  var s = String(src).replace(/×/g, "*").replace(/÷/g, "/").replace(/−/g, "-")
  var out = []
  var i = 0
  while (i < s.length) {
    var c = s[i]
    if (c === " ") { i++; continue }
    var num = /^(\d+([.,]\d*)?|[.,]\d+)/.exec(s.slice(i))
    if (num) { out.push({ t: "n", v: parseFloat(num[0].replace(",", ".")) }); i += num[0].length; continue }
    var id = /^([a-zA-Zπ]+)/.exec(s.slice(i))
    if (id) { out.push({ t: "id", v: id[0].toLowerCase() }); i += id[0].length; continue }
    if ("+-*/%^()".indexOf(c) !== -1) { out.push({ t: c }); i++; continue }
    return null
  }
  return out
}

function evaluate(src) {
  var toks = tokenize(src)
  if (!toks || toks.length === 0) return null
  // Il faut au moins un opérateur ou une fonction : « 42 » seul n'est pas un calcul.
  var hasOp = false
  // Idem pour une constante seule (« e », « pi ») : il faut un opérateur ou une fonction.
  for (var k = 0; k < toks.length; k++) {
    var tt = toks[k].t
    if ((tt !== "n" && tt !== "id" && tt !== "(" && tt !== ")") || (tt === "id" && FUNCS.hasOwnProperty(toks[k].v))) { hasOp = true; break }
  }
  if (!hasOp) return null

  var p = 0
  function peek() { return toks[p] }
  function eat(t) { if (toks[p] && toks[p].t === t) { p++; return true } return false }

  function expr() {
    var v = term()
    while (peek() && (peek().t === "+" || peek().t === "-")) {
      var op = toks[p++].t
      var r = term()
      v = op === "+" ? v + r : v - r
    }
    return v
  }
  function term() {
    var v = unary()
    while (peek() && (peek().t === "*" || peek().t === "/" || peek().t === "%" || peek().t === "(" || peek().t === "id")) {
      var t = peek().t
      if (t === "(" || t === "id") { v = v * unary(); continue }   // multiplication implicite : 2pi, 3(4+1)
      p++
      var r = unary()
      v = t === "*" ? v * r : (t === "/" ? v / r : v % r)
    }
    return v
  }
  function unary() {
    if (eat("-")) return -unary()
    if (eat("+")) return unary()
    return power()
  }
  function power() {
    var b = atom()
    if (eat("^")) return Math.pow(b, unary())
    return b
  }
  function atom() {
    var tk = toks[p]
    if (!tk) throw "eof"
    if (tk.t === "n") { p++; return tk.v }
    if (tk.t === "(") {
      p++
      var v = expr()
      if (!eat(")")) throw "paren"
      return v
    }
    if (tk.t === "id") {
      p++
      if (CONSTS.hasOwnProperty(tk.v)) return CONSTS[tk.v]
      if (FUNCS.hasOwnProperty(tk.v)) {
        if (!eat("(")) throw "fn"
        var a = expr()
        if (!eat(")")) throw "paren"
        return FUNCS[tk.v](a)
      }
      throw "id"
    }
    throw "tok"
  }

  try {
    var v = expr()
    if (p !== toks.length || !isFinite(v)) return null
    return v
  } catch (e) {
    return null
  }
}

// Format lisible : 12 chiffres significatifs, virgule française, espaces fines.
function format(v) {
  if (v === null || v === undefined) return ""
  var r = Math.abs(v) >= 1e15 || (Math.abs(v) < 1e-6 && v !== 0) ? v.toExponential(6) : String(parseFloat(v.toPrecision(12)))
  var parts = r.split(".")
  if (r.indexOf("e") === -1) parts[0] = parts[0].replace(/\B(?=(\d{3})+(?!\d))/g, " ")
  return parts.join(",")
}

// Valeur brute (point décimal) pour le presse-papiers.
function plain(v) {
  return String(parseFloat(v.toPrecision(12)))
}
