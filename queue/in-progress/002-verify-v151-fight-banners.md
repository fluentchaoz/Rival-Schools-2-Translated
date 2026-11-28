# 002 Verify remaining fight banners in game (vs the current build)

**Needs:** emulator
**Claimed by:** Claude (2026-11-27)
**Seen in:** v150/v151
**Source:** `DAT2/CEFT1.BIZ` TIM 0x10800

## Problem
Built but never seen in game: ROUND 3/4/5 (and numerals 2-5 other than "ROUND 2"), FIN AL (final fight), FIN ISH (KO), SUPER! / PERFECT! (制圧! / 圧倒! share the middle sprite), TIME UP, DRAW, GUTS COUNTER. Seen OK so far (through v154): READY!!, ROUND 1, ROUND 2, FIGHT!, DREAM ATTACK, TIME UP, FIN ISH, PERFECT!. Still unseen: FIN AL (final fight only), ROUND 3/4/5, DRAW, GUTS COUNTER, SUPER! (制圧!).

## Notes
Banners last about 1 s. Record with `work/loopcap2.ps1` (new timestamped folder per run); see `PLAYTEST_HOWTO.md`. Losing a fight ends in CONTINUE? then GAME OVER; the CONTINUE timer is 10 s. Check for clipping and seams. SUPER!/PERFECT! wording is a guess - tell the user.

## Progress (2026-11-27, v154)
Seen in game and all English, no clipping at capture size (640x360 frames): ROUND (number mid-animation), FIGHT!, TIME UP, FIN ISH, PERFECT!, DREAM ATTACK, **FIN AL** (the deciding round at 1-1 shows FINAL, not ROUND 3). ROUND 3/4/5 numerals still unseen: they need a longer match. Still unseen: DRAW (needs equal health at time up), GUTS COUNTER, SUPER! (制圧!).
New Japanese found on the way: see 008 (辛勝! win banner), 004 (主役交代? box), 003 (vertical name labels), 006 (第一話 card).
Routing tip: Solo Play fights are CPU vs CPU until you mash attacks (Right, C, Z, V); hold Start 0.6 s on the character select (0.2 s was ignored once, focus lost after starting loopcap2: run fg2.ps1 + margin click after starting it).

## Result
