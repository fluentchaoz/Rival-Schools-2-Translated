# 010 Savestate library and fast triggers for playtesting

**Needs:** emulator
**Claimed by:** -
**Priority:** high
**Verify:** savestate
**Source:** DuckStation save states (F1 load / F2 save, slots F3/F4), `tools/vram_from_state.py`

## Problem
Every test restarts from boot: logos, intro skips, menus, a 40 s load, then a mashed fight. Most checks only need one scene.

## What to produce
1. States saved at: title; Mode Select; Solo Play character select (just before Start); the first fight at READY; a round end (win and lose); the win banner; CONTINUE?; one School Life screen. Name them by scene and record them in `docs/SAVESTATES.md` (scene, build it was made on, how to reach it). States themselves are not committed.
2. Check that a state made on one build still behaves on the next (same disc layout, so it should); note which scenes reload art from the disc (those show new art) and which do not (those keep old VRAM and must be re-made).
3. Find RAM addresses for the round timer and both health bars (diff two state files offline), and write a small DuckStation cheat (.cht) that sets the timer to 1 or a health bar to 1, so TIME UP, DRAW, FIN ISH and win banners can be forced in seconds.
4. Update `PLAYTEST_HOWTO.md` so the default route is "load state, trigger", and booting from scratch is the fallback.

## Notes
Cheats and states live under `%LOCALAPPDATA%\DuckStation` (or the app's data folder); keep copies of the useful ones in `C:\Users\Fluent\JG2-Project\work\states\` (outside the repo).

## Result
