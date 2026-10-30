# Translation state — 2026-10-28

## Whole-disc translation programme started — 2026-10-29

Publication boundary: automatic approval review rejected public dialogue-packet
and detailed inventory publication. They and the validation report are saved in
the private JG2-Mainline-Foundation-Batch01.zip checkpoint; public plan/tools are
safe to publish. Do not silently retry the rejected publication.

The user explicitly sets the goal to translate the whole disc, School Life first,
including other modes afterward. Read TRANSLATION_ROADMAP.md, TRANSLATION_STYLE.md
and translation_progress.json before choosing new work. This supersedes the
screenshot-driven patch cadence. Native screenshots guide QA rather than define
every next translation item.

The original-disc structural inventory verified 947 ISO files and all78 runtime
text images:62,639 message coordinates,42,681 raw unique payloads and18,807 exact
glyph/control patterns. These match the pinned upstream structural denominators.
They are not current-English completion percentages or independently reviewed
semantic/reachability counts. Other-mode surfaces have file metadata only so far.

Batch01 is started:46 source-reviewed English prose drafts for4,836 original
dynamic-date coordinates across78 images. This includes the April21 after-school
narration and its separately reviewed player variant. See
the private translations/shared_daily_dates_batch01.json packet in
JG2-Mainline-Foundation-Batch01.zip. Source-fingerprint and protected
control audits pass; five parser regressions and syntax checks pass. Current v25
English overrides must be reconciled before writing anything. Fitting, generic
multi-bank patching, candidate build and native tests remain pending. No v26
exists. Continue that batch; do not redo the inventory or ask Ryan for screenshots
of every untranslated page.

Current built v25 SHA remains
5f31d90f089f520d6824add5c5368e10be2607955ad3b9e5c24b73b9aa010453;
keep v24. Preserve previous successful layers and the original private recovery
inputs. GitHub code/metadata alone does not restore missing ROM/font/codebook/save
inputs. The full plan includes a cumulative original-disc recipe, private-input
backup manifest, clean recovery drill and differential-patch release validation.


## Native route reaches April 21; after-school text/date gap — 2026-10-29

After receiving the actual v25 CUE, the user reports accepting Ran's invitation,
visiting what they believe was the Ferris wheel, then reaching the attached
April 21 classroom screen. The screenshot shows HUD 4/21 WED and English BASEBALL,
but a Japanese in-dialogue date and ordinary after-school narration.
This establishes progression to April21 on the reported route. It does not
separately establish v25 School Gate/Plaza or suffix rendering, all field-trip
branches, or which exact ride occurred. Loaded disc identity is not independently
visible in the screenshot; actual built v25 remains
5f31d90f089f520d6824add5c5368e10be2607955ad3b9e5c24b73b9aa010453.

Next scope: trace the ordinary April after-school scene's active bank and entry,
translate the surrounding daily-school sequence and choices, and inventory its
date-message format alongside other ordinary scene banks. The v24 date sweep
covered 25 MGG event banks; it was not a complete ordinary-scene date sweep.
Do not assume this screenshot's text bank or coordinates until verified against
source/runtime data. Do not change the already-English HUD date. Preserve v25
and its predecessor. No v26 builder or output has been produced yet.


## Actual v25 Windows build passed — 2026-10-29

The user's production v25 passed its Rust test (1 passed, 0 failed, 496.09 seconds)
and final PowerShell output verification. Actual output BIN SHA-256:
` 5f31d90f089f520d6824add5c5368e10be2607955ad3b9e5c24b73b9aa010453 `.
Changed raw sectors: 23,126. All 100 honorific insertion strings across 25 event
banks localized. Enrolled names and relationship-based name selection preserved.
Matching location strips translated and existing English strips preserved.
The console did not include per-label counts; the detailed JSON was not attached.
Do not use the original-disc fixture's location counts as production counts.
Unused-import/dead-code warnings did not prevent successful completion.

CUE to test:

```text
C:\Users\Fluent\JG2-Recovery-v1\candidates\locations-names-v25-8ef409d5d481430d84ba83b3b08c64a1\build\justice-gakuen2-locations-names-v25.cue
```

Keep v24. Fresh-boot this v25 CUE in DuckStation and check School Gate and Plaza,
Hinata/Ran addressing O without Japanese suffixes, and dialogue continuing normally
after each inserted name. Native v25 gameplay remains pending. Unmatched graphics,
other scene banks and untranslated later stories remain outside scope.
See validation/locations-names-v25-windows.json for actual console evidence.


## v25 locations and English name insertions candidate ready — 2026-10-29

Read LOCATIONS_NAMES_V25.md and use build_locations_names_english_v25.ps1 against actual v24 c21d3d0a6ffdfc3d4a666251f450edbc5b68f16b90716101143d2c69e2415e4f. It makes a fresh candidate. Keep v24.

Four renderer-owned honorific messages (selector2 entries5–8: kanji kun, katakana kun, san, chan) become valid empty end-terminated insertions in25 MGG event banks and their five loaded bundles. Relationship controls and enrolled names are preserved; natural English addresses use the name alone. Known location strip fingerprints are matched across48 MGBG archives; existing English strips are preserved and unmatched labels remain outside scope.

The direct Rust full original-disc fixture passed in886.39 seconds:100 honorific entries,394 location copies across43 archives,28886 changed raw sectors. Readback, sector ownership, native EDC/ECC and unchanged input identities passed. Representative School Gate/Plaza/park labels were visually reviewed and empty insertion payloads read back. Nimbus Sans substituted for Arial; only QA master identity changed. This fixture lacks prior English layers, so production counts will differ and actual v24 compression profiles still require the Windows build. Source restored exactly. Static wrapper/source checks pass; PowerShell runtime/native v25 tests remain pending. See validation/locations-names-v25.json. Allow several minutes for the broader compression sweep.


## v24 native field-trip opening reached; location/suffix gaps — 2026-10-29

User screenshots show Taiyo April16 field-trip dialogue in English at entries348,
352 (Hinata) and366 (Ran); BASEBALL HUD remains English. This establishes the
visited opening only, not completion of the field trip or its choices/title-card checks.
Working candidate actual v24 SHA c21d3d0a6ffdfc3d4a666251f450edbc5b68f16b90716101143d2c69e2415e4f.

Remaining Japanese shown:
- School Gate `校門前` in the field-trip departure background.
- Plaza `広場` in the amusement-park background.
- Hinata's inserted name `Oクン` and Ran's `O君`: both are the kun honorific,
  coming through preserved native name controls, not part of the enrolled O.

Next fix should sweep remaining location strips/copies and inspect the shared
name insertion producer for honorifics. Preserve enrolled name, relationship
selection, speaker style and other name behavior. Do not blindly remove controls
or overwrite shared glyphs. The prior name-width guard only bounded inserted
text; it did not prove English suffix rendering. Source-bound runtime suffix
localization or supported per-message insertion adaptation needs verification.
Do not claim v25 exists yet.


## Actual v24 Windows build passed — 2026-10-29

User's actual v24 build passed one Rust test (zero failures,213.44 seconds) and
final PowerShell verification. Output SHA-256: `c21d3d0a6ffdfc3d4a666251f450edbc5b68f16b90716101143d2c69e2415e4f`.
Changed raw sectors:10,137. 430 field-trip messages,1550 event-date formats and
43 title copies patched; the five earlier English entrance-ceremony copies were
preserved. The compiler warnings did not prevent successful completion.

CUE to test:

```text
C:\Users\Fluent\JG2-Recovery-v1\candidates\field-trip-dates-v24-0fd1c9c115b9475891766ead046da4ae\build\justice-gakuen2-field-trip-dates-v24.cue
```

Keep v23. Fresh-boot v24 and check April16 title, opening date/dialogue, and
field-trip branches. Native v24 gameplay is still pending. Later stories and
other schools' story prose remain outside scope. Actual console evidence is in
validation/field-trip-dates-v24-windows.json; do not confuse the local fixture hash
with this production output. Detailed Windows JSON report was not attached.


## v24 field trip and event dates candidate ready — 2026-10-29

Read FIELD_TRIP_DATES_V24.md and run build_field_trip_dates_english_v24.ps1 from actual v23 (9329e5a8ed0c1270fa090f015a4a833ee4b00f120ec884b3f079d67d619fd4f1). The complete direct-Rust full-disc fixture passed: 430 field-trip messages, the spring-trip opening, 1550 date formats in 25 event banks, and all 19 inventoried event/exam cards (48 original references; existing English April8 copies preserved on production). Final visual check passed after removing horizontal clearing bands. All changed records and sector checksums read back correctly; fixture changed10857 sectors. Windows/native v24 tests remain pending. Keep v23. Japanese prose attached to other dates, other schools' story dialogue and later events remain untranslated. See validation/field-trip-dates-v24.json for fixture/font/hash-guard limits. Native title-card style uses source-colored clearing panels and rainbow/white English.


## v23 native baseball route passed; April 16 field trip is next — 2026-10-29

User reports getting through all baseball joining dialogue and reaching April 16.
Screenshots show the BASEBALL HUD label in English and continued gameplay into
April 16. This validates the visited baseball route, not all eight clubs or both
player variants. Keep actual v23 SHA-256
`9329e5a8ed0c1270fa090f015a4a833ee4b00f120ec884b3f079d67d619fd4f1`.

First screenshot: graphic title card `4月16日 / 遠足` = APRIL 16 / FIELD TRIP.
Second screenshot: dialogue date `4月16日`, then `今日は、春の遠足だ。` =
Today is the spring field trip. The HUD date already reads 4/16 FRI.
These are separate title graphics and dialogue date/text layers.

User requests a comprehensive sweep of date screens, not only April 16.
Next patch scope should inventory event title/date cards across the disc and
all dynamic dialogue date templates, preserve existing English HUD dates,
and translate the complete Taiyo spring field-trip event and branches.
Do not claim all date screens fixed until this inventory and build validation
are complete. No v24 patch has been built yet. Source-bank field-trip opening
is expected just after entry 347; verify exact coordinates from source.


## Actual v23 Windows build passed — 2026-10-29

The user's v23 build passed one Rust test (zero failures) and final PowerShell verification.
Actual output SHA-256: `9329e5a8ed0c1270fa090f015a4a833ee4b00f120ec884b3f079d67d619fd4f1`.
Changed raw sectors: 245. Text compression: 225,312 / 225,706 bytes.
Shared arena: 61,672 / 102,368 bytes; 623 shared message references.
342 remaining club tutorial/joining entries, nine HUD club labels and the secondary
Club Building location label installed. Earlier/untargeted layers and MGAME verified preserved.

Actual CUE:

```text
C:\Users\Fluent\JG2-Recovery-v1\candidates\club-join-v23-40f8384b526946e4835840503771845e\build\justice-gakuen2-club-join-v23.cue
```

Keep v22. Fresh-boot this CUE and test Club Building, baseball selection and HUD,
remaining tutorial and farewell. Native v23 gameplay remains pending.
See `validation/club-join-v23-windows.json`; the local fixture remains separate.


## v23 club joining candidate ready — 2026-10-29

Read CLUB_JOIN_V23.md. The user reached Taiyo club selection in v22 and joined baseball; Japanese begins at the remaining tutorial farewell (entry 179). v23 translates selectors 0/1 entries 177–347 (342 messages), nine shared club HUD labels, and the missed secondary Club Building TIM in graphics member 3. The direct Rust full-disc fixture passed (1 test, zero failures); actual Windows and native testing remain pending. Keep actual v22 b21934066fc21a217ce5c37772abd53b81e881706d685bd10dc349cc0f8be95e. Run build_club_join_english_v23.ps1 to create a fresh candidate. Later field-trip scenes and other schools are outside scope.


## Actual v22 Windows build passed — 2026-10-28

The user's production builder passed its Rust test (1 passed, 0 failed) and
final PowerShell verification. Actual output BIN SHA-256:
`b21934066fc21a217ce5c37772abd53b81e881706d685bd10dc349cc0f8be95e`.

The build changed 1,232 raw sectors. Dialogue uses 225,304 / 225,706 compressed
bytes; the shared text arena uses 69,896 / 102,368 bytes, with 502 duplicate
message references shared. The shared header uses 75,818 / 77,342 bytes.
The report confirms 240 story entries, four menu-help entries, all seven
location-label groups, and preservation checks. Actual Arial font SHA-256:
`b3658eadae55e682b5f69eb64c439c1ecc8f196c0bb8d4756d145d13bc86476a`.

CUE to test:

```text
C:\Users\Fluent\JG2-Recovery-v1\candidates\pool-club-v22-6fee622ae48d460093e6ce45ca87e084\build\justice-gakuen2-pool-club-v22.cue
```

Keep v21. Boot this CUE fresh in DuckStation, check the daily menu, pool
conversation, both club-selection pages and choice columns, then join a club
and test the training tutorial. Native v22 gameplay is still pending.
The original compiler unused-import warnings did not prevent the successful
build. See `validation/pool-club-v22-windows.json` for the actual production
report; `validation/pool-club-v22.json` remains the separate local fixture.


## Pool/club and daily menu v22 candidate — 2026-10-28

Continue from actual v21 BIN SHA-256
`f4a470836cded402c5ec5df041f0023693099761f1a25cd1045690d8bae005f0`.
The user confirmed the ceremony apology route reached the pool and said the
stored name was probably O. Do not alter name handling for that observation.
Keep v21 as the visited-route checkpoint and v20 as another fallback.

Read [POOL_CLUB_V22.md](POOL_CLUB_V22.md). The new candidate translates Taiyo
selectors 0/1 entries 57–176 (240 story entries), selector 2 menu-help entries
52–55, shared CONTINUE/MOVE/STATUS/DIARY graphics, and matching April location
labels. It covers the pool introductions, all eight clubs and the go-home
option, club selection, and the training tutorial. Windows v22 build passed; native v22 tests
remain pending; later April events and other school dialogue remain Japanese.

The v22 arena shares identical payloads through native message pointers. Future
patches must use the pointer-aware reader in `patches/pool_club_v22.rs` (or the
inspection helper) on v22 output; upstream's contiguous-bank parser rejects
aliases. Native pointer-load and end-termination instructions are guarded.
All earlier and untargeted payloads, scripts, graphics, and other school
members are verified unchanged. Five records are owned; MGAME changes only
its 72-byte action-label spacing block at +0x19454.

Local PowerShell execution was blocked by automatic review over a Visual Studio
telemetry connection. No wrapper runtime pass is claimed. Validation uses
direct Rust execution, offline wrapper consistency checks, and actual saved
MGAME/MGCOCK shared records inside a clearly identified disc fixture.
See `validation/pool-club-v22.json` for final local results and limits.

## v21 live playtest: apology route reaches pool conversation — 2026-10-28

The user reports Batsu and the rest of the ceremony dialogue appeared in English,
selected the apology response, and continued through the ceremony into the club
orientation transition. Screenshots directly show English dialogue at entries
3 (Batsu calling the inserted name), 45 (after being told off), and 55 (ceremony
over / joining a club). The following screenshot is the untranslated pool
conversation at entry 57. This is the expected end of v21's text scope.

Retain the actual v21 build with SHA-256
`f4a470836cded402c5ec5df041f0023693099761f1a25cd1045690d8bae005f0`,
plus v20 as fallback. This validates the visited apology route; it does not
establish the teasing branch, other player variant, all prior checks, or the
separately unpictured title/date/location replacements.

Remaining work identified:

- Shared daily action menu: CONTINUE / STATUS / DIARY, with the help text.
- Location graphics: `渡り廊下` (Covered Walkway) and `プールサイド` (Poolside).
- Taiyo pool/club-orientation dialogue starting at selectors 0/1 entry 57.
- Check the yellow O/0 shown in the HUD and Batsu's inserted name. It appears
  to be the stored player name, but the intended enrolled name is not yet known.
  Do not patch the character-name data based only on that visual inference.

## Actual v21 Windows build passed — 2026-10-28

The user's production v21 run passed one Rust test (0 failures) and every final
PowerShell output check. Actual BIN SHA-256:
`f4a470836cded402c5ec5df041f0023693099761f1a25cd1045690d8bae005f0`.
Changed raw sectors: 1,516. Dialogue compression: 225,290 / 225,706 bytes.
114 dialogue entries and four dynamic date messages were installed, along with
five title-card copies, six School Gate copies, and three Gym copies.

CUE to test:

```text
C:\Users\Fluent\JG2-Recovery-v1\candidates\entrance-ceremony-v21-b7a5cc0526a848acbfc2038e1f80067a\build\justice-gakuen2-entrance-ceremony-v21.cue
```

Next: boot this CUE fresh, replay the quiz, and check the April 8 title/date,
Taiyo ceremony dialogue, player-name insertion, both apology/teasing branches,
Ran's introduction, and transition toward club orientation. Keep v20 until
that native check passes. The Windows build is verified from the supplied log;
no v21 gameplay evidence has yet been received. Later club events and other
schools' ceremony dialogue remain untranslated.

## v20 reached April 8; next candidate is Taiyo ceremony v21 — 2026-10-28

The user's actual Windows v20 build passed its test and final checks:
`bf79b70fb5d806669fbf48917c634920e1934ff63d82072b9a0a48ab63238fec`.
It changed 13 sectors and used 86,044 / 86,620 bytes in the quiz graphics member.
The user then reported completing the quiz and supplied screenshots of the pink
April 8 entrance-ceremony card and the following school exterior/date message.
This establishes progression along the tested route; individual quiz branches
and all earlier classroom/stat-message checks are not separately enumerated.

Actual v20 CUE:

```text
C:\Users\Fluent\JG2-Recovery-v1\candidates\rating-popup-v20-dc07cc86a1334a718dfd03c037468812\build\justice-gakuen2-rating-popup-v20.cue
```

Continue from that exact v20 with [ENTRANCE_CEREMONY_V21.md](ENTRANCE_CEREMONY_V21.md).
The new scene candidate covers 114 Taiyo dialogue entries across both player
variants, apology/teasing branches, four dynamic date messages, the title card,
and matching School Gate/Gym labels. It reaches Ran's introduction and the
opening transition toward club orientation. Later club scenes and other
schools' ceremony dialogue remain Japanese. The complete local fixture builder and
eight wrapper tests passed; see `validation/entrance-ceremony-v21.json`.
The later Windows build above passed; native v21 checks remain pending.

Runtime ownership: MGG04T.BIZ is member 0 of the loaded MGG04.BZZ bundle;
both must be updated. Graphics are in MGBGG04.BZZ. Ceremony messages are
selectors 0/1 entries 0–54; 55–56 begin the orientation transition, and 57 onward
starts the pool/club sequence. Date-only messages are selectors 3/4 entries
18/19. Do not overwrite shared month/day glyphs. The English packet, Rust
template, assembly script, builder, and tests are committed for recovery.

## v19 Windows build succeeded; next target is the rating popup

The user's actual Windows v19 build passed its Rust test and final verification.
BIN SHA-256: `0b378dd421323c6248307013ef185270ea581964d34cd7ab52826eb8b6e412f2`.
It changed 66 raw sectors; classroom member size is 172,054 / 173,606 bytes,
with 11px text. The actual CUE is:

```text
C:\Users\Fluent\JG2-Recovery-v1\candidates\classroom-label-v19-f025cc6ac36c4d4f94e886d4fa730ef6\build\justice-gakuen2-classroom-label-v19.cue
```

The next quiz screenshot confirms that the English `CORRECT!` stamp appears.
It also shows a separate rainbow `評価UP` popup (Rating Up) still in Japanese.
The screenshot does not establish which disc was loaded, does not show the
classroom banner, and does not validate the post-quiz stat-result text.
Do not mark those separate native checks as passed.

Continue with [RATING_POPUP_V20.md](RATING_POPUP_V20.md), using the exact v19
image as input and retaining it. v20 addresses only the rating popup. Keep the
original recovery kit and its private translation packets unchanged.

## Earlier checkpoint: CLASSROOM location banner v19

The v18 Windows build passed. The user then pointed out `教室` (Classroom)
beneath the stat HUD in the pre-quiz classroom. This is a separate graphic;
that screenshot does not show or validate the v18 stat-result messages.

`build_classroom_label_english_v19.ps1` changes only the classroom location
strip in MGBGK04 member 1, preserving the background, portraits, School Gate,
quiz graphics, and v18 text bank. It starts from the exact v18 hash below and
creates a separate candidate. Read [CLASSROOM_LABEL_V19.md](CLASSROOM_LABEL_V19.md)
for build instructions, evidence, and the native-test checklist. The record patch,
eight wrapper tests, and full disc fixture passed. The actual Windows build
subsequently passed as recorded above; native checks remain pending. Keep v18.

## Built on Windows: MGK04 stat results English v18

The user's private stat-record export has been received and verified. The new
`build_stat_results_english_v18.ps1` translates selector 2 entries 34–51 in
MGK04: nine stat increases and nine decreases. It retains the native arrows,
game logic, all 100 quiz entries, and earlier layers. It starts from exact v17h
and creates a separate candidate without changing the recovery kit.

The actual record patch, rendered text layout, six wrapper regressions, and
full disc-fixture build passed. Compressed MGK04 occupies 206,858 / 207,226 bytes.
Patched record SHA-256:
`91ca0e81829fb578d41797854718590e0f05e29b1325b6a1675e9df3a4584fa0`.

The user's Windows run passed its build test and final checks: 18 messages,
71 changed sectors, and 206,858 / 207,226 compressed bytes. Actual output SHA-256:
`d720ea2ae3c2c1c52981b0536642b836ec8e2151c6e94b658abdd1a49e094068`.
Native stat-message validation is still pending; continue with the v19 banner
candidate and check both together. Retain v18, v17h, and v16.
See [STAT_RESULTS_V18.md](STAT_RESULTS_V18.md).

## Current continuation input: v17h reaches the post-quiz stat results

On 2026-10-25 the user reported that v17h worked and that the first Japanese
they reached was the post-quiz classroom stat-result message. The supplied
screenshot shows the English date and six-stat HUD alongside the untranslated
intelligence-decrease message. This is live evidence for the visited route,
not exhaustive verification of every quiz branch or graphic.

The related stat-message patch is now prepared from the completed private
export; see the v18 candidate section above.
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
The next action is the v20 rating-popup candidate above. Keep the kit and its
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
| v18 | MGK04 stat increase/decrease messages | Actual Windows build and final verification passed; native stat-message test pending |
| v19 | CLASSROOM location banner | Candidate prepared from exact v18; Windows build and live test pending |

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
