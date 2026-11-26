# 004 主役交代? / 相棒交代? prompts

**Needs:** emulator
**Claimed by:** -
**Seen in:** v149 fight, yellow text under a portrait box after a time-up
**Source:** `DAT2/CEFT1.BIZ` TIM 0x10800: 主役交代 (512,192,63,11), ? (578,192,10,11), 相棒交代 (592,192,63,11), ? (658,192,10,11); PUSH BUTTON is already English

## Problem
Tiny 8 px text. "SWAP LEAD" fits at about 6 px per character; "PARTNER" needs a narrower wording. Wording is open.

## Notes
`small_text()` in `tools/hud_v150.py` paints the 8 px bitmap style (see `READY!!`).

## Result
