# 003 Red vertical fighter name labels (fight HUD)

**Needs:** emulator, image-generation (stacked or rotated English)
**Claimed by:** Claude (2026-11-28)
**Seen in:** every fight, left and right of the HUD under the health bars (e.g. バツ, 醍醐, さくら)
**Source (guessed):** `DAT2/CEFT1.BIZ` TIM 0x10800, x 0-256, y ~150-256 (orange/red brush names)

## Problem
Each fighter's name is a vertical Japanese label (about 30 px wide, 60-80 px tall). English needs stacked capitals or rotated text in the same red/orange style.

## Notes
24 names (same set as the character select captions in `tools/charselect_v145.py`). The style-learning painter in `tools/hud_v150.py` can reuse the colours; letterforms are the hard part.

## Result
Built v160/v161 (`tools/hud_v160.py`): 17 of the 21 labels painted in English, rotated top-to-bottom, two short lines for names of 5+ letters (e.g. BAT/SU, DAI/GO, SHO/MA, KYO/KO); squarish cells horizontal. SEEN IN GAME on v160/v161 (walk from Mode Select): BAT/SU left and DAI/GO right, readable. Cells painted: DAIGO, SHOMA, BATSU, KYOKO, ROY, RAN, KYOSUKE, EDGE, AKIRA, HIDEO, NATSU, HINATA, BOMAN, GAN, SAKURA, RAIZO, TIFFANY (the last few not yet seen in game; identification by eye, TIFFANY least certain).
STILL JAPANESE (not identified safely): the horizontal two-glyph pair at (25,185,47,20) (reads 雷/流-like), the tall cell (119,192,25,60) and the 4-katakana cell (145,199,22,49) which reads as ロベルト (ROBERTO) but was left alone; check in game which fighter shows each, then add them to `LABELS` in `hud_v160.py` (rect + English).
