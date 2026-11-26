# Title, exam and native layout corrections v32

**WITHDRAWN — native freeze reported after the memory-card notice. Use the v33
boot hotfix candidate described in BOOT_HOTFIX_V33.md; native boot remains pending.**

This candidate addresses Ryan's four reports after the v31 playtest:

1. Install the supplied Rival Schools / Hot-Blooded Youth Diary 2 title image.
2. Keep Current Points inside the visible native label area.
3. Translate the reported first-term Practice Exam introduction.
4. Align replay YES/NO lettering with the original cursor positions.

## Implementation and source ownership

### Supplied title image

The 8-bpp TIM at `DAT2/TITLE.BIZ + 0x6000` is a 512×480 picture. The supplied PNG
is resized and quantized to the existing 256-color palette; pixels above row 400
are replaced. Rows 384..399 make a short transition to the original backdrop.
The source audio/prefix, TIM metadata, palette and lower 80 rows (including exact
original copyright pixels) remain unchanged. PRESS START is a separate runtime
element and its code/data are not patched or duplicated into the picture.

The source image SHA is recorded in validation/title-exam-v32.json. Its private
file is `Rival Schools_ Hot-Blooded Youth Diary.png`, supplied by Ryan. The title
says RIVAL SCHOOLS as requested; it is the approved localized mockup, not a new
literal translation of the franchise name. The separate small MODE SELECT logo
is not replaced by this title-screen operation.

### Current Points crop

The two-line v31 label clipped in native play. v32 puts CURRENT POINTS on one
line, with all ink confined to the top 16 rows of the existing 80×24 cell
`(544,224,80,24)` in `MENU.BIZ` TIM `0x22800`. This conservative visible-height
bound avoids reliance on the cropped lower rows. No cursor, score value or other
atlas cell changes. Exact native crop height was not independently established.

### Replay cursor alignment

The three shared native replay panels cover Sprint, Dance and the four ball
games. Original Japanese ink centers are YES `(33.5,42)` and NO `(76.5,42)`
relative to each panel. The v31 English letters were above those anchors. v32
moves YES left 1/down 2 source pixels and NO left 3/down 2, matching both original
centers exactly. Only the two answer lettering rectangles change. The question,
frame, checkerboard outside the letters, palettes and selection logic remain.
These anchors were checked against the original v29 panels in all three files.

### First-term Practice Exam introduction

The supplied frame matches `TESTMJ.TIZ` member 30. Its source body is packed into
32×16 tiles. Reconstructing sequential tiles 8..53 into rows of 9/7/13/9/8 tiles
reproduces all five Japanese lines in the reported frame. The image match was
visually checked and approximately correlated (0.7973 with scaling/filtering
variation). It is source-layout evidence, not an emulator test of v32.

English body:

- Dodge Hideo's energy waves
- and touch Hideo!
- Use sidesteps and dashes
- to get past his shots.
- Master those moves!

The body is rendered in native row widths, then repacked into exactly those
46 source tiles. The first-term heading is also English within its 160-pixel
native title width. Other tiles, CLUT, archive table, record size and all other
32 members remain unchanged. In particular the second/year-end intros and 30
basic instruction cards are still separate future work; this candidate fixes
the exact first-term page Ryan reported, not all practical instruction content.

## Verification

Input v31 SHA:
`f9a3d199c9f535188258203b3a4ddea159755fe35b52e88a8c0c273871b7e7f2`

Output v32 SHA:
`4cfa22fde28be1d805b141fe67f0bbe0f9cbcf999d6f015abd858e4b8dc8654b`

Both images are 663,216,960 bytes. Six records change; all 941 other ISO records
compare exactly equal. The full v30 practice batch and FIERY SPRINT strip remain.
All record lengths and readbacks, original-source preservation, source final
input pages, decoder expansion limits, whole-image sector ownership and EDC/ECC
passed. Seven regressions cover crop survival, original replay anchors, title
footer/audio/palette preservation, exam table/member/tile ownership, earlier
practice retention and wrong-input rejection. All six edited surfaces were
visually reviewed. See validation/title-exam-v32.json for exact identities/counts.

Private cumulative updater paths from exact v29, v30 and v31 all reproduce the
same v32 hash. The equivalent Python apply paths were executed; the PowerShell
wrapper was reviewed but not executed here. Native v32 testing remains pending.

## Use

Extract the private updater beside an extracted v31, v30 or v29 BIN. Open
PowerShell in the folder containing Apply-Title-Exam-v32.ps1 and run:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File ".\Apply-Title-Exam-v32.ps1"
```

Add `-MasterBin "C:\path\to\your.bin"` if needed. It creates a separate
`title-exam-v32` folder and verifies exact source/patch/output hashes. Fresh-boot
the printed CUE, then load an in-game save. Do not load an older save state over
the new graphics. Earlier discs and memory cards are not overwritten.

Check the new title and existing PRESS START; the complete points label; the
first-term Practice Exam card; and both replay choices after all six minigames.
The win banner visible behind the reported replay panel still has Japanese
lettering and is tracked separately; it is not part of the cursor adjustment.

## Rebuild and recovery

```sh
python tools/build_title_exam_v32.py /private/v31.bin /private/new-v32 --title-image /private/supplied-title.png --font /path/to/DejaVuSans-Bold.ttf --accelerator /private/practice_lz.so
```

Python 3.11+, Pillow/NumPy, the earlier optional C encoder and the supplied image
are required. Raw art, disc images, source member previews and sector payloads
remain private. Public Git holds original code/English, coordinates, hashes and
validation metadata. See TITLE_EXAM_V32.md, CURRENT_MILESTONE.md and the running
V29_PLAYTEST_CHECKLIST.md to resume in another session.
