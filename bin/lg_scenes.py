"""Scènes supplémentaires de liquid-glass-tty : une famille par style de bureau.

Chaque scène dessine sur une toile (put / text) ou en dégradé (shade_lines). Les
couleurs viennent toujours du thème courant : app.fg, app.acc, app.alt, app.dim.
"""
import calendar
import math
import os
import random
import subprocess
import threading
import time


class Canvas:
    def __init__(self, w, h, fgc):
        self.w, self.h, self.fgc = w, h, fgc
        self.g = [[" "] * w for _ in range(h)]
        self.c = [[None] * w for _ in range(h)]

    def put(self, x, y, ch, col):
        x, y = int(x), int(y)
        if 0 <= x < self.w and 0 <= y < self.h:
            self.g[y][x] = ch
            self.c[y][x] = col

    def text(self, x, y, s, col):
        for i, ch in enumerate(s):
            if ch != " ":
                self.put(int(x) + i, y, ch, col)

    def center(self, y, s, col):
        self.text((self.w - len(s)) // 2, y, s, col)

    def lines(self):
        out = []
        for y in range(self.h):
            row, last = [], None
            for x in range(self.w):
                c = self.c[y][x]
                if c and c != last:
                    row.append(self.fgc(c))
                    last = c
                row.append(self.g[y][x])
            out.append("".join(row))
        return out


def build(Scene, mix, fgc, shade_lines, FONT, JOURS, MOIS):
    """Crée les classes de scènes avec les outils de liquid-glass-tty."""

    class Base(Scene):
        def canvas(self, w, h):
            return Canvas(w, h, fgc)

        def step(self, t):
            dt = 0.0 if getattr(self, "_t", None) is None else min(0.25, t - self._t)
            self._t = t
            return dt

    class Stars(Base):
        """Saut en hyperespace : les étoiles fuient depuis le centre."""
        def __init__(self, app):
            super().__init__(app)
            self.s = [self.new(True) for _ in range(140)]

        def new(self, spread=False):
            return [random.uniform(-1, 1), random.uniform(-1, 1), random.uniform(0.05, 1) if spread else 1.0]

        def frame(self, t, w, h):
            dt, a, c = self.step(t), self.app, self.canvas(w, h)
            speed = 0.25 + 0.9 * a.audio.bass
            for i, s in enumerate(self.s):
                s[2] -= dt * speed
                if s[2] <= 0.02:
                    self.s[i] = s = self.new()
                x, y = w / 2 + s[0] / s[2] * w / 4, h / 2 + s[1] / s[2] * h / 4
                near = 1 - s[2]
                if 0 <= x < w and 0 <= y < h:
                    c.put(x, y, "·.+*@"[min(4, int(near * 5))], mix(a.bg, mix(a.fg, a.acc, near), 0.3 + 0.7 * near))
                else:
                    self.s[i] = self.new()
            return c.lines()

    class Orbit(Base):
        """Système solaire : six planètes, dont une avec des anneaux."""
        def frame(self, t, w, h):
            a, c = self.app, self.canvas(w, h)
            cx, cy = w / 2, h / 2
            rmax = min(w / 2 - 2, h - 2)
            for dy in range(-1, 2):
                for dx in range(-3, 4):
                    if dx * dx / 9 + dy * dy <= 1.1:
                        c.put(cx + dx, cy + dy, "@", mix(a.acc, a.fg, 0.3 + 0.5 * a.audio.bass))
            for i in range(6):
                r = rmax * (i + 1.4) / 7
                for k in range(int(r * 5)):
                    an = k / (r * 5) * math.tau
                    c.put(cx + r * math.cos(an), cy + r * 0.5 * math.sin(an), "·", mix(a.bg, a.fg, 0.2))
                an = t * (0.9 / (i + 1)) + i * 1.7
                px, py = cx + r * math.cos(an), cy + r * 0.5 * math.sin(an)
                c.put(px, py, "O" if i in (2, 4) else "o", mix(a.acc, a.alt, i / 5))
                if i == 4:
                    c.put(px - 1, py, "-", a.fg)
                    c.put(px + 1, py, "-", a.fg)
            return c.lines()

    class Hole(Scene):
        """Trou noir : disque d'accrétion qui tourne autour d'un vide parfait."""
        def frame(self, t, w, h):
            a = self.app
            bass = a.audio.bass

            def fn(u, v):
                y = v * 2.6
                r = math.hypot(u, y)
                if r < 0.3:
                    return None
                ang = math.atan2(y, u)
                arm = 0.5 + 0.5 * math.sin(ang * 3 + 6 / (r + 0.2) - t * 2.2)
                ring = math.exp(-((r - 0.42) / 0.06) ** 2)
                halo = math.exp(-((math.hypot(u, v) - 0.36) / 0.035) ** 2)
                return min(1, max(ring, 0.8 * halo) + arm * max(0, 1 - r / 1.25) * (0.6 + 0.5 * bass))

            return shade_lines(w, h, fn, lambda i, u, v: mix(mix(a.bg, a.alt, 0.5), mix(a.acc, a.fg, i), i))

    class Fish(Base):
        """Aquarium : poissons, bulles et algues qui ondulent."""
        SHAPES = [("><>", "<><"), ("><(((°>", "<°)))><"), ("=>", "<="), ("><{{{*>", "<*}}}><")]

        def __init__(self, app):
            super().__init__(app)
            self.f, self.b = [], []

        def frame(self, t, w, h):
            dt, a, c = self.step(t), self.app, self.canvas(w, h)
            while len(self.f) < max(4, w * h // 260):
                d = random.choice((-1, 1))
                self.f.append([-8.0 if d > 0 else w + 8.0, random.uniform(1, max(2, h - 4)), d, random.uniform(4, 12),
                               random.choice(self.SHAPES), random.choice((a.acc, a.alt, a.fg))])
            for f in list(self.f):
                f[0] += f[2] * f[3] * dt * (1 + a.audio.bass)
                if f[0] < -10 or f[0] > w + 10:
                    self.f.remove(f)
                    continue
                c.text(f[0], f[1] + 0.6 * math.sin(t + f[3]), f[4][0 if f[2] > 0 else 1], f[5])
            if random.random() < 0.2:
                self.b.append([random.uniform(0, w), float(h - 1)])
            for b in list(self.b):
                b[1] -= dt * 4
                b[0] += math.sin(t * 2 + b[1]) * dt * 2
                if b[1] < 0:
                    self.b.remove(b)
                    continue
                c.put(b[0], b[1], "o" if b[1] > h / 2 else "°", a.dim)
            for x in range(3, w, 9):
                for k in range(min(h // 3, 2 + x % 4)):
                    c.put(x + (1 if math.sin(t * 1.5 + k + x) > 0 else 0), h - 1 - k, "(" if k % 2 else ")", mix(a.acc, a.bg, 0.35))
            return c.lines()

    class Lava(Scene):
        """Lampe à lave : boules qui fusionnent en montant et descendant."""
        def frame(self, t, w, h):
            a = self.app
            balls = [(0.5 * math.sin(t * 0.31 + k * 2.1), math.sin(t * (0.23 + k * 0.05) + k), 0.2 + 0.05 * (k % 3)) for k in range(6)]
            bass = 1 + 0.25 * a.audio.bass

            def fn(u, v):
                s = 0.0
                for x, y, r in balls:
                    s += r * r / ((u - x) ** 2 + (v - y) ** 2 + 1e-3)
                s *= bass
                return min(1, (s - 0.7) * 1.2) if s > 0.7 else None

            return shade_lines(w, h, fn, lambda i, u, v: mix(a.alt, a.acc, min(1, max(0, 0.5 - v / 2))))

    class Fall(Base):
        """Chute lente : feuilles, pétales ou neige, selon la sous-classe."""
        GLYPHS = "*"
        WIND = 2.0

        def __init__(self, app):
            super().__init__(app)
            self.p = []

        def extra(self, c, t, w, h):
            pass

        def color(self):
            return random.choice((self.app.acc, self.app.alt))

        def frame(self, t, w, h):
            dt, a, c = self.step(t), self.app, self.canvas(w, h)
            self.extra(c, t, w, h)
            while len(self.p) < max(12, w * h // 70):
                self.p.append([random.uniform(0, w), random.uniform(-h, 0), random.uniform(1.5, 4.5), random.uniform(0, 6),
                               random.choice(self.GLYPHS), self.color()])
            for p in self.p:
                p[1] += p[2] * dt
                p[0] += (math.sin(t + p[3]) * 2 + self.WIND * (1 + a.audio.bass)) * dt
                if p[1] > h or p[0] > w + 1:
                    p[0], p[1] = random.uniform(-w / 3, w), -1.0
                c.put(p[0], p[1], p[4], p[5])
            return c.lines()

    class Leaves(Fall):
        """Forêt : feuilles qui tombent, lucioles, sous-bois."""
        GLYPHS = "&%*,'"

        def extra(self, c, t, w, h):
            a = self.app
            for i in range(10):
                x = (w * 0.5 + w * 0.48 * math.sin(t * 0.21 + i * 2.4))
                y = h * 0.6 + h * 0.3 * math.sin(t * 0.33 + i * 1.3)
                if math.sin(t * 2 + i * 1.9) > 0.2:
                    c.put(x, y, "•", mix(a.acc, a.fg, 0.5))
            for x in range(w):
                c.put(x, h - 1, "wvW,"[(x * 7) % 4], mix(a.acc, a.bg, 0.45))

    class Petals(Fall):
        """Sakura : pétales et branche en fleur."""
        GLYPHS = "❀✿*°'"
        WIND = 3.0

        def extra(self, c, t, w, h):
            a = self.app
            n = max(8, w // 2)
            for x in range(n):
                y = 1 + int(x * x / (n * n / max(2, h / 3)))
                c.put(x, y, "~", mix(a.fg, a.bg, 0.45))
                if x % 3 == 0:
                    c.put(x, y + 1, "❀", a.acc)

    class Snow(Fall):
        GLYPHS = "*·.+"
        WIND = 0.8

        def color(self):
            return self.app.fg

    class Plasma(Scene):
        """Plasma : vagues de couleurs qui se mélangent."""
        def frame(self, t, w, h):
            a = self.app
            bass = a.audio.bass

            def fn(u, v):
                return 0.5 + 0.25 * (math.sin(u * 5 + t) + math.sin(v * 6 - t * 0.7)) + 0.12 * math.sin((u + v) * 7 + t * 1.3 + bass * 2)

            def col(i, u, v):
                k = 0.5 + 0.5 * math.sin(i * 6 + t * 0.4)
                return mix(a.acc, a.alt, k)

            return shade_lines(w, h, fn, col)

    class Snake(Base):
        """Serpent qui joue seul : il va droit vers la pomme en évitant son corps."""
        def __init__(self, app):
            super().__init__(app)
            self.body, self.food, self.acc, self.size = [], None, 0.0, (0, 0)

        def reset(self, w, h):
            self.size = (w, h)
            self.body = [(w // 2 - i, h // 2) for i in range(5)]
            self.food = self.spot(w, h)

        def spot(self, w, h):
            while True:
                p = (random.randrange(1, max(2, w - 1)), random.randrange(1, max(2, h - 1)))
                if p not in self.body:
                    return p

        def frame(self, t, w, h):
            dt, a, c = self.step(t), self.app, self.canvas(w, h)
            if self.size != (w, h) or not self.body:
                self.reset(w, h)
            self.acc += dt * 14
            while self.acc >= 1:
                self.acc -= 1
                hx, hy = self.body[0]
                fx, fy = self.food
                opts = sorted(((hx + dx, hy + dy) for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1))),
                              key=lambda p: abs(p[0] - fx) + abs(p[1] - fy))
                nxt = next((p for p in opts if 0 <= p[0] < w and 0 <= p[1] < h and p not in self.body[:-1]), None)
                if nxt is None:
                    self.reset(w, h)
                    break
                self.body.insert(0, nxt)
                if nxt == self.food:
                    self.food = self.spot(w, h)
                    if len(self.body) > w * h // 4:
                        self.reset(w, h)
                else:
                    self.body.pop()
            c.put(*self.food, "●", a.alt)
            n = len(self.body)
            for i, (x, y) in enumerate(self.body):
                c.put(x, y, "█", mix(a.acc, a.bg, 0.65 * i / n))
            c.text(1, 0, f"{n}", a.dim)
            return c.lines()

    class Life(Base):
        """Jeu de la vie : une cellule vit ou meurt selon ses voisines."""
        def __init__(self, app):
            super().__init__(app)
            self.cells, self.size, self.acc, self.gen = set(), (0, 0), 0.0, 0

        def seed(self, w, h):
            self.size, self.gen = (w, h), 0
            self.cells = {(x, y) for x in range(w) for y in range(h) if random.random() < 0.24}

        def frame(self, t, w, h):
            dt, a, c = self.step(t), self.app, self.canvas(w, h)
            if self.size != (w, h) or len(self.cells) < 6 or self.gen > 400:
                self.seed(w, h)
            self.acc += dt * 8
            while self.acc >= 1:
                self.acc -= 1
                self.gen += 1
                n = {}
                for x, y in self.cells:
                    for dx in (-1, 0, 1):
                        for dy in (-1, 0, 1):
                            if dx or dy:
                                k = ((x + dx) % w, (y + dy) % h)
                                n[k] = n.get(k, 0) + 1
                self.cells = {k for k, v in n.items() if v == 3 or (v == 2 and k in self.cells)}
            for x, y in self.cells:
                c.put(x, y, "█", mix(a.fg, a.acc, (x + y) % 5 / 5))
            return c.lines()

    class Pipes(Base):
        """Tuyaux : des tubes qui se dessinent et remplissent l'écran."""
        TURN = {(1, 0, 0, 1): "┐", (1, 0, 0, -1): "┘", (-1, 0, 0, 1): "┌", (-1, 0, 0, -1): "└",
                (0, 1, 1, 0): "└", (0, 1, -1, 0): "┘", (0, -1, 1, 0): "┌", (0, -1, -1, 0): "┐"}

        def __init__(self, app):
            super().__init__(app)
            self.c, self.acc, self.heads, self.n = None, 0.0, [], 0

        def head(self, w, h):
            return [random.randrange(w), random.randrange(h), *random.choice(((1, 0), (-1, 0), (0, 1), (0, -1))),
                    random.choice((self.app.acc, self.app.alt, self.app.fg))]

        def frame(self, t, w, h):
            dt, c = self.step(t), self.c
            if c is None or (c.w, c.h) != (w, h) or self.n > w * h * 0.7:
                c = self.c = self.canvas(w, h)
                self.heads, self.n = [self.head(w, h) for _ in range(3)], 0
            self.acc += dt * 45
            while self.acc >= 1:
                self.acc -= 1
                for p in self.heads:
                    x, y, dx, dy, col = p
                    if random.random() < 0.14:
                        ndx, ndy = random.choice(((dy, dx), (-dy, -dx)))
                        c.put(x, y, self.TURN.get((dx, dy, ndx, ndy), "+"), col)
                        dx, dy = ndx, ndy
                    else:
                        c.put(x, y, "─" if dx else "│", col)
                    x, y = x + dx, y + dy
                    self.n += 1
                    p[:4] = ((x % w, y % h, dx, dy) if random.random() < 0.97 and 0 <= x < w and 0 <= y < h else self.head(w, h)[:4])
            return c.lines()

    class Tunnel(Scene):
        """Tunnel : anneaux qui avancent vers toi."""
        def frame(self, t, w, h):
            a = self.app
            sp = 1.4 + 2.5 * a.audio.bass

            def fn(u, v):
                r = math.hypot(u, v) + 0.02
                ang = math.atan2(v, u)
                g = (math.sin(1 / r * 2.2 + t * sp) > 0) ^ (math.sin(ang * 6 + t * 0.4) > 0)
                return (0.85 if g else 0.12) * min(1, r * 1.8)

            return shade_lines(w, h, fn, lambda i, u, v: mix(a.dim, a.acc, i))

    class Waves(Scene):
        """Mer : houle à trois plans."""
        def frame(self, t, w, h):
            a = self.app
            rows = [[" "] * w for _ in range(h)]
            cols = [[None] * w for _ in range(h)]
            for layer in range(3):
                base = h * (0.42 + 0.2 * layer)
                col = mix(a.acc, a.alt if layer == 1 else a.fg, 0.2 * layer)
                for x in range(w):
                    y = base + (h / 10) * math.sin(x / (9 + layer * 3) + t * (1.1 - layer * 0.2)) * (1 + a.audio.bass) + math.sin(x / 3.1 + t * 2) * 0.6
                    for yy in range(max(0, int(y)), h):
                        rows[yy][x] = "~" if yy == int(y) else ("≈" if yy - int(y) < 2 else "·")
                        cols[yy][x] = col if yy == int(y) else mix(col, a.bg, min(0.8, 0.2 + (yy - y) / h * 1.6))
            c = Canvas(w, h, fgc)
            c.g, c.c = rows, cols
            return c.lines()

    class Fire(Base):
        """Feu : la chaleur monte et se refroidit ligne après ligne."""
        def __init__(self, app):
            super().__init__(app)
            self.b, self.size = [], (0, 0)

        def frame(self, t, w, h):
            a = self.app
            if self.size != (w, h):
                self.size, self.b = (w, h), [[0.0] * w for _ in range(h)]
            b = self.b
            for x in range(w):
                b[h - 1][x] = random.uniform(0.55, 1) * (0.8 + 0.3 * a.audio.bass)
            cool = 1.5 / h           # les flammes s'éteignent aux deux tiers de la hauteur
            for y in range(h - 1):
                row, under = b[y], b[y + 1]
                for x in range(w):
                    row[x] = max(0.0, (under[x] + under[(x - 1) % w] + under[(x + 1) % w] + b[min(h - 1, y + 2)][x]) / 4
                                 - cool * random.uniform(0.4, 1.6))
            c = self.canvas(w, h)
            ramp = " .:*sS#$"
            for y in range(h):
                for x in range(w):
                    v = b[y][x]
                    if v > 0.08:
                        c.put(x, y, ramp[min(7, int(v * 8))], mix(mix(a.bg, a.alt, 0.7), mix(a.acc, a.fg, max(0, v * 2 - 1)), min(1, v * 1.6)))
            return c.lines()

    class Bounce(Base):
        """Logo qui rebondit et change de couleur à chaque mur."""
        def __init__(self, app):
            super().__init__(app)
            self.p = [3.0, 2.0, 11.0, 5.0]
            self.k = 0

        def frame(self, t, w, h):
            dt, a, c = self.step(t), self.app, self.canvas(w, h)
            name = a.label or "Liquid Glass"
            lines = [a.glyph + "  " + name] if a.glyph else [name]
            box = "─" * (len(lines[0]) + 2)
            art = ["╭" + box + "╮", "│ " + lines[0] + " │", "╰" + box + "╯"]
            aw, ah = len(art[0]) + 1, 3
            p = self.p
            p[0] += p[2] * dt
            p[1] += p[3] * dt
            if p[0] <= 0 or p[0] >= w - aw:
                p[2] = -p[2]; self.k += 1
                p[0] = max(0, min(w - aw, p[0]))
            if p[1] <= 0 or p[1] >= h - ah:
                p[3] = -p[3]; self.k += 1
                p[1] = max(0, min(h - ah, p[1]))
            col = (a.acc, a.alt, a.fg)[self.k % 3]
            for i, r in enumerate(art):
                c.text(p[0], p[1] + i, r, col)
            return c.lines()

    class Radar(Base):
        """Radar : le faisceau balaie, les échos s'estompent."""
        def __init__(self, app):
            super().__init__(app)
            self.e = []

        def frame(self, t, w, h):
            dt, a, c = self.step(t), self.app, self.canvas(w, h)
            cx, cy = w / 2, h / 2
            R = min(w / 2 - 1, h - 1)
            for k in (0.33, 0.66, 1):
                n = int(R * 8)
                for i in range(n):
                    an = i / n * math.tau
                    c.put(cx + R * k * math.cos(an), cy + R * k * 0.5 * math.sin(an), "·", a.dim)
            for x in range(int(cx - R), int(cx + R)):
                c.put(x, cy, "-", mix(a.bg, a.dim, 0.5))
            sweep = t * 1.6
            for trail in range(14):
                an = sweep - trail * 0.05
                for r in range(1, int(R)):
                    c.put(cx + r * math.cos(an), cy + r * 0.5 * math.sin(an), "/" if trail == 0 else ".", mix(a.acc, a.bg, trail / 14))
            if random.random() < 0.05:
                self.e.append([sweep, random.uniform(0.2, 0.95) * R, 1.0])
            for e in list(self.e):
                e[2] -= dt * 0.3
                if e[2] <= 0:
                    self.e.remove(e)
                    continue
                c.put(cx + e[1] * math.cos(e[0]), cy + e[1] * 0.5 * math.sin(e[0]), "◉", mix(a.bg, a.alt, e[2]))
            return c.lines()

    class Hex(Base):
        """Vidage hexadécimal d'octets aléatoires (décor, aucune donnée réelle)."""
        def __init__(self, app):
            super().__init__(app)
            self.l, self.acc, self.off = [], 0.0, 0

        def frame(self, t, w, h):
            dt, a, c = self.step(t), self.app, self.canvas(w, h)
            self.acc += dt * 12
            n = max(4, min(16, (w - 11) // 4))
            while self.acc >= 1:
                self.acc -= 1
                b = os.urandom(n)
                self.l.append((f"{self.off:08x}", " ".join(f"{x:02x}" for x in b), "".join(chr(x) if 33 <= x < 127 else "." for x in b)))
                self.off += n
            self.l = self.l[-h:]
            for y, (o, hx, tx) in enumerate(self.l):
                c.text(0, y, o, a.dim)
                c.text(10, y, hx, a.acc)
                c.text(11 + 3 * n, y, tx, a.fg)
            return c.lines()

    class Cpu(Base):
        """Vraies mesures : chaque cœur du processeur, mémoire et température."""
        def __init__(self, app):
            super().__init__(app)
            self.prev, self.v, self.last, self.mem, self.temp = {}, [], 0.0, 0.0, None

        def read(self):
            vals = []
            with open("/proc/stat") as f:
                for ln in f:
                    if ln.startswith("cpu") and ln[3].isdigit():
                        p = ln.split()
                        n = [int(x) for x in p[1:9]]
                        idle, tot = n[3] + n[4], sum(n)
                        o = self.prev.get(p[0])
                        self.prev[p[0]] = (idle, tot)
                        vals.append(1 - (idle - o[0]) / max(1, tot - o[1]) if o else 0.0)
            self.v = vals
            m = {}
            with open("/proc/meminfo") as f:
                for ln in f:
                    k, v = ln.split(":")
                    m[k] = int(v.split()[0])
            self.mem = 1 - m["MemAvailable"] / m["MemTotal"]
            try:
                with open("/sys/class/thermal/thermal_zone0/temp") as f:
                    self.temp = int(f.read()) // 1000
            except (OSError, ValueError):
                self.temp = None

        def frame(self, t, w, h):
            a, c = self.app, self.canvas(w, h)
            if t - self.last > 1 or not self.v:
                self.last = t
                self.read()
            rows = self.v + [self.mem]
            names = [f"c{i}" for i in range(len(self.v))] + ["ram"]
            top = max(0, (h - len(rows) - 2) // 2)
            bw = max(6, w - 12)
            step = 1 if len(rows) + 2 >= h - 1 else 1
            for i, (n, v) in enumerate(zip(names, rows)):
                y = top + i * step
                c.text(1, y, n, a.dim)
                fill = int(v * bw)
                for x in range(bw):
                    c.put(5 + x, y, "█" if x < fill else "░", mix(a.acc, a.alt, x / bw) if x < fill else mix(a.bg, a.fg, 0.14))
                c.text(6 + bw, y, f"{int(v * 100):3d}", a.fg)
            if self.temp is not None:
                c.center(top + len(rows) + 1, f"{self.temp} °C", a.dim)
            return c.lines()

    class Scope(Base):
        """Oscilloscope : le spectre de la musique, tracé en une courbe."""
        def frame(self, t, w, h):
            a, c = self.app, self.canvas(w, h)
            bars = a.audio.bars
            n = len(bars)
            mid = h / 2
            py = None
            for x in range(w):
                v = bars[int(x / w * n)] if any(bars) else 0.12 * (1 + math.sin(x / 4 + t * 2))
                y = mid + math.sin(x / 2.2 + t * 8) * v * (h / 2 - 1)
                if py is not None:
                    lo, hi = sorted((int(py), int(y)))
                    for yy in range(lo, hi + 1):
                        c.put(x, yy, "│" if hi > lo else "─", mix(a.acc, a.alt, x / w))
                py = y
            return c.lines()

    class Cal(Base):
        """Calendrier du mois, aujourd'hui en surbrillance."""
        def frame(self, t, w, h):
            a, c = self.app, self.canvas(w, h)
            now = time.localtime()
            weeks = calendar.Calendar(0).monthdayscalendar(now.tm_year, now.tm_mon)
            cw = 3 if w < 34 else 4
            x0 = (w - cw * 7) // 2
            y0 = max(0, (h - len(weeks) * (2 if h > 16 else 1) - 3) // 2)
            c.center(y0, f"{MOIS[now.tm_mon - 1]} {now.tm_year}", a.acc)
            for i, d in enumerate("LMMJVSD"):
                c.text(x0 + i * cw + 1, y0 + 2, d, a.dim)
            gap = 2 if h > 16 else 1
            for r, wk in enumerate(weeks):
                for i, d in enumerate(wk):
                    if d:
                        today = d == now.tm_mday
                        s = f"{d:2d}"
                        c.text(x0 + i * cw, y0 + 3 + r * gap, s, a.alt if today else a.fg)
                        if today:
                            c.put(x0 + i * cw - 1, y0 + 3 + r * gap, "[", a.alt)
                            c.put(x0 + i * cw + 2, y0 + 3 + r * gap, "]", a.alt)
            return c.lines()

    class Timer(Base):
        """Minuteur : durée réglée dans le menu ⌃⌘M. Espace = pause, r = recommencer."""
        def __init__(self, app):
            super().__init__(app)
            self.total = max(1, app.minutes) * 60
            self.end = time.time() + self.total
            self.left = None
            self.rang = False

        def key(self, k):
            if k == "r":
                self.end, self.left, self.rang = time.time() + self.total, None, False
            elif k == "t":
                if self.left is None:
                    self.left = max(0, self.end - time.time())
                else:
                    self.end, self.left = time.time() + self.left, None
            else:
                return False
            return True

        def frame(self, t, w, h):
            a, c = self.app, self.canvas(w, h)
            rem = self.left if self.left is not None else max(0, self.end - time.time())
            if rem <= 0 and not self.rang:
                self.rang = True
                subprocess.Popen(["notify-send", "Minuteur", f"{self.total // 60} min écoulées"],
                                 stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
            s = f"{int(rem) // 60:02d}:{int(rem) % 60:02d}"
            sc = max(1, min((w - 2) // (len(s) * 12), (h - 5) // 7))
            cwid = 2 * sc if len(s) * 12 * sc <= w else 1
            x0 = (w - len(s) * 6 * cwid) // 2
            y0 = max(0, (h - 7 * sc - 3) // 2)
            done = 1 - rem / self.total
            flash = rem <= 0 and int(t * 2) % 2
            col = a.alt if flash else mix(a.acc, a.fg, 0.2)
            if len(s) * 6 * cwid > w:           # terminal trop étroit : texte simple
                c.center(h // 2 - 1, s, col)
            else:
                for ci, ch in enumerate(s):
                    g = FONT.get(ch, ["00000"] * 7)
                    for gy in range(7):
                        for gx in range(5):
                            if g[gy][gx] == "1":
                                for yy in range(sc):
                                    for xx in range(cwid):
                                        c.put(x0 + (ci * 6 + gx) * cwid + xx, y0 + gy * sc + yy, "█", col)
            by = min(h - 2, y0 + 7 * sc + 1)
            bw = max(4, min(w - 4, 40))
            bx = (w - bw) // 2
            for x in range(bw):
                c.put(bx + x, by, "━", a.acc if x < done * bw else mix(a.bg, a.fg, 0.18))
            if self.left is not None:
                c.center(by + 1, "en pause", a.dim)
            return c.lines()

    class Video(Base):
        """Vidéo en terminal : ffmpeg décode, on trace des demi-blocs aux couleurs du thème
        (noir → accent → blanc), comme une console de film."""
        def __init__(self, app):
            super().__init__(app)
            self.size, self.proc, self.buf, self.lock = (0, 0), None, None, threading.Lock()
            self.src = app.video or self.find()

        @staticmethod
        def find():
            home = os.path.expanduser("~")
            for d in (home + "/Vidéos", home + "/Videos", home + "/.local/share/liquid-glass/videos"):
                if os.path.isdir(d):
                    for f in sorted(os.listdir(d)):
                        if f.lower().endswith((".mp4", ".webm", ".mkv", ".mov", ".gif")):
                            return os.path.join(d, f)
            return ""

        def start(self, w, h):
            self.stop()
            self.size = (w, h)
            pw, ph = w, h * 2
            cmd = ["ffmpeg", "-v", "error", "-stream_loop", "-1", "-re", "-i", self.src, "-an", "-vf",
                   f"fps={self.app.fps},scale={pw}:{ph}:force_original_aspect_ratio=increase,crop={pw}:{ph}",
                   "-pix_fmt", "gray", "-f", "rawvideo", "-"]
            self.proc = subprocess.Popen(cmd, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL)
            threading.Thread(target=self.read, args=(self.proc, pw * ph), daemon=True).start()

        def read(self, proc, n):
            while proc.poll() is None:
                b = proc.stdout.read(n)
                if not b or len(b) < n:
                    return
                with self.lock:
                    self.buf = b

        def stop(self):
            if self.proc:
                self.proc.terminate()
                self.proc = None

        def frame(self, t, w, h):
            a, c = self.app, self.canvas(w, h)
            if not self.src:
                c.center(h // 2 - 1, "Aucune vidéo", a.fg)
                c.center(h // 2, "Dépose un fichier dans ~/Vidéos", a.dim)
                return c.lines()
            if self.size != (w, h):
                self.start(w, h)
                self.lut = [mix(mix(a.bg, a.acc, min(1, i / 128)), a.fg, max(0, (i - 128) / 127)) for i in range(256)]
            with self.lock:
                b = self.buf
            if b is None or len(b) < w * h * 2:
                c.center(h // 2, "…", a.dim)
                return c.lines()
            out, lut = [], self.lut
            for y in range(h):
                up, lo = y * 2 * w, (y * 2 + 1) * w
                row, last = [], None
                for x in range(w):
                    k = (b[up + x] >> 3, b[lo + x] >> 3)
                    if k != last:
                        last = k
                        u, l = lut[b[up + x]], lut[b[lo + x]]
                        row.append(f"\x1b[38;2;{u[0]};{u[1]};{u[2]};48;2;{l[0]};{l[1]};{l[2]}m")
                    row.append("▀")
                row.append("\x1b[0m")
                out.append("".join(row))
            return out

    return {"video": Video, "stars": Stars, "orbit": Orbit, "hole": Hole, "fish": Fish, "lava": Lava, "leaves": Leaves,
            "petals": Petals, "snow": Snow, "plasma": Plasma, "snake": Snake, "life": Life, "pipes": Pipes,
            "tunnel": Tunnel, "waves": Waves, "fire": Fire, "bounce": Bounce, "radar": Radar, "hex": Hex,
            "cpu": Cpu, "scope": Scope, "cal": Cal, "timer": Timer}
