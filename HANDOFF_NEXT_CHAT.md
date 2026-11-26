# START HERE (updated 2026-11-26, current build v151)

**Repo layout (reorganised 2026-11-26):** rules for every assistant are in `AGENTS.md` (read first). This file is the only live handoff; old per-version notes are in `docs/archive/`, superseded scripts in `legacy/scripts/`. Nothing in `tools/` moved.
**Current build:** `1-KEEP\v151-CURRENT-play-this\justice-gakuen2-v151.cue` (v150 + second HUD batch: FIGHT!, SUPER!/PERFECT!, TIME UP, DRAW, DREAM ATTACK, GUTS COUNTER; `tools/hud_v151.py` / `build_hud_v151.py`, master = the v150 BIN, SHA-256 `72b2d27f...2327`, `JG2_VERSION=151`). v150 is the rollback in `2-CAN-DELETE\v150-play-this`. Move old builds into `2-CAN-DELETE`; only the user empties it. `original-disc` and `v46-base-for-next-patch` must stay in 1-KEEP. v151 seen in game: ROUND 1, FIGHT!, DREAM ATTACK (FIGHT! has a seam gap, see queue 001).
**How to test:** read `PLAYTEST_HOWTO.md`. The user wants DuckStation kept **fullscreen (F11)** while testing. Refocus with `work/fg2.ps1`, click the left black margin, use 0.2 s `hold_key`, double Start on the title.
**Done recently:** v145-v149 (Solo Play character select, shared overlay prompts, Mode Select labels; all verified). v150: fight HUD announcer art (READY!!, ROUND n, FIN AL, FIN ISH) - READY!! and ROUND 2 verified in game, the rest built but unseen. Details in the v150 section at the bottom.
**Next:** open work is in `queue/` (one file per task, folder = status; `python tools/queue_status.py` to list). Highest value first: 002 (see the remaining fight banners in game), 001 (spacing fixes), then 003/004/005.
**Tools added:** `tools/hud_v150.py` + `build_hud_v150.py` (v150), `tools/charselect_v145.py`, `over_v147.py`, `menu_fit_v148.py`, `menu_center_v149.py` (+ matching `build_*.py`), `vram_from_state.py` (VRAM from a DuckStation state). DuckStation's Debug menu is enabled in its settings (Debug > Dump CPU to VRAM Copies finds dynamic uploads; turn it off and delete the PNGs afterwards in %LOCALAPPDATA%\DuckStation).

---

# Handoff for the next chat (updated at v144, 2026-11-24)

## What this is
English patch for Justice Gakuen 2 / Rival Schools 2 (PSX, SLPM-86750). Played in DuckStation. Project root: C:\Users\Fluent\JG2-Project
GitHub: https://github.com/fluentchaoz/Rival-Schools-2-Translated (local checkout: `repo/`). Last commit 1863cda "v142"; local main matches origin/main. Only uncommitted changes: line-ending noise in Apply-Exam-Dance-v35.ps1 and Apply-Practice-Layout-v34.ps1 (ignore or `git checkout` them).

## FIXED in v143/v144: Solo Play black screen (v141/v142 bug) and narration layout
Bug: Solo Play start (Mode Select > SOLO PLAY > character + partner > Start) went black (audio on) in v141 and v142. Root cause: the global encoder (`compress` in practice_disc_v30.py) cannot reproduce OP01.BIZ's original stream layout (huge zero runs, 95 blocks crossing page boundaries, max_match 53396); even a no-text-change recompression of OP01 garbled the screen (tested). Pixels were never the problem.
Fix: `repo/tools/surgical_lz_v143.py` parses OP01's ORIGINAL stream into tokens (round-trips byte-identical), keeps every token whose replay already equals the patched data, and re-encodes only runs that differ. Result 202,452 bytes (< original 206,992), same decoder profile, stream start unchanged so the exe catalog signature is untouched (v143 restores the exe that v141 had rebound). `repo/tools/build_images_v143.py <v142 bin> <out> --original <v140 bin>`. VERIFIED IN GAME: Solo Play now shows the opening narration over the background art, English text.
Use this surgical approach for any other record whose original stream does not follow the page schedule the global encoder assumes (check `decode(...)` profile: crossing_blocks > 0 or very large max_match).

FIXED in v144 (verified in game): the English OP01 narration LAYOUT. How the game draws this text (applies to the other baked narration/epilogue images too, e.g. EDB/ED):
- Each on-screen text row is a PAIR of 24-px bands in a 256-px column: first 256 px in band 2k, the rest in band 2k+1 (work\op01_orig_text.png shows the Japanese wrapping across the pair). A 512x256 image holds 2 columns x 5 rows.
- The game draws the picture stretched ~1.3x horizontally and CROPS the right-hand band of each row to the width of the ORIGINAL Japanese ink in it. So an English row may only be 256 + (right-band ink extent of the original) px wide, and a row with no right-band ink only 256 px. For OP01 these budgets are col0 rows 0-4: 256/328/308/353/408 (-3), col1: 299/280/256/279. `band_text_v141.letter()` now computes this limit itself from the original pixels, prints font size and width/limit per row, and refuses to build if text does not fit (MINSIZE 12).
- Text lines in use are in `JOBS` in band_text_v141.py. The pages build up on screen as lines accumulate (as in the original): page 1 = col0 rows 0-2, later rows added below.
Rebuild recipe (for any change to the narration text): `venv\Scripts\python.exe repo\tools\build_images_v143.py <current play BIN> <new out dir> --original 2-CAN-DELETE\v140-CURRENT-play-this\justice-gakuen2-v140.bin` with env var JG2_MASTER = SHA-256 (lowercase) of the current play BIN. The script always names its output justice-gakuen2-v143.bin + .cue: rename both (and fix the cue's FILE line) when filing a new version.
Other v142 jobs (AISYOU labels, HERE "Hold on") and v140 minigame cards are still not seen in game.
Confirmed good in v144: boot, intro movie, title, Mode Select (English; "SOLO PLAY" shows as "SOLO PLF" on the right-hand banner, "SKILL 99" clipped, as known), Solo Play start and the full English opening narration (8 lines over 2 pages, nothing clipped). Character select is still Japanese (the screen right before the narration).
Playtest tip: DuckStation pauses when it loses focus; run `work\fg.ps1`, then click the left black margin before sending keys. The intro movie needs Enter pressed 2-3 times to reach the title.

## Current build
`1-KEEP\v144-CURRENT-play-this\justice-gakuen2-v144.bin/.cue` (+ report.json). SHA-256 c6d02c05...c3043. v144 = v143 (OP01 surgical fix) + corrected narration layout. v143 is in 2-CAN-DELETE\v143-old-narration-layout, v142 in 2-CAN-DELETE\v142-solo-play-black-screen. GitHub: v143 tools are pushed (6d55f23); the v144 change to repo/tools/band_text_v141.py (new letter() + text) and this handoff are NOT yet committed.
Always keep in 1-KEEP: `original-disc`, `v46-base-for-next-patch` (the fixed master all dialogue builds start from, SHA-256 7e5a778e...476d17), and the current play build. Older builds go to `2-CAN-DELETE` (move, never delete). NOTE: 2-CAN-DELETE currently holds folders named v139/v140/v141-CURRENT-play-this - the names are stale, they are old builds. Also README.txt in the project root is badly out of date (stops at v40); trust this file.

## Build chain (each step takes the exact previous BIN as master, checks size 663216960 + SHA, writes to a NEW output folder)
1. `repo/tools/build_dialogue_v136.py` (from v46 base, dialogue + bundle mirroring) - spec: `make_dialogue_spec_v47.py` -> `repo/assets/dialogue_spec.json`
2. `build_images_v137.py` (v135 image labels on v136 output)
3. `build_tweak_v138.py` (tutorial heading colour)
4. v139: hand-rewrote 509 lines the fitter had mangled; squeeze is now whole-word-safe (dialogue rebuilt)
5. `build_images_v140.py` + `minigame_pages_v140.py`: minigame title cards, taglines, rules pages
6. `build_images_v141.py` + `band_text_v141.py`: Solo Play opening narration (OP01 band text)
7. `build_images_v142.py` + `label_jobs_v142.py`: AISYOU compatibility labels and HERE.TIZ "Hold on" text
Env var `JG2_MASTER` overrides the expected master SHA. Image jobs only let named rectangles change (`replace_pixels`) and audit sector ownership.

## Key discoveries (read these)
1. The game loads April/June/Aug/Sep/Nov story from `DAT2/MGG04/06/08/09/11.BZZ` bundles (5 school scripts each), not the loose `MGGmmS.BIZ`. Every build must also write patched scripts into the bundle slots (done since v131).
2. Name tokens (codes 2000-2009) print the player's name at runtime: wrapper reserves 7 cells for each (`NAME_CODES` in make_dialogue_spec_v47.py).
3. The game crops baked label sprites to the width of the ORIGINAL Japanese text; English must fit that width (`fit_w` in `repo/tools/img_label.py`).
4. DuckStation keyboard keys were added to the REAL settings.ini (backup: settings.ini.bak-before-keyboard): Enter=Start, C=Circle(confirm), X=Cross, arrows. The game window loses focus, so click the window margin before each key; hold keys ~0.2 s; Start must be pressed twice with a pause on the title.
5. Do NOT call the computer-use `open_application` for DuckStation after launching it: it starts a second copy. Launch once with Start-Process; bring forward with `work\fg.ps1`.
6. pip install was blocked by the safety classifier (tried capstone); do not work around it.
7. Bitmap font: A-Z, digits, space ! ' , - . / ? only; <=20 cells per line, <=4 lines. Style guide: `repo/TRANSLATION_STYLE.md`.

## State of translation
- Dialogue corpus ids 0-18340 plus extras (ids 20000+: practice descriptions, menus): all translated and applied (39,653 entries). Only debug-style menus stay Japanese on purpose (character grid in 78 records; 5 menus in MGK04/MGT00, no spare text space).
- Baked images done: KOUBAI0/KOUBAI1 (shop/bonus labels), minigame title cards/taglines/rules pages (v140), Solo Play opening narration (v141), AISYOU labels + HERE "Hold on" (v142).
- Verified in game (older): opening tutorial, quiz, Gorin and Taiyo April 8 scenes, Bonus menus, mode select. v140 verified to boot and reach Solo Play opening; v141/v142 black-screen at Solo Play start (see top). Minigame cards (v140) and AISYOU/HERE (v142) not yet seen in game.
- NOT yet seen in game: the 49 practice descriptions, later months (June/Aug/Sep/Nov), Justice/Pacific/Gedo scenes.

## Still Japanese / to do (details: PLAYTEST_LIST.md, repo/REMAINING_JAPANESE_AUDIT.md - the audit is from v45 and its dialogue numbers are obsolete)
- Solo Play story/episode screens, character select (キャラクターセレクト, 主役, 相棒), "かかって来なさい!" banner
- Ending epilogues EDB01-25 (33 images) and ED01-24 narration pages: blocker = display geometry unknown; per-ending code is DAT1/END##.BIN (MIPS, load base 0x800a2000). Reaching an ending in game or finding the draw code would unblock it.
- OPTINFO.TIZ help (5 images), EDITCM01-24 move lists (the work/editcm.png screenshot suggests this was being examined last), CARD (39 images), TOROFY, KOUKA, credits/MGSTAFF1, PDATIM
- Bonus screen: rainbow title おまけ; panel text (所持 / カードをみる / カードをあげる) and footer hint come from a glyph-atlas table (string table not located)
- Mode Select strip art: "SOLO PLAY"/"SKILL 99" cut off at the right edge
- Small: enrollment confirm leftover "か?" (baked), "USE TRI-SKIP TO CHOICE" awkward, quiz intro repeats "ANSWER QUICKLY", 2 leftover 保健室 in MGBGK03 #17 / MGBGM01 #12

## GitHub decision still open
Repo notes say not to commit extracted game assets, but extracted Japanese source text (corpus.txt, corpus_items.pkl, remaining_v135.*, glyphmap) may have been committed in 7cfbfd1 ("Add dialogue translation corpus"). Check `git show --stat 7cfbfd1` and decide whether to keep them. .gitignore excludes *.bin.

## v143/v144 update (2026-11-24)
Current build: `1-KEEP\v144-CURRENT-play-this\justice-gakuen2-v144.cue`. v143 fixed the Solo Play black screen (surgical token-level OP01 patch, `surgical_lz_v143.py`); v144 fixed the narration layout (row pairs + per-row crop limits). **User confirmed in game: Solo Play opening narration now displays correctly.**
Next targets: Solo Play episode/story screens (e.g. 第一話), character select (キャラクターセレクト, 主役, 相棒), "かかって来なさい!" banner. Need in-game screenshots of these screens to identify the source files before building.

## v145 update (2026-11-24)
Current build: `1-KEEP\v145-CURRENT-play-this\justice-gakuen2-v145.cue` (v144 + `tools/charselect_v145.py` / `build_charselect_v145.py`; master sha c6d02c05...3043, run with `PYTHONPATH=tools --accelerator build-tools/practice_lz.dll`). v144 moved to `2-CAN-DELETE\v144-play-this`.
Solo Play character select is English and **verified in game**: PLAYER SELECT banner, LEAD / PARTNER headers, BATSU caption (24 name captions relettered, others not yet seen). Banner is PLAYER, not CHARACTER, SELECT: the キャラクタ cells (7,2), (0,3), (2,1) are shared with the league/tournament titles (PLSEL3/4) and row 3 is the English number font. PLSEL2/5 have no such banner string.
How it works: see `CHARSELECT_NOTES.md` (text = (col,row) cell strings in PLSEL overlays + 32x32 / 40x20 / 48x16 sprite cells in SELPn 0x17800).
Still Japanese: top-right prompts スタートボタンを押して！ / ちょっと待って！ and the かかって来なさい！ banner (global overlay, not SELP), 第一話 card, fight HUD (第一戦, 準備OK!!, red vertical names), return-to-Mode-Select prompt. Not checked: PLSEL3/4 screens, "2" name variants, the other SELP schools.

## v146 update (2026-11-24)
Current build: `1-KEEP\v146-CURRENT-play-this\justice-gakuen2-v146.cue` = v145 lettering restyled. User saw v145 at 1080p fullscreen: banner had dark stripes and uneven gaps, LEAD/PARTNER were garbled. Cause: per-row fill learned from the Japanese glyphs included outline-colour rows. v146 uses a cleaned gradient (`clean_fill`), outline index 1, shadow index 13, even 13 px letter slots, and flat yellow (14) + shade (2) headers. Verified in game fullscreen: banner, LEAD, PARTNER, BATSU look clean. v145 moved to `2-CAN-DELETE\v145-garbled-lettering`, v144 kept as rollback.
Rebuild: `JG2_VERSION=146 PYTHONPATH=tools python tools/build_charselect_v145.py <v144 bin> <new folder> --accelerator build-tools/practice_lz.dll` (master is still v144, sha c6d02c05...3043).
Captions seen clean in game: BATSU HINATA KYOSUKE SHOMA NATSU ROBERTO ROY TIFFANY BOMAN KYOKO HIDEO GAN AKIRA EDGE RAIZO HYO SAKURA. Not yet seen: DAIGO, HAYATO, the "2" variants.
Testing rule from the user: keep DuckStation fullscreen (F11).

## Research after v146: fight HUD / episode card / top-right prompts (not built)
- Fight announcer + HUD art is in `DAT2/CEFT1.BIZ` (TIM at 0x10800, 768x256) and `DAT2/CEFT3.BIZ` (TIMs at 0x10800 and 0x19000). CEFT1 0x10800 contains: 最終 / 第 + 一二三四五 (so 第一戦 = 第 + digit + 戦, giving FINAL / ROUND n), 開始! (START!), 決着 (decision), GAME OVER (already English), 圧倒! / 勝 / 時間切れ引き分け (time-up draw), 準備OK!! (small, both corners), the vertical red name labels (醍醐 将馬 バツ 響子 ロイ ラン 英雄 エッジ アキラ 雷蔵 ひなた さくら ボーマン ティファニー ロベルト 夏 雪 ...), 主役交代? / 相棒交代? / PUSH BUTTON, 完全夢想アタック / 根性カウンター. Contact sheets: `work/shots/scan_hud.png`, `work/shots/ceft1_10800_3x.png`. CEFT4/6 (exam HUD) were already done in v34.
- The top-right prompts スタートボタンを押して！ / ちょっと待って！ / かかって来なさい！ were NOT found in CEFT1-3, MOJI2, EDITMOJI, CONT, MGSTAT or FONT.TIM. Remaining candidates: archive members of DAT2/COMMOT.BIZ, MGBETA.TZZ, MGSCH.TZZ, HEADQMD.BIZ (TIM scan found nothing at top level, so they need member-level decoding), or the main executable.
- 第一話 episode card: not yet located (white serif on black; probably a TIM in OP01.BIZ's sibling or an ED/END file).
- Scan helper: scratchpad scripts `scan.py` / `sheet.py` pattern = decode record, regex TIM header `10 00 00 00 [08|09|02|03] 00 00 00`, render with `rgb_image`.

## Prompt-hunt result (2026-11-24, not solved)
Top-right prompts (スタートボタンを押して！ etc.) were not found by: SJIS search (all records), TIM scans of CEFT1-3/MOJI2/EDITMOJI/CONT/MGSTAT/FONT, member scans of COMMOT/MGBETA/MGSCH/HEADQMD (they have no (off,size) table), or VRAM matching. VRAM was dumped from a fresh state with the prompt on screen (`tools/vram_from_state.py`; capture method in its docstring). The fb text is only ~84x16 px for ~12 glyphs (about 7 px per glyph), so it is probably composed from small scaled glyph sprites, and a whole-string image match finds nothing (best NCC 0.36).
Next ideas: (a) catch the GPU draw list (DuckStation GPU dump / debugger) to get the texpage+UV of those sprites, then trace the texture back; (b) find the overlay that draws it: same text shows in the fight, so look for a battle/arena overlay in DAT1 (not PLSEL) or SLPS data; (c) do the known fight HUD art in CEFT1/CEFT3 first.
User's resume state was backed up and restored; backups also in scratchpad state-backup.

## Prompt hunt, round 2 (2026-11-24): the draw packet is found, the texture is not
Method: two resume states (one per message) parsed with `tools/vram_from_state.py`; main RAM sits at payload offset 0x31a63 (PLSEL1 code found at 0x800a2960 for calibration). The top-right prompt is ONE GPU quad (POLY_FT4, code 0x2c, tag size 9) at RAM 0x1c6504 (double-buffer copy at 0x1c652c). Each message is one row of a text sheet on texture page (960,256), 4-bit, CLUT field 0x7fc0 (x0,y511), drawn at screen y 13..35 (2x vertical stretch of 11 texel rows):
- かかって来なさい！: screen x 328..416 (w 88), UV (0,100)-(88,111)
- スタートボタンを押して！: screen x 316..428 (w 112), UV (0,116)-(112,127)
- rows are 16 apart, so ちょっと待って！ is probably the next row (v=132 or 84). Per-glyph pitch is about 11 texels (11 px font).
Unresolved: in both captured VRAMs, page (960,256) rows 100..127 hold the 20x20 kanji atlas (SELP 0x38000 block 3), and the CLUT at (0,511) is junk (0x3333 x8), so the packet fields alone do not describe the real texture (the VRAM backbuffer region also renders with wrong colours, green instead of orange). Either the text strip is uploaded to VRAM and drawn in the same frame before the atlas is restored, or the displayed buffer is elsewhere and uses other fields.
Cleanest next step: a real GP0 trace of one frame (DuckStation: View > enable "Show Debug Menu" in Settings > Advanced, then Debug > Capture GPU Frame / GPU dump) to see the LoadImage that fills the strip and its source data; that source bitmap is what to re-letter. Alternative: break on the VRAM write via the DuckStation debugger. Settings change needs the user's OK.
Not yet translated: those three prompts, 第一話 card, fight HUD (CEFT1/CEFT3).

## v147 update (2026-11-24): shared overlay prompts, SOLVED
Current build: `1-KEEP\v147-CURRENT-play-this\justice-gakuen2-v147.cue` (v146 + `tools/over_v147.py` / `build_over_v147.py`; master sha 2ffe2080...ee61). v146 moved to `2-CAN-DELETE\v146-play-this`, v144 also still there.
The top-right prompts are rows of `DAT2/OVER.TIZ` (TIM at 0, 256x240, 4bpp). Found by dumping CPU->VRAM uploads (DuckStation Debug menu, now enabled in settings) plus a VRAM texel match; row table is in `tools/over_v147.py`. English: COME ON!, PRESS START!, HOLD ON!, ADD [n] COINS!, STREAK! RIVAL, in thin Verdana-like caps (fill idx 3, shade idx 7). Verified in game fullscreen: PRESS START! / COME ON! at character select and COME ON! over the opening narration. HOLD ON!, insert-coin and streak rows not seen in game yet.
Still Japanese on the Solo Play route: 第一話 card, fight HUD (CEFT1/CEFT3: 第一戦, 準備OK!!, vertical names, 開始!, 決着, 圧倒!), "Return to Mode Select?" prompt.
Debug aids: Debug > "Dump CPU to VRAM Copies" writes cpu_to_vram_copy_N.png into %LOCALAPPDATA%\DuckStation (turn off and delete afterwards); `tools/vram_from_state.py` for state VRAM.

## v148 update (2026-11-24): Mode Select labels no longer clipped
Current build: `1-KEEP\v148-CURRENT-play-this\justice-gakuen2-v148.cue` (v147 + `tools/menu_fit_v148.py` / `build_menu_fit_v148.py`; master sha a5a007e1...8495). v147 moved to `2-CAN-DELETE\v147-play-this`.
Problem (user report): on Mode Select, unselected list labels SOLO PLAY / TRAINING / SKILL 99 lost their last letters and the orange card tabs read "SOLO PLF" / "TRAININ" / "SKILL 9". Cause: each baked label sprite is cropped to about the original Japanese width; the English cells in `DAT2/MENU.BIZ` TIM 0x22800 (1280x256) were wider. Fix: horizontal squeeze (`menu_fit_v148.squeeze`, majority non-zero index per output column, exact pixel style kept) of 6 cells into the original JP span; spans in `JOBS`. VERIFIED in game: all three list labels and all three tabs show in full. Original JP extents measured from the original disc atlas. The real crop widths are not in MODESEL.BIN (that data is libgs); targets were chosen from observed clipping.
Still rough: the TOURNAMENT label and tab are drawn in the tiny 8 px font and look crushed but legible; left alone.
Mode Select atlas layout notes: list labels at x~885-1135 (blue), tab titles x~306-410 (rows 84-107 SOLO PLAY, 115-138 TRAINING, 147-171 SKILL 99, 181-204 TOURNAMENT), small card captions elsewhere.

## v149 update (2026-11-24): Mode Select list labels centred
Current build: `1-KEEP\v149-CURRENT-play-this\justice-gakuen2-v149.cue` (v148 + `tools/menu_center_v149.py` / `build_menu_center_v149.py`; master sha 19fe532f...9e10). v148 moved to `2-CAN-DELETE\v148-play-this`.
User request: centre the list labels in the green side panel (OPTIONS etc. hugged the right edge). Cause: English cells were centred ~8-9 px right of the original Japanese ink centres (x 936 for the SOLO PLAY..TRAINING column, x 1071 for SKILL 99..OPTIONS). Fix: pure horizontal shift of 13 labels to the JP centres (`JOBS` in menu_center_v149.py). VERIFIED in game: all list labels centred in the panel, highlight bars unchanged.

## v150 update (2026-11-26): fight HUD announcer art (partly verified)
Current build `1-KEEP\v150-CURRENT-play-this`. All edits are in the TIM at 0x10800 of `DAT2/CEFT1.BIZ` (768x256, 4-bit); only named rectangles change.
- **How the art is made** (`tools/hud_v150.py`): the originals are brush script, so each job LEARNS colour from the original sprite (index by distance to the top-left / bottom-right edge and vertical quarter), then paints English letters (Bahnschrift Bold Condensed, italic shear) as fill + 1 px outline + drop shadow with those indices. Stays correct for whichever CLUT the game binds (round banner is yellow in game, others red/purple). Small `READY!!` is painted directly as an 8 px bitmap font (rows b,b,c,c,d,d,e,e,e, shadow a).
- **Cells (x,y,w,h of ink; the game crops each quad to about this):** 最 (257,1,77,60)="FIN", 終 (337,2,86,57)="AL"; 第 (256,64,79,61)="ROUND", 戦 (336,65,87,60)=blank (so 最終戦 = FIN AL and 第n戦 = ROUND n); numerals 一..五 at x=428 (y 0/24/68/126/166, h 24/44/58/42/62) = 1..5; 決 (258,182,88,62)="FIN", 着 (346,184,78,63)="ISH"; 準備OK!! (160,96,80,11)="READY!!".
- **VERIFIED in game (fullscreen, v150):** READY!! in both lower corners (clean, right colours); "ROUND 2" banner (yellow, reads well). **Not yet seen:** ROUND 1/3/4/5, FIN AL (final fight), FIN ISH (KO), 開始! (not edited yet, cells interlock so the split between 開/始/! is unknown).
- **Still Japanese in the fight:** 開始!, 制圧! (shown when you lose/are dominated; strip at top of the right half of the TIM, x>=512,y<64), 時間切れ (time up), 勝, 引き分け, 主役交代?/相棒交代? (small strips at y~190, x 512-590 / 600-660), 完全夢想アタック and 根性カウンター popups (pink-bar sprites x 512-768, y 160-190, seen purple in game), red vertical name labels (x 0-256, y 150-256), 愛と友情の... special-move captions (x 576-704, y 112-140). Contact sheets: `work/hud/c_right.png`, `c_big.png`.
- Gotchas: `work/keys.ps1` is NOT a reliable driver (it skipped the margin click, most Start presses were lost). Follow PLAYTEST_HOWTO: computer-use `request_access` for DuckStation, `work/fg2.ps1`, click the left black margin, `hold_key` 0.2 s. A DuckStation update dialog appears at launch: click "Remind Me Later" (no download). `work/loopcap.ps1 <dir> <n> <ms>` grabs the screen every N ms (good for brief banners). Round start banners last ~1 s; losing a fight leads to CONTINUE? then GAME OVER then attract, so to re-see banners route again (Start, Start, Down, C, C, C, Start; first fight loads ~45 s after Start).
