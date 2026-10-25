# Resume from the English quiz

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

## Test this output

```text
upstream\work\english-quiz-fixed-ui-v17h\build\justice-gakuen2-quiz-fixed-ui-v17h.cue
```

Open the new CUE in the emulator, then check:

1. English questions and all four answer choices still work.
2. The question heading says QUESTION.
3. One correct answer displays CORRECT! and one wrong answer displays WRONG!.
4. Finishing the quiz displays EXAM OVER.
5. School Gate, the timer, and adjacent graphics still display correctly.

Keep v16 as the working master until these pass. Save the output SHA-256 and
`quiz-fixed-ui-v17h-report.json` with the test result before promoting it.
If the build fails, retain `build-v17h.log`; the exact Rust-source backup is
`runtime_bundle_build.pre-v17h.rs.bak` in the selected work folder. A rerun uses
a fresh `-WorkRoot` so previous results are never silently deleted.

## Validation

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

These checks do not replace testing the actual translated v16 master or the
native game's rendering. Windows PowerShell 5.1 and in-game testing remain
pending. The production builder always enforces the original and v16 hashes.

Run the wrapper regressions without game data:

```text
python tests/test_quiz_builder_preflight.py
```

Set `POWERSHELL` to the executable path if PowerShell is not on PATH.

## Remaining translation work

After quiz UI validation, inventory the remaining reachable School Life
dialogue and graphics, then work through them in source-verified batches.
The current evidence establishes 20 questions in the live MGK04 bank; it does
not establish that every quiz, route, event, or ending has been translated.
The full MGK04/MGK10 source-bound JSON packets remain local and are required
only if rebuilding v15b/v16 themselves. They contain source Japanese text and
are intentionally excluded from this public repository.
