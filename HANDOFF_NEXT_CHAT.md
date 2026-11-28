# START HERE (updated 2026-11-28, current build v155 verified; v156, v157, v158 built, unverified)

**Repo layout (reorganised 2026-11-26):** rules for every assistant are in `AGENTS.md` (read first). This file is the only live handoff; old per-version notes are in `docs/archive/`, superseded scripts in `legacy/scripts/`. Nothing in `tools/` moved.
**Current build:** `1-KEEP\v155-CURRENT-play-this\justice-gakuen2-v155.cue` (SHA-256 `31fd4791...d17c`). Fight HUD art in `DAT2/CEFT1.BIZ`: READY!!, ROUND n, FIN AL, FIN ISH, FIGHT!, SUPER!/PERFECT!, TIME UP, DRAW, DREAM ATTACK, GUTS COUNTER. v155 = v154 + English "SWAP LEAD ?" prompt (seen in game; the "SWAP ALLY" partner variant is built, not yet seen). Rollbacks in `2-CAN-DELETE`: v154 (previous), v153, v150-v152. Only the user empties that folder. `original-disc` and `v46-base-for-next-patch` must stay in 1-KEEP. Rebuild/extend: `JG2_MASTER=<sha of previous BIN> JG2_VERSION=NNN PYTHONPATH=tools python tools/build_hud_v155.py <previous BIN> <new folder> --accelerator build-tools/practice_lz.dll --original <original disc BIN>` (`build_hud_v155.py` re-renders ALL HUD jobs from the original sprites, then paints the prompts: edit jobs in `tools/hud_v150.py` / `hud_v151.py` / `hud_v155.py`).
**How to test:** read `PLAYTEST_HOWTO.md` in full first (it separates the three kinds of Start, and says Tab fast-forward is for short bursts only because it steals focus). Fullscreen (F11), `work/fg2.ps1`, click the left black margin, 0.2 s `hold_key`.
**Done recently:** v145-v149 (Solo Play character select, shared overlay prompts, Mode Select labels; all verified). v150: fight HUD announcer art (READY!!, ROUND n, FIN AL, FIN ISH) - READY!! and ROUND 2 verified in game, the rest built but unseen. Details in the v150 section at the bottom.
**v156 (built, NOT seen in game):** `1-KEEP\v156-CURRENT-play-this` = v155 + English epilogue narration (22 EDB pages, SHA-256 `28300c13...1eff`). v155 stays the last verified build. Do not call v156 good until an epilogue is seen in game (queue 011 has the risks). Rebuild: `JG2_MASTER=<sha of previous BIN> JG2_VERSION=NNN PYTHONPATH=tools python tools/build_endings_v156.py <previous BIN> <new folder> --original <original disc BIN>`.
**v158 (built, NOT seen in game, newest):** `1-KEEP\v158-CURRENT-play-this` = v157 + English ending dialogue (23 ED pages); contains everything from v156-v157 (SHA-256 `7da50d74...adfa`). Rebuild: `JG2_MASTER=<sha> JG2_VERSION=NNN PYTHONPATH=tools python tools/build_endings_v158.py <previous BIN> <new folder> --original <original BIN>`. If any ending screen goes black, fall back to v157 (HUD only) or v155.
**v157 (built, NOT seen in game):** `1-KEEP\v157-CURRENT-play-this` = v156 + CLOSE WIN! banner + HEAL sprite (PL140/240/410), SHA-256 `8e2baab6...c657`. `2-CAN-DELETE\v157-first-build-with-HITS` is an obsolete first attempt. Rebuild: `JG2_MASTER=<sha> JG2_VERSION=NNN PYTHONPATH=tools python tools/build_hud_v157.py <previous BIN> <new folder> --accelerator build-tools/practice_lz.dll --original <original BIN>`.
**Next:** see an ending/epilogue in game to confirm v156 (queue 011), then the ED dialogue pages; then 003+008 CEFT1, 012, 013, 014, 015; also 005. Verify offline first, then load a state (docs/SAVESTATES.md) for one short in-game pass per batch (see "Workflow" in `AGENTS.md`).
**Tools added:** `tools/hud_v150.py` + `build_hud_v150.py` (v150), `tools/charselect_v145.py`, `over_v147.py`, `menu_fit_v148.py`, `menu_center_v149.py` (+ matching `build_*.py`), `vram_from_state.py` (VRAM from a DuckStation state). DuckStation's Debug menu is enabled in its settings (Debug > Dump CPU to VRAM Copies finds dynamic uploads; turn it off and delete the PNGs afterwards in %LOCALAPPDATA%\DuckStation).

---

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


Per-version history (v143-v154 notes, prompt-hunt research, fight HUD details): `docs/archive/HANDOFF_history_v143-v154.md`.
