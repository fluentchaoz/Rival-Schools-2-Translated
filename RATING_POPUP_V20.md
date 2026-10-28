# Quiz rating popup English v20

The user's correct-answer screenshot shows the English CORRECT! stamp and a
separate rainbow 評価UP graphic. This patch translates that popup as RATING UP.
The screenshot confirms the stamp display, not every quiz branch, classroom
banner, stat-result message, or the identity of the loaded disc.

## Input and recovery order

Use the exact successful Windows v19 BIN:

`0b378dd421323c6248307013ef185270ea581964d34cd7ab52826eb8b6e412f2`

Recovery order is the original private recovery kit through v16, v17h quiz UI,
v18 stat results, v19 classroom banner, then this v20 candidate. Keep the private
kit/workspace/quiz packets and original disc separately; public GitHub does not
contain those inputs or rebuilt discs. Do not alter the hash-bound recovery kit.
See `recovery/RECOVERY_README.txt`, `RESUME_QUIZ.md`, `STAT_RESULTS_V18.md`, and
`CLASSROOM_LABEL_V19.md` for predecessor instructions.

## Build

Download `build_rating_popup_english_v20.ps1` from the same commit as this file,
then run it in Windows PowerShell:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\build_rating_popup_english_v20.ps1
```

It automatically finds an exact v19 candidate under
`C:\Users\Fluent\JG2-Recovery-v1\candidates\classroom-label-v19-*\build`.
It uses the staged original disc, prepared upstream source, installed Arial,
Rust 1.98.0, and existing recovery Cargo cache. It creates a separate folder
`candidates/rating-popup-v20-<unique-id>/build` and prints its CUE path.

Optional parameters: `-RecoveryRoot`, `-UpstreamRoot`, `-MasterBin`, `-SourceBin`,
`-FontPath`, and a new `-WorkRoot`. `-CheckOnly` performs read-only preflight.
The normal single-drive headroom requirement is approximately 4.65 GiB.
An exact source backup and build log remain in the candidate directory.
The wrapper restores source bytes and environment variables even after failure.
If interrupted externally, restore `runtime_bundle_build.pre-v20.rs.bak` before
retrying when the script reports an existing injection. Never bypass hash checks.

## Ownership and preservation

Only `DAT2/MGBGK04.BZZ`, member 2, TIM at decoded offset `0xe000` is changed.
The popup occupies x=664, y=80, width=104, height=40 in its 768x256 4-bpp atlas.
The source popup pixels are checked against both the original disc and a fixed
hash. The current member must match the reproducible v17h member hash:

`43c6bdd2a2f3af4735dcd56a32a0de124db7f60dcd978ee7e48008eac85201a2`

The text is fitted within a two-pixel inset, with vertically doubled font ink,
a dark outline at index 13, transparency at 0, and rainbow ink indices 1–12.
Native cycling palettes remain byte-identical; the game still selects them.
The builder does not modify sprite commands, timing, game logic, or UV coordinates.

Every decoded byte and indexed pixel outside the popup is verified unchanged.
The CLASSROOM and School Gate members are preserved byte-for-byte, as are
QUESTION, CORRECT!, WRONG!, EXAM OVER, TIME, and other quiz graphics outside the
popup. The full-disc builder verifies the existing MGK04 quiz/stat text record,
its unchanged readback, image length, allowed changed sectors, EDC/ECC, and input
hashes. Native compression-prefix, final-page, match, and control-block limits
remain enforced, within the fixed 86,620-byte member slot.

## Native test still required

Keep v19. Open the newly printed v20 CUE in DuckStation and boot fresh rather
than restoring an old save state with loaded textures.

1. Get a quiz answer correct and check the complete RATING UP text.
2. Check that its rainbow colors cycle and it appears/disappears normally.
3. Check CORRECT!, wrong-answer feedback, quiz progression, and EXAM OVER.
4. Continue to the stat results and check the English message and arrow spacing.
5. Check CLASSROOM on the classroom screen; this remains a separate check.

The Windows v20 build and native tests are pending. Local validation results are
recorded separately in `validation/rating-popup-v20.json`; local font-dependent
output hashes are not the Windows candidate's identity.

## Local validation

The v17h member was reconstructed using the committed v17h renderer and native
encoder; it reproduced the 86,044-byte stream. The v20 record patch passed,
including preservation sentinels in the unrelated members. The preview was
visually checked in three native rainbow palette phases. With Liberation Sans
Regular at 18px, 3,176 indexed pixels changed and compression remained
86,044 / 86,620 bytes. This font is not claimed to be Windows Arial.

Eight PowerShell wrapper tests passed: wrong master, check-only, low space,
existing output, compiler failure/source restoration, missing success outputs,
automatic v19 discovery, and missing font. Run them with:

```text
python -m unittest discover -s tests -p test_rating_popup_builder.py -v
```

The complete wrapper passed on a full-sized disc fixture constructed from the
verified original, reconstructed v17h quiz-graphics member, opaque sentinels in
other graphics members, and unchanged original MGK04 text. Only the fixture
copy's expected master and text-record hashes were substituted. Production
checks retain the actual v19 and v18-text identities. This test changed 13
sectors, passed EDC/ECC/readback checks, preserved inputs, and restored source
exactly. It is not an actual Windows v20 disc or in-game validation.
