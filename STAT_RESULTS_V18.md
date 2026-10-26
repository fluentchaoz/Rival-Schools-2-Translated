# Continue at the post-quiz stat results

## Live checkpoint — 2026-10-25

After building v17h, the user reported that it worked and that the first Japanese
they reached was the classroom stat-result screen after the quiz. Their screenshot
shows the English date and `ATK / DEF / STAM / GUTS / POT / INT` panel alongside
the untranslated intelligence-decrease message. The intended English wording is
`INT decreased!!`, with the native down-arrow retained and spaced correctly.

This establishes a successful reported playthrough to that screen. It does not
independently verify every correct/wrong branch, graphic, route, or ending.
Use v17h as the next investigation input and retain v16 as the recovery fallback.

Working v17h BIN SHA-256:

`2ff4d83cca04a22a217883ac9c29b3e2fa9c5c4796d9661db3f95d9acd92149a`

## Export the exact records

Run `probe_stat_results_v18.ps1` in Windows PowerShell. It locates the completed
v17h BIN through `JG2-Recovery-v1/recovery-state.json` and the staged original
under `project/upstream/roms/`. It needs no compiler, network, font, or full-image
copy. Both source images must match the fixed SHA-256 identities and lengths.

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\probe_stat_results_v18.ps1
```

The script creates a uniquely named `JG2-Stat-Probe-v18-<id>.zip` in Downloads.
Attach that ZIP in the translation conversation. It contains extracted game
records and must stay out of public GitHub. The script never uploads it.

Each of these four records is exported from both the original and v17h:

| Record | Why it is needed |
| --- | --- |
| `DAT1/MGAME.BIN` | Stat-message consumers and native arrow-coordinate table |
| `DAT2/MGK04.BIZ` | Opening/quiz runtime text banks and the current English font/text layer |
| `DAT2/MGCOCK.TIZ` | Existing English stat HUD and adjacent graphics |
| `SLPS_021.20` | Runtime address context and existing executable changes |

`manifest.json` records input hashes, each record's LBA, length, and SHA-256.
Input handles are opened read-only, both images are hashed again after extraction,
and every saved ZIP entry is read back and compared before success is reported.
No original, master image, CUE, recovery state, kit, or project source is edited.
Existing ZIPs and partial exports are never replaced. An interrupted export can
leave its own `.zip.partial`; use a new output name on retry.

Optional parameters:

- `-RecoveryRoot`: relocated recovery root.
- `-SourceBin` / `-MasterBin`: explicit original and exact v17h BIN paths.
- `-OutputZip`: a new ZIP path in an existing folder.
- `-CheckOnly`: verifies both discs and all eight records without creating an export.

Do not modify the original recovery kit to install this script. Its resume
mechanism binds the kit and generated source to their saved hashes.

## Implementation evidence and next patch

Pinned upstream `98ca12ddf082d6e2367b2963f76edf5a09242deb` includes
`src/dialogue_audit/stat_result_layout.rs`. It identifies nine paired increase/
decrease messages and a separate nine-entry arrow-offset table at
`DAT1/MGAME.BIN + 0x21D4`. The native consumer is at `0x1A128..0x1A154`.
The old prototype deliberately used unreachable stat-message bindings, so its
initial dialogue layer did not translate these messages.

Next, inspect the exported original and v17h text banks, bind the actual stat
messages to their controls and font, and build one isolated candidate from v17h.
Translate matched increase/decrease pairs together and derive arrow placement
from the actual English text. Preserve unrelated quiz text, graphics, and stat
logic. No v18 translation candidate has been built yet; the export supplies the
missing bytes needed to make that patch source-verified.

## Probe validation

Seven synthetic tests passed under PowerShell 7.4.13. They cover byte-exact ZIP
contents and manifest hashes, read-only preflight, rejection of either wrong
input hash, preservation of existing outputs, missing files, malformed ISO
fields/raw sectors, and out-of-bounds extents. Synthetic images exercise both
Mode 1 and Mode 2 Form 1 data, sector-padded directories, and partial final sectors.
All tests check that input discs, recovery state, and a project source marker
remain byte-identical. No copyrighted game data is included in the tests.

```text
python -m unittest discover -s tests -p test_stat_result_probe.py -v
```

Set `POWERSHELL` to the executable path if `pwsh` is not on PATH. The probe is
written for Windows PowerShell 5.1 and PowerShell 7, but this new export has not
yet been run against the user's actual discs on Windows.
