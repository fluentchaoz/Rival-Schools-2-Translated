# 001 Fight HUD spacing: FIGHT! gap and ROUND numeral position

**Needs:** emulator
**Claimed by:** Claude, 2026-11-26
**Seen in:** v151 fullscreen, first Solo Play fight (ROUND 1 then FIGHT! banners)
**Source:** `DAT2/CEFT1.BIZ` TIM 0x10800; `tools/hud_v150.py`, `tools/hud_v151.py`

## Problem
FIGHT! reads "FIG HT !" with a visible gap at the sprite seams; the ROUND numeral is a small glyph centred in a 78 px cell so it floats away from ROUND.

## Notes
Cells are drawn abutting. Right-align the left cell's letters and left-align the next one's (`align` param in `render_cell`) so the gaps close; left-align the numerals. Cell rects are in the `hud_v151.py` docstring. Numeral cell for 1 is only 24 px tall.

## Result
Done in v152-v154 (Claude, 2026-11-26). `render_cell` gained `align` (left/center/right) and `stretch`; v152+ re-renders every HUD job from the ORIGINAL sprites (`tools/hud_v152.py`, `build_hud_v152.py --original <original disc BIN>`). Verified in game: FIGHT! reads as one word; PER FECT ! and FIN ISH read correctly (v153 fixed the 圧/倒 cell order: 制圧! = cells 0+2+3, 圧倒! = cells 2+1+3). v154 stretches PER to touch both neighbours - not yet looked at in game. ROUND numeral now left-aligned next to ROUND.
