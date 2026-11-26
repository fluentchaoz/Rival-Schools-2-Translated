# Minigame practice interfaces v30

Built from the exact recovered v29 BIN. This is an offline-verified candidate;
DuckStation validation is still required. Keep v29 and existing memory cards.

## Audit and implementation

| Diary option | Practice archive | Landing | Rules pages |
| --- | --- | --- | --- |
| Fiery Sprint | DAT2/MINITTLB.BIZ | English title, practice marker and coach | 1 |
| Doki-Waku-Dance | DAT2/MINITTLC.BIZ | English practice marker and coach | 1 |
| PK Shootout | DAT2/MINITTL6.BIZ | English title, practice marker and coach | 2 |
| Explosive Shot | DAT2/MINITTL7.BIZ | English title, practice marker and coach | 1 |
| Service Ace | DAT2/MINITTL8.BIZ | English title, practice marker and coach | 1 |
| Home Run Contest | DAT2/MINITTL5.BIZ | English title, practice marker and coach | 1 |

The six practice backgrounds and seven instruction pages were visually reviewed
from the recovered disc. The native screenshot directly establishes the Sprint
route; other route mappings are identified by their authored titles/artwork in
the corresponding practice bundles, pending native confirmation.

All 13 MINITTL0..C files have an identical first TIM (exact decoded prefix hash
fdf7e3570a22668e169a297a901dcc5a6b747aaae0c911b1e1ac0ec20b8b50cf).
Their shared menu labels are translated together: game titles, game/1P/VS start,
back, rules/controls, record captions, return-to-mode-menu and watch mode.
Digits, timing units, thumbnail artwork and palettes remain intact. The UI
heading and coach regions use new English panels; the instruction content is
relaid into readable English panels, with button names spelled out.

The Diary FIERY SPRINT label extended beyond the native 144-pixel consumed strip.
It is redrawn within that strip; the former tail is cleared in its 152-pixel source
region. MGAME code and descriptors are unchanged. The source descriptor contract
is in pinned upstream src/diary_header/menu_consumer.rs (MINIGAME_DESCRIPTORS).

## Bounded coverage

This batch translates practice landing/menu/rules interfaces. It is not a claim
that all gameplay, result screens or character selectors are English. The extra
selector TIMs in Sprint/Dance bundles still contain Japanese character/school
labels, and the shared atlas retains its tiny source speed badges. Their native
reachability in the Diary practice route needs checking. Gameplay textures
SPRINT.BIZ, DANCE.BIZ and CEFT5.BIZ remain outside this patch. The separate opening
mode-select CURRENT POINTS label (#001) is also still open.

## Identities

Input v29 BIN SHA-256:
`f4f974c40220dd82925d4b17d6a31b3f95218a6017783666851204ea3040c67f`

Candidate v30 BIN SHA-256:
`c9fdc6a749084fdf972b4debb36dda6b77cb44e0b34f4161d27573130dc44815`

Both images are 663,216,960 bytes. Fourteen records change (13 MINITTL archives
and MGCOCK.TIZ); the whole-image comparison found 2,461 changed raw sectors.
All record lengths, palettes and metadata are preserved. Decoded writes are
checked against owned rectangles. Record readback, source final input pages,
source maximum match/control-block/page expansion limits, absence of crossing
control blocks, and changed-sector ownership/EDC/ECC passed. No executable,
save-state, memory-card or gameplay overlay records change.

Five regression tests passed. The private sector updater recreated the exact
candidate hash. Its Python path was executed; the PowerShell wrapper was reviewed
but cannot be executed in this Linux environment. See validation/practice-v30.json.
No emulator gameplay test was performed here.

## Use the private updater

Extract the updater beside justice-gakuen2-boot-notice-v29.bin, then run
Apply-Practice-v30.ps1. It checks the source, patch and output hashes and creates
a separate practice-v30 folder with BIN/CUE. It never replaces v29.
An explicit source path can be passed with -MasterBin. Python users can run:

```sh
python apply_practice_v30.py /path/to/v29.bin --output /new/output
```

Fresh-boot the printed CUE, load an in-game save and check the six practice
landing screens and rules pages (both PK pages), back navigation, the full Sprint
selection label, record values and earlier English. Then launch each game and
record any remaining Japanese. Do not replace a native pass with an asset preview.

The updater payload and game previews are private deliverables and are not in
public Git. Original code, authored English wording, coordinates, hashes and
validation metadata are committed here.

## Rebuild from source

Python 3.11+, Pillow and NumPy are required. The verified font was
DejaVuSans-Bold.ttf; its exact hash is in the validation report. Other fonts can
change output identity and must be reviewed. Original game data is not embedded.

```sh
gcc -O3 -shared -fPIC tools/practice_lz_v30.c -o /private/practice_lz.so
python tools/build_practice_v30.py /private/v29.bin /private/new-v30 --font /path/to/DejaVuSans-Bold.ttf --accelerator /private/practice_lz.so
```

The optional C encoder accelerates the equivalent Python implementation; parity
and roundtrip tests cover both. Format contracts and page scheduling follow
mcpads/justice-gakuen2-kr-patch@98ca12ddf082d6e2367b2963f76edf5a09242deb.
Its MIT notice is retained in THIRD_PARTY_LZ_LICENSE.txt.
