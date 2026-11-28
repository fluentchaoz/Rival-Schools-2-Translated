# 013 Move list sheets (EDITCM01-24)

**Needs:** image-generation or painter
**Claimed by:** -
**Priority:** medium-high
**Verify:** offline, then a savestate
**Source:** `DAT2/EDITCM01-24.BIZ`: 412x369 table at 0x0, 512x256 super-move name list at 0x13000. See `docs/INVENTORY.md` row 5.

## Problem
Per-character move list screens: fixed headers (SPECIAL MOVES, DREAM ATTACK, EASY COMMANDS, LOVE AND FRIENDSHIP TAG ATTACK) plus each character's move names. The headers are the same in all 24 files; the move names are per file.

## Notes
Use the HUD's wording (DREAM ATTACK). Button glyph sprites are language-neutral and stay. Do the shared headers first (one painter job over 24 files), then the move names.

## Result
