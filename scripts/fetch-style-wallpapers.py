#!/usr/bin/env python3
"""Fonds d'écran des styles Linux, pris sur Wallhaven (API publique, images SFW).

    scripts/fetch-style-wallpapers.py              tous les styles
    scripts/fetch-style-wallpapers.py mono foret   seulement ceux-là
    PER_QUERY=8 scripts/fetch-style-wallpapers.py  nombre d'images par recherche

Chaque style a ses recherches, inspirées des vidéos de référence (rices
Hyprland : forêts et lacs au couchant, manga en noir et blanc, brume violette,
pastel, Windows « bloom »…). Les images vont dans themes/<thème>/backgrounds/
sous le nom wh-<id>.<ext> (gitignoré) ; on ne télécharge jamais deux fois.
Filtres : 16:9, au moins 1920×1080, au plus 3840×2160, triées par pertinence.
"""
import json
import os
import sys
import time
import urllib.parse
import urllib.request
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
PER_QUERY = int(os.environ.get("PER_QUERY", "6"))
UA = "liquid-glass-wallpapers/1.0"

STYLES = {
    "blanc": ["white minimalism", "white architecture", "white aesthetic", "snow minimal", "white flowers"],
    "sombre": ["black minimalism", "dark japan", "dark mountains", "night city rain", "black and white photography"],
    "jouet": ["pastel", "kawaii", "colorful 3d render", "candy", "pastel clouds", "cute illustration", "colorful toys", "isometric room"],
    "violet": ["purple mountains", "purple night sky", "violet landscape", "purple mist", "purple anime", "purple city neon", "lavender anime"],
    "violet-aube": ["lavender field", "lilac sky", "purple sunrise", "soft purple"],
    "rose": ["pink pastel", "pink sky", "cherry blossom", "pink clouds", "pink aesthetic"],
    "windows": ["windows 11 bloom", "abstract blue", "blue gradient", "fluent design"],
    "windows-sombre": ["dark blue abstract", "windows 11 dark", "blue neon dark"],
    "mono": ["monochrome anime", "manga panel", "black and white anime", "monochrome illustration"],
    "mono-papier": ["foggy torii", "fog japan temple", "white minimal japan", "misty mountains monochrome", "snow shrine"],
    "mono-sakura": ["cherry blossom anime", "sakura tree", "pink japan street", "sakura night", "pink sunset anime"],
    "espace": ["black hole", "galaxy", "nebula", "planet space", "interstellar", "purple nebula", "mars planet", "astronaut", "saturn rings", "moon surface"],
    "cosmos": ["earth from space", "moon surface", "planet earth night", "astronaut earth"],
    "ruban": ["blue anime sky", "abstract blue shapes", "anime city blue", "red black abstract", "gold black abstract", "anime eye blue", "abstract ribbons"],
    "debian": ["debian", "debian linux", "abstract red dark", "red lines minimal"],
    "fedora": ["fedora linux", "abstract blue waves", "blue mountains illustration", "blue night sky"],
    "mint": ["linux mint", "green mountains", "green forest aerial", "mint green abstract"],
    "kali": ["kali linux", "dark blue dragon", "dark hacker", "dark blue circuit"],
    "arch": ["arch linux", "blue dark minimal", "dark blue mountains", "blue geometric dark"],
    "foret": ["forest lake", "mountain lake sunset", "pine forest", "misty forest", "camping night"],
    "ile": ["chainsaw man manga", "manga girl sketch", "monochrome anime girl", "manga panel white background", "anime line art", "black and white anime girl"],
    "infini": ["cherry blossom dark", "sakura night", "dark cherry blossom branch", "pink flowers dark", "sakura dark aesthetic", "cherry blossom night"],
    "lain": ["serial experiments lain", "cyberpunk anime", "retro anime aesthetic", "glitch art"],
}


NEED_FIRST = {"infini", "espace", "ruban", "mono-papier", "mono-sakura", "debian", "fedora", "mint", "kali", "arch"}


def get(url, timeout=30):
    req = urllib.request.Request(url, headers={"User-Agent": UA})
    with urllib.request.urlopen(req, timeout=timeout) as r:
        return r.read()


def search(q):
    params = {"q": q, "categories": "110", "purity": "100", "ratios": "16x9", "atleast": "1920x1080",
              "sorting": "relevance", "order": "desc"}
    data = json.loads(get("https://wallhaven.cc/api/v1/search?" + urllib.parse.urlencode(params)))
    return [w for w in data.get("data", []) if w.get("dimension_x", 0) <= 3840 and w.get("file_size", 0) < 9_000_000]


def main():
    want = sys.argv[1:] or list(STYLES)
    total = 0
    for theme in want:
        d = REPO / "themes" / theme / "backgrounds"
        d.mkdir(parents=True, exist_ok=True)
        have = {p.stem for p in d.iterdir()}
        for q in STYLES.get(theme, []):
            try:
                hits = search(q)
            except Exception as e:  # réseau, quota (45 req/min)
                print(f"[{theme}] recherche « {q} » : {e}", file=sys.stderr)
                time.sleep(3)
                continue
            n = 0
            for w in hits:
                if n >= PER_QUERY:
                    break
                name = "wh-" + w["id"]
                if name in have:
                    continue
                ext = Path(w["path"]).suffix or ".jpg"
                try:
                    (d / (name + ext)).write_bytes(get(w["path"], timeout=60))
                except Exception as e:
                    print(f"[{theme}] {w['path']} : {e}", file=sys.stderr)
                    continue
                have.add(name)
                n += 1
                total += 1
                time.sleep(0.4)
            print(f"[{theme}] « {q} » : {n} nouveaux", flush=True)
            time.sleep(1.4)
        # Fond de référence (sélecteur, premier choix du thème) : 01-<nom>.jpg.
        first = d / f"01-{theme.split('-')[-1]}.jpg"
        jpgs = sorted(d.glob("wh-*.jpg"))
        if theme in NEED_FIRST and not first.exists() and jpgs:
            first.write_bytes(jpgs[0].read_bytes())
    print(f"Terminé : {total} fonds téléchargés.")


if __name__ == "__main__":
    main()
