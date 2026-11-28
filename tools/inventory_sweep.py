"""Offline sweep: find every indexed TIM image on a disc and render contact sheets (task 009).

Usage: python tools/inventory_sweep.py <disc BIN> <out dir>
Writes <out>/inventory.csv (file, offset, w, h, cluts, mode) and <out>/sheets/<file>.png (one sheet per file, CLUT 0).
Output stays outside the repo (extracted art is never committed).
"""
import csv, struct, sys
from pathlib import Path
import numpy as np
from PIL import Image, ImageDraw
sys.path.insert(0, str(Path(__file__).parent))
from practice_disc_v30 import Disc, decode
from build_practice_v30 import tim, rgb_image

MAGIC = b'\x10\x00\x00\x00'


def blobs(rec):
    yield 'raw', rec
    try:
        d = decode(rec)[0]
        if d:
            yield 'lz', d
    except Exception:
        pass


def find_tims(data):
    seen = set()
    p = data.find(MAGIC)
    while p != -1:
        if p % 4 == 0 and p not in seen:
            try:
                t = tim(data, p)
                if t['width'] >= 32 and t['height'] >= 16 and t['width'] / t['height'] < 40:
                    seen.add(p)
                    yield t
            except Exception:
                pass
        p = data.find(MAGIC, p + 1)


def main(bin_path, out):
    out = Path(out); (out / 'sheets').mkdir(parents=True, exist_ok=True)
    d = Disc(bin_path)
    rows = []
    for name in sorted(d.records):
        lba, size = d.records[name]
        if size < 4096 or name.upper().endswith(('.XA', '.STR', '.XDB')):
            continue
        rec = d.read(lba, size)
        tims = []
        for kind, data in blobs(rec):
            for t in find_tims(data):
                tims.append((kind, t))
        if not tims:
            continue
        thumbs = []
        for kind, t in tims:
            ncl = len(t['palette']) // (16 if t['mode'] == 0 else 256)
            rows.append([name, kind, hex(t['at']), t['width'], t['height'], ncl, t['mode']])
            try:
                thumbs.append((kind, t, rgb_image(t).convert('RGB')))
            except Exception:
                pass
        W = 1100; x = y = rowh = 0; cells = []
        for kind, t, im in thumbs:
            s = min(1.0, 520 / im.width, 400 / im.height)
            im2 = im.resize((max(1, int(im.width * s)), max(1, int(im.height * s))))
            if x + im2.width > W:
                x = 0; y += rowh + 14; rowh = 0
            cells.append((x, y + 12, im2, '%s %s %dx%d' % (kind, hex(t['at']), t['width'], t['height'])))
            x += im2.width + 8; rowh = max(rowh, im2.height + 12)
        sheet = Image.new('RGB', (W, y + rowh + 14), (40, 40, 40)); dr = ImageDraw.Draw(sheet)
        for cx, cy, im2, lab in cells:
            sheet.paste(im2, (cx, cy)); dr.text((cx, cy - 11), lab, fill=(255, 255, 0))
        sheet.save(out / 'sheets' / (name.replace('/', '_') + '.png'))
        print(name, len(thumbs), flush=True)
    with (out / 'inventory.csv').open('w', newline='') as f:
        w = csv.writer(f); w.writerow(['file', 'stream', 'offset', 'w', 'h', 'cluts', 'mode']); w.writerows(rows)
    print('TIMs', len(rows))


if __name__ == '__main__':
    main(sys.argv[1], sys.argv[2])
