# v33 boot hotfix — v32 title catalog mismatch

**v32 is withdrawn: Ryan reports a freeze immediately after the no-memory-card
notice.** v31 remains the earlier booting fallback. v33 is the next boot-test
candidate; native boot success has not yet been confirmed.

## Diagnosis

The v32 title resource was recompressed with a different first encoded word.
Its decoded audio/header/palette data remained valid and the image/checksum tests
passed, but the original executable's 12-byte native CD locator still expected
the old encoded signature. Decoded-prefix preservation does not satisfy that
loader contract. This was missing from the v32 checks.

The actual locator in `SLPS_021.20` at `0x770D4` binds:

- BCD CD position for TITLE.BIZ at LBA 158593.
- Stored size 179992 bytes.
- First four compressed bytes, at executable offset `0x770DC`.

v31/catalog expected `00 08 70 42`; v32 TITLE.BIZ actually begins `00 00 70 42`.
The native loader locator contract is defined by pinned upstream
`src/native_disc_resource.rs`. The upstream record compositor explicitly guards
this encoded-prefix case in `src/mode_descendant_graphics/record_compositor.rs`.
This is a proven loader-contract violation consistent with the reported freeze;
it is not a claim that v33 has already passed a console boot test.

## Repair and verification

v33 binds the existing locator to the actual new title signature. It changes only
one executable **data** byte (`SLPS_021.20 + 0x770DD`, 08 → 00). Locator position
and size are unchanged. No executable instructions are altered. The changed raw
sector is LBA 263688, with regenerated EDC/ECC. Every other one of the 946 ISO
records compares byte-for-byte equal to v32, including the entire new title,
exam card, points label and aligned replay panels.

A scan matched 876 native resource locator entries to exact ISO positions/sizes.
v32 has exactly one signature mismatch (TITLE.BIZ); v33 has zero. Six regression
tests cover rejection of failed v32, all matched signatures, the exact one-byte
scope, all unowned records, sector checksums and wrong-input preflight.
The Python private updater reproduced the exact v33 hash. PowerShell was reviewed
but was not executed here. Native v33 boot remains pending.

Input failed v32 SHA-256:
`4cfa22fde28be1d805b141fe67f0bbe0f9cbcf999d6f015abd858e4b8dc8654b`

Output v33 SHA-256:
`1efd2f0231f9eaaa941830406450e705063d141fe23caa88f2bfe08dfeff03a9`

Both are 663,216,960 bytes. See validation/boot-hotfix-v33.json.

## Apply

Extract the small v33 hotfix beside the extracted v32 BIN and run:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File ".\Apply-Boot-Hotfix-v33.ps1"
```

If needed add `-MasterBin "C:\path\to\justice-gakuen2-title-exam-v32.bin"`.
The script accepts only exact v32, verifies the patch and final image, and creates
a separate `boot-hotfix-v33` folder. It does not overwrite previous discs or
memory cards. Fresh-boot the printed v33 CUE. First verify progress beyond the
memory-card notice to the English title and mode select. Only then continue the
points, replay and first-term exam checks.

## Build prevention and resume

`tools/native_resource_catalog.py` now audits actual or planned replacement
records against the executable locator signatures. `build_title_exam_v32.py`
now invokes this check before writing a BIN; the withdrawn recipe is rejected
instead of silently reproducing the known failed image.

The hotfix can be rebuilt without image/font dependencies:

```sh
python tools/build_boot_hotfix_v33.py /private/v32.bin /private/new-v33.bin
```

Do not promote v33 as boot-tested until Ryan confirms native progress. If it
still freezes, record the exact new filename/output hash and native log/error;
retain v31 and isolate further from that baseline. Do not resume translation
batching over a failing boot baseline.
