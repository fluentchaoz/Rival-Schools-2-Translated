# 011 Ending (ED01-24) and epilogue (EDB01-25) narration text

**Needs:** none for the build; emulator for the final check
**Claimed by:** -
**Priority:** high
**Verify:** offline (rendered page), then a savestate or one ending in game
**Source:** `DAT2/ED01-ED24.BIZ` 512x256 text page at 0x4000 (ED24: 256x168); `DAT2/EDB01-EDB25.BIZ` 512x256 at 0x5f800. See `docs/INVENTORY.md` rows 1-2.

## Problem
The ending and epilogue narration are baked Japanese images, about 49 pages, one set per ending. Same kind of image as OP01, which is done (v144).

## Notes
Technique: `tools/band_text_v141.py` + `build_images_v143.py` (see "FIXED in v143/v144" in `docs/archive/HANDOFF_history_v143-v154.md`: rows are pairs of 24 px bands, the game stretches about 1.3x and crops the right band to the original ink width; `surgical_lz_v143.py` for streams that do not follow the page schedule). Steps: read each page's Japanese from the sheet, write the English into `translations/` (JSON; no Japanese dumps committed), run the band painter per file, rebuild in one batch, check the rendered pages offline, then play one ending.

## Result
