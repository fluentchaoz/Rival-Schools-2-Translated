"""v141: English re-lettering of baked narration text (24-px bands, white-on-black 4-bit TIMs).

Each text image is a stack of 24-px bands; every band is one displayed row, 256 px wide per column
(512-px images hold two columns: x 0-255 and x 256-511). Anti-aliased greys map onto the TIM's own grey ramp.
"""
import numpy as np
from PIL import Image, ImageDraw, ImageFont
from build_practice_v30 import tim, rgb_palette, replace_pixels

BAND = 24
FONT = 'C:/Windows/Fonts/arial.ttf'


def letter(pix, col_x, col_w, bands, bg=1, size=18, font=FONT):
    """Return a copy of pix with the column's bands rewritten. bands: list of strings ('' = blank)."""
    out = pix.copy()
    f = ImageFont.truetype(font, size)
    for i, text in enumerate(bands):
        y0 = i * BAND
        if y0 + BAND > pix.shape[0]:
            raise ValueError('too many bands')
        cell = np.full((BAND, col_w), bg, dtype=np.uint8)
        if text:
            s = size
            ff = f
            im = Image.new('L', (col_w * 4, BAND * 4), 0)
            while True:
                d = ImageDraw.Draw(im)
                w = d.textlength(text, font=ff)
                if w <= col_w - 6 or s <= 9:
                    break
                s -= 1
                ff = ImageFont.truetype(font, s)
            if w > col_w - 6:
                raise ValueError('band too wide: %r' % text)
            im = Image.new('L', (col_w, BAND), 0)
            d = ImageDraw.Draw(im)
            b = d.textbbox((0, 0), text, font=ff)
            d.text((3 - b[0], (BAND - (b[3] - b[1])) // 2 - b[1] - 1), text, font=ff, fill=255)
            g = np.array(im).astype(np.int32)
            idx = bg + np.rint(g / 255 * (15 - bg)).astype(np.int32)
            cell = idx.astype(np.uint8)
        out[y0:y0 + BAND, col_x:col_x + col_w] = cell
    return out


# record -> list of (tim offset, [(col_x, col_w, bands), ...])
JOBS = {
    'DAT2/OP01.BIZ': [(0x63a50, [
        (0, 256, ['Late 20th century.', '',
                  'Top high-school students were', 'being kidnapped or attacked', 'all across the country.', '',
                  'Neither police nor adults', 'could be relied on anymore!',
                  'So the students themselves', 'finally stood up.']),
        (256, 256, ['"We\'ll protect our school', 'with our own hands!"',
                    'Each student, with their own', 'resolve in their heart,', 'faces down a great evil.', '',
                    '"Our goal: Justice', 'Academy!"', '', '']),
    ])],
}


def patch_record(after, name):
    claims = []
    for off, cols in JOBS[name]:
        t = tim(bytes(after), off)
        pix = t['pixels'].copy()
        rects = []
        for x, w, bands in cols:
            pix = letter(pix, x, w, bands)
            rects.append((x, 0, w, len(bands) * BAND))
        replace_pixels(after, tim(bytes(after), off), pix, rects)
        claims.append((off, rects))
    return claims
