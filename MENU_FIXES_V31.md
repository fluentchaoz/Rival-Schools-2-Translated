# Menu fixes v31 — Current Points, replay and full Sprint label

Offline-built candidate. Native DuckStation testing remains pending. This update
includes all three fixes requested by Ryan: the opening Current Points label,
PLAY AGAIN / YES / NO prompts, and the full FIERY SPRINT selection label. The
experimental English title logo is deliberately not installed.

## Changes and source bindings

- `DAT2/MENU.BIZ`, TIM `0x22800`, cell `(544,224,80,24)`: replace the Japanese
  points label with CURRENT / POINTS in two readable lines. Other mode-select
  labels, imagery, dynamic score digits and palettes are unchanged.
- `DAT2/SPRINT.BIZ`, TIM `0`, panel `(0,68,112,60)`: English replay question/answers.
- `DAT2/DANCE.BIZ`, TIM `0`, panel `(256,82,112,60)`: matching Dance replay text.
- `DAT2/CEFT5.BIZ`, TIM `0x10800`, panel `(656,180,112,60)`: matching replay text
  for the four ball games (Home Run, PK, Explosive Shot and Service Ace).
- The exact v30 `MGCOCK.TIZ` record is retained, including the complete
  FIERY SPRINT text within the native 144-pixel Diary strip. All 13 v30 MINITTL
  archives and their practice landing/rules translations are unchanged.

The three physical replay surfaces are identified by the pinned upstream
`mode_descendant_graphics/gorin_retry.rs` family, not inferred from one screenshot.
Only its three owned lettering rectangles are written in each panel:
`(10,8,94,22)`, `(18,30,35,22)`, `(58,30,44,22)` relative to panel origin.
The question and answers keep their separate native palette ramps; frames,
checkerboard outside lettering, CLUTs and selection/game logic are preserved.

The points cell and atlas offset are bound by upstream `mode_select/assets.rs`
and `mode_select/source.rs`. The Sprint strip width is documented in
`diary_header/menu_consumer.rs`. Upstream is pinned to
`98ca12ddf082d6e2367b2963f76edf5a09242deb`.

## Identities and validation

Input v30 SHA-256:
`c9fdc6a749084fdf972b4debb36dda6b77cb44e0b34f4161d27573130dc44815`

Output v31 SHA-256:
`f9a3d199c9f535188258203b3a4ddea159755fe35b52e88a8c0c273871b7e7f2`

Both images are 663,216,960 bytes. Four records and 145 raw sectors change from
v30. All 943 other ISO records compare byte-for-byte equal. Source and output
record readback, exact decoded ownership, metadata/palette preservation,
source final input pages, source match/block/page expansion limits, absence of
crossing control blocks, and whole-image changed-sector ownership/EDC/ECC pass.
All four edited surfaces were visually reviewed using the bound palettes.

Six regression tests passed, including source rejection, frame/ramp protection,
matching answer heights, point-cell ownership and retention of every v30 practice
archive plus the Sprint label. The v30 baseline was rebuilt here and matched its
recorded SHA exactly. See `validation/menu-fixes-v31.json`.

Private updater paths from both the recovered v29 and verified v30 recreate the
same v31 output SHA. The v29 path includes every v30 translation. PowerShell was
reviewed but not executed here; the equivalent Python paths were executed.
No claim of native gameplay validation is made.

## Use

Extract the private updater beside either extracted v29 or v30 BIN. Open
PowerShell in the updater folder and run:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File ".\Apply-Menu-Fixes-v31.ps1"
```

If auto-discovery misses your BIN, add `-MasterBin "C:\path\to\your.bin"`.
A new `menu-fixes-v31` folder is created. Existing input and output folders are
never overwritten. The script checks the input, selected patch and final image
hashes. Fresh-boot the printed `justice-gakuen2-menu-fixes-v31.cue` and load an
in-game save, not an older save state.

Check CURRENT POINTS on MODE SELECT; the full FIERY SPRINT row; replay prompts
and both choices after each of the six minigames; score/time values and earlier
practice menus/rules. Keep previous discs and existing memory cards. Other
untranslated gameplay/selector artwork remains outside this patch.

The private ZIP contains sector patch payloads, PowerShell/Python apply scripts,
checksums, report and previews. Public Git contains source, authored English,
coordinates and validation metadata, not disc/sector payloads or game previews.

## Rebuild

Python 3.11+, Pillow and NumPy; the v30 verified DejaVuSans-Bold.ttf font. The
optional C encoder is built from the existing `tools/practice_lz_v30.c`.

```sh
python tools/build_menu_fixes_v31.py /private/v30.bin /private/new-v31 --font /path/to/DejaVuSans-Bold.ttf --accelerator /private/practice_lz.so
```
