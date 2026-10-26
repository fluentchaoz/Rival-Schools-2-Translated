# Project Handoff — Read This First

This file is the continuity document for future ChatGPT sessions working on this project.

## Live continuation — 2026-10-25

The user reported v17h working through the quiz and supplied a screenshot of the
first remaining Japanese: the post-quiz intelligence-decrease message. The date
and stat HUD are English. Continue from v17h, retain v16, and address the paired
stat-result messages next. This report does not enumerate every quiz branch.

`probe_stat_results_v18.ps1` is a standalone read-only export, with seven passing
synthetic tests. It reads four records from each verified original/v17h image
and writes a private ZIP for the user to attach in the conversation. It does
not edit or rebuild anything in the recovery project. Read `STAT_RESULTS_V18.md`.
The next patch requires the actual exported records; no v18 candidate exists yet.

## Recovery completed — 2026-10-25

The full Windows recovery run completed all 22 stages and restored v16 with
SHA-256 `67ad4b9d628d0141493a42b456dfd8ce7631d3e9fdd7b2d387ceb84362127a51`.
Every reported stage hash matches the recovery plan. The original missing-image
blocker is resolved. The v8 CUE alone was insufficient; the recovered builders,
workspace and quiz packets rebuilt the translated disc from the original.

Current project: `C:\Users\Fluent\JG2-Recovery-v1\project`.
The extracted kit is `C:\Users\Fluent\Downloads\JG2-Recovery-Kit-v1`.

The subsequent Windows `-Resume` run successfully built v17h from this exact v16.
Candidate BIN SHA-256: `2ff4d83cca04a22a217883ac9c29b3e2fa9c5c4796d9661db3f95d9acd92149a`.
The patch changed 26 raw sectors and its build test passed. The complete CUE
path and in-game checklist are in `RESUME_QUIZ.md`.

Keep the kit, its plan/scripts, and
v16 unchanged; the recovery runner checks their saved identities on resume.

The source checkpoints, predecessor builds, and original input are retained.
v17h remains a separate image. Its Windows build and the user's subsequent
playthrough to the post-quiz stat screen are recorded; individual graphic/branch
checks have not all been separately reported.
The validation record is in `recovery/VALIDATION.md`.

Source-bound workspace ZIP/JSON stays outside public Git. No original game
disc, font, rebuilt image, or extracted workspace is included in this repository.

## Resume update — 2026-10-24

Read `CURRENT_MILESTONE.md` and `RESUME_QUIZ.md` before selecting an input build.
The user reports successfully reaching the English quiz. The active target is
v16, with a required input SHA enforced by `build_quiz_fixed_ui_english_v17h.ps1`.
The v5/v6 status sections and nickname task below are historical notes, not the
current starting point. Twelve later build scripts have been recovered into
this repository. At that earlier checkpoint, v17h still required a build on the
actual v16 master and in-game validation. The 2026-10-25 updates above supersede
that status.

Do not run the older v9 greeting rebuild over the later quiz work. A saved
attempt exhausted disk space during full workspace extraction. The v17h quiz
builder checks space first and patches only the relevant graphics member;
it does not extract the full translation workspace.

## Project

English fan translation / reverse-engineering of:

**Shiritsu Justice Gakuen - Nekketsu Seishun Nikki 2 (Japan)**  
Game ID: `SLPS-02120`

The goal is a complete English School Life / dating-sim mode while preserving Japanese audio and original game behavior as much as possible.

## Collaboration style

Work incrementally and prove each layer before moving on.

The preferred loop is:

1. Probe the original/runtime data.
2. Identify the exact producer/consumer or owned graphic cell.
3. Build one isolated patch.
4. Verify source hashes before writing.
5. Verify readback and changed-sector scope afterward.
6. Test in-game.
7. Promote the build only after live validation.
8. Commit successful scripts/docs to Git.

Avoid speculative edits, broad binary rewrites, or manual Rust edits when a source-verified scripted patch can be made instead.

When something fails, diagnose the **first actual error** and provide a corrected one-run PowerShell script.

## Local layout

Project root:

`C:\Users\Fluent\JG2-Recovery-v1\project`

Pinned upstream checkout:

`C:\Users\Fluent\JG2-Recovery-v1\project\upstream`

Source ROM folder:

`C:\Users\Fluent\Downloads\Shiritsu Justice Gakuen - Nekketsu Seishun Nikki 2 (Japan)`

Original BIN filename:

`Shiritsu Justice Gakuen - Nekketsu Seishun Nikki 2 (Japan).bin`

Original SHA-256:

`0fce6eda2082d91af5a963c73fbf80a7935b1ebd5446dff5d01e548370fabe8e`

Do not trust the source CUE blindly. It may reference a stale `[SLPS-02120]` filename that is not present. Probes/builders should create or use an explicit CUE against the SHA-verified BIN when necessary.

## Upstream

Repository:

`mcpads/justice-gakuen2-kr-patch`

Pinned commit:

`98ca12ddf082d6e2367b2963f76edf5a09242deb`

The local `upstream/` folder is deliberately ignored by this repo because it is its own checkout.

`SLPS_021.20` matches upstream exactly.

## Git rules

This repository should contain only original project work such as:

- PowerShell builders and probes
- documentation
- checksums
- reports that do not embed copyrighted game data
- original translation/build logic

Do **not** commit:

- ROM/BIN/CUE/ISO/CHD/PBP images
- BIOS files
- generated rebuilt discs
- extracted copyrighted game assets
- emulator saves/states
- Rust `target/`
- `upstream/work/`

The repository is currently public, so err on the side of not committing extracted game text/assets unless they are clearly safe to redistribute.

## Historical milestone

### v5 — live-tested master before behavior patch

SHA-256:

`2fe51561d025cc2ffdface62d1a7e7222a40937bb3b5a97ebc019f8338d43977`

Tag:

`name-entry-v5`

Confirmed working layers include:

- English main mode-select graphics
- School Life `PLAY / LOAD`
- English dialogue glyph support
- playable Batsu-route prototype
- HUD: `ATK / DEF / STAM / GUTS / POT / INT`
- MGK04 opening greeting
- `SCHOOL GATE`
- dynamic date such as `4/1 THU`
- full MGK04 tutorial/admissions dialogue translation layer
- English enrollment form
- English name-entry controls: `HIRA / KATA / A-Z / DEL / NEXT / BACK / OK`
- native `0-9 / A-Z / a-z` keyboard preserved and verified in-game

## Historical candidate

### v6 — default A-Z on first name-entry open

Built from v5.

Output SHA-256:

`e3808a7bef6c6529e45b29963895a6e45a26dd7c30b031be928fcdb4fa98a09f`

Patched MGENT SHA-256:

`93aee308f5db552b97482b5f2c91f95ae2246849965334d5c47b2ecf54d15751`

Patch scope:

- `9` changed bytes in `DAT1/MGENT.BIN`
- `1` raw disc sector changed
- graphics untouched

Live result:

- first entry into NAME now defaults to A-Z successfully
- however, when transitioning to NICKNAME, the game resets the page away from A-Z

Do **not** call v6 the final master yet; this nickname reset is the next behavior fix.

## Name-entry reverse engineering

Overlay:

`DAT1/MGENT.BIN`

Source SHA-256:

`eaf243e2d5a78919055b453611ea8b785766a6dc945966a1d5c0ce166714f70a`

Object fields:

- page index: `+9`
- record slot index: `+10`
- cursor cell: `+12`
- field index: `+15`

Physical pages:

- page `0` = Hiragana
- page `1` = Katakana
- page `2` = Alphanumeric

Native alphanumeric page is exactly 62 selectable glyphs:

- 10 digits
- 26 uppercase
- 26 lowercase

Cold-start page initializer:

- `MGENT + 0x1A5C` originally stores zero to object `+9`
- v6 rewrites the surrounding initializer so it stores `2` while preserving neighboring field initialization and restoring `V0 = 0x0200` before the original later halfword store

Nickname-specific initializer:

- `MGENT + 0x1FA4`: `addiu v0, zero, 1`
- `MGENT + 0x1FA8`: `sb v0, 9(s0)`
- therefore nickname explicitly forces page `1` (KATA)
- immediately afterward, `MGENT + 0x1FAC` reloads `v0 = 2`, so changing only `0x1FA4` from immediate `1` to `2` is the clean next patch

This means the next build should start from v6 and change only the nickname initializer immediate from `1` to `2`, then live-test NAME → FIRST → NICKNAME and page cycling.

## Name-entry fixed graphics

`DAT2/MA_ENT.BIZ`

Application-form TIM starts at decoded offset `0`:

- image x: 512
- image y: 0
- pixel width: 448
- image height: 464
- CLUT: 16×1

Name-entry font/control TIM starts at decoded offset `0x19000`:

- image x: 768
- image y: 0
- pixel width: 768
- image height: 256
- CLUT: 352×1 / 22 palettes

Native control sprite cells:

- `HIRA`: `(560,200)` 48×24
- `KATA`: `(608,200)` 48×24
- `A-Z`: `(656,200)` 48×24
- `DEL`: `(512,224)` 48×24
- `NEXT`: `(560,224)` 48×24
- `BACK`: `(608,224)` 48×24
- `OK`: `(656,224)` 48×24

Adjacent `(704,200)` is reserved for the incomplete-slot cue; do not overwrite it casually.

## Date subsystem

`DAT2/MGCOCK.TIZ` is a 4bpp TIM decoded to 1024×256.

Clean identities:

- decoded SHA: `bc81dda96d98a4ed06b37db9415636430db630d13217d2275059bb306d9fb655`
- stored SHA: `241d3ba8b25aef281c932f9bd64c0ffb84693abf72ad7b1d5cde852d4b655285`
- `DAT1/MGAME.BIN` SHA: `887c7c1775db5a18aed19661a08d109a5f35c54303259b21c7d6560ef1a3baba`

Final live-tested visible format is `4/1 THU`.

Important lesson: visually blank MGCOCK cells may be shared. Do not modify a cell merely because it looks unused; one earlier blank-cell experiment corrupted the stat HUD.

## School Gate layer

Opening location `校門前` maps to MGBG catalogue member 6.

Runtime consumers discovered:

- `DAT2/MGBGE03.BZZ` members 4 and 12
- `DAT2/MGBGK02.BZZ` member 26
- `DAT2/MGBGK04.BZZ` member 0

Fit-corrected live-tested build SHA was:

`a2e1587b828d5508a5dc99e4e64020d0a16fb4a8d0a569d3e8ddffccff0d98d1`

## MGK04 tutorial layer

Full tutorial/admissions translation v3 was live-tested and became the master before name entry.

SHA:

`30cdcc7cdbc1a21818b65272ac50e7baebc245f0505c83d03dfb2c00db713ac4`

58 semantic groups were authored. The patch replaced only `DAT2/MGK04.BIZ` and verified readback.

## Build discipline

Every production builder should, where practical:

- verify the exact input master SHA
- verify the exact source record SHA
- verify exact source instructions/cells before patching
- fail before writing if the source does not match expectations
- touch only the intended record(s)
- compare output disc sectors to ensure changes are inside owned records
- verify disc length is unchanged
- re-read the patched record from the rebuilt disc and compare bytes/hash
- print the output SHA, changed-sector count, and CUE path

A build is only a candidate until live-tested.

## How to resume in a future chat

A future assistant should begin by reading:

1. `README.md`
2. `CURRENT_MILESTONE.md`
3. `PROJECT_HANDOFF.md`

Then verify the newest live-tested master before making a new patch.

Do not assume the newest generated build is promoted merely because it compiled.

The original handoff's v6 nickname task is superseded by the recovered v7
builder. The current task is to test the built v17h quiz graphics candidate
in-game, as described in `RESUME_QUIZ.md`.
