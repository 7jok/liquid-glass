#!/usr/bin/env python3
"""Génère une fiche fastfetch par bureau dans terminal/fastfetch/styles/.

Les bureaux de distribution gardent le logo officiel de fastfetch. Les autres ont
leur dessin, leur cadre et leurs libellés. Couleurs ANSI : elles suivent le thème.
"""
import json
from pathlib import Path

OUT = Path(__file__).resolve().parent.parent / "terminal/fastfetch/styles"

ART = {
    "blanc": ["┌──────┐", "│ ░░░░ │", "│ ░░░░ │", "│ ░░░░ │", "└──────┘"],
    "sombre": ["▓▓▓▓▓▓▓▓", "▓░░░░░░▓", "▓░ ██ ░▓", "▓░░░░░░▓", "▓▓▓▓▓▓▓▓"],
    "jouet": ["  ▄▄▄▄  ", " █ ◕◕ █ ", " █ ▽▽ █ ", "  ▀██▀  ", "  ▟  ▙  "],
    "violet": [" ▄▄  ▄▄ ", "████████", " ██████ ", "  ████  ", "   ██   "],
    "expressive": ["  ◢██◣  ", " ◢████◣ ", "◢██████◣", " ◥████◤ ", "  ◥██◤  "],
    "mono": ["●      ", "  ●    ", "    ●  ", "      ●", "    ●  "],
    "foret": ["   ▲   ", "  ▲▲▲  ", " ▲▲▲▲▲ ", "▲▲▲▲▲▲▲", "   █   "],
    "ruban": ["▰▰▰▰▰▰▱", " ▰▰▰▰▰▱", "  ▰▰▰▰▱", " ▰▰▰▰▰▱", "▰▰▰▰▰▰▱"],
    "espace": ["   .  *   ", " *  ◯    .", "  ╱───╲  ", " (  ●  ) ", "  ╲───╱ *"],
    "cosmos": ["  ▄▄██▄▄  ", " ██▓▒░▒██ ", "███▒░ ░▓██", " ██▓░▒▓██ ", "  ▀▀██▀▀  "],
    "gouts": ["╭─────╮", "│ ♫ ♥ │", "│ ☾ ★ │", "╰─────╯"],
}
BUILTIN = {"debian": "debian", "fedora": "fedora", "mint": "linuxmint", "kali": "kali", "arch": "arch", "windows": "windows"}
# clé : (cadre haut, préfixe de ligne, séparateur de section, libellés)
FR = ["os", "noyau", "bureau", "paquets", "allumé", "cpu", "mémoire", "disque", "batterie"]
STYLES = {
    "blanc": ("", "", "", FR),
    "sombre": ("", "▌ ", "", [k.upper() for k in FR]),
    "jouet": ("★ ★ ★ ★ ★", "★ ", "", FR),
    "violet": ("", "♡ ", "· · · · ·", FR),
    "expressive": ("", "◆ ", "", FR),
    "mono": ("┌─ système ─────────────────────", "│ ", "├─ machine ─────────────────────", FR),
    "foret": ("", "❧ ", "~ ~ ~ ~ ~", FR),
    "ruban": ("▰▰▰▰▰▰▰▰▰▰▰▰▰▰", "▸ ", "", [k.upper() for k in FR]),
    "espace": ("", "◦ ", "· · ·", ["orbite", "noyau", "vaisseau", "cargo", "en vol", "moteur", "mémoire", "soute", "énergie"]),
    "cosmos": ("", "◦ ", "· · ·", ["orbite", "noyau", "vaisseau", "cargo", "en vol", "moteur", "mémoire", "soute", "énergie"]),
    "gouts": ("", "♪ ", "", FR),
    "windows": ("", "", "", ["Système", "Noyau", "Bureau", "Paquets", "Allumé", "Processeur", "Mémoire", "Disque", "Batterie"]),
    "debian": ("", "", "", FR),
    "fedora": ("", "", "", FR),
    "mint": ("", "", "", FR),
    "kali": ("┌──(kali㉿liquid-glass)", "│ ", "", FR),
    "arch": ("", " ", "", FR),
}
OS_NAME = {"debian": "Debian", "fedora": "Fedora", "mint": "Linux Mint", "kali": "Kali Linux", "arch": "Arch Linux"}


def config(style):
    top, pre, sep, k = STYLES[style]
    mods = [{"type": "title", "format": "{user-name-colored}{at-symbol-colored}{host-name-colored}"}]
    if top:
        mods.append({"type": "custom", "format": top})
    os_mod = {"type": "os", "key": pre + k[0], "format": "{pretty-name}"}
    if style in OS_NAME:
        os_mod = {"type": "os", "key": pre + k[0], "format": OS_NAME[style] + " · sur {pretty-name}"}
    mods += [os_mod, {"type": "kernel", "key": pre + k[1]}, {"type": "wm", "key": pre + k[2], "format": "{pretty-name}"},
             {"type": "packages", "key": pre + k[3]}, {"type": "uptime", "key": pre + k[4]}]
    if sep:
        mods.append({"type": "custom", "format": sep})
    mods += [{"type": "cpu", "key": pre + k[5], "format": "{name}"}, {"type": "memory", "key": pre + k[6]},
             {"type": "disk", "key": pre + k[7], "folders": "/"}, {"type": "battery", "key": pre + k[8]},
             "break", {"type": "colors", "symbol": "circle", "paddingLeft": 2}]
    if style in BUILTIN:
        logo = {"source": BUILTIN[style], "padding": {"top": 1, "left": 2, "right": 3}}
    else:
        logo = {"type": "data", "source": "\n".join(ART[style]), "padding": {"top": 2, "left": 3, "right": 4},
                "color": {"1": "blue"}}
    return {"$schema": "https://github.com/fastfetch-cli/fastfetch/raw/dev/doc/json_schema.json", "logo": logo,
            "display": {"separator": "  ", "key": {"width": 14 + len(pre)}, "color": {"keys": "blue"}}, "modules": mods}


OUT.mkdir(parents=True, exist_ok=True)
for st in STYLES:
    (OUT / f"{st}.jsonc").write_text(json.dumps(config(st), ensure_ascii=False, indent=2) + "\n")
print(f"{len(STYLES)} fiches dans {OUT}")
