"""v155: prompts 主役交代? / 相棒交代? (queue 004) painted as hard-edged 9 px caps in the same palette rows as PUSH BUTTON.

Cell rows 192..202: row 0 and row 10 are padding, glyph rows 1..9 use fill index 1, the bottom glyph row index 3, background index 7.
"""
import numpy as np
from PIL import Image, ImageDraw, ImageFont
from hud_v152 import patch_all

BAHN = 'C:/Windows/Fonts/bahnschrift.ttf'
CAP = 9
PROMPTS = [  # (rect, text)
    ((512, 192, 63, 11), 'SWAP LEAD', 1),
    ((592, 192, 63, 11), 'SWAP ALLY', 1),
]


def _font(cap, variation=b'Bold Condensed'):
    for size in range(6, 24):
        f = ImageFont.truetype(BAHN, size)
        f.set_variation_by_name(variation)
        b = f.getbbox('H')
        if b[3] - b[1] == cap:
            return f
    raise ValueError('no size gives cap %d' % cap)


def glyph_rows(text, cap=CAP, spacing=1, variation=b'Bold Condensed'):
    f = _font(cap, variation)
    top = f.getbbox('H')[1]
    cells = []
    for c in text:
        if c == ' ':
            cells.append(np.zeros((cap, 3), bool))
            continue
        l, t, r, b = f.getbbox(c)
        im = Image.new('L', (r - l + 4, cap + 6), 0)
        d = ImageDraw.Draw(im)
        d.fontmode = '1'
        d.text((2 - l, 3 - top), c, font=f, fill=255)
        a = np.array(im) > 0
        ys, xs = np.where(a)
        a = a[3:3 + cap, xs.min():xs.max() + 1]
        cells.append(a)
    W = sum(c.shape[1] for c in cells) + spacing * (len(cells) - 1)
    core = np.zeros((cap, W), bool)
    x = 0
    for c in cells:
        core[:, x:x + c.shape[1]] |= c
        x += c.shape[1] + spacing
    return core


def paint_prompt(px, rect, text, spacing=1, variation=b'SemiBold Condensed'):
    """Palette 0 = clear, 1 = glyph core, 7 = 1 px outline, 3 = bottom core row (as in the original PUSH BUTTON cell)."""
    x0, y0, w, h = rect
    core = glyph_rows(text, spacing=spacing, variation=variation)
    cw = core.shape[1]
    if cw + 2 > w:
        raise ValueError('%r is %d px (+2 outline), cell is %d' % (text, cw, w))
    out = px.copy()
    out[y0:y0 + h, x0:x0 + w] = 0
    ox = x0 + (w - cw - 2) // 2 + 1
    oy = y0 + 2
    pad = np.zeros((CAP + 2, cw + 2), bool)
    pad[1:-1, 1:-1] = core
    ring = np.zeros_like(pad)
    for dy in (-1, 0, 1):
        for dx in (-1, 0, 1):
            ring |= np.roll(np.roll(pad, dy, 0), dx, 1)
    ring &= ~pad
    for r in range(CAP + 2):
        for c in range(cw + 2):
            yy, xx = y0 + 1 + r - 1 + 1 - 1, ox - 1 + c
            if ring[r, c]:
                out[y0 + r, xx] = 7
            elif pad[r, c]:
                out[y0 + r, xx] = 3 if r == CAP else 1
    return out


def patch_all155(orig_px):
    px, rects = patch_all(orig_px)
    for rect, text, sp in PROMPTS:
        px = paint_prompt(px, rect, text, spacing=sp)
        rects.append(rect)
    return px, rects


if __name__ == '__main__':
    for t in ('SWAP LEAD', 'SWAP PARTNER', 'CHANGE LEAD', 'CHANGE PARTNER', 'SWAP BUDDY', 'SWAP PAL'):
        print(t, glyph_rows(t).shape[1])
