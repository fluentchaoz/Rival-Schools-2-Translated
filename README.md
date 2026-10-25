# Rival Schools 2 Translated

English fan-translation / reverse-engineering project for the Japanese PlayStation
release of **Shiritsu Justice Gakuen - Nekketsu Seishun Nikki 2** (`SLPS-02120`).

## Status

Work has progressed through the **English quiz**. The active resume target is
the v16 quiz build; its exact input hash is enforced by the next builder.
See [CURRENT_MILESTONE.md](CURRENT_MILESTONE.md) for the distinction between
repository-recorded live milestones, recovered work, and untested candidates.

**Next candidate: quiz fixed UI v17h** — `QUESTION`, `CORRECT!`, `WRONG!`, and
`EXAM OVER`. The user's latest scan did not find the required v16 BIN under
Downloads. If v16 is available elsewhere, use [RESUME_QUIZ.md](RESUME_QUIZ.md).
Otherwise use the separate recovery kit described in
[recovery/RECOVERY_README.txt](recovery/RECOVERY_README.txt). It rebuilds the
earlier layers from the verified original in a new folder; Windows validation
of that full recovery chain is still pending.

### Confirmed English work so far

- Main mode-select graphics
- School Life `PLAY / LOAD` title UI
- English dialogue glyph support
- Batsu-route prototype work
- Status HUD (`ATK / DEF / STAM / GUTS / POT / INT`)
- MGK04 opening greeting
- `SCHOOL GATE` opening location
- Dynamic English date (`4/1 THU`)
- Full MGK04 tutorial/admissions dialogue layer
- Enrollment/application form
- Name-entry controls (`HIRA / KATA / A-Z / DEL / NEXT / BACK / OK`)
- Native `0-9 / A-Z / a-z` keyboard preserved and verified in-game

### Recovered later work

Twelve builders missing from the previous repository snapshot have been
recovered, covering v6–v17g: name/nickname A-Z defaults, school choices,
greeting palettes, sex/subject/favorite-word choices, enrollment completion,
face customization, and the MGK10/MGK04 quiz layers. Recovery preserves the
historical scripts; it does not certify every intermediate candidate.

`recovery_manifest.json` records their content hashes. The v15b/v16 translation
packets remain local because they also contain extracted Japanese text.
They are not needed to run v17h on an existing v16 master.

## Development philosophy

Changes are built as isolated, source-verified layers. Each successful build is
identified by SHA-256 and tested in-game before becoming the next working master.

## Upstream tooling

Reverse-engineering/build tooling is based on:

`mcpads/justice-gakuen2-kr-patch`

Pinned upstream commit:

`98ca12ddf082d6e2367b2963f76edf5a09242deb`

The local `upstream/` checkout is intentionally not committed here.

## Copyright / repository contents

This repository is for translation code, build/probe scripts, documentation,
checksums, and original project work.

**No ROM/disc image, BIOS, rebuilt BIN/CUE, or copyrighted game asset is included.**
You must supply your own legally obtained game data when using the tooling.
