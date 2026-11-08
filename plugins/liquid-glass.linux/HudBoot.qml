import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "T.js" as T

// Style 7JOKS, démarrage : sur fond noir, les lignes du noyau défilent au milieu de
// l'écran, puis le nom 7JOKS grésille et s'encadre, puis « Bienvenue, <nom> ». Un clic
// passe directement au bureau. finished() lance l'arrivée des panneaux.
PanelWindow {
  id: boot
  property var service: null
  readonly property var s: service
  property color acc: "#e6e6e6"
  property string font: "Share Tech Mono"
  property string title: "7JOKS"
  signal finished()

  color: "transparent"
  anchors { top: true; bottom: true; left: true; right: true }
  exclusionMode: ExclusionMode.Ignore
  WlrLayershell.layer: WlrLayer.Overlay
  WlrLayershell.namespace: "liquid-glass-hud-boot"
  WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

  readonly property real k: Math.min(width / 1280, height / 720)
  // 0 : noyau · 1 : logo · 2 : bienvenue · 3 : fondu
  property int step: 0
  property real fade: 1

  Rectangle { anchors.fill: parent; color: "black"; opacity: boot.fade }
  MouseArea { anchors.fill: parent; enabled: boot.step < 3; onClicked: boot.leave() }

  // ------------------------------------------------------------ lignes du noyau
  property var facts: ({ kernel: "", cpu: "", mem: "", host: "", cores: "" })
  Process {
    running: true
    command: ["sh", "-c", "uname -r; grep -m1 'model name' /proc/cpuinfo | cut -d: -f2; awk '/MemTotal/{print $2}' /proc/meminfo; cat /etc/hostname; nproc"]
    stdout: StdioCollector {
      onStreamFinished: {
        var l = text.split("\n")
        boot.facts = { kernel: (l[0] || "").trim(), cpu: (l[1] || "").trim(), mem: (l[2] || "").trim(), host: (l[3] || "").trim(), cores: (l[4] || "").trim() }
      }
    }
  }
  function stamp(i) {
    var t = (i * 0.0137 + (i > 30 ? 0.8 : 0) + (i > 60 ? 1.4 : 0)).toFixed(6)
    return "[" + ("            " + t).slice(-12) + "] "
  }
  readonly property var script: [
    "Linux version " + facts.kernel + " (linux@archlinux) #1 SMP PREEMPT_DYNAMIC",
    "Command line: initrd=\\initramfs-linux.img root=UUID=… rw quiet splash",
    "BIOS-provided physical RAM map:",
    "BIOS-e820: [mem 0x0000000000000000-0x000000000009efff] usable",
    "BIOS-e820: [mem 0x0000000000100000-0x0000000040000000] usable",
    "NX (Execute Disable) protection: active",
    "DMI: " + facts.host,
    "tsc: Detected " + (facts.cpu.match(/@ ?([0-9.]+GHz)/) ? facts.cpu.match(/@ ?([0-9.]+GHz)/)[1] : "2.4 GHz") + " processor",
    "Memory: " + Math.round(Number(facts.mem || 0) / 1024) + "M available",
    "smpboot: CPU0: " + facts.cpu,
    "smp: Brought up 1 node, " + facts.cores + " CPUs",
    "devtmpfs: initialized",
    "clocksource: jiffies: mask: 0xffffffff max_cycles: 0xffffffff",
    "NET: Registered PF_NETLINK/PF_ROUTE protocol family",
    "ACPI: Interpreter enabled",
    "ACPI: PM: (supports S0 S3 S4 S5)",
    "PCI: Using host bridge windows from ACPI",
    "iommu: Default domain type: Translated",
    "SCSI subsystem initialized",
    "usbcore: registered new interface driver usbfs",
    "NetLabel: Initializing",
    "clocksource: Switched to clocksource tsc-early",
    "NET: Registered PF_INET protocol family",
    "TCP established hash table entries: 65536",
    "Unpacking initramfs...",
    "Freeing initrd memory: 18432K",
    "Initialise system trusted keyrings",
    "zbud: loaded",
    "Key type asymmetric registered",
    "io scheduler mq-deadline registered",
    "input: Power Button as /devices/LNXSYSTM:00/input/input0",
    "Serial: 8250/16550 driver, 4 ports, IRQ sharing enabled",
    "rtc_cmos 00:01: RTC can wake from S4",
    "intel_pstate: HWP enabled",
    "NET: Registered PF_INET6 protocol family",
    "Loading compiled-in X.509 certificates",
    "Freeing unused kernel image memory: 4096K",
    "Run /init as init process",
    "systemd[1]: systemd 258 running in system mode",
    "systemd[1]: Detected architecture x86-64.",
    "systemd[1]: Hostname set to <" + facts.host + ">.",
    "systemd[1]: Queued start job for default target Graphical Interface.",
    "systemd[1]: Created slice Slice /system/getty.",
    "systemd[1]: Reached target Local Encrypted Volumes.",
    "systemd[1]: Listening on Journal Socket.",
    "systemd[1]: Mounting Huge Pages File System...",
    "systemd[1]: Starting Load Kernel Modules...",
    "EXT4-fs (nvme0n1p2): mounted filesystem with ordered data mode",
    "systemd[1]: Started Journal Service.",
    "systemd-journald[214]: Received client request to flush runtime journal.",
    "i915 0000:00:02.0: [drm] Initialized i915 1.6.0 for 0000:00:02.0 on minor 1",
    "snd_hda_intel 0000:00:1f.3: enabling device",
    "iwlwifi 0000:3a:00.0: loaded firmware version",
    "Bluetooth: Core ver 2.22",
    "Bluetooth: HCI device and connection manager initialized",
    "systemd[1]: Reached target Sound Card.",
    "systemd[1]: Starting Network Manager...",
    "NetworkManager[402]: <info>  NetworkManager is starting...",
    "systemd[1]: Started Network Manager.",
    "wlan0: authenticate with access point",
    "wlan0: associated",
    "IPv6: ADDRCONF(NETDEV_CHANGE): wlan0: link becomes ready",
    "systemd[1]: Reached target Network.",
    "systemd[1]: Starting User Login Management...",
    "systemd[1]: Started User Login Management.",
    "systemd[1]: Reached target Multi-User System.",
    "systemd[1]: Reached target Graphical Interface.",
    "Hyprland: compositor started",
    "quickshell: loading configuration",
    T.t("liquid-glass : bureau 7JOKS chargé"),
    T.t("Prêt.")
  ]
  property int shown: 0
  Timer {
    interval: 38; repeat: true
    running: boot.step === 0 && boot.visible
    onTriggered: {
      boot.shown += Math.random() < 0.2 ? 2 : 1
      if (boot.shown >= boot.script.length) { boot.shown = boot.script.length; stop(); toLogo.start() }
    }
  }
  Timer { id: toLogo; interval: 350; onTriggered: { boot.step = 1; logoAnim.start() } }
  // Les lignes partent du milieu de l'écran et montent au fur et à mesure.
  Item {
    visible: boot.step === 0
    x: boot.width * 0.2; width: boot.width * 0.6
    y: 0; height: boot.height * 0.62
    clip: true
    Column {
      anchors.bottom: parent.bottom
      width: parent.width
      Repeater {
        model: boot.shown
        Text {
          required property int index
          width: parent.width
          text: boot.stamp(index) + boot.script[index]
          elide: Text.ElideRight
          font.family: boot.font; font.pixelSize: Math.round(11 * boot.k)
          color: boot.acc; opacity: 0.85
        }
      }
    }
  }

  // ------------------------------------------------------------ logo
  property real glitch: 0       // 1 → 0 : le nom se stabilise
  property real boxed: 0        // le cadre se dessine autour
  SequentialAnimation {
    id: logoAnim
    NumberAnimation { target: boot; property: "glitch"; from: 1; to: 0; duration: 900; easing.type: Easing.OutCubic }
    NumberAnimation { target: boot; property: "boxed"; from: 0; to: 1; duration: 380; easing.type: Easing.OutCubic }
    PauseAnimation { duration: 650 }
    ScriptAction { script: boot.step = 2 }
    PauseAnimation { duration: 1500 }
    ScriptAction { script: boot.leave() }
  }
  property int tick: 0
  Timer { interval: 45; repeat: true; running: boot.step === 1 && boot.glitch > 0.02; onTriggered: boot.tick++ }
  function scramble(str, amount) {
    var pool = "#$%&@*+=?/<>[]{}01", out = ""
    for (var i = 0; i < str.length; i++) out += Math.random() < amount * 0.8 ? pool.charAt(Math.floor(Math.random() * pool.length)) : str.charAt(i)
    return out
  }
  Item {
    id: logo
    visible: boot.step === 1
    anchors.centerIn: parent
    width: name.implicitWidth + 44 * boot.k; height: name.implicitHeight + 18 * boot.k
    layer.enabled: true
    layer.effect: MultiEffect { shadowEnabled: true; shadowColor: boot.acc; shadowBlur: 0.9; shadowOpacity: 0.55 * boot.boxed; shadowHorizontalOffset: 0; shadowVerticalOffset: 0 }
    // Copies décalées rouge et bleue pendant le grésillement.
    Text { anchors.centerIn: parent; anchors.horizontalCenterOffset: (boot.tick % 3 - 1) * 6 * boot.glitch * boot.k
           text: name.text; font: name.font; color: "#ff3355"; opacity: 0.7 * boot.glitch }
    Text { anchors.centerIn: parent; anchors.horizontalCenterOffset: -(boot.tick % 2) * 5 * boot.glitch * boot.k
           text: name.text; font: name.font; color: "#33ccff"; opacity: 0.7 * boot.glitch }
    Text {
      id: name
      anchors.centerIn: parent
      anchors.verticalCenterOffset: (boot.tick % 4 === 0 ? 3 : 0) * boot.glitch * boot.k
      text: boot.tick >= 0 ? boot.scramble(boot.title, boot.glitch) : boot.title
      font.family: "Michroma"; font.pixelSize: Math.round(46 * boot.k); font.letterSpacing: 4 * boot.k
      color: boot.acc
    }
    // Cadre : les quatre côtés se tracent depuis le coin haut gauche.
    Rectangle { x: 0; y: 0; height: 2; width: parent.width * boot.boxed; color: boot.acc }
    Rectangle { x: parent.width - 2; y: 0; width: 2; height: parent.height * boot.boxed; color: boot.acc }
    Rectangle { x: parent.width * (1 - boot.boxed); y: parent.height - 2; height: 2; width: parent.width * boot.boxed; color: boot.acc }
    Rectangle { x: 0; y: parent.height * (1 - boot.boxed); width: 2; height: parent.height * boot.boxed; color: boot.acc }
  }

  // ------------------------------------------------------------ bienvenue
  Text {
    anchors.centerIn: parent
    visible: boot.step === 2
    opacity: boot.step === 2 ? 1 : 0
    Behavior on opacity { NumberAnimation { duration: 500 } }
    text: T.t("Bienvenue, ") + (Quickshell.env("USER") || "")
    font.family: boot.font; font.pixelSize: Math.round(22 * boot.k); font.letterSpacing: 2 * boot.k
    color: boot.acc
  }

  // ------------------------------------------------------------ sortie
  function leave() {
    if (step >= 3) return
    logoAnim.stop()
    step = 3
    outAnim.start()
  }
  SequentialAnimation {
    id: outAnim
    NumberAnimation { target: boot; property: "fade"; to: 0; duration: 450; easing.type: Easing.OutCubic }
    ScriptAction { script: boot.finished() }
  }
}
