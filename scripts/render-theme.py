#!/usr/bin/env python3
"""Liquid Glass — génère les fichiers « glass » d'un thème Omarchy.

Usage : render-theme.py <dossier-du-thème> [config.toml]

Lit <thème>/colors.toml (+ la config centrale si fournie) et écrit :
  shell.toml    surfaces du shell Omarchy (barre, popups, menus, lock…) translucides
  hyprland.lua  bordures fines translucides des fenêtres
  foot.ini      terminal en verre (fond translucide flouté, palette lisible)

Les alphas des surfaces sont multipliés par `glass.opacity` (0.0–1.0, défaut 1.0)
de la config centrale : plus bas = plus transparent.
"""
from __future__ import annotations

import sys
import tomllib
from pathlib import Path


def hex_to_rgb(h: str) -> tuple[int, int, int]:
    h = h.lstrip("#")
    return int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16)


def mix(a: str, b: str, pct_a: float) -> str:
    """Mélange a et b ; pct_a = part de a (0..1)."""
    ra, ga, ba = hex_to_rgb(a)
    rb, gb, bb = hex_to_rgb(b)
    r = round(ra * pct_a + rb * (1 - pct_a))
    g = round(ga * pct_a + gb * (1 - pct_a))
    bl = round(ba * pct_a + bb * (1 - pct_a))
    return f"#{r:02x}{g:02x}{bl:02x}"


def clamp(x: float) -> float:
    return max(0.0, min(1.0, x))


# Palettes ANSI des terminaux : plus contrastées que colors.toml, pensées pour
# du texte posé sur du verre (blanc ou sombre).
TERM_LIGHT = {
    "regular": ["1d1d1f", "c9252c", "1f7a36", "946200", "0a63c9", "8a3fc7", "117a85", "6e6e73"],
    "bright": ["8e8e93", "ff3b30", "28a745", "b77900", "007aff", "af52de", "0ea5b7", "3a3a3c"],
}
TERM_DARK = {
    "regular": ["3a3a3c", "ff6b62", "4fd97a", "ffd75e", "5aa9ff", "cf8bf7", "6fd6f2", "e5e5ea"],
    "bright": ["8e8e93", "ff8f88", "7ee69f", "ffe58f", "8cc4ff", "e0b0ff", "a0e6ff", "ffffff"],
}


def render(theme_dir: Path, config: dict) -> None:
    c = tomllib.loads((theme_dir / "colors.toml").read_text())
    light = c.get("mode", "dark") == "light"
    glass = config.get("glass", {})
    # Multiplicateur global d'opacité × style du verre (comme le réglage
    # « Liquid Glass » de macOS 26.1) : clear = très transparent, tinted = plus opaque.
    style_k = {"clear": 0.7, "standard": 1.0, "tinted": 1.45}.get(str(glass.get("style", "standard")), 1.0)
    k = float(glass.get("opacity", 1.0)) * style_k

    def a(light_val: float, dark_val: float) -> str:
        return f"{clamp((light_val if light else dark_val) * k):.2f}"

    bg, fg, accent, red = c["background"], c["foreground"], c["accent"], c["red"]
    # Liseré « rim light » des surfaces du shell : blanc translucide.
    rim = "rgba(ffffffa6)" if light else "rgba(ffffff2e)"
    placeholder = mix(fg, bg, 0.45)

    shell = f"""# Liquid Glass — surfaces du shell Omarchy. FICHIER GÉNÉRÉ par
# liquid-glass/scripts/render-theme.py : modifie la config centrale plutôt que ce fichier.
# Le flou derrière ces surfaces vient des layer rules Hyprland (mode « glassy »).

[bar]
background       = "{bg}"
background-alpha = {a(0.50, 0.40)}
text             = "{fg}"
active           = "{red}"
scale-with-font  = true
size-horizontal  = 28
size-vertical    = 30

[hyprland]
active-border            = "{rim}"
active-border-foreground = "{rim}"

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

focus-color        = "{accent}"
focus-fill-alpha   = 0.10
focus-border       = "{accent}"
focus-border-width = 1
focus-border-alpha = 0.55

selected-color        = "{accent}"
selected-fill-alpha   = 0.85
selected-border       = "{accent}"
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
background-alpha = {a(0.70, 0.62)}
text             = "{fg}"
border           = "hyprland.active-border"
border-alpha     = 1.0
border-width     = 1

[tooltip]
background       = "{bg}"
background-alpha = {a(0.86, 0.82)}
text             = "{fg}"
border           = "hyprland.active-border-foreground"
border-alpha     = 1.0

[notifications]
background       = "{bg}"
background-alpha = {a(0.72, 0.62)}
text             = "{fg}"
border           = "hyprland.active-border"
border-alpha     = 1.0
border-width     = 1
countdown        = "{accent}"

[launcher]
background                = "{bg}"
background-alpha          = {a(0.72, 0.62)}
text                      = "{fg}"
border                    = "hyprland.active-border-foreground"
border-alpha              = 1.0
scrim                     = "{bg}"
scrim-alpha               = 0.12
selected-background       = "{accent}"
selected-background-alpha = 0.85
selected-text             = "#ffffff"
selected-border           = "{accent}"
selected-border-alpha     = 0.0

[menu]
background                = "{bg}"
background-alpha          = {a(0.72, 0.62)}
text                      = "{fg}"
border                    = "hyprland.active-border-foreground"
border-alpha              = 1.0
scrim                     = "{bg}"
scrim-alpha               = 0.12
selected-background       = "{accent}"
selected-background-alpha = 0.85
selected-text             = "#ffffff"
selected-border           = "{accent}"
selected-border-alpha     = 0.0

[polkit]
background       = "{bg}"
background-alpha = {a(0.80, 0.72)}
text             = "{fg}"
text-error       = "{red}"
border           = "hyprland.active-border"
border-error     = "{red}"
border-alpha     = 1.0
scrim            = "{bg}"
scrim-alpha      = 0.25
accent           = "{accent}"

[lock]
background       = "{bg}"
background-alpha = {a(0.38, 0.30)}
text             = "{fg}"
placeholder      = "{placeholder}"
text-error       = "{red}"
border           = "{rim}"
border-active    = "{accent}"
border-error     = "{red}"
border-alpha     = 1.0
selection        = "{accent}"
selection-alpha  = 0.45

[image-picker]
text                    = "{fg}"
selected-border         = "{accent}"
selected-border-alpha   = 1.0
unselected-border       = "{fg}"
unselected-border-alpha = 0.28
"""
    (theme_dir / "shell.toml").write_text(shell)

    act = c.get("hyprland_active_border", "rgba(ffffff40)")
    ina = c.get("hyprland_inactive_border", "rgba(ffffff1f)")
    hypr = f"""-- Liquid Glass — bordures des fenêtres. FICHIER GÉNÉRÉ par render-theme.py.
-- Liseré fin, blanc translucide, sans couleur agressive.
local active_border_color = "{act}"
local inactive_border_color = "{ina}"

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
"""
    (theme_dir / "hyprland.lua").write_text(hypr)

    term = TERM_LIGHT if light else TERM_DARK
    tcfg = config.get("terminal", {})
    term_alpha = clamp(float(tcfg.get("opacity_light", 0.80) if light else tcfg.get("opacity_dark", 0.76)))
    term_bg = "fbfbfd" if light else bg.lstrip("#")
    lines = [
        "# Liquid Glass — terminal foot en verre. FICHIER GÉNÉRÉ par render-theme.py.",
        "[colors-dark]",
        f"alpha={term_alpha:.2f}",
        "blur=yes",
        f"foreground={fg.lstrip('#')}",
        f"background={term_bg}",
        f"selection-foreground={fg.lstrip('#')}",
        f"selection-background={c['selection'].lstrip('#')}",
        f"cursor={term_bg} {accent.lstrip('#')}",
        f"urls={accent.lstrip('#')}",
    ]
    lines += [f"regular{i}={col}" for i, col in enumerate(term["regular"])]
    lines += [f"bright{i}={col}" for i, col in enumerate(term["bright"])]
    (theme_dir / "foot.ini").write_text("\n".join(lines) + "\n")

    print(f"rendu : {theme_dir.name} ({'clair' if light else 'sombre'}, opacité ×{k})")


def main() -> int:
    if len(sys.argv) < 2:
        print(__doc__)
        return 1
    config: dict = {}
    if len(sys.argv) > 2 and Path(sys.argv[2]).is_file():
        config = tomllib.loads(Path(sys.argv[2]).read_text())
    render(Path(sys.argv[1]), config)
    return 0


if __name__ == "__main__":
    sys.exit(main())
