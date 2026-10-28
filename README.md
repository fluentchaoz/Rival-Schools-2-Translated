# Rival Schools 2 Translated

English fan-translation / reverse-engineering project for the Japanese PlayStation
release of **Shiritsu Justice Gakuen - Nekketsu Seishun Nikki 2** (`SLPS-02120`).

## Status

**v20 built on Windows and played through the quiz into April 8.** Actual
SHA-256: `bf79b70fb5d806669fbf48917c634920e1934ff63d82072b9a0a48ab63238fec`.
The next candidate translates the Taiyo entrance ceremony: both player variants,
both ceremony choices, the title/date, and location graphics through Ran's
introduction and the opening transition toward club orientation. See
[ENTRANCE_CEREMONY_V21.md](ENTRANCE_CEREMONY_V21.md).
Windows/native v21 checks remain pending. Later club scenes and other schools'
ceremony dialogue remain untranslated.

The recovery reproduced all 22 historical hashes through v16, then v17h, v18,
v19, and v20 built successfully on Windows. The current source, hashes, recovery
order, and validation limits are recorded in [PROJECT_HANDOFF.md](PROJECT_HANDOFF.md),
[CURRENT_MILESTONE.md](CURRENT_MILESTONE.md), and [recovery/VALIDATION.md](recovery/VALIDATION.md).
The private recovery kit, original disc, workspace/quiz packets, and rebuilt
images require a separate private backup; they are not in public GitHub.

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
