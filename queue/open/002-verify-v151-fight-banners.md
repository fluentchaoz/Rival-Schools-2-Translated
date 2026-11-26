# 002 Verify remaining fight banners in game (current build v154)

**Needs:** emulator
**Claimed by:** -
**Seen in:** v150/v151
**Source:** `DAT2/CEFT1.BIZ` TIM 0x10800

## Problem
Built but never seen in game: ROUND 3/4/5 (and numerals 2-5 other than "ROUND 2"), FIN AL (final fight), FIN ISH (KO), SUPER! / PERFECT! (制圧! / 圧倒! share the middle sprite), TIME UP, DRAW, GUTS COUNTER. Seen OK so far (through v154): READY!!, ROUND 1, ROUND 2, FIGHT!, DREAM ATTACK, TIME UP, FIN ISH, PERFECT!. Still unseen: FIN AL (final fight only), ROUND 3/4/5, DRAW, GUTS COUNTER, SUPER! (制圧!).

## Notes
Banners last about 1 s. Record with `work/loopcap2.ps1` (new timestamped folder per run); see `PLAYTEST_HOWTO.md`. Losing a fight ends in CONTINUE? then GAME OVER; the CONTINUE timer is 10 s. Check for clipping and seams. SUPER!/PERFECT! wording is a guess - tell the user.

## Result
