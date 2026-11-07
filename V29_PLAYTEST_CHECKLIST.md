# Translation playtest checklist — v29 onward

Running list of Japanese text and other issues reported during testing from recovered v29 onward. Record observations separately from implemented fixes and native validation.

## 001 — School Life 2 mode-select points label

- Reported: 2026-11-06.
- Build under test: recovered v29 (BIN SHA-256 `f4f974c40220dd82925d4b17d6a31b3f95218a6017783666851204ea3040c67f`), per the current playtest context; screenshot alone does not prove disc identity.
- Location: opening MODE SELECT menu, SCHOOL LIFE 2 selected; bottom-right yellow information panel, bottom-left red label beside `0 PTS`.
- Visible Japanese: `現在のポイント`.
- Meaning / proposed English: `CURRENT POINTS` (subject to graphic fit).
- Evidence: user-provided mode-select screenshot. Main description and SCHOOL LIFE 2 title are already English; this points label remains Japanese.
- Status: OPEN — v33 native screenshot confirms the entire English label fits, but CURRENT POINTS is cramped and hard to read. Improve lettering legibility in the next batch.
- Follow-up confirmation (2026-11-06): user supplied another mode-select screenshot circling the same red label after the v30 practice batch was delivered. It is the existing issue #001, not a new issue. Exact running disc version is not established by the screenshot. This surface was outside v30's practice-interface scope.
- Next investigation: identify the label's source graphic and all shared consumers before patching; preserve the points value and menu behavior.

- v31 scope: source-bound 80×24 label cell replaced with CURRENT / POINTS; dynamic score remains untouched.

- Native progression: v31 CURRENT / POINTS had bottom clipping; v32/v33 single-line label fits the visible area. Ryan reports v33 label is hard to read; the attached screenshot confirms dense outlined lettering. Next revision should use simpler pixel lettering with clear spacing and verify at native resolution. Keep collecting reports before building the next batch.

## 002 — Fiery Sprint practice screen remains Japanese

- Reported: 2026-11-06, during the recovered-v29 playtest.
- Reproduction: Diary → MINIGAME PRACTICE → FIERY SPRIN.
- Screenshot context: practice selection on April 16, Friday; then the sprint practice landing screen.
- Observed untranslated surfaces: large title, practice stamp, coach speech bubble, START / RULES AND CONTROLS / BACK menu, and current-best-record caption.
- Suggested menu English: `1P START`, `RULES & CONTROLS`, `BACK`; practice stamp: `PRACTICE`; record caption: `CURRENT BEST`.
- Coach speech meaning: approving the choice to practice and telling the player to practice thoroughly to avoid failing in the real event. Final English wording and fit remain to be authored.
- Status: IMPLEMENTED IN v30 CANDIDATE — native validation pending; see PRACTICE_V30.md.
- Follow-up scope: audit all six minigame practice landing screens and their rules/control pages as one interface batch. Only the Fiery Sprint landing screen is confirmed by these screenshots; other minigames and deeper rules/gameplay screens remain unchecked.
- Preserve minigame behavior, controls, best-record values and save data. Do not conflate this practice landing screen with the separately tracked practical-exam instruction artwork.

## 003 — Fiery Sprint selection label omits final T

- Reported: 2026-11-06.
- Location: Diary → MINIGAME PRACTICE, top-left choice.
- Visible label: `FIERY SPRIN`.
- Intended English: `FIERY SPRINT`.
- The lower help text already displays `FIERY SPRINT` in full. The selected label is missing only the final T; whether the graphic itself omits it or the draw region clips it is not established.
- Status: IMPLEMENTED IN v30, RETAINED IN v31 — native validation pending.
- v30 candidate: full wording fitted within the native 144-pixel consumed strip; awaiting in-game confirmation.
- Fix target: fit the complete title cleanly within its menu row, then verify selected and unselected rendering. Use the spelling `FIERY`; “Firey” in the user report is not the spelling shown in the screenshot.

- v31 retention: MGCOCK.TIZ and all 13 v30 practice archives compare exactly equal to v30.

## 004 — Sprint post-game replay prompt remains Japanese

- Reported: 2026-11-06, after the v30 candidate was supplied; exact running image version not independently established by this screenshot.
- Reproduction: finish a Fiery Sprint practice race; the replay dialog appears over the result screen.
- Visible Japanese: `もう一回する？`, `はい`, `いいえ`.
- Proposed English: `PLAY AGAIN?`, `YES`, `NO`.
- Evidence: user-provided Sprint result screenshot showing `1P LOSE`, race times and the Japanese replay dialog.
- Status: English replay wording confirmed by the supplied Sprint result screenshot. Answer alignment defect is tracked as #007. Other-game native checks and both choice actions remain pending.
- Confirmed scope: Sprint replay prompt. The other five minigames may share this surface, but that is not yet verified.
- Next investigation: audit replay/retry/quit prompts across all six minigames, identify shared graphics and native consumers, and preserve selection logic, timing values and score data. The v30 practice landing/rules work does not establish gameplay-result localization.

- v31 scope: all three source-bound physical replay panels are patched (Sprint, Dance and shared ball games). Native replay/choice checks remain pending for all six games.

## 005 — Install supplied English title screen

- User now explicitly requests installing the supplied English mockup. Earlier v31 intentionally retained the original title.
- Status: CONFIRMED IN v33 — Ryan reports successful launch and English title screen on 2026-11-06.
- Supplied title art installed in TITLE.BIZ; original audio, palette, footer copyright pixels and runtime PRESS START are preserved. Small MODE SELECT logo remains a separate asset.

## 006 — First-term Practice Exam instruction card remains Japanese

- Reproduction: Diary → Practice Exam; teacher in red introduces the first-term task involving Hideo's energy waves, sidesteps and dashes.
- Source: TESTMJ.TIZ member 30; captured five-row presentation reconstructed from tiles 8..53 as 9/7/13/9/8.
- Status: IMPLEMENTED IN v32 CANDIDATE — native test pending.
- Scope: exact reported first-term intro and heading. Other 32 instruction members, including other terms/basic cards, remain separate work.

## 007 — English replay answers misaligned with yellow selection box

- Native screenshot confirms PLAY AGAIN / YES / NO, but YES is too high relative to the highlight.
- Original Japanese centers: YES (33.5,42), NO (76.5,42), checked in all three shared panels.
- Status: IMPLEMENTED IN v32 CANDIDATE — native retest pending.
- v32 shifts YES left 1/down 2 and NO left 3/down 2 source pixels; question, frame, palette and selection code unchanged.

## 008 — Sprint win announcement still Japanese

- Latest supplied winning Sprint result screenshot shows Japanese lettering in the large result banner behind the English replay panel.
- Status: OPEN — recorded separately from replay alignment; not patched in v32.
- Audit win/result announcements across minigames before choosing the next coherent gameplay graphics batch.

## 009 — v32 freezes after no-memory-card screen (boot blocker)

- Native report: user says v32 freezes immediately after the no-memory-card notice.
- Status: RESOLVED IN v33 — Ryan confirms launch and working English title screen on 2026-11-06; supplied screenshot also shows mode select. v32 remains withdrawn.
- Diagnosis: TITLE.BIZ begins 00007042 after recompression, but its executable CD locator still expects 00087042. This mismatch was missed by decoded-image/checksum tests.
- Repair: one catalog data byte at SLPS_021.20 + 0x770DD corrected; all v32 graphics/translations remain unchanged. Audit of 876 matched native locator entries: v32 one mismatch, v33 zero.
- Next: continue collecting issues one at a time on v33. Boot/title confirmation does not validate the exam, replay alignment or all practice routes.
- Evidence and directions: BOOT_HOTFIX_V33.md; validation/boot-hotfix-v33.json.

## 010 — Practice menu BACK label clipped

- Reported: 2026-11-06, current v33 playtest.
- Reproduction: Diary → Minigame Practice → Fiery Sprint; third menu option BACK.
- Evidence: user screenshot image(20261106-214702).png; right edge of the final K is visibly clipped.
- Status: OPEN — collect with the next batch; no build yet.
- Next investigation: check the label texture cell and sampled width, add safe right padding or adjust lettering fit, and audit the equivalent BACK labels across all six practice options. Only Sprint is confirmed affected by this screenshot.
- The screenshot also confirms the Sprint landing screen title and instruction panel display in English; this does not validate its rules page or other practice routes.

## 011 — Sprint practice popup: multiple clipped labels and Japanese speed markers

- Reported: 2026-11-06, current v33 playtest; screenshot image(20261106-214811).png.
- Location: black, white-bordered popup over Fiery Sprint practice landing screen, showing five vertically arranged purple labels, a blue selection band and a vertical arrow.
- Evidence: multiple English labels are visibly truncated; examples include HOME RU and BATSU S fragments. Exact intended full strings and popup purpose require source verification rather than inference from clipped text.
- Remaining Japanese: left-side speed markers 速 (fast) and 遅 (slow).
- Status: OPEN — collect for next batch; separate from #010 BACK clipping.
- Next investigation: identify the popup source, audit all five label cells, native texture sampling widths and text scales, and check shared consumers across six practice routes. Restore full readable labels and translate speed markers within their available space. Only this Sprint popup is confirmed affected so far.

## 012 — Practice Exam in-fight announcements and HUD remain Japanese

- Reported: 2026-11-06, current v33 playtest; screenshot image(20261106-215036).png.
- Reproduction: Diary → Practice Exam → first-term fight/task; Japanese appears intermittently during the fight.
- Confirmed visible Japanese: central 開始 (START), and lower-left 科目1 (Subject 1 / Task 1) beside the already-English FIRST TERM EXAM.
- Status: OPEN — include in the next batch audit. The v32/v33 first-term intro-card translation did not cover these in-fight graphics.
- Next investigation: locate the announcement and HUD texture sources, inventory related timed prompts and result/feedback graphics, and verify all relevant shared consumers. Preserve timer and task behavior; other unseen prompts are audit targets, not confirmed defects.
- Screenshot alone does not confirm the first-term introduction is translated or that replay alignment is correct.

## 013 — Practice Exam results screen remains Japanese

- Reported: 2026-11-06, after the v34 updater was supplied; v34 is the current playtest context, but the screenshot alone does not establish the running BIN hash.
- Reproduction: finish a Practice Exam; the exam-results/report-card screen appears.
- Evidence: screenshot image(20261106-235951).png.
- Confirmed Japanese UI: 試験結果 (Exam Results); 「９９年度試験」成績表 (1999 Exam Report Card); table headers 試験 / 記録 / 評価 (Exam / Record / Grade); 1学期末試験 (First-Term Final Exam); のこり beside TIME (Remaining); ×ボタン戻る (X Button: Back).
- Other visible Japanese: 出席簿 on the book (Attendance Register), plus decorative background school/title lettering.
- Status: IMPLEMENTED IN v35 CANDIDATE — native test pending; see EXAM_DANCE_V35.md.
- Next batch investigation: identify the results-screen assets and native text consumers, audit exam/term variants and the return prompt, distinguish UI from decorative artwork, and preserve numerical records, grade and return behavior.
- This result screenshot does not validate the earlier points/BACK/popup/WIN/exam-HUD changes.

## 014 — Practice Exam animated result stamp remains Japanese

- Reported: 2026-11-06, immediately after the results screen tracked as #013.
- Evidence: screenshot image(20261107-000222).png shows a large diagonal blue 不合格 stamp (FAIL / not passed) over the report card.
- Status: IMPLEMENTED IN v35 CANDIDATE — native test pending; see EXAM_DANCE_V35.md.
- Next investigation: locate the animated stamp artwork and its native sprite/tile assembly, translate FAIL within its display boundaries, and audit the corresponding 合格 (PASS) variant. Only the FAIL stamp is confirmed by this screenshot.
- Preserve the stamp timing, scaling/rotation, color roles and actual pass/fail determination. This is a separate overlay from the results-screen labels in #013.

## 015 — Explosive Shot gameplay HUD remains partly Japanese

- Reported: 2026-11-06, during the current post-v34-release playtest; exact running BIN hash not established by the screenshot.
- Reproduction: Minigame Training/Practice → Explosive Shot → gameplay.
- Evidence: screenshot image(20261107-000452).png.
- User-highlighted surface: bottom-left あと 6 球 means 6 balls remaining. Translate the fixed remaining/ball labels while retaining the live ball count.
- Additional confirmed Japanese in the same frame: top-left 芸術点 (Style Points), フレーム点 (Frame Points), and 点 beside the large score (points unit).
- Status: IMPLEMENTED IN v35 CANDIDATE — native test pending; see EXAM_DANCE_V35.md.
- Next investigation: identify the HUD texture cells and native sampling widths, audit count/unit variants and shared minigame consumers, and fit complete English without clipping. Preserve scoring formulas, numerical values, remaining-ball countdown and aim gauges.

## 016 — Doki-Waku Dance player-selection popup remains Japanese

- Reported: 2026-11-06, current post-v34-release playtest; exact running BIN hash not independently established.
- Reproduction: Minigame Practice → Doki-Waku Dance → Player Select.
- Evidence: screenshot image(20261107-000727).png; PLAYER SELECT heading is already English.
- Confirmed Japanese: プレイヤー (Player), 太陽学園男子 (Taiyo High Male), パートナー (Partner), バツ (Batsu), 決定 (Confirm).
- Status: IMPLEMENTED IN v35 CANDIDATE — native test pending; see EXAM_DANCE_V35.md.
- Next investigation: identify the fixed popup labels and dynamic school/gender/character-name consumers; audit other choices and shared selectors. Fit complete English within actual sampled cells, preserving arrows, highlight, selection order and confirmation behavior.
- Only the pictured school/gender and partner are confirmed by this screenshot; other choices are audit targets.

## 017 — Doki-Waku Dance scrolling gameplay captions remain partly Japanese

- Reported: 2026-11-06, current post-v34-release playtest; exact running BIN hash not independently established.
- Reproduction: enter Doki-Waku Dance gameplay; multiple colored text lines scroll across the dancing characters.
- Evidence: screenshot image(20261107-001028).png.
- Confirmed Japanese: yellow caption ヘイ！ブラザー！ (Hey! Brother!) at left; another caption beginning さあゴキゲ… is partially off-screen at right. Do not infer its full wording from this frame.
- Existing English captions are visible at the same time, including Hey! This game is Doki-Waku. The surface is mixed-language.
- Status: IMPLEMENTED IN v35 CANDIDATE — native test pending; see EXAM_DANCE_V35.md.
- Next investigation: inventory the complete scrolling-caption bank and native texture/sprite assembly, translate remaining Japanese, and verify all captions across their movement cycle. Preserve scroll timing, colors, dance controls, scoring and already-English text.
- Off-screen fragments during scrolling are not by themselves evidence of unintended clipping.

## 018 — School Life PLAY/LOAD screen title logos remain Japanese

- Reported: 2026-11-06, start of the next screenshot-by-screenshot batch after v35 was supplied; exact running BIN hash not independently established.
- Evidence: screenshot image(20261107-022137).png.
- Location: PLAY / LOAD entry screen with a blue upper panel and character-photo collage.
- Confirmed surfaces: large lower-right 熱血青春日記2 logo, with the existing NEKKETSU SEISYUN NIKKI romanized strip; small upper-right combined game logo also remains Japanese.
- Proposed English: lower subtitle logo HOT-BLOODED YOUTH DIARY 2; small combined mark RIVAL SCHOOLS / HOT-BLOODED YOUTH DIARY 2, consistent with the supplied English title artwork. Final small-size composition requires readability review.
- Status: OPEN — log and investigate in the next batch; do not generate artwork or build yet while collecting screenshots.
- Required work: locate the separate native logo texture assets and all shared consumers; inspect palette/transparency, sampled bounds and tile/sprite assembly; adapt approved English artwork to each actual footprint; reinsert without clipping or changing adjacent collage/menu graphics.
- Audit repeated uses of the small combined logo, including MODE SELECT, rather than assuming the full title-screen replacement covers them.
- Preserve PLAY/LOAD controls and existing English menu text. Native title/logo success elsewhere does not validate these distinct assets.

## 019 — Diary Backup menu remains Japanese

- Reported: 2026-11-06, next screenshot-by-screenshot batch after v35 was supplied; exact running BIN hash not independently established.
- Reproduction: Diary → Backup.
- Evidence: screenshot image(20261107-022457).png; April 8 / MAKO status HUD, desk background and green lower menu panel.
- Confirmed Japanese: どれをおこないますか？ (What would you like to do?), セーブ (Save), ロード (Load), メニューに戻る (Return to Menu).
- Already English: CANCEL = X button hint; preserve this and the translated status HUD.
- Status: OPEN — log only while collecting the batch.
- Next investigation: identify the menu string/graphic bank and native consumer, fit the prompt and all three choices, and audit the subsequent save/load slot lists, confirmations and memory-card messages for untranslated shared text.
- Only this first Backup menu is confirmed by the screenshot; later dialogs are audit targets. Preserve selection, cancellation, existing saves and memory-card behavior. Do not perform save/load actions as part of logging.

## v34 batch implementation status — native retest pending

- #001: replaces squeezed outlined Current Points text with an unsqueezed 5×7 bitmap in the verified upper 16 source rows, using a solid native dark/red ink index.
- #010: BACK fits within a conservative 40×20 area, leaving the old 48-pixel cell tail clear; needs native confirmation.
- #011: actual Sprint popup descriptors bind HYO 20×20, SHOMA 40×20 at x=200, BATSU 40×20, HOME RUN 80×20 and GAN 20×20. Corrected all 13 shared atlases; speed disks show F (fast) and S (slow). Other games' equivalent screens need native checks.
- #008: WIN lettering replaced within the original 56×24 cell in Sprint and the matching shared ball-game graphic; 1P and replay panel unchanged.
- #012: both shared CEFT4/CEFT6 providers have English vertical START/FINISH and two native glyph cells spelling TASK. Timer digits, colon, portraits and palette tables remain unchanged. Other unseen exam prompts remain possible follow-up work.
- v34 remains a candidate until tested. Earlier replay-answer alignment (#007), exam intro (#006) and all-route gameplay checks are still unconfirmed.

## v35 batch implementation status — native retest pending

- #013–#017 implemented within source-bound result, HUD, selector and caption assets; details in EXAM_DANCE_V35.md.
- Large and small PASS/FAIL variants are included. Record values, grades, timing, ball countdown, selection order and previous English graphics are preserved.
- Eight integration tests, 876 matched catalog signatures, 934 untouched records, changed-sector checksums/ownership and updater hash reproduction pass.
- Native boot and all new screens remain to be confirmed. Decorative repeated school/title text in the exam backdrop is retained.

## Playtest scope

This screenshot establishes the mode-select label issue. It does not establish whether the v29 startup notice was displayed or passed its native test. Continue the playthrough and append subsequent findings in order.
