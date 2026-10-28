# Taiyo entrance ceremony English v21

Continuation input is the user's successful v20 Windows image:
`bf79b70fb5d806669fbf48917c634920e1934ff63d82072b9a0a48ab63238fec`.
The user completed the quiz and reached the April 8 ceremony card and school
exterior. Keep v20 and the original private recovery inputs.

## Scope

- Taiyo selectors 0/1, entries 0–56: 114 dialogue entries, covering both player
  variants, apology/teasing choices, the clock mix-up, and Ran's introduction.
- Four date-only messages (selectors 3/4, entries 18/19) use dynamic month/day
  notation such as `4/8`, preserving the native number insertions and text style.
- The same dialogue replaces member 0 of MGG04.BZZ, which the game loads.
- The April runtime graphics bundle gets APRIL 8 / ENTRANCE CEREMONY, matching
  SCHOOL GATE labels, and GYM labels. Exact matching copies are updated.

Later club-orientation events and other schools' ceremony dialogue remain
untranslated. The first transition toward club orientation is included.
The source screenshots match Taiyo's exterior. Both player variants were read
from their original rendered glyphs; untranslated events retain their font.

## Build and recovery

The self-contained `build_entrance_ceremony_english_v21.ps1` finds exact v20 under
`JG2-Recovery-v1/candidates/rating-popup-v20-*`. It requires the staged original,
prepared upstream, installed Arial, Cargo, and Rust 1.98.0. It prints the new CUE
under a separate `candidates/entrance-ceremony-v21-<unique-id>/build` folder.

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\build_entrance_ceremony_english_v21.ps1
```

Use `-CheckOnly` for read-only preflight. Alternate `-RecoveryRoot`, `-MasterBin`,
`-SourceBin`, `-UpstreamRoot`, `-FontPath`, and a fresh `-WorkRoot` are supported.
Typical single-drive headroom is 4.65 GiB. The original recovery kit and its
hash-bound plan/state remain unchanged. Recovery order is original private kit
through v16, then v17h, v18, v19, v20, and this v21 candidate.

The wrapper saves exact source bytes as `name_entry_input_tests.pre-v21.rs.bak`,
restores source/environment on ordinary failure or completion, and retains a log.
After an external interruption, restore that backup if preflight reports a
remaining v21 injection. Never bypass source or master hash checks.

## Ownership and implementation

Only DAT2/MGG04T.BIZ, DAT2/MGG04.BZZ, and DAT2/MGBGG04.BZZ are replaced.
Each is bound to its original identity, and v20 must contain those exact records.
The whole-disc check requires every changed sector to belong to these records.
It verifies readback, EDC/ECC, fixed image length, and unchanged input hashes.

New ASCII glyphs go after all original nonblank or referenced slots. Every
message is limited to four 20-cell lines. Choices retain two rows. Name
insertions, renderer modes, styles and terminators are preserved; English line
wrapping/spaces replace Japanese line breaks/blank-column padding. Untargeted
message payloads and script bytes are preserved exactly, with banks reparsed.
The runtime bundle preserves other school members and padding.

Graphics replacements match exact original TIM bytes. The title uses its native
two-half layout (256x220 stored, 512x110 displayed). Only the original title/date
rectangles are repainted with row-matched colors from the existing pink palette;
flower artwork outside these rectangles stays exact. English title ink uses
vertical scale 2. Location labels change only their left strip. Palettes, TIM
headers, other images and all unrelated member bytes remain unchanged. Native
compression-prefix, final-page, match and control-block limits remain enforced.

The reviewed English packet and Rust template are versioned in `translations/`
and `patches/`. Run `python tools/assemble_ceremony_v21.py` to regenerate the
self-contained builder after changes; users need only that generated PS1.

## Validation and playtest

The complete builder passed on a verified original-disc fixture. Only the QA
copy's expected master hash was substituted; the production builder retains
the exact v20 identity. All three source-record guards stayed active. The test
changed 1,516 sectors inside the three owned records, passed record readback,
image-length and EDC/ECC checks, preserved input hashes, restored source exactly,
and passed every final PowerShell output check (exit code 0).

The dialogue uses 35 new glyphs in slots 892–926, 100,908 / 102,368 message-arena
bytes, and 225,290 / 225,706 compressed bytes. The graphics patch updates five
title copies, six matching gate copies, and three matching gym copies across
12 runtime members. All native compression contracts passed.

Eight wrapper tests passed: wrong master, check-only, insufficient space,
existing outputs, compiler failure/source restoration, missing success outputs,
automatic v20 discovery, and missing font. Run with:

```text
python -m unittest discover -s tests -p test_entrance_ceremony_builder.py -v
```

The rendered title and location previews were visually inspected. Dialogue
layout/name/control checks pass, and the new text record reproduces the earlier
visually inspected record hash. Local tests used Liberation Sans Regular,
which is not claimed to be Windows Arial. Full machine-readable evidence is in
`validation/entrance-ceremony-v21.json`. Its output hash is a fixture identity;
that fixture lacks earlier English layers. Windows v21/native checks remain
pending; the Windows output hash will be recorded after the user's run.

Boot the new CUE fresh and complete the quiz. Check the pink title card, the
`4/8` date, School Gate/Gym labels, Batsu calling the player's name, both ceremony
choices, Ran's introduction, and transition toward club orientation. Old emulator
save states can retain loaded Japanese textures or banks. Keep v20 throughout.
