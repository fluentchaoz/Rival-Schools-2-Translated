# v29 playtest checklist

Running list of Japanese text and other issues reported while playing the recovered v29 candidate. Record observations separately from implemented fixes and native validation.

## 001 — School Life 2 mode-select points label

- Reported: 2026-11-06.
- Build under test: recovered v29 (BIN SHA-256 `f4f974c40220dd82925d4b17d6a31b3f95218a6017783666851204ea3040c67f`), per the current playtest context; screenshot alone does not prove disc identity.
- Location: opening MODE SELECT menu, SCHOOL LIFE 2 selected; bottom-right yellow information panel, bottom-left red label beside `0 PTS`.
- Visible Japanese: `現在のポイント`.
- Meaning / proposed English: `CURRENT POINTS` (subject to graphic fit).
- Evidence: user-provided mode-select screenshot. Main description and SCHOOL LIFE 2 title are already English; this points label remains Japanese.
- Status: OPEN — observed, not fixed.
- Next investigation: identify the label's source graphic and all shared consumers before patching; preserve the points value and menu behavior.

## Playtest scope

This screenshot establishes the mode-select label issue. It does not establish whether the v29 startup notice was displayed or passed its native test. Continue the playthrough and append subsequent findings in order.
