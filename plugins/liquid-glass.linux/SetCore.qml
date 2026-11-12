import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Bluetooth
import Quickshell.Services.Pipewire
import Quickshell.Services.UPower
import "SetData.js" as SD
import "T.js" as T

// Moteur commun des réglages de chaque thème (Set<Thème>.qml) : pages, lignes,
// valeurs, état du système et actions. Chaque thème ne fait que l'habiller.
Item {
  id: core
  property var service: null
  readonly property var s: service
  readonly property string st: s ? s.style : "blanc"

  // ---------------------------------------------------------------- pages
  readonly property var pages: SD.pages(st)
  property string page: "home"
  readonly property int pageIndex: { for (var i = 0; i < pages.length; i++) if (pages[i][0] === page) return i; return 0 }
  readonly property var pageInfo: pages[pageIndex]
  function rows(p) { return SD.pageRows(st, p || page) }
  function step(n) { page = pages[(pageIndex + n + pages.length) % pages.length][0] }
  function styleName(x) { return SD.name(x || st) }

  // ---------------------------------------------------------------- valeurs
  // Clé du style (« ruban_date ») : linux.ruban_date ; clé commune (« widgets ») :
  // gardée pour ce thème seulement, linux.<style>__widgets (comme dans les Réglages).
  function fullKey(k) { return k.indexOf(st + "_") === 0 ? k : st + "__" + k }
  property var pending: ({})      // valeurs posées à l'instant, avant que config.json soit relu
  function val(k, d) {
    var fk = fullKey(k)
    if (pending.hasOwnProperty(fk)) return pending[fk]
    if (k === "radius" && d === undefined) return s.radius
    return s.opt(k, d)
  }
  function set(k, v) {
    var fk = fullKey(k), p = Object.assign({}, pending)
    p[fk] = v
    pending = p
    s.setOpt(fk, v)
    clearPending.restart()
  }
  Timer { id: clearPending; interval: 2500; onTriggered: core.pending = ({}) }
  function asBool(v, d) { return v === undefined || v === null ? d : (v === true || v === "true" || v === 1 || v === "1") }
  function fmt(f, v) {
    return f === "pct" ? "+" + Math.round((v - 1) * 100) + " %" : f === "op" ? Math.round(v * 100) + " %"
         : f === "px" ? Math.round(v) + " px" : f === "n" ? String(Math.round(v)) : "×" + Number(v).toFixed(2)
  }
  function run(cmd) { Quickshell.execDetached(cmd) }
  function close() { s.closeAll(); s.menuOpen = false }
  function act(cmd) { close(); Quickshell.execDetached(["sh", "-c", "sleep 0.25; " + cmd]) }

  // ---------------------------------------------------------------- système
  PwObjectTracker { objects: [Pipewire.defaultAudioSink, Pipewire.defaultAudioSource] }
  readonly property var sink: Pipewire.defaultAudioSink
  readonly property var source: Pipewire.defaultAudioSource
  readonly property var bt: Bluetooth.defaultAdapter
  readonly property var btDevices: Bluetooth.devices ? Bluetooth.devices.values.filter(function(d) { return d.paired || d.connected }) : []
  readonly property var sinks: (Pipewire.nodes ? Pipewire.nodes.values : []).filter(function(n) { return n.isSink && !n.isStream && n.audio })
  property bool nightOn: false
  property bool dndOn: false
  Process {
    running: true
    command: ["sh", "-c", "pgrep -x hyprsunset >/dev/null && echo n; makoctl mode 2>/dev/null | grep -q do-not-disturb && echo d; true"]
    stdout: StdioCollector { onStreamFinished: { core.nightOn = text.indexOf("n") >= 0; core.dndOn = text.indexOf("d") >= 0 } }
  }
  Component.onCompleted: { s.readBrightness(); s.scanWifi() }

  // Interrupteurs système (type T) : wifi bt night dnd mute micmute.
  function sysOn(id) {
    switch (id) {
    case "wifi": return s.wifiOn
    case "bt": return !!bt && bt.enabled
    case "night": return nightOn
    case "dnd": return dndOn
    case "mute": return !!sink && !!sink.audio && sink.audio.muted
    case "micmute": return !!source && !!source.audio && source.audio.muted
    }
    return false
  }
  function sysToggle(id) {
    switch (id) {
    case "wifi": s.setWifi(!s.wifiOn); break
    case "bt": if (bt) bt.enabled = !bt.enabled; break
    case "night": nightOn = !nightOn; run(["omarchy-toggle-nightlight"]); break
    case "dnd": dndOn = !dndOn; run(["omarchy-toggle-notification-silencing"]); break
    case "mute": if (sink && sink.audio) sink.audio.muted = !sink.audio.muted; break
    case "micmute": if (source && source.audio) source.audio.muted = !source.audio.muted; break
    }
  }
  function sysIcon(id) {
    var on = sysOn(id)
    return ({ wifi: on ? "wifi" : "wifi_off", bt: on ? "bluetooth" : "bluetooth_disabled", night: "nightlight", dnd: "do_not_disturb_on",
              mute: on ? "volume_off" : "volume_up", micmute: on ? "mic_off" : "mic" })[id] || "toggle_on"
  }
  function sysSub(id) {
    switch (id) {
    case "wifi": { var a = s.wifiList.filter(function(w) { return w.active }); return s.wifiOn ? (a.length ? a[0].ssid : T.t("Pas connecté")) : T.t("Coupé") }
    case "bt": { var c = btDevices.filter(function(d) { return d.connected }); return bt && bt.enabled ? (c.length ? c[0].name : T.t("Allumé")) : T.t("Coupé") }
    }
    return ""
  }
  // Curseurs système (type S) : vol mic bright, de 0 à 1 ; -1 = absent.
  function sysVal(id) {
    switch (id) {
    case "vol": return sink && sink.audio ? Math.min(1, sink.audio.volume) : -1
    case "mic": return source && source.audio ? Math.min(1, source.audio.volume) : -1
    case "bright": return s.brightness
    }
    return -1
  }
  function sysSet(id, v) {
    v = Math.max(0, Math.min(1, v))
    if (id === "vol" && sink && sink.audio) { sink.audio.volume = v; if (sink.audio.muted && v > 0) sink.audio.muted = false }
    else if (id === "mic" && source && source.audio) source.audio.volume = v
    else if (id === "bright") s.setBrightness(v)
  }
  function sysSliderIcon(id) { return ({ vol: "volume_up", mic: "mic", bright: "light_mode" })[id] || "tune" }

  // Bluetooth, sorties son.
  function btToggle(d) { if (d.connected) d.disconnect(); else d.connect() }
  function btIcon(d) {
    var i = String(d.icon || "")
    return i.indexOf("headset") >= 0 || i.indexOf("headphone") >= 0 || i.indexOf("audio") >= 0 ? "headphones"
         : i.indexOf("mouse") >= 0 ? "mouse" : i.indexOf("keyboard") >= 0 ? "keyboard" : i.indexOf("phone") >= 0 ? "smartphone" : "bluetooth"
  }
  function sinkName(n) { return String(n.description || n.nickname || n.name || "") }
  function setSink(n) { Pipewire.preferredDefaultAudioSink = n }

  // Batterie et énergie.
  readonly property var battery: UPower.displayDevice
  readonly property int batteryPct: s.batteryPct
  readonly property bool charging: s.charging
  readonly property string batteryText: batteryPct < 0 ? T.t("Sur secteur") : batteryPct + " %" + (charging ? T.t(" · en charge") : "")
  readonly property string batteryTime: {
    if (batteryPct < 0 || !battery) return ""
    var t = charging ? battery.timeToFull : battery.timeToEmpty
    if (!t || t <= 0) return ""
    var h = Math.floor(t / 3600), m = Math.round((t % 3600) / 60)
    return (charging ? T.t("plein dans ") : T.t("reste ")) + (h > 0 ? h + " h " : "") + m + " min"
  }
  readonly property var profiles: [["saver", T.t("Économie"), "eco"], ["balanced", T.t("Équilibré"), "balance"], ["perf", T.t("Performance"), "bolt"]]
  readonly property string profile: PowerProfiles.profile === PowerProfile.PowerSaver ? "saver" : (PowerProfiles.profile === PowerProfile.Performance ? "perf" : "balanced")
  function setProfile(p) { PowerProfiles.profile = p === "saver" ? PowerProfile.PowerSaver : (p === "perf" ? PowerProfile.Performance : PowerProfile.Balanced) }
  readonly property var powerActs: [["lock", "lock", T.t("Verrouiller")], ["suspend", "bedtime", T.t("Veille")], ["logout", "logout", T.t("Quitter")],
                                    ["reboot", "restart_alt", T.t("Redémarrer")], ["poweroff", "power_settings_new", T.t("Éteindre")]]
  function power(p) { s.power(p) }

  // Teintes et couleurs du style.
  readonly property var tones: s.toneDefs[st] ? s.toneDefs[st][1] : []
  readonly property string tone: tones.length ? String(s.opt(s.toneDefs[st][0], tones[0][0])) : ""
  function setTone(v) { run(["liquid-glass", "profile", st + ":" + v]) }
  readonly property var colorModes: [["theme", "palette", T.t("Du style")], ["fond", "wallpaper", T.t("Du fond")], ["perso", "colorize", T.t("Perso")]]
  function setColors(m) {
    s.setOpt(st + "_colors", m)
    if (m === "perso" && s.accentHex === "") s.setOpt(st + "_accent", s.accentSwatches[7])
  }
  function setAccent(hex) { s.setOpt(st + "_accent", hex) }
  function hueHex(h) {
    var c = Qt.hsla(Math.max(0, Math.min(0.999, h)), 0.72, s.darkSkin ? 0.66 : 0.48, 1)
    return "#" + [c.r, c.g, c.b].map(function(v) { var x = Math.round(v * 255).toString(16); return x.length < 2 ? "0" + x : x }).join("")
  }

  // Bureaux (sélecteur de style) : [id, nom].
  readonly property var styleList: ["blanc", "sombre", "jouet", "violet", "expressive", "gouts", "windows", "mono", "foret", "ruban",
    "espace", "cosmos", "ile", "hud", "infini", "debian", "fedora", "mint", "kali", "arch"].map(function(x) { return [x, SD.name(x)] })
  function pickStyle(x) { s.pickStyle(x) }

  // Fonds d'écran.
  property int liveCount: 0
  Process {
    running: true
    command: ["sh", "-c", "ls \"$HOME\"/.local/share/liquid-glass/live/*.mp4 2>/dev/null | wc -l"]
    stdout: StdioCollector { onStreamFinished: core.liveCount = parseInt(text) || 0 }
  }
  readonly property string bgName: String(s.bgPath || "").split("/").pop().replace(/\.[^.]+$/, "")
  function walls() { close(); s.wallsOpen = true }
  function nextWall() { run(["omarchy-theme-bg-next"]) }
  function randomLive() {
    run(["sh", "-c", "f=$(ls \"$HOME\"/.local/share/liquid-glass/live/*.mp4 2>/dev/null | shuf -n1); [ -n \"$f\" ] && omarchy-theme-bg-set \"$f\""])
  }

  // Raccourcis : [icône, nom, commande ou @action].
  readonly property var acts: [["screenshot_region", T.t("Capture"), "omarchy-capture-screenshot"],
    ["videocam", T.t("Vidéo"), "omarchy-capture-screenrecording"], ["wallpaper", T.t("Fonds"), "@walls"],
    ["colorize", T.t("Pipette"), "hyprpicker -a"], ["terminal", T.t("Terminal"), "uwsm-app -- xdg-terminal-exec"],
    ["folder", T.t("Fichiers"), "uwsm-app -- nautilus --new-window"], ["dashboard_customize", T.t("Bureaux"), "liquid-glass profile pick"],
    ["keyboard", T.t("Raccourcis"), "@keys"]]
  function doAct(c) {
    if (c === "@walls") walls()
    else if (c === "@keys") { close(); s.toggleKeys() }
    else act(c)
  }

  // Fiche de l'ordinateur : [nom, valeur].
  readonly property var infoRows: [[T.t("Nom"), s.info.host || ""], [T.t("Modèle"), s.info.model || ""], [T.t("Processeur"), s.info.cpu || ""],
    [T.t("Mémoire"), (s.info.ram || "?") + " Go"], [T.t("Graphique"), s.info.gpu || ""], [T.t("Disque"), s.info.disk || ""],
    [T.t("Système"), s.info.os || ""], ["Omarchy", s.info.omarchy || ""], ["Noyau", s.info.kernel || ""], [T.t("Allumé depuis"), s.uptimeText]]
    .filter(function(r) { return String(r[1]).trim() !== "" })
}
