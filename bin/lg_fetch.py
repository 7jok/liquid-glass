"""Fiches fastfetch de chaque bureau. Trois présentations : `classic` (longue liste, comme sur
les distributions), `box` (cadres et icônes) et `card` (carte arrondie). Trois densités selon
la place : full, short, mini. Couleurs ANSI : elles suivent le thème du terminal.
"""
import fcntl
import json
import random
import struct
import subprocess
import termios
from pathlib import Path

import lg_art

SCHEMA = "https://github.com/fastfetch-cli/fastfetch/raw/dev/doc/json_schema.json"
MARK = "// liquid-glass : fiche générée, remplacée à chaque changement de bureau.\n"
BUILTIN = {"debian": "debian", "fedora": "fedora", "mint": "linuxmint", "kali": "kali", "arch": "arch",
           "windows": "windows", "mac": "macos"}
OS_NAME = {"debian": "Debian", "fedora": "Fedora", "mint": "Linux Mint", "kali": "Kali Linux", "arch": "Arch Linux"}
# clé : présentation, couleur des libellés, images, texte en grand.
STYLES = {
    "mac": ("classic", "blue", [], "MAC"),
    "windows": ("classic", "cyan", [], "WINDOWS"),
    "debian": ("classic", "red", [], "DEBIAN"),
    "fedora": ("classic", "blue", [], "FEDORA"),
    "mint": ("classic", "green", [], "MINT"),
    "kali": ("classic", "blue", [], "KALI"),
    "arch": ("classic", "cyan", [], "ARCH"),
    "blanc": ("box", "default", ["vitruve", "riders", "wave"], "BLANC"),
    "sombre": ("classic", "white", ["riders", "aldrin", "pillars"], "SOMBRE"),
    "jouet": ("card", "magenta", ["tux", "fuji", "starry"], "JOUET"),
    "violet": ("card", "magenta", ["starry", "pillars", "wave"], "VIOLET"),
    "expressive": ("card", "yellow", ["starry", "wave", "fuji"], "EXPRESSIVE"),
    "mono": ("box", "white", ["wave", "riders", "vitruve"], "MONO"),
    "foret": ("classic", "green", ["fuji", "wave", "starry"], "FORET"),
    "ruban": ("card", "red", ["riders", "fuji", "wave"], "RUBAN"),
    "espace": ("box", "cyan", ["saturn", "astronaut", "aldrin", "pillars"], "ESPACE"),
    "cosmos": ("box", "blue", ["earth", "earthrise", "aldrin", "saturn"], "COSMOS"),
    "gouts": ("card", "magenta", ["starry", "wave", "tux", "earth"], "OMARCHY"),
}
LABELS = {
    "fr": {"os": "OS", "host": "Hôte", "kernel": "Noyau", "uptime": "Allumé", "packages": "Paquets", "shell": "Shell",
           "display": "Écran", "de": "Bureau", "wm": "Fenêtres", "wmtheme": "Thème fen.", "theme": "Thème",
           "icons": "Icônes", "font": "Police", "cursor": "Curseur", "terminal": "Terminal", "terminalfont": "Police term.",
           "cpu": "Processeur", "gpu": "Carte vidéo", "memory": "Mémoire", "swap": "Échange", "disk": "Disque",
           "localip": "IP locale", "battery": "Batterie", "locale": "Langue", "hard": "Matériel", "soft": "Logiciel"},
    "en": {"os": "OS", "host": "Host", "kernel": "Kernel", "uptime": "Uptime", "packages": "Packages", "shell": "Shell",
           "display": "Display", "de": "DE", "wm": "WM", "wmtheme": "WM Theme", "theme": "Theme", "icons": "Icons",
           "font": "Font", "cursor": "Cursor", "terminal": "Terminal", "terminalfont": "Terminal Font", "cpu": "CPU",
           "gpu": "GPU", "memory": "Memory", "swap": "Swap", "disk": "Disk", "localip": "Local IP", "battery": "Battery",
           "locale": "Locale", "hard": "Hardware", "soft": "Software"},
}
SPACE = {"fr": {"os": "Orbite", "host": "Vaisseau", "uptime": "En vol", "packages": "Cargo", "cpu": "Moteur",
                "disk": "Soute", "battery": "Énergie"},
         "en": {"os": "Orbit", "host": "Ship", "uptime": "In flight", "packages": "Cargo", "cpu": "Engine",
                "disk": "Hold", "battery": "Power"}}
ICON = {"os": "", "host": "", "kernel": "", "uptime": "", "packages": "", "shell": "",
        "display": "", "wm": "", "terminal": "", "cpu": "", "gpu": "", "memory": "",
        "disk": "", "battery": "", "localip": "", "theme": ""}
DENSITY = {
    "full": ["os", "host", "kernel", "uptime", "packages", "shell", "display", "de", "wm", "wmtheme", "theme", "icons",
             "font", "cursor", "terminal", "terminalfont", "cpu", "gpu", "memory", "swap", "disk", "localip", "battery",
             "locale"],
    "short": ["os", "host", "kernel", "uptime", "packages", "shell", "wm", "terminal", "cpu", "gpu", "memory", "disk"],
    "mini": ["os", "kernel", "uptime", "cpu", "memory"],
}
HARD = ["host", "cpu", "gpu", "memory", "disk", "display", "battery"]
SOFT = ["os", "kernel", "wm", "shell", "terminal", "packages", "uptime"]
CARD = {"full": ["host", "os", "kernel", "packages", "wm", "shell", "terminal", "cpu", "gpu", "memory", "disk", "uptime"],
        "short": ["os", "kernel", "packages", "cpu", "memory", "disk", "uptime"], "mini": ["os", "cpu", "memory", "uptime"]}


def module(style: str, name: str, key: str) -> dict:
    m: dict = {"type": name, "key": key}
    if name == "os":
        m["format"] = f"{OS_NAME[style]} · sur {{pretty-name}}" if style in OS_NAME else "{pretty-name} {arch}"
    elif name == "disk":
        m["folders"] = "/"
    elif name == "cpu":
        m["format"] = "{name} ({cores-logical}) @ {freq-max}"
    elif name == "wm":
        m["format"] = "{pretty-name} ({protocol-name})"
    return m


def labels(style: str, lang: str) -> dict:
    base = dict(LABELS.get(lang, LABELS["fr"]))
    if style in ("espace", "cosmos"):
        base.update(SPACE.get(lang, SPACE["fr"]))
    return base


def classic(style: str, density: str, lang: str, color: str) -> list:
    k = labels(style, lang)
    mods: list = [{"type": "title", "format": "{user-name-colored}{at-symbol-colored}{host-name-colored}"}, "separator"]
    pre = "│ " if style == "kali" else ""
    if style == "kali":
        mods[1] = {"type": "custom", "format": "┌──(kali㉿{#1}liquid-glass{#})"}
    mods += [module(style, n, pre + k[n]) for n in DENSITY[density]]
    if density != "mini":
        mods += ["break", {"type": "colors", "paddingLeft": 0, "symbol": "block"}]
    return mods


def box(style: str, density: str, lang: str, color: str) -> list:
    k = labels(style, lang)
    width = 46

    def rule(title: str, left: str = "┌", right: str = "┐") -> dict:
        side = (width - len(title) - 4) // 2
        line = "─" * side
        return {"type": "custom", "format": f"{left}{line}  {{#1}}{title}{{#}}  {line}{right}"}

    def rows(names: list[str]) -> list:
        return [module(style, n, f"  {ICON.get(n, '•')}  ::") for n in names]

    take = {"full": 7, "short": 5, "mini": 3}[density]
    mods: list = [rule(k["hard"]), *rows(HARD[:take]), "break", rule(k["soft"]), *rows(SOFT[:take])]
    mods += [{"type": "custom", "format": "└" + "─" * (width - 1) + "┘"}]
    if density != "mini":
        mods += [{"type": "colors", "paddingLeft": 2, "symbol": "circle"}]
    return mods


def card(style: str, density: str, lang: str, color: str) -> list:
    k = labels(style, lang)
    names = CARD[density]
    inner = max(len(k[n]) for n in names) + 5
    mods: list = [{"type": "custom", "format": f"╭{'─' * inner}╮"}]
    mods += [module(style, n, f"│ {ICON.get(n, '•')}  {k[n]:<{inner - 5}} │") for n in names]
    mods += [{"type": "custom", "format": f"╰{'─' * inner}╯"}]
    if density != "mini":
        mods += [{"type": "colors", "paddingLeft": 2, "symbol": "circle"}]
    return mods


KINDS = {"classic": classic, "box": box, "card": card}


def config(style: str, density: str = "full", lang: str = "fr", logo: dict | None = None) -> dict:
    kind, color, _, _ = STYLES.get(style, STYLES["gouts"])
    key_width = 0 if kind != "classic" else 14
    return {"$schema": SCHEMA, "logo": logo if logo is not None else default_logo(style),
            "display": {"separator": " " if kind != "classic" else ": ", "key": {"width": key_width},
                        "color": {"keys": color, "title": color}, "bar": {"width": 12}, "disableLinewrap": True,
                        "percent": {"type": 3}},
            "modules": KINDS[kind](style, density, lang, color)}


def builtin_logo(style: str) -> dict:
    return {"source": BUILTIN[style], "padding": {"top": 1, "left": 1, "right": 3}}


def art_path(name: str) -> Path | None:
    for ext in (".jpg", ".png"):
        p = lg_art.ART_DIR / (name + ext)
        if p.exists():
            return p
    return None


def ansi_of(color: str) -> str:
    return {"red": "31", "green": "32", "yellow": "33", "blue": "34", "magenta": "35", "cyan": "36",
            "white": "37"}.get(color, "")


def ascii_logo(path: Path, w: int, h: int, color: bool, tint: str, position: str = "left") -> dict:
    f = lg_art.cached(path, w, h, color=color, ansi="" if color else ansi_of(tint))
    return {"type": "file-raw", "source": str(f), "width": w, "height": h, "position": position,
            "padding": {"top": 1, "left": 1, "right": 3}}


def cell_size() -> tuple[int, int]:
    """Taille d'une case en pixels, telle que le terminal la déclare."""
    try:
        rows, cols, xp, yp = struct.unpack("HHHH", fcntl.ioctl(1, termios.TIOCGWINSZ, b"\0" * 8))
        return (xp // cols, yp // rows) if xp and yp and cols and rows else (0, 0)
    except OSError:
        return 0, 0


def sixel_file(path: Path, w: int, h: int) -> Path | None:
    """Vraie image (sixel), à la taille exacte de w×h cases : foot l'affiche à côté de la fiche."""
    cw, ch = cell_size()
    if not cw:
        return None
    f = lg_art.CACHE / f"six-{path.stem}-{w * cw}x{h * ch}.six"
    if not f.exists() or f.stat().st_size == 0:
        f.parent.mkdir(parents=True, exist_ok=True)
        subprocess.run(["magick", str(path) + "[0]", "-background", "black", "-alpha", "remove", "-resize", f"{w * cw}x{h * ch}^",
                        "-gravity", "center", "-extent", f"{w * cw}x{h * ch}", "-colors", "200", f"sixel:{f}"], timeout=30)
    return f if f.exists() and f.stat().st_size else None


def default_logo(style: str) -> dict:
    """Logo du `fastfetch` tapé à la main : celui de la distribution, ou une image du style."""
    if style in BUILTIN:
        return builtin_logo(style)
    _, color, art, _ = STYLES.get(style, STYLES["gouts"])
    p = art_path(art[0]) if art else None
    return ascii_logo(p, 40, 20, True, color) if p else {"type": "small"}


def banner_logo(text: str, width: int, tint: str) -> dict | None:
    lines, _ = lg_art.banner(text, width)
    if not lines or len(lines) < 3:
        return None
    w = max(map(len, lines))
    f = lg_art.CACHE / f"banner-{abs(hash((text, tuple(lines))))}.txt"
    f.parent.mkdir(parents=True, exist_ok=True)
    code = ansi_of(tint) or "1"
    f.write_text("\n".join(f"\x1b[{code}m{x}\x1b[0m" for x in lines) + "\n")
    return {"type": "file-raw", "source": str(f), "width": w, "height": len(lines), "position": "top",
            "padding": {"top": 1, "left": 1, "right": 1}}


def choose(style: str, cols: int, rows: int, mode: str = "") -> tuple[dict, str]:
    """Logo et densité qui tiennent dans le terminal. mode : ascii, color, image, text ou vide."""
    kind, color, art, word = STYLES.get(style, STYLES["gouts"])
    info = 46 if kind == "classic" else 44      # les lignes trop longues sont coupées, pas repliées
    density = "full" if rows >= 29 else "short" if rows >= 17 else "mini"
    room = cols - info - 5
    if style in BUILTIN:
        return (builtin_logo(style) if room >= 34 else {"type": "none"}), density
    names = art or [p.stem for p in lg_art.gallery()]
    own = [p for p in lg_art.gallery(own_only=True)]
    pick = random.choice(own) if own and random.random() < 0.5 else art_path(random.choice(names))
    mode = mode or random.choice(["ascii", "ascii", "color", "color", "image", "text"])
    if mode == "text" and rows >= 26 and cols >= 50:
        logo = banner_logo(word, cols - 4, color)
        if logo:
            return logo, "short" if rows >= 34 else "mini"
    if room < 18 or not pick:
        return {"type": "none"}, density
    w = min(room, 64, int((rows - 3) * 2.05))
    h = max(6, int(w / 2.05))
    if mode == "image" and (f := sixel_file(pick, w, h)):
        # La fiche réserve la place avec un logo vide ; liquid-glass-fetch dessine l'image avant.
        blank = lg_art.CACHE / f"blank-{h}.txt"
        blank.write_text("\n" * (h - 1))
        return {"type": "file-raw", "source": str(blank), "width": w, "height": h, "sixel": str(f),
                "padding": {"top": 1, "left": 1, "right": 3}}, density
    return ascii_logo(pick, w, h, mode == "color", color), density


def write_default(style: str, dest: Path, lang: str = "fr") -> None:
    """Écrit la fiche du bureau, sans toucher à un fichier que tu aurais fait toi-même."""
    if dest.is_symlink():
        dest.unlink()
    elif dest.exists() and not dest.read_text(errors="ignore").startswith(MARK):
        return
    dest.parent.mkdir(parents=True, exist_ok=True)
    dest.write_text(MARK + json.dumps(config(style, "full", lang), ensure_ascii=False, indent=2) + "\n")
