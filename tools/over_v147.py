"""v147: English shared overlay prompts in DAT2/OVER.TIZ (TIM at 0, 256x240, 4-bit).

Found 2026-11-24 via a VRAM capture at Solo Play character select (see HANDOFF_NEXT_CHAT.md): the top-right prompt is one
quad per message, centred on screen by its width, reading a 16-row-spaced text sheet from this texture:
  v=84  あと [n] コインを入れて！   (two pieces: x 0..15 and 24..94, a number sprite is drawn between them)
  v=100 かかって来なさい！          (quad 88 wide)
  v=116 スタートボタンを押して！    (quad 112 wide)
  v=132 連勝中！挑戦者              (x 16..99)
  v=148 CONTINUE?, v=164 GAME OVER, v=180 PRESS START BUTTON are already English and are the style reference
  v=196 ちょっと待って！            (x 0..76; the big GAME OVER logo starts at y=209)
Style (copied from the English rows): fill index 3 (white), index 7 shade one pixel down-right, 8 px capitals in a
12-row cell (cap rows 2..9, shade row 10).
"""
import numpy as np
from PIL import Image, ImageDraw, ImageFont
from charselect_v145 import place, paint

FILL, SHADE = 3, 7
CAP_H = 8
THIN = 'C:/Windows/Fonts/verdana.ttf'  # wide, 1 px strokes like the original English rows


FONTS = ['C:/Windows/Fonts/verdana.ttf', 'C:/Windows/Fonts/tahoma.ttf', 'C:/Windows/Fonts/arial.ttf']


def _raw_mask(text, font, cap):
    for size in range(16, 6, -1):
        f = ImageFont.truetype(font, size)
        l, t, r, b = f.getbbox('H')
        if b - t != cap:
            continue
        bl, bt, br, bb = f.getbbox(text)
        im = Image.new('L', (br - bl, cap + 4), 0)
        d = ImageDraw.Draw(im)
        d.fontmode = '1'
        d.text((-bl, 2 - t), text, font=f, fill=255)
        a = np.array(im) > 0
        ys, xs = np.where(a)
        return a[ys.min():ys.max() + 1, xs.min():xs.max() + 1]
    return None


def thin_mask(text, max_w, cap=CAP_H):
    """Crisp 1-bit capitals, `cap` px high. Tries wide-to-narrow fonts; if none fits max_w the narrowest is squeezed."""
    best = None
    for font in FONTS:
        a = _raw_mask(text, font, cap)
        if a is None:
            continue
        best = a
        if a.shape[1] <= max_w:
            return a
    if best is None:
        raise ValueError('no font gives cap height %d' % cap)
    img = Image.fromarray((best * 255).astype(np.uint8)).resize((max_w, best.shape[0]), Image.Resampling.LANCZOS)
    return np.array(img) >= 110


# (cell rect x, v, w, h) -> list of (text, x offset of the text slot, slot width)
ROWS = [
    ((0, 84, 100, 12), [('ADD', 0, 17), ('COINS!', 24, 71)], 'insert coin (number sprite sits between the pieces)'),
    ((0, 100, 90, 12), [('COME ON!', 0, 88)], 'かかって来なさい！'),
    ((0, 116, 114, 12), [('PRESS START!', 0, 112)], 'スタートボタンを押して！'),
    ((0, 132, 104, 12), [('STREAK! RIVAL', 16, 84)], '連勝中！挑戦者'),
    ((0, 196, 80, 12), [('HOLD ON!', 0, 77)], 'ちょっと待って！'),
]


def patch_over(px):
    rects = []
    style = ([FILL] * 12, [SHADE] * 12)
    for rect, parts, _ in ROWS:
        x, y, w, h = rect
        core = np.zeros((h, w), dtype=bool)
        for text, off, slot in parts:
            m = thin_mask(text, slot)
            ox = off + (slot - m.shape[1]) // 2
            core[2:2 + CAP_H, ox:ox + m.shape[1]] |= m
        px = paint(px, rect, core, 0, style, shadow=(1, 1, SHADE))
        rects.append(rect)
    return px, rects
