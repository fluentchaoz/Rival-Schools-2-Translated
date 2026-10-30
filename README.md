# Rival Schools 2 Translated

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

**Latest Windows-built candidate: v28.** Both Windows tests and final verification
passed; the user reports that Status and Diary menus work in DuckStation.
See [v28 details](STATUS_DIARY_V28.md) and validation/status-diary-v28-windows.json.
Keep v27 as its fallback. Not every item description or birthday variant is native-tested.

**v29 startup notice is ready for Windows/native testing.** See
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
