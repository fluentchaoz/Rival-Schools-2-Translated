"""v148: fit clipped English labels on the Mode Select screen (DAT2/MENU.BIZ, TIM at 0x22800, 1280x256 indexed).

The game crops each baked label sprite to roughly the width of the original Japanese, so English that is wider than
that gets cut off on screen: the unselected list labels SOLO PLAY / TRAINING / SKILL 99 and the matching card tab
titles ("SOLO PLF", "TRAININ", "SKILL 9"). Observed from v147 in game (2026-11-24).

Each job squeezes one existing English label horizontally into a target span, keeping the exact pixel style (palette
indices): every output column takes the most common non-zero index of the source columns it covers.
"""
import numpy as np

# (name, rows y0..y1 inclusive, current ink span a..b, target span a2..b2)
JOBS = [
    ('tab SOLO PLAY', (84, 107), (307, 413), (308, 398)),
    ('tab TRAINING', (115, 138), (313, 407), (315, 398)),
    ('tab SKILL 99', (147, 171), (313, 407), (315, 398)),
    ('list SOLO PLAY', (89, 108), (891, 997), (892, 979)),
    ('list TRAINING', (233, 251), (897, 991), (893, 980)),
    ('list SKILL 99', (1, 20), (1033, 1127), (1025, 1117)),
]


def squeeze(px, rows, src, dst, bg=0):
    y0, y1 = rows
    a, b = src
    a2, b2 = dst
    old_w, new_w = b - a + 1, b2 - a2 + 1
    block = px[y0:y1 + 1, a:b + 1].copy()
    out = px.copy()
    lo, hi = min(a, a2), max(b, b2)
    out[y0:y1 + 1, lo:hi + 1] = bg
    ratio = old_w / new_w
    for i in range(new_w):
        s0 = int(round(i * ratio))
        s1 = max(s0 + 1, int(round((i + 1) * ratio)))
        cols = block[:, s0:min(s1, old_w)]
        col = np.zeros(block.shape[0], dtype=px.dtype)
        for r in range(block.shape[0]):
            vals = cols[r][cols[r] != bg]
            if len(vals):
                u, c = np.unique(vals, return_counts=True)
                col[r] = u[np.argmax(c)]
        out[y0:y1 + 1, a2 + i] = col
    return out


def patch_menu(px):
    rects = []
    for name, rows, src, dst in JOBS:
        px = squeeze(px, rows, src, dst)
        lo, hi = min(src[0], dst[0]), max(src[1], dst[1])
        rects.append((lo, rows[0], hi - lo + 1, rows[1] - rows[0] + 1))
    return px, rects
