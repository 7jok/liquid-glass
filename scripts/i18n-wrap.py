#!/usr/bin/env python3
"""Enveloppe dans T.t(...) tous les textes des QML qui ont une traduction (shared/lang/en.tsv).
Laisse les comparaisons, clés d'objets et commandes. Relançable. Usage : i18n-wrap.py DOSSIER..."""
import re
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
tr = {}
for ln in (REPO / "shared/lang/en.tsv").read_text().splitlines():
    a, _, b = ln.partition("\t")
    tr[a] = b
QUOTE = re.compile(r'"((?:[^"\\]|\\.)*)"')
SKIP_LINE = ("import ", "//", "font.family", "property string font", "fontFamily")


def line(ln: str) -> str:
    if ln.lstrip().startswith(SKIP_LINE):
        return ln

    def sub(m):
        x = m.group(1)
        if x not in tr:
            return m.group(0)
        before, after = ln[:m.start()].rstrip(), ln[m.end():].lstrip()
        if before.endswith(("T.t(", "===", "!==", "==", "!=", "case", "indexOf(", "includes(", "startsWith(", "[")) and not before.endswith(("[", "T.t(")) or before.endswith("T.t("):
            return m.group(0)
        if after.startswith(("===", "!==", "]:")) or (after.startswith(":") and not before.endswith("?")):
            return m.group(0)
        return f'T.t("{x}")'

    ln = QUOTE.sub(sub, ln)
    return ln.replace('Qt.locale("fr_FR")', "Qt.locale(T.loc)")


for d in sys.argv[1:]:
    for f in Path(d).glob("*.qml"):
        src = f.read_text()
        out = "".join(line(x) for x in src.splitlines(True))
        if ("T.t(" in out or "T.loc" in out) and 'import "T.js" as T' not in out:
            last = list(re.finditer(r"^import .*\n", out, re.M))[-1]
            out = out[:last.end()] + 'import "T.js" as T\n' + out[last.end():]
        if out != src:
            f.write_text(out)
