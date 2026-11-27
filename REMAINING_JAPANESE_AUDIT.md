# What is still Japanese on the disc (audit of v45)

Method: compared every text record against the original disc and against the English glyph set. Nothing here needed
the game to be booted. Counts are *message slots* ("coordinates") unless stated. Contact sheets of the image finds are
in `legacy/validation/audit-images/`.

## 1. Story / dialogue text (DAT2/MG*.BIZ, 78 records) — the big one

| Group | Still Japanese | Notes |
| --- | ---: | --- |
| Dialogue, selectors 0/1 (male/female player) | 38,597 slots (~18,400 distinct patterns) | Only ~1,540 slots translated so far (rooftop, infirmary, classroom/ground, parts of MGG04T) |
| UI/name/stat strings, selector 2 | 7,111 slots (~830 distinct) | Stat-up messages, item names, character names, club names; half already English |
| Practice descriptions, selector 6 | 694 slots (144 distinct) | 14 records |
| Daily narration, selectors 3/4 | 552 slots (12 distinct) | e.g. "Where should I go?" style prompts; the 38-line daily set is already English |
| Memory-card messages, selector 5 | 78 slots (1 distinct) | Essentially done |

Remaining dialogue by record family (slots, both variants): MGK (Kyosuke route?) 8.2k, MGM 8.1k, MGT 6.1k, MGG08 5.9k,
MGG09 5.7k, MGG04 4.5k, MGC (calendar/common) 3.3k, MGG11 1.8k, MGG06 1.6k, MGE 1.2k, MGF 1.2k.
Record-level detail: run `scratchpad/audit3.py` (also saved as `tools/audit_remaining_text.py`).

## 2. Images / textures with Japanese lettering

| Resource | What it is | Effort |
| --- | --- | --- |
| `DAT2/EDB*.BIZ` (23 files, 1-3 images each) | Ending epilogue paragraphs as baked images | Medium: re-render English paragraphs, same technique as the calendar |
| `DAT2/ED01-ED24.BIZ` | Ending narration pages (small-font textures) | Medium/high: check whether they are glyph atlases or baked text |
| `DAT2/EDITCM*.BIZ` (about 25) | Edit-mode move lists (special-move names) | Medium: names plus command icons stay |
| `DAT2/PDATIM.BIZ` (5 pages) | Pocket Justice instructions | Low/medium: five full pages of baked text |
| `DAT2/CARD.BIZ` (39 images) | Collectible card faces and handwritten notes | High: lots of small text, handwriting |
| `DAT2/OPTINFO.TIZ` | Options help text (also looks cropped in the original) | Low |
| `DAT2/TOROFY.BIZ` | Trophy certificate | Low |
| `DAT2/KOUBAI0/1.TIZ` | Shop ("Bonus"/"Purchase Club") menus and labels | Low/medium |
| `DAT2/HERE.TIZ` | "Wait a moment!" flash text | Low |
| `DAT2/KOUKA00-04.BIZ` | School artwork with kanji titles | Optional (decorative) |
| `DAT2/EDSR.BIZ` | Staff-roll art (mostly pictures, little text) | Check |
| `DAT2/OP01.BIZ`, `DAT2/MGSTAFF1.BIZ`, `OMOIDE.TZZ`, `NKBG.BIZ`, `DAT4/*.STR` | Opening text screens, credits and movies | Not yet inspected (movies cannot be edited this way) |
| Background label strips (MGBG*.BZZ) | 2 copies of 保健室 remain in MGBGK03 #17 and MGBGM01 #12; other location labels were done earlier | Low |

## 3. Executables / overlays

Shift-JIS scan of DAT1/*.BIN and SLPS_021.20 finds only a few strings (the "forced shutdown / console modified" notice
in KOUBAI2, MGTIT, MODESEL and the save-data title string). Almost all runtime text is in the glyph records above.

## 4. Suggested order

1. Cheap shared tables first: selector 2 (names, stats, items), selector 6, selector 3/4 remainders, MGBG leftovers. About 1,000 distinct strings, applied to every record automatically.
2. Baked-image batches in one go: EDB endings, PDATIM, OPTINFO, KOUBAI, TOROFY, HERE, EDITCM.
3. Dialogue by scene cluster, school by school. Taiyo (T) first since MGG04T is nearly done, then MGM/MGK.
4. Cards, credits, optional art last.

## 5. How to stop testing every step

* The data can be audited and **rendered back from the built disc** for every text slot and image, which is how the checks
  above worked. That catches wrong text, overflow and wrong slots, not behaviour.
* Plan: build one candidate per whole category, with before/after contact sheets, and have you test only a short route
  per batch (boot, one scene per category, one save).
