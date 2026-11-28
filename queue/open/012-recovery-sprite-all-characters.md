# 012 回復 sprite in every PL/PLE file

**Needs:** none (emulator for a last look)
**Claimed by:** -
**Priority:** medium
**Verify:** offline
**Source:** `DAT2/PL010-PL410.BIZ` and `PLE*.BIZ`, TIM 0x6800 (256x256): the green block "GUTS UP / LIFE UP / 回復" near (132,86). See `docs/INVENTORY.md` row 4.

## Problem
"回復" (recovery) is Japanese in every character's effect sheet. Same rect in all files: one painter job patched across about 40 files.

## Notes
Style-learn from the file's own sprite (`hud_v150.learn`). English: HEAL or RECOVER (fit the cell). Use the TIM reader in `tools/inventory_sweep.py`.

## Result
