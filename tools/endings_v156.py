"""v156: English epilogue narration (DAT2/EDB*.BIZ) re-lettered into the original text image (queue task 011).

Layout (same rule as OP01, tools/band_text_v141.py): a 512- or 256-px-wide 4-bit text TIM at 0x5f800 holds rows; one row is a
pair of 24-px bands in a 256-px column (band 2k = first 256 px, band 2k+1 = the rest); column 0 holds rows 0-4, column 1 rows
5-9. The page is one paragraph read column 0 then column 1. The game crops each row to the width of the ORIGINAL ink, so a row
may only be 256 + (original right-band ink) - 3 px wide, and only rows whose left band had ink may be used.

translations/endings_en.json holds one paragraph per unique page; this module wraps it into the available rows with the
largest font size (17 down to 12) that fits, then hands the rows to band_text_v141.letter().
"""
import json
from pathlib import Path

import numpy as np
from PIL import ImageFont

import band_text_v141 as B
from PIL import Image, ImageDraw
from build_practice_v30 import tim, replace_pixels, rgb_palette

TEXT_TIM = 0x5f800        # EDB pages; ED pages use 0x4000 (ED_TIM)
ED_TIM = 0x4000
ROOT = Path(__file__).resolve().parents[1]
MARGIN = 5


def load_translations(path=None):
    d = json.loads(Path(path or ROOT / 'translations' / 'endings_en.json').read_text(encoding='utf-8'))
    pages = dict(d['pages'])
    for alias, target in d['aliases'].items():
        pages[alias] = pages[target]
    return pages


def rows_in(height):
    """Rows (band pairs) whose first 24-px band fits fully; a trailing single band counts as a row."""
    return (height - 24) // 48 + 1 if height >= 24 else 0


def slots(pix, ncols):
    """[(col_x, row, limit)] in reading order for rows whose left band holds real ink (>= 5 columns)."""
    bg = np.bincount(pix.ravel()).argmax()
    out = []
    for cx in range(0, ncols * 256, 256):
        for k in range(rows_in(pix.shape[0])):
            y0 = k * 48
            left = (pix[y0:y0 + 24, cx:cx + 256] != bg).any(axis=0).sum()
            if left < 5:
                continue
            right = np.where((pix[y0 + 24:y0 + 48, cx:cx + 256] != bg).any(axis=0))[0]
            out.append((cx, k, 256 + (int(right.max()) + 1 if len(right) else 0) - 3))
    return out


def wrap(text, lims, size):
    f = ImageFont.truetype(B.FONT, size)
    words = text.split()
    rows, i = [], 0
    for lim in lims:
        line = ''
        while i < len(words):
            trial = (line + ' ' + words[i]).strip()
            if f.getlength(trial) <= lim - MARGIN or not line and f.getlength(trial) <= lim:
                line = trial
                i += 1
            else:
                break
        rows.append(line)
    return rows if i == len(words) else None


def layout(pix, width, text):  # one paragraph, read column 0 then column 1 ...
    ncols = max(1, width // 256)
    nrows = rows_in(pix.shape[0])
    sl = slots(pix, ncols)
    lims = [s[2] for s in sl]
    for size in range(17, B.MINSIZE - 1, -1):
        rows = wrap(text, lims, size)
        if rows:
            break
    else:
        raise ValueError('text does not fit %d slots (%d px total)' % (len(sl), sum(lims)))
    cols = []
    for ci in range(ncols):
        col_rows = [''] * nrows
        for (cx, k, _), line in zip(sl, rows):
            if cx == ci * 256:
                col_rows[k] = line
        cols.append((ci * 256, 256, col_rows))
    return size, cols


def gray_lut(t, bg):
    """Map 0..255 gray to this TIM's own palette index: bg for black, else the nearest grey among non-black entries."""
    pal = rgb_palette(t, 0)[:, 0].astype(int)
    cand = [i for i in range(16) if pal[i] >= 8]
    lut = np.zeros(256, dtype=np.uint8)
    for g in range(256):
        lut[g] = bg if g < 8 else min(cand, key=lambda i: abs(int(pal[i]) - g))
    return lut


def letter(pix, lut, bg, col_x, col_w, rows, size, font=B.FONT):
    """Like band_text_v141.letter but maps anti-aliasing through the page's own grey palette."""
    out = pix.copy()
    full = col_w * 2
    f = ImageFont.truetype(font, size)
    for k, text in enumerate(rows):
        y0 = k * 2 * B.BAND
        if y0 + B.BAND > pix.shape[0]:
            raise ValueError('too many rows')
        row = np.full((B.BAND, full), bg, dtype=np.uint8)
        reg = pix[y0 + B.BAND:y0 + 2 * B.BAND, col_x:col_x + col_w]
        cols = np.where((reg != bg).any(axis=0))[0]
        limit = col_w + (int(cols.max()) + 1 if len(cols) else 0) - 3
        if text:
            probe = ImageDraw.Draw(Image.new('L', (full, B.BAND), 0))
            w = probe.textlength(text, font=f)
            if w > limit:
                raise ValueError('row too wide (%d > %d): %r' % (w, limit, text))
            im = Image.new('L', (full, B.BAND), 0)
            d = ImageDraw.Draw(im)
            b = d.textbbox((0, 0), text, font=f)
            d.text((3 - b[0], (B.BAND - (b[3] - b[1])) // 2 - b[1] - 1), text, font=f, fill=255)
            row = lut[np.array(im)]
        out[y0:y0 + B.BAND, col_x:col_x + col_w] = row[:, :col_w]
        h2 = min(B.BAND, pix.shape[0] - (y0 + B.BAND))   # a trailing single band has no second half
        if h2 > 0:
            out[y0 + B.BAND:y0 + B.BAND + h2, col_x:col_x + col_w] = row[:h2, col_w:]
    return out


def patch_page(after, name, offset=TEXT_TIM, translations=None):
    text = (translations or load_translations())[name]
    t = tim(bytes(after), offset)
    size, cols = layout(t['pixels'], t['width'], text)
    pix = t['pixels'].copy()
    bg = int(np.bincount(pix.ravel()).argmax())
    lut = gray_lut(t, bg)
    rects = []
    for x, w, rows in cols:
        pix = letter(pix, lut, bg, x, w, rows, size)
        rects.append((x, 0, w, min(len(rows) * 2 * B.BAND, pix.shape[0])))
    replace_pixels(after, tim(bytes(after), offset), pix, rects)
    return size, [(offset, rects)]
