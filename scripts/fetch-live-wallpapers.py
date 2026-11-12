#!/usr/bin/env python3
"""Fonds d'écran animés (vidéos en boucle) : Minecraft et pixel art.

    scripts/fetch-live-wallpapers.py            Minecraft (tout) + pixel art
    scripts/fetch-live-wallpapers.py minecraft  seulement une catégorie
    TOTAL=200 scripts/fetch-live-wallpapers.py  complète en pixel art jusqu'à 200 fonds (défaut)
    scripts/fetch-live-wallpapers.py shrink     réduit en 1080p les fonds plus grands
    scripts/fetch-live-wallpapers.py link       refaire seulement les liens

Sources gratuites, en 1080p : MoeWalls, MotionBGs et DesktopHut. Le son est
retiré, la vidéo n'est pas réencodée. Les vidéos vont dans
~/.local/share/liquid-glass/live/<catégorie>-<nom>.mp4, une affiche par vidéo
dans ~/.cache/liquid-glass/posters/ (carrousel ⌃⌘Espace, catégorie
« Animés » ; Réglages → Fond d'écran, « Dynamiques »). Un lien vers chaque vidéo est mis dans
~/.config/omarchy/backgrounds/<thème>/ pour tous les thèmes : le sélecteur de
fond d'Omarchy les montre donc partout. Un même fond pris sur deux sites n'est
gardé qu'une fois (empreinte de la première image).
"""
import os
import re
import shutil
import subprocess
import sys
import tempfile
import time
import urllib.parse
import urllib.request
from pathlib import Path

HOME = Path.home()
LIVE = HOME / ".local/share/liquid-glass/live"
THUMBS = HOME / ".cache/liquid-glass/posters"      # même dossier que Réglages → Fond d'écran
UA = "Mozilla/5.0 (X11; Linux x86_64; rv:130.0) Gecko/20100101 Firefox/130.0"
PIXEL = int(os.environ.get("PIXEL", "60"))


def get(url: str, referer: str = "") -> bytes:
    req = urllib.request.Request(url, headers={"User-Agent": UA, **({"Referer": referer} if referer else {})})
    with urllib.request.urlopen(req, timeout=60) as r:
        return r.read()


def page(url: str) -> str:
    try:
        return get(url).decode("utf-8", "replace")
    except Exception as e:  # noqa: BLE001 — une page absente ne doit pas tout arrêter
        print(f"  ! {url} : {e}", file=sys.stderr)
        return ""


# --- Listes : (nom court, fonction qui renvoie l'URL de la vidéo, page) -------------

def moewalls(query: str, tag: str, keep) -> list[tuple[str, str, str]]:
    links: set[str] = set()
    for base in (f"https://moewalls.com/page/{{p}}/?s={query}", f"https://moewalls.com/tag/{tag}/page/{{p}}/"):
        for p in range(1, 30):
            html = page(base.format(p=p))
            found = {u for u in re.findall(r'href="(https://moewalls\.com/[a-z-]+/[a-z0-9-]+/)"', html)
                     if keep(u) and "/tag/" not in u and "/page/" not in u and "/category/" not in u}
            if not found - links:
                break
            links |= found
            time.sleep(0.3)
    return [(u.rstrip("/").split("/")[-1], "moewalls", u) for u in sorted(links)]


def motionbgs(tag: str, limit: int = 10_000) -> list[tuple[str, str, str]]:
    slugs: list[str] = []
    for p in range(1, 30):
        html = page(f"https://motionbgs.com/tag:{tag}/" + (f"{p}/" if p > 1 else ""))
        for s in re.findall(r"href=/([a-z0-9-]+)[ >]", html):
            if s not in slugs:
                slugs.append(s)
        if "rel=next" not in html or len(slugs) >= limit:
            break
        time.sleep(0.3)
    return [(s, "motionbgs", f"https://motionbgs.com/{s}") for s in slugs]


def desktophut(query: str) -> list[tuple[str, str, str]]:
    slugs: list[str] = []
    for p in range(1, 10):
        html = page(f"https://www.desktophut.com/search/{query}?page={p}")
        new = [s for s in re.findall(r'href="/([a-z0-9-]+)"', html) if query in s and s not in slugs]
        if not new:
            break
        slugs += new
        time.sleep(0.3)
    return [(s, "desktophut", f"https://www.desktophut.com/{s}") for s in slugs]


def video_url(site: str, url: str) -> str:
    html = page(url)
    if site == "moewalls":
        # Le bouton « Download Wallpaper » (les autres data-url sont des boutons de partage).
        m = re.search(r'data-id\s*=\s*"\d+"\s*data-url\s*=\s*"([^"]+)"', html)
        return f"https://go.moewalls.com/download.php?video={m.group(1)}" if m else ""
    if site == "motionbgs":
        m = re.search(r"href=(/dl/hd/\d+)", html)
        return "https://motionbgs.com" + m.group(1) if m else ""
    m = re.search(r"https://media\.desktophut\.com/files/[^\"' ]+\.mp4", html)
    return m.group(0) if m else ""


# --- Vidéos -------------------------------------------------------------------------

def probe(f: Path) -> tuple[int, int]:
    out = subprocess.run(["ffprobe", "-v", "error", "-select_streams", "v:0", "-show_entries", "stream=width,height",
                          "-of", "csv=p=0", str(f)], capture_output=True, text=True).stdout.strip()
    try:
        w, h = out.split(",")[:2]
        return int(w), int(h)
    except ValueError:
        return 0, 0


def fingerprint(f: Path) -> int | None:
    """dHash 64 bits de l'image à 0,5 s : deux copies du même fond se ressemblent."""
    raw = subprocess.run(["ffmpeg", "-v", "error", "-ss", "0.5", "-i", str(f), "-frames:v", "1",
                          "-vf", "scale=9:8,format=gray", "-f", "rawvideo", "-"], capture_output=True).stdout
    if len(raw) < 72:
        return None
    bits = 0
    for y in range(8):
        for x in range(8):
            bits = (bits << 1) | (raw[y * 9 + x] > raw[y * 9 + x + 1])
    return bits


def thumb(f: Path) -> None:
    t = THUMBS / (f.stem + ".jpg")
    if not t.exists():
        subprocess.run(["ffmpeg", "-v", "error", "-y", "-ss", "1", "-i", str(f), "-frames:v", "1",
                        "-vf", "scale=480:300:force_original_aspect_ratio=increase,crop=480:300", "-q:v", "4", str(t)])


def clean_name(slug: str, cat: str) -> str:
    words = [w for w in slug.split("-") if w not in ("minecraft", "live", "wallpaper", "4k", "hd", "in", "the", "of")
             and not (len(w) == 4 and re.search(r"\d", w))]
    return f"{cat}-" + ("-".join(words) or slug)


def fetch(cat: str, items: list[tuple[str, str, str]], prints: dict[str, int], limit: int = 10_000) -> int:
    """Télécharge les pages pas encore vues (liste dans live/.vus, doublons et refus compris)."""
    done_file = LIVE / ".vus"
    done = set(done_file.read_text().split()) if done_file.exists() else set()
    added = 0
    for slug, site, url in items:
        if added >= limit:
            break
        if url in done:
            continue
        name = clean_name(slug, cat)
        while (LIVE / f"{name}.mp4").exists():                 # même nom, autre fond
            name += "-2"
        src = video_url(site, url)
        if src:
            ok = grab(name, site, url, src, prints)
            added += ok or 0
        if src and ok is not None:
            done.add(url)
            done_file.write_text("\n".join(sorted(done)) + "\n")
        time.sleep(0.5)
    return added


def to_1080(src: Path, out: Path, w: int) -> bool:
    """Sans le son ; au-dessus de 1080p, réduit en 1080p (un fond 4K coûte 4× plus à décoder)."""
    vid = ["-c", "copy"] if w <= 1920 else ["-vf", "scale=1920:-2:flags=lanczos", "-c:v", "libx264", "-preset", "medium",
                                            "-crf", "20", "-pix_fmt", "yuv420p"]
    return subprocess.run(["nice", "-n", "15", "ffmpeg", "-v", "error", "-y", "-i", str(src), "-map", "0:v:0", *vid, "-an",
                           "-movflags", "+faststart", str(out)]).returncode == 0


def shrink() -> None:
    """Fonds déjà téléchargés en plus de 1080p : réduits sur place."""
    for f in sorted(LIVE.glob("*.mp4")):
        w, _h = probe(f)
        if w > 1920:
            tmp = f.with_suffix(".part.mp4")
            if to_1080(f, tmp, w):
                tmp.replace(f)
                print(f"  ↓ {f.stem} : {w} px → 1920 px")
            else:
                tmp.unlink(missing_ok=True)


TOTAL = int(os.environ.get("TOTAL", "200"))


def grab(name: str, site: str, url: str, src: str, prints: dict[str, int]) -> int | None:
    """1 = ajouté, 0 = doublon ou refusé, None = échec réseau (on réessaiera)."""
    with tempfile.TemporaryDirectory(dir=LIVE) as tmp:
        raw, out = Path(tmp) / "raw", Path(tmp) / "out.mp4"
        try:
            raw.write_bytes(get(src, referer=url))
        except Exception as e:  # noqa: BLE001
            print(f"  ! {name} : {e}", file=sys.stderr)
            return None
        w, h = probe(raw)
        if w == 0:
            print(f"  ! {name} : pas une vidéo", file=sys.stderr)
            return None
        if w < 1280 or h > w:                                  # trop petit ou vertical (téléphone)
            print(f"  - {name} ignoré ({w}×{h})")
            return 0
        if not to_1080(raw, out, w):
            return None
        fp = fingerprint(out)
        twin = next((k for k, v in prints.items() if fp is not None and bin(v ^ fp).count("1") <= 6), None)
        if twin:
            print(f"  = {name} (déjà là : {twin})")
            return 0
        shutil.move(out, LIVE / f"{name}.mp4")
    if fp is not None:
        prints[name] = fp
    thumb(LIVE / f"{name}.mp4")
    print(f"  + {name} ({w}×{h}, {site})")
    return 1


def themes() -> set[str]:
    names = set()
    for root in (HOME / ".config/omarchy/themes", Path("/usr/share/omarchy/themes")):
        if root.is_dir():
            names |= {d.name for d in root.iterdir() if d.is_dir()}
    return names


def link() -> None:
    videos = sorted(LIVE.glob("*.mp4"))
    for v in videos:
        thumb(v)
    for t in sorted(themes()):
        d = HOME / ".config/omarchy/backgrounds" / t
        d.mkdir(parents=True, exist_ok=True)
        for old in d.iterdir():                                # vidéos supprimées depuis
            if old.is_symlink() and not old.exists():
                old.unlink()
        for v in videos:
            target = d / v.name
            if not target.exists():
                target.symlink_to(v)
    print(f"{len(videos)} fonds animés, liés dans {len(themes())} thèmes.")


def main() -> None:
    if not shutil.which("ffmpeg"):
        sys.exit("ffmpeg est nécessaire (sudo pacman -S ffmpeg)")
    LIVE.mkdir(parents=True, exist_ok=True)
    THUMBS.mkdir(parents=True, exist_ok=True)
    args = sys.argv[1:]
    if args == ["shrink"]:
        shrink()
        return
    if args != ["link"]:
        prints = {f.stem: fp for f in LIVE.glob("*.mp4") if (fp := fingerprint(f)) is not None}
        if not args or "minecraft" in args:
            print("Minecraft…")
            # MoeWalls d'abord : 60 images/s, la meilleure qualité des trois.
            n = fetch("minecraft", moewalls("minecraft", "minecraft", lambda u: "minecraft" in u), prints)
            n += fetch("minecraft", motionbgs("minecraft"), prints)
            n += fetch("minecraft", desktophut("minecraft"), prints)
            print(f"  {n} nouveaux")
        if not args or "pixel" in args:
            print("Pixel art…")
            # Assez de pixel art pour arriver à TOTAL fonds en tout (au moins PIXEL).
            have = len(list(LIVE.glob("pixel-*.mp4")))
            want = max(PIXEL, TOTAL - len(list(LIVE.glob("minecraft-*.mp4"))))
            items = [i for i in motionbgs("pixel", want * 2) if "minecraft" not in i[0]]
            n = fetch("pixel", items, prints, limit=want - have) if have < want else 0
            print(f"  {n} nouveaux")
    link()


if __name__ == "__main__":
    main()
