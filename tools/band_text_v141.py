"""v141: English re-lettering of baked narration text (24-px bands, white-on-black 4-bit TIMs).

Each text image is a stack of 24-px bands; every band is one displayed row, 256 px wide per column
(512-px images hold two columns: x 0-255 and x 256-511). Anti-aliased greys map onto the TIM's own grey ramp.
"""
import numpy as np
from PIL import Image, ImageDraw, ImageFont
from build_practice_v30 import tim, rgb_palette, replace_pixels

BAND = 24
FONT = 'C:/Windows/Fonts/arial.ttf'


MINSIZE = 12


def letter(pix, col_x, col_w, rows, bg=1, size=17, font=FONT):
    """Rewrite one 256-px column. Each ROW is one on-screen line up to 2*col_w px wide, stored split across two
    consecutive 24-px bands: band 2k = first col_w px, band 2k+1 = the rest (the original Japanese lines wrap this way).
    rows: list of strings ('' = blank row)."""
    out = pix.copy()
    full = col_w * 2
    f = ImageFont.truetype(font, size)
    for k, text in enumerate(rows):
        y0 = k * 2 * BAND
        if y0 + 2 * BAND > pix.shape[0]:
            raise ValueError('too many rows')
        row = np.full((BAND, full), bg, dtype=np.uint8)
        # The game crops the right-hand band of each row to the width of the ORIGINAL ink in it (and draws the row
        # stretched ~1.3x horizontally), so the English line may only be col_w + that ink width wide.
        reg = pix[y0 + BAND:y0 + 2 * BAND, col_x:col_x + col_w]
        bgv = np.bincount(reg.ravel()).argmax()
        cols = np.where((reg != bgv).any(axis=0))[0]
        limit = col_w + (int(cols.max()) + 1 if len(cols) else 0) - 3
        if text:
            s = size
            ff = f
            probe = ImageDraw.Draw(Image.new('L', (full, BAND), 0))
            while True:
                w = probe.textlength(text, font=ff)
                if w <= limit or s <= MINSIZE:
                    break
                s -= 1
                ff = ImageFont.truetype(font, s)
            if w > limit:
                raise ValueError('row too wide (%d > %d): %r' % (w, limit, text))
            print('  row %d: %2d px font, %3d/%3d px: %s' % (k, s, w, limit, text))
            im = Image.new('L', (full, BAND), 0)
            d = ImageDraw.Draw(im)
            b = d.textbbox((0, 0), text, font=ff)
            d.text((3 - b[0], (BAND - (b[3] - b[1])) // 2 - b[1] - 1), text, font=ff, fill=255)
            g = np.array(im).astype(np.int32)
            row = (bg + np.rint(g / 255 * (15 - bg)).astype(np.int32)).astype(np.uint8)
        out[y0:y0 + BAND, col_x:col_x + col_w] = row[:, :col_w]
        out[y0 + BAND:y0 + 2 * BAND, col_x:col_x + col_w] = row[:, col_w:]
    return out


# record -> list of (tim offset, [(col_x, col_w, bands), ...])
JOBS = {
    'DAT2/OP01.BIZ': [(0x63a50, [
        (0, 256, ['Late 20th century.',
                  'Top high-schoolers were being kidnapped',
                  'or attacked all across the country.',
                  "Police and adults can't be relied on!",
                  'So the students themselves finally stood up.']),
        (256, 256, ["\"We'll protect our school ourselves!\"",
                    'Each, with resolve in their hearts,',
                    'faces down a great evil.',
                    '"Our goal: Justice Academy!"',
                    '']),
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
            rects.append((x, 0, w, len(bands) * 2 * BAND))
        replace_pixels(after, tim(bytes(after), off), pix, rects)
        claims.append((off, rects))
    return claims
