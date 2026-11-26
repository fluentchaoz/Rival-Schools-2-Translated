# 003 Red vertical fighter name labels (fight HUD)

**Needs:** emulator, image-generation (stacked or rotated English)
**Claimed by:** -
**Seen in:** every fight, left and right of the HUD under the health bars (e.g. バツ, 醍醐, さくら)
**Source (guessed):** `DAT2/CEFT1.BIZ` TIM 0x10800, x 0-256, y ~150-256 (orange/red brush names)

## Problem
Each fighter's name is a vertical Japanese label (about 30 px wide, 60-80 px tall). English needs stacked capitals or rotated text in the same red/orange style.

## Notes
24 names (same set as the character select captions in `tools/charselect_v145.py`). The style-learning painter in `tools/hud_v150.py` can reuse the colours; letterforms are the hard part.

## Result
