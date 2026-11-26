"""v151: second batch of English fight HUD art in DAT2/CEFT1.BIZ (TIM 0x10800), applied on top of exact v150.

Uses the style-learning painter from hud_v150 (colour layering learnt from the original sprite). All regions here are
untouched in v150, so styles are learnt from the v150 pixels themselves.
  開始! (257,129,165,54): three sprites 開 | 始 | !  (column ink minima at x=336..338 and 394..395) -> FIG | HT | !
  制 (512,32,55,32) 倒 (569,34,54,30) 圧 (624,32,55,32) ! (680,32,55,32): banners are 制圧! = 制+圧+! and 圧倒! = 圧+倒+! ->
      SU|PER|! = "SUPER!" and PER|FECT|! = "PERFECT!"
  時間切れ (512,87,95,20) -> TIME UP;  引き分け (608,86,95,19) -> DRAW
  完全夢想アタック (512,160,127,30) -> DREAM ATTACK;  根性カウンター (640,160,127,30) -> GUTS COUNTER
"""
import numpy as np
from hud_v150 import render_cell

KAISHI = (257, 129, 165, 54)
# cells end 1 px short of the guessed sprite seams (x=337, 394); letters hug the seams so the abutting sprites read as one word
KAISHI_CELLS = [((257, 129, 80, 54), 'FIG', 'right'), ((338, 129, 55, 54), 'HT', 'left'), ((394, 129, 28, 54), '!', 'left')]
SEI = [(512, 32, 55, 32), (569, 34, 54, 30), (624, 32, 55, 32), (680, 32, 55, 32)]
# In-game order (seen in v152 footage: win banner read "FECT PER !" with the old order): 制圧! = cell0 + cell2 + cell3,
# 圧倒! = cell2 + cell1 + cell3, so cell1 is 倒 and cell2 is 圧.
SEI_TEXT = ['SU', 'FECT', 'PER', '!']
SEI_ALIGN = ['right', 'left', 'center', 'left']
TIMEUP = (512, 87, 95, 20)
DRAW = (608, 86, 95, 19)
MOVES = [((512, 160, 127, 30), 'DREAM ATTACK'), ((640, 160, 127, 30), 'GUTS COUNTER')]


def patch_hud2(px):
    orig = px.copy()
    rects = []
    out = px.copy()
    x, y, w, h = KAISHI
    out[y:y + h, x:x + w] = 0
    for rect, text, al in KAISHI_CELLS:
        out = render_cell(out, text, rect, [KAISHI], src=orig, text_h=44, gap=3, align=al)
        rects.append(rect)
    rects.append(KAISHI)
    for rect, text, al in zip(SEI, SEI_TEXT, SEI_ALIGN):
        # PER sits between SU and ! in SUPER! and before FECT in PERFECT!, so it is stretched to touch both neighbours
        out = render_cell(out, text, rect, SEI, src=orig, text_h=26, gap=2, shear=0.15, align=al, stretch=(text == 'PER'))
        rects.append(rect)
    out = render_cell(out, 'TIME UP', TIMEUP, [TIMEUP], src=orig, text_h=14, gap=2, shear=0.1, band_map=(0, 1, 1, 1))
    out = render_cell(out, 'DRAW', DRAW, [DRAW], src=orig, text_h=14, gap=2, shear=0.1, band_map=(0, 1, 1, 1))
    rects += [TIMEUP, DRAW]
    for rect, text in MOVES:
        out = render_cell(out, text, rect, [m[0] for m in MOVES], src=orig, text_h=22, gap=2, shear=0.12, band_map=(0, 1, 1, 1))
        rects.append(rect)
    return out, rects
