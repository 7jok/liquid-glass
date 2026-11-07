#!/usr/bin/env python3
"""Enveloppe dans T.t(...) les textes des QML qui ont une traduction (shared/lang/en.tsv).
Relançable : un texte déjà enveloppé n'est pas retouché. Usage : i18n-wrap.py DOSSIER..."""
import re
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
tr = {}
for ln in (REPO / "shared/lang/en.tsv").read_text().splitlines():
    a, _, b = ln.partition("\t")
    tr[a] = b
KEY = re.compile(r'(?<![\w.])(text|label|sub|title|placeholderText|subtitle|desc|hint|name)(\s*:\s*)([^;}\n]*)')
QUOTE = re.compile(r'(?<!T\.t\()"([^"\\]*)"')
PAIR = re.compile(r'(\["[\w:.-]*", )"([^"\\]+)"')


def wrap(m):
    return f'T.t("{m.group(1)}")' if m.group(1) in tr else m.group(0)


def line(ln):
    if ln.lstrip().startswith(("import ", "//", "font.family")):
        return ln
    ln = KEY.sub(lambda m: m.group(1) + m.group(2) + QUOTE.sub(wrap, m.group(3)), ln)
    ln = PAIR.sub(lambda m: f'{m.group(1)}T.t("{m.group(2)}")' if m.group(2) in tr else m.group(0), ln)
    return ln.replace('Qt.locale("fr_FR")', "Qt.locale(T.loc)")


for d in sys.argv[1:]:
    for f in Path(d).glob("*.qml"):
        src = f.read_text()
        out = "".join(line(x) for x in src.splitlines(True))
        if "T.t(" in out or "T.loc" in out:
            if 'import "T.js" as T' not in out:
                last = [m for m in re.finditer(r'^import .*\n', out, re.M)][-1]
                out = out[:last.end()] + 'import "T.js" as T\n' + out[last.end():]
        if out != src:
            f.write_text(out)
