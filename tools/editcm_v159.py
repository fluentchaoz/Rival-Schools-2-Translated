"""v159: English move-list sheets, DAT2/EDITCM01-24.BIZ TIM 0x0 (412x369, 4-bit, one CLUT) - queue task 013.

Layout (identical in all 24 files): four coloured header blocks on the left (yellow 必殺技, orange 完全燃焼アタック, red
カンタンコマンド, purple 愛と友情のツープラトン), white cells in the middle with each character's move names (section A: special
moves, 3-5 lines; section B: dream attacks, 2-4 lines), button icons on the right with a few red labels:
空中可 on a red pill, 空中で as small red text, and 弱/強 on the last row.
Move names come from translations/editcm_en.json ({"01": {"A": [...], "B": [...]}, ...}); line counts must match the sheet.
"""
import json
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFont
from scipy import ndimage as ndi

BAHN = 'C:/Windows/Fonts/bahnschrift.ttf'
# anti-aliasing ramps in this CLUT: dark text on light = 0 (16), 1 (82), 4 (115); white text on red = 15, 12 (213)
ROOT = Path(__file__).resolve().parents[1]


class Pal:
    """Roles by colour: each file's CLUT is quantised separately, so indices differ."""

    def __init__(self, rgb):
        self.rgb = np.asarray(rgb, dtype=int)
        r, g, b = self.rgb[:, 0], self.rgb[:, 1], self.rgb[:, 2]
        gray = (np.abs(r - g) <= 14) & (np.abs(g - b) <= 14)
        bright = self.rgb.mean(axis=1)
        self.white = int(np.argmax(np.where(gray, bright, -1) + (bright >= 250) * 1000))
        self.red = int(np.argmin(np.abs(r - 255) + g + b))
        self.dark = [int(i) for i in np.argsort(bright) if gray[i] and bright[i] <= 125]      # darkest first
        self.dark_set = set(self.dark)
        self.light = [int(i) for i in np.argsort(-bright) if gray[i] and bright[i] >= 190]    # lightest first
        self.near_white = {i for i in range(16) if min(self.rgb[i]) >= 150}
        self.reddish = {i for i in range(16) if r[i] >= 200 and g[i] <= 190 and b[i] <= 190 and r[i] - g[i] >= 60}

    def dark_levels(self):
        d = self.dark[:3] + [self.dark[-1]] * (3 - len(self.dark[:3]))
        return [(200, d[0]), (120, d[1] if len(d) > 1 else d[0]), (60, d[2] if len(d) > 2 else d[-1])]

    def name_levels(self):
        d = self.dark + [self.dark[-1]] * 3
        return [(200, d[0]), (140, d[1]), (80, d[2]), (40, self.light[1] if len(self.light) > 1 else self.light[0])]

    def light_levels(self):
        return [(200, self.white), (120, self.light[1] if len(self.light) > 1 else self.white)]

BLOCKS = {  # name: ((x, y, w, h), text rule, English lines)
    'Y': ((2, 2, 100, 156), 'dark', ['SPECIAL', 'MOVES']),
    'O': ((2, 161, 100, 111), 'dark', ['DREAM', 'ATTACK']),
    'R': ((2, 274, 126, 45), 'light', ['EASY', 'COMMAND']),
    'P': ((2, 321, 100, 46), 'dark', ['LOVE & FRIENDSHIP', 'TAG ATTACK']),
}


def font(size, variation=b'Bold Condensed'):
    f = ImageFont.truetype(BAHN, size)
    f.set_variation_by_name(variation)
    return f


def fit_font(text, maxw, maxh, start=30, minsize=9, variation=b'SemiBold Condensed'):
    for s in range(start, minsize - 1, -1):
        f = font(s, variation)
        b = f.getbbox(text)
        if b[2] - b[0] <= maxw and b[3] - b[1] <= maxh:
            return f, s
    return font(minsize, variation), minsize


def draw_mask(text, f):
    b = f.getbbox(text)
    im = Image.new('L', (b[2] - b[0] + 2, b[3] - b[1] + 2), 0)
    ImageDraw.Draw(im).text((1 - b[0], 1 - b[1]), text, font=f, fill=255)
    return np.array(im)


def blit(px, mask, cx, cy, levels):
    """Paste grey mask centred on (cx, cy); levels = [(min grey, palette idx), ...] highest first."""
    h, w = mask.shape
    x0, y0 = int(round(cx - w / 2)), int(round(cy - h / 2))
    for yy in range(h):
        for xx in range(w):
            g = mask[yy, xx]
            for lim, idx in levels:
                if g >= lim:
                    px[y0 + yy, x0 + xx] = idx
                    break


def text_lines(p, pal, x0, x1, y0, y1):
    dark = np.isin(p[y0:y1, x0:x1], list(pal.dark_set)).any(axis=1)
    out, start = [], None
    for i, v in enumerate(dark):
        if v and start is None:
            start = i
        if not v and start is not None:
            out.append((y0 + start, y0 + i - 1))
            start = None
    if start is not None:
        out.append((y0 + start, y1 - 1))
    m = []
    for a, b in out:
        if m and a - m[-1][1] <= 3:
            m[-1] = (m[-1][0], b)
        else:
            m.append((a, b))
    return [x for x in m if x[1] - x[0] >= 6]


def ink_x(p, pal, x0, x1, ya, yb):
    cols = np.where(np.isin(p[ya:yb + 1, x0:x1], list(pal.dark_set)).any(axis=0))[0]
    return x0 + int(cols.min()), x0 + int(cols.max())


def patch_headers(p, orig, pal):
    out = p.copy()
    for key, ((x, y, w, h), rule, lines) in BLOCKS.items():
        blk = orig[y:y + h, x:x + w]
        ink = np.isin(blk, list(pal.near_white)) if rule == 'light' else np.isin(blk, list(pal.dark_set))
        ys, xs = np.where(ink)
        if not len(ys):
            continue
        ty0, ty1, tx0, tx1 = y + ys.min(), y + ys.max(), x + xs.min(), x + xs.max()
        m = 5
        ey0, ey1 = max(y + 3, ty0 - m), min(y + h - 3, ty1 + m)
        ex0, ex1 = max(x + 8, tx0 - m), min(x + w - 3, tx1 + m)
        strip = orig[:, x + 3:x + 9]          # six text-free columns of this block
        for yy in range(ey0, ey1 + 1):
            if np.isin(strip[yy], list(pal.dark_set)).any() or np.isin(strip[yy], list(pal.near_white)).any():
                row = [v for v in orig[yy, x + 2:x + w - 2].tolist() if v not in pal.dark_set and v not in pal.near_white]
                fill = max(set(row), key=row.count) if row else int(orig[yy, x + 2])
                out[yy, ex0:ex1 + 1] = fill
            else:
                for xx in range(ex0, ex1 + 1):
                    out[yy, xx] = strip[yy, (xx - (x + 3)) % 6]
        cx, cy = (tx0 + tx1) / 2, (ty0 + ty1) / 2
        n = len(lines)
        lh = min(18, (ty1 - ty0 + 1 + 8) // n)
        levels = pal.light_levels() if rule == 'light' else pal.dark_levels()
        f, _ = fit_font(max(lines, key=len), w - 8, lh, start=16, minsize=8, variation=b'Bold Condensed')
        for k, text in enumerate(lines):
            blit(out, draw_mask(text, f), cx, cy + (k - (n - 1) / 2) * (lh + 1), levels)
    return out


def patch_names(p, orig, names, pal):
    out = p.copy()
    for sect, (xa, xb, ya, yb), maxw in (('A', (106, 282, 3, 157), 172), ('B', (132, 282, 163, 316), 146)):
        found = text_lines(orig, pal, xa, xb, ya, yb)
        want = names[sect]
        if len(found) != len(want):
            raise ValueError('section %s: sheet has %d lines, translation has %d' % (sect, len(found), len(want)))
        for (a, b), text in zip(found, want):
            out[max(ya, a - 2):min(yb, b + 2) + 1, xa:xb] = pal.white
            f, s = fit_font(text, maxw, 24)
            m = draw_mask(text, f)
            blit(out, m, (xa + xb) / 2, (a + b) / 2, pal.name_levels())
    return out


def patch_icons(p, orig, pal):
    WHITE, RED = pal.white, pal.red
    out = p.copy()
    # 1) red pills with white 空中可 -> AIR
    red = orig[0:320, 284:412] == RED
    lab, n = ndi.label(ndi.binary_dilation(red, iterations=1))
    f = font(12, b'Bold Condensed')
    for k, sl in enumerate(ndi.find_objects(lab)):
        ys, xs = sl
        m = (lab[sl] == k + 1) & red[sl]
        w, h = xs.stop - xs.start, ys.stop - ys.start
        if 19 <= h <= 21 and 24 <= w <= 38 and m.sum() >= 100:       # pill
            x0, y0 = 284 + xs.start, ys.start
            mid = orig[y0 + h // 2, max(284, x0 - 2):min(412, x0 + w + 2)]
            nz = np.where(~np.isin(mid, list(pal.near_white)))[0]
            if len(nz):
                lo, hi = max(284, x0 - 2) + int(nz.min()), max(284, x0 - 2) + int(nz.max())
                x0, w = lo, hi - lo + 1
            cx, cy, rx, ry = x0 + w / 2 - 0.5, y0 + h / 2 - 0.5, w / 2 - 0.5, h / 2 - 0.5
            yy, xx = np.mgrid[y0:y0 + h, x0:x0 + w]
            inside = ((xx - cx) / rx) ** 2 + ((yy - cy) / ry) ** 2 <= 1.0
            out[y0:y0 + h, x0:x0 + w][inside] = RED
            blit(out, draw_mask('AIR', f), x0 + w / 2, y0 + h / 2, [(140, WHITE)])
    # 2) small red 空中で text (two components: 18x13 and 9x12) -> AIR
    comps = []
    for k, sl in enumerate(ndi.find_objects(lab)):
        ys, xs = sl
        m = (lab[sl] == k + 1) & red[sl]
        w, h = xs.stop - xs.start, ys.stop - ys.start
        if (16 <= w <= 20 and 12 <= h <= 14 and m.sum() >= 34) or (8 <= w <= 10 and 11 <= h <= 13 and 14 <= m.sum() <= 20):
            comps.append((284 + xs.start, ys.start, w, h, m, sl))
    # 空中で = a 17x13 comp near the left edge plus the pieces of で (1-2 small comps) 16-24 px to its right
    firsts = [c for c in comps if c[2] >= 16 and c[0] <= 292]
    small = []
    for k, sl in enumerate(ndi.find_objects(lab)):
        ys, xs = sl
        m = (lab[sl] == k + 1) & red[sl]
        if (xs.stop - xs.start) <= 10 and (ys.stop - ys.start) <= 13 and m.sum() >= 3:
            small.append((284 + xs.start, ys.start, xs.stop - xs.start, ys.stop - ys.start))
    pairs = []
    for c in firsts:
        part = [q for q in small if c[0] + 15 <= q[0] <= c[0] + 22 and c[1] - 3 <= q[1] <= c[1] + 8]
        if part:
            pairs.append([(c[0], c[1], c[2], c[3])] + part)
    for pr in pairs:
        xs0 = min(c[0] for c in pr); xs1 = max(c[0] + c[2] for c in pr)
        ys0 = min(c[1] for c in pr); ys1 = max(c[1] + c[3] for c in pr)
        out[ys0 - 1:ys1 + 1, xs0 - 1:min(xs1 + 1, 316)] = WHITE
        blit(out, draw_mask('AIR', font(11, b'Bold Condensed')), (xs0 + min(xs1, 315)) / 2, (ys0 + ys1) / 2, [(140, RED)])
    # 3) tag row 弱 / 強 -> L / H
    big = font(24, b'Bold')
    for (x, y, w, h, letter) in ((295, 323, 19, 20, 'L'), (349, 323, 19, 20, 'L'), (295, 344, 19, 21, 'H'), (349, 344, 19, 21, 'H')):
        out[y:y + h, x:x + w] = WHITE
        blit(out, draw_mask(letter, big), x + w / 2, y + h / 2, [(140, RED)])
    return out


LABELS = {  # file: [(zone x, y, w, h), English, font size]
    '05': [((355, 22, 40, 26), 'HOLD', 11)],
    '06': [((362, 206, 42, 28), 'HOLD', 11)],
    '07': [((344, 6, 66, 26), 'MASH OK', 11)],
    '08': [((344, 58, 16, 22), '>', 12), ((378, 56, 30, 26), 'MASH', 11)],
    '22': [((358, 88, 34, 22), 'MASH', 11)],
}


def patch_labels(p, orig, pal, key):
    out = p.copy()
    for (x, y, w, h), text, size in LABELS.get(key, []):
        zone = orig[y:y + h, x:x + w]
        coloured = [i for i in range(16) if int(pal.rgb[i].max() - pal.rgb[i].min()) >= 40 or (i != pal.white and i in pal.light)]
        ys, xs = np.where(np.isin(zone, coloured))
        if not len(ys):
            continue
        for yy, xx in zip(ys, xs):
            out[y + yy, x + xx] = pal.white
        # also clear anti-aliased pink halo pixels around those strokes (neither white nor dark icon pixels)
        cx, cy = x + (xs.min() + xs.max() + 1) / 2, y + (ys.min() + ys.max() + 1) / 2
        blit(out, draw_mask(text, font(size, b'Bold Condensed')), cx, cy, [(140, pal.red)])
    return out


def load_names(path=None):
    return json.loads(Path(path or ROOT / 'translations' / 'editcm_en.json').read_text(encoding='utf-8'))


def patch_sheet(orig, key, rgb_pal, names=None):
    names = (names or load_names())[key]
    pal = Pal(rgb_pal)
    out = patch_headers(orig, orig, pal)
    out = patch_names(out, orig, names, pal)
    out = patch_icons(out, orig, pal)
    out = patch_labels(out, orig, pal, key)
    return out


# ---- second image (TIM 0x13000, 512x256): shared tag-attack name list, thin white outlines on black, one set per 24-px band
LIST_TIM = 0x13000
LIST_LINES = [
    'Double Spirit Bullet  Last Symphony  Ultimate Wave of Love',
    'Guts x100  Love & Peace',
    'Fight x100  Ultimate Correction',
    'Trap Double Shot  Blood Hell',
    'Double Rising Tornado  Combo Dance',
    'Double Power Buster  Active Volcano',
    'Shimazu True Seiha Fist  Man Among Men',
    'Crossfire Kick  Strange Rock Strike',
    'Double Sky Attack  Human Cannon',
    'Dive & Press  Concerto Combo Ver.',
]


def patch_list(px, rgb_pal):
    pal = Pal(rgb_pal)
    out = px.copy()
    bg = int(np.bincount(px.ravel()).argmax())
    f = font(18, b'SemiBold Condensed')
    for k, text in enumerate(LIST_LINES):
        y0 = k * 24
        out[y0:y0 + 24, :] = bg
        im = Image.new('L', (px.shape[1], 24), 0)
        d = ImageDraw.Draw(im)
        d.fontmode = '1'
        d.text((1, 2), text, font=f, fill=255)
        solid = np.array(im) >= 128
        edge = solid & ~ndi.binary_erosion(solid, structure=np.ones((3, 3), bool))   # hollow outline like the original
        band = out[y0:y0 + 24]
        band[edge] = pal.white
    return out
