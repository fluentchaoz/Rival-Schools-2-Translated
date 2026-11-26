# AGENTS.md - rules for any AI assistant (Claude, ChatGPT/Codex) on this project

English patch for Justice Gakuen 2 / Rival Schools 2 (PSX, SLPM-86750), played in DuckStation.
This file is the shared contract. `CLAUDE.md` points here. If this file and an older doc disagree, this file wins.

## Read order
1. The "START HERE" block at the top of `HANDOFF_NEXT_CHAT.md` - the ONLY live handoff.
2. `PLAYTEST_HOWTO.md` (driving DuckStation) and `PLAYTEST_LIST.md` (what is verified / pending).
3. `TRANSLATION_STYLE.md` before writing any English text.
Everything in `docs/archive/` and `legacy/` is history. Do not treat it as current.

## Layout
- `tools/` - the live Python toolchain (build chain v47 -> current; see the handoff's "Build chain").
- `assets/`, `translations/` - English text and small JSON inputs. Never commit extracted Japanese text, glyph tables, previews or disc data (see `.gitignore`).
- `tests/` - unit tests. Some still pin Codex-era scripts at the repo root (`build_*_english_v*.ps1`, `probe_stat_results_v18.ps1`, `Apply-Practice-Roof-v37.ps1`, `PRACTICE_*_V3*.md`); do not move those without updating the tests. Known baseline: 54 tests, 1 failure, 6 errors, 44 skipped (environment: no cargo / PowerShell quirks).
- `legacy/scripts/` - superseded PowerShell/probe scripts (Codex era, v1-v37). Reference only.
- `docs/archive/` - superseded per-version notes, old handoffs and milestones.
- Game builds live OUTSIDE the repo in `C:\Users\Fluent\JG2-Project\1-KEEP\` (current) and `2-CAN-DELETE\` (old).

## Hard rules
- Never delete a build: move old ones to `2-CAN-DELETE`. `original-disc` and `v46-base-for-next-patch` always stay in `1-KEEP`.
- Each build step takes the exact previous BIN as master (size 663216960 + SHA check, `JG2_MASTER` env var) and writes to a NEW folder.
- The user commits and pushes only when they say so. Never push on your own.
- Do not commit `*.bin`/`*.cue`/disc images or extracted game assets.
- Do not work around blocked installs (e.g. pip) - ask.
- Keep DuckStation fullscreen (F11) while playtesting; do not call `open_application` for it after launch (spawns a second copy).
- Bitmap font: A-Z, digits, space ! ' , - . / ? only; <= 20 cells per line, <= 4 lines.

## Handoff protocol (so two assistants don't collide)
- Before starting: read the START HERE block, then `git status` / `git log -5`. Say which build you are continuing from.
- One assistant works on a given build step at a time. Note in START HERE who has it ("in progress: <assistant>, <target>") and clear it when done.
- After each VERIFIED (seen in game) build: update START HERE and `PLAYTEST_LIST.md`. Do not create new `*_Vnn.md` files or new root-level scripts; put feature notes in the handoff or in a short file under `docs/`, and new tools in `tools/`.
- Mark anything not seen in game as unverified. "Built" is not "works".
