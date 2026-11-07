# Practice interfaces and rooftop event v37

Exact v36 input SHA-256: `9885ee49e0404d43218b36e7b40b7308a9b7300274e6984f0aa3a260cdba95f1`.

Verified v37 output SHA-256: `66e77edfbb41c7a20255407d5718ad54533f207026c23620c8121fcc38703ffc`.

This candidate addresses #022–#025. Native gameplay remains pending.

- #022: installs the approved English Kyosuke Kagami loading illustration in ALOAD32 member 32, using its existing native palette. Removes baked loading lettering from the generated background layer so the original separate NOW LOADING sprite stays intact. All 49 other archive members, the archive table and message TIM remain exact. Other Japanese loading cards remain a future batch.
- #023: translates the source-bound GUTS lettering in CEFT5. Both visible PK Shootout captions consume this shared cell. Numeric space, orange strip edges and all other HUD pixels remain exact.
- #024: adds wide English P PAUSE / RESUME / BACK lettering in previously empty OVER texture cells. Rebinds the source-validated text descriptors in five MGAME overlays, four practical-exam overlays, SKHAY and the main executable: eleven consumers. The original 1/2 digit sprites are preserved. Original shared Japanese glyphs are retained to avoid changing unrelated strings. The main executable's longer mode-return label is rebound to BACK with its original action and data extent retained. No executable instructions, highlight logic, action mapping or pause-state code is modified. This reaches shared providers beyond the reported PK screen; live checks in all six minigames, including Doki-Waku's common path, are still required.
- #025: translates 53 reviewed entries (indices 67–119) in each of MGM04 selectors 0/1, covering the Edge/Daigo rooftop sparring encounter from the reported opening through the reviewed leave, spar and decline branches. Includes both choice prompts. English is fitted to the native twenty-column/four-row window; existing name/timing control codes and arguments remain in order. All other message payloads, font pixels and event scripts remain exact. Also translates 16 copies of the Japanese ROOFTOP label across 11 background archives. Other rooftop encounters are outside this reviewed block and remain follow-up work.

## Build and validation

Python 3.11+, Pillow, NumPy, SciPy, C compiler and exact private v36 BIN required. The indexed loading artwork contribution and source-bound translation plans are checked into Git; the full disc and private sector packet are not.

```sh
cc -O2 -shared -fPIC tools/practice_lz_v30.c -o /tmp/practice_lz.so
cc -O2 -shared -fPIC tools/practice_lz_v36.c -o /tmp/practice_lz_v36.so
python tools/build_practice_roof_v37.py /path/to/v36.bin /new/build --font /usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf --accelerator /tmp/practice_lz.so --tail-accelerator /tmp/practice_lz_v36.so
python tools/test_practice_roof_v37.py /path/to/v36.bin /new/build/justice-gakuen2-practice-roof-v37.bin /new/build/practice-roof-v37-report.json validation/practice-roof-v37.json
```

The tail compressor now preserves source page crossings only in the unchanged compressed prefix; its rebuilt tail introduces none. Original per-record decoder match/block/page bounds, final input pages, compressed slots, archive tables and ISO extents remain enforced. A complete rebuild under the same bounds is used when a preserved prefix cannot fit. The exact decoded result is always verified.

Ten integration checks pass. All 876 native loader signatures match; 921 untargeted records remain byte-exact. All 1,483 changed sectors passed complete ownership and Mode 2 EDC/ECC checks. No catalog rebinding is needed in this build. Updater roundtrip results are recorded separately. PowerShell was reviewed but not executed on the Linux host.

## Native retest

Apply to exact v36, retain v36 and existing memory cards, and fresh-boot the new CUE. Check the Kyosuke card and single native loading message; both PK GUTS counters; Start, RESUME and BACK in each minigame and any 2P variant; the rooftop label, first dialogue, choices, sparring and decline outcomes. Verify the same in-game save retains its name/date/club/relationships. Old emulator states may restore earlier resources. Keep #022–#025 open until the relevant live checks pass.
