"""v152: v150 + v151 HUD art re-rendered from the ORIGINAL sprites with seam-hugging alignment (queue task 001).

The v150/v151 builds painted letters centred in each sprite cell, which left visible gaps where the game draws cells
side by side (FIG HT !, ROUND   1). Here every job right-aligns the left cell's text and left-aligns the right cell's,
starting again from the original disc pixels so styles are learnt from the real art, not from earlier English.
"""
from hud_v150 import patch_hud
from hud_v151 import patch_hud2


def patch_all(orig_px):
    px, r1 = patch_hud(orig_px.copy())
    px, r2 = patch_hud2(px)
    return px, r1 + r2
