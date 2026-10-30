# Classroom location banner English v19

## Why this patch exists

After the successful v18 Windows build, the user pointed out `教室` beneath the
stat HUD in the pre-quiz classroom. It means **Classroom**. The screenshot shows
English dialogue, date, and stats; the remaining text belongs to the location
graphic. It does not show a v18 stat-result message and therefore does not
complete the v18 increase/decrease live test.

v19 changes that MGK04 location banner to `CLASSROOM`. It starts from the user's
actual v18 output, whose SHA-256 is:

`d720ea2ae3c2c1c52981b0536642b836ec8e2151c6e94b658abdd1a49e094068`

The user's original disc and earlier graphics export supplied the evidence;
no repeat export is needed. No game records or rendered game pixels are committed.

## Build and test

Run the standalone script from any Windows PowerShell directory:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\build_classroom_label_english_v19.ps1
```

It searches the recovery folder's `candidates/stat-results-v18-*` directories
for the exact verified v18 BIN, uses the staged original and prepared upstream
source, and loads the installed `C:\Windows\Fonts\arial.ttf`. It reuses Rust
1.98.0 and the recovery Cargo cache. It does not replay the recovery stages or
modify their state, plan, or scripts.

Output is a fresh folder:

```text
C:\Users\Fluent\JG2-Recovery-v1\candidates\classroom-label-v19-<unique-id>\build\
```

Open the printed `justice-gakuen2-classroom-label-v19.cue` in DuckStation.
Keep v18, v17h, and v16. Start the new CUE fresh; an older emulator save state
can retain a previously loaded texture or text bank.

1. Check that the banner under the stats says `CLASSROOM`, including its final M.
2. Check its white lettering, outline, and surrounding colored bar.
3. Check that the classroom background and teacher portraits remain intact.
4. Continue through the quiz, checking the English questions and fixed labels.
5. Check v18's `INT` increase/decrease message and native arrow, then report
   the next remaining Japanese.

Optional parameters: `-RecoveryRoot`, `-UpstreamRoot`, `-MasterBin`, `-SourceBin`,
`-FontPath`, and a fresh `-WorkRoot`. `-CheckOnly` performs read-only preflight.
The usual single-drive headroom requirement is approximately 4.65 GiB.

The builder saves an exact backup named `runtime_bundle_build.pre-v19.rs.bak`
before temporarily appending its Rust module to
`upstream/src/diary_scene/runtime_bundle_build.rs`. It restores those source
bytes even when compilation fails. The backup and `build-v19.log` remain in
the candidate folder. Existing output folders are rejected. After a hard
process interruption, restore that backup before retrying if the script reports
a remaining v19 injection.

## Verified ownership

The classroom appears in `DAT2/MGBGK04.BZZ`, member 1, first embedded 8-bpp TIM.
That image contains the classroom background and a location strip at
`x=0, y=220, width=128, height=24`. The earlier graphics export visually matches
the user's screenshot, including the `教室` lettering in that strip.

Only the left 128-by-24 strip is cleared. English ink is constrained to the
established visible area `x=4..79`; font sizes 12, 11, then 10 are tried until
the complete outlined word fits. The classroom palette differs from School
Gate: clear is index 0, outline is 1, and white fill is 228. Index 255 is not
white in this texture. Palette words, headers, background pixels, right-hand
strip pixels, all trailing portraits, and other members stay byte-identical.

Member 0 contains the earlier School Gate work; member 2 contains the quiz UI.
Both stored streams are preserved verbatim. `DAT2/MGK04.BIZ`, which contains
the quiz and v18 stat messages, is also verified unchanged after disc rebuilding.
Only this runtime classroom copy is patched; other scene bundles and catalogue
copies may still have Japanese labels.

| Identity | SHA-256 |
| --- | --- |
| Original MGBGK04 archive | `c45932c3ae22706250f3db1c000d9f8911a475083bd74e485c6daebbb3167558` |
| v18 MGBGK04 archive | `f418235d0a1d714ae1d63e88d254ffe42d034db9e3eb54e64892f261b92c5277` |
| Original classroom member, compressed | `6b807a50bf631b350ef4086ccdb8e0ea9c838627877e0e5773908295e1036c5d` |
| Original classroom member, decoded | `05c1aa75c4ebf24f7dc6623576565cd9adef9886913d006bda2a3cdd0877471d` |
| Original classroom TIM | `d07eac0aedbecf52ec68b896cce9f660c1d24bc6fd5f48aa0c10a5a039baf29f` |
| Original location strip | `11ca7aa45d9787c49e89d7c1e7c4f59e0003a7bdd506c12d78383d7df290f09e` |

The native runtime compression contract preserves a source compressed prefix,
the final input page, and the original maximum match and control-block limits.
The replacement must fit the unchanged 173,606-byte member slot and decode
exactly both before and after padding. Disc checks cover record readback,
unchanged image length, sector scope, regenerated EDC/ECC, and input hashes.

## Validation status

The actual source record patch and rendered banner preview passed using
Liberation Sans Regular as the local test font. At 11 pixels, the outlined word
fits within `x=4..74`, and the member uses 172,054 of 173,606 bytes. Sentinels
inside members 0 and 2 survived exactly. These font-dependent output values
are test evidence, not promised Windows Arial hashes or compression sizes.

The full PowerShell builder also passed against a 663,216,960-byte disc fixture
based on the verified original disc, the actual patched v18 MGK04 record, and
opaque preservation sentinels in the other MGBGK04 members. A temporary QA copy
substituted only the master image/archive identities; the production identities
remain fixed. The build changed 66 sectors inside MGBGK04, passed record readback,
image-length and EDC/ECC checks, preserved the v18 MGK04 bytes, rechecked both
input images, and restored the exact Rust source. This is a fixture result,
not a real v19 Windows disc or emulator test.

Machine-readable test metadata: [validation/classroom-label-v19.json](validation/classroom-label-v19.json).

Eight PowerShell wrapper tests passed: input identity, read-only preflight,
space, output collision, exact source restoration, missing success outputs,
automatic v18 discovery, and missing font. Run them with:

```text
python -m unittest discover -s tests -p test_classroom_label_builder.py -v
```

Set `POWERSHELL` to the executable path if `pwsh` is not on PATH. The actual
Windows v19 build subsequently passed; native in-game checks remain pending. The builder records
the selected font hash, pixel size, exact output hash, and preview path.

## Actual Windows build received

The user's run passed one Rust test and all final checks. Output SHA-256:
`0b378dd421323c6248307013ef185270ea581964d34cd7ab52826eb8b6e412f2`.
Changed sectors: 66. Compressed member: 172,054 / 173,606 bytes. Font: 11px,
clear 0, outline 1, fill 228. This is actual Windows evidence, distinct from
the earlier local fixture. The next screenshot shows the quiz CORRECT stamp
and untranslated rating popup, not the classroom banner or stat results.
