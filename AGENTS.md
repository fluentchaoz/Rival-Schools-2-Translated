# AGENTS.md - rules for any AI assistant (Claude, ChatGPT/Codex) on this project

English patch for Justice Gakuen 2 / Rival Schools 2 (PSX, SLPM-86750), played in DuckStation.
This file is the shared contract. `CLAUDE.md` points here. If this file and an older doc disagree, this file wins.

## New here? Do these 5 things
1. Read this file, then the START HERE block of `HANDOFF_NEXT_CHAT.md`.
2. Run `git log -5` and `python tools/queue_status.py` to see where things stand.
3. Pick a task in `queue/open/` that you can do (check its **Needs** line: `emulator`, `image-generation` or `none`), move it to `queue/in-progress/`, and when done fill in **Result** and move it to `queue/done/`.
4. If you cannot do something (no emulator, cannot draw English art for a Japanese image), say so in the task file and move it back. Do not guess or fake it.
5. Never push, never delete builds, never commit disc data. Mark anything you did not see in game as unverified.

## Read order
1. The "START HERE" block at the top of `HANDOFF_NEXT_CHAT.md` - the ONLY live handoff.
2. `PLAYTEST_HOWTO.md` (driving DuckStation) and `PLAYTEST_LIST.md` (what is verified / pending).
3. `TRANSLATION_STYLE.md` before writing any English text.
Everything in `docs/archive/` and `legacy/` is history. Do not treat it as current.

## Layout
- `queue/` - the work queue: one file per task, folder = status (`open/`, `in-progress/`, `done/`). Read `queue/README.md`; `python tools/queue_status.py` lists it. Any assistant may take a task it can do.
- `tools/` - the live Python toolchain (build chain v47 -> current; see the handoff's "Build chain").
- `assets/`, `translations/` - English text and small JSON inputs. Never commit extracted Japanese text, glyph tables, previews or disc data (see `.gitignore`).
- `tests/` - unit tests. Some still pin Codex-era scripts at the repo root (`build_*_english_v*.ps1`, `probe_stat_results_v18.ps1`, `Apply-Practice-Roof-v37.ps1`, `PRACTICE_*_V3*.md`); do not move those without updating the tests. Known baseline: 54 tests, 1 failure, 6 errors, 44 skipped (environment: no cargo / PowerShell quirks).
- `legacy/scripts/` - superseded PowerShell/probe scripts (Codex era, v1-v37). Reference only.
- `docs/archive/` - superseded per-version notes, old handoffs and milestones.
- Game builds live OUTSIDE the repo in `C:\Users\Fluent\JG2-Project\1-KEEP\` (current) and `2-CAN-DELETE\` (old).

## Hard rules
- Never delete a build yourself: move old ones to `2-CAN-DELETE`; only empty that folder when the user asks. `original-disc` and `v46-base-for-next-patch` always stay in `1-KEEP`.
- Each build step takes the exact previous BIN as master (size 663216960 + SHA check, `JG2_MASTER` env var) and writes to a NEW folder.
- The user commits and pushes only when they say so. Never push on your own.
- Do not commit `*.bin`/`*.cue`/disc images or extracted game assets.
- Do not work around blocked installs (e.g. pip) - ask.
- Keep DuckStation fullscreen (F11) while playtesting; do not call `open_application` for it after launch (spawns a second copy).
- Bitmap font: A-Z, digits, space ! ' , - . / ? only; <= 20 cells per line, <= 4 lines.

## Workflow (how work is done here)
1. **Inventory before editing.** Know what is still Japanese before translating. The inventory is task 009; keep it current as items are fixed.
2. **Batch by source file.** Group every item that lives in one disc file (e.g. all of `DAT2/CEFT1.BIZ`) into one build. One build per batch, not one per sprite.
3. **Verify offline first.** Preview the patched sheet with the game's real palette, or dump VRAM from a savestate, before touching the emulator. Playing is for placement, cropping, timing and wording in context.
4. **Test from savestates, not from boot.** Task 010 keeps a library of states (scene name, build, how it was made). Use a state and a fast trigger, not a 3-minute boot and a mashed fight. Booting fresh is the last resort.
5. **One short in-game pass per batch.** Record what was seen and what was not in `PLAYTEST_LIST.md`; log newly found Japanese as inventory entries, not as ad-hoc tasks.
6. **Split by capability.** Tasks that need real art generation go to whoever has image tools; the sprite painter and emulator work go to whoever can drive DuckStation.

## Handoff protocol (so two assistants don't collide)
- Before starting: read the START HERE block, then `git status` / `git log -5`. Say which build you are continuing from.
- One assistant works on a given build step at a time. Note in START HERE who has it ("in progress: <assistant>, <target>") and clear it when done.
- Open work lives in `queue/`, not in the handoff. Claim by moving the task file to `in-progress/`; finish by filling in **Result** and moving it to `done/`; if you cannot finish, move it back with notes.
- After each VERIFIED (seen in game) build: update START HERE and `PLAYTEST_LIST.md`. Do not create new `*_Vnn.md` files or new root-level scripts; put feature notes in the handoff or in a short file under `docs/`, and new tools in `tools/`.
- Mark anything not seen in game as unverified. "Built" is not "works".
