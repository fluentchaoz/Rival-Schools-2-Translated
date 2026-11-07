# Menu art and Backup v36

Applies issues #018–#021 to the exact v35 master. Native emulator validation remains pending.

- #018: installs the approved generated subtitle and combined English logos in eight native cells across MA_TIT, MENU and SELP1–5. Original palette tables, texture extents, photo collage and menu controls remain exact. The MODE SELECT sprite's overlapping 16-pixel neighbor is preserved.
- #019: replaces 29 selector-5 messages in each of 78 dialogue providers, including Backup actions, slot choices, confirmations, progress and memory-card failures. The date alphabet keeps ten original decimal cells and changes only month/day labels to M/D. English Cancel remains exact. Five monthly bundles mirror their 25 independent school providers exactly. Uses existing English glyph imagery; no font slots or executable save/load logic are changed. YES/NO remain on native rows 2/3. Two preimage-bound quiz/title font variants were reviewed separately.
- #020: replaces Service Ace's CURRENT and HI SCORE captions in the shared CEFT5 HUD. Score values, P units, aiming/power gauge and other v35 labels remain exact.
- #021: converts the generated clean olive/gold English pattern into each of the two native SIKEN20 background palettes. Original report sheets, tables, props, English heading/return hint, record atlas and animated PASS/FAIL stamps remain in place. The generated mockup's baked scores were not imported.

## Reproduction

Requires Python 3.11+, Pillow, NumPy, SciPy, a C compiler and the exact private v35 BIN. The repository contains the generated indexed artwork contributions and their source/palette hashes, not a disc image.

```sh
cc -O2 -shared -fPIC tools/practice_lz_v30.c -o /tmp/practice_lz.so
cc -O2 -shared -fPIC tools/practice_lz_v36.c -o /tmp/practice_lz_v36.so
python tools/build_menu_art_v36.py /path/to/v35.bin /new/output --font /usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf --accelerator /tmp/practice_lz.so --tail-accelerator /tmp/practice_lz_v36.so
```

The dialogue encoder retains complete original compressed pages before the first changed decoded byte, then rebuilds the tail with the original back-reference dictionary and page/block/match limits. Pool-alignment search changes only zero padding and pointer data in the reserved arena. Every rebuilt stream is decoded and compared before use. The common encoder also adjusts literal-prefix scheduling when a final terminator would straddle a page; the existing decoder limits remain enforced.

The builder validates exact ISO extents, all record readbacks, native CD locator signatures, complete changed-sector ownership and Mode 2 EDC/ECC. It retains the input and refuses an existing output directory. Only resource-signature data is rebound in the executable if required by recompressed graphics.

## Native retest

Fresh-boot the v36 CUE, then use an in-game save. Check the PLAY/LOAD and MODE SELECT logos, character-selector copies, Backup selections and cancellation, save/load confirmations, Service Ace current/high records, both exam result variants and stamps. Keep the v35 disc and memory cards. Do not close the four issues until these live screens pass. Generated artwork may need a readability adjustment at native resolution.

Verified output BIN SHA-256: `9885ee49e0404d43218b36e7b40b7308a9b7300274e6984f0aa3a260cdba95f1`. 854 untargeted records retained; 3504 changed sectors; 5 native catalog data signatures rebound.
