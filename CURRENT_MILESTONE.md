# Current Known-Good Milestone

## Name-entry UI v7 — live tested

Live-tested rebuilt-disc SHA-256:

`c9eb6cc1c15eb3b65f1aa9e02cee102fbb1bc502483e88950175139720ca48f5`

Patched `DAT1/MGENT.BIN` SHA-256:

`a3459705345ac3457e941aa72ae5e48cec43afdca635cff269a9ebaf0e9946e3`

Local working CUE (not tracked by Git):

`upstream\work\english-name-entry-nickname-default-az-v7\build\justice-gakuen2-name-entry-nickname-default-az-v7.cue`

### Confirmed behavior

- English enrollment form renders correctly in-game.
- Native name-entry controls render as `HIRA / KATA / A-Z / DEL / NEXT / BACK / OK`.
- Original control colors remain correct.
- Native `0-9 / A-Z / a-z` keyboard is intact.
- NAME opens directly on A-Z.
- Moving into NICKNAME also keeps/opens A-Z.
- HIRA/KATA/A-Z cycling still works.
- Keyboard navigation and cursor highlighting work.
- v5 form/control graphics remain intact.

### v7 behavior patch

v7 builds on v6 and changes only the nickname-specific page seed:

- `MGENT + 0x1FA4`: `addiu v0, zero, 1` -> `addiu v0, zero, 2`
- `MGENT + 0x1FA8`: existing `sb v0, 9(s0)` then stores page index 2

Patch scope from v6 to v7:

- `1` changed byte in `DAT1/MGENT.BIN`
- `1` raw disc sector changed

### Next target

Translate the five-school selection popup shown immediately after nickname entry while preserving the crest icons and selection logic.

Known school-choice descriptor table:

- `MGENT + 0x15F8`
- 10 descriptors total
- text descriptors are indexes `1, 3, 5, 7, 9`
- 5 logical school choices

Do not promote a later build over v7 until it is live-tested.
