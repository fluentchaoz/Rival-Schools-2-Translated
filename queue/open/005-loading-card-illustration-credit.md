# 005 Loading card between narration and fight: "イラスト 大野純二"

**Needs:** emulator (to locate), image-generation or pixel retyping
**Claimed by:** -
**Seen in:** v151, loading screen after the Solo Play narration (illustration of Daigo, a girl in armour and others); credit text top-right
**Source:** unknown (loading cards are illustrations loaded before each fight; the earlier practice loading card was done in v37)

## Problem
Credit text in Japanese on the loading illustration. Other loading cards in the same series probably carry the same credit.

## Notes
Find which record holds the image (VRAM dump with `tools/vram_from_state.py`, or DuckStation Debug > Dump CPU to VRAM Copies), then re-letter the small caption. Do not redraw the artwork.

## Result
