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
