"""Ending/epilogue narration pages (task 011): dump contact sheets or print size/volume stats.

Usage (project venv, from the JG2-Project folder):
  python repo/tools/ed_pages.py dump [original disc BIN]   -> work/hud/pages_NN.png (4 pages per sheet)
  python repo/tools/ed_pages.py stats [original disc BIN]  -> width/height/approx glyph count per page
Pages: DAT2/ED*.BIZ text TIM at 0x4000, DAT2/EDB*.BIZ text TIM at 0x5f800. Output is not committed.
"""
import re
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw

sys.path.insert(0, str(Path(__file__).parent))
from practice_disc_v30 import Disc, decode
from build_practice_v30 import tim, rgb_image

ORIG = '1-KEEP/original-disc/Shiritsu Justice Gakuen - Nekketsu Seishun Nikki 2 (Japan).bin'


def pages(disc_path):
    d = Disc(disc_path)
    for name in sorted(d.records):
        m = re.match(r'DAT2/(ED\d\d|EDB\d\d)\.BIZ$', name)
        if not m:
            continue
        data = decode(d.record(name))[0]
        off = 0x5f800 if m.group(1).startswith('EDB') else 0x4000
        yield m.group(1), tim(data, off)


def dump(disc_path):
    allp = list(pages(disc_path))
    Path('work/hud').mkdir(parents=True, exist_ok=True)
    for k in range(0, len(allp), 4):
        grp = allp[k:k + 4]
        W = max(t['width'] for _, t in grp)
        H = sum(t['height'] + 16 for _, t in grp)
        S = Image.new('RGB', (W, H), (30, 30, 30))
        dr = ImageDraw.Draw(S)
        y = 0
        for n, t in grp:
            dr.text((2, y + 1), '%s %dx%d' % (n, t['width'], t['height']), fill=(0, 255, 255))
            S.paste(rgb_image(t).convert('RGB'), (0, y + 14))
            y += t['height'] + 16
        S.save('work/hud/pages_%02d.png' % (k // 4))
    print(len(allp), 'pages')


def stats(disc_path):
    tot = 0
    for name, t in pages(disc_path):
        p = t['pixels']
        bg = np.bincount(p.ravel()).argmax()
        ink = p != bg
        chars = sum(int(ink[y:y + 24].any(axis=0).sum() // 14) for y in range(0, p.shape[0] - 23, 24))
        tot += chars
        print(name, t['width'], t['height'], chars)
    print('total approx JP chars', tot)


if __name__ == '__main__':
    cmd = sys.argv[1] if len(sys.argv) > 1 else 'stats'
    disc = sys.argv[2] if len(sys.argv) > 2 else ORIG
    {'dump': dump, 'stats': stats}[cmd](disc)
