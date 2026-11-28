# 013 Move list sheets (EDITCM01-24)

**Needs:** image-generation or painter
**Claimed by:** Claude (2026-11-28)
**Priority:** medium-high
**Verify:** offline, then a savestate
**Source:** `DAT2/EDITCM01-24.BIZ`: 412x369 table at 0x0, 512x256 super-move name list at 0x13000. See `docs/INVENTORY.md` row 5.

## Problem
Per-character move list screens: fixed headers (SPECIAL MOVES, DREAM ATTACK, EASY COMMANDS, LOVE AND FRIENDSHIP TAG ATTACK) plus each character's move names. The headers are the same in all 24 files; the move names are per file.

## Notes
Use the HUD's wording (DREAM ATTACK). Button glyph sprites are language-neutral and stay. Do the shared headers first (one painter job over 24 files), then the move names.


## Progress 2026-11-28: built v159 (unverified)
- `tools/editcm_v159.py` + `build_editcm_v159.py` (builds on exact v158): for all 24 `DAT2/EDITCM01-24.BIZ` it repaints TIM 0 (412x369): the four header blocks (SPECIAL MOVES, DREAM ATTACK, EASY COMMAND, LOVE & FRIENDSHIP TAG ATTACK), every move name (A: special moves, B: dream attacks), the red pill 空中可 -> AIR, the small red 空中で -> AIR, 弱/強 -> L/H, and the rare red labels ため -> HOLD, 連続入力可 -> MASH OK, 後 -> ">", 連打 -> MASH (files 05-08, 22). Each file's CLUT is quantised separately, so roles are picked by colour (`Pal`).
- Move names are in `translations/editcm_en.json` (my transliteration/translation of the Japanese; wording is a draft, e.g. "Ki Mass", "Hidden Gate", "Layout Dive", "Deadly Nursing Care").
- The shared 512x256 list at 0x13000 (tag-attack names, identical in all files) is repainted in the original's hollow thin-line style (`LIST_LINES`; guesses, e.g. "Man Among Men", "Strange Rock Strike", "Concerto Combo Ver.").
- Previewed offline across all 24 files; NOT seen in game. Where it shows is probably the EDIT mode character/move screens; confirm when seen. Known blemish: file 04's first pill keeps a tiny red tick at its right end.
