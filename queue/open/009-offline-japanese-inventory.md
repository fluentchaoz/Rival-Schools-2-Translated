# 009 Offline inventory of everything still Japanese

**Needs:** none (disc image + Python only)
**Claimed by:** -
**Priority:** high
**Verify:** offline
**Source:** the whole disc: every TIM / texture / baked-text file, plus script and menu text

## Problem
There is no current list of what is untranslated; items have been found by chance while playing. Build one.

## What to produce
1. `tools/inventory_sweep.py`: walks the current build's files, finds every TIM/CLUT image, renders each with its real palette to a contact sheet under `work/inventory/` (not committed), and records file, offset, size, rectangles.
2. `docs/INVENTORY.md` (committed, no Japanese text dumps or art): one table row per Japanese item: id, file/offset/rect, what it says (English gloss), where and when it appears, how often a player sees it (priority), status (open / built vNNN / seen), and who can do it (painter / image-generation).
3. A coverage line at the top: items done / items total.
4. Create or update queue tasks from the table, grouped by source file (batch), not per sprite.

## Notes
Start from the files already known: `DAT2/CEFT1.BIZ`, `CEFT3.BIZ` (TIMs 0x10800 and 0x19000), the EDB/ED and OP01 narration images, loading cards, menus. `tools/` has TIM readers; `work/hud/dump.py` and `crop.py` show the CEFT1 route. Do not commit extracted art or Japanese text (see `.gitignore`).

## Result
