# Solo Play character select: investigation notes (started 2026-11-24, v144)

Status: **implemented in v145 (tools/charselect_v145.py), verified in game: banner, LEAD, PARTNER, BATSU.**

## What is on screen (all Japanese in v144)
Screenshot: `work/shots/solo_charselect.jpg`.
- Red banner キャラクターセレクト (10 glyphs, one repeated: ク x2).
- Column headers 主役 (Lead) and 相棒 (Partner).
- Blinking top-right prompt: スタートボタンを押して！ alternating with ちょっと待って！.
- Name captions under the two chosen portraits (バツ, ひなた).
- Background watermark LEGION OF HEROES is already English.

## Where it comes from
- Code overlays `DAT1/PLSEL1..5.BIN` (24-51 KB each, raw MIPS, first word is an 0x800aXXXX pointer, not LZ-packed).
  The Legion of Heroes background means PLSEL1/SELP1 for the Justice school; 2-5 are the other schools.
- Textures `DAT2/SELP1..5.BIZ` (TIM members at 0x6800 school crest, 0x8800 portraits, 0x17800 text atlas 1024x256, 0x38000 font atlas 768x256).
  Previous sheets: `work/survey2/SELPn_BIZ_*.png`, `work/s_selp.png`. Enlarged: `work/shots/selp1_17800_2x.png`, `selp1_38000_2x.png`.
- There is no Shift-JIS text and no "SELP" filename string anywhere on the disc (checked all records, raw and decoded). Strings are glyph indices into the atlases; files are loaded by catalog index.
- 0x17800 atlas holds: stylized red banner cells (勝 ナ メ ン 戦 対 団 体 / 利 リ ー グ V S 1 2 / P キ ャ ラ ク タ セ レ ト), a 16x16 kanji/kana block that includes 主役相棒負番, the character-name labels (バツ ひなた 恭介 将馬 夏 ロベルト ロイ ティファニー ボーマン エッジ アキラ 岩 英雄 響子 雷蔵 雪 さくら 醍醐 隼人 あきら), and the prompts スタートボタンを押して下さい / この組み合わせでしますか？ / もう一回しますか？.
  Already-English cells exist in the same atlas (large and small A-Z, a-z, digits, OK!, CPU MAN, 1st-6th).
- 0x38000 atlas is a 36 x 12 grid of 20x20 cells: Latin + kana + the kanji used by the menus.

## PLSEL1.BIN layout seen so far (file offsets)
- 0x20-0x9f: table of (x,y) u16 pairs (screen positions of the 3x9 grid of portrait slots, 0x1e..0x1ae, y = 0x03/0x45/0x87 = 3, 69, 135).
- 0xa0-0x2ff: 16-byte glyph/sprite records. Pattern `0003 KK00 AA00 BB00 ...` where KK steps by 0x10 and (AA,BB) = (48*(n//4), 64*(n%4)): looks like a table of texture cell origins, to be decoded.
- 0x300-0x6ef: small byte tables (cell index pairs like `0a06 0b06 0c06 ...`, probably per-glyph column/row indices into the 0x38000 font, i.e. string data) followed by pointer tables to 0x800a25xx/0x800a28xx.
- Code starts around 0x960.
These are leads, not a decoded format. Stride-12 and stride-8 descriptor scans (the v37 MGAME format) found nothing here, so the format differs.

## Plan
1. Decode the glyph record table and string tables (use `work/mips.py` to read the draw routine near 0x960, as for END01).
2. Locate the strings for the banner, 主役/相棒, the two prompts and the name captions.
3. Either (a) re-letter the atlas cells in place so the same descriptors show English (names and headers fit; the banner has only 10 cells for CHARACTER SELECT, so use two letters per cell or rebind descriptors as v37 #024 did), or (b) rebind descriptors to existing English cells.
4. Apply to all five SELP/PLSEL pairs, keep every other byte exact, run the sector/ownership audit used by `build_images_v14x.py`.
5. Verify through the route in `PLAYTEST_HOWTO.md` (Solo Play, character select screen).

## Related untranslated screens on the same route
Episode card 第一話, banner かかって来なさい！, fight HUD (第一戦, 準備OK!!, vertical name labels). See `PLAYTEST_LIST.md`, section "v144 in-game survey".
