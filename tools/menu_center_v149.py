"""v149: centre the Mode Select list labels in the green side panel (DAT2/MENU.BIZ, TIM 0x22800).

The original Japanese labels were centred on x~936 (SOLO PLAY ... TRAINING cells) and x~1071 (SKILL 99 ... OPTIONS
cells) of the 1280x256 atlas; the English cells sat about 8 px to the right, so labels such as OPTIONS and RECORDS hugged
the right edge of the panel. Each label's ink is shifted horizontally (no resampling) to its original Japanese centre.
"""
import numpy as np

# (name, rows y0..y1 covering only this label, search window x0..x1, original JP ink centre)
JOBS = [
    ('SOLO PLAY', (89, 108), (885, 1015), 936.0),
    ('VERSUS', (113, 132), (885, 1015), 937.5),
    ('LEAGUE', (137, 156), (885, 1015), 936.0),
    ('TEAM BATTLE', (161, 180), (885, 1015), 935.5),
    ('TOURNAMENT', (185, 204), (885, 1015), 934.5),
    ('CO-OP', (209, 228), (885, 1015), 935.5),
    ('TRAINING', (233, 251), (885, 1015), 936.0),
    ('SKILL 99', (1, 20), (1024, 1135), 1071.0),
    ('GORIN FEST', (24, 45), (1024, 1135), 1071.0),
    ('EDIT', (47, 70), (1024, 1135), 1072.0),
    ('BONUS', (72, 94), (1024, 1135), 1071.0),
    ('RECORDS', (96, 118), (1024, 1135), 1071.5),
    ('OPTIONS', (120, 142), (1024, 1135), 1072.0),
]


def center_label(px, rows, window, center, bg=0):
    y0, y1 = rows
    x0, x1 = window
    reg = px[y0:y1 + 1, x0:x1 + 1]
    cols = np.where((reg != bg).any(0))[0]
    a, b = x0 + int(cols.min()), x0 + int(cols.max())
    w = b - a + 1
    a2 = int(round(center - (w - 1) / 2.0))
    block = px[y0:y1 + 1, a:b + 1].copy()
    out = px.copy()
    lo, hi = min(a, a2), max(b, a2 + w - 1)
    out[y0:y1 + 1, lo:hi + 1] = bg
    out[y0:y1 + 1, a2:a2 + w] = block
    return out, (a, b), (a2, a2 + w - 1), (lo, hi)


def patch_menu(px):
    rects = []
    for name, rows, window, center in JOBS:
        px, old, new, (lo, hi) = center_label(px, rows, window, center)
        rects.append((lo, rows[0], hi - lo + 1, rows[1] - rows[0] + 1))
    return px, rects
