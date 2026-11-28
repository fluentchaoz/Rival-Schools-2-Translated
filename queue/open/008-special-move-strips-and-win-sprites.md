# 008 Remaining CEFT1 strips: 勝, 愛と友情のプラトン, フィニッシュ..., win counters

**Needs:** emulator (to learn when each shows)
**Claimed by:** -
**Seen in:** not seen in game yet
**Source:** `DAT2/CEFT1.BIZ` TIM 0x10800: 勝 (514,112,59,39), pink-bar strip (576,112,127,31), small strip row y~144-152, 幸 (705,108,53,32)

## Problem
Meaning and trigger unknown; trigger each in a fight to learn what the Japanese says before translating. `CEFT3.BIZ` (TIMs 0x10800 and 0x19000) also holds HUD art not yet checked.

## Seen in v153 footage
- Beside the FIN ISH banner: a Japanese caption (looks like 愛と友情のプラトン over フィニッシュ), the finishing-move name popup, drawn as blue/pink-bar sprites at the right of the screen.
- The dream-attack hit burst contains a Japanese word (about 2 kanji, orange; looks like 友情, 'friendship').
- Stage backdrops carry Japanese signs (e.g. a pool-side sign on the pool stage): scenery art, low priority.

## Result

## Seen 2026-11-27 (v154)
After a won round the game shows a big red-gold Japanese banner **辛勝!** (narrow win; probably 勝 plus 辛/幸 cells) beside the winner's portrait, with the 主役交代? box lower left (task 004). The "ROUND BONUS 0" panel under it is already English. Likely English: "NARROW WIN!" or "CLOSE WIN!" (guess; check for the other win variants such as 完勝 and 圧勝 first). Captured frames: `work/shots/run-081623` (outside the repo), roughly frames 130-160.

## Progress 2026-11-28 (v157, offline preview only, not seen in game)
- Done: win banner 辛勝! = 幸 (705,108,53,32) -> CLOSE + 勝 (514,112,59,39) -> WIN, with the shared "!" cell: reads CLOSE WIN!. Painter job in `tools/hud_v157.py`.
- Found: the on-screen "N発" combo counter and the "先制" popup are NOT in this sheet. The red-grid areas are reserved space the game fills at run time from the font, so those strings live in code (overlay/executable strings) and need a text patch, not an image edit. 発 at (711,143,25,17) belongs to the finish-move caption strip (フィニッシュ必殺... 発 ○); I left it alone because its meaning is unclear.
- Still open: 愛と友情のツープラトン pink-bar strip, フィニッシュ必殺 strip, 24 vertical name labels (cells merge in the sheet and must be split by gaps; plan: identify each by matching rendered Japanese roster names, then stack or rotate English).
- CEFT3 (DAT2/CEFT3.BIZ) was checked: TIM 0x19000 is a copy of CEFT1's announcer banners (最終 第戦 開始! 決着 and numerals) shifted -256 px, used by another mode, and TIM 0x10800 is the Training-mode glyph atlas and labels. Both still Japanese. The banner copy can reuse the CEFT1 jobs with x-256.

## Correction 2026-11-28 (v161)
The earlier note that "N発 and 先制 are not in this sheet" was WRONG: it came from a test on a savestate that already held the old HUD art in VRAM. Savestates made after the HUD loads (slots 4+) never show new CEFT1 art; only a walk from Mode Select (slot 3) reloads it. Re-tested properly: v161 shows "2 HITS" in the combo counter, so the 発 cell (711,143,25,17) -> HITS is correct and seen in game. 先制 (first hit popup) probably also lives in this sheet: look for it next with a walk-through test.

## 先制 popup (searched 2026-11-28, not found)
The yellow-green "先制" (first hit) popup that appears near the right-hand name label after the first hit is not among the CEFT1 cells that remain unpainted (every component outside the known jobs was listed: only the HUD frames, GAME OVER, digits and strips). It is not in CEFT2-CEFT6 or CEFT3's Training atlas either. It may reuse the 制 cell from the 制圧! row (now "SU") or live in another file. To find it: capture the popup in game (screenshot right after the first hit, on v161) and check whether the second glyph now reads SU; otherwise save a state while it is showing and look at VRAM (`tools/vram_from_state.py`).
