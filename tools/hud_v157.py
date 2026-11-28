"""v157: more English fight art on top of v152's HUD + v155 prompts (queue tasks 008, 012).

DAT2/CEFT1.BIZ TIM 0x10800 (styles learnt from the ORIGINAL sprites):
  辛勝 win banner: 幸 (705,108,53,32) -> CLOSE and 勝 (514,112,59,39) -> WIN; the "!" is the shared exclamation cell (done in v151).
  (The on-screen N発 combo counter and the 先制 popup are NOT in this sheet: they are drawn at run time from the font,
   in the red-grid reserved area; they live in code strings. 発 at (711,143) belongs to the finish-move caption strip.)
DAT2/PL140, PL240, PL410 (TIM 0x6800, 256x256): 回復 under GUTS UP / LIFE UP -> HEAL (same pixels in all three files).
"""
import numpy as np

from hud_v150 import render_cell
from hud_v155 import patch_all155

KOU = (705, 108, 53, 32)      # 幸 (of 辛勝)
SHOU = (514, 112, 59, 39)     # 勝
PL_FILES = ['DAT2/PL140.BIZ', 'DAT2/PL240.BIZ', 'DAT2/PL410.BIZ']
PL_TIM = 0x6800


def patch_ceft1(orig_px):
    px, rects = patch_all155(orig_px)
    out = px.copy()
    out = render_cell(out, 'CLOSE', KOU, [KOU], src=orig_px, text_h=26, gap=1, shear=0.12, align='right')
    out = render_cell(out, 'WIN', SHOU, [SHOU], src=orig_px, text_h=32, gap=2, shear=0.12, align='left')
    return out, rects + [KOU, SHOU]


def recovery_rect(px):
    """Cell of the 回復 sprite: columns 128..206, rows 32..63 (a leaf sprite sits left of x=128, the heart right of x=207)."""
    return (128, 32, 79, 32)


def patch_recovery(px):
    rect = recovery_rect(px)
    out = render_cell(px.copy(), 'HEAL', rect, [rect], src=px, text_h=rect[3] - 4, gap=2, shear=0.0, align='center')
    return out, [rect]
