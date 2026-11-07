# Rival Schools 2 Translated

## v37 practice / rooftop candidate — 2026-11-06

Issues #022–#025 are implemented in a new candidate based on exact v36: approved Kyosuke loading card, PK Shootout GUTS, shared English pause menus and the reviewed Edge/Daigo rooftop encounter. Rooftop coverage is 53 entries in each player variant (106 coordinates), with choices/outcomes, plus 16 location-label copies in 11 archives. Other rooftop encounters and other loading illustrations remain follow-up work. Read [PRACTICE_ROOF_V37.md](PRACTICE_ROOF_V37.md), [integration validation](validation/practice-roof-v37.json) and [updater validation](validation/practice-roof-v37-updater.json).

Output BIN SHA-256: `66e77edfbb41c7a20255407d5718ad54533f207026c23620c8121fcc38703ffc`. Ten integration checks pass; all 876 catalog signatures match, 921 untouched records remain exact, and all 1,483 changed sectors pass ownership/EDC/ECC checks. Native boot and live tests remain pending. Keep v36; fresh-boot the v37 CUE and use an in-game save. Check all six pause paths and the rooftop branches before closing the issues. PowerShell is reviewed, not executed here; the equivalent Python updater reproduces the exact BIN.

## v36 menu art / Backup candidate — 2026-11-06

Issues #018–#021 are implemented: eight menu-logo cells, 29 Backup messages in each of 78 runtime banks (plus M/D date-unit labels and 25 bundled mirrors), Service Ace record captions and both exam backdrop variants. Uses exact v35; preserves original report sheets/props, live result data, stamps and earlier English. Read [MENU_ART_V36.md](MENU_ART_V36.md) and [validation/menu-art-v36.json](validation/menu-art-v36.json). Native boot and live-screen checks remain pending; keep v35 and fresh-boot the new CUE.

Output BIN SHA-256: `9885ee49e0404d43218b36e7b40b7308a9b7300274e6984f0aa3a260cdba95f1`. All 876 loader bindings match, all 854 untargeted records remain exact, and all 3504 changed sectors passed ownership/EDC/ECC checks. The PowerShell wrapper is reviewed, not executed here; equivalent Python updater verification is recorded separately.

## v35 exam results / ball HUD / dance candidate — 2026-11-06

Issues #013–#017 are implemented in the v35 candidate. It applies to exact v34 and adds exam results/stamps, Explosive Shot HUD lettering, Doki-Waku selector names/schools and four Japanese scrolling captions. Eight integration tests and an updater roundtrip pass; native v35 boot/gameplay remains pending. Read EXAM_DANCE_V35.md and validation/exam-dance-v35.json. Preserve v34 and test via fresh boot with an in-game save.

Output BIN SHA-256: `c25207ba7f18dd73e56f5569d3df7dcdf3d9f92cc605dbbf17692b28a6e9cf8c`. All 876 catalog bindings match; all 934 untargeted records are exact. Decorative exam backdrop text remains original. Do not close issues until Ryan checks the relevant live screens.


## v34 practice layout / exam HUD candidate — 2026-11-06

Current native baseline: Ryan confirmed v33 boot, English title and mode select. v34 addresses issues #001 (points legibility), #008 (Sprint/shared ball-game WIN), #010 (BACK clipping), #011 (practice popup labels/speed markers) and #012 (exam START/FINISH/TASK graphics). Native v34 validation is pending. Read PRACTICE_LAYOUT_V34.md and validation/practice-layout-v34.json. Apply the new updater to exact v33; keep v33 as the boot-tested fallback. Do not close checklist issues until Ryan checks their corresponding screens.


## v33 native boot/title confirmed; collecting next batch — 2026-11-06

Ryan confirms v33 launches and the English title screen works. The supplied mode-select screenshot confirms CURRENT POINTS now fits, but its dense outlined lettering is difficult to read. Issue #001 remains open for legibility; boot blocker #009 is resolved. Continue collecting issues one at a time before preparing another build. Exam/replay/all-route tests remain unconfirmed.


English fan translation of **Shiritsu Justice Gakuen — Nekketsu Seishun Nikki 2**
for Japanese PlayStation, `SLPS-02120`.

**Goal: the whole disc in English, with School Life first.** Japanese voice audio
and game behavior are preserved. Other game modes, help, interfaces, graphics,
bonus material and credits are part of the intended scope.

## Start here

- [Whole-disc roadmap](TRANSLATION_ROADMAP.md): priorities, batch workflow, release and recovery requirements.
- [Current milestone](CURRENT_MILESTONE.md): latest actual build and native evidence.
- [Progress ledger](translation_progress.json): separate draft, fit, build and native statuses.
- [Project handoff](PROJECT_HANDOFF.md): historical checkpoints and technical constraints.
- [Translation conventions](TRANSLATION_STYLE.md).

## Current state

**v32 is withdrawn after a reported native boot freeze. Latest candidate: v33
boot hotfix.** A one-byte title-resource catalog correction preserves all v32
work. Catalog/sector checks and six tests pass; native boot is pending.
See [boot hotfix directions](BOOT_HOTFIX_V33.md). Keep v31 as fallback.


**Withdrawn build: v32.** Installs the supplied English title art,
repairs points/replay native layout defects, and translates the reported
first-term Practice Exam card. Earlier practice translations are retained.
Seven tests and all three updater paths passed; native testing is pending.
See [v32 details and directions](TITLE_EXAM_V32.md).


**Previous candidate: v31.** Current Points and the shared replay
prompts are English; the full FIERY SPRINT label and all v30 practice work are
retained. Updater paths from v29 and v30 passed exact-hash checks. Native testing
is pending. See [the v31 directions](MENU_FIXES_V31.md).


**Previous candidate: v30 practice interfaces.** All six practice
landing screens and seven rules pages are translated, shared menu labels are
updated, and FIERY SPRINT fits its native selection strip. The recovered-v29
sector updater reproduced the exact candidate hash. **Native testing is pending.**
See [practice audit and directions](PRACTICE_V30.md); keep v29.


**Recovered baseline: v29.** Its recovered BIN is 663,216,960 bytes, with
SHA-256 `f4f974c40220dd82925d4b17d6a31b3f95218a6017783666851204ea3040c67f`.
Archive extraction, CUE identity and all four startup-notice string slots passed
read-only checks. See [recovery verification](validation/boot-notice-v29-recovered.json).
The original build log/report was not supplied; v29 native gameplay is pending.

**Latest user-confirmed gameplay: v28.** Both Windows tests and final verification
passed; the user reports that Status and Diary menus work in DuckStation.
See [v28 details](STATUS_DIARY_V28.md) and validation/status-diary-v28-windows.json.
Keep v27 as its fallback. Not every item description or birthday variant is native-tested.

**Fresh-boot the recovered v29 CUE to test its startup notice.** See
[the v29 directions](BOOT_NOTICE_V29.md). It translates the two startup messages
using existing English glyphs. No additional private translation ZIP is needed.
Keep v28; practical-exam instruction graphics are still under investigation.

The project is moving to corpus-based batches instead of discovering each page
during a playthrough. The original-disc structural scan verified **78 School Life
text images, 62,639 message coordinates and 18,807 exact glyph/control patterns**.
Coordinates include repeats, variants and potentially unreferenced content.
These counts are not an English completion percentage.

## Existing translation and recovery work

Historical layers cover mode selection, School Life entry, admissions/enrollment,
English name entry, the quiz and fixed UI, stat messages, Taiyo ceremony,
pool/club orientation, club joining, spring field trip, event dates/titles and
matching location/name-insertion work. Coverage is partial; other schools and
later story content remain untranslated.

See the milestone/handoff for actual hashes and bounded playtest evidence.
The original recovery reproduced all 22 historical stages through v16; later
builders create separate verified candidates. Do not use an older builder over
a later working master without its required input hash.

## Tooling and reproducibility

Based on `mcpads/justice-gakuen2-kr-patch`, pinned upstream commit
`98ca12ddf082d6e2367b2963f76edf5a09242deb`.
The local `upstream/` checkout is intentionally not committed.

Read-only inventory (Python 3.11+ and Pillow, used by the shared reader):

```sh
python tools/inventory_disc_translation.py "/path/to/original.bin" "/private/disc-translation-inventory.json" --private-output "/private/source-review"
python tools/test_disc_translation_inventory.py
python tools/audit_shared_dates_batch01.py "/private/shared_daily_dates_batch01.json"
```

The optional private output contains extracted records and source fingerprints;
keep it outside public Git. See the roadmap for source binding, compression,
pointer, layout, sector and clean-rebuild requirements.

## Backups and public distribution

GitHub holds original translations, code, documentation, hashes and metadata.
It does **not** back up the original disc, extracted game assets/source text,
fonts, private codebook/workspace inputs, generated images or emulator saves.
Keep a separate private backup of those prerequisites and memory cards.

No ROM/disc image, BIOS or copyrighted game asset is distributed here.
The public-release goal is a reproducible differential patch for the exact
supported original, with installation directions, credits and known issues.
