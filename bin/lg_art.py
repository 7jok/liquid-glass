"""Images et textes en ASCII, sans dépendance : magick lit les images, les polices FIGlet
sont de simples fichiers texte (assets/figlet). Sert à liquid-glass-fetch, aux scènes de
liquid-glass-tty et à `liquid-glass ascii`.
"""
import hashlib
import os
import random
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
ART_DIR = ROOT / "assets/art"
FONT_DIR = ROOT / "assets/figlet"
LOOP_DIR = ROOT / "assets/loops"
CACHE = Path.home() / ".cache/liquid-glass/art"
RAMP = " .:-=+*#%@"
# Ces images ont un fond clair : on inverse pour que le trait soit dense sur fond sombre.
LIGHT_PAPER = {"vitruve", "riders"}
IMAGE_EXT = (".jpg", ".jpeg", ".png", ".webp")
VIDEO_EXT = (".mp4", ".webm", ".mkv", ".mov", ".gif", ".ogv")


def gallery(own_only: bool = False) -> list[Path]:
    """Tes images d'abord (~/Images/ascii, ~/Pictures/ascii), puis celles du dépôt."""
    home = Path.home()
    found: list[Path] = []
    for d in (home / "Images/ascii", home / "Pictures/ascii"):
        if d.is_dir():
            found += sorted(p for p in d.iterdir() if p.suffix.lower() in IMAGE_EXT)
    if not own_only and ART_DIR.is_dir():
        found += sorted(p for p in ART_DIR.iterdir() if p.suffix.lower() in IMAGE_EXT)
    return found


def loops() -> list[Path]:
    home = Path.home()
    found: list[Path] = []
    for d in (home / "Vidéos/ascii", home / "Videos/ascii", home / ".local/share/liquid-glass/videos", LOOP_DIR):
        if d.is_dir():
            found += sorted(p for p in d.iterdir() if p.suffix.lower() in VIDEO_EXT)
    return found


def pixels(path, w: int, h: int, fit: str = "cover") -> bytes:
    """Image réduite à w×h cases, en RGB. Une case fait deux fois plus haut que large."""
    src = str(path) + "[0]"
    if fit == "contain":
        size = ["-resize", f"{w}x{h * 2}", "-background", "black", "-gravity", "center", "-extent", f"{w}x{h * 2}"]
    else:
        size = ["-resize", f"{w}x{h * 2}^", "-gravity", "center", "-extent", f"{w}x{h * 2}"]
    cmd = ["magick", src, "-auto-orient", "-background", "black", "-alpha", "remove", *size,
           "-resize", f"{w}x{h}!", "-normalize", "-unsharp", "0x1", "-depth", "8", "rgb:-"]
    out = subprocess.run(cmd, capture_output=True, timeout=30).stdout
    return out if len(out) == w * h * 3 else b""


def luma(r: int, g: int, b: int) -> float:
    return (0.2126 * r + 0.7152 * g + 0.0722 * b) / 255


def grid(path, w: int, h: int, invert: bool | None = None, fit: str = "cover") -> list[list[tuple]]:
    """Cases (caractère, couleur) d'une image."""
    if invert is None:
        invert = Path(path).stem in LIGHT_PAPER
    px = pixels(path, w, h, fit)
    rows = []
    top = len(RAMP) - 1
    for y in range(h if px else 0):
        row = []
        for x in range(w):
            i = (y * w + x) * 3
            r, g, b = px[i], px[i + 1], px[i + 2]
            v = luma(r, g, b)
            v = 1 - v if invert else v
            row.append((RAMP[min(top, int(v * (top + 1)))], (r, g, b)))
        rows.append(row)
    return rows


def render(path, w: int, h: int, color: bool = False, ansi: str = "", invert: bool | None = None,
           fit: str = "cover") -> list[str]:
    """Lignes prêtes à imprimer. color : vraies couleurs ; ansi : une teinte du terminal."""
    out = []
    for row in grid(path, w, h, invert, fit):
        if not color:
            line = "".join(c for c, _ in row).rstrip()
            out.append(f"\x1b[{ansi}m{line}\x1b[0m" if ansi else line)
            continue
        parts, last = [], None
        for ch, (r, g, b) in row:
            k = (r >> 3, g >> 3, b >> 3)
            if ch != " " and k != last:
                parts.append(f"\x1b[38;2;{r};{g};{b}m")
                last = k
            parts.append(ch)
        out.append("".join(parts).rstrip() + "\x1b[0m")
    return out


BAYER = (0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5)


def braille(path, w: int, h: int, ansi: str = "", invert: bool | None = None) -> list[str]:
    """Image en points braille tramés : huit points par case, assez fin pour dessiner une
    silhouette nette, là où des lettres donneraient une bouillie."""
    if invert is None:
        invert = Path(path).stem in LIGHT_PAPER
    pw, ph = w * 2, h * 4
    cmd = ["magick", str(path) + "[0]", "-auto-orient", "-background", "black", "-alpha", "remove",
           "-resize", f"{pw}x{ph}^", "-gravity", "center", "-extent", f"{pw}x{ph}",
           "-colorspace", "Gray", "-normalize", "-gamma", "1.35", "-sigmoidal-contrast", "4x45%", "-depth", "8", "gray:-"]
    px = subprocess.run(cmd, capture_output=True, timeout=30).stdout
    if len(px) != pw * ph:
        return []
    bits = ((0, 0, 1), (0, 1, 2), (0, 2, 4), (1, 0, 8), (1, 1, 16), (1, 2, 32), (0, 3, 64), (1, 3, 128))
    out = []
    for y in range(h):
        row = []
        for x in range(w):
            v = 0
            for dx, dy, bit in bits:
                xx, yy = x * 2 + dx, y * 4 + dy
                g = px[yy * pw + xx]
                g = 255 - g if invert else g
                if g > 92 + BAYER[(yy & 3) * 4 + (xx & 3)] * 5:     # trame serrée : aplats nets, pas de brouillard
                    v |= bit
            row.append(chr(0x2800 + v) if v else " ")
        line = "".join(row).rstrip()
        out.append(f"\x1b[{ansi}m{line}\x1b[0m" if ansi else line)
    return out


def sixel(path, cols: int, rows: int, cw: int, ch: int, fit: str = "cover") -> bytes:
    """Vraie image à la taille exacte de cols×rows cases, mise en cache."""
    src = Path(path)
    key = f"{src.resolve()}{src.stat().st_mtime_ns}{cols}x{rows}@{cw}x{ch}{fit}"
    f = CACHE / (hashlib.sha1(key.encode()).hexdigest()[:16] + ".six")
    if not f.exists() or f.stat().st_size == 0:
        CACHE.mkdir(parents=True, exist_ok=True)
        size = f"{cols * cw}x{rows * ch}"
        grow = ["-resize", size + "^", "-gravity", "center", "-extent", size] if fit == "cover" else ["-resize", size]
        subprocess.run(["magick", str(src) + "[0]", "-auto-orient", "-background", "#0c0c12", "-alpha", "remove",
                        *grow, "-colors", "230", f"sixel:{f}"], timeout=40)
    return f.read_bytes() if f.exists() else b""


def cached(path, w: int, h: int, color: bool = False, ansi: str = "", invert: bool | None = None) -> Path:
    """Même chose, écrit dans un fichier pour le logo de fastfetch."""
    src = Path(path)
    key = f"{src.resolve()}{src.stat().st_mtime_ns}{w}x{h}{color}{ansi}{invert}"
    f = CACHE / (hashlib.sha1(key.encode()).hexdigest()[:16] + ".txt")
    if not f.exists() or f.stat().st_size == 0:
        CACHE.mkdir(parents=True, exist_ok=True)
        f.write_text("\n".join(render(src, w, h, color, ansi, invert)) + "\n")
    return f


# ------------------------------------------------------------------ texte FIGlet
class Figlet:
    """Lit une police .flf. Les lettres sont rapprochées jusqu'à se toucher (crénage)."""

    def __init__(self, name: str):
        self.name = name
        data = (FONT_DIR / f"{name}.flf").read_bytes()
        try:
            raw = data.decode("utf-8").split("\n")
        except UnicodeDecodeError:
            raw = data.decode("latin-1").split("\n")
        head = raw[0].split()
        self.blank = head[0][-1]
        self.height = int(head[1])
        start = 1 + int(head[5])
        self.glyphs: dict[int, list[str]] = {}
        code, i = 32, start
        while code < 127 and i + self.height <= len(raw):
            self.glyphs[code] = [self._clean(x) for x in raw[i:i + self.height]]
            i += self.height
            code += 1

    @staticmethod
    def _clean(line: str) -> str:
        line = line.rstrip("\r ")
        return line.rstrip(line[-1]) if line else line

    def glyph(self, ch: str) -> list[str]:
        g = self.glyphs.get(ord(ch)) or self.glyphs.get(ord(ch.upper())) or self.glyphs.get(32) or [""] * self.height
        width = max(len(x) for x in g)
        return [x.ljust(width) for x in g]

    def render(self, text: str) -> list[str]:
        rows = [""] * self.height
        for ch in text:
            g = self.glyph(ch)
            # Décalage possible : plus petit vide cumulé entre le texte et la lettre, ligne par ligne.
            room = min((len(r) - len(r.rstrip())) + (len(x) - len(x.lstrip())) for r, x in zip(rows, g)) if rows[0] else 0
            cut = max(0, room - 1) if ch != " " else 0
            for i, x in enumerate(g):
                left = rows[i]
                keep = max(0, len(left) - cut)
                over = left[keep:]
                merged = "".join(b if b != " " else a for a, b in zip(over.ljust(len(x[:cut])), x[:cut]))
                rows[i] = left[:keep] + merged + x[cut:]
        return [r.replace(self.blank, " ").rstrip() for r in rows]


def fonts() -> list[str]:
    return sorted(p.stem for p in FONT_DIR.glob("*.flf")) if FONT_DIR.is_dir() else []


def banner(text: str, width: int = 0, font: str = "") -> tuple[list[str], str]:
    """Texte en grand. Sans police imposée, en tire une au sort parmi celles qui tiennent."""
    names = [font] if font else random.sample(fonts(), len(fonts()))
    best: list[str] = [text]
    used = ""
    for name in names:
        try:
            lines = Figlet(name).render(text)
        except (OSError, ValueError, IndexError):
            continue
        while lines and not lines[-1].strip():
            lines.pop()
        while lines and not lines[0].strip():
            lines.pop(0)
        if lines and (not width or max(map(len, lines)) <= width):
            return lines, name
        if font:
            best, used = lines, name
    return best, used


def theme_backgrounds() -> list[Path]:
    d = Path.home() / ".local/state/omarchy/current/theme/backgrounds"
    return sorted(p for p in d.iterdir() if p.suffix.lower() in IMAGE_EXT) if d.is_dir() else []


def style_backgrounds(style: str) -> list[Path]:
    d = Path.home() / ".config/omarchy/themes" / style / "backgrounds"
    found = sorted(p for p in d.iterdir() if p.suffix.lower() in IMAGE_EXT) if d.is_dir() else []
    return found or theme_backgrounds()


def wallpaper() -> Path | None:
    p = Path.home() / ".local/state/omarchy/current/background"
    return p if p.exists() else next(iter(theme_backgrounds()), None)


def terminal_size() -> tuple[int, int]:
    try:
        s = os.get_terminal_size(1)
        return s.columns, s.lines
    except OSError:
        return 100, 40
