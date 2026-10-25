# Translation state — 2026-10-25

## Current working input: English quiz v16 restored

On 2026-10-25 the user supplied the complete Windows recovery transcript.
All 22 stages passed. Each reported output hash was compared with the saved
recovery plan; all matched in sequence. The run ended with `V16 RESTORED`.
See [recovery/VALIDATION.md](recovery/VALIDATION.md).

Restored v16 BIN SHA-256:

`67ad4b9d628d0141493a42b456dfd8ce7631d3e9fdd7b2d387ceb84362127a51`

Current recovered CUE:

`C:\Users\Fluent\JG2-Recovery-v1\project\upstream\work\english-live-mgk04-quiz-v16\build\justice-gakuen2-live-mgk04-quiz-v16.cue`

This reproduces the historical v16 image, including MGK04 selector 6's 20
questions and 80 answers, the preceding MGK10 quiz work, and earlier layers.
No v17h output or new in-game result was supplied in this transcript.

From the same extracted recovery kit, run:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\rebuild_quiz_from_original.ps1 -Resume
```

Omit `-StopAtV16` to continue to the candidate. Keep this kit and its
`recovery-plan.json` unchanged: resume binds to their saved identities.

## Next candidate: quiz fixed UI v17h

Builder: `build_quiz_fixed_ui_english_v17h.ps1`

Scope: four graphic areas in `DAT2/MGBGK04.BZZ`, member 2, TIM at `0xE000`:

- QUESTION
- CORRECT!
- WRONG!
- EXAM OVER

The patch starts from v16's current archive, preserves other members including
School Gate, and verifies compression, record readback, disc length, and sector
scope. Its wrapper checks free space and output collisions before any writes,
retains an exact source backup, and restores source bytes after the build.

Status: candidate only. Follow `RESUME_QUIZ.md`; do not promote until the
v16-based v17h build and in-game checks pass.

## Recovered work after the previous repository snapshot

| Version | Purpose | Evidence / limitation |
| --- | --- | --- |
| v6–v7 | NAME and NICKNAME default to A-Z | v7 was promoted in repository history |
| v8 | Five school choices in English | Promoted and recorded as live-tested |
| v9b | Blue greeting title, white body | Recovered builder; final live status not established here |
| v10–v12 | Sex, best subject, favorite words | Recovered builders and later input-hash chain |
| v13–v14 | Enrollment completion, face customization | Recovered builders and later input-hash chain |
| v15b | MGK10 quiz translation | Predecessor required by v16 builder |
| v16 | Live MGK04 quiz translation | Exact historical image restored on Windows; all 22 predecessor/output hashes passed |
| v17g | Fixed quiz graphics | Recovered candidate, not promoted |
| v17h | Fixed quiz graphics with safer build wrapper | New candidate; validation described in `RESUME_QUIZ.md` |

## Last milestone explicitly promoted in the old repository: v8

School-choice UI v8 live-tested BIN SHA-256:

`07b4dda156ab0eac7f149f66f7bcb9727a8e74fad4faa2d19d77cee362504d84`

Local CUE:

`upstream\work\english-name-entry-school-choices-v8\build\justice-gakuen2-name-entry-school-choices-v8.cue`

Confirmed behavior included English enrollment/name-entry controls, native
alphanumeric keyboard, NAME/NICKNAME A-Z defaults, and TAIYO/GORIN/PACIFIC/GEDO/
JUSTICE HIGH choices with crest icons and selection logic preserved.

School descriptors are at `MGENT + 0x15F8`: ten entries, with text in indices
`1, 3, 5, 7, 9`. The crest descriptors remain untouched.

The former greeting-color task is historical. The isolated recovery chain
replays v9b after v8 only as a dependency on the way back to the quiz; do not
overwrite a later existing quiz build with that older layer.
