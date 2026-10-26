# Translation state — 2026-10-25

## Current continuation input: v17h reaches the post-quiz stat results

On 2026-10-25 the user reported that v17h worked and that the first Japanese
they reached was the post-quiz classroom stat-result message. The supplied
screenshot shows the English date and six-stat HUD alongside the untranslated
intelligence-decrease message. This is live evidence for the visited route,
not exhaustive verification of every quiz branch or graphic.

Next: translate the related stat increase/decrease messages and preserve the
native arrows. Run the standalone read-only `probe_stat_results_v18.ps1` to
export the exact original/v17h records. See [STAT_RESULTS_V18.md](STAT_RESULTS_V18.md).
Retain both v17h and v16; keep the recovery kit unchanged.

## Recovered baseline: English quiz v16

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
The original recovery transcript stopped at v16; a subsequent resume transcript
establishes the v17h build below. The later playthrough report is recorded above.

The same recovery kit has now built v17h successfully from this v16 image.
The next action is the stat-result export above. Keep the kit and its
`recovery-plan.json` unchanged: resume binds to their saved identities.

## Built and played: quiz fixed UI v17h

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

The user's Windows resume run completed the v16-based v17h build on 2026-10-25.
Its build test passed (1 passed, 0 failed), and final-output verification completed.

Candidate BIN SHA-256:

`2ff4d83cca04a22a217883ac9c29b3e2fa9c5c4796d9661db3f95d9acd92149a`

Current candidate CUE:

`C:\Users\Fluent\JG2-Recovery-v1\project\upstream\work\english-quiz-fixed-ui-v17h-e380163248384b70a99130d1193c7368\build\justice-gakuen2-quiz-fixed-ui-v17h.cue`

Observed scope: 26 raw sectors changed; member 2 compressed to 86,044 of 86,620
bytes (576 bytes spare). The restored v16 is retained. See
`recovery/VALIDATION.md` for the record.

Status: the user reports successful play through the quiz to the stat-result
screen. Individual QUESTION, correct/wrong, EXAM OVER, timer, and School Gate
checks were not separately enumerated. Continue from this image while retaining
v16 and the remaining regression checklist in `RESUME_QUIZ.md`.

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
| v17h | Fixed quiz graphics with safer build wrapper | Windows build passed; user reports reaching post-quiz stat results successfully; individual branch checks not enumerated |

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
