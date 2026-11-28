# Savestates and fast triggers (playtesting)

States are DuckStation files `%LOCALAPPDATA%\DuckStation\savestates\SLPM-86750_<slot>.sav` (copies in `C:\Users\Fluent\JG2-Project\work\states\`). They are not committed. Slots 1 and 2 are the user's older states: do not overwrite them. Use slots 3 and up.

Load one at launch (about 10 s to the scene, instead of about 3 minutes from boot):

```powershell
Start-Process "$env:LOCALAPPDATA\Programs\DuckStation\duckstation-qt-x64-ReleaseLTCG.exe" -ArgumentList @('-batch','-state','9','"<path to the build>.cue"')
```

Then `work/fg2.ps1` and click the left margin as usual. The window opens windowed with a menu bar (F11 for fullscreen). In-game: F4 selects the next slot, F2 saves, F1 loads.

| Slot | Scene | Made on | Notes |
|---|---|---|---|
| 3 | Mode Select, cursor on SCHOOL LIFE | v155 | Down, then C for Solo Play |
| 4 | Solo Play character select, Batsu + Hinata chosen | v155 | press C once, then hold Start 0.6 s |
| 5 | NOW LOADING card (Japanese "ただいまロード中…") right before fight 1 | v155 | art is loaded from the disc after this point: shows new art on a new build |
| 6 | Fight 1, round 1, timer about 67 | v155 | VRAM already holds the HUD art of the build that made it |
| 7, 8 | same fight, timer about 58 and 36 | v155 | used to find the timer; otherwise redundant |
| 9 | Fight 1 with the timer set to 1 (made by `tools/state_patch.py`) | v155 | round ends in about 8 s with TIME UP, then PERFECT! and the "SWAP LEAD ?" prompt (checked) |

## Forcing events by patching a state
`python tools/state_patch.py <src.sav> <dst.sav> <data_offset>=<byte>` (Python 3.14). Offsets are into the machine-data frame; PS1 RAM starts at data offset 0x2000.
- Round timer: data offset `0x9ecff` (PS1 `0x8009CCFF`), one byte, 1..99. Set it to 1 for an immediate TIME UP. Found by diffing three states a few seconds apart (`work/statediff2.py` logic: the byte that went 67 → 59 → 36).
- Health bars: not located yet. Method: save two states with different health, diff the two for 16-bit values that match the bar fill.

## Caveats
- A state taken after the HUD art was uploaded keeps the OLD art in VRAM. To see new art, use slot 5 (before the load) or make a new state on the new build. Slot 3 (made on v155) reloads cleanly on v156 (checked 2026-11-27: Mode Select came up); slots 4 and 5 are not yet checked on another build.
- The in-app cheat route did not work (the Cheats menu stayed disabled even with `EnableCheats` set); patching the state file is the reliable way.
- Slot, timer address and offsets are specific to SLPM-86750 / the memory layout of the fight scene; re-find them for other scenes.
