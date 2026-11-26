# 001 Fight HUD spacing: FIGHT! gap and ROUND numeral position

**Needs:** emulator
**Claimed by:** -
**Seen in:** v151 fullscreen, first Solo Play fight (ROUND 1 then FIGHT! banners)
**Source:** `DAT2/CEFT1.BIZ` TIM 0x10800; `tools/hud_v150.py`, `tools/hud_v151.py`

## Problem
FIGHT! reads "FIG HT !" with a visible gap at the sprite seams; the ROUND numeral is a small glyph centred in a 78 px cell so it floats away from ROUND.

## Notes
Cells are drawn abutting. Right-align the left cell's letters and left-align the next one's (`align` param in `render_cell`) so the gaps close; left-align the numerals. Cell rects are in the `hud_v151.py` docstring. Numeral cell for 1 is only 24 px tall.

## Result
