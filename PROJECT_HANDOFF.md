# Project Handoff — Read This First

## v26 shared dates and daily narration ready for Windows build — 2026-10-30

Run build_shared_dates_english_v26.ps1 against actual v25
5f31d90f089f520d6824add5c5368e10be2607955ad3b9e5c24b73b9aa010453.
Download the private JG2-Shared-Dates-v26-Inputs.zip from the conversation into
Downloads; leave it zipped. The standalone builder locates it and checks the
packet member SHA-256 714f77e8112daed6585e5912a5e312b8093229bbd13ad1cce9fdafb521cebfa6.
It also accepts -PacketPath with the ZIP or exact JSON. No dialogue is embedded
in the public builder. Read SHARED_DATES_V26.md.

The original-disc full fixture passed in131.08 seconds:78 banks,4836 date/narration
coordinates,46 native-glyph previews,10761 changed raw sectors, all pointer/record,
compression-slot, ownership and EDC/ECC checks. QA fixture output SHA-256
4c02ebabd9e569fe96f5ada6bb38ab206c777d4ff1f27a5ca3a7cc56c827201a
is NOT the production hash. Nimbus Sans substituted for Arial and only the QA
master guard changed; production requires exact v25. Current v25 compression and
preservation counts still require the actual Windows run.

A separate mixed source/slash/custom-payload regression passed in3.26 seconds:
custom payload retained byte-for-byte;61 other date slots translated.
Five offline wrapper regressions passed; PowerShell was not locally executed.
Both test invocations restored the exact original upstream Rust source.

All46 bitmap previews were inspected for four-row/20-cell fit. Preview MM/DD
illustrates dynamic two-digit dates, not literal text installed instead of digits.
Native date controls and palette arguments remain unchanged. Other payloads,
fonts except new empty glyph cells, scripts, HUD and graphics are preserved.
Existing current custom date prose is retained and counted separately; source
separator-only changes are eligible for upgrade.

No actual v26 Windows hash/CUE or native v26 pass exists yet. Keep v25, build a
fresh v26 candidate, then fresh-boot it using an in-game save. Check April21
opening/date, seasonal or exam text and an earlier custom translated event.
This batch does not translate subsequent unique story dialogue.
Continue with shared daily interfaces and coherent story packages from the
whole-disc roadmap. Detailed private input/QA is in JG2-Shared-Dates-v26-Inputs.zip;
public validation summary is validation/shared-dates-v26.json.


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


This file is the continuity document for future ChatGPT sessions working on this project.

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

## v18 Windows build and v19 classroom continuation — 2026-10-26

The user's v18 Windows build passed its test and final output checks. Actual
BIN SHA-256: `d720ea2ae3c2c1c52981b0536642b836ec8e2151c6e94b658abdd1a49e094068`.
It changed 71 sectors and translated 18 messages in MGK04. The next screenshot
is the pre-quiz classroom; the user points to `教室` below the stats. It does
not show the new stat messages, so do not promote them as native-validated yet.

The v19 builder changes this classroom banner in MGBGK04 member 1 to CLASSROOM.
It preserves the background, portraits, other members, and MGK04 text. It finds
the exact v18 candidate automatically. Read `CLASSROOM_LABEL_V19.md` for the
implementation and validation status. Next: Windows v19 build, fresh boot,
classroom banner check, then quiz and v18 stat-result checks. Keep all baselines.

## v18 candidate prepared — 2026-10-26

The actual stat-probe ZIP has been received and its eight record hashes verified.
`build_stat_results_english_v18.ps1` is ready: MGK04 selector 2 entries 34–51
become 18 English stat messages. It uses compact labels made from the current
English font, keeps both native palette controls and padding controls, and
preserves the shared MGAME arrow table rather than changing other scenes.

The actual record build, text-layout inspection, six wrapper regressions, and
a complete disc-fixture build passed. The fixture changed 71 sectors inside
MGK04 only. Tested replacement record SHA-256:
`91ca0e81829fb578d41797854718590e0f05e29b1325b6a1675e9df3a4584fa0`.
It uses 206,858 / 207,226 compressed bytes. All 100 quiz payloads are unchanged.

The later Windows build is recorded above and supersedes the earlier build-pending
status. Read `STAT_RESULTS_V18.md`; its validation section distinguishes actual
records, the synthetic whole-disc fixture, and the successful user build.

## Live continuation — 2026-10-25

The user reported v17h working through the quiz and supplied a screenshot of the
first remaining Japanese: the post-quiz intelligence-decrease message. The date
and stat HUD are English. Continue from v17h, retain v16, and address the paired
stat-result messages next. This report does not enumerate every quiz branch.

`probe_stat_results_v18.ps1` is a standalone read-only export, with seven passing
synthetic tests. It reads four records from each verified original/v17h image
and writes a private ZIP for the user to attach in the conversation. It does
not edit or rebuild anything in the recovery project. Read `STAT_RESULTS_V18.md`.
That export is now complete; the 2026-10-26 update above supersedes this earlier
export-waiting checkpoint.

## Recovery completed — 2026-10-25

The full Windows recovery run completed all 22 stages and restored v16 with
SHA-256 `67ad4b9d628d0141493a42b456dfd8ce7631d3e9fdd7b2d387ceb84362127a51`.
Every reported stage hash matches the recovery plan. The original missing-image
blocker is resolved. The v8 CUE alone was insufficient; the recovered builders,
workspace and quiz packets rebuilt the translated disc from the original.

Current project: `C:\Users\Fluent\JG2-Recovery-v1\project`.
The extracted kit is `C:\Users\Fluent\Downloads\JG2-Recovery-Kit-v1`.

The subsequent Windows `-Resume` run successfully built v17h from this exact v16.
Candidate BIN SHA-256: `2ff4d83cca04a22a217883ac9c29b3e2fa9c5c4796d9661db3f95d9acd92149a`.
The patch changed 26 raw sectors and its build test passed. The complete CUE
path and in-game checklist are in `RESUME_QUIZ.md`.

Keep the kit, its plan/scripts, and
v16 unchanged; the recovery runner checks their saved identities on resume.

The source checkpoints, predecessor builds, and original input are retained.
v17h remains a separate image. Its Windows build and the user's subsequent
playthrough to the post-quiz stat screen are recorded; individual graphic/branch
checks have not all been separately reported.
The validation record is in `recovery/VALIDATION.md`.

Source-bound workspace ZIP/JSON stays outside public Git. No original game
disc, font, rebuilt image, or extracted workspace is included in this repository.

## Resume update — 2026-10-24

Read `CURRENT_MILESTONE.md` and `RESUME_QUIZ.md` before selecting an input build.
The user reports successfully reaching the English quiz. The active target is
v16, with a required input SHA enforced by `build_quiz_fixed_ui_english_v17h.ps1`.
The v5/v6 status sections and nickname task below are historical notes, not the
current starting point. Twelve later build scripts have been recovered into
this repository. At that earlier checkpoint, v17h still required a build on the
actual v16 master and in-game validation. The 2026-10-25 updates above supersede
that status.

Do not run the older v9 greeting rebuild over the later quiz work. A saved
attempt exhausted disk space during full workspace extraction. The v17h quiz
builder checks space first and patches only the relevant graphics member;
it does not extract the full translation workspace.

## Project

English fan translation / reverse-engineering of:

**Shiritsu Justice Gakuen - Nekketsu Seishun Nikki 2 (Japan)**  
Game ID: `SLPS-02120`

The goal is a complete English School Life / dating-sim mode while preserving Japanese audio and original game behavior as much as possible.

## Collaboration style

Work incrementally and prove each layer before moving on.

The preferred loop is:

1. Probe the original/runtime data.
2. Identify the exact producer/consumer or owned graphic cell.
3. Build one isolated patch.
4. Verify source hashes before writing.
5. Verify readback and changed-sector scope afterward.
6. Test in-game.
7. Promote the build only after live validation.
8. Commit successful scripts/docs to Git.

Avoid speculative edits, broad binary rewrites, or manual Rust edits when a source-verified scripted patch can be made instead.

When something fails, diagnose the **first actual error** and provide a corrected one-run PowerShell script.

## Local layout

Project root:

`C:\Users\Fluent\JG2-Recovery-v1\project`

Pinned upstream checkout:

`C:\Users\Fluent\JG2-Recovery-v1\project\upstream`

Source ROM folder:

`C:\Users\Fluent\Downloads\Shiritsu Justice Gakuen - Nekketsu Seishun Nikki 2 (Japan)`

Original BIN filename:

`Shiritsu Justice Gakuen - Nekketsu Seishun Nikki 2 (Japan).bin`

Original SHA-256:

`0fce6eda2082d91af5a963c73fbf80a7935b1ebd5446dff5d01e548370fabe8e`

Do not trust the source CUE blindly. It may reference a stale `[SLPS-02120]` filename that is not present. Probes/builders should create or use an explicit CUE against the SHA-verified BIN when necessary.

## Upstream

Repository:

`mcpads/justice-gakuen2-kr-patch`

Pinned commit:

`98ca12ddf082d6e2367b2963f76edf5a09242deb`

The local `upstream/` folder is deliberately ignored by this repo because it is its own checkout.

`SLPS_021.20` matches upstream exactly.

## Git rules

This repository should contain only original project work such as:

- PowerShell builders and probes
- documentation
- checksums
- reports that do not embed copyrighted game data
- original translation/build logic

Do **not** commit:

- ROM/BIN/CUE/ISO/CHD/PBP images
- BIOS files
- generated rebuilt discs
- extracted copyrighted game assets
- emulator saves/states
- Rust `target/`
- `upstream/work/`

The repository is currently public, so err on the side of not committing extracted game text/assets unless they are clearly safe to redistribute.

## Historical milestone

### v5 — live-tested master before behavior patch

SHA-256:

`2fe51561d025cc2ffdface62d1a7e7222a40937bb3b5a97ebc019f8338d43977`

Tag:

`name-entry-v5`

Confirmed working layers include:

- English main mode-select graphics
- School Life `PLAY / LOAD`
- English dialogue glyph support
- playable Batsu-route prototype
- HUD: `ATK / DEF / STAM / GUTS / POT / INT`
- MGK04 opening greeting
- `SCHOOL GATE`
- dynamic date such as `4/1 THU`
- full MGK04 tutorial/admissions dialogue translation layer
- English enrollment form
- English name-entry controls: `HIRA / KATA / A-Z / DEL / NEXT / BACK / OK`
- native `0-9 / A-Z / a-z` keyboard preserved and verified in-game

## Historical candidate

### v6 — default A-Z on first name-entry open

Built from v5.

Output SHA-256:

`e3808a7bef6c6529e45b29963895a6e45a26dd7c30b031be928fcdb4fa98a09f`

Patched MGENT SHA-256:

`93aee308f5db552b97482b5f2c91f95ae2246849965334d5c47b2ecf54d15751`

Patch scope:

- `9` changed bytes in `DAT1/MGENT.BIN`
- `1` raw disc sector changed
- graphics untouched

Live result:

- first entry into NAME now defaults to A-Z successfully
- however, when transitioning to NICKNAME, the game resets the page away from A-Z

Do **not** call v6 the final master yet; this nickname reset is the next behavior fix.

## Name-entry reverse engineering

Overlay:

`DAT1/MGENT.BIN`

Source SHA-256:

`eaf243e2d5a78919055b453611ea8b785766a6dc945966a1d5c0ce166714f70a`

Object fields:

- page index: `+9`
- record slot index: `+10`
- cursor cell: `+12`
- field index: `+15`

Physical pages:

- page `0` = Hiragana
- page `1` = Katakana
- page `2` = Alphanumeric

Native alphanumeric page is exactly 62 selectable glyphs:

- 10 digits
- 26 uppercase
- 26 lowercase

Cold-start page initializer:

- `MGENT + 0x1A5C` originally stores zero to object `+9`
- v6 rewrites the surrounding initializer so it stores `2` while preserving neighboring field initialization and restoring `V0 = 0x0200` before the original later halfword store

Nickname-specific initializer:

- `MGENT + 0x1FA4`: `addiu v0, zero, 1`
- `MGENT + 0x1FA8`: `sb v0, 9(s0)`
- therefore nickname explicitly forces page `1` (KATA)
- immediately afterward, `MGENT + 0x1FAC` reloads `v0 = 2`, so changing only `0x1FA4` from immediate `1` to `2` is the clean next patch

This means the next build should start from v6 and change only the nickname initializer immediate from `1` to `2`, then live-test NAME → FIRST → NICKNAME and page cycling.

## Name-entry fixed graphics

`DAT2/MA_ENT.BIZ`

Application-form TIM starts at decoded offset `0`:

- image x: 512
- image y: 0
- pixel width: 448
- image height: 464
- CLUT: 16×1

Name-entry font/control TIM starts at decoded offset `0x19000`:

- image x: 768
- image y: 0
- pixel width: 768
- image height: 256
- CLUT: 352×1 / 22 palettes

Native control sprite cells:

- `HIRA`: `(560,200)` 48×24
- `KATA`: `(608,200)` 48×24
- `A-Z`: `(656,200)` 48×24
- `DEL`: `(512,224)` 48×24
- `NEXT`: `(560,224)` 48×24
- `BACK`: `(608,224)` 48×24
- `OK`: `(656,224)` 48×24

Adjacent `(704,200)` is reserved for the incomplete-slot cue; do not overwrite it casually.

## Date subsystem

`DAT2/MGCOCK.TIZ` is a 4bpp TIM decoded to 1024×256.

Clean identities:

- decoded SHA: `bc81dda96d98a4ed06b37db9415636430db630d13217d2275059bb306d9fb655`
- stored SHA: `241d3ba8b25aef281c932f9bd64c0ffb84693abf72ad7b1d5cde852d4b655285`
- `DAT1/MGAME.BIN` SHA: `887c7c1775db5a18aed19661a08d109a5f35c54303259b21c7d6560ef1a3baba`

Final live-tested visible format is `4/1 THU`.

Important lesson: visually blank MGCOCK cells may be shared. Do not modify a cell merely because it looks unused; one earlier blank-cell experiment corrupted the stat HUD.

## School Gate layer

Opening location `校門前` maps to MGBG catalogue member 6.

Runtime consumers discovered:

- `DAT2/MGBGE03.BZZ` members 4 and 12
- `DAT2/MGBGK02.BZZ` member 26
- `DAT2/MGBGK04.BZZ` member 0

Fit-corrected live-tested build SHA was:

`a2e1587b828d5508a5dc99e4e64020d0a16fb4a8d0a569d3e8ddffccff0d98d1`

## MGK04 tutorial layer

Full tutorial/admissions translation v3 was live-tested and became the master before name entry.

SHA:

`30cdcc7cdbc1a21818b65272ac50e7baebc245f0505c83d03dfb2c00db713ac4`

58 semantic groups were authored. The patch replaced only `DAT2/MGK04.BIZ` and verified readback.

## Build discipline

Every production builder should, where practical:

- verify the exact input master SHA
- verify the exact source record SHA
- verify exact source instructions/cells before patching
- fail before writing if the source does not match expectations
- touch only the intended record(s)
- compare output disc sectors to ensure changes are inside owned records
- verify disc length is unchanged
- re-read the patched record from the rebuilt disc and compare bytes/hash
- print the output SHA, changed-sector count, and CUE path

A build is only a candidate until live-tested.

## How to resume in a future chat

A future assistant should begin by reading:

1. `README.md`
2. `CURRENT_MILESTONE.md`
3. `PROJECT_HANDOFF.md`

Then verify the newest live-tested master before making a new patch.

Do not assume the newest generated build is promoted merely because it compiled.

The original handoff's v6 nickname task is superseded by the recovered v7
builder. The current task is native testing of the built v21 ceremony candidate described
at the top of this file and in `ENTRANCE_CEREMONY_V21.md`.
