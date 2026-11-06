# Translation playtest checklist — v29 onward

Running list of Japanese text and other issues reported during testing from recovered v29 onward. Record observations separately from implemented fixes and native validation.

## 001 — School Life 2 mode-select points label

- Reported: 2026-11-06.
- Build under test: recovered v29 (BIN SHA-256 `f4f974c40220dd82925d4b17d6a31b3f95218a6017783666851204ea3040c67f`), per the current playtest context; screenshot alone does not prove disc identity.
- Location: opening MODE SELECT menu, SCHOOL LIFE 2 selected; bottom-right yellow information panel, bottom-left red label beside `0 PTS`.
- Visible Japanese: `現在のポイント`.
- Meaning / proposed English: `CURRENT POINTS` (subject to graphic fit).
- Evidence: user-provided mode-select screenshot. Main description and SCHOOL LIFE 2 title are already English; this points label remains Japanese.
- Status: OPEN — observed, not fixed.
- Next investigation: identify the label's source graphic and all shared consumers before patching; preserve the points value and menu behavior.

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
- Status: IMPLEMENTED IN v30 CANDIDATE — native validation pending.
- v30 candidate: full wording fitted within the native 144-pixel consumed strip; awaiting in-game confirmation.
- Fix target: fit the complete title cleanly within its menu row, then verify selected and unselected rendering. Use the spelling `FIERY`; “Firey” in the user report is not the spelling shown in the screenshot.

## 004 — Sprint post-game replay prompt remains Japanese

- Reported: 2026-11-06, after the v30 candidate was supplied; exact running image version not independently established by this screenshot.
- Reproduction: finish a Fiery Sprint practice race; the replay dialog appears over the result screen.
- Visible Japanese: `もう一回する？`, `はい`, `いいえ`.
- Proposed English: `PLAY AGAIN?`, `YES`, `NO`.
- Evidence: user-provided Sprint result screenshot showing `1P LOSE`, race times and the Japanese replay dialog.
- Status: OPEN — observed, not fixed.
- Confirmed scope: Sprint replay prompt. The other five minigames may share this surface, but that is not yet verified.
- Next investigation: audit replay/retry/quit prompts across all six minigames, identify shared graphics and native consumers, and preserve selection logic, timing values and score data. The v30 practice landing/rules work does not establish gameplay-result localization.

## Playtest scope

This screenshot establishes the mode-select label issue. It does not establish whether the v29 startup notice was displayed or passed its native test. Continue the playthrough and append subsequent findings in order.
