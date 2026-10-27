# MGK04 stat results English v18 — candidate builder ready

## Current status — 2026-10-26

The user's v17h playthrough reached the post-quiz stat-result screen before
encountering Japanese. Their private stat-probe export is now received, and all
eight extracted records match their manifest hashes. The v18 record patch and
an end-to-end disc-fixture build passed. The next action is to build and test
v18 on the user's actual Windows installation. It is not yet live-tested.

The patch translates selector 2 entries 34–51 in `DAT2/MGK04.BIZ`: nine increase
messages and nine decrease messages. Labels are `ATK`, `DEF`, `STAM`, `GUTS`,
`POT`, `SPEED`, `PUNCH`, `KICK`, and `INT`, followed by the native arrow and
`INCREASED!!` or `DECREASED!!`.

Working v17h input SHA-256:

`2ff4d83cca04a22a217883ac9c29b3e2fa9c5c4796d9661db3f95d9acd92149a`

## Build the candidate

Run the standalone builder from anywhere in Windows PowerShell:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\build_stat_results_english_v18.ps1
```

It finds v17h through `C:\Users\Fluent\JG2-Recovery-v1\recovery-state.json` and
uses the staged original and prepared upstream source in that recovery project.
It reuses the installed Rust 1.98.0 toolchain and recovery Cargo cache. No font
installation, translation-packet download, or replay of the 22 recovery stages
is needed. Keep the original recovery kit and its plan unchanged.

The builder creates a new candidate folder under:

```text
C:\Users\Fluent\JG2-Recovery-v1\candidates\stat-results-v18-<unique-id>\build\
```

Open the exact `justice-gakuen2-stat-results-v18.cue` path it prints. Retain v17h
and v16. The builder leaves both inputs unchanged and restores its temporarily
appended Rust test source byte-for-byte, retaining an exact backup and build log
in the candidate folder. It never replaces an existing work folder. An interrupted
build's backup is `name_entry_input_tests.pre-v18.rs.bak`; its target is
`upstream/src/dialogue_audit/name_entry_input_tests.rs`.

Optional parameters are `-RecoveryRoot`, `-UpstreamRoot`, `-MasterBin`,
`-SourceBin`, and a fresh `-WorkRoot`. `-CheckOnly` checks prerequisites without
writing. `CARGO_TARGET_DIR` can put compiler output on another drive. The usual
single-drive headroom requirement is about 4.65 GiB.

## In-game checks

Boot the new CUE fresh; an old emulator save state can retain the old loaded
text bank. Replay the opening quiz and verify:

1. Questions and all four answers still render in English.
2. QUESTION, CORRECT!/WRONG!, EXAM OVER, timer, and progression remain intact.
3. The result says `INT` and `INCREASED!!` or `DECREASED!!` as appropriate.
4. The native arrow remains visible, with clear space on both sides.
5. Stat values and bars still behave normally; report the next Japanese screen.

Test both result directions when reachable. This candidate translates the
MGK04 stat-message copies, not the corresponding copies in every other scene
bank. A later scene can still have Japanese stat feedback.

## Patch evidence and ownership

The provided export independently confirms the original stat messages were
still unchanged in v17h. The current MGK04 stored record hash is
`460f998df47eab3a4e82425afc352badca543a66f4dbc7a82e2056657cf1c70d`.
The current MGAME hash is
`e8885452773fcf91bef4b85b2363a37d07547ab3c04b463c92c658d66cc1492f`.

Pinned upstream `98ca12ddf082d6e2367b2963f76edf5a09242deb` identifies the shared
arrow table at `MGAME + 0x21D4` and its consumer at `0x1A128..0x1A154`. Changing
that table for only MGK04 could affect untranslated scenes. This patch instead
composes compact labels from the already-installed Arial capital letters,
keeps the native arrow coordinates, and reserves the necessary blank columns.
The label ink ends 16 pixels before the arrow; the result begins 24 pixels after
its 48-pixel width. The complete row is at most 400 pixels wide.

Both palette controls, their arguments, the two protected padding controls, and
the message terminator are preserved. The exclamation cell combines the existing
Arial I stem and period, preserving their palette and baseline. The patch adds
36 glyph cells at codes 964–999, after all existing nonzero or referenced cells.
Future font allocation must preserve referenced blank cells too; these label
cells remain owned even when a whole component cell is blank.

The shared message arena is repacked, with every pointer rewritten and every
message parsed back. All non-target messages, including all 100 live quiz
entries, are byte-identical. The primary script and later decoded data remain
byte-identical. Only MGK04 is replaced in the disc; MGAME, MGCOCK, MGBGK04, the
executable, and other records stay unchanged.

Validated patched MGK04 SHA-256:

`91ca0e81829fb578d41797854718590e0f05e29b1325b6a1675e9df3a4584fa0`

- Decoded SHA-256: `3f41042b4a9258cebbfeaa3efacd95db7ba85aa9a84348c6df3cbd3a25e9375e`.
- Compressed bytes: 206,858 / 207,226; 368 bytes spare.
- Message arena: 31,372 / 102,368 bytes; 70,996 bytes spare.
- Native page-safe compression limits and final input page are preserved.

Machine-readable metadata: [validation/stat-results-v18.json](validation/stat-results-v18.json).
The production builder pins the tested replacement-record hash as well as both
full input-image hashes. The actual Windows output-disc hash is not known yet;
it will be reported by the user's run.

## Validation performed

- The actual uploaded original/v17h records passed manifest hashes, ZIP integrity,
  source identity checks, and the Rust record-build test.
- All 18 rendered text rows were inspected from the patched glyph pixels. This
  was a typography/layout preview with marked arrow bounds, not an emulator test.
- Six wrapper tests passed under PowerShell 7.4.13: wrong master, read-only check,
  insufficient disk, existing output, exact source restoration after compiler
  failure, and rejection of a success exit without required output files.
- The complete PowerShell builder ran successfully against 663,216,960-byte raw
  disc fixtures containing the actual exported records at their actual LBAs.
  Only the temporary QA copy's full-image identities were substituted. The
  production script's original/v17h hashes were not weakened.
- That fixture build changed 71 raw sectors, all inside MGK04, and passed record
  readback, unchanged-image-length, and regenerated Mode 2 EDC/ECC checks.
  The original input images and exact pre-build Rust source were preserved.
- Windows execution of this new builder and native in-game validation remain
  pending. A fixture disc SHA is not a real v18 disc SHA.

```text
python -m unittest discover -s tests -p test_stat_result_builder.py -v
```

Set `POWERSHELL` to the executable path if `pwsh` is not on PATH.

## Completed export

`probe_stat_results_v18.ps1` completed on the user's Windows PC, producing a
0.85 MiB private ZIP. It contains original and v17h copies of `DAT1/MGAME.BIN`,
`DAT2/MGK04.BIZ`, `DAT2/MGCOCK.TIZ`, and `SLPS_021.20`, plus record metadata.
That probe's seven synthetic tests also passed. The ZIP and extracted records
stay outside public GitHub; only scripts, checksums, original translation logic,
tests, and documentation are committed. No repeat export is currently needed.
