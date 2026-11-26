## v37 practice / rooftop candidate — 2026-11-06

Issues #022–#025 are implemented in a new candidate based on exact v36: approved Kyosuke loading card, PK Shootout GUTS, shared English pause menus and the reviewed Edge/Daigo rooftop encounter. Rooftop coverage is 53 entries in each player variant (106 coordinates), with choices/outcomes, plus 16 location-label copies in 11 archives. Other rooftop encounters and other loading illustrations remain follow-up work. Read [PRACTICE_ROOF_V37.md](PRACTICE_ROOF_V37.md), [integration validation](validation/practice-roof-v37.json) and [updater validation](validation/practice-roof-v37-updater.json).

Output BIN SHA-256: `66e77edfbb41c7a20255407d5718ad54533f207026c23620c8121fcc38703ffc`. Ten integration checks pass; all 876 catalog signatures match, 921 untouched records remain exact, and all 1,483 changed sectors pass ownership/EDC/ECC checks. Native boot and live tests remain pending. Keep v36; fresh-boot the v37 CUE and use an in-game save. Check all six pause paths and the rooftop branches before closing the issues. PowerShell is reviewed, not executed here; the equivalent Python updater reproduces the exact BIN.

## v36 menu art / Backup candidate — 2026-11-06

Issues #018–#021 are implemented: eight menu-logo cells, 29 Backup messages in each of 78 runtime banks (plus M/D date-unit labels and 25 bundled mirrors), Service Ace record captions and both exam backdrop variants. Uses exact v35; preserves original report sheets/props, live result data, stamps and earlier English. Read [MENU_ART_V36.md](MENU_ART_V36.md) and [validation/menu-art-v36.json](validation/menu-art-v36.json). Native boot and live-screen checks remain pending; keep v35 and fresh-boot the new CUE.

Output BIN SHA-256: `9885ee49e0404d43218b36e7b40b7308a9b7300274e6984f0aa3a260cdba95f1`. All 876 loader bindings match, all 854 untargeted records remain exact, and all 3504 changed sectors passed ownership/EDC/ECC checks. The PowerShell wrapper is reviewed, not executed here; equivalent Python updater verification is recorded separately.

## v35 exam results / ball HUD / dance candidate — 2026-11-06

Issues #013–#017 are implemented in the v35 candidate. It applies to exact v34 and adds exam results/stamps, Explosive Shot HUD lettering, Doki-Waku selector names/schools and four Japanese scrolling captions. Eight integration tests and an updater roundtrip pass; native v35 boot/gameplay remains pending. Read EXAM_DANCE_V35.md and validation/exam-dance-v35.json. Preserve v34 and test via fresh boot with an in-game save.

Output BIN SHA-256: `c25207ba7f18dd73e56f5569d3df7dcdf3d9f92cc605dbbf17692b28a6e9cf8c`. All 876 catalog bindings match; all 934 untargeted records are exact. Decorative exam backdrop text remains original. Do not close issues until Ryan checks the relevant live screens.


## v34 practice layout / exam HUD candidate — 2026-11-06

Current native baseline: Ryan confirmed v33 boot, English title and mode select. v34 addresses issues #001 (points legibility), #008 (Sprint/shared ball-game WIN), #010 (BACK clipping), #011 (practice popup labels/speed markers) and #012 (exam START/FINISH/TASK graphics). Native v34 validation is pending. Read PRACTICE_LAYOUT_V34.md and validation/practice-layout-v34.json. Apply the new updater to exact v33; keep v33 as the boot-tested fallback. Do not close checklist issues until Ryan checks their corresponding screens.


## v33 native boot/title confirmed; collecting next batch — 2026-11-06

Ryan confirms v33 launches and the English title screen works. The supplied mode-select screenshot confirms CURRENT POINTS now fits, but its dense outlined lettering is difficult to read. Issue #001 remains open for legibility; boot blocker #009 is resolved. Continue collecting issues one at a time before preparing another build. Exam/replay/all-route tests remain unconfirmed.


English fan translation of **Shiritsu Justice Gakuen — Nekketsu Seishun Nikki 2**
for Japanese PlayStation, `SLPS-02120`.

**Goal: the whole disc in English, with School Life first.** Japanese voice audio
and game behavior are preserved. Other game modes, help, interfaces, graphics,
bonus material and credits are part of the intended scope.

