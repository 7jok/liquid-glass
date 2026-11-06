#!/usr/bin/env python3
"""Liquid Glass — génère le logo fastfetch en pixel art (blocs de texte).

Une goutte de verre dessinée à la main sur une grille de 16 × 18 « pixels ».
Chaque pixel vaut deux caractères █, ce qui le rend carré dans un terminal.
L'ombrage est fait en paliers, comme en pixel art : reflet blanc en haut à
gauche, dégradé du cyan au bleu-violet, contour clair côté lumière et sombre
côté ombre, petit éclat en bas à droite.

Les chiffres sont les couleurs $1…$7 de fastfetch, définies (en 24 bits) dans
terminal/fastfetch/config.jsonc :
  1 reflet   2 bleu glace   3 cyan   4 azur   5 bleu-violet
  6 contour clair   7 contour sombre

Usage : gen-fastfetch-logo.py [sortie]   (défaut : terminal/fastfetch/logo.txt)
"""
from __future__ import annotations

import sys
from pathlib import Path

ART = """
.......67.......
.......67.......
......6337......
......6347......
.....623447.....
.....623447.....
....62334457....
...6123344557...
..612334444557..
..612334444557..
.61223344444557.
.61233444444557.
.62333444444557.
.63334444442557.
..633444445557..
..734444455557..
...7744455577...
.....777777.....
"""


def render(art: str) -> str:
    rows = [r for r in art.strip("\n").splitlines()]
    width = max(len(r) for r in rows)
    out = []
    for r in rows:
        r = r.ljust(width, ".")
        s, cur = "", None
        for ch in r:
            if ch == ".":
                s += "  "
                continue
            if ch != cur:
                s += f"${ch}"
                cur = ch
            s += "██"
        out.append(s.rstrip())
    return "\n".join(out) + "\n"


if __name__ == "__main__":
    dest = Path(sys.argv[1]) if len(sys.argv) > 1 else Path(__file__).resolve().parent.parent / "terminal/fastfetch/logo.txt"
    dest.write_text(render(ART))
    print(dest)
