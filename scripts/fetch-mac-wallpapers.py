#!/usr/bin/env python3
"""Fonds d'écran officiels de macOS (de Cheetah à macOS 27 Golden Gate).

Récupérés une fois sur 512pixels.net et basicappleguy.com, réduits à 3840 px de
large (jpg 90) et rangés dans les thèmes du profil Mac :
  themes/liquid-glass/backgrounds/os-*.jpg       (clairs / jour)
  themes/liquid-glass-dark/backgrounds/os-*.jpg  (sombres / nuit)
Les .heic « dynamiques » (une image par moment de la journée) sont découpés en
dyn-<nom>-<n>.jpg dans ~/.local/share/liquid-glass/dynamic/ : liquid-glass.appearance
change d'image selon l'heure (Réglages → Fond d'écran → Dynamique).

Non versionnés (.gitignore). Relancer ne retélécharge que ce qui manque.
Usage : fetch-mac-wallpapers.py [--force]
"""
import os, subprocess, sys, urllib.request, shutil, tempfile

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
LIGHT = os.path.join(REPO, "themes/liquid-glass/backgrounds")
DARK = os.path.join(REPO, "themes/liquid-glass-dark/backgrounds")
DYN = os.path.expanduser("~/.local/share/liquid-glass/dynamic")
CACHE = os.path.expanduser("~/.cache/liquid-glass/os-walls")
P = "https://media.512pixels.net/downloads/macos-wallpapers-6k/"
B = "https://basicappleguy.com/s/"

# (nom, url, clair|sombre) ; l'ordre donne l'ordre d'affichage.
WALLS = [
    ("27-golden-gate", P + "27-Golden-Gate.png", "light"),
    ("27-golden-gate-sombre", P + "27-Golden-Gate-Dark.png", "dark"),
    ("27-golden-gate-pont", P + "27-Golden-Gate-Bridge.jpg", "light"),
    ("27-golden-gate-nuit", B + "GoldenGate_Mac_Night.jpg", "dark"),
    ("26-tahoe", P + "26-Tahoe-Light-6K.png", "light"),
    ("26-tahoe-sombre", P + "26-Tahoe-Dark-6K.png", "dark"),
    ("26-tahoe-plage-aube", P + "26-Tahoe-Beach-Dawn.png", "light"),
    ("26-tahoe-plage-jour", P + "26-Tahoe-Beach-Day.png", "light"),
    ("26-tahoe-plage-crepuscule", P + "26-Tahoe-Beach-Dusk.png", "dark"),
    ("26-tahoe-plage-nuit", P + "26-Tahoe-Beach-Night.png", "dark"),
    ("26-tiburon", B + "Tiburon_Mac.png", "light"),
    ("15-sequoia", P + "15-Sequoia-Light-6K.jpg", "light"),
    ("15-sequoia-sombre", P + "15-Sequoia-Dark-6K.jpg", "dark"),
    ("15-sequoia-lever", P + "15-Sequoia-Sunrise.png", "light"),
    ("14-sonoma", P + "14-Sonoma-Light.jpg", "light"),
    ("14-sonoma-sombre", P + "14-Sonoma-Dark.jpg", "dark"),
    ("14-sonoma-horizon", P + "14-Sonoma-Horizon.png", "light"),
    ("13-ventura", P + "13-Ventura-Light.jpg", "light"),
    ("13-ventura-sombre", P + "13-Ventura-Dark.jpg", "dark"),
    ("12-monterey", P + "12-Monterey-Light.jpg", "light"),
    ("12-monterey-sombre", P + "12-Monterey-Dark.jpg", "dark"),
    ("11-big-sur-couleur", P + "11-Big-Sur-Color-Day-6k.jpg", "light"),
    ("11-big-sur-couleur-nuit", P + "11-Big-Sur-Color-Night-6k.jpg", "dark"),
    ("11-big-sur", P + "11-Big-Sur-Day-6k.jpg", "light"),
    ("11-big-sur-nuit", P + "11-Big-Sur-Night-6k.jpg", "dark"),
    ("10.15-catalina", P + "10-15-Day-6k.jpg", "light"),
    ("10.15-catalina-nuit", P + "10-15-Night-6k.jpg", "dark"),
    ("10.14-mojave", P + "10-14-Day-6k.jpg", "light"),
    ("10.14-mojave-nuit", P + "10-14-Night-6k.jpg", "dark"),
    ("10.13-high-sierra", P + "10-13-6k.jpg", "light"),
    ("10.12-sierra", P + "10-12-6k.jpg", "light"),
    ("10.11-el-capitan", P + "10-11-6k.jpg", "dark"),
    ("10.10-yosemite", P + "10-10-6k.jpg", "light"),
    ("10.9-mavericks", P + "10-9-6k.jpg", "dark"),
    ("10.8-mountain-lion", P + "10-8-6k.jpg", "dark"),
    ("10.7-lion", P + "10-7-6k.jpg", "dark"),
    ("10.6-snow-leopard", P + "10-6-6k.jpg", "dark"),
    ("10.5-leopard", P + "10-5-6k.jpg", "dark"),
    ("10.4-tiger", P + "10-4-6k.jpg", "light"),
    ("10.3-panther", P + "10-3-6k.jpg", "light"),
    ("10.2-jaguar", P + "10-2-6k.jpg", "light"),
    ("10.0-cheetah", P + "10-0_10-1-6k.jpg", "light"),
]
# Fonds dynamiques : .heic à plusieurs images (jour → nuit).
DYNAMIC = [
    ("golden-gate", B + "Dynamic.heic"),
    ("sequoia", B + "SequoiaDynamic.heic"),
]


def get(url, dest):
    if os.path.exists(dest) and os.path.getsize(dest) > 10000:
        return True
    req = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0 (X11; Linux x86_64)"})
    try:
        with urllib.request.urlopen(req, timeout=120) as r, open(dest + ".part", "wb") as f:
            shutil.copyfileobj(r, f)
        os.replace(dest + ".part", dest)
        return True
    except Exception as e:
        print(f"  ! {url}: {e}", file=sys.stderr)
        return False


def shrink(src, dst):
    subprocess.run(["magick", src + "[0]", "-resize", "3840x3840>", "-quality", "90",
                    "-strip", dst], check=True)


def main():
    force = "--force" in sys.argv
    for d in (LIGHT, DARK, DYN, CACHE):
        os.makedirs(d, exist_ok=True)
    ok = 0
    for name, url, kind in WALLS:
        out = os.path.join(LIGHT if kind == "light" else DARK, f"os-{name}.jpg")
        if os.path.exists(out) and not force:
            ok += 1
            continue
        raw = os.path.join(CACHE, os.path.basename(url))
        print(f"→ {name}")
        if get(url, raw):
            try:
                shrink(raw, out)
                ok += 1
                os.remove(raw)
            except subprocess.CalledProcessError as e:
                print(f"  ! conversion {name}: {e}", file=sys.stderr)
    for name, url in DYNAMIC:
        if any(f.startswith(f"dyn-{name}-") for f in os.listdir(DYN)) and not force:
            continue
        raw = os.path.join(CACHE, f"{name}.heic")
        print(f"→ dynamique {name}")
        if not get(url, raw):
            continue
        tmp = tempfile.mkdtemp(dir=CACHE)
        # heif-convert -> une image par élément (primaire + suivantes)
        subprocess.run(["heif-convert", raw, os.path.join(tmp, "f.jpg")],
                       stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        frames = sorted(f for f in os.listdir(tmp) if f.endswith(".jpg"))
        for i, f in enumerate(frames):
            shrink(os.path.join(tmp, f), os.path.join(DYN, f"dyn-{name}-{i:02d}.jpg"))
        shutil.rmtree(tmp, ignore_errors=True)
        print(f"  {len(frames)} images")
    print(f"{ok}/{len(WALLS)} fonds macOS prêts")


if __name__ == "__main__":
    main()
