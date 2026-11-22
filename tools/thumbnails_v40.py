"""v40: Tournament thumbnail name labels plus English headers on the large right-panel pictures of MENU.BIZ."""
import numpy as np
from scipy.ndimage import binary_dilation
import thumbnails_v39 as V
from thumbnails_v39 import FONT, glyph, erase

def draw_big(pix, x, y, text, fill, outline, scale):
    mask = np.zeros(pix.shape, bool)
    for k, c in enumerate(text):
        g = np.kron(glyph(c), np.ones((scale, scale), np.uint8)) == 1
        h, w = g.shape; cx = x + k * (3 * scale + scale)
        mask[y:y + h, cx:cx + w] |= g
    ring = binary_dilation(mask, structure=np.ones((3, 3), bool), iterations=max(1, scale // 2)) & ~mask
    pix[ring] = outline; pix[mask] = fill
    ys, xs = np.nonzero(mask | ring)
    return (int(xs.min()), int(ys.min()), int(xs.max() - xs.min() + 1), int(ys.max() - ys.min() + 1))

TOP = ['RAN', 'HIN', 'ROY', 'KYO', 'EDG', 'BAT', 'SHO', 'HAY']
BOT = ['GAN', 'NAT', 'TIF', 'AKI', 'DAI', 'RAI', 'HID', 'BOM']
PX = [7, 21, 35, 49, 68, 82, 96, 110]
SMALL = {
 0x95800: dict(size=(128, 96), erase=[], fill=[((4, 45, 119, 5), 3), ((4, 66, 119, 5), 3), ((12, 31, 17, 8), 0)],
  text=[(x, 45, s, 11, None) for x, s in zip(PX, TOP)] + [(x, 66, s, 11, None) for x, s in zip(PX, BOT)] + [(15, 33, 'YOU', 11, None)]),
 0x7c000: dict(size=(100, 114), erase=[((26, 2, 62, 10), {0, 1, 2, 4, 5, 6, 7, 8}, set(), 0), ((26, 2, 18, 10), {9, 10}, set(), 0), ((57, 2, 31, 10), {9, 10}, set(), 0)], fill=[],
  text=[(27, 2, 'TOURNAMENT', 12, None)]),
 0x7d800: dict(size=(100, 114), erase=[((37, 2, 32, 7), {4, 7, 9, 10}, set(), 0), ((60, 2, 22, 8), {4, 7, 9, 10, 12}, set(), 0)], fill=[],
  text=[(41, 3, 'LEAGUE', 14, None)]),
 0x79000: dict(size=(100, 114), erase=[], fill=[((12, 22, 32, 25), 12), ((22, 7, 26, 7), 9)],
  text=[(12, 24, 'YOU TWO', 8, None), (12, 31, 'SYNERGY', 8, None), (12, 38, 'IS:', 8, None), (27, 8, 'TEAM', 11, None)]),
}
BIG = {0x71800: dict(erase=[((2, 4, 96, 28), {12, 13}, set(), 1)], text=[(5, 7, "'99 EXAM", 13, 2, 3)])}

def patch_all(before, tim, replace_pixels):
    after = bytearray(before); claims = []
    for at, spec in SMALL.items():
        t = tim(before, at)
        if (t['width'], t['height']) != spec['size'] or t['mode'] != 0: raise ValueError('geometry %x' % at)
        pix = t['pixels'].copy(); rects = []
        for rect, colors, protect, grow in spec['erase']: erase(pix, rect, colors, protect, grow); rects.append(rect)
        for (x, y, w, h), v in spec['fill']: pix[y:y + h, x:x + w] = v; rects.append((x, y, w, h))
        for x, y, s, f, sh in spec['text']:
            if x < 0 or y < 0 or x + len(s) * 4 > pix.shape[1]: raise ValueError('text out of bounds ' + s)
            V.draw(pix, x, y, s, f, sh); rects.append((x, y, len(s) * 4 + 1, 6))
        replace_pixels(after, t, pix, rects); claims.append(dict(tim_offset=hex(at), rectangles=rects))
    for at, spec in BIG.items():
        t = tim(before, at)
        if (t['width'], t['height'], t['mode']) != (100, 114, 0): raise ValueError('geometry %x' % at)
        pix = t['pixels'].copy(); rects = []
        for rect, colors, protect, grow in spec['erase']: erase(pix, rect, colors, protect, grow); rects.append(rect)
        for x, y, s, f, o, sc in spec['text']: rects.append(draw_big(pix, x, y, s, f, o, sc))
        replace_pixels(after, t, pix, rects); claims.append(dict(tim_offset=hex(at), rectangles=rects))
    return bytes(after), claims
