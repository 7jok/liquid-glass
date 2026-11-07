#!/usr/bin/env python3
"""Liquid Glass — thèmes Omarchy des styles du bureau Linux.

Pour chaque style (blanc, sombre, jouet, violet, violet-aube, rose) écrit dans
themes/<nom>/ : colors.toml (terminaux, mode clair/sombre), hyprland.lua
(bordures), shell.toml (barre, menus, notifications, verrouillage), icons.theme.
Les fonds sont générés à part par scripts/gen-linux-wallpapers.py.

    scripts/gen-linux-themes.py [dossier-thèmes]
"""
import sys
from pathlib import Path

THEMES = {
    "windows": dict(
        title="windows — clair, mica, accent bleu", mode="light", icons="Yaru-blue",
        bg="#f3f3f3", bg_dark="#ebebeb", bg_darker="#e0e0e0", bg_light="#ffffff",
        fg="#1b1b1b", fg_dark="#5d5d5d", fg_light="#2b2b2b", fg_bright="#000000",
        accent="#005fb8", selection="#cce4f7", muted="#8a8a8a", border=("005fb8cc", "0078d4cc"), inactive="d0d0d0ff",
        ansi=["#0c0c0c", "#c50f1f", "#13a10e", "#c19c00", "#0037da", "#881798", "#3a96dd", "#cccccc",
              "#767676", "#e74856", "#16c60c", "#f9f1a5", "#3b78ff", "#b4009e", "#61d6d6", "#f2f2f2"],
        bar_alpha=0.94, popup_alpha=0.97),
    "windows-sombre": dict(
        title="windows sombre — mica foncé, accent bleu clair", mode="dark", icons="Yaru-blue-dark",
        bg="#1c1c1c", bg_dark="#161616", bg_darker="#0f0f0f", bg_light="#2b2b2b",
        fg="#ffffff", fg_dark="#c5c5c5", fg_light="#e6e6e6", fg_bright="#ffffff",
        accent="#4cc2ff", selection="#0f3a54", muted="#7a7a7a", border=("4cc2ffcc", "60cdffcc"), inactive="3d3d3dff",
        ansi=["#0c0c0c", "#c50f1f", "#13a10e", "#c19c00", "#0037da", "#881798", "#3a96dd", "#cccccc",
              "#767676", "#e74856", "#16c60c", "#f9f1a5", "#3b78ff", "#b4009e", "#61d6d6", "#f2f2f2"],
        bar_alpha=0.94, popup_alpha=0.97),
    "mono": dict(
        title="mono — noir et blanc, trame (caelestia)", mode="dark", icons="Yaru-dark",
        bg="#0d0d0d", bg_dark="#080808", bg_darker="#000000", bg_light="#191919",
        fg="#e9e9e9", fg_dark="#9e9e9e", fg_light="#cfcfcf", fg_bright="#ffffff",
        accent="#e6e6e6", selection="#2c2c2c", muted="#6b6b6b", border=("e6e6e6aa", "7a7a7aaa"), inactive="2a2a2aff",
        ansi=["#191919", "#ff8a8a", "#b5c9a8", "#e0d3a0", "#a9b8cf", "#c7b3d6", "#a8cfc9", "#d9d9d9",
              "#4a4a4a", "#ffa3a3", "#c9dcbc", "#efe4b8", "#c0cde0", "#d8c8e4", "#bfe0da", "#ffffff"],
        bar_alpha=0.95, popup_alpha=0.97),
    "mono-papier": dict(
        title="mono papier — blanc pur, encre noire (caelestia blanc)", mode="light", icons="Yaru",
        bg="#ffffff", bg_dark="#f4f4f4", bg_darker="#e8e8e8", bg_light="#ffffff",
        fg="#161616", fg_dark="#6a6a6a", fg_light="#2a2a2a", fg_bright="#000000",
        accent="#1a1a1a", selection="#e2e2e2", muted="#9a9a9a", border=("1a1a1aaa", "9a9a9aaa"), inactive="dcdcdcff",
        ansi=["#161616", "#c2464f", "#4f8a4a", "#a07c1c", "#3e66b3", "#8a4fa8", "#2f8a86", "#6a6a6a",
              "#4a4a4a", "#d45a6a", "#5fa05a", "#b8902a", "#5580cc", "#a066c0", "#3fa39e", "#9a9a9a"],
        bar_alpha=0.97, popup_alpha=0.98),
    "mono-sakura": dict(
        title="mono sakura — prune profond, rose cerisier", mode="dark", icons="Yaru-magenta-dark",
        bg="#1d1218", bg_dark="#160d12", bg_darker="#0f080c", bg_light="#2a1b23",
        fg="#fbe6ee", fg_dark="#c9a3b3", fg_light="#ecd2dc", fg_bright="#ffffff",
        accent="#f7a8c4", selection="#5c2a40", muted="#8e6a7a", border=("f7a8c4cc", "ffc9a8cc"), inactive="4a3240ff",
        ansi=["#2a1b23", "#ff8a9a", "#b8d8a8", "#ffd9a8", "#a8c0f0", "#f7a8c4", "#a8e0d8", "#fbe6ee",
              "#4a3240", "#ffa3b1", "#cce8bc", "#ffe6c2", "#c0d2f7", "#ffc2d8", "#c2ece6", "#ffffff"],
        bar_alpha=0.94, popup_alpha=0.96),
    "espace": dict(
        title="espace — ciel noir, bleu glacé (ilyamiro)", mode="dark", icons="Yaru-blue-dark",
        bg="#070b14", bg_dark="#05080f", bg_darker="#02040a", bg_light="#111929",
        fg="#eef3fa", fg_dark="#9aa9bd", fg_light="#d6e3f2", fg_bright="#ffffff",
        accent="#8fc7ff", selection="#1c3a5e", muted="#5a6a80", border=("8fc7ffaa", "ffd27aaa"), inactive="25324aff",
        ansi=["#111929", "#ff7b86", "#7fdcae", "#ffd27a", "#8fc7ff", "#c58bff", "#7fdcdc", "#d6e3f2",
              "#25324a", "#ff9aa3", "#a0ecc6", "#ffe0a0", "#b0d8ff", "#d8acff", "#a0ecec", "#ffffff"],
        bar_alpha=0.85, popup_alpha=0.94),
    "ile": dict(
        title="île — prune désaturée, encoche noire", mode="dark", icons="Yaru-purple-dark",
        bg="#26232b", bg_dark="#1b191f", bg_darker="#17151b", bg_light="#322e37",
        fg="#d8d2da", fg_dark="#8a8490", fg_light="#c9c2cc", fg_bright="#ffffff",
        accent="#c9c2cc", selection="#3a3640", muted="#5e5864", border=("c9c2cc55", "7c74c855"), inactive="35313bff",
        ansi=["#322e37", "#d98c8c", "#9cc3a5", "#d8bd8a", "#9aa8d8", "#b8a0d8", "#9cc6c6", "#c9c2cc",
              "#5e5864", "#e8a3a3", "#b4d6bb", "#e8d2a5", "#b4c0e8", "#cdb8e8", "#b4dada", "#ffffff"],
        bar_alpha=0.55, popup_alpha=0.96),
    "cosmos": dict(
        title="cosmos — Terre et Lune, verre sarcelle (ilyamiro)", mode="dark", icons="Yaru-blue-dark",
        bg="#0b1216", bg_dark="#070d10", bg_darker="#02070c", bg_light="#152127",
        fg="#e4eef2", fg_dark="#92a6af", fg_light="#d5e6ee", fg_bright="#ffffff",
        accent="#9fdcf5", selection="#16404f", muted="#5b6f78", border=("9fdcf5aa", "cdbdffaa"), inactive="2a3a42ff",
        ansi=["#152127", "#ff8a8a", "#8fe0b0", "#ffd98a", "#9fdcf5", "#cdbdff", "#8fe0e0", "#d5e6ee",
              "#2a3a42", "#ffa8a8", "#a8ecc4", "#ffe6a8", "#bce8fa", "#e0d4ff", "#a8ecec", "#ffffff"],
        bar_alpha=0.85, popup_alpha=0.94),
    "ruban": dict(
        title="rubans — bleu nuit, cyan, aplats en biais", mode="dark", icons="Yaru-blue-dark",
        bg="#06102e", bg_dark="#050c24", bg_darker="#03081a", bg_light="#0d2050",
        fg="#ffffff", fg_dark="#a8dfff", fg_light="#d8f6ff", fg_bright="#ffffff",
        accent="#19d3ff", selection="#0a3a8c", muted="#4f8fd0", border=("19d3ffff", "ffffffff"), inactive="1d3f8aff",
        ansi=["#0d2050", "#ff5a6e", "#3ddbb4", "#ffc800", "#19a3ff", "#c58bff", "#19d3ff", "#d8f6ff",
              "#1d3f8a", "#ff8a9a", "#6fe8cc", "#ffe080", "#60c0ff", "#dcb0ff", "#8fe8ff", "#ffffff"],
        bar_alpha=0.96, popup_alpha=0.98),
    "debian": dict(
        title="debian — GNOME, framboise", mode="dark", icons="Yaru-red-dark",
        bg="#1e1e1e", bg_dark="#171717", bg_darker="#101010", bg_light="#2a2a2a",
        fg="#f2f2f2", fg_dark="#b8b8b8", fg_light="#dcdcdc", fg_bright="#ffffff",
        accent="#d70a53", selection="#5a1830", muted="#7c7c7c", border=("d70a53ee", "d70a53aa"), inactive="3a3a3aff",
        ansi=["#2e2e2e", "#e05561", "#4fb06a", "#d6a23d", "#4c8dd6", "#b06bd6", "#3fb4b4", "#d0d0d0",
              "#5c5c5c", "#ff7b86", "#6fd18b", "#f0c060", "#72acf0", "#cc8ff0", "#60d0d0", "#ffffff"],
        bar_alpha=0.98, popup_alpha=0.98),
    "fedora": dict(
        title="fedora — GNOME, bleu Fedora", mode="dark", icons="Yaru-blue-dark",
        bg="#1e2228", bg_dark="#171a1f", bg_darker="#101317", bg_light="#2a3038",
        fg="#f2f2f2", fg_dark="#b8b8b8", fg_light="#dcdcdc", fg_bright="#ffffff",
        accent="#3c6eb4", selection="#24406a", muted="#7c7c7c", border=("3c6eb4ee", "3c6eb4aa"), inactive="3a3a3aff",
        ansi=["#2e2e2e", "#e05561", "#4fb06a", "#d6a23d", "#4c8dd6", "#b06bd6", "#3fb4b4", "#d0d0d0",
              "#5c5c5c", "#ff7b86", "#6fd18b", "#f0c060", "#72acf0", "#cc8ff0", "#60d0d0", "#ffffff"],
        bar_alpha=0.98, popup_alpha=0.98),
    "mint": dict(
        title="mint — Cinnamon, vert menthe", mode="dark", icons="Yaru-sage-dark",
        bg="#262626", bg_dark="#1f1f1f", bg_darker="#181818", bg_light="#303030",
        fg="#f2f2f2", fg_dark="#b8b8b8", fg_light="#dcdcdc", fg_bright="#ffffff",
        accent="#35a854", selection="#1f5a30", muted="#7c7c7c", border=("35a854ee", "35a854aa"), inactive="3a3a3aff",
        ansi=["#2e2e2e", "#e05561", "#4fb06a", "#d6a23d", "#4c8dd6", "#b06bd6", "#3fb4b4", "#d0d0d0",
              "#5c5c5c", "#ff7b86", "#6fd18b", "#f0c060", "#72acf0", "#cc8ff0", "#60d0d0", "#ffffff"],
        bar_alpha=0.98, popup_alpha=0.98),
    "kali": dict(
        title="kali — Xfce, bleu nuit", mode="dark", icons="Yaru-blue-dark",
        bg="#1b1d26", bg_dark="#15161e", bg_darker="#0f1016", bg_light="#262936",
        fg="#f2f2f2", fg_dark="#b8b8b8", fg_light="#dcdcdc", fg_bright="#ffffff",
        accent="#367bf0", selection="#1f3f7a", muted="#7c7c7c", border=("367bf0ee", "367bf0aa"), inactive="3a3a3aff",
        ansi=["#2e2e2e", "#e05561", "#4fb06a", "#d6a23d", "#4c8dd6", "#b06bd6", "#3fb4b4", "#d0d0d0",
              "#5c5c5c", "#ff7b86", "#6fd18b", "#f0c060", "#72acf0", "#cc8ff0", "#60d0d0", "#ffffff"],
        bar_alpha=0.98, popup_alpha=0.98),
    "arch": dict(
        title="arch — Plasma, bleu Arch", mode="dark", icons="Yaru-blue-dark",
        bg="#1b1e20", bg_dark="#151719", bg_darker="#0f1112", bg_light="#272b2e",
        fg="#f2f2f2", fg_dark="#b8b8b8", fg_light="#dcdcdc", fg_bright="#ffffff",
        accent="#1793d1", selection="#104f70", muted="#7c7c7c", border=("1793d1ee", "1793d1aa"), inactive="3a3a3aff",
        ansi=["#2e2e2e", "#e05561", "#4fb06a", "#d6a23d", "#4c8dd6", "#b06bd6", "#3fb4b4", "#d0d0d0",
              "#5c5c5c", "#ff7b86", "#6fd18b", "#f0c060", "#72acf0", "#cc8ff0", "#60d0d0", "#ffffff"],
        bar_alpha=0.98, popup_alpha=0.98),
    "foret": dict(
        title="forêt — olive, tilleul et pêche (c01)", mode="dark", icons="Yaru-sage-dark",
        bg="#1a1d14", bg_dark="#15180f", bg_darker="#0f110b", bg_light="#252a1d",
        fg="#e6e9d6", fg_dark="#b9bea4", fg_light="#d5dac2", fg_bright="#f7f9ee",
        accent="#cfe89a", selection="#3f5120", muted="#868c72", border=("cfe89aee", "f4b6a6ee"), inactive="434a36aa",
        ansi=["#252a1d", "#f4a6a0", "#cfe89a", "#f2d38a", "#9fc2d6", "#d9b2d0", "#a6d8c4", "#e6e9d6",
              "#434a36", "#ffbab4", "#e0f5b4", "#f7e1a6", "#b8d6e6", "#e6c6de", "#bde8d6", "#f7f9ee"],
        bar_alpha=0.92, popup_alpha=0.95),
    "blanc": dict(
        title="blanc — tout en blanc, encre noire, police mono", mode="light", icons="Yaru",
        bg="#f7f7f7", bg_dark="#efefef", bg_darker="#e6e6e6", bg_light="#ffffff",
        fg="#141414", fg_dark="#6e6e6e", fg_light="#2a2a2a", fg_bright="#000000",
        accent="#141414", selection="#dcdcdc", muted="#9a9a9a", border=("141414ee", "141414ee"), inactive="d6d6d6ff",
        ansi=["#141414", "#b3261e", "#2e7d32", "#8d6e00", "#1f4fbf", "#7b3fa0", "#00796b", "#6e6e6e",
              "#5c5c5c", "#d32f2f", "#43a047", "#b08900", "#3b6fe0", "#9c4dcc", "#00897b", "#9a9a9a"],
        bar_alpha=0.96, popup_alpha=0.98),
    "sombre": dict(
        title="sombre — noir profond, blanc cassé", mode="dark", icons="Yaru-dark",
        bg="#070707", bg_dark="#050505", bg_darker="#000000", bg_light="#141414",
        fg="#ededed", fg_dark="#8c8c8c", fg_light="#d0d0d0", fg_bright="#ffffff",
        accent="#f2f2f2", selection="#2a2a2a", muted="#5a5a5a", border=("f2f2f2cc", "8c8c8ccc"), inactive="2a2a2aff",
        ansi=["#1c1c1c", "#d0716f", "#8fb08a", "#d6c07a", "#8aa4c8", "#b294bb", "#8abeb7", "#cfcfcf",
              "#4a4a4a", "#e08a88", "#a7c9a1", "#e6d393", "#a3bde0", "#c9addb", "#a3d6cf", "#ffffff"],
        bar_alpha=0.92, popup_alpha=0.95),
    "jouet": dict(
        title="jouet — bonbon, contours épais, ombres dures", mode="light", icons="Yaru-magenta",
        bg="#fff8ee", bg_dark="#ffeedd", bg_darker="#ffe4cc", bg_light="#fffdf7",
        fg="#1b1030", fg_dark="#5b4a7a", fg_light="#2d1f48", fg_bright="#0d0618",
        accent="#ff5fa2", selection="#ffd9ea", muted="#b9a2ff", border=("ff5fa2ff", "6ec6ffff"), inactive="1b1030ff",
        ansi=["#1b1030", "#ff3b6b", "#1fb98f", "#e0a800", "#2f8fe0", "#c14fd6", "#12a9b8", "#5b4a7a",
              "#4a3a6a", "#ff5fa2", "#3ddbb4", "#ffd23f", "#6ec6ff", "#b9a2ff", "#5ee6e6", "#8d7aa8"],
        bar_alpha=0.97, popup_alpha=0.98),
    "violet": dict(
        title="violet nuit — montagnes violettes, horloge bonbon", mode="dark", icons="Yaru-purple-dark",
        bg="#1a1230", bg_dark="#140e26", bg_darker="#0e091c", bg_light="#271d43",
        fg="#ece4ff", fg_dark="#b6a8d8", fg_light="#d9ccff", fg_bright="#ffffff",
        accent="#cdb6ff", selection="#3b2f5e", muted="#7e6fa6", border=("cdb6ffff", "f0a6d8ff"), inactive="43376baa",
        ansi=["#271d43", "#ff7a9a", "#9ee6b8", "#ffd99a", "#9fb8ff", "#cdb6ff", "#9fe3f0", "#d9ccff",
              "#4a3d73", "#ff9bb3", "#b8f0cc", "#ffe6b8", "#bccdff", "#e0d0ff", "#bdf0f8", "#ffffff"],
        bar_alpha=0.85, popup_alpha=0.92),
    "violet-aube": dict(
        title="violet aube — lilas clair", mode="light", icons="Yaru-purple",
        bg="#f6f1fd", bg_dark="#eee6fb", bg_darker="#e0d3f5", bg_light="#fbf8ff",
        fg="#2c1b4d", fg_dark="#6d5a91", fg_light="#3b2463", fg_bright="#1a0d33",
        accent="#8a63c9", selection="#d9c8f5", muted="#a593c7", border=("3b2463ff", "b06bd6ff"), inactive="d5c8ecff",
        ansi=["#2c1b4d", "#c2365e", "#2f8a5a", "#9a6a00", "#3a5bc4", "#8a63c9", "#1f8a9a", "#6d5a91",
              "#4a3a70", "#d64b6a", "#3fa56f", "#b88400", "#5577de", "#a37de0", "#2ba3b5", "#a593c7"],
        bar_alpha=0.9, popup_alpha=0.96),
    "rose": dict(
        title="rose — pastel, brume crème", mode="light", icons="Yaru-magenta",
        bg="#fff6f9", bg_dark="#fdeef3", bg_darker="#f6d6e2", bg_light="#fffafc",
        fg="#4a2533", fg_dark="#8c5c6e", fg_light="#5e2f42", fg_bright="#2e121d",
        accent="#c06a8c", selection="#f6cfdc", muted="#c995a8", border=("8a3e5cff", "9b6bd1ff"), inactive="f0cfdbff",
        ansi=["#4a2533", "#d6365a", "#3a8a5f", "#a86b00", "#5a6fd1", "#b04f8a", "#2e8f96", "#8c5c6e",
              "#6e3a4f", "#e8587a", "#4fa676", "#c48a1a", "#7a8de6", "#c96aa3", "#45a9b0", "#c995a8"],
        bar_alpha=0.9, popup_alpha=0.96),
}

NAMES = ["black", "red", "green", "yellow", "blue", "magenta", "cyan", "white"]


def mix(c1, c2):
    a = [int(c1[i:i + 2], 16) for i in (1, 3, 5)]
    b = [int(c2[i:i + 2], 16) for i in (1, 3, 5)]
    return "#" + "".join(f"{(a[i] + b[i]) // 2:02x}" for i in range(3))


def colors_toml(t):
    a = t["ansi"]
    lines = [f"# Liquid Glass — {t['title']} (profil Linux, ⌘⇧Espace).", "# Généré par scripts/gen-linux-themes.py.",
             f'mode = "{t["mode"]}"', "",
             f'accent = "{t["accent"]}"', f'selection = "{t["selection"]}"', f'muted = "{t["muted"]}"', "",
             f'background = "{t["bg"]}"', f'dark_background = "{t["bg_dark"]}"', f'darker_background = "{t["bg_darker"]}"',
             f'lighter_background = "{t["bg_light"]}"', "",
             f'foreground = "{t["fg"]}"', f'dark_foreground = "{t["fg_dark"]}"', f'light_foreground = "{t["fg_light"]}"',
             f'bright_foreground = "{t["fg_bright"]}"', "",
             f'hyprland_active_border = "rgba({t["border"][0]}) rgba({t["border"][1]}) 45deg"', "",
             f'hyprland_inactive_border = "rgba({t["inactive"]})"', ""]
    # Omarchy lit les couleurs par nom (pas color0…15).
    for i, n in enumerate(NAMES):
        if n in ("black", "white"):
            continue
        lines.append(f'{n} = "{a[i]}"')
    lines.append(f'orange = "{mix(a[1], a[3])}"')
    lines.append(f'brown = "{mix(a[3], a[0])}"')
    lines.append("")
    for i, n in enumerate(NAMES):
        if n in ("black", "white"):
            continue
        lines.append(f'bright_{n} = "{a[8 + i]}"')
    return "\n".join(lines) + "\n"


def hypr_lua(t):
    return f'''-- Thème « {t["title"].split(" —")[0]} » (profil Linux) : bordure en dégradé à 45°.
-- Généré par scripts/gen-linux-themes.py ; le service du bureau Linux affine
-- ensuite bordures, arrondis et ombres selon le style.
local active_border_color = {{ colors = {{ "rgba({t["border"][0]})", "rgba({t["border"][1]})" }}, angle = 45 }}
local inactive_border_color = "rgba({t["inactive"]})"

hl.config({{
  general = {{
    col = {{
      active_border = active_border_color,
      inactive_border = inactive_border_color,
    }},
  }},
  group = {{
    col = {{
      border_active = active_border_color,
      border_inactive = inactive_border_color,
    }},
  }},
}})
'''


def shell_toml(t):
    bg, fg, ac = t["bg"], t["fg"], t["accent"]
    sel_text = t["bg"] if t["mode"] == "dark" else "#ffffff"
    if t["accent"] in ("#f2f2f2",):
        sel_text = "#0a0a0a"
    b = t["border"][0]
    return f'''# Liquid Glass — thème « {t["title"]} » (profil Linux). Généré par scripts/gen-linux-themes.py.

[bar]
background       = "{bg}"
background-alpha = {t["bar_alpha"]}
text             = "{fg}"
active           = "{ac}"
scale-with-font  = true
size-horizontal  = 24
size-vertical    = 30

[hyprland]
active-border            = "rgba({b})"
active-border-foreground = "rgba({b})"

[controls]
normal-color        = "{fg}"
normal-fill-alpha   = 0.05
normal-border       = "{fg}"
normal-border-width = 1
normal-border-alpha = 0.12

hover-cursor-color        = "{fg}"
hover-cursor-fill-alpha   = 0.09
hover-cursor-border       = "{fg}"
hover-cursor-border-width = 0
hover-cursor-border-alpha = 0.0

focus-color        = "{ac}"
focus-fill-alpha   = 0.12
focus-border       = "{ac}"
focus-border-width = 1
focus-border-alpha = 0.6

selected-color        = "{ac}"
selected-fill-alpha   = 0.88
selected-border       = "{ac}"
selected-border-width = 0
selected-border-alpha = 1.0

pressed-fill-alpha   = 0.18
selection-fill-alpha = 0.35

[spacing]
scale = 1.0
scale-with-font = true
panel-padding = 16
popup-padding = 14

[font]
base-size = 12

[popups]
background       = "{bg}"
background-alpha = {t["popup_alpha"]}
text             = "{fg}"
border           = "hyprland.active-border"
border-alpha     = 1.0
border-width     = 1

[tooltip]
background       = "{bg}"
background-alpha = {t["popup_alpha"]}
text             = "{fg}"
border           = "hyprland.active-border-foreground"
border-alpha     = 1.0

[notifications]
background       = "{bg}"
background-alpha = {t["popup_alpha"]}
text             = "{fg}"
border           = "hyprland.active-border"
border-alpha     = 1.0
border-width     = 1
countdown        = "{ac}"

[launcher]
background                = "{bg}"
background-alpha          = 0.97
text                      = "{fg}"
border                    = "hyprland.active-border-foreground"
border-alpha              = 1.0
scrim                     = "{bg}"
scrim-alpha               = 0.12
selected-background       = "{ac}"
selected-background-alpha = 0.88
selected-text             = "{sel_text}"
selected-border           = "{ac}"
selected-border-alpha     = 0.0

[menu]
background                = "{bg}"
background-alpha          = 0.97
text                      = "{fg}"
border                    = "hyprland.active-border-foreground"
border-alpha              = 1.0
scrim                     = "{bg}"
scrim-alpha               = 0.12
selected-background       = "{ac}"
selected-background-alpha = 0.88
selected-text             = "{sel_text}"
selected-border           = "{ac}"
selected-border-alpha     = 0.0

[polkit]
background       = "{bg}"
background-alpha = 0.94
text             = "{fg}"
text-error       = "{t["ansi"][9]}"
border           = "hyprland.active-border"
border-error     = "{t["ansi"][9]}"
border-alpha     = 1.0
scrim            = "{bg}"
scrim-alpha      = 0.25
accent           = "{ac}"

[lock]
background       = "{bg}"
background-alpha = 0.80
text             = "{fg}"
placeholder      = "{t["fg_dark"]}"
text-error       = "{t["ansi"][9]}"
border           = "rgba({b})"
border-active    = "{ac}"
border-error     = "{t["ansi"][9]}"
border-alpha     = 1.0
selection        = "{ac}"
selection-alpha  = 0.45

[image-picker]
text                    = "{fg}"
selected-border         = "{ac}"
selected-border-alpha   = 1.0
unselected-border       = "{fg}"
unselected-border-alpha = 0.28
'''


def main():
    root = Path(sys.argv[1]) if len(sys.argv) > 1 else Path(__file__).resolve().parent.parent / "themes"
    for name, t in THEMES.items():
        d = root / name
        (d / "backgrounds").mkdir(parents=True, exist_ok=True)
        (d / "colors.toml").write_text(colors_toml(t))
        (d / "hyprland.lua").write_text(hypr_lua(t))
        (d / "shell.toml").write_text(shell_toml(t))
        (d / "icons.theme").write_text(t["icons"] + "\n")
        print("thème", d)


if __name__ == "__main__":
    main()
