# Translation state — 2026-10-25

## Current blocker: v16 was not found under Downloads

The user subsequently reported deleting the local project and recovered only
`justice-gakuen2-name-entry-school-choices-v8(1).cue`. Its entire payload is a
single-track descriptor referencing `justice-gakuen2-name-entry-school-choices-v8.bin`.
The CUE contains no disc sectors or translated assets and cannot establish that
the matching BIN survived. Verify an actual BIN before choosing a resume point.

The user's scan found only the original Japanese image with SHA-256
`0fce6eda2082d91af5a963c73fbf80a7935b1ebd5446dff5d01e548370fabe8e`.
The default v16 path is missing. This does not establish that every other drive
was searched or that all old builds were deleted. Do not send the v17h-only
command again until v16 is located or rebuilt.

The saved Batsu bootstrap workspace and both quiz translation packets have been
recovered. `recovery/` assembles a private Windows kit that rebuilds the historical
chain in a new directory, checks every output hash through v16, and then invokes
v17h. See `recovery/RECOVERY_README.txt`. Full Windows rebuild and play testing
remain pending; no new game image has been promoted.

## Active resume target: English quiz v16

The user confirmed successfully reaching the English quiz. Saved builders
identify the next input as the v16 live MGK04 quiz build. This establishes the
resume target, while the local file must still pass the exact hash check.

Required v16 BIN SHA-256:

`67ad4b9d628d0141493a42b456dfd8ce7631d3e9fdd7b2d387ceb84362127a51`

Default local BIN:

`upstream\work\english-live-mgk04-quiz-v16\build\justice-gakuen2-live-mgk04-quiz-v16.bin`

The recovered v16 builder translates MGK04 selector 6: 20 questions and 80
answers. It builds from v15b, preserving the preceding enrollment and face
customization layers. This is one quiz bank, not proof of complete game coverage.

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

Status: candidate only. Follow `RESUME_QUIZ.md`; do not promote until the actual
v16 build and in-game checks pass.

## Recovered work after the previous repository snapshot

| Version | Purpose | Evidence / limitation |
| --- | --- | --- |
| v6–v7 | NAME and NICKNAME default to A-Z | v7 was promoted in repository history |
| v8 | Five school choices in English | Promoted and recorded as live-tested |
| v9b | Blue greeting title, white body | Recovered builder; final live status not established here |
| v10–v12 | Sex, best subject, favorite words | Recovered builders and later input-hash chain |
| v13–v14 | Enrollment completion, face customization | Recovered builders and later input-hash chain |
| v15b | MGK10 quiz translation | Predecessor required by v16 builder |
| v16 | Live MGK04 quiz translation | User reports English quiz playable; next builder checks exact BIN hash |
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
