#!/usr/bin/env python3
"""Liquid Glass — fonds générés des styles Linux (aucune image externe).

Montagnes en couches dans la brume (style violet : nuit / aube / rose, et
variantes blanc / sombre / jouet). Chaque crête est tirée par déplacement du
point milieu, remplie d'une teinte qui s'assombrit vers l'avant, puis une bande
de brume en dégradé est posée au pied de chaque couche. Tout passe par
ImageMagick (`magick`) : rendu en 1280x720 puis agrandi en 2560x1440 avec un
grain léger contre le banding.

    scripts/gen-linux-wallpapers.py [dossier-thèmes]   (défaut : themes/ du dépôt)
"""
import random
import subprocess
import sys
from pathlib import Path

W, H = 1280, 720
OUT_W, OUT_H = 2560, 1440


def ridge(seed, base, amp, rough=0.48, n=7):
    """Crête : liste de points (x, y) de gauche à droite."""
    rnd = random.Random(seed)
    pts = [base + rnd.uniform(-amp, amp) * 0.5, base + rnd.uniform(-amp, amp) * 0.5]
    a = amp
    for _ in range(n):
        out = []
        for i in range(len(pts) - 1):
            out.append(pts[i])
            out.append((pts[i] + pts[i + 1]) / 2 + rnd.uniform(-a, a))
        out.append(pts[-1])
        pts = out
        a *= rough
    step = W / (len(pts) - 1)
    return [(round(i * step, 1), round(y, 1)) for i, y in enumerate(pts)]


def mix(c1, c2, t):
    a = [int(c1[i:i + 2], 16) for i in (1, 3, 5)]
    b = [int(c2[i:i + 2], 16) for i in (1, 3, 5)]
    return "#" + "".join(f"{round(a[i] + (b[i] - a[i]) * t):02x}" for i in range(3))


def rgba(c, a):
    r, g, b = (int(c[i:i + 2], 16) for i in (1, 3, 5))
    return f"rgba({r},{g},{b},{a})"


def mountains(out, sky_top, sky_bot, far, near, fog, layers=6, seed=1, sun=None, fog_a=0.55, stars=False):
    args = ["magick", "-size", f"{W}x{H}", f"gradient:{sky_top}-{sky_bot}"]
    if stars:
        rnd = random.Random(seed * 7)
        pts = " ".join(f"point {rnd.randint(0, W)},{rnd.randint(0, int(H * 0.45))}" for _ in range(160))
        args += ["-fill", rgba("#ffffff", 0.7), "-draw", pts]
    if sun:
        cx, cy, r, col = sun
        args += ["(", "-size", f"{W}x{H}", "xc:none", "-fill", col, "-draw", f"circle {cx},{cy} {cx + r},{cy}",
                 "-blur", "0x2", ")", "-composite",
                 "(", "-size", f"{W}x{H}", "xc:none", "-fill", rgba(col[:7] if col.startswith("#") else "#ffffff", 0.35),
                 "-draw", f"circle {cx},{cy} {cx + r * 2.2},{cy}", "-blur", "0x60", ")", "-composite"]
    for i in range(layers):
        t = i / max(1, layers - 1)
        base = H * (0.34 + 0.56 * t ** 1.15)
        amp = H * (0.16 - 0.08 * t)
        pts = ridge(seed * 100 + i, base, amp, rough=0.42 + 0.08 * t)
        poly = " ".join(f"{x},{y}" for x, y in pts) + f" {W},{H} 0,{H}"
        col = mix(far, near, t ** 0.9)
        blur = max(0.4, 3.2 * (1 - t))
        args += ["(", "-size", f"{W}x{H}", "xc:none", "-fill", col, "-draw", f"polygon {poly}", "-blur", f"0x{blur:.1f}", ")",
                 "-composite"]
        if i < layers - 1:
            # Brume au pied de la couche, qui s'efface vers le bas.
            top = int(min(y for _, y in pts) + amp * 0.6)
            hh = int(H * 0.22)
            args += ["(", "-size", f"{W}x{hh}", f"gradient:{rgba(fog, 0)}-{rgba(fog, fog_a * (1 - t * 0.6))}", ")",
                     "-geometry", f"+0+{top}", "-composite",
                     "(", "-size", f"{W}x{hh}", f"gradient:{rgba(fog, fog_a * (1 - t * 0.6))}-{rgba(fog, 0)}", ")",
                     "-geometry", f"+0+{top + hh}", "-composite"]
    args += ["-resize", f"{OUT_W}x{OUT_H}!",
             "(", "-size", f"{OUT_W}x{OUT_H}", "xc:gray50", "-attenuate", "0.25", "+noise", "Gaussian",
             "-colorspace", "gray", ")", "-compose", "overlay", "-composite", "-quality", "92", str(out)]
    subprocess.run(args, check=True)
    print("généré", out)


def lines(out, bg, ink, seed=3, n=46, amp=60):
    """Blanc : ondes en traits fins (line art), façon carte topographique."""
    rnd = random.Random(seed)
    draws = []
    for k in range(n):
        y0 = H * 0.2 + k * (H * 0.75 / n)
        pts = ridge(seed * 10 + k // 6, y0, amp * (0.6 + 0.4 * rnd.random()), rough=0.5, n=6)
        draws.append("polyline " + " ".join(f"{x},{y + k * 2}" for x, y in pts))
    args = ["magick", "-size", f"{W * 2}x{H * 2}", f"xc:{bg}", "-scale", "50%", "-fill", "none",
            "-stroke", ink, "-strokewidth", "0.8"]
    for d in draws:
        args += ["-draw", d]
    args += ["-resize", f"{OUT_W}x{OUT_H}!", "-quality", "94", str(out)]
    subprocess.run(args, check=True)
    print("généré", out)


def bloom(out, bg_top, bg_bot, petals, seed=2):
    """Windows : « fleur » de rubans translucides qui se replient au centre
    (dessin original : ellipses floues tournées autour d'un même pivot)."""
    cx, cy = W * 0.5, H * 0.5
    args = ["magick", "-size", f"{W}x{H}", f"gradient:{bg_top}-{bg_bot}"]
    for i, (ang, col, a, rx, ry, dx) in enumerate(petals):
        args += ["(", "-size", f"{W}x{H}", "xc:none", "-fill", rgba(col, a),
                 "-draw", f"ellipse {cx + dx},{cy} {rx},{ry} 0,360", "-blur", f"0x{3 + i % 3 * 2}",
                 "-distort", "SRT", f"{cx},{cy} 1 {ang}", ")", "-compose", "over", "-composite"]
        # liseré lumineux le long du ruban
        args += ["(", "-size", f"{W}x{H}", "xc:none", "-fill", "none", "-stroke", rgba("#ffffff", 0.35), "-strokewidth", "2",
                 "-draw", f"ellipse {cx + dx},{cy} {rx},{ry} 200,340", "-blur", "0x1.5",
                 "-distort", "SRT", f"{cx},{cy} 1 {ang}", ")", "-compose", "over", "-composite"]
    args += ["-resize", f"{OUT_W}x{OUT_H}!",
             "(", "-size", f"{OUT_W}x{OUT_H}", "xc:gray50", "-attenuate", "0.12", "+noise", "Gaussian",
             "-colorspace", "gray", ")", "-compose", "overlay", "-composite", "-quality", "93", str(out)]
    subprocess.run(args, check=True)
    print("généré", out)


def halftone(out, src):
    """Mono : une image passée en trame de points noir et blanc (fond noir)."""
    mean = float(subprocess.run(["magick", str(src), "-colorspace", "gray", "-format", "%[fx:mean]", "info:"],
                                capture_output=True, text=True).stdout or 0)
    args = ["magick", str(src), "-resize", f"{OUT_W}x{OUT_H}^", "-gravity", "center", "-extent", f"{OUT_W}x{OUT_H}",
            "-colorspace", "gray"]
    if mean > 0.5:
        args += ["-negate"]
    args += ["-sigmoidal-contrast", "6x55%", "-resize", "25%", "-ordered-dither", "h4x4a", "-filter", "point",
             "-resize", f"{OUT_W}x{OUT_H}!", "-blur", "0x0.7", "-level", "20%,80%", "-quality", "90", str(out)]
    subprocess.run(args, check=True)
    print("généré", out)


def forest(out, sky_top, sky_mid, sky_bot, glow, mtn_far, mtn_near, snow, trees, seed=3):
    """Forêt : ciel au couchant, sommets enneigés, ligne de sapins et lac qui
    reflète le tout."""
    rnd = random.Random(seed)
    horizon = int(H * 0.66)
    args = ["magick", "-size", f"{W}x{horizon // 2}", f"gradient:{sky_top}-{sky_mid}",
            "-size", f"{W}x{horizon - horizon // 2}", f"gradient:{sky_mid}-{sky_bot}", "-append"]
    # nuages en bandes
    for k in range(7):
        y = rnd.randint(int(horizon * 0.08), int(horizon * 0.5))
        args += ["(", "-size", f"{W}x{horizon}", "xc:none", "-fill", rgba(glow, 0.22 + rnd.random() * 0.2),
                 "-draw", f"ellipse {rnd.randint(0, W)},{y} {rnd.randint(160, 380)},{rnd.randint(8, 22)} 0,360",
                 "-blur", "0x14", ")", "-composite"]
    # sommets
    for i, (col, base, amp) in enumerate([(mtn_far, 0.36, 0.3), (mtn_near, 0.54, 0.14)]):
        pts = ridge(seed * 31 + i, H * base, H * amp, rough=0.5)
        poly = " ".join(f"{x},{y}" for x, y in pts) + f" {W},{horizon} 0,{horizon}"
        args += ["(", "-size", f"{W}x{horizon}", "xc:none", "-fill", col, "-draw", f"polygon {poly}", "-blur", "0x0.8", ")",
                 "-composite"]
        if i == 0:
            # neige : le haut de la crête, éclairé
            snow_poly = " ".join(f"{x},{y}" for x, y in pts) + " " + " ".join(f"{x},{y + H * (0.012 + 0.05 * max(0.0, (H * 0.36 - y) / (H * 0.3)))}" for x, y in reversed(pts))
            args += ["(", "-size", f"{W}x{horizon}", "xc:none", "-fill", rgba(snow, 0.85), "-draw", f"polygon {snow_poly}",
                     "-blur", "0x2", ")", "-composite"]
    # sapins
    tree_draw = []
    x = -10
    while x < W + 10:
        hgt = rnd.randint(40, 120) * (1.4 if rnd.random() < 0.15 else 1)
        w2 = hgt * 0.22
        base = horizon + 2
        tree_draw.append(f"polygon {x - w2:.0f},{base} {x:.0f},{base - hgt:.0f} {x + w2:.0f},{base}")
        x += rnd.randint(6, 16)
    args += ["(", "-size", f"{W}x{horizon}", "xc:none", "-fill", trees] + sum((["-draw", d] for d in tree_draw), []) + \
            ["-blur", "0x0.6", ")", "-composite"]
    # lac : reflet flou et assombri
    args += ["(", "+clone", "-flip", "-crop", f"{W}x{H - horizon}+0+0", "+repage", "-blur", "0x3",
             "-fill", trees, "-colorize", "35", ")", "-append",
             "(", "-size", f"{W}x{H - horizon}", "xc:none", "-fill", rgba("#ffffff", 0.05)]
    for k in range(40):
        y = rnd.randint(0, H - horizon)
        args += ["-draw", f"line {rnd.randint(0, W)},{y} {rnd.randint(0, W)},{y}"]
    args += [")", "-geometry", f"+0+{horizon}", "-composite"]
    args += ["-resize", f"{OUT_W}x{OUT_H}!",
             "(", "-size", f"{OUT_W}x{OUT_H}", "xc:gray50", "-attenuate", "0.25", "+noise", "Gaussian",
             "-colorspace", "gray", ")", "-compose", "overlay", "-composite", "-quality", "92", str(out)]
    subprocess.run(args, check=True)
    print("généré", out)


MONO_SOURCES = ["anime-281d5y.jpg", "anime-45g3x3.jpg", "anime-5gzq69.jpg", "anime-5yp939.jpg", "anime-3q9w3v.jpg",
                "anime-5gmrj5.jpg"]


def main():
    root = Path(sys.argv[1]) if len(sys.argv) > 1 else Path(__file__).resolve().parent.parent / "themes"
    v = root / "violet" / "backgrounds"
    va = root / "violet-aube" / "backgrounds"
    r = root / "rose" / "backgrounds"
    b = root / "blanc" / "backgrounds"
    s = root / "sombre" / "backgrounds"
    j = root / "jouet" / "backgrounds"
    w = root / "windows" / "backgrounds"
    wd = root / "windows-sombre" / "backgrounds"
    mo = root / "mono" / "backgrounds"
    fo = root / "foret" / "backgrounds"
    only = set(sys.argv[2:])
    for d in (v, va, r, b, s, j, w, wd, mo, fo):
        d.mkdir(parents=True, exist_ok=True)
    if "saisons" in only:
        return seasons(root)
    if only:
        return extra(w, wd, mo, fo, only)
    extra(w, wd, mo, fo, {"windows", "mono", "foret"})

    # Violet nuit : ciel prune, crêtes violettes, brume lavande.
    mountains(v / "01-violet-nuit.jpg", "#4c3a8a", "#5b4699", "#47367f", "#140b28", "#7a63b8", seed=4, fog_a=0.45)
    mountains(v / "02-violet-crepuscule.jpg", "#2c1f5c", "#8e5aa8", "#6b4a9e", "#0d0720", "#c48fd0", seed=9,
              sun=(880, 300, 70, "#ffd27a"))
    mountains(v / "03-violet-etoiles.jpg", "#1d1440", "#3d2c74", "#3a2b6e", "#0b0619", "#6a55a8", seed=31, fog_a=0.4,
              stars=True)
    mountains(v / "04-rose-nuit.jpg", "#3a1630", "#8a3e6a", "#7a3a66", "#14060f", "#d98fb4", seed=21, stars=True)
    # Violet aube : lilas clair.
    mountains(va / "01-violet-aube.jpg", "#efe6fb", "#d9c7f3", "#c4abee", "#3b2463", "#f4ecff", seed=4, fog_a=0.7)
    mountains(va / "02-lilas-soleil.jpg", "#f4eefc", "#e2d2f6", "#cdb6f2", "#4a2f7a", "#fbf7ff", seed=14, fog_a=0.7,
              sun=(980, 230, 64, "#fff3d6"))
    # Rose : pastel, brume crème.
    mountains(r / "01-rose-pastel.jpg", "#fdeef3", "#f8d3e1", "#f0b4c9", "#6e2f4a", "#fff4f7", seed=12, fog_a=0.7,
              sun=(360, 250, 60, "#fff6e8"))
    mountains(r / "02-rose-lavande.jpg", "#fbeaf4", "#e9d2f2", "#e2b5d6", "#5a2f62", "#fff6fb", seed=27, fog_a=0.7)

    # Blanc : papier et traits, ou montagnes neige.
    lines(b / "01-blanc-ondes.jpg", "#f7f7f7", "#1a1a1a")
    lines(b / "02-creme-ondes.jpg", "#fbf7ee", "#2b2723", seed=8)
    mountains(b / "03-blanc-neige.jpg", "#ffffff", "#eeeeee", "#e2e2e2", "#2a2a2a", "#ffffff", seed=6, fog_a=0.8)

    # Sombre : crêtes noires, brume grise.
    mountains(s / "01-sombre-crêtes.jpg", "#0a0a0a", "#1a1a1a", "#262626", "#020202", "#5a5a5a", seed=5, fog_a=0.35,
              stars=True)
    lines(s / "02-sombre-ondes.jpg", "#070707", "#d8d8d8", seed=11)

    # Jouet : bonbon.
    mountains(j / "01-jouet-bonbon.jpg", "#b9a2ff", "#ffd9ea", "#6ec6ff", "#ff5fa2", "#fff8ee", seed=7, fog_a=0.6,
              sun=(980, 200, 80, "#ffd23f"))
    mountains(j / "02-jouet-menthe.jpg", "#e9e0ff", "#7ee8cf", "#3ddbb4", "#1b1030", "#fffdf7", seed=17, fog_a=0.6)
    seasons(root)


def seasons(root):
    """Teintes du style violet ajoutées : crépuscule, lavande, prune et les quatre saisons."""
    d = {n: root / f"violet-{n}" / "backgrounds" for n in ("crepuscule", "lavande", "prune", "ete", "automne", "hiver", "printemps")}
    for p in d.values():
        p.mkdir(parents=True, exist_ok=True)
    mountains(d["crepuscule"] / "01-violet-crepuscule.jpg", "#2a1d55", "#e08a7a", "#8a5a9e", "#120a22", "#f0a88a", seed=19,
              sun=(760, 330, 80, "#ffd3a0"), fog_a=0.5)
    mountains(d["crepuscule"] / "02-crepuscule-etoiles.jpg", "#1a1240", "#b06a8e", "#6a4a8e", "#0c0718", "#d898b0", seed=37,
              stars=True, fog_a=0.45)
    mountains(d["lavande"] / "01-violet-lavande.jpg", "#f4f2fa", "#e2ddf0", "#cfc6e6", "#3d3554", "#faf8ff", seed=23, fog_a=0.72)
    mountains(d["lavande"] / "02-lavande-soleil.jpg", "#f7f4fb", "#e6def2", "#d2c4ea", "#4a3f6a", "#fdfbff", seed=41, fog_a=0.7,
              sun=(420, 240, 56, "#fff5e6"))
    mountains(d["prune"] / "01-violet-prune.jpg", "#3a1030", "#6e2550", "#5a1e44", "#12040e", "#b0507e", seed=13, fog_a=0.42,
              stars=True)
    mountains(d["prune"] / "02-prune-or.jpg", "#2a0a22", "#8a3a58", "#6a2a4a", "#0e030a", "#e09a8a", seed=29,
              sun=(1040, 280, 62, "#ffcf7a"))
    mountains(d["ete"] / "01-ete-coucher.jpg", "#ffd9b8", "#ffb0a0", "#e88aa0", "#5a2a5e", "#fff0e0", seed=8, fog_a=0.6,
              sun=(640, 300, 96, "#fff1b8"))
    mountains(d["ete"] / "02-ete-lilas.jpg", "#fde6d6", "#e8c6ee", "#f0a6b0", "#4a2a6a", "#fff6ee", seed=33, fog_a=0.62,
              sun=(1000, 220, 70, "#ffe08a"))
    mountains(d["automne"] / "01-automne-braise.jpg", "#3a1a24", "#c0603a", "#8a3a2e", "#140808", "#f0915a", seed=17, fog_a=0.45,
              sun=(980, 320, 70, "#ffc65a"))
    mountains(d["automne"] / "02-automne-prune.jpg", "#2a1426", "#8a4a3a", "#6a2e3a", "#0e0608", "#d9876a", seed=43, stars=True,
              fog_a=0.4)
    mountains(d["hiver"] / "01-hiver-neige.jpg", "#e8eef8", "#cdd8ee", "#b8c6e6", "#2c3a5e", "#ffffff", seed=11, fog_a=0.78)
    mountains(d["hiver"] / "02-hiver-aube.jpg", "#eef0fb", "#d8d2f0", "#c2c8ea", "#33406a", "#ffffff", seed=47, fog_a=0.75,
              sun=(760, 260, 58, "#fff8ee"))
    mountains(d["printemps"] / "01-printemps-cerisier.jpg", "#fdf0f4", "#f6d0de", "#b8dcc4", "#2f5a40", "#fff8fa", seed=25,
              fog_a=0.66, sun=(360, 230, 60, "#fff9e0"))
    mountains(d["printemps"] / "02-printemps-menthe.jpg", "#f1f8f2", "#d6ecdc", "#e8b8cc", "#334a38", "#fbfffb", seed=53,
              fog_a=0.66)


def extra(w, wd, mo, fo, only):
    if "windows" in only:
        blue = [(-28, "#0a5bd3", 0.85, 330, 120, -40), (-8, "#1f86f0", 0.8, 300, 110, 10), (12, "#4fb3ff", 0.75, 280, 95, 50),
                (32, "#2c74e8", 0.7, 260, 90, 80), (52, "#8fd0ff", 0.55, 230, 70, 100), (-48, "#063f9e", 0.8, 300, 105, -80)]
        bloom(w / "01-windows-bloom.jpg", "#d6e7f7", "#eef5fc", blue)
        bloom(w / "02-windows-flow.jpg", "#e8eef6", "#f6f8fb",
              [(a + 20, c, al, rx, ry, dx) for a, c, al, rx, ry, dx in blue], seed=5)
        bloom(wd / "01-windows-nuit.jpg", "#04080f", "#0b1626", blue)
        bloom(wd / "02-windows-glow.jpg", "#05070d", "#101a2c",
              [(a - 25, c, al * 0.9, rx * 1.1, ry, dx) for a, c, al, rx, ry, dx in blue])
    if "mono" in only:
        src = Path.home() / ".local/share/liquid-glass/wallpapers"
        pool = [src / n for n in MONO_SOURCES if (src / n).exists()]
        if len(pool) < 4:
            pool += sorted(src.glob("anime-*.jpg"))[: 6 - len(pool)]
        for i, f in enumerate(pool[:6], 1):
            halftone(mo / f"{i:02d}-mono-trame.jpg", f)
        lines(mo / "07-mono-ondes.jpg", "#000000", "#bcbcbc", seed=21)
    if "foret" in only:
        forest(fo / "01-foret-lac.jpg", "#3b2a5c", "#9a5a86", "#f0a07a", "#ffb08a", "#5b5a84", "#2b3350", "#f6d6d0", "#0d1a10", seed=3)
        forest(fo / "02-foret-aube.jpg", "#f7c6c9", "#f6d3c4", "#fde8d8", "#ffffff", "#c7a3b8", "#6d6f8f", "#ffffff", "#1d2a1c", seed=9)
        forest(fo / "03-foret-nuit.jpg", "#0d1424", "#2a2b4d", "#5c4a6e", "#9c86c0", "#2d3150", "#1a1f33", "#c9c6e0", "#070c08", seed=17)


if __name__ == "__main__":
    main()
