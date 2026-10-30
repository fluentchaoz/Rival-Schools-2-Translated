# Shared School Life dates and daily narration v26

This is the first build candidate from the whole-disc batch plan. It covers the
ordinary dynamic-date messages and attached narration across all 78 School Life
runtime text images, including the April21 after-school opening reported by Ryan.
It is not a translation of all subsequent unique story dialogue.

## Inputs and preservation

- Actual v25 master BIN SHA-256:
  `5f31d90f089f520d6824add5c5368e10be2607955ad3b9e5c24b73b9aa010453`.
- Original BIN SHA-256:
  `0fce6eda2082d91af5a963c73fbf80a7935b1ebd5446dff5d01e548370fabe8e`.
- Private packet `shared_daily_dates_v26.json`, SHA-256:
  `714f77e8112daed6585e5912a5e312b8093229bbd13ad1cce9fdafb521cebfa6`.
- Recovery checkout, Rust 1.98.0 and a font; default Windows Arial.

The private packet is supplied in **JG2-Shared-Dates-v26-Inputs.zip** through the
translation conversation. Download it into Downloads; leave it zipped. The
builder reads only the expected bounded member and checks its exact content hash.
It also accepts `-PacketPath` with that ZIP or the exact JSON file. The public
builder does not embed the dialogue packet or fetch it from a public service.
This preserves the publication boundary established in the mainline roadmap.

There are 46 original date/narration patterns at 4,836 coordinates. Repeated
slots are not 4,836 unique new translations. Both player-variant phrasings were
read and fitted to the native 20-cell, four-row dialogue window. Month/day remain
runtime insertions; the date's palette controls and arguments are retained.

Original-source glyph/control fingerprints identify the targets. A current
message is eligible when all text and controls still match the source after
ignoring the literal month/day separators. That permits upgrading the older
slash-only date patch. Any other changed payload is retained byte-for-byte and
listed in the report, preserving custom English such as the field-trip opening.
Do not claim retained custom payloads were newly translated by v26.

The patcher reuses identical English glyph tiles where present and installs
missing characters only in unused, empty extension cells. Existing glyphs,
unrelated messages, script bytes, palettes, HUD, graphics and non-text records
are preserved. Banks are repacked with native shared pointers, within the same
arena and fixed compressed record slots. The five MGG loaded bundles are checked
against their 25 standalone records and updated together.

## Run

Use the terminal where recovery builds succeeded:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\build_shared_dates_english_v26.ps1
```

Optional read-only preflight:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\build_shared_dates_english_v26.ps1 -CheckOnly
```

The builder locates the exact v25 candidate, requires a new output directory,
checks free space, saves an exact Rust source backup, restores source/environment
in `finally`, and rechecks input/output identities. It produces:

```text
C:\Users\Fluent\JG2-Recovery-v1\candidates\shared-dates-v26-<new GUID>\build\justice-gakuen2-shared-dates-v26.cue
```

The final console prints the actual path and BIN hash, translated/preserved
coordinate counts, report path and native-glyph preview folder. Keep v25.

## Validation and limits

The direct Rust original-disc fixture passed: 78 banks, all 4,836 coordinates,
46 previews, fixed-slot compression, native pointer/record readback, owned-sector
changes and EDC/ECC. It changed 10,761 sectors and finished in 131.08 seconds.
Fixture output SHA-256:
`4c02ebabd9e569fe96f5ada6bb38ab206c777d4ff1f27a5ca3a7cc56c827201a`.

That is **not** the expected production hash. The fixture substitutes the
verified original for the QA master and Nimbus Sans for Windows Arial; it lacks
the previous English layers. Production retains the exact v25 master guard.
Actual v25 compression profiles and preservation counts must pass the user's
Windows run. The fixture's zero preserved-custom count is expected on an original
disc and must not be quoted as production evidence.

All 46 bitmap previews were inspected: no clipped text or row/column overflows.
Previews use MM/DD to illustrate the maximum two-digit insertion width and a
neutral white palette. The live game supplies digits and the preserved date
palette. They are layout checks, not emulator screenshots.

The separate preservation regression and offline wrapper checks are recorded
in `validation/shared-dates-v26.json`. PowerShell runtime and native gameplay
validation remain pending until the actual Windows build and playtest.

## In-game checks

Fresh-boot the newly printed CUE in DuckStation. Use an in-game memory-card save,
not a save state holding the old loaded text bank.

1. Reach April21: date uses a slash and the after-school narration is English.
2. Check an available seasonal or exam notice; confirm the date and four-row fit.
3. Revisit an earlier translated event when convenient, especially the custom
   spring field-trip opening, and confirm its text is retained.
4. Check both player variants during broader QA. One playthrough cannot certify
   every school or branch.

Later unique encounters and story dialogue remain outside this shared batch.
The whole-disc roadmap continues with common daily interfaces and coherent
story/event packages rather than waiting for screenshots of each Japanese page.
