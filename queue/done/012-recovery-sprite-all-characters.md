# 012 回復 sprite in every PL/PLE file

**Needs:** none (emulator for a last look)
**Claimed by:** Claude (2026-11-28)
**Priority:** medium
**Verify:** offline
**Source:** `DAT2/PL010-PL410.BIZ` and `PLE*.BIZ`, TIM 0x6800 (256x256): the green block "GUTS UP / LIFE UP / 回復" near (132,86). See `docs/INVENTORY.md` row 4.

## Problem
"回復" (recovery) is Japanese in every character's effect sheet. Same rect in all files: one painter job patched across about 40 files.

## Notes
Style-learn from the file's own sprite (`hud_v150.learn`). English: HEAL or RECOVER (fit the cell). Use the TIM reader in `tools/inventory_sweep.py`.

## Result
Built v157 (`tools/hud_v157.py` `patch_recovery`, `build_hud_v157.py`): 回復 -> HEAL in the cell (128,32,79,32) of TIM 0x6800. Only THREE files carry this sprite (PL140, PL240, PL410, byte-identical region), not 40 as first assumed. Previewed offline only (style learnt from the sprite, gradient and blue shadow kept); NOT seen in game. Seeing it needs one of those characters (140/240/410) using a recovery move.
