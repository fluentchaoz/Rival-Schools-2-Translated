# Handoff for the next chat (written at v138)

## What this is
English patch for Justice Gakuen 2 / Rival Schools 2 (PSX, SLPM-86750). Played in DuckStation. Project root: C:\Users\Fluent\JG2-Project

## Current build
`1-KEEP\v138-CURRENT-play-this\justice-gakuen2-images-v138.bin/.cue` (built on exact v137 -> v136 dialogue + v135 image labels).
Always keep in 1-KEEP: `original-disc`, `v46-base-for-next-patch` (the fixed master all dialogue builds start from, SHA-256 7e5a778e...476d17). Older builds go to `2-CAN-DELETE` (move, never delete).
Build chain: `repo/tools/build_dialogue_v136.py` (from v46 base, includes bundle mirroring) -> `repo/tools/build_images_v137.py` (image labels, master = v136 output) -> `repo/tools/build_tweak_v138.py` (tutorial heading colour). Spec: `repo/tools/make_dialogue_spec_v47.py` -> `repo/assets/dialogue_spec.json`.

## Key discoveries this session (read these)
1. The game loads April/June/Aug/Sep/Nov story from `DAT2/MGG04/06/08/09/11.BZZ` bundles (5 school scripts each), not the loose `MGGmmS.BIZ`. Every build must also write patched scripts into the bundle slots (done in build_dialogue_v131+).
2. Name tokens (codes 2000-2009) print the player's name at runtime: wrapper reserves 7 cells for each (`NAME_CODES` in make_dialogue_spec_v47.py).
3. The game crops baked label sprites to the width of the ORIGINAL Japanese text; English must fit that width (`fit_w` in `repo/tools/img_label.py`).
4. DuckStation was bound to a gamepad only. Keyboard keys were added to the REAL settings.ini (backup: settings.ini.bak-before-keyboard): Enter=Start, C=Circle(confirm), X=Cross, arrows. In-game tips: the game window loses focus, so click the window margin before each key; hold keys ~0.2 s; Start must be pressed twice with a pause on the title.
5. Do NOT call the computer-use `open_application` for DuckStation after launching it: it starts a second copy. Launch once with Start-Process; bring forward with `work\fg.ps1`.
6. pip install was blocked by the safety classifier (tried capstone); do not work around it.

## State of translation
- Dialogue corpus ids 0-18340: all translated and applied (39,653 message entries incl. selectors 2/6; `tr_dlg_*.txt`, ids 20000+ are the extra practice descriptions/menus). Only debug-style menus remain Japanese (character grid in 78 records; 5 menus in MGK04/MGT00).
- Verified in game: opening tutorial, quiz, Gorin and Taiyo April 8 scenes, Bonus menus (English labels), mode select. NOT yet seen in game: the 49 practice descriptions, later months, Justice/Pacific/Gedo scenes.
- Baked images done: KOUBAI0/KOUBAI1 (shop/bonus labels). Tool: `repo/tools/img_label.py` + `build_images_*.py`.
- Tutorial heading "SCHOOL LIFE 2" now yellow (colour code 0 instead of 9).

## Still Japanese / to do (see PLAYTEST_LIST.md for details)
Solo Play story/episode screens, character select, "かかって来なさい!" banner, ending epilogues EDB/ED (display geometry unknown; per-ending code is DAT1/END##.BIN, MIPS, load base 0x800a2000), OPTINFO help, EDITCM move lists, CARD images, credits, HERE.TIZ flame text, Bonus panel text drawn from a glyph-atlas table, おまけ title. Menu strip art: "SOLO PLAY"/"SKILL 99" cut off on Mode Select.

## GitHub
NOT pushed. Repo = `repo/` (remote origin github.com/fluentchaoz/Rival-Schools-2-Translated). 239 uncommitted paths (tools, English translations, specs, plus Japanese source extracts: corpus.txt, corpus_items.pkl, remaining_v135.*, glyphmap). .gitignore already excludes *.bin. Decide before pushing whether extracted Japanese source text should be committed (repo notes say not to commit extracted game assets). Project root (outside repo): PLAYTEST_LIST.md, HANDOFF, README, work/.

## Style
TRANSLATION_STYLE.md in repo. Bitmap font: A-Z, digits (new), space ! ' , - . / ? only; <=20 cells per line, <=4 lines.

## v139 update
Current build is `1-KEEP\v139-CURRENT-play-this\justice-gakuen2-v139.cue`. The layout fitter (`SQUEEZE` in make_dialogue_spec_v47.py) used to delete words with plain substring replace, which mangled 509 lines ("HOLDING BACKST BATSU", "!ICE'S"). Those 509 lines are now hand-rewritten in `assets/dialogue/tr_dlg_114..124.txt` (later files override earlier ones), all fit 4x20 with no squeezing; SQUEEZE is now whole-word-only and no longer drops YOU'RE/LET'S/SO/THEN. Image/tweak builders accept `JG2_MASTER=<sha256>` to chain from a rebuilt dialogue master. Native testing of v139 pending.

## v140 update
Current build: `1-KEEP\v140-CURRENT-play-this\justice-gakuen2-v140.cue` (v139 + `tools/build_images_v140.py` / `tools/minigame_pages_v140.py`, run with `PYTHONPATH=tools`, `--accelerator build-tools/practice_lz.dll`, master = v139 `ef2b2419...`). English title cards, speech-bubble taglines and rules pages for the regular (non-practice) minigames MINITTL0-4, 9, A (Gorin Festival, Home Run, PK, Explosive Shot, Service Ace, Fiery Sprint, Doki-Waku-Dance). Next targets found: OPTINFO.TIZ (option help text), AISYOU.TIZ (compatibility mode), HERE.TIZ (vertical flame text), SELP glyph atlases, epilogues (need ending save state).

## v141 update
Current build: `1-KEEP\v141-CURRENT-play-this\justice-gakuen2-v141.cue` (v140 + `tools/band_text_v141.py` / `build_images_v141.py`, master = v140 `dbc425cd...`). Re-lettered the Solo Play opening narration `DAT2/OP01.BIZ` (TIM at 0x63a50). NOT yet seen in game (reach it via Solo Play).
Layout finding: baked narration images are 24-px bands (one displayed row each), 256 px wide per column; a 512-px image holds two columns. Anti-aliased grey ramp = palette indices 1..15 (1 = background). EDB##/ED## epilogue text images use the same band idea but with a long first row and 13-char wraps; geometry still needs an in-game look.
Emulator driving tips: `work/fg2.ps1` (reliable focus), `work/keys.ps1 ENTER wait1500 ...` (220 ms holds), `work/cap.ps1 out.png` (captures only the DuckStation window). Do NOT use full-screen screenshots. Backup of savestates/memcards: `work/savestate-backup*`; kill DuckStation with Stop-Process so the resume state is not overwritten.
Still Japanese: OPTINFO.TIZ, AISYOU.TIZ, HERE.TIZ, EDB/ED epilogues, EDITCM move lists, CARD, TOROFY (award certificate), SELP glyph atlases, credits.
