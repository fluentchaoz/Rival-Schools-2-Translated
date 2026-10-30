# Whole-disc English translation roadmap

The end goal is a playable English translation of the whole Japanese PlayStation
disc SLPS-02120. School Life is the priority. Preserve Japanese voice audio and
game behavior; translate readable dialogue, menus, help, interface graphics,
event cards and the other modes. Movie text and any unsupported text systems
must be inventoried rather than silently excluded.

This plan replaces the screenshot-driven sequence of small patches. Screenshots
remain valuable bug reports and native test evidence, but do not define the
translation backlog. A release being the first English translation is not a
verified claim at this point.

## Starting point and measured size

Current built candidate: v25,
`5f31d90f089f520d6824add5c5368e10be2607955ad3b9e5c24b73b9aa010453`.
The user reports progressing through Ran's invitation/ride to April21. This is
route progression evidence, not proof of every v25 location or name insertion.
Keep v24 as fallback. No v26 has been built.

The read-only original-disc scan verified the following. Its detailed report and
English draft packet are retained in the private `JG2-Mainline-Foundation-Batch01.zip`
checkpoint; the public repository stores this plan and reusable tools.

| Scope | Measured population | Meaning |
| --- | ---: | --- |
| ISO files | 947 | Path/size catalogue; not 947 text assets |
| School Life runtime text images | 78 | All source paths match pinned upstream inventory |
| Message coordinates | 62,639 | Includes duplicates, variants and potentially unreferenced slots |
| Exact glyph/control patterns | 18,807 | Pixel-based source identity; context must still be reviewed |
| Raw unique payloads | 42,681 | Different local glyph codes can represent the same visible text |
| Dynamic-date coordinates | 4,836 | All 78 text images, not just the 25 MGG event banks |
| Dynamic-date patterns | 46 | Both player variants and attached prose reviewed for first batch |

Pinned upstream independently defines 18,221 semantic groups at 40,026 referenced
coordinates for its resolved-primary script scope. Those are upstream constants,
not a new codebook/context audit performed here. Do not substitute either group
count for an English completion percentage. The original-source scan does not
measure the current English disc.

## Delivery order

| Phase | Work | Exit evidence |
| --- | --- | --- |
| 0. Foundation | Source inventory, reusable translation packets, coverage ledger, terminology, reproducible build manifest | 78-image structural scan done; current-English coverage import still required |
| 1. Shared School Life | Ordinary dates and their prose, daily menu/help, status/diary/save/load, choices, names/honorifics, common results, location variants | Every mapped shared group classified; source/control/fit checks and representative native tests pass |
| 2. Complete Taiyo | Remaining year of events, everyday encounters, club progression, exams, relationship branches, endings, both player variants | All reachable Taiyo-owned groups translated/reviewed; route matrix exercised; no known untranslated reachable groups |
| 3. Other schools | Pacific, Gorin, Gedo and Justice as complete route/event packages; reuse reviewed shared groups | Each school has an explicit coverage matrix, both variants and choice/endings checks |
| 4. Other game modes | Mode selection, fighting/arcade/story where present, training, options, character material, bonus content, credits, errors and save interfaces | Every inventoried mode/surface has a translated/already-English/approved-exclusion disposition and test evidence |
| 5. Public release | Consistency review, fresh-start and save compatibility tests, original-disc differential patch, recovery guide, known issues and credits | Reapply distributed patch to exact supported original; reproduce release hash and test boot/runtime |

Phases overlap where shared interfaces or non-School-Life text are inexpensive
to finish. The priority remains School Life. Complete Taiyo provides an end-to-end
pilot; it must not be mistaken for complete School Life. The other-school order
can follow measured unique workload, with Pacific first by default because the
user already encountered its untranslated route.

## How batches work

1. Select a complete system, event cluster or route chapter from the inventory.
   Aim for several hundred reviewed unique messages when context is coherent;
   split earlier for a new renderer, a large choice tree or uncertain ownership.
2. Extract private source/context and identify actual script consumers, speakers,
   branch conditions, both variants, loaded bundles and embedded graphic copies.
   Start from the existing upstream corpus/workspace/primary-script tooling.
3. Translate Japanese directly. Reuse a shared translation only after comparing
   context, control arguments and speaker voice. Record intentional exceptions.
4. Review meaning, terminology, player-name behavior and choices; then fit the
   actual renderer. English prose and fitted text are separate fields so a space
   adjustment cannot silently erase meaning. Keep all native control arguments.
5. Build cumulatively, preserving every untargeted payload/asset. Check source
   identity, pointers, glyph allocation, line/choice geometry, arena/compression
   limits, standalone/loaded-bundle agreement, changed-sector ownership and EDC/ECC.
6. Give Ryan one candidate and a short test route for the whole batch. Use in-game
   saves where supported; old save states can retain stale loaded banks. A handful
   of screens never establishes every branch passed.
7. Commit translations, builders, manifest/hashes, coverage changes, review notes,
   test evidence and resume directions. Keep the last tested candidate.

Do not reset reviewed work merely because the next batch uses a new master.
Eventually consolidate the growing historical script chain into a versioned
cumulative recipe that builds from the supported original plus private inputs.
Retain the historical builders for recovery until that recipe reproduces a known
candidate exactly. Do not spend an entire new pass redoing already-saved inventories.

## First batch: shared daily dates and narration

The private packet `translations/shared_daily_dates_batch01.json` starts the bulk workflow now:
46 source-reviewed English drafts, linked by source glyph/control fingerprint to
4,836 original coordinates across all 78 School Life text images. The raw English
is not yet fitted or built. Existing English overrides, including the field-trip
opening, must be retained or explicitly reconciled; never replace them blindly
with a generic source match.

The April21 screenshot matches the ordinary after-school narration in MGK04
selector3 entries0–2 (DATE-000); selector4 entries0–2 contain its separately
reviewed player-variant wording (DATE-024). Additional slots share each pattern.
That establishes a source match, not an execution trace proving which bank the
game loaded on that frame. The surrounding prose, seasonal lead-ins, exam and
holiday notifications all belong in this batch. Preserve runtime month/day
insertions and translate their literal separators.

Next implementation steps:

- Import current v25 coverage and private codebook/context from saved recovery
  inputs; confirm current glyph/payload identities without publishing game data.
- Resolve current-English conflicts for all 4,836 candidate coordinates.
- Fit the 46 drafts and source-control signatures to the live dialogue renderer;
  install missing glyphs without corrupting other messages.
- Use a reusable multi-bank patcher with standalone/loaded-bundle bindings. Run
  full fixed-slot/arena/sector validation and prepare a fresh v26 candidate.
- Native checks: April21 ordinary after-school opening, one seasonal lead-in,
  one exam notification, male/female variants and a previously translated event.

Batch02 then addresses common daily actions/help/status/diary choices identified
by the same corpus. Unique story batches proceed from the full route inventory,
not from the last Japanese screenshot.

## Progress and quality definitions

Every work item has independent fields for source mapped, English drafted,
meaning reviewed, renderer fitted, build passed and native test evidence.
"Translated" never automatically means "native tested." Unknown/unreachable
content remains explicitly listed until script/context evidence resolves it.

Public progress should report reviewed unique groups by a named, audited scope,
plus remaining unclassified surfaces. Do not add coordinate counts from earlier
patches and call that a disc percentage; duplicates overlap heavily.

A complete English release requires no known unclassified player-facing text,
reviewed reachable groups, working names/choices/save flows, and representative
route/ending coverage for every school and both variants. Broad automation
supports testing; it cannot certify every route merely by finding no Japanese
characters in a text export.

## Recovery and distribution

GitHub stores original translations, code, plans, checksums, manifests and test
results. It does not contain the original disc, fonts, generated discs, extracted
Japanese text/assets, emulator memory cards or private workspace/codebook inputs.
Keep a separate private backup of those irreplaceable inputs and saved games.

Each release checkpoint must identify its source hash, master/output hashes,
pinned upstream revision, font hashes, translation packet hashes, build order,
private prerequisites and current CUE. A clean restore drill must prove those
instructions are sufficient. Do not promise GitHub alone can restore private data.

Distribute a verified differential patch and instructions for the exact supported
original, not a rebuilt disc. Reapplying that patch and reproducing the release
hash is a required release test. Credit upstream reverse-engineering work and
contributors; confirm license obligations before distribution.

## Working agreement

The assistant owns inventory, translation drafting, context review, code and
automated validation, recovery records and preparing the next coherent batch.
Ryan owns gameplay feedback and the final artistic/project decisions, and runs
Windows builds where his private environment is required. No need to collect a
screenshot of every untranslated page. Report clear blockers honestly rather
than promising background progress between turns or a completion date without
measured translation/review throughput.

## Current publication boundary

Automatic approval review rejected the public upload of the dialogue packet and
extensive source-derived inventory. Those files and their validation report were
saved privately in JG2-Mainline-Foundation-Batch01.zip. This does not block local
translation, fitting or builds. Explicit authorization is needed before revisiting
that rejected public publication. The reusable tools and this plan contain no
extracted game text/assets.
