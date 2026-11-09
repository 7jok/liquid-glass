"""Fiches fastfetch de chaque bureau. Trois présentations : `classic` (longue liste, comme sur
les distributions), `box` (cadres et icônes) et `card` (carte arrondie). Trois densités selon
la place : full, short, mini. Couleurs ANSI : elles suivent le thème du terminal.
"""
import fcntl
import json
import os
import random
import struct
import sys
import termios
from pathlib import Path

import lg_art

SCHEMA = "https://github.com/fastfetch-cli/fastfetch/raw/dev/doc/json_schema.json"
MARK = "// liquid-glass : fiche générée, remplacée à chaque changement de bureau.\n"
BUILTIN = {"debian": "debian", "fedora": "fedora", "mint": "linuxmint", "kali": "kali", "arch": "arch", "mac": "macos"}
OS_NAME = {"debian": "Debian", "fedora": "Fedora", "mint": "Linux Mint", "kali": "Kali Linux", "arch": "Arch Linux"}
# clé : présentation, couleur des libellés, images, texte en grand.
STYLES = {
    "mac": ("classic", "blue", [], "MAC"),
    "omarchy": ("tree", "green", ["tux", "earth"], "OMARCHY"),
    "windows": ("frames", "cyan", ["fuji", "wave"], "WINDOWS"),
    "debian": ("classic", "red", [], "DEBIAN"),
    "fedora": ("classic", "blue", [], "FEDORA"),
    "mint": ("classic", "green", [], "MINT"),
    "kali": ("classic", "blue", [], "KALI"),
    "arch": ("classic", "cyan", [], "ARCH"),
    "blanc": ("frames", "default", ["vitruve", "riders", "wave"], "BLANC"),
    "sombre": ("tree", "white", ["riders", "aldrin", "pillars"], "SOMBRE"),
    "jouet": ("tree", "magenta", ["tux", "fuji", "starry"], "JOUET"),
    "violet": ("tree", "magenta", ["starry", "pillars", "wave"], "VIOLET"),
    "expressive": ("card", "yellow", ["starry", "wave", "fuji"], "EXPRESSIVE"),
    "mono": ("frames", "white", ["wave", "riders", "vitruve"], "MONO"),
    "foret": ("tree", "green", ["fuji", "wave", "starry"], "FORET"),
    "ruban": ("frames", "yellow", ["riders", "fuji", "wave"], "RUBAN"),
    "espace": ("frames", "cyan", ["saturn", "astronaut", "aldrin", "pillars"], "ESPACE"),
    "cosmos": ("box", "blue", ["earth", "earthrise", "aldrin", "saturn"], "COSMOS"),
    "ile": ("tree", "white", ["riders", "vitruve", "wave"], "ILE"),
    "gouts": ("tree", "magenta", ["starry", "wave", "tux", "earth"], "OMARCHY"),
    "hud": ("box", "white", ["earth", "tux"], "7JOKS"),
    "infini": ("tree", "magenta", ["starry", "fuji", "wave"], "INFINI"),
}
LABELS = {
    "fr": {"os": "OS", "host": "Hôte", "kernel": "Noyau", "uptime": "Allumé", "packages": "Paquets", "shell": "Shell",
           "display": "Écran", "de": "Bureau", "wm": "Fenêtres", "wmtheme": "Thème fen.", "theme": "Thème",
           "icons": "Icônes", "font": "Police", "cursor": "Curseur", "terminal": "Terminal", "terminalfont": "Police term.",
           "cpu": "Processeur", "gpu": "Carte vidéo", "memory": "Mémoire", "swap": "Échange", "disk": "Disque",
           "localip": "IP locale", "battery": "Batterie", "locale": "Langue", "hard": "Matériel", "soft": "Logiciel",
           "sys": "SYSTÈME", "desk": "BUREAU", "mach": "MATÉRIEL", "life": "Vie"},
    "en": {"os": "OS", "host": "Host", "kernel": "Kernel", "uptime": "Uptime", "packages": "Packages", "shell": "Shell",
           "display": "Display", "de": "DE", "wm": "WM", "wmtheme": "WM Theme", "theme": "Theme", "icons": "Icons",
           "font": "Font", "cursor": "Cursor", "terminal": "Terminal", "terminalfont": "Terminal Font", "cpu": "CPU",
           "gpu": "GPU", "memory": "Memory", "swap": "Swap", "disk": "Disk", "localip": "Local IP", "battery": "Battery",
           "locale": "Locale", "hard": "Hardware", "soft": "Software",
           "sys": "SYSTEM", "desk": "DESKTOP", "mach": "HARDWARE", "life": "Life"},
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


TREE = {"full": (["os", "kernel", "uptime", "packages", "shell"], ["de", "wm", "theme", "icons", "font", "terminal"],
                  ["cpu", "gpu", "memory", "disk", "battery", "localip"]),
        "short": (["os", "kernel", "uptime", "shell"], ["wm", "theme", "terminal"], ["cpu", "gpu", "memory", "disk"]),
        "mini": (["os", "kernel"], ["wm"], ["cpu", "memory"])}
COLORS3 = ("red", "yellow", "blue")


def tree(style: str, density: str, lang: str, color: str) -> list:
    """Sections de couleur, branches et flèches."""
    k = labels(style, lang)
    mods: list = [{"type": "title", "format": "{user-name-colored}{at-symbol-colored}{host-name-colored}"}, "separator"]
    for sec, tint, names in zip(("sys", "desk", "mach"), COLORS3, TREE[density]):
        mods.append({"type": "custom", "format": f"{{#1;{ansi_of(tint)}}}○ {k[sec]}{{#}}"})
        for i, n in enumerate(names):
            branch = "┗" if i == len(names) - 1 else "┣"
            mods.append({**module(style, n, f" {branch} {k[n]}"), "keyColor": tint})
        if density != "mini" and sec != "mach":
            mods.append("break")
    if density != "mini":
        mods += ["break", {"type": "colors", "paddingLeft": 2, "symbol": "circle"}]
    return mods


def frames(style: str, density: str, lang: str, color: str) -> list:
    """Cadres titrés et arbres d'icônes."""
    k = labels(style, lang)
    width = 46

    def head(title: str) -> dict:
        side = (width - len(title) - 2) // 2
        return {"type": "custom", "format": f"┌{'─' * side}{{#1}}{title}{{#}}{'─' * (width - side - len(title) - 2)}┐"}

    def foot() -> dict:
        return {"type": "custom", "format": f"└{'─' * width}┘"}

    def rows(names: list[str], tint: str) -> list:
        out = []
        for i, n in enumerate(names):
            branch = "└" if i == len(names) - 1 else "├"
            out.append({**module(style, n, f"  {branch} {ICON.get(n, '•')} "), "keyColor": tint})
        return out

    take = {"full": 6, "short": 4, "mini": 2}[density]
    mods: list = [head(k["hard"]), *rows(["cpu", "gpu", "memory", "disk", "battery", "display"][:take], "green"), foot()]
    if density != "mini":
        mods.append("break")
    mods += [head(k["soft"]), *rows(["os", "kernel", "packages", "wm", "shell", "terminal"][:take], "yellow"), foot()]
    if density == "full":
        mods += ["break", head(k["life"]), *rows(["uptime", "localip"], "magenta"), foot()]
    return mods


KINDS = {"classic": classic, "box": box, "card": card, "tree": tree, "frames": frames}


def config(style: str, density: str = "full", lang: str = "fr", logo: dict | None = None) -> dict:
    kind, color, _, _ = STYLES.get(style, STYLES["gouts"])
    key_width = 14 if kind == "classic" else 16 if kind == "tree" else 0
    return {"$schema": SCHEMA, "logo": logo if logo is not None else default_logo(style),
            "display": {"separator": ": " if kind == "classic" else " → " if kind == "tree" else " ", "key": {"width": key_width},
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


def cell_size() -> tuple[int, int]:
    """Taille d'une case en pixels, telle que le terminal la déclare."""
    try:
        with open("/dev/tty", "rb", buffering=0) as t:
            rows, cols, xp, yp = struct.unpack("HHHH", fcntl.ioctl(t, termios.TIOCGWINSZ, b"\0" * 8))
        return (xp // cols, yp // rows) if xp and yp and cols and rows else (0, 0)
    except OSError:
        return 0, 0


def default_logo(style: str) -> dict:
    """Logo du `fastfetch` tapé à la main : celui de la distribution, ou une image du bureau."""
    if style in BUILTIN:
        return builtin_logo(style)
    run = Path(__file__).resolve().parent / "liquid-glass-fetch"
    return {"type": "command-raw", "source": f"{run} --logo 42 21 --style {style}", "width": 42, "height": 21,
            "padding": {"top": 1, "left": 1, "right": 3}}


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


def pool(style: str, mode: str = "image") -> list[Path]:
    """Tes images, les fonds du bureau, puis les images du dépôt. Les points ont besoin d'un
    sujet net : ils laissent de côté les fonds d'écran, trop sombres ou trop chargés."""
    _, _, art, _ = STYLES.get(style, STYLES["gouts"])
    own = lg_art.gallery(own_only=True)
    mine = [p for p in (art_path(n) for n in art) if p]
    if mode != "image":
        return own + mine or lg_art.gallery()
    return own * 4 + lg_art.style_backgrounds(style) + mine * 3 or lg_art.gallery()


def choose(style: str, cols: int, rows: int, mode: str = "") -> tuple[dict, str]:
    """Logo et densité qui tiennent dans le terminal. mode : image, dots, color, text ou vide."""
    kind, color, _, word = STYLES.get(style, STYLES["gouts"])
    density = "full" if rows >= 27 else "short" if rows >= 17 else "mini"
    room = cols - (34 if density == "mini" else 50)
    if style in BUILTIN:
        return (builtin_logo(style) if room >= 34 else {"type": "none"}), density
    if style == "hud":          # 7JOKS : toujours le nom en grandes lettres, au-dessus de la fiche
        logo = banner_logo(word, cols - 4, color) if cols >= 40 else None
        return (logo or {"type": "none"}), "short" if rows >= 30 else "mini"
    cw, ch = cell_size()
    mode = mode or random.choice(["image"] * 6 + ["dots"] * 3 + ["color", "text"])
    if mode == "text" and rows >= 26 and cols >= 50:
        logo = banner_logo(word, cols - 4, color)
        if logo:
            return logo, "short" if rows >= 34 else "mini"
    if mode == "image" and not cw:
        mode = "dots"
    if mode not in ("image", "dots", "color"):
        mode = "dots"
    ratio = (ch / cw) if cw else 2.05
    src = random.choice(pool(style, mode))
    h = max(8, min(rows - 2, 34))
    w = min(room, int(h * ratio))
    if w >= 24:
        h = min(h, max(8, int(w / ratio)))
        return raw_logo(src, mode, w, h, color, cw, ch), density
    # Terminal étroit et haut : l'image passe au-dessus de la fiche.
    if rows >= 22:
        h = int(rows * 0.55)
        w = min(cols - 2, int(h * ratio))
        h = min(h, int(w / ratio))
        return {**raw_logo(src, mode, w, h, color, cw, ch), "position": "top"}, "mini"
    return {"type": "none"}, density


def raw_logo(src: Path, mode: str, w: int, h: int, tint: str, cw: int, ch: int) -> dict:
    """Fichier de logo. Une vraie image laisse sa place vide : foot l'efface si du texte
    s'écrit après elle sur les mêmes lignes, liquid-glass-fetch la pose donc à la fin."""
    f = lg_art.CACHE / f"logo-{os.getpid()}.txt"
    f.parent.mkdir(parents=True, exist_ok=True)
    logo = {"type": "file-raw", "source": str(f), "width": w, "height": h, "padding": {"top": 1, "left": 1, "right": 3}}
    data = lg_art.sixel(src, w, h, cw, ch) if mode == "image" else b""
    if data:
        logo["sixel"] = data
        f.write_bytes(b" \n" * h)
    else:
        f.write_bytes(text_logo(src, mode, w, h, tint))
    return logo


def text_logo(src: Path, mode: str, w: int, h: int, tint: str) -> bytes:
    if mode == "color" and w >= 30:
        return ("\n".join(lg_art.render(src, w, h, color=True)) + "\n").encode()
    ansi = ansi_of(tint) or "37"
    # Couleur vive : un point est fin. Le blanc d'un thème clair est sombre, on prend alors le texte du terminal.
    ansi = "39" if ansi.endswith(("7", "9")) else "9" + ansi[-1]
    return ("\n".join(lg_art.braille(src, w, h, ansi)) + "\n").encode()


def print_logo(style: str, w: int, h: int) -> None:
    """Logo du `fastfetch` tapé à la main : fastfetch lance cette commande à chaque fois, le
    dessin change donc à chaque terminal. Pas d'image ici : fastfetch écrit par-dessus."""
    _, color, _, _ = STYLES.get(style, STYLES["gouts"])
    sys.stdout.buffer.write(text_logo(random.choice(pool(style, "dots")), "dots", w, h, color))


def write_default(style: str, dest: Path, lang: str = "fr") -> None:
    """Écrit la fiche du bureau, sans toucher à un fichier que tu aurais fait toi-même."""
    if dest.is_symlink():
        dest.unlink()
    elif dest.exists() and not dest.read_text(errors="ignore").startswith(MARK):
        return
    dest.parent.mkdir(parents=True, exist_ok=True)
    dest.write_text(MARK + json.dumps(config(style, "full", lang), ensure_ascii=False, indent=2) + "\n")
