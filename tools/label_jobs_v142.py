"""v142: English lettering for AISYOU (compatibility mode) and HERE ("Hold on!") baked labels."""
import numpy as np
from PIL import Image, ImageDraw, ImageFont
from scipy.ndimage import binary_dilation
from build_practice_v30 import tim, replace_pixels
from img_label import restyle, learn_style

FONT = 'C:/Windows/Fonts/arialn.ttf'
BOLD = 'C:/Windows/Fonts/arialbd.ttf'
O1 = dict(outline_px=1)
O2 = dict(outline_px=2, embolden=1)


def vertical(px, rect, text, bg=0, font=BOLD, stretch=1.5):
    """Stack the letters of `text` top to bottom in rect, using the original label's fill/outline rows."""
    x, y, w, h = rect
    cell = h / len(text)
    ramp = [14, 13, 12, 10, 9, 8, 6, 5]
    row_fill = [ramp[min(len(ramp) - 1, int(((r % cell) / cell) * len(ramp)))] for r in range(h)]
    row_out = [1] * h
    core = np.zeros((h, w), dtype=bool)
    for i, ch in enumerate(text):
        if ch == ' ':
            continue
        size = 60
        while size > 8:
            f = ImageFont.truetype(font, size)
            l, t, r, b = f.getbbox(ch)
            if (b - t) <= cell - 8 and (r - l) * stretch <= w - 10:
                break
            size -= 1
        im = Image.new('L', (r - l, b - t), 0)
        ImageDraw.Draw(im).text((-l, -t), ch, font=f, fill=255)
        im = im.resize((max(1, int((r - l) * stretch)) if ch not in '!' else r - l, b - t))
        m = np.array(im) >= 128
        ox = (w - m.shape[1]) // 2
        oy = int(i * cell + (cell - m.shape[0]) / 2)
        core[oy:oy + m.shape[0], ox:ox + m.shape[1]] |= m
    core = binary_dilation(core, iterations=1)
    edge = binary_dilation(core, iterations=2) & ~core
    out = px.copy()
    new = np.full((h, w), bg, dtype=np.uint8)
    for r in range(h):
        new[r][edge[r]] = row_out[r]
        new[r][core[r]] = row_fill[r]
    out[y:y + h, x:x + w] = new
    return out


def wipe(px, rect, bg=0):
    out = px.copy()
    x, y, w, h = rect
    out[y:y + h, x:x + w] = bg
    return out


# record -> list of (tim offset, [(kind, rect, text, kwargs)])
JOBS = {
    'DAT2/AISYOU.TIZ': [
        (0x20800, [
            ('r', (0, 0, 84, 25), 'SYNC', O1), ('r', (84, 0, 85, 25), 'SKILL', O1), ('r', (169, 0, 82, 25), 'TRUST', O1),
            ('r', (0, 25, 84, 24), 'BOND', O1), ('r', (84, 25, 116, 24), 'RATING', dict(O1, fit_w=100)),
            ('r', (0, 208, 300, 36), "CHAIR'S COMPATIBILITY CORNER", dict(outline_px=1, embolden=1)),
        ]),
        (0x45000, [
            ('r', (0, 96, 238, 28), 'BACK TO MODE MENU', O1),
            ('r', (0, 128, 168, 27), 'COMPAT. MODE', O1),
            ('r', (0, 160, 121, 27), 'VERSUS MODE', O1),
            ('r', (144, 0, 90, 39), 'CO-OP', dict(outline_px=1, embolden=1)),
            ('w', (144, 40, 40, 40), None, {}),
        ]),
    ],
    'DAT2/HERE.TIZ': [
        (0, [('v', (0, 0, 64, 210), 'HOLD ON!', {})]),
    ],
}


def patch_record(after, name):
    claims = []
    for off, items in JOBS[name]:
        t = tim(bytes(after), off)
        pix = t['pixels'].copy()
        rects = []
        for kind, rect, text, kw in items:
            if kind == 'r':
                pix = restyle(pix, rect, text, FONT, **dict(dict(fit_w=rect[2] - 2), **kw))
            elif kind == 'v':
                pix = vertical(pix, rect, text)
            else:
                pix = wipe(pix, rect)
            rects.append(rect)
        replace_pixels(after, tim(bytes(after), off), pix, rects)
        claims.append((off, rects))
    return claims
