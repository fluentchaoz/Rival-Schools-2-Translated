# v34 practice layout and exam HUD corrections

Built from the exact v33 BIN that Ryan confirmed reaches the English title and
mode select. This is a new candidate: **native v34 boot/gameplay is pending**.
Keep v33 as the boot-tested fallback. v32 remains withdrawn.

## Changes and boundaries

| Issue | Implementation | Native check needed |
|---|---|---|
| #001 Current Points | Unsqueezed bitmap lettering, solid native red/dark index, all ink within source rows 224–239 | Legibility on the yellow School Life 2 card |
| #010 BACK | Fit into the first 40×20 pixels; clear old oversized cell | Complete K on all six practice routes |
| #011 Popup labels | Correct the actual sampled cells, including SHOMA starting at x=200 rather than x=192; update all 13 shared atlases | All five Sprint popup labels; equivalent other-game popups |
| #011 Speed markers | F and S replace Japanese inside the original circular markers | F at fast end, S at slow end |
| #008 WIN | Render WIN in the source 56×24 cell in Sprint and the shared ball-game atlas | Winning result banner and original 1P/replay placement |
| #012 Exam HUD | English START/FINISH in both shared CEFT4/CEFT6 providers; two native 16-wide glyphs spell TASK | Beginning/end announcements and TASK 1 beside FIRST TERM EXAM |

The popup descriptors at `DAT1/MGAME06.BIN + 0x1a8` are five 12-byte records:
screen x/y followed by source x/y and width/height, all little-endian u16.

| Text | Source x/y | Sampled width/height |
|---|---|---|
| HYO | 192,216 | 20,20 |
| SHOMA | 200,192 | 40,20 |
| BATSU | 160,192 | 40,20 |
| HOME RUN | 160,168 | 80,20 |
| GAN | 216,216 | 20,20 |

v30's full texture previews missed these narrower display windows. In particular,
the SHOMA writer incorrectly started at x=192 and the BATSU allocation was too
short. v34 changes pixels within the native cells; it does not change the popup
renderer, selection order or gameplay. BACK uses a conservative safe inset based
on the reported clipping; its live width remains to be confirmed.

## Preserved data

TITLE.BIZ, its corrected v33 loader signature, the complete TESTMJ.TIZ archive
(including the English first-term introduction), Diary Sprint row and all three
English replay panels remain exact. All timer digits, colon, portraits, palette
tables, ISO record positions/sizes and source image bytes remain unchanged except
the explicitly claimed texture cells. This patch does not translate every unseen
exam prompt or all Japanese elsewhere in the game.

The vertical exam columns retain the native two-half sprite layout. Announcement
face indices 4–10 and the cyan index-15 offset preserve their source CLUT roles.
The exam TASK prefix retains native index-1 white edges and index-15 blue faces.
The fixed-width UI font is a checked-in 5×7 bit pattern, without horizontal image
compression or antialiasing. WIN uses DejaVu Sans Bold with a recorded font hash.

## Build and checks

```bash
python tools/build_practice_layout_v34.py /private/v33.bin /private/new-v34 \
  --font /usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf \
  --accelerator /private/practice_lz.so
```

The accelerator is optional; compile `tools/practice_lz_v30.c` as a shared library
for faster compression. Python 3.11+, NumPy and Pillow are required for building;
the packaged updater uses PowerShell or Python standard-library code only.

`validation/practice-layout-v34.json` records the exact output identity, source
compression limits, 18 edited resources and their pixel ownership rectangles.
All 876 matched native catalog entries must match their resource signatures before
and after writing. The builder permits only explicit catalog-signature data
rebinding when necessary; no rebinding is needed for this candidate.

Six integration tests cover actual popup consumers/padding, safe points rows,
all catalog bindings, unrelated record preservation, shared HUD ownership and
retention of the title/exam introduction/replay panels. Whole-image changed-sector
ownership and EDC/ECC verification also pass in the builder. A Python updater
roundtrip reproduces the output hash. The PowerShell wrapper is reviewed, but was
not executed in this Linux environment. These checks do not replace native tests.

Upstream source evidence: `mcpads/justice-gakuen2-kr-patch` commit
`98ca12ddf082d6e2367b2963f76edf5a09242deb`, particularly
`src/mode_descendant_graphics/gorin_selector_names.rs`,
`gorin_announcements.rs`, `gorin_sprint_announcements.rs` and
`practical_exam/gameplay_hud.rs`. Current production cells were read and checked
against exact v33; no Korean text/artwork is included in this patch.

## Windows update

Extract the updater ZIP beside the v33 BIN, open PowerShell in the folder
containing `Apply-Practice-Layout-v34.ps1` and run:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File ".\Apply-Practice-Layout-v34.ps1"
```

If auto-detection cannot find it, append
`-MasterBin "C:\path\to\justice-gakuen2-boot-hotfix-v33.bin"`.
Allow 700 MB free for the separate output. Existing output directories are
rejected. Wait for V34 VERIFIED and fresh-boot the printed v34 CUE, then use an
in-game save. Test boot/title first and then the listed screens; do not load a
v33 emulator save state over the changed graphics.

The private patch is a sorted collection of replaced raw sectors, bound to exact
source, patch and output hashes. It is for the user's existing v33 disc only.
The public repository contains source/validation, not original game data.
