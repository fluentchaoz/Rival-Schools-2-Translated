"""v160: English fighter name labels in DAT2/CEFT1.BIZ TIM 0x10800 (queue task 003), on top of the v157 HUD jobs.

The labels are small brush-style kanji/katakana sprites (about 20x30 px each, drawn under the health bars). English is
painted in the colour layering learnt from the originals, rotated 90 degrees (top to bottom) when that gives bigger letters
than horizontal text, and horizontal for the squarish one-glyph cells. Only labels identified with confidence are touched.
Cells that could not be identified safely (the two-glyph pair at (25,185,47,20) and the tall cells at (98..145,191..199)
that read as ロベルト/ハヤト) stay Japanese until checked in game.
"""
import numpy as np
from PIL import Image

from hud_v150 import learn, layer_indices, layered, text_mask
from hud_v157 import patch_ceft1 as patch_ceft1_157

# (rect x, y, w, h), English
LABELS = [
    ((0, 152, 24, 32), 'DAIGO'),        # 醍醐
    ((23, 151, 25, 33), 'SHOMA'),       # 将馬
    ((49, 154, 22, 29), 'BATSU'),       # バツ
    ((73, 153, 22, 36), 'KYOKO'),       # 響子
    ((97, 162, 20, 28), 'ROY'),         # ロイ
    ((122, 162, 19, 29), 'RAN'),        # ラン
    ((143, 161, 25, 35), 'KYOSUKE'),    # 恭介
    ((168, 162, 21, 36), 'EDGE'),       # エッジ
    ((193, 162, 20, 46), 'AKIRA'),      # アキラ
    ((215, 159, 25, 34), 'HIDEO'),      # 英雄
    ((0, 184, 23, 21), 'NATSU'),        # 夏
    ((2, 209, 20, 43), 'HINATA'),       # ひなた
    ((49, 207, 21, 49), 'BOMAN'),       # ボーマン
    ((71, 193, 22, 19), 'GAN'),         # 岩
    ((27, 210, 17, 44), 'SAKURA'),      # さくら
    ((71, 218, 25, 36), 'RAIZO'),       # 雷蔵
]
OUTLINE = 0
TIFFANY = ((98, 191, 21, 65), 'TIFFANY')   # ティファニー (tall katakana cell)
LABELS.append(TIFFANY)


def _style(src, rects):
    table, loose = {}, {}
    for r in rects:
        t, l = learn(src, r)
        for k, v in t.items():
            table.setdefault(k, v)
        for k, v in l.items():
            loose.setdefault(k, v)
    return layer_indices(table, loose)


def _stack(lines, aw, ah_total, gap=1):
    """Text lines stacked top to bottom inside aw x ah_total; every line gets the same letter height."""
    per = (ah_total - gap * (len(lines) - 1)) // len(lines)
    masks = [text_mask(t, aw, per, shear=0.0, gap=1, variation=b'Bold') for t in lines]
    hh = min(m.shape[0] for m in masks)            # keep letter height uniform
    masks = [m if m.shape[0] == hh else np.array(Image.fromarray((m * 255).astype(np.uint8)).resize((m.shape[1], hh), Image.Resampling.LANCZOS)) >= 128 for m in masks]
    W = max(m.shape[1] for m in masks)
    out = np.zeros((hh * len(masks) + gap * (len(masks) - 1), W), bool)
    for i, m in enumerate(masks):
        out[i * (hh + gap):i * (hh + gap) + hh, (W - m.shape[1]) // 2:(W - m.shape[1]) // 2 + m.shape[1]] = m
    return out, hh


def render_label(px, text, rect, layers):
    x, y, w, h = rect
    splits = [[text]]
    if len(text) >= 5:
        k = (len(text) + 1) // 2
        splits.append([text[:k], text[k:]])
    best = None
    for orient in ('v', 'h'):
        for lines in splits:
            for margin in (2, 3, 4):
                aw, ah = (h - margin, w - margin) if orient == 'v' else (w - margin, h - margin)
                if aw < 6 or ah < 5:
                    continue
                core, hh = _stack(lines, aw, ah)
                painted = layered(core, OUTLINE, (1, 1), layers)
                if orient == 'v':
                    painted = np.rot90(painted, -1)
                ph, pw = painted.shape
                if ph <= h and pw <= w:
                    score = (hh, core.shape[0] * core.shape[1])
                    if best is None or score > best[0]:
                        best = (score, painted)
                    break
    if best is None:
        raise ValueError('%r does not fit %dx%d' % (text, w, h))
    painted = best[1]
    ph, pw = painted.shape
    out = px.copy()
    out[y:y + h, x:x + w] = 0
    out[y + (h - ph) // 2:y + (h - ph) // 2 + ph, x + (w - pw) // 2:x + (w - pw) // 2 + pw] = painted
    return out


def patch_labels(px, src):
    layers = _style(src, [r for r, _ in LABELS])
    out = px.copy()
    for rect, text in LABELS:
        out = render_label(out, text, rect, layers)
    return out, [r for r, _ in LABELS]


def patch_ceft1(orig_px):
    px, rects = patch_ceft1_157(orig_px)
    px, r2 = patch_labels(px, orig_px)
    return px, rects + r2
