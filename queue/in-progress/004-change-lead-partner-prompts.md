# 004 主役交代? / 相棒交代? prompts

**Needs:** emulator
**Claimed by:** Claude (2026-11-27)
**Seen in:** v149 fight, yellow text under a portrait box after a time-up
**Source:** `DAT2/CEFT1.BIZ` TIM 0x10800: 主役交代 (512,192,63,11), ? (578,192,10,11), 相棒交代 (592,192,63,11), ? (658,192,10,11); PUSH BUTTON is already English

## Problem
Tiny 8 px text. "SWAP LEAD" fits at about 6 px per character; "PARTNER" needs a narrower wording. Wording is open.

## Notes
`small_text()` in `tools/hud_v150.py` paints the 8 px bitmap style (see `READY!!`).

## Result (built v155, partly verified)
`tools/hud_v155.py` + `build_hud_v155.py`: glyph core idx 1, 1 px outline idx 7, bottom core row idx 3, background 0 (palette read from the PUSH BUTTON cell). Texts "SWAP LEAD" and "SWAP ALLY" ("SWAP PARTNER" is 63 px and does not fit with the outline). "SWAP LEAD ?" seen in game on v155, legible. NOT seen: "SWAP ALLY ?". Wording is a guess; ALLY vs PARTNER elsewhere in the patch is an inconsistency to tell the user. Move to done/ once the partner prompt is seen. (built v155, partly verified)
`tools/hud_v155.py` + `build_hud_v155.py`: glyph core idx 1, 1 px outline idx 7, bottom core row idx 3, background 0 (palette read from the PUSH BUTTON cell). Texts: "SWAP LEAD" and "SWAP ALLY" (SWAP PARTNER is 63 px and did not fit with the outline). "SWAP LEAD ?" seen in game on v155 and legible. NOT seen: "SWAP ALLY ?" (partner swap). Wording is a guess; "ALLY" vs "PARTNER" elsewhere in the patch is a known inconsistency, tell the user. Move to done/ once the partner prompt is seen.
