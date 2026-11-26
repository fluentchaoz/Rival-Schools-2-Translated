"""v150: English fight HUD announcer art in DAT2/CEFT1.BIZ (TIM at 0x10800, 768x256, 4-bit).

Sprites (x, y, w, h of the original ink; the game draws each as its own quad and crops to roughly this box, so English
may not exceed it):
  最 (257,1,77,60) 終 (337,2,86,57)     = FINAL          (shown as "FIN" + "AL")
  第 (256,64,79,61) 戦 (336,65,87,60)   = ROUND n        (第 + numeral + 戦; the numerals are the kanji 一..五 at x>=428)
  決 (258,182) 着 (346,184,78,63)       = FINISH
  準備OK!! (158,92,88,15)               = READY!!        (small, both lower corners)
Style handling: the originals are hand-drawn brush script (blue outline, red/purple gradient fill, brown/orange shadow,
white sparkles). Rather than guess indices, each job LEARNS how colour depends on position inside the original ink:
  fa = run length to the nearest top-left edge, fb = run length to the nearest bottom-right edge, band = vertical
  quarter of the sprite. table[(fa,fb,band)] = most common palette index in the original. The English silhouette
  (letters + outline ring + drop shadow) is then painted through the same table, so outline, gradient and shadow colours
  come from the art itself and match whichever CLUT the game binds to that sprite.
"""
import numpy as np
from PIL import Image, ImageDraw, ImageFont
from scipy.ndimage import binary_dilation
from collections import Counter

FONT = 'C:/Windows/Fonts/bahnschrift.ttf'
VARIATION = b'Bold Condensed'
SMALL_FONT = 'C:/Windows/Fonts/arialbd.ttf'
SHEAR = 0.22


def _runs(ink):
    h, w = ink.shape
    L = np.zeros((h, w), int); U = np.zeros((h, w), int); R = np.zeros((h, w), int); D = np.zeros((h, w), int)
    for y in range(h):
        for x in range(w):
            if ink[y, x]:
                L[y, x] = (L[y, x - 1] if x else 0) + 1
                U[y, x] = (U[y - 1, x] if y else 0) + 1
    for y in range(h - 1, -1, -1):
        for x in range(w - 1, -1, -1):
            if ink[y, x]:
                R[y, x] = (R[y, x + 1] if x < w - 1 else 0) + 1
                D[y, x] = (D[y + 1, x] if y < h - 1 else 0) + 1
    return np.minimum(L, U), np.minimum(R, D)


CAP_A, CAP_B = 4, 7


def _keys(ink):
    ys, xs = np.where(ink)
    y0, y1 = ys.min(), ys.max()
    fa, fb = _runs(ink)
    band = np.clip(((np.arange(ink.shape[0]) - y0) * 4) // max(1, y1 - y0 + 1), 0, 3)
    return fa, fb, band


def learn(px, rect):
    """Table {(fa,fb,band): index} from the ink (non-zero pixels) of `rect` in px."""
    x, y, w, h = rect
    reg = px[y:y + h, x:x + w]
    ink = reg != 0
    fa, fb, band = _keys(ink)
    votes = {}
    for yy, xx in zip(*np.where(ink)):
        k = (min(fa[yy, xx], CAP_A), min(fb[yy, xx], CAP_B), int(band[yy]))
        votes.setdefault(k, Counter())[int(reg[yy, xx])] += 1
    table = {k: c.most_common(1)[0][0] for k, c in votes.items()}
    loose = {}
    for (a, b, bd), v in votes.items():
        loose.setdefault((a, b), Counter()).update(v)
    loose = {k: c.most_common(1)[0][0] for k, c in loose.items()}
    return table, loose


def lookup(table, loose, a, b, band):
    a, b = min(a, CAP_A), min(b, CAP_B)
    k = (a, b, band)
    if k in table:
        return table[k]
    if (a, b) in loose:
        return loose[(a, b)]
    near = min(loose, key=lambda q: abs(q[0] - a) * 2 + abs(q[1] - b))
    return loose[near]


def apply_style(ink, table, loose):
    h, w = ink.shape
    out = np.zeros((h, w), dtype=np.uint8)
    if not ink.any():
        return out
    fa, fb, band = _keys(ink)
    for yy, xx in zip(*np.where(ink)):
        out[yy, xx] = lookup(table, loose, fa[yy, xx], fb[yy, xx], int(band[yy]))
    return out


def trim(a):
    ys, xs = np.where(a)
    return a[ys.min():ys.max() + 1, xs.min():xs.max() + 1]


def text_mask(text, max_w, max_h, font=FONT, shear=SHEAR, gap=3, variation=None):
    """Crisp 1-bit italic mask of `text` fitted inside max_w x max_h with a uniform scale (letters are never squeezed).
    Letters are rendered separately and placed `gap` px apart so outline rings of neighbours do not merge."""
    f = ImageFont.truetype(font, 160)
    if font == FONT:
        f.set_variation_by_name(variation or VARIATION)
    top = min(f.getbbox(c)[1] for c in text if c != ' ')
    bot = max(f.getbbox(c)[3] for c in text if c != ' ')
    H = bot - top
    glyphs = []
    for c in text:
        if c == ' ':
            glyphs.append(np.zeros((H, 60), bool))
            continue
        l, t, r, b = f.getbbox(c)
        im = Image.new('L', (r - l, H), 0)
        ImageDraw.Draw(im).text((-l, -top), c, fill=255, font=f)
        glyphs.append(np.array(im) > 100)
    wsum = sum(g.shape[1] for g in glyphs)
    n = len(glyphs)
    s = min(max_h / H, (max_w - gap * (n - 1)) / (wsum + shear * H))
    gh = max(1, int(round(H * s)))
    cols = []
    for g in glyphs:
        w = max(1, int(round(g.shape[1] * s)))
        img = Image.fromarray((g * 255).astype(np.uint8)).resize((w, gh), Image.Resampling.LANCZOS)
        cols.append(np.array(img) >= 128)
    sh_px = int(round(shear * gh))
    total = sum(c.shape[1] for c in cols) + gap * (n - 1) + sh_px
    out = np.zeros((gh, total), bool)
    x = 0
    for c in cols:
        out[:, x:x + c.shape[1]] |= c
        x += c.shape[1] + gap
    # shear: shift each row right proportionally to its height above the baseline
    res = np.zeros_like(out)
    for y in range(gh):
        d = int(round((gh - 1 - y) * shear))
        res[y, d:] = out[y, :total - d] if d else out[y]
    return trim(res)


def silhouette(core, outline=2, shadow=(3, 3)):
    """Letters + outline ring + drop shadow, as one ink mask on a canvas big enough to hold it."""
    h, w = core.shape
    pad = outline + max(shadow) + 1
    canvas = np.zeros((h + 2 * pad, w + 2 * pad), bool)
    canvas[pad:pad + h, pad:pad + w] = core
    body = binary_dilation(canvas, iterations=outline) if outline else canvas
    sh = np.zeros_like(body)
    sh[shadow[1]:, shadow[0]:] = body[:body.shape[0] - shadow[1], :body.shape[1] - shadow[0]]
    return body | sh


def render_cell(px, text, rect, style_rects, src=None, font=FONT, outline=1, shadow=(2, 2), shear=SHEAR, align='center', gap=3,
                text_h=None, variation=None, band_map=None, stretch=False):
    """Paint `text` into rect (x,y,w,h) of px, in the style learnt from the union of style_rects. Returns new px."""
    x, y, w, h = rect
    src = px if src is None else src
    tables = [learn(src, r) for r in style_rects]
    # merge tables of all style rects (votes are already reduced; first wins, others fill gaps)
    table, loose = {}, {}
    for t, l in tables:
        for k, v in t.items():
            table.setdefault(k, v)
        for k, v in l.items():
            loose.setdefault(k, v)
    avail_w, avail_h = w - (2 * outline + shadow[0]), h - (2 * outline + shadow[1])
    if text_h:
        avail_h = min(avail_h, text_h)
    core = text_mask(text, avail_w, avail_h, font=font, shear=shear, gap=gap, variation=variation)
    if stretch and core.shape[1] < avail_w:  # widen the letterforms to fill the cell edge to edge (abutting sprites)
        core = np.array(Image.fromarray((core * 255).astype(np.uint8)).resize((avail_w, core.shape[0]), Image.Resampling.LANCZOS)) >= 128
    layers = layer_indices(table, loose)
    if band_map:
        layers = {b: layers[band_map[b]] for b in range(4)}
    painted = layered(core, outline, shadow, layers)
    sh, sw = painted.shape
    if sh > h or sw > w:
        raise ValueError(f'{text!r} silhouette {sw}x{sh} exceeds cell {w}x{h}')
    out = px.copy()
    out[y:y + h, x:x + w] = 0
    ox = {'center': x + (w - sw) // 2, 'left': x, 'right': x + w - sw}[align]
    oy = y + (h - sh) // 2
    out[oy:oy + sh, ox:ox + sw] = painted
    return out


def layer_indices(table, loose):
    """Per vertical band: (fill, ring, shadow) palette indices read from the learnt table of the original art."""
    out = {}
    for band in range(4):
        fill = table.get((CAP_A, CAP_B, band)) or table.get((CAP_A, CAP_B - 1, band)) or loose.get((CAP_A, CAP_B))
        ring = table.get((1, CAP_B, band)) or table.get((1, CAP_B - 1, band)) or table.get((1, 3, band)) or loose.get((1, CAP_B))
        shad = table.get((CAP_A, 1, band)) or table.get((3, 1, band)) or table.get((2, 1, band)) or loose.get((CAP_A, 1)) or loose.get((1, 1))
        out[band] = (fill, ring, shad)
    return out


def layered(core, outline, shadow, layers):
    h, w = core.shape
    pad = outline + max(shadow) + 1
    cv = np.zeros((h + 2 * pad, w + 2 * pad), bool)
    cv[pad:pad + h, pad:pad + w] = core
    body = binary_dilation(cv, iterations=outline) if outline else cv
    sh = np.zeros_like(body)
    sh[shadow[1]:, shadow[0]:] = body[:body.shape[0] - shadow[1], :body.shape[1] - shadow[0]]
    allm = body | sh
    ys, xs = np.where(allm)
    y0, y1, x0, x1 = ys.min(), ys.max() + 1, xs.min(), xs.max() + 1
    cv, body, sh = cv[y0:y1, x0:x1], body[y0:y1, x0:x1], sh[y0:y1, x0:x1]
    H, W = cv.shape
    out = np.zeros((H, W), np.uint8)
    for yy in range(H):
        band = min(3, (yy * 4) // H)
        fill, ring, shad = layers[band]
        row = out[yy]
        row[sh[yy] & ~body[yy]] = shad
        row[body[yy] & ~cv[yy]] = ring
        row[cv[yy]] = fill
    return out


# --- jobs ---------------------------------------------------------------------------------------------------------
# (name, text, rect to repaint, style source rects, kwargs)
DIGIT_CELLS = {
    1: (428, 0, 78, 24), 2: (428, 24, 77, 44), 3: (428, 68, 80, 58), 4: (428, 126, 82, 42), 5: (428, 166, 84, 62),
}
SEL = [(257, 1, 77, 60), (337, 2, 86, 57)]      # 最終 (style source)
DAI = [(256, 64, 79, 61), (336, 65, 87, 60)]     # 第戦
KET = [(258, 182, 88, 62), (346, 184, 78, 63)]   # 決着
# The small 8x? 準備OK!! font: 9 rows (y 97..105), rows filled b,b,c,c,d,d,e,e,e, 1 px shadow 'a' down-right (no outline).
READY_RECT = (160, 96, 80, 11)
READY_FILL = [0xb, 0xb, 0xc, 0xc, 0xd, 0xd, 0xe, 0xe, 0xe]
READY_SHADOW = 0xa
JOBS = [
    ('FIN', 'FIN', SEL[0], SEL, dict(align='right')),
    ('AL', 'AL', SEL[1], SEL, dict(align='left')),
    ('ROUND', 'ROUND', DAI[0], DAI, dict(gap=3, text_h=28, outline=1, shadow=(1, 1), shear=0.15, align='right')),
    ('BLANK-SEN', '', DAI[1], None, {}),
    ('FIN2', 'FIN', KET[0], KET, dict(align='right')),
    ('ISH', 'ISH', KET[1], KET, dict(align='left')),
] + [(f'num{n}', str(n), r, DAI, dict(text_h=20, outline=1, shadow=(1, 1), shear=0.15, variation=b'Bold', align='left')) for n, r in DIGIT_CELLS.items()] + [
]


def patch_hud(px):
    orig = px.copy()
    rects = []
    for name, text, rect, styles, kw in JOBS:
        if not text:
            x, y, w, h = rect
            px = px.copy()
            px[y:y + h, x:x + w] = 0
        else:
            px = render_cell(px, text, rect, styles, src=orig, **kw)
        rects.append(rect)
    px = small_text(px, READY_RECT, 'READY!!', READY_FILL, READY_SHADOW, cx=198.5, top=97, spacing=3)
    rects.append(READY_RECT)
    return px, rects


def small_text(px, rect, text, fills, shadow_idx, cx, top, font=SMALL_FONT, cap=9, spacing=1):
    """Hard-edged bitmap caps `cap` px high centred on column cx; row r of the glyph uses fills[r]; 1 px shadow down-right."""
    for size in range(8, 20):
        f = ImageFont.truetype(font, size)
        if f.getbbox('H')[3] - f.getbbox('H')[1] == cap:
            break
    else:
        raise ValueError('no size gives cap height')
    top_off = f.getbbox('H')[1]
    cells = []
    for c in text:
        l, t, r, b = f.getbbox(c)
        im = Image.new('L', (max(1, r - l) + 2, cap + 4), 0)
        d = ImageDraw.Draw(im)
        d.fontmode = '1'
        d.text((1 - l, 1 - top_off), c, font=f, fill=255)
        a = np.array(im) > 0
        ys, xs = np.where(a[:, :])
        cells.append(a[:, xs.min():xs.max() + 1] if len(xs) else a[:, :2])
    W = sum(c.shape[1] for c in cells) + spacing * (len(cells) - 1)
    core = np.zeros((cap + 4, W), bool)
    x = 0
    for c in cells:
        core[:, x:x + c.shape[1]] |= c
        x += c.shape[1] + spacing
    core = core[1:1 + cap]
    x0, y0, w, h = rect
    if W + 1 > w:
        raise ValueError('text %d wide, rect %d' % (W, w))
    out = px.copy()
    out[y0:y0 + h, x0:x0 + w] = 0
    ox = int(round(cx - W / 2.0)) - 0
    oy = top
    sh = np.zeros((cap + 1, W + 1), bool)
    sh[1:, 1:] = core
    for yy in range(cap + 1):
        for xx in range(W + 1):
            if sh[yy, xx] and not (yy < cap and xx < W and core[yy, xx]):
                out[oy + yy, ox + xx] = shadow_idx
    for yy in range(cap):
        out[oy + yy, ox:ox + W][core[yy]] = fills[yy]
    return out
