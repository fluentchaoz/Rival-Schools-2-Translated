# v35 exam results, Explosive Shot HUD and Doki-Waku interfaces

This candidate rolls issues #013–#017 into exact v34. Native v35 boot/gameplay
is pending. The reported screens establish the new untranslated surfaces; they
do not independently establish the running disc hash or close earlier layout tests.

## Included surfaces

| Issue | Changes |
|---|---|
| #013 Exam results | EXAM RESULTS, 1999 EXAM REPORT, EXAM/RECORD/GRADE headers, first/second/year-final result titles, LEFT/TIME, X: BACK; history labels and the attendance book's ROLL label |
| #014 Stamps | Large PASS/FAIL artwork in both 1999 result providers; small PASS/FAIL badges in result atlases and their resident menu mirrors |
| #015 Explosive Shot HUD | STYLE, FRAME and P score unit; LEFT and BALL labels around the untouched live remaining-ball number |
| #016 Doki-Waku selector | PLAYER, PARTNER, OK, all 22 character descriptors, five school labels and BOY/GIRL; four shared texture providers plus both native selector tables |
| #017 Dance captions | Four Japanese introduction strips translated; four existing English strips retained exactly |

| Japanese caption | English |
|---|---|
| ヘイ！ブラザー！ | Hey, brother! |
| さあゴキゲンな | Let's get groovy! |
| Doki-Waku-Danceが始まるぜ！ | Doki-Waku Dance starts now! |
| 準備はいいか？ヒアウィーゴー！ | Ready? Here we go! |

Decorative repeated school/title text in the exam backdrop remains original.
This is not a claim that every unseen minigame/exam prompt is translated.

## Native layout and retention

The selector uses 20-pixel glyph cells, five owned name rows and separate native
school/gender descriptors. Full English names are repacked within those rows.
Only each name descriptor's start/count data bytes change in MGAME06/MGAME07;
character order, pointer order and renderer instructions remain unchanged. Four
MINITTL9/A/B/C providers receive the same translated selector. The earlier menu
atlas, practice landing/rules graphics and already-English PLAYER SELECT remain
exact. OK fits the native two-glyph confirmation cell.

The ball-game HUD writes only reviewed lettering areas. The slanted strip's
number space (x=54..103), lower border, all scoring digits, aim gauges and the
English replay panel remain exact. STYLE/FRAME ink stays inside the native upper
ten-row band. The four Japanese dance captions fit their original strip extents;
existing English captions, heart meter, gameplay markers and retry panel remain.

SIKEN20.BIZ is an indexed archive, not a single compressed stream. Both members
are decoded/patched/recompressed separately and its complete header remains
exact. Each large stamp retains its TIM geometry, original clear/ink palette
roles and native animation consumers. New English lettering is composed inside
those texture boundaries. The report-card text uses source paper texture for
clearing, retaining table lines and numeric/grade positions. Original palettes,
including STP bits, remain exact.

SIKENKK.BIZ result-title members 30–32 use their existing 0x800-byte slots. The
new wording exceeds the old compressed byte lengths, so only those three member
length fields are updated (1926 bytes each). Offsets, slot extents, all other
member headers and all 30 other compressed members remain exact. The stored
lengths stay inside each existing slot and decode to the original 0x708-byte TIM
geometry. No files move or grow at the ISO level.

TITLE.BIZ, MENU.BIZ, SPRINT.BIZ, CEFT4/CEFT6 and TESTMJ.TIZ remain exact to v34,
preserving the title-loader repair, points lettering, Sprint WIN/replay graphics
and exam introduction/START/FINISH/TASK work. v35 changes 13 ISO records; the other
934 are exact. All 876 matched loader signatures agree; no catalog rebinding is
needed for this candidate.

## Verification and limits

Eight integration tests pass: catalog/ISO geometry, unrelated records, previous
boot/title/menu work, selector layout/data ownership, retained English captions,
ball number/border/gauge retention, result palettes/grade alphabet, and archive
slot/member boundaries. The builder verifies every changed sector's ownership
and EDC/ECC, complete record readback and unchanged input hash. Python updater
roundtrip reproduces the output hash. The PowerShell wrapper is reviewed but was
not executed in this Linux environment. Native gameplay is pending.

Input v34 SHA-256:
`2ed4e3233c01b0f1eccf804bffdce6ed6c1f268ce71cf94109c839e86894734a`

Output v35 SHA-256:
`c25207ba7f18dd73e56f5569d3df7dcdf3d9f92cc605dbbf17692b28a6e9cf8c`

Both images are 663,216,960 bytes. See `validation/exam-dance-v35.json` for exact
record hashes, ownership, compression profiles, member lengths and test evidence.

## Apply on Windows

Extract the ZIP beside the v34 BIN and open PowerShell in the extracted folder:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File ".\Apply-Exam-Dance-v35.ps1"
```

If needed, append `-MasterBin "C:\path\to\justice-gakuen2-practice-layout-v34.bin"`.
Allow 700 MB free for the separate output. Existing output folders are rejected.
Wait for V35 VERIFIED, then fresh-boot the printed v35 CUE and use an in-game save.
Keep v34 and existing memory cards. Old emulator save states can retain old
loaded graphics and are unsuitable for validating this change.

First check boot/title. Then test exam results and both outcome stamps, a live
remaining-ball countdown in Explosive Shot, all Doki-Waku school/gender/partner
choices, and the complete scrolling-caption sequence. Test selection/return
behavior as well as text appearance. Revisit any earlier unconfirmed layout tests.

## Rebuild

```bash
python tools/build_exam_dance_v35.py /private/v34.bin /private/new-v35 \
  --font /usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf \
  --accelerator /private/practice_lz.so
```

Python 3.11+, Pillow and NumPy are needed to build. Compile the optional
accelerator from `tools/practice_lz_v30.c`; the updater itself needs only
PowerShell or Python's standard library. Public source does not embed game data.

Source layout evidence: upstream `mcpads/justice-gakuen2-kr-patch` commit
`98ca12ddf082d6e2367b2963f76edf5a09242deb`, especially gorin_selector_names,
gorin_hud_labels, gorin_gauge_labels,
gorin_dance_intro, practical_results and the
SIKENKK indexed-member contract. All production preimages were checked on exact
v34; no Korean artwork/text is carried into this patch.
