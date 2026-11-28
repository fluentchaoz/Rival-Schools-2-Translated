# 011 Ending (ED01-24) and epilogue (EDB01-25) narration text

**Needs:** none for the build; emulator for the final check
**Claimed by:** Claude (2026-11-27)
**Priority:** high
**Verify:** offline (rendered page), then a savestate or one ending in game
**Source:** `DAT2/ED01-ED24.BIZ` 512x256 text page at 0x4000 (ED24: 256x168); `DAT2/EDB01-EDB25.BIZ` 512x256 at 0x5f800. See `docs/INVENTORY.md` rows 1-2.

## Problem
The ending and epilogue narration are baked Japanese images, about 49 pages, one set per ending. Same kind of image as OP01, which is done (v144).

## Findings 2026-11-27
- 45 pages, not 49: ED01-16, 18-24 (23) and EDB01-14, 17, 18, 20-25 (22). Widths vary: 512, 768 or 1024 px for most ED pages (ED02 is 1024x256), 256 px wide for ED21-24 and several EDB. Height 256 px = 10 bands of 24 px.
- Volume: about 10,400 Japanese characters in total (`python repo/tools/ed_pages.py stats`), roughly 6-7k English words. ED pages are character dialogue (about 250-540 chars each); EDB pages are short narration (about 130-220 chars each).
- Layout: in ED01 each 24 px band reads left half then right half as one continuous line (32 glyphs across 512 px), unlike OP01 where a row is a band pair inside one 256 px column. The last bands of a page are often half width. The game most likely crops each line to the original ink width, as in OP01, but this is NOT confirmed for ED/EDB: it needs one ending seen in game before building all pages. The data before the text TIM (first 0x4000 bytes) is a script (`pQES` header), not yet decoded.
- Tooling: `tools/ed_pages.py dump` writes stacked page images to `work/hud/pages_NN.png`; `stats` prints size and volume.
- Suggested order: EDB first (short narrator text, 22 pages), then ED. Translate to `translations/endings_en.json` (one entry per page), then fit lines to the per-band width limits (ink width of the original right half) and rebuild with the surgical LZ patch (as v143).

## Notes
Technique: `tools/band_text_v141.py` + `build_images_v143.py` (see "FIXED in v143/v144" in `docs/archive/HANDOFF_history_v143-v154.md`: rows are pairs of 24 px bands, the game stretches about 1.3x and crops the right band to the original ink width; `surgical_lz_v143.py` for streams that do not follow the page schedule). Steps: read each page's Japanese from the sheet, write the English into `translations/` (JSON; no Japanese dumps committed), run the band painter per file, rebuild in one batch, check the rendered pages offline, then play one ending.

## Result
