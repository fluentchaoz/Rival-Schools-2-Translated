"""v145: English Solo Play character select (banner, LEAD/PARTNER headers, name captions).

Geometry (decoded from DAT1/PLSELn.BIN, see CHARSELECT_NOTES.md):
  * Banner: the overlay draws a string at file offset 0x56c = count byte + (col,row) pairs, each a 32x32 cell
    of the DAT2/SELPn.BIZ TIM at 0x17800, page x offset 256 (u = col*32, v = row*32).
  * Headers (lead/partner): 40x20 sprites at v=220, u = 0 / 40.
  * Name captions: 48x16 sprites, page x offset 512, (u,v) listed by a table at overlay 0x2a0.
The five SELP atlases are identical in these regions, so one set of edits is applied to all.
"""
import numpy as np
from PIL import Image, ImageDraw, ImageFont
from scipy.ndimage import binary_dilation
from img_label import learn_style
from build_practice_v30 import tim, replace_pixels

BOLD = 'C:/Windows/Fonts/arialbd.ttf'

BANNER_PAGE_X = 256
NAME_PAGE_X = 512

# PLAYER SELECT from six 32x32 cells (1..6,2), originally キ ャ ラ ク タ セ. Cells (7,2) レ, (0,3) ト and (2,1) ー are
# shared with the league / tournament titles (PLSEL3 / PLSEL4) and row 3 holds the small English number font, so none
# of those are touched. (0,0) in a string is a skipped blank slot, used as the word gap.
BANNER_CELLS = [((1, 2), 'PL'), ((2, 2), 'AY'), ((3, 2), 'ER'), ((4, 2), 'SE'), ((5, 2), 'LE'), ((6, 2), 'CT')]
BANNER_SEQ = [(1, 2), (2, 2), (3, 2), (0, 0), (4, 2), (5, 2), (6, 2)]
STYLE_CELLS = [(c, 2) for c in range(1, 8)] + [(0, 3), (2, 1)]  # original キャラクタセレ/ト/ー glyphs, style source only
BANNER_OLD = bytes([10, 1, 2, 2, 2, 3, 2, 4, 2, 5, 2, 2, 1, 6, 2, 7, 2, 4, 2, 0, 3])
BANNER_NEW = bytes([len(BANNER_SEQ)] + [v for c in BANNER_SEQ for v in c])
BANNER_NEW = BANNER_NEW + bytes(len(BANNER_OLD) - len(BANNER_NEW))

HEADERS = [((0, 220, 40, 20), 'LEAD'), ((40, 220, 40, 20), 'PARTNER')]

# (u, v) of each 48x16 name cell -> English (same spellings as the dialogue translation).
NAMES = {
    (96, 0): 'KYOSUKE', (0, 0): 'BATSU', (48, 0): 'HINATA', (144, 0): 'SHOMA', (192, 0): 'NATSU',
    (0, 16): 'ROBERTO', (48, 16): 'ROY', (96, 16): 'TIFFANY', (144, 16): 'BOMAN', (192, 16): 'EDGE',
    (0, 32): 'AKIRA', (48, 32): 'GAN', (96, 32): 'HIDEO', (144, 32): 'KYOKO', (192, 32): 'RAIZO',
    (0, 48): 'HYO', (192, 48): 'AKIRA', (48, 48): 'SAKURA', (96, 48): 'DAIGO', (144, 48): 'HAYATO',
    (0, 64): 'HINATA 2', (48, 64): 'NATSU 2', (144, 64): 'TIFFANY 2', (192, 64): 'KYOKO 2',
}
NAME_TABLE_OFFSET = 0x2a0
NAME_TABLE_PAIRS = 30


def render_mask(text, max_w, height, align='center', font=BOLD):
    """Crisp 1-bit mask of `text`, `height` px tall (cap height), at most max_w wide, squeezed if needed."""
    size = 8
    while True:
        f = ImageFont.truetype(font, size)
        l, t, r, b = f.getbbox('H')
        if b - t >= height:
            break
        size += 1
    f = ImageFont.truetype(font, size * 4)
    l, t, r, b = f.getbbox(text)
    big = Image.new('L', (r - l + 8, f.getbbox('H')[3] - f.getbbox('H')[1] + 40), 0)
    ImageDraw.Draw(big).text((4 - l, 20 - f.getbbox('H')[1]), text, fill=255, font=f)
    arr = np.array(big) > 0
    ys, xs = np.where(arr)
    arr = arr[ys.min():ys.max() + 1, xs.min():xs.max() + 1]
    nat_w = max(1, round(arr.shape[1] * height / arr.shape[0]))
    w = min(nat_w, max_w)
    img = Image.fromarray((arr * 255).astype(np.uint8)).resize((w, height), Image.Resampling.LANCZOS)
    return np.array(img) >= 120


def place(mask, w, h, align='center', margin=0):
    out = np.zeros((h, w), dtype=bool)
    mh, mw = mask.shape
    y = (h - mh) // 2
    x = (w - mw) // 2 if align == 'center' else margin
    out[y:y + mh, x:x + mw] = mask
    return out


def learn_union(px, rects, bg=0):
    """Per-row fill/outline learned from several original cells stacked side by side (robust to rows a single glyph leaves empty)."""
    h = rects[0][3]
    stack = np.concatenate([px[y:y + h, x:x + w] for x, y, w, _ in rects], axis=1)
    return learn_style(stack, bg)


def paint(px, rect, core, outline_px, style, shadow=None, bg=0):
    x, y, w, h = rect
    row_fill, row_out = style
    edge = binary_dilation(core, iterations=outline_px) & ~core if outline_px else np.zeros_like(core)
    cell = np.full((h, w), bg, dtype=np.uint8)
    if shadow is not None:
        dx, dy, sidx = shadow
        body = core | edge
        sh = np.zeros_like(body)
        sh[dy:, dx:] = body[:h - dy, :w - dx]
        cell[sh & ~body] = sidx
    for r in range(h):
        cell[r][edge[r]] = row_out[r]
        cell[r][core[r]] = row_fill[r]
    out = px.copy()
    out[y:y + h, x:x + w] = cell
    return out


def banner_rect(cell):
    return (BANNER_PAGE_X + cell[0] * 32, cell[1] * 32, 32, 32)


def patch_selp(px):
    """Return (new pixel array, claimed rectangles) for a SELP atlas (TIM 0x17800)."""
    rects = []
    banner_style = learn_union(px, [banner_rect(c) for c in STYLE_CELLS])
    header_style = learn_union(px, [r for r, _ in HEADERS])
    name_style = learn_union(px, [(NAME_PAGE_X + u, v, 48, 16) for (u, v) in NAMES])
    for cell, text in BANNER_CELLS:
        rect = banner_rect(cell)
        w = 32
        if len(text) == 1:
            core = place(render_mask(text, 13, 22), w, 32, 'left', 5)
        else:
            parts = [render_mask(c, 13, 22) for c in text]
            core = np.zeros((32, w), dtype=bool)
            for i, m in enumerate(parts):
                core |= place(m, w, 32, 'left', 3 + i * 14)
        px = paint(px, rect, core, 1, banner_style, shadow=(2, 2, 1))
        rects.append(rect)
    for rect, text in HEADERS:
        core = place(render_mask(text, rect[2] - 4, 12 if len(text) <= 4 else 8), rect[2], rect[3])
        px = paint(px, rect, core, 1, header_style)
        rects.append(rect)
    for (u, v), text in NAMES.items():
        rect = (NAME_PAGE_X + u, v, 48, 16)
        core = place(render_mask(text, 44, 9), 48, 16)
        px = paint(px, rect, core, 1, name_style)
        rects.append(rect)
    return px, rects


def patch_plsel(before):
    """Rewrite the banner string in a PLSEL overlay. Returns (bytes, claims)."""
    p = before.find(BANNER_OLD)
    if p < 0:
        return before, []  # overlay has no player-select banner (PLSEL2, PLSEL5)
    if before.find(BANNER_OLD, p + 1) >= 0:
        raise ValueError('banner string not unique')
    after = bytearray(before)
    after[p:p + len(BANNER_OLD)] = BANNER_NEW
    return bytes(after), [dict(offset=hex(p), before=BANNER_OLD.hex(), after=BANNER_NEW.hex())]


def check_name_table(overlay):
    """Every name cell the overlay can request must have an English label (or be an unrelated cell)."""
    import struct
    seen = [struct.unpack_from('<HH', overlay, NAME_TABLE_OFFSET + 4 * i) for i in range(NAME_TABLE_PAIRS)]
    return [uv for uv in seen if uv not in NAMES]
