# START HERE (updated 2026-11-28)

**Read first:** `AGENTS.md` (rules, "New here? Do these 5 things", Workflow), then this block, `PLAYTEST_HOWTO.md`, `docs/INVENTORY.md` (what is still Japanese), `docs/SAVESTATES.md` (fast tests), `docs/ENDING_ENGINE.md` (how ending text is drawn). `python tools/queue_status.py` lists the work queue; all open work is in `queue/`.

## Builds (outside the repo, in `C:\Users\Fluent\JG2-Project\`)
- `1-KEEP\v161-CURRENT-play-this\justice-gakuen2-v161.cue`: NEWEST. Chain v155 -> v156 -> ... -> v161, each built on the exact previous BIN (SHA-256 below). Not everything in it has been seen in game.
- `1-KEEP\v155-CURRENT-play-this`: last fully verified build (rollback if anything in v156-v161 breaks).
- `1-KEEP\original-disc` and `v46-base-for-next-patch`: never remove. `2-CAN-DELETE\`: older and intermediate builds; only the user empties it.

| Build | Adds (builder script in `tools/`) | Seen in game? | SHA-256 |
|---|---|---|---|
| v155 | "SWAP LEAD ?" prompt (`build_hud_v155.py`) | yes | 31fd479195f2138ddcc5307e6917bc3d283712c7b0b7e25247a5058b4f4fd17c |
| v156 | 22 epilogue pages EDB (`build_endings_v156.py`) | NO | 28300c131dde3335ae6cad0ef2aa6ef4158e75f2a7a2a8795f9b165ff46f1eff |
| v157 | CLOSE WIN! banner, HEAL sprite in PL140/240/410 (`build_hud_v157.py`) | NO | 8e2baab650175d92ceb186962e5531c127161e5366eb10ed3f836379bb1ac657 |
| v158 | 23 ED ending dialogue pages (`build_endings_v158.py`) | NO | 7da50d7426d17db637c7124cb0355bf54a44abb00b3b7a69f93380e5bbc5fada |
| v159 | 24 move-list sheets EDITCM + tag-attack list (`build_editcm_v159.py`) | NO | 87bd1105fda2a513c249cd3059b67b9cfdc994963edeca04bb440765b0c73673 |
| v160 | 17 fighter name labels (`build_hud_v160.py`) | yes (BAT/SU, DAI/GO) | 8a354b8ff012a5289146a8a49b8684c3cf7611267bc699949dfc1c16eff9cc62 |
| v161 | HITS combo counter (`build_hud_v161.py`) | yes ("2 HITS") | b2875f9873e16d4198cc2ca199ad6a7b27c03e70806ff4aa61d4ab9ff4679615 |

Rebuild/extend: `JG2_MASTER=<sha of previous BIN> JG2_VERSION=NNN PYTHONPATH=tools python tools/<builder>.py <previous BIN> <NEW folder> [--accelerator build-tools/practice_lz.dll] --original <original disc BIN>` (new folder every time; builders enforce the exact master). New painter jobs go in the matching `tools/hud_*.py` / `endings_v156.py` / `editcm_v159.py`; translations in `translations/*.json` (English only).

## Testing rules that cost time when ignored
- Close DuckStation when a test is done. Launch with `-batch -state N <cue>`; a state records its disc path (retarget with `tools/state_retarget.py`).
- New fight HUD art only shows when walking from slot 3 (Mode Select); states made after the HUD loads keep the old art in VRAM.
- Character select needs one extra C before Start, then hold Start 0.6 s.

## Next work (priority order)
1. See an ending and an epilogue in game on v161 (queue 011) to confirm the EDB/ED layout and the streams; fine-tune font size and breaks from that. Also view CLOSE WIN!, HEAL, the move-list screens (013), the other name labels (003 follow-up) and the 先制 popup (008).
2. Queue 014: exam / shop / options / Edit-mode UI sheets (SIKEN, KOUBAI, OPTINFO, MENU, MOJI2, EDITMOJI, SELP).
3. Queue 008: remaining CEFT1 strips (愛と友情のツープラトン, フィニッシュ必殺), CEFT3 copy of the banners and Training text; 005 loading-card text (ただいまロード中, credit); 006 第一話 card; 007; 015 (certificate, school songs).
4. Keep `docs/INVENTORY.md` current: re-run `tools/inventory_sweep.py` on each new build.

Tools added recently: `inventory_sweep.py`, `ed_pages.py`, `endings_v156.py`, `editcm_v159.py`, `hud_v155/v157/v160.py`, `state_patch.py`, `state_retarget.py`, `vram_from_state.py` (+ the builders above).

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
