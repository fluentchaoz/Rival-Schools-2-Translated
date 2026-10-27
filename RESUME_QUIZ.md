# Resume from the English quiz

## Continue from v17h at the stat-result screen

The user subsequently reported successful play through the quiz to the
post-quiz classroom stat-result screen. The first remaining Japanese is the
intelligence-decrease message; the screenshot shows the English date and stat
HUD. The next task is the paired stat increase/decrease messages.

The stat-probe export has been received and verified. Run
`build_stat_results_english_v18.ps1` to build the next candidate from v17h and
the original disc. See [STAT_RESULTS_V18.md](STAT_RESULTS_V18.md) for its scope,
validation, output location, and in-game checklist. It creates a separate image,
restores its temporary source edit exactly, and keeps the recovery kit unchanged.
Retain both v17h and the v16 fallback until v18 passes live testing.

## v17h build and remaining regression checks

Both the 22-stage recovery and the subsequent v17h Windows build passed on
2026-10-25. The actual candidate BIN SHA-256 is:

`2ff4d83cca04a22a217883ac9c29b3e2fa9c5c4796d9661db3f95d9acd92149a`

Open this CUE in DuckStation:

```text
C:\Users\Fluent\JG2-Recovery-v1\project\upstream\work\english-quiz-fixed-ui-v17h-e380163248384b70a99130d1193c7368\build\justice-gakuen2-quiz-fixed-ui-v17h.cue
```

For remaining regression checks, start from the disc; an old emulator save
state can restore previously loaded game data. The user's successful
playthrough does not separately enumerate each check below. Retain v16.

The same unchanged recovery kit's `-Resume` command verifies and reports an
already-completed v17h candidate. No rebuild of the 22 predecessor stages is
needed. Keep the kit and its plan intact so its saved state remains valid.

## Direct builder for a separately prepared project

The direct builder requires the exact v16 and original Japanese BINs. For a
moved project, pass their full paths with `-MasterBin` and `-SourceBin`.

Put `build_quiz_fixed_ui_english_v17h.ps1` in the existing project root beside
`upstream/`. Open PowerShell there and run:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\build_quiz_fixed_ui_english_v17h.ps1
```

The builder uses the existing v16 master and original Japanese source BIN.
It does not rerun v9 or unpack the full translation workspace. It produces a
separate candidate and leaves the inputs unchanged.

For a read-only prerequisite check, add `-CheckOnly`. If files were moved,
use `-MasterBin`, `-SourceBin`, and/or `-UpstreamRoot`. To keep an existing
candidate or put output on another drive, specify a fresh `-WorkRoot` folder.
`CARGO_TARGET_DIR` can place compiler output on another drive. No input-hash
bypass is provided.

## Test the candidate

Use the exact CUE path printed by the recovery runner. Its work-directory name
includes a unique suffix. The standalone builder's default path is:

```text
upstream\work\english-quiz-fixed-ui-v17h\build\justice-gakuen2-quiz-fixed-ui-v17h.cue
```

Open the new CUE in the emulator, then check:

1. English questions and all four answer choices still work.
2. The question heading says QUESTION.
3. One correct answer displays CORRECT! and one wrong answer displays WRONG!.
4. Finishing the quiz displays EXAM OVER.
5. School Gate, the timer, and adjacent graphics still display correctly.

Keep v16 as the recovery fallback while continuing from the played v17h image.
Save the output SHA-256 and `quiz-fixed-ui-v17h-report.json` with test results.
If the build fails, retain `build-v17h.log`; the exact Rust-source backup is
`runtime_bundle_build.pre-v17h.rs.bak` in the selected work folder. A rerun uses
a fresh `-WorkRoot` so previous results are never silently deleted.

## Validation

- The full recovery chain through v16 passed on Windows on 2026-10-25:
  22 outputs matched their saved hashes.
- The subsequent actual v16-based v17h Windows build also passed: 1 build test
  passed, final output verification completed, and 26 raw sectors changed.
  The candidate hash above was reported by both the builder and final check.
  This establishes the built image. The later user report and screenshot
  establish live progression to the post-quiz stat-result screen.

- Recovered v17g Rust test compiled against pinned upstream
  `98ca12ddf082d6e2367b2963f76edf5a09242deb` using Rust 1.98.0.
- v17h asset validation passed against the hash-bound original MGBGK04 archive.
  The changed member occupies 86,044 of 86,620 bytes, leaving 576 bytes in its
  fixed compressed slot. Changes are confined to the four owned graphics cells.
- Compression round-trip and unchanged archive geometry passed. A sentinel
  representing prior work in member 0 survived byte-for-byte.
- Five wrapper regressions passed under PowerShell 7.4.13: wrong master,
  read-only check, insufficient space, existing output, and exact source
  restoration after compiler failure (including BOM and CRLF).
- A full disc fixture build passed: 26 raw sectors changed, all inside
  MGBGK04.BZZ; record readback and image-length checks passed; source code
  restored exactly. This used the verified original disc as the test master
  in a temporary QA copy, not the unavailable translated v16 disc. The
  production script's required v16 hash was not changed.

The v17h Windows build from restored v16 passed, followed by the user's
successful playthrough to the first untranslated stat-result message. Individual
branches and all remaining graphics are not exhaustively verified. The production
v17h builder always enforces the original and v16 hashes.

Run the wrapper regressions without game data:

```text
python tests/test_quiz_builder_preflight.py
```

Set `POWERSHELL` to the executable path if PowerShell is not on PATH.

## Remaining translation work

Address the post-quiz stat-result messages next, then inventory the remaining
reachable School Life dialogue and graphics in source-verified batches.
The current evidence establishes 20 questions in the live MGK04 bank; it does
not establish that every quiz, route, event, or ending has been translated.
The full MGK04/MGK10 source-bound JSON packets remain local and are required
only if rebuilding v15b/v16 themselves. They contain source Japanese text and
are intentionally excluded from this public repository.
